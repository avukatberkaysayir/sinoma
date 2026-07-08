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
    # Priority passes so an interactive request never waits behind a long batch:
    #   1) whisper_clip — a single-clip Whisper the admin is waiting on live
    #   2) heavy batch  — youtube_asr / movie (whole-video segmentation)
    #   3) anything left — video_meta and the rest
    # (Within a pass, oldest first.) This only reorders PENDING jobs; a batch job
    # already mid-run still holds the single worker until it finishes — the admin
    # surfaces that as "busy, queued" rather than a dead worker.
    hdr = {"apikey": service_key, "Authorization": f"Bearer {service_key}"}
    job = None
    for type_filter in (
        "&job_type=eq.whisper_clip",
        "&job_type=not.in.(video_meta,whisper_clip)",
        "",
    ):
        resp = requests.get(
            f"{base_url}/rest/v1/pipeline_jobs"
            f"?status=eq.pending{type_filter}&order=created_at.asc&limit=1&select=*",
            headers=hdr,
            timeout=10,
        )
        if resp.status_code < 300 and resp.json():
            job = resp.json()[0]
            break
    if job is None:
        return None

    # Atomic claim — sadece hâlâ pending ise güncelle. PostgREST 0 satır
    # eşleşse de 204 döner; kazandığımızı GÖVDEDEN doğrula (return=
    # representation), yoksa iki poller aynı işi işler → her klip çift.
    patch = requests.patch(
        f"{base_url}/rest/v1/pipeline_jobs",
        params={"id": f"eq.{job['id']}", "status": "eq.pending"},
        json={"status": "processing"},
        headers={**_headers(service_key), "Prefer": "return=representation"},
        timeout=10,
    )
    try:
        claimed = patch.status_code < 300 and len(patch.json()) > 0
    except ValueError:
        claimed = False
    return job if claimed else None


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


def _requeue_stale(base_url: str, service_key: str) -> None:
    """On startup, re-queue any job left in 'processing' by a previous worker that
    died mid-job (otherwise it stays 'processing' forever and the admin polls a
    zombie). Safe: a fresh worker hasn't claimed anything yet."""
    try:
        resp = requests.patch(
            f"{base_url}/rest/v1/pipeline_jobs?status=eq.processing",
            json={"status": "pending"},
            headers=_headers(service_key),
            timeout=10,
        )
        if resp.status_code < 300:
            print("  [poller] takılı 'processing' işler yeniden kuyruğa alındı")
    except Exception as exc:
        print(f"  [poller] requeue hatası: {exc}")


def _poll_loop(base_url: str, service_key: str) -> None:
    print("  [poller] pipeline_jobs izleniyor…")
    _requeue_stale(base_url, service_key)
    from youtube_asr_pipeline import run as asr_run
    from youtube_asr_pipeline import transcribe_clip
    from movie_supabase_pipeline import run as movie_run
    from youtube_miner import fetch_video_meta
    from pathlib import Path

    def _write_video_meta(youtube_id: str, url: str) -> dict[str, Any]:
        meta = fetch_video_meta(url)
        if meta and youtube_id:
            requests.patch(
                f"{base_url}/rest/v1/import_history",
                params={"youtube_id": f"eq.{youtube_id}"},
                json={**meta, "updated_at": datetime.now(timezone.utc).isoformat()},
                headers=_headers(service_key),
                timeout=15,
            )
        return meta or {}

    while True:
        try:
            job = _claim_pending(base_url, service_key)
            if job:
                job_id = job["id"]
                payload = job.get("payload") or {}
                url = payload.get("url", "")
                active = payload.get("active", False)
                hsk_filter = payload.get("hsk_filter") or None
                word_filter = payload.get("word_filter") or None
                grammar_filter = payload.get("grammar_filter") or None
                job_type = job.get("job_type") or "youtube_asr"
                print(f"\n  [poller] İş alındı {job_id[:8]}… type={job_type} url={url}")
                try:
                    def _progress(n: int, meta: dict[str, Any] | None = None) -> None:
                        _update_progress(base_url, service_key, job_id, n, meta)
                    if job_type == "video_meta":
                        result = _write_video_meta(
                            payload.get("youtube_id", ""), url)
                    elif job_type == "whisper_clip":
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
                        result = asr_run(url, active=active, hsk_filter=hsk_filter,
                                         word_filter=word_filter,
                                         grammar_filter=grammar_filter,
                                         on_progress=_progress)
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
