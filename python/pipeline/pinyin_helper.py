"""Pinyin generation wrapper around pypinyin."""

from __future__ import annotations

from pypinyin import Style, lazy_pinyin


def get_pinyin(text: str) -> str:
    """Return space-separated tone-marked pinyin for a Chinese string."""
    return " ".join(lazy_pinyin(text, style=Style.TONE))
