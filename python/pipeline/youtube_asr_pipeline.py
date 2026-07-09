"""
YouTube ASR pipeline — yt-dlp audio + faster-whisper → Supabase production.

Tries caption download first (fast). Falls back to Whisper ASR for
burned-in subtitle videos.

Requires python/.env with:
    SUPABASE_URL=https://...
    SUPABASE_SERVICE_ROLE_KEY=eyJ...
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any, Callable

import requests

# ── .env loader ───────────────────────────────────────────────────────────────

def _load_dotenv() -> None:
    env_path = Path(__file__).parent.parent / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        os.environ.setdefault(key.strip(), val.strip())

_load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://pqyceostpukueydwuiut.supabase.co")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

# Anti-hallucination layer E: Gemini coherence gate. ON by default; set
# SINOMA_COHERENCE_GATE=0 to skip. Fail-open everywhere so it can only ever
# drop clear garbage, never silently lose a whole video.
COHERENCE_GATE = os.environ.get("SINOMA_COHERENCE_GATE", "1") != "0"


def gate_coherence(texts: list[str]) -> list[bool]:
    """Ask the gate-coherence edge function which segment texts are real spoken
    Mandarin (vs. hallucinated gibberish). Returns one keep-flag per text.
    Fail-open: any error/missing config keeps everything."""
    if not texts:
        return []
    if not COHERENCE_GATE or not SUPABASE_SERVICE_KEY:
        return [True] * len(texts)
    try:
        resp = requests.post(
            f"{SUPABASE_URL}/functions/v1/gate-coherence",
            json={"texts": texts},
            headers=_supabase_headers(),
            timeout=40,
        )
        if resp.status_code >= 300:
            return [True] * len(texts)
        keep = resp.json().get("keep", [])
        return [bool(keep[i]) if i < len(keep) else True for i in range(len(texts))]
    except Exception:
        return [True] * len(texts)


# ── HSK analysis via Supabase REST ───────────────────────────────────────────

def _supabase_headers() -> dict[str, str]:
    return {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
    }


def _extract_candidates(text: str) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for chunk in re.findall(r"[一-鿿]+", text):
        for i in range(len(chunk)):
            for length in range(1, min(5, len(chunk) - i + 1)):
                word = chunk[i : i + length]
                if word not in seen:
                    seen.add(word)
                    result.append(word)
    return result


def _query_dictionary(candidates: list[str]) -> list[dict[str, Any]]:
    """Batch-query Supabase dictionary for up to 100 candidates at a time.
    Retries per batch: a transient REST blip (ConnectionError / 5xx) used to
    propagate up and kill the WHOLE split job mid-video (EnyMsJwsy1k,
    2026-07-09); a batch that still fails after retries is skipped — its
    words just don't match, same as an unknown word."""
    if not candidates or not SUPABASE_SERVICE_KEY:
        return []
    rows: list[dict[str, Any]] = []
    batch_size = 100
    for i in range(0, len(candidates), batch_size):
        batch = candidates[i : i + batch_size]
        encoded = ",".join(batch)
        for attempt in range(3):
            try:
                resp = requests.get(
                    f"{SUPABASE_URL}/rest/v1/dictionary",
                    params={"simplified": f"in.({encoded})",
                            "select": "id,simplified,hsk_level"},
                    headers=_supabase_headers(),
                    timeout=30,
                )
                if resp.status_code < 300:
                    rows.extend(resp.json())
                    break
            except requests.RequestException as exc:
                if attempt == 2:
                    print(f"  [DICT] batch atlandı ({exc})")
            time.sleep(2 * (attempt + 1))
    return rows


def _segment_ordered(text: str, valid: set[str]) -> list[str]:
    """Greedy longest-match (≤4) left-to-right segmentation, falling back to a
    single character when no dictionary word matches. Same algorithm as the
    admin's segmentSentence so the imported word list is already clean and IN
    ORDER (join → the original sentence), not a scrambled n-gram dump."""
    result: list[str] = []
    i, n = 0, len(text)
    while i < n:
        chosen = text[i]
        for length in range(4, 1, -1):
            if i + length <= n and text[i : i + length] in valid:
                chosen = text[i : i + length]
                break
        result.append(chosen)
        i += len(chosen)
    return result


