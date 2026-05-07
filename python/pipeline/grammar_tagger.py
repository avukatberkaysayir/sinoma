"""
Chinese Grammar Pattern Tagger — VoScreen voStructure equivalent for Mandarin.

Maps a Chinese sentence to one of the grammar pattern categories below.
Priority order: first match wins. Patterns are ordered from most specific
to most general to avoid false positives.

Categories (maps to QuizCategory enum in Flutter):
  baConstruct     — 把字句  (把 disposal construction)
  beiPassive      — 被动句  (被 passive voice)
  shiDeEmphasis   — 是…的  (emphasis/focus construction)
  conditional     — 如果/要是/假如…就  (if-then)
  contrast        — 虽然/尽管…但是/却  (although-but)
  causeEffect     — 因为/由于…所以/因此  (cause-effect)
  guoExperience   — 过  (experiential aspect)
  biComparison    — 比/没有…那么/跟…一样  (comparison)
  huiNengKeyi     — 会/能/可以  (ability / permission / possibility)
  yingDeiYao      — 应该/得/要/必须  (should / must / need to)
  xiangDasuan     — 想/打算/希望/准备  (want to / plan to)
  questions       — 吗/呢/吧/为什么/怎么  (questions)
  leCompletion    — 了  (completion / change of state)
  negation        — 不/没  (negation)
  timeWords       — 时候/以后/之前/刚/马上  (time expressions)
  locationWords   — 在…上/下/里/从…到  (location / direction)
  general         — fallback
"""

from __future__ import annotations

import re

# ── Category constants (must match QuizCategory enum names in Dart) ───────────

BA_CONSTRUCT    = "baConstruct"
BEI_PASSIVE     = "beiPassive"
SHI_DE          = "shiDeEmphasis"
CONDITIONAL     = "conditional"
CONTRAST        = "contrast"
CAUSE_EFFECT    = "causeEffect"
GUO_EXPERIENCE  = "guoExperience"
BI_COMPARISON   = "biComparison"
HUI_NENG_KEYI   = "huiNengKeyi"
YING_DEI_YAO    = "yingDeiYao"
XIANG_DASUAN    = "xiangDasuan"
QUESTIONS       = "questions"
LE_COMPLETION   = "leCompletion"
NEGATION        = "negation"
TIME_WORDS      = "timeWords"
LOCATION_WORDS  = "locationWords"
GENERAL         = "general"


# ── Compiled patterns (ordered by specificity) ────────────────────────────────

