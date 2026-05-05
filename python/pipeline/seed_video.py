"""
End-to-end pipeline: YouTube URL → yt-dlp subtitles → Firestore Emulator

Usage:
    python seed_video.py --url "https://youtu.be/VIDEO_ID"
    python seed_video.py --url "https://youtu.be/VIDEO_ID" --hsk-map hsk_map.json
    python seed_video.py --url "https://youtu.be/VIDEO_ID" --active   # set isActive=True immediately
    python seed_video.py --url "https://youtu.be/VIDEO_ID" --sub-file captions.vtt

Writes directly to the Firestore Emulator (localhost:9299) using the REST API
with Authorization: Bearer owner (emulator-only bypass — never use in production).

If --hsk-map is not provided, uses a built-in HSK word map (limited but sufficient for demos).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

from youtube_miner import run as mine_video, extract_video_id_from_path

FIRESTORE_BASE = (
    "http://localhost:9299/v1/projects/demo-mandarin-academy"
    "/databases/(default)/documents"
)
HEADERS = {
    "Content-Type": "application/json",
    "Authorization": "Bearer owner",
}

# ── Built-in minimal HSK word map (fallback when --hsk-map not provided) ─────

_BUILTIN_HSK_MAP: dict[str, int] = {
    # HSK 1
    "你": 1, "好": 1, "我": 1, "是": 1, "的": 1, "了": 1, "在": 1,
    "有": 1, "不": 1, "人": 1, "他": 1, "她": 1, "们": 1, "这": 1,
    "那": 1, "什么": 1, "谁": 1, "哪": 1, "吗": 1, "呢": 1,
    "我们": 1, "你们": 1, "他们": 1, "她们": 1,
    "一": 1, "二": 1, "三": 1, "四": 1, "五": 1,
    "六": 1, "七": 1, "八": 1, "九": 1, "十": 1,
    "中国": 1, "汉语": 1, "学生": 1, "老师": 1, "朋友": 1,
    "吃": 1, "喝": 1, "去": 1, "来": 1, "看": 1, "听": 1, "说": 1,
    "大": 1, "小": 1, "多": 1, "少": 1, "好": 1, "很": 1,
    "今天": 1, "明天": 1, "昨天": 1, "年": 1, "月": 1, "日": 1,
    # HSK 2
    "但是": 2, "可以": 2, "因为": 2, "所以": 2, "虽然": 2,
    "知道": 2, "觉得": 2, "学习": 2, "工作": 2, "时间": 2,
    "喜欢": 2, "想": 2, "能": 2, "会": 2, "要": 2,
    "比较": 2, "非常": 2, "已经": 2, "还是": 2, "或者": 2,
    "生活": 2, "城市": 2, "问题": 2, "孩子": 2, "家庭": 2,
    "高兴": 2, "漂亮": 2, "便宜": 2, "贵": 2, "快": 2, "慢": 2,
    # HSK 3
    "机会": 3, "发现": 3, "经常": 3, "完成": 3, "建议": 3,
    "提高": 3, "培养": 3, "表示": 3, "影响": 3, "关系": 3,
    "情况": 3, "方面": 3, "重要": 3, "需要": 3, "应该": 3,
    "认为": 3, "发展": 3, "社会": 3, "文化": 3, "历史": 3,
    # HSK 4
    "即使": 4, "况且": 4, "并且": 4, "逐渐": 4, "程度": 4,
    "具体": 4, "保证": 4, "实现": 4, "推广": 4, "环境": 4,
    "经济": 4, "政治": 4, "科学": 4, "技术": 4, "教育": 4,
    # HSK 5
    "尽管": 5, "值得": 5, "承认": 5, "显然": 5, "确实": 5,
    "掌握": 5, "分析": 5, "归纳": 5, "评价": 5, "概念": 5,
    # HSK 6
    "势必": 6, "诚然": 6, "倘若": 6, "鉴于": 6, "固然": 6,
}


# ── Firestore REST encoding ───────────────────────────────────────────────────

def _encode_val(v: Any) -> dict:
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [_encode_val(i) for i in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: _encode_val(vv) for k, vv in v.items()}}}
    return {"stringValue": str(v)}


def _encode_fields(data: dict) -> dict:
    return {k: _encode_val(v) for k, v in data.items()}


# ── Emulator write ────────────────────────────────────────────────────────────

def write_to_emulator(collection: str, doc_id: str, data: dict) -> None:
    url = f"{FIRESTORE_BASE}/{collection}/{doc_id}"
    body = json.dumps({"fields": _encode_fields(data)})
    res = requests.patch(url, headers=HEADERS, data=body, timeout=10)
    if res.status_code >= 300:
        raise RuntimeError(
            f"Firestore write error {res.status_code}: {res.text[:200]}"
        )


def check_emulator_reachable() -> bool:
    try:
        r = requests.get(
            f"http://localhost:9299/v1/projects/demo-mandarin-academy"
            "/databases/(default)/documents/videos?pageSize=1",
            headers=HEADERS,
            timeout=3,
        )
        return r.status_code < 300
    except Exception:
        return False


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="YouTube URL → yt-dlp → Firestore Emulator"
    )
    parser.add_argument("--url", required=True, help="YouTube video URL")
    parser.add_argument(
        "--sub-file", type=Path,
        help="Local .vtt or .srt subtitle file (skips yt-dlp download)"
    )
    parser.add_argument(
        "--hsk-map", type=Path,
        help="JSON {word: level} map. If omitted, uses built-in map."
    )
    parser.add_argument(
        "--active", action="store_true",
        help="Set isActive=True on all segments (default: False)"
    )
    parser.add_argument("--min-sec", type=float, default=5.0)
    parser.add_argument("--max-sec", type=float, default=10.0)
    args = parser.parse_args()

    # Check emulator
    print("🔌 Checking Firestore emulator...")
    if not check_emulator_reachable():
        print(
            "❌ Cannot reach emulator at localhost:9299.\n"
            "   Start it with: firebase emulators:start --import=./emulator_data",
            file=sys.stderr,
        )
        sys.exit(1)
    print("   ✓ Emulator is running\n")

    # Load HSK map
    if args.hsk_map and args.hsk_map.exists():
        hsk_map: dict[str, int] = json.loads(
            args.hsk_map.read_text(encoding="utf-8")
        )
        print(f"📖 Loaded HSK map: {len(hsk_map)} words from {args.hsk_map}")
    else:
        hsk_map = _BUILTIN_HSK_MAP
        print(f"📖 Using built-in HSK map ({len(hsk_map)} words)")

    # Run pipeline to get segments as JSON
    import tempfile
    tmp_output = Path(tempfile.mktemp(suffix=".json"))

    print(f"🎬 Processing: {args.url}\n")
    try:
        mine_video(
            url=args.url,
            hsk_map=hsk_map,
            output_path=tmp_output,
            sub_file=args.sub_file,
            min_sec=args.min_sec,
            max_sec=args.max_sec,
        )
    except SystemExit:
        sys.exit(1)

    docs: list[dict] = json.loads(tmp_output.read_text(encoding="utf-8"))
    tmp_output.unlink(missing_ok=True)

    if not docs:
        print("⚠️  No segments produced. Check the video has Chinese subtitles.")
        sys.exit(1)

    # Write to emulator
    print(f"\n🔥 Writing {len(docs)} segments to Firestore emulator...")
    now_ts = datetime.now(timezone.utc).isoformat()
    success = 0
    errors = 0
    for doc in docs:
        doc_id = doc["videoId"]
        # Finalise fields
        doc["isActive"] = args.active
        doc["createdAt"] = now_ts
        # Remove None videoUrl to keep doc clean
        if doc.get("videoUrl") is None:
            doc.pop("videoUrl", None)
        try:
            write_to_emulator("videos", doc_id, doc)
            print(f"  ✓ {doc_id}")
            success += 1
        except RuntimeError as e:
            print(f"  ✗ {doc_id}: {e}", file=sys.stderr)
            errors += 1

    print(
        f"\n✅ Done! {success} segments written"
        + (f", {errors} errors" if errors else "")
    )
    print(
        f"   isActive={args.active} — "
        + ("all clips are LIVE" if args.active else
           "clips hidden until you toggle them ON in the admin panel")
    )
    print("   App: http://localhost:9300/admin")


if __name__ == "__main__":
    main()