# ── Auto-classification (grammar + life topic) ────────────────────────────────
# Deterministic, no API. Grammar: surface-form triggers for the salient HSK
# grammar points (the ubiquitous 的/了/是/不 are skipped — they add no diversity).
# Ordered most-specific-first so nested patterns (怎么样 before 怎么) win; a matched
# trigger is consumed so the shorter one does not double-tag. Capped at 4.
_GRAMMAR_TRIGGERS: list[tuple[str, list[str]]] = [
    # connectors / complex sentences
    ("ruguo", ["如果"]), ("yaoshi", ["要是"]), ("jiaru", ["假如"]), ("wanyi", ["万一"]),
    ("fouze", ["否则"]), ("zhiyao", ["只要"]), ("zhiyou", ["只有"]), ("wulun", ["无论"]),
    ("buguan", ["不管"]), ("chufei", ["除非"]), ("yinwei", ["因为"]), ("suoyi", ["所以"]),
    ("jiran", ["既然"]), ("yinci", ["因此"]), ("suiran", ["虽然"]), ("danshi", ["但是", "可是"]),
    ("raner", ["然而"]), ("jishi", ["即使"]), ("napa", ["哪怕"]), ("jinguan", ["尽管"]),
    ("budan", ["不但"]), ("bujin", ["不仅"]), ("erqie", ["而且"]), ("shenzhi", ["甚至"]),
    ("huozhe", ["或者"]), ("yaome", ["要么"]), ("ranhou", ["然后"]), ("yushi", ["于是"]),
    ("yibian", ["一边"]), ("que", ["却"]),
    # special patterns / comparison
    ("yuelaiyue", ["越来越"]), ("genYiyang", ["一样"]), ("buru", ["不如"]),
    ("ba", ["把"]), ("bei", ["被"]), ("bijiao", ["比较"]), ("bi", ["比"]),
    # modal verbs
    ("yinggai", ["应该"]), ("xuyao", ["需要"]), ("bixu", ["必须"]), ("dasuan", ["打算"]),
    ("keyi", ["可以"]), ("hui", ["会"]), ("neng", ["能"]), ("yao", ["要"]),
    ("xiang", ["想"]), ("gan", ["敢"]),
    # question forms
    ("weishenme", ["为什么"]), ("zenmeyang", ["怎么样"]), ("zenme", ["怎么"]),
    ("haishi", ["还是"]), ("nandao", ["难道"]),
    # prepositions
    ("weile", ["为了"]), ("guanyu", ["关于"]), ("genju", ["根据"]), ("chule", ["除了"]),
    ("cong", ["从"]), ("gei", ["给"]), ("gen", ["跟"]), ("xiangPrep", ["向"]),
    ("li", ["离"]), ("lian", ["连"]), ("dui", ["对"]),
    # adverbs
    ("yizhi", ["一直"]), ("yijing", ["已经"]), ("changchang", ["常常", "经常"]),
    ("zhongyu", ["终于"]),
    ("cai", ["才"]), ("jiu", ["就"]), ("dou", ["都"]), ("zaiAgain", ["再"]),
    ("youAgain", ["又"]), ("tai", ["太"]), ("geng", ["更"]), ("zui", ["最"]),
    # aspect / complements / particles
    ("zhengzai", ["正在"]), ("qilai", ["起来"]), ("xiaqu", ["下去"]),
    ("guo", ["过"]), ("zhe", ["着"]), ("dehua", ["的话"]),
    ("ma", ["吗"]), ("ne", ["呢"]), ("baParticle", ["吧"]),
]

_LIFE_LEXICON: list[tuple[str, list[str]]] = [
    ("family", ["妈妈", "爸爸", "父母", "孩子", "儿子", "女儿", "家人", "家庭", "哥哥",
                "姐姐", "弟弟", "妹妹", "爷爷", "奶奶", "老婆", "老公", "丈夫", "妻子", "宝宝"]),
    ("food", ["吃", "喝", "饭", "菜", "餐厅", "饿", "味道", "好吃", "早餐", "午餐", "晚餐",
              "咖啡", "水果", "米饭", "点菜", "厨房", "做饭", "饮料"]),
    ("shopping", ["买", "卖", "商店", "超市", "价格", "多少钱", "便宜", "购物", "商场",
                  "打折", "付钱", "市场"]),
    ("travel", ["旅游", "旅行", "飞机", "机场", "酒店", "宾馆", "行李", "护照", "火车",
                "地铁", "公交", "车站", "出发", "景点", "导游", "签证"]),
    ("business", ["工作", "公司", "会议", "老板", "合同", "客户", "经理", "上班", "同事",
                  "办公室", "项目", "业务", "面试", "加班", "销售", "经济"]),
    ("school", ["学校", "老师", "学生", "考试", "作业", "上课", "学习", "大学", "同学",
                "教室", "成绩", "毕业", "专业", "图书馆"]),
    ("health", ["医生", "医院", "生病", "吃药", "身体", "健康", "感冒", "发烧", "看病",
                "护士", "受伤"]),
    ("technology", ["电脑", "手机", "网络", "软件", "网站", "科技", "技术", "互联网",
                    "程序", "数据", "应用", "电子", "系统", "科学", "研究"]),
    ("entertainment", ["电影", "音乐", "唱歌", "游戏", "电视", "节目", "明星", "演员",
                       "跳舞", "艺术", "小说", "演出", "娱乐"]),
    ("sports", ["足球", "篮球", "跑步", "游泳", "比赛", "锻炼", "健身", "体育", "冠军", "球队"]),
    ("children", ["小朋友", "玩具", "童话", "动画", "幼儿园", "小孩"]),
]


