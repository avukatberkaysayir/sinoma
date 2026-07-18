# -*- coding: utf-8 -*-
"""Fix Whisper homophone errors from a video's burned-in subtitles.

Whisper transcribes by sound, so it picks the wrong same-sound character often
enough to matter: 找不着 (zhǎo bù zháo, "can't find") where the burned-in caption
reads 招不招 (zhāo bù zhāo, "confess or not"). The caption on screen is the
authored text — trust it over the ASR when, and only when, the two agree by
sound but differ in writing.

The rule is deliberately narrow (Berkay chose the strict variant, 2026-07-17):
align the two strings, and inside the aligned region replace a Whisper character
with the OCR one ONLY when their toneless pinyin is identical. Everything the OCR
did not cover is left untouched — a caption shows one line while a Whisper
segment may span several, so the OCR text is usually a *subset*, and replacing
wholesale would delete the rest of the sentence.
"""
from __future__ import annotations

import difflib
import re

try:
    from pypinyin import lazy_pinyin
    _PY_OK = True
except ImportError:  # pragma: no cover - pypinyin ships with the pipeline
    _PY_OK = False

try:
    import jieba
    jieba.initialize()
    _FREQ = jieba.dt.FREQ
except Exception:  # pragma: no cover
    _FREQ = {}

_HAN = re.compile(r"[一-鿿]")

# A real word the OCR change would DESTROY vetoes the change: 逐渐 (freq 7853)
# must never become 逐奸 (freq 0) just because jiàn==jiān. Tuned to the measured
# split — genuine fixes sit at 0-on-the-Whisper-side (割杀无论→格杀勿论 is 0→40),
# so any common Whisper word above this is the ASR being right and the OCR wrong.
_WORD_VETO_FREQ = 200


def _best_word_freq(text: str, lo: int, hi: int) -> int:
    """Highest jieba frequency of any 2-4 char word that covers [lo, hi)."""
    best = 0
    n = len(text)
    for L in (2, 3, 4):
        for s in range(max(0, hi - L), min(lo, n - L) + 1):
            best = max(best, _FREQ.get(text[s:s + L], 0))
    return best


def _han_only(s: str) -> str:
    return "".join(_HAN.findall(s or ""))


def _toneless(chars: str) -> list[str]:
    # One pinyin syllable per hanzi, no tone marks. lazy_pinyin already drops
    # tones; strip any stray digits just in case a backend returns them.
    return [re.sub(r"\d", "", p) for p in lazy_pinyin(chars)] if chars else []


def homophone_fix(whisper: str, ocr: str) -> tuple[str, list[tuple[str, str]]]:
    """Return (corrected_whisper, [(from, to), ...]).

    Only same-sound / different-character substitutions inside the aligned
    region are applied. Punctuation and any span the OCR did not reach are kept
    exactly. If nothing qualifies, the original string comes back unchanged.
    """
    if not _PY_OK or not whisper or not ocr:
        return whisper, []

    w_h = _han_only(whisper)
    o_h = _han_only(ocr)
    if len(w_h) < 2 or len(o_h) < 2:
        return whisper, []

    w_py = _toneless(w_h)
    o_py = _toneless(o_h)

    # Map each hanzi position in w_h back to its index in the full string, so a
    # replacement lands on the right character and leaves punctuation alone.
    han_pos = [i for i, ch in enumerate(whisper) if _HAN.match(ch)]

    sm = difflib.SequenceMatcher(a=w_h, b=o_h, autojunk=False)
    out = list(whisper)
    subs: list[tuple[str, str]] = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        # A homophone slip shows up as an equal-length 'replace' block where
        # each Whisper char has the same sound as the OCR char facing it.
        if tag != "replace" or (i2 - i1) != (j2 - j1):
            continue
        block: list[tuple[int, int]] = []
        for k in range(i2 - i1):
            wi, oj = i1 + k, j1 + k
            if not w_py[wi] or w_py[wi] != o_py[oj]:
                continue  # different sound → not a homophone, leave it
            if w_h[wi] == o_h[oj]:
                continue  # same char already
            block.append((wi, oj))
        if not block:
            continue
        # Word veto: if the OCR change would break a common Whisper word, the ASR
        # was right and the OCR misread. Compare the strongest word covering the
        # block on each side; veto when the Whisper side is common and the OCR
        # side is weaker.
        lo, hi = block[0][0], block[-1][0] + 1
        w_freq = _best_word_freq(w_h, lo, hi)
        o_side = w_h[:lo] + "".join(o_h[oj] for _, oj in block) + w_h[hi:]
        o_freq = _best_word_freq(o_side, lo, hi)
        if w_freq >= _WORD_VETO_FREQ and w_freq > o_freq:
            continue  # keep Whisper — 逐渐 must not become 逐奸
        for wi, oj in block:
            out[han_pos[wi]] = o_h[oj]
            subs.append((w_h[wi], o_h[oj]))

    return ("".join(out), subs) if subs else (whisper, [])