_RULES: list[tuple[re.Pattern, str]] = [

    # 1. 把字句 — disposal construction
    (re.compile(
        r"把[^。，！？\n]{1,15}(?:放|拿|给|带|交|写|打|叫|推|拉|扔|送|告诉|说|当|变成|做成)"
    ), BA_CONSTRUCT),

    # 2. 被动句 — passive voice
    (re.compile(
        r"被[^。，！？\n]{1,15}(?:了|过|着|打|骗|选|抓|带|送|叫|称为)|"
        r"让[^，。！？\n]{0,8}(?:我|你|他|她|它|我们|你们|他们)(?:来|去|做|买|拿|说|写)"
    ), BEI_PASSIVE),

    # 3. 是…的 — emphasis / focus
    (re.compile(
        r"是[^。，！？\n]{2,20}的(?=[。！？\s]|$)"
    ), SHI_DE),

    # 4. 条件句 — conditional (if-then)
    (re.compile(
        r"如果[^，。！？\n]{2,20}就|"
        r"要是[^，。！？\n]{2,20}就|"
        r"假如[^，。！？\n]{2,20}就|"
        r"万一[^，。！？\n]{2,20}就|"
        r"一旦[^，。！？\n]{2,20}就|"
        r"只要[^，。！？\n]{2,20}就|"
        r"只有[^，。！？\n]{2,20}才"
    ), CONDITIONAL),

    # 5. 转折句 — contrast / concession
    (re.compile(
        r"虽然[^，。！？\n]{2,20}但[是]?|"
        r"尽管[^，。！？\n]{2,20}但[是]?|"
        r"即使[^，。！？\n]{2,20}也|"
        r"不管[^，。！？\n]{2,20}都|"
        r"不过[^，。！？\n]{2,15}|"
        r"然而[^，。！？\n]{2,15}|"
        r"却[^，。！？\n]{1,15}"
    ), CONTRAST),

    # 6. 因果句 — cause and effect
    (re.compile(
        r"因为[^，。！？\n]{2,20}所以|"
        r"由于[^，。！？\n]{2,20}因此|"
        r"由于[^，。！？\n]{2,20}所以|"
        r"既然[^，。！？\n]{2,20}就|"
        r"所以[^，。！？\n]{2,20}|"
        r"因此[^，。！？\n]{2,15}|"
        r"结果[^，。！？\n]{2,15}"
    ), CAUSE_EFFECT),

    # 7. 经历 — experiential aspect (过)
    (re.compile(
        r"[一-鿿]过(?=[。！？，\s的没]|$)"
    ), GUO_EXPERIENCE),

    # 8. 比较句 — comparison
    (re.compile(
        r"比[^，。！？\n]{1,12}[更还]?[多少高低大小快慢好坏长短重轻热冷贵便宜]|"
        r"没有[^，。！？\n]{1,10}那么|"
        r"跟[^，。！？\n]{1,10}一样|"
        r"和[^，。！？\n]{1,10}相比|"
        r"越来越[^，。！？\n]{1,8}|"
        r"越[^，。！？\n]{1,6}越[^，。！？\n]{1,6}"
    ), BI_COMPARISON),

    # 9. 会/能/可以 — ability / permission / possibility
    (re.compile(
        r"(?:会|能|可以)(?:[^，。！？\n]{1,15})?(?:[吗？]|$)|"
        r"(?:不会|不能|不可以)[^，。！？\n]{1,12}"
    ), HUI_NENG_KEYI),

    # 10. 应该/得/要/必须 — should / must / need to
    (re.compile(
        r"应该[^，。！？\n]{1,15}|"
        r"必须[^，。！？\n]{1,15}|"
        r"需要[^，。！？\n]{1,15}|"
        r"得(?=[一-鿿])[^，。！？\n]{1,12}|"
        r"要[一-鿿][^，。！？\n]{1,12}(?<!想要|需要)"
    ), YING_DEI_YAO),

    # 11. 想/打算/希望 — want to / plan to / hope
    (re.compile(
        r"想(?:[要去做买吃喝学看听说找]|[一-鿿]{1,2})[^，。！？\n]{0,12}|"
        r"打算[^，。！？\n]{1,15}|"
        r"希望[^，。！？\n]{1,15}|"
        r"准备(?=[去做买说学])[^，。！？\n]{1,12}|"
        r"计划[^，。！？\n]{1,12}"
    ), XIANG_DASUAN),

    # 12. 疑问句 — questions
    (re.compile(
        r"[吗呢吧](?:[。？！\s]|$)|"
        r"为什么|什么时候|怎么[了样回去来]|"
        r"哪[里个些儿]|几[点个次]|多少[钱人次]|"
        r"有没有|是不是|能不能|可不可以|"
        r"是否|有无"
    ), QUESTIONS),

    # 13. 了 — completion / change of state
    (re.compile(
        r"[一-鿿]了(?:[。！？，\s]|$)|"
        r"了[一-鿿]{0,2}(?:[吗呢吧。！？]|$)"
    ), LE_COMPLETION),

    # 14. 否定句 — negation
    (re.compile(
        r"不[一-鿿]{1,10}|没[有一-鿿]{0,10}|别[一-鿿]{1,10}|"
        r"从来不|从不|从没|永远不|绝对不"
    ), NEGATION),

    # 15. 时间表达 — time expressions
    (re.compile(
        r"的时候|以后|之前|之后|刚[刚才]?|马上|立刻|"
        r"已经[一-鿿]{1,10}|还[没不][一-鿿]{1,8}|"
        r"再[一-鿿]{1,8}|又[一-鿿]{1,8}|才[一-鿿]{1,8}|"
        r"先[一-鿿]{1,8}[，,]?然后|"
        r"一边[一-鿿]{1,8}一边"
    ), TIME_WORDS),

    # 16. 方位/地点 — location and direction
    (re.compile(
        r"在[^，。！？\n]{1,8}[上下里面内外前后左右边旁]|"
        r"从[^，。！？\n]{1,6}到[^，。！？\n]{1,6}|"
        r"往[东西南北左右上下][走去来]|"
        r"向[一-鿿]{1,6}[走去来走移]|"
        r"朝[一-鿿]{1,6}[走去来]|"
        r"离[^，。！？\n]{1,8}[很较挺十分]?[近远]"
    ), LOCATION_WORDS),
]


def tag_grammar(text: str) -> str:
    """Return the grammar pattern category for the given Chinese sentence."""
    clean = text.strip()
    for pattern, category in _RULES:
        if pattern.search(clean):
            return category
    return GENERAL


def sentence_length_bucket(text: str) -> str:
    """Return a voRhythm-style bucket based on Chinese character count."""
    han_count = len(re.sub(r"[^一-鿿]", "", text))
    if han_count <= 5:
        return "1-5字"
    if han_count <= 10:
        return "6-10字"
    if han_count <= 15:
        return "11-15字"
    if han_count <= 20:
        return "16-20字"
    return "21字+"