def classify_segment(text: str) -> tuple[list[str], list[str]]:
    """Return (grammar_categories, life_categories) auto-detected from the text.
    Multi-label; falls back to 'general' / 'daily_life' when nothing matches."""
    work = text
    grammar: list[str] = []
    for name, triggers in _GRAMMAR_TRIGGERS:
        for t in triggers:
            if t and t in work:
                grammar.append(name)
                work = work.replace(t, " ", 1)
                break
        if len(grammar) >= 4:
            break
    if not grammar:
        grammar = ["general"]

    life: list[str] = []
    for name, kws in _LIFE_LEXICON:
        if any(k in text for k in kws):
            life.append(name)
        if len(life) >= 3:
            break
    if not life:
        life = ["daily_life"]
    return grammar, life


def analyze_segment(text: str) -> tuple[list[str], int]:
    """Return (words, hsk_level): a clean IN-ORDER word segmentation of the
    sentence plus its HSK level (0 = no dictionary match → caller drops it)."""
    candidates = _extract_candidates(text)
    if not candidates:
        return [], 0
    rows = _query_dictionary(candidates)
    # Deterministic per-word level: a homograph can have several dictionary rows
    # with different hsk_level; take the lowest positive one (the level the word
    # is first taught at) instead of whichever row arrived last.
    valid: dict[str, int] = {}
    for r in rows:
        s = r.get("simplified")
        if not s:
            continue
        lvl = r.get("hsk_level") or 0
        cur = valid.get(s)
        if cur is None or (lvl and (cur == 0 or lvl < cur)):
            valid[s] = lvl
    if not valid:
        return [], 0
    words = _segment_ordered(text, set(valid.keys()))
    levels = [valid[w] for w in words if valid.get(w)]
    hsk_level = min(6, max(1, max(levels))) if levels else 0
    return words, hsk_level


# ── Supabase insert ───────────────────────────────────────────────────────────

def insert_segments(rows: list[dict[str, Any]]) -> None:
    # Retry transient network drops (e.g. "Connection aborted / RemoteDisconnected"
    # mid-stream) so one hiccup doesn't fail the whole job and force a re-run.
    last = ""
    for attempt in range(4):
        try:
            resp = requests.post(
                f"{SUPABASE_URL}/rest/v1/videos",
                json=rows,
                headers={**_supabase_headers(), "Prefer": "return=minimal"},
                timeout=60,
            )
            if resp.status_code < 300:
                return
            last = f"Supabase insert failed {resp.status_code}: {resp.text[:200]}"
            if resp.status_code < 500:
                raise RuntimeError(last)  # client error — won't fix on retry
        except requests.exceptions.RequestException as exc:
            last = f"insert network error: {exc}"
        import time as _t
        _t.sleep(0.6 * (attempt + 1))
    raise RuntimeError(last or "Supabase insert failed")


def _delete_pending_for(youtube_id: str) -> None:
    """Clear this video's previous PENDING segments before a (re)run so a retried
    job never piles up duplicates. Active/approved clips are kept."""
    if not youtube_id or youtube_id == "unknown":
        return
    try:
        requests.delete(
            f"{SUPABASE_URL}/rest/v1/videos",
            params={"youtube_id": f"eq.{youtube_id}", "status": "eq.pending"},
            headers={**_supabase_headers(), "Prefer": "return=minimal"},
            timeout=30,
        )
    except Exception:
        pass


# ── Main pipeline ─────────────────────────────────────────────────────────────

