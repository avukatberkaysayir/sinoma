"""
ADIM 17 — CC Content Pipeline V2: Internet Archive video discovery.

Searches the Internet Archive for CC-BY/CC-BY-SA licensed Chinese videos
and returns structured metadata for use by cc_video_processor.py.

Only CC-BY and CC-BY-SA licenses are accepted — both allow commercial use,
which is required for running AdMob ads alongside the content.

Usage:
    python cc_video_finder.py --query "mandarin chinese lesson" --limit 20
    python cc_video_finder.py --query "汉语" --output found_videos.json
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from typing import Any

try:
    import internetarchive as ia  # type: ignore
    _IA_AVAILABLE = True
except ImportError:
    _IA_AVAILABLE = False

# Only licenses allowing commercial use.
_ALLOWED_LICENSES = {
    "https://creativecommons.org/licenses/by/4.0/",
    "https://creativecommons.org/licenses/by/3.0/",
    "https://creativecommons.org/licenses/by/2.0/",
    "https://creativecommons.org/licenses/by/1.0/",
    "https://creativecommons.org/licenses/by-sa/4.0/",
    "https://creativecommons.org/licenses/by-sa/3.0/",
    "https://creativecommons.org/licenses/by-sa/2.0/",
    "https://creativecommons.org/licenses/by-sa/1.0/",
}

_VIDEO_FORMATS = {".mp4", ".webm", ".ogv", ".avi", ".mkv", ".mov"}
_SUBTITLE_FORMATS = {".vtt", ".srt"}


@dataclass
class CcVideoMetadata:
    identifier: str
    title: str
    description: str
    license: str
    language: str
    video_url: str
    subtitle_url: str | None
    duration_seconds: float | None
    subject: list[str] = field(default_factory=list)


def _normalize_license(raw: Any) -> str:
    """Return the first license URL string from a scalar or list field."""
    if isinstance(raw, list):
        return str(raw[0]) if raw else ""
    return str(raw) if raw else ""


def _best_video_file(files: list[dict[str, Any]]) -> dict[str, Any] | None:
    """Pick the best video file: prefer mp4, then webm, then any video format."""
    preferred = [".mp4", ".webm", ".ogv"]
    for ext in preferred:
        for f in files:
            name = f.get("name", "")
            if name.lower().endswith(ext):
                return f
    for f in files:
        if any(f.get("name", "").lower().endswith(e) for e in _VIDEO_FORMATS):
            return f
    return None


def _best_subtitle_file(files: list[dict[str, Any]]) -> dict[str, Any] | None:
    """Pick a subtitle file if one exists (VTT preferred over SRT)."""
    for ext in (".vtt", ".srt"):
        for f in files:
            if f.get("name", "").lower().endswith(ext):
                return f
    return None


def _file_url(identifier: str, filename: str) -> str:
    return f"https://archive.org/download/{identifier}/{filename}"


def search_ia_videos(
    query: str,
    limit: int = 20,
    language_filter: str = "chi",
) -> list[CcVideoMetadata]:
    """Search Internet Archive for CC-licensed Chinese videos.

    Args:
        query: Search terms (e.g. "mandarin chinese lesson").
        limit: Maximum number of results to return.
        language_filter: ISO 639-2 language code; 'chi' = Chinese (any).

    Returns:
        List of CcVideoMetadata for items that pass license + video-file checks.
    """
    if not _IA_AVAILABLE:
        print(
            "internetarchive package not installed. Run: pip install internetarchive",
            file=sys.stderr,
        )
        return []

    # Build IA advanced search query
    ia_query = (
        f"({query}) AND mediatype:movies "
        f"AND language:{language_filter} "
        f"AND licenseurl:(*creativecommons.org/licenses/by/*)"
    )

    results: list[CcVideoMetadata] = []
    try:
        search_results = ia.search_items(
            ia_query,
            fields=["identifier", "title", "description", "licenseurl", "language", "subject"],
            num_found=limit,
            params={"rows": limit},
        )
    except Exception as exc:
        print(f"Internet Archive search error: {exc}", file=sys.stderr)
        return []

    for item_meta in search_results:
        identifier = item_meta.get("identifier", "")
        if not identifier:
            continue

        raw_license = _normalize_license(item_meta.get("licenseurl", ""))
        if not any(allowed in raw_license for allowed in _ALLOWED_LICENSES):
            continue

        # Fetch file listing for this item
        try:
            item = ia.get_item(identifier)
            files = list(item.files)
        except Exception:
            continue

        video_file = _best_video_file(files)
        if not video_file:
            continue

        subtitle_file = _best_subtitle_file(files)
        duration_raw = video_file.get("length")
        try:
            duration = float(duration_raw) if duration_raw else None
        except (TypeError, ValueError):
            duration = None

        raw_subject = item_meta.get("subject", [])
        if isinstance(raw_subject, str):
            raw_subject = [raw_subject]

        results.append(
            CcVideoMetadata(
                identifier=identifier,
                title=str(item_meta.get("title", "")),
                description=str(item_meta.get("description", "")),
                license=raw_license,
                language=str(item_meta.get("language", "")),
                video_url=_file_url(identifier, video_file["name"]),
                subtitle_url=_file_url(identifier, subtitle_file["name"])
                if subtitle_file
                else None,
                duration_seconds=duration,
                subject=list(raw_subject),
            )
        )

        if len(results) >= limit:
            break

    return results


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Search Internet Archive for CC-licensed Chinese videos"
    )
    parser.add_argument("--query", required=True, help="Search query")
    parser.add_argument("--limit", type=int, default=20, help="Max results")
    parser.add_argument(
        "--language", default="chi",
        help="ISO 639-2 language code (default: chi = Chinese)"
    )
    parser.add_argument(
        "--output", default=None,
        help="Write results JSON to this file (default: stdout)"
    )
    args = parser.parse_args()

    results = search_ia_videos(
        query=args.query,
        limit=args.limit,
        language_filter=args.language,
    )

    if not results:
        print("No CC-licensed Chinese videos found.", file=sys.stderr)
        sys.exit(1)

    output_data = [
        {
            "identifier": r.identifier,
            "title": r.title,
            "license": r.license,
            "language": r.language,
            "video_url": r.video_url,
            "subtitle_url": r.subtitle_url,
            "duration_seconds": r.duration_seconds,
            "subject": r.subject,
        }
        for r in results
    ]

    json_str = json.dumps(output_data, ensure_ascii=False, indent=2)
    if args.output:
        from pathlib import Path
        Path(args.output).write_text(json_str, encoding="utf-8")
        print(f"Found {len(results)} video(s). Written to {args.output}")
    else:
        print(json_str)


if __name__ == "__main__":
    main()
