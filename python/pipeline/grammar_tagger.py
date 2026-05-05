"""
Grammar pattern tagger — maps a Chinese sentence to a QuizCategory.

Rule priority (first match wins):
  culture      → festival / history / food keywords
  conversation → daily greeting / request phrases
  grammar      → grammatical structures (把/被/虽然…etc.)
  listening    → question-ending particles / interrogative words
  characters   → very short text (≤5 chars, single-char focus)
  vocabulary   → default fallback
"""

from __future__ import annotations

import re

QUIZ_CATEGORY_VOCABULARY = "vocabulary"
QUIZ_CATEGORY_GRAMMAR = "grammar"
QUIZ_CATEGORY_LISTENING = "listening"
QUIZ_CATEGORY_CHARACTERS = "characters"
QUIZ_CATEGORY_CONVERSATION = "conversation"
QUIZ_CATEGORY_CULTURE = "culture"


_CULTURE_RE = re.compile(
    r"节日|春节|中秋|元宵|端午|清明|重阳|饺子|汤圆|月饼|"
    r"文化|历史|传统|习俗|民族|皇帝|朝代|古代|"
    r"长城|故宫|天安门|丝绸之路|"
    r"茶|功夫|太极|书法|国画|京剧|"
    r"孔子|老子|儒家|道家"
)

_CONVERSATION_RE = re.compile(
    r"你好|您好|谢谢|不客气|再见|对不起|没关系|不好意思|"
    r"请问|怎么样|我想要|麻烦你|可以吗|帮我|我需要|"
    r"早上好|晚上好|下午好|好久不见|初次见面"
)

_GRAMMAR_RE = re.compile(
    r"把[^。，]{1,15}(?:放|拿|给|带|交|写|打|叫)|"
    r"被[^。，]{1,10}(?:了|过|着)|"
    r"虽然.{1,20}但是|"
    r"不管.{1,15}都|"
    r"只要.{1,15}就|"
    r"如果.{1,15}就|"
    r"是.{1,10}的(?=[。，！？\s]|$)|"
    r"除了.{1,15}以外|"
    r"越来越|"
    r"一边.{1,10}一边|"
    r"先.{1,8}再.{1,8}然后|"
    r"比.{1,5}[更还]|"
    r"连.{1,5}都[不没]|"
    r"宁可.{1,15}也[不没]"
)

_LISTENING_RE = re.compile(
    r"[吗呢吧](?:[。？！]|$)|"
    r"为什么|什么时候|怎么[了回]|哪里|哪个|哪些|"
    r"谁的|几点|多少钱|多少人|有没有|是不是|"
    r"能不能|可不可以"
)


def tag_grammar(text: str) -> str:
    """Return the QuizCategory string that best describes the grammar in text."""
    clean = text.strip()

    # Characters: very short (≤5 Han chars), typically single-char exercises
    han_chars = re.sub(r"[^一-鿿]", "", clean)
    if len(han_chars) <= 5:
        return QUIZ_CATEGORY_CHARACTERS

    if _CULTURE_RE.search(clean):
        return QUIZ_CATEGORY_CULTURE
    if _CONVERSATION_RE.search(clean):
        return QUIZ_CATEGORY_CONVERSATION
    if _GRAMMAR_RE.search(clean):
        return QUIZ_CATEGORY_GRAMMAR
    if _LISTENING_RE.search(clean):
        return QUIZ_CATEGORY_LISTENING

    return QUIZ_CATEGORY_VOCABULARY