def run(
    url: str,
    active: bool = False,
    hsk_filter: list[int] | None = None,
    word_filter: list[str] | None = None,
    grammar_filter: list[str] | None = None,
    on_progress: Callable[..., None] | None = None,
) -> dict[str, Any]:
    """Full pipeline: YouTube URL → audio → Whisper → Supabase.

    Returns {"segmentsWritten": N, "method": "subtitles"|"whisper"}.
    hsk_filter: if set, only segments whose hsk_level is in this list are inserted.
    word_filter / grammar_filter: criterion pre-filter. After the path trigger
    assigns each clip a CRITERION (slot_word / slot_grammar, or its backup_*
    equivalent), clips whose criterion is not in the selected words/grammars are
    dropped. So selecting only some HSK-1 words yields ONLY clips whose teaching
    item is one of those words — clips whose highest-level criterion sits at
    another level are never kept. Applied server-side (robust regardless of
    whether the admin tab stays open) right before the per-clip whisper fill, so
    no whisper work is spent on clips that will be dropped.
    """
    if not SUPABASE_SERVICE_KEY:
        raise RuntimeError(
            "SUPABASE_SERVICE_ROLE_KEY ayarlı değil.\n"
            "python/.env dosyasına SUPABASE_SERVICE_ROLE_KEY= satırı ekleyin.\n"
            "(Supabase Dashboard → Settings → API → Service role key)"
        )

    import tempfile
    from youtube_miner import (
        download_audio,
        download_subtitles,
        parse_subtitle_file,
        build_segments,
        stream_segments,
        iter_whisper_cues,
        extract_youtube_id,
        normalize_youtube_url,
    )
    from pinyin_helper import get_pinyin

    url = normalize_youtube_url(url)
    youtube_id = extract_youtube_id(url)
    print(f"\n▶ YouTube ASR pipeline: {url} ({youtube_id})")

    # Idempotent (re)run: drop any leftover PENDING segments of this video first,
    # so a retried/re-queued job never produces duplicate clips.
    _delete_pending_for(youtube_id)

    method = "subtitles"
    inserted = 0
    matched = 0  # segments seen that matched the dictionary (before filter)
    gated = 0    # segments dropped by the coherence gate (layer E)
    seg_seen = 0
    duration_sec = 0.0  # total audio length (Whisper), for the admin ETA
    last_pos = 0.0      # latest segment end-time = how far ASR has progressed
    buf: list[dict[str, Any]] = []
    emitted_texts: set[str] = set()  # drop repeat clips (same line said twice)

    def _report() -> None:
        # Two-arg progress: count + meta (duration + audio position) so the admin
        # can show a real countdown ETA instead of a count-up timer.
        if on_progress:
            on_progress(inserted, {"durationSec": round(duration_sec, 1),
                                   "lastPos": round(last_pos, 1)})

    def _set_meta(meta: dict[str, Any]) -> None:
        nonlocal duration_sec
        duration_sec = float(meta.get("durationSec") or 0.0)
        _report()  # surface the ETA basis immediately, before the first segment

    def _flush(force: bool = False) -> None:
        nonlocal inserted, buf, gated
        if buf and (force or len(buf) >= 5):
            keep = gate_coherence([r["transcription"] for r in buf])
            kept = [r for r, k in zip(buf, keep) if k]
            gated += len(buf) - len(kept)
            buf = []
            if kept:
                insert_segments(kept)
                inserted += len(kept)
                print(f"  ✓ {inserted} segment yazıldı (akışlı)")
                _report()

    def _emit(seg: dict[str, Any]) -> None:
        nonlocal seg_seen, matched, last_pos
        seg_seen += 1
        last_pos = max(last_pos, float(seg["end"]))
        word_ids, hsk_level = analyze_segment(seg["text"])
        # Guard: target_words must be Chinese only — never let a stray pinyin/latin
        # token through (it pollutes the word chips + the admin title built from them).
        word_ids = [w for w in word_ids
                    if w and not re.search(r"[A-Za-zÀ-ÖØ-öø-ÿĀ-ɏ]", w)]
        if hsk_level == 0:
            return
        matched += 1
        if hsk_filter and hsk_level not in hsk_filter:
            return
        norm = re.sub(r"\s+", "", seg["text"])
        if norm in emitted_texts:
            return  # identical transcription already imported — skip the dupe
        emitted_texts.add(norm)
        grammar, life = classify_segment(seg["text"])
        buf.append({
            "source_type": "youtube",
            "youtube_id": youtube_id,
            "start_time": seg["start"],
            "end_time": seg["end"],
            "transcription": seg["text"],
            "pinyin": get_pinyin(seg["text"]),
            "hsk_level": hsk_level,
            "hsk_levels": [hsk_level],
            "target_words": word_ids,
            "quiz_category": grammar[0],
            "quiz_categories": grammar,
            "life_category": life[0],
            "life_categories": life,
            "quiz": {"question": "", "correctAnswer": "", "wrongAnswer": ""},
            "is_active": active,
        })
        _flush()

    # Stream: segments are analysed + inserted AS they close, so they appear in
    # the "pending" tab progressively instead of all at once at the end. Works
    # for hour-long videos (no in-memory accumulation, no single huge insert).
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)

        print("  Önce altyazı deneniyor…")
        sub_path = download_subtitles(url, tmp)
        if sub_path:
            print(f"  Altyazı bulundu: {sub_path.name}")
            entries = parse_subtitle_file(sub_path)
            print(f"  {len(entries)} cue → akışlı segmentleme…")
            for seg in stream_segments(entries):
                _emit(seg)
        else:
            method = "whisper"
            print("  Altyazı yok → ses indiriliyor (Whisper ASR)…")
            audio_path = download_audio(url, tmp)
            size_kb = audio_path.stat().st_size // 1024
            # Keep the audio so the whisper_text fill below reuses it (no re-download).
            try:
                import shutil as _sh
                _sh.copy(str(audio_path), str(_audio_cache_path(youtube_id)))
            except Exception:
                pass
            print(f"  Ses: {audio_path.name} ({size_kb} KB) — akışlı transkripsiyon…")
            for seg in stream_segments(iter_whisper_cues(audio_path, on_meta=_set_meta)):
                _emit(seg)

    _flush(force=True)

    if gated:
        print(f"  ⚠ {gated} segment tutarlılık kapısında elendi (halüsinasyon)")
    if seg_seen == 0:
        raise RuntimeError(
            "Segment oluşturulamadı — video Mandarin içermiyor veya ses/altyazı yetersiz."
        )
    if inserted == 0:
        raise RuntimeError(
            "Hiçbir segment yazılamadı — sözlük eşleşmesi yok, HSK filtresi dışı, "
            "veya tutarlılık kapısı hepsini halüsinasyon saydı. Filtreyi değiştirin."
        )

    # Before the clips sit in "pending": (1) auto-fill whisper_text for each so the
    # admin sees ASR + an independent Whisper transcription side by side, and
    # (2) drop any clip Whisper found silent (no real dialogue — a caption artifact
    # or music). This is what keeps "no-dialogue" clips out of the review queue.
    dropped_ns = 0
    dropped_dup = 0
    dropped_unplaced = 0
    dropped_crit = 0
    try:
        # Criterion filter first (before the costly per-clip whisper): keep only
        # clips whose assigned teaching item is one of the selected words/grammars.
        dropped_crit = _drop_non_criteria_pending(youtube_id, word_filter, grammar_filter)
        fill_whisper_text(youtube_id, url)
        dropped_ns = _drop_no_speech_pending(youtube_id)
        # Every import: drop clips that already exist as an ACTIVE video.
        dropped_dup = _drop_active_duplicates(youtube_id)
        # Repeated lines / particle variants (我要怎么做呢 vs 我要怎么做).
        dropped_dup += _drop_text_duplicates(youtube_id)
        # Every import: drop clips that couldn't be placed in ANY slot (redundant).
        dropped_unplaced = _drop_unplaced_pending(youtube_id)
    except Exception as exc:
        print(f"  [WHISPER-FILL] atlandı: {exc}")
    return {"segmentsWritten":
                inserted - dropped_ns - dropped_dup - dropped_unplaced - dropped_crit,
            "method": method, "gatedOut": gated, "droppedNoSpeech": dropped_ns,
            "droppedDuplicates": dropped_dup, "droppedUnplaced": dropped_unplaced,
            "droppedCriterion": dropped_crit}


