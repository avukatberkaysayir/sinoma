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


def _update_progress(
    base_url: str, service_key: str, job_id: str, n: int,
    meta: dict[str, Any] | None = None,
) -> None:
    try:
        result: dict[str, Any] = {"segmentsWritten": n, "in_progress": True}
        if meta:
            result.update(meta)  # durationSec / lastPos for the admin ETA
        requests.patch(
            f"{base_url}/rest/v1/pipeline_jobs",
            params={"id": f"eq.{job_id}"},
            json={"result": result},
            headers=_headers(service_key),
            timeout=5,
        )
    except Exception:
        pass


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
    from youtube_asr_pipeline import transcribe_clip
    from movie_supabase_pipeline import run as movie_run
    from pathlib import Path

    while True:
        try:
            job = _claim_pending(base_url, service_key)
            if job:
                job_id = job["id"]
                payload = job.get("payload") or {}
                url = payload.get("url", "")
                active = payload.get("active", False)
                hsk_filter = payload.get("hsk_filter") or None
                job_type = job.get("job_type") or "youtube_asr"
                print(f"\n  [poller] İş alındı {job_id[:8]}… type={job_type} url={url}")
                try:
                    def _progress(n: int, meta: dict[str, Any] | None = None) -> None:
                        _update_progress(base_url, service_key, job_id, n, meta)
                    if job_type == "whisper_clip":
                        result = transcribe_clip(
                            url,
                            float(payload.get("start", 0)),
                            float(payload.get("end", 0)),
                            payload.get("row_id", ""),
                            on_progress=_progress,
                        )
                    elif job_type == "movie":
                        result = movie_run(
                            Path(payload.get("video_path", "")),
                            sub_path=Path(payload["sub_path"])
                            if payload.get("sub_path") else None,
                            active=active,
                            hsk_filter=hsk_filter,
                            on_progress=_progress,
                        )
                        # Normalise key so the admin's progress reader works.
                        result.setdefault("segmentsWritten",
                                          result.get("clipsWritten", 0))
                    else:
                        result = asr_run(url, active=active, hsk_filter=hsk_filter, on_progress=_progress)
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
