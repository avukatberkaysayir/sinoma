"""
pipeline_poller.py — Supabase pipeline_jobs tablosunu izler.
Pending iş bulunca çeker, Whisper ASR çalıştırır, sonucu yazar.
dev_server.py tarafından arka plan thread olarak başlatılır.
"""
from __future__ import annotations

import threading
import time
from datetime import datetime, timezone
from typing import Any

import requests

POLL_INTERVAL = 5  # saniye


def _headers(service_key: str) -> dict[str, str]:
    return {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }


def _claim_pending(base_url: str, service_key: str) -> dict[str, Any] | None:
    resp = requests.get(
        f"{base_url}/rest/v1/pipeline_jobs",
        params={"status": "eq.pending", "order": "created_at.asc", "limit": "1", "select": "*"},
        headers={"apikey": service_key, "Authorization": f"Bearer {service_key}"},
        timeout=10,
    )
    if resp.status_code >= 300 or not resp.json():
        return None
    job = resp.json()[0]

    # Atomic claim — sadece hâlâ pending ise güncelle
    patch = requests.patch(
        f"{base_url}/rest/v1/pipeline_jobs",
        params={"id": f"eq.{job['id']}", "status": "eq.pending"},
        json={"status": "processing"},
        headers=_headers(service_key),
        timeout=10,
    )
    return job if patch.status_code < 300 else None


def _finish_job(
    base_url: str,
    service_key: str,
    job_id: str,
    status: str,
    result: dict | None = None,
    error: str | None = None,
) -> None:
    data: dict[str, Any] = {"status": status}
    if result:
        data["result"] = result
    if error:
        data["error_text"] = error[:2000]
    requests.patch(
        f"{base_url}/rest/v1/pipeline_jobs",
        params={"id": f"eq.{job_id}"},
        json=data,
        headers=_headers(service_key),
        timeout=10,
    )


def _poll_loop(base_url: str, service_key: str) -> None:
    print("  [poller] pipeline_jobs izleniyor…")
    from youtube_asr_pipeline import run as asr_run

    while True:
        try:
            job = _claim_pending(base_url, service_key)
            if job:
                job_id = job["id"]
                payload = job.get("payload") or {}
                url = payload.get("url", "")
                active = payload.get("active", False)
                print(f"\n  [poller] İş alındı {job_id[:8]}… url={url}")
                try:
                    result = asr_run(url, active=active)
                    _finish_job(base_url, service_key, job_id, "done", result=result)
                    print(f"  [poller] ✅ {result}")
                except Exception as exc:
                    _finish_job(base_url, service_key, job_id, "error", error=str(exc))
                    print(f"  [poller] ❌ {exc}")
        except Exception as exc:
            print(f"  [poller] Poll hatası: {exc}")
        time.sleep(POLL_INTERVAL)


def start(base_url: str, service_key: str) -> None:
    t = threading.Thread(
        target=_poll_loop,
        args=(base_url, service_key),
        daemon=True,
        name="pipeline-poller",
    )
    t.start()