def _audio_cache_path(youtube_id: str) -> Path:
    import tempfile
    d = Path(tempfile.gettempdir()) / "sinoma_audio_cache"
    d.mkdir(parents=True, exist_ok=True)
    return d / f"{youtube_id}.mp4"


# One loaded Whisper model reused across every clip of a fill/backfill run.
_WHISPER_MODEL = None


def _get_whisper_model():
    global _WHISPER_MODEL
    if _WHISPER_MODEL is None:
        from faster_whisper import WhisperModel
        from youtube_miner import WHISPER_MODEL_SIZE
        print(f"  [ASR] Whisper '{WHISPER_MODEL_SIZE}' yükleniyor…")
        _WHISPER_MODEL = WhisperModel(
            WHISPER_MODEL_SIZE, device="cpu", compute_type="int8")
    return _WHISPER_MODEL


def _whisper_window(model, audio, sr: int, start: float, end: float) -> str:
    """Whisper-transcribe ONLY [start,end] of an already-decoded audio array;
    return cleaned Simplified text ('' for music / silence / boilerplate)."""
    from youtube_miner import (
        WHISPER_CLIP_KWARGS, _to_simplified, is_whisper_hallucination,
        is_repetition_hallucination,
    )
    # Pad the window slightly — caption/segment boundaries often clip the first or
    # last syllable.
    pad = int(0.4 * sr)
    a = max(0, int(start * sr) - pad)
    b = min(len(audio), int(end * sr) + pad)
    clip = audio[a:b] if b > a else audio
    # VAD-off, lenient kwargs: this window is a KNOWN speech region (from a caption),
    # so only reject near-certain silence — keep music-bedded real dialogue.
    segments, _ = model.transcribe(clip, **WHISPER_CLIP_KWARGS)
    parts = []
    for s in segments:
        if getattr(s, "no_speech_prob", 0.0) > 0.85:
            continue
        if any("一" <= ch <= "鿿" for ch in s.text):
            parts.append(s.text)
    text = _to_simplified(re.sub(r"\s+", "", "".join(parts).strip()))
    # Repetition hallucination over non-speech is NOT real dialogue → empty so the
    # clip is dropped as no-speech.
    if is_repetition_hallucination(text):
        return ""
    return "" if is_whisper_hallucination(text) else text


def _ensure_cached_audio(youtube_id: str, url: str) -> Path:
    import shutil
    import tempfile
    from youtube_miner import download_audio
    cache = _audio_cache_path(youtube_id)
    if not cache.exists():
        with tempfile.TemporaryDirectory() as td:
            ap = download_audio(url, Path(td))
            shutil.copy(str(ap), str(cache))
    return cache


def fill_whisper_text(
    youtube_id: str,
    url: str,
    force: bool = False,
    on_progress: Callable[[int], None] | None = None,
) -> int:
    """For every PENDING clip of this video, run Whisper on its [start,end] window
    and store videos.whisper_text — so the admin sees BOTH the ASR/auto-caption
    transcription and an independent Whisper one side by side, without clicking.
    One audio download + one model load per video, reused across all its clips."""
    from faster_whisper.audio import decode_audio
    resp = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"youtube_id": f"eq.{youtube_id}", "status": "eq.pending",
                "select": "id,start_time,end_time,whisper_text",
                "order": "start_time.asc"},
        headers=_supabase_headers(), timeout=30,
    )
    rows = resp.json() if resp.status_code < 300 else []
    if not force:
        rows = [r for r in rows if not (r.get("whisper_text") or "").strip()]
    if not rows:
        return 0
    cache = _ensure_cached_audio(youtube_id, url)
    audio = decode_audio(str(cache))
    sr = 16000
    model = _get_whisper_model()
    print(f"  [WHISPER-FILL] {youtube_id}: {len(rows)} klip için whisper_text…")
    filled = 0
    for r in rows:
        text = _whisper_window(model, audio, sr,
                               float(r["start_time"]), float(r["end_time"]))
        requests.patch(
            f"{SUPABASE_URL}/rest/v1/videos",
            params={"id": f"eq.{r['id']}"},
            json={"whisper_text": text},
            headers=_supabase_headers(), timeout=15,
        )
        filled += 1
        if on_progress:
            on_progress(filled)
    print(f"  [WHISPER-FILL] ✓ {filled} whisper_text yazıldı ({youtube_id})")
    return filled


def _drop_non_criteria_pending(
    youtube_id: str,
    word_filter: list[str] | None,
    grammar_filter: list[str] | None,
) -> int:
    """Criterion filter. When word_filter and/or grammar_filter is set, delete this
    video's PENDING clips whose ASSIGNED criterion is none of the selected items.
    The criterion is what the path trigger pinned the clip through: slot_word /
    slot_grammar (placed) or backup_word / backup_grammar (backup). A clip is kept
    iff its slot/backup word is in word_filter OR its slot/backup grammar is in
    grammar_filter. This is stricter than "contains the word": a sentence merely
    mentioning a selected word but taught through a different (higher-level)
    criterion is dropped — so picking HSK-1 words never yields other-level clips."""
    wf = set(word_filter or ())
    gf = set(grammar_filter or ())
    if not wf and not gf:
        return 0
    resp = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"youtube_id": f"eq.{youtube_id}", "status": "eq.pending",
                "select": "id,slot_word,slot_grammar,backup_word,backup_grammar"},
        headers=_supabase_headers(), timeout=30,
    )
    rows = resp.json() if resp.status_code < 300 else []
    ids = []
    for r in rows:
        word = r.get("slot_word") or r.get("backup_word")
        gram = r.get("slot_grammar") or r.get("backup_grammar")
        keep = (word is not None and word in wf) or (gram is not None and gram in gf)
        if not keep:
            ids.append(r["id"])
    for cid in ids:
        requests.delete(
            f"{SUPABASE_URL}/rest/v1/videos",
            params={"id": f"eq.{cid}"}, headers=_supabase_headers(), timeout=15)
    if ids:
        print(f"  [CRITERION] {len(ids)} klip kriter-dışı silindi ({youtube_id})")
    return len(ids)


def _drop_unplaced_pending(youtube_id: str) -> int:
    """Delete this video's PENDING clips that the path trigger left UNPLACED — no
    level AND no backup. That happens only when EVERY teaching slot the clip could
    fill (its grammar(s) and word(s) at its level) is already taken by another
    active/pending clip, i.e. the clip is fully redundant. There is no slot to
    review it for, so it should not sit in the pending queue at all."""
    resp = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"youtube_id": f"eq.{youtube_id}", "status": "eq.pending",
                "select": "id,level,backup_level"},
        headers=_supabase_headers(), timeout=30,
    )
    rows = resp.json() if resp.status_code < 300 else []
    ids = [r["id"] for r in rows
           if r.get("level") is None and r.get("backup_level") is None]
    for cid in ids:
        requests.delete(
            f"{SUPABASE_URL}/rest/v1/videos",
            params={"id": f"eq.{cid}"}, headers=_supabase_headers(), timeout=15)
    if ids:
        print(f"  [UNPLACED] {len(ids)} yerleşemeyen (her slotu dolu) klip silindi ({youtube_id})")
    return len(ids)


def _drop_no_speech_pending(youtube_id: str) -> int:
    """Delete this video's PENDING clips where the (VAD-off) Whisper found NO
    speech at all — empty whisper_text means the audio in that window is music /
    silence with no real dialogue, so the caption was an artifact. These must not
    reach the review queue."""
    resp = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"youtube_id": f"eq.{youtube_id}", "status": "eq.pending",
                "select": "id,whisper_text"},
        headers=_supabase_headers(), timeout=30,
    )
    rows = resp.json() if resp.status_code < 300 else []
    ids = [r["id"] for r in rows if not (r.get("whisper_text") or "").strip()]
    for cid in ids:
        requests.delete(
            f"{SUPABASE_URL}/rest/v1/videos",
            params={"id": f"eq.{cid}"}, headers=_supabase_headers(), timeout=15)
    if ids:
        print(f"  [NO-SPEECH] {len(ids)} diyalogsuz klip silindi ({youtube_id})")
    return len(ids)


def _drop_active_duplicates(youtube_id: str) -> int:
    """Delete this video's PENDING clips that cover the same spoken moment as an
    ALREADY-ACTIVE clip. Re-importing re-segments the audio, so the copy may have
    slightly shifted boundaries / a trimmed prefix (842.6-848.6 '同学们你们…' active
    vs 843.0-851.2 '你们…' pending). Matching on TIME OVERLAP (>50% of the shorter
    clip) catches these near-duplicates that an exact transcription match misses —
    keeping them as backup has no value, so they are removed outright."""
    ra = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"youtube_id": f"eq.{youtube_id}", "status": "eq.active",
                "select": "start_time,end_time"},
        headers=_supabase_headers(), timeout=30,
    )
    actives = [(float(r["start_time"]), float(r["end_time"]))
               for r in (ra.json() if ra.status_code < 300 else [])]
    if not actives:
        return 0
    rp = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"youtube_id": f"eq.{youtube_id}", "status": "eq.pending",
                "select": "id,start_time,end_time"},
        headers=_supabase_headers(), timeout=30,
    )
    ids = []
    for r in (rp.json() if rp.status_code < 300 else []):
        ps, pe = float(r["start_time"]), float(r["end_time"])
        for a_s, a_e in actives:
            overlap = min(a_e, pe) - max(a_s, ps)
            if overlap > 0.5 * min(a_e - a_s, pe - ps):
                ids.append(r["id"])
                break
    for cid in ids:
        requests.delete(
            f"{SUPABASE_URL}/rest/v1/videos",
            params={"id": f"eq.{cid}"}, headers=_supabase_headers(), timeout=15)
    if ids:
        print(f"  [DEDUP] {len(ids)} aktif-kopyası pending klip silindi ({youtube_id})")
    return len(ids)


# "Temelde aynı" cümleler: sadece noktalama ya da cümle-sonu edatı farklı olan
# klipler (我要怎么做呢 vs 我要怎么做) ayrı klip olmamalı — Berkay 2026-07-08.
_TRAILING_PARTICLES = "呢吧啊吗呀哦啦嘛哈嘞喽"


def _norm_sentence(t: str) -> str:
    s = re.sub(r"[^一-鿿]", "", t or "")
    return s.rstrip(_TRAILING_PARTICLES)


def _drop_text_duplicates(youtube_id: str) -> int:
    """A speaker repeating a line (or ASR variants of it) yields near-identical
    clips at different timestamps that time-overlap dedup can't see. Normalize
    (CJK only, trailing particles stripped) and keep only the FIRST pending
    occurrence; also drop a pending whose normalized sentence already exists
    as an ACTIVE clip in ANY video — the feed shouldn't teach the same
    sentence twice."""
    ra = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"status": "eq.active", "select": "transcription"},
        headers=_supabase_headers(), timeout=30,
    )
    active_norm = {_norm_sentence(r.get("transcription", ""))
                   for r in (ra.json() if ra.status_code < 300 else [])}
    active_norm.discard("")
    rp = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"youtube_id": f"eq.{youtube_id}", "status": "eq.pending",
                "select": "id,start_time,transcription",
                "order": "start_time.asc"},
        headers=_supabase_headers(), timeout=30,
    )
    seen: set[str] = set()
    ids = []
    for r in (rp.json() if rp.status_code < 300 else []):
        n = _norm_sentence(r.get("transcription", ""))
        if len(n) < 3:
            continue
        if n in seen or n in active_norm:
            ids.append(r["id"])
        else:
            seen.add(n)
    for cid in ids:
        requests.delete(
            f"{SUPABASE_URL}/rest/v1/videos",
            params={"id": f"eq.{cid}"}, headers=_supabase_headers(), timeout=15)
    if ids:
        print(f"  [DEDUP] {len(ids)} tekrar-cümleli pending klip silindi ({youtube_id})")
    return len(ids)


def backfill_pending_whisper(force: bool = False) -> dict[str, Any]:
    """Fill whisper_text for ALL current pending YouTube clips (every distinct
    video). Applies the auto-Whisper to clips imported before it existed."""
    resp = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"status": "eq.pending", "source_type": "eq.youtube",
                "select": "youtube_id"},
        headers=_supabase_headers(), timeout=30,
    )
    ids = sorted({r["youtube_id"] for r in resp.json()}) if resp.status_code < 300 else []
    print(f"  [WHISPER-FILL] {len(ids)} bekleyen video taranıyor…")
    total = 0
    for yid in ids:
        try:
            total += fill_whisper_text(
                yid, f"https://www.youtube.com/watch?v={yid}", force=force)
        except Exception as exc:
            print(f"  [WHISPER-FILL] {yid} atlandı: {exc}")
    return {"videos": len(ids), "filled": total}


def transcribe_clip(
    url: str,
    start: float,
    end: float,
    row_id: str,
    on_progress: Callable[[int], None] | None = None,
) -> dict[str, Any]:
    """Whisper-transcribe ONLY the [start, end] window of the clip (not the whole
    video) and write videos.whisper_text for that one row. The full audio is
    cached per youtube_id so repeated clips of the same video are fast."""
    if not SUPABASE_SERVICE_KEY:
        raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY ayarlı değil.")

    from faster_whisper.audio import decode_audio
    from youtube_miner import extract_youtube_id, normalize_youtube_url

    url = normalize_youtube_url(url)
    youtube_id = extract_youtube_id(url)
    print(f"\n▶ Whisper clip {start:.1f}-{end:.1f}s: {youtube_id} (row {row_id[:8]})")

    cache = _ensure_cached_audio(youtube_id, url)
    audio = decode_audio(str(cache))  # 16kHz mono float32, no ffmpeg (PyAV)
    sr = 16000
    if on_progress:
        on_progress(1)

    model = _get_whisper_model()
    text = _whisper_window(model, audio, sr, start, end)

    requests.patch(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"id": f"eq.{row_id}"},
        json={"whisper_text": text},
        headers=_supabase_headers(),
        timeout=15,
    )
    print(f"  ✓ whisper_text yazıldı: {text[:40]}")
    return {"whisper_text": text}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--active", action="store_true")
    args = parser.parse_args()
    result = run(args.url, active=args.active)
    print(json.dumps(result, ensure_ascii=False))
