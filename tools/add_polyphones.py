# Polyphonic characters (多音字): single-character entries that have more than
# one reading get ALL readings, comma-separated, in (1) the HSK/Diğer Dart word
# files, (2) the dictionary DB rows and (3) path_word_slots (gözat panels).
# Sentence-pinyin derivation in the app takes only the first reading.
import os, re, sys, requests

sys.stdout.reconfigure(encoding='utf-8')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# char -> all common readings, most frequent first.
P = {
 '行': 'xíng, háng', '还': 'hái, huán', '都': 'dōu, dū', '得': 'de, dé, děi',
 '了': 'le, liǎo', '地': 'de, dì', '长': 'cháng, zhǎng', '着': 'zhe, zháo, zhuó',
 '教': 'jiāo, jiào', '假': 'jiǎ, jià', '难': 'nán, nàn', '倒': 'dǎo, dào',
 '数': 'shù, shǔ', '乐': 'lè, yuè', '重': 'zhòng, chóng', '为': 'wèi, wéi',
 '干': 'gān, gàn', '空': 'kōng, kòng', '好': 'hǎo, hào', '少': 'shǎo, shào',
 '中': 'zhōng, zhòng', '发': 'fā, fà', '几': 'jǐ, jī', '差': 'chà, chā, chāi',
 '处': 'chù, chǔ', '当': 'dāng, dàng', '调': 'diào, tiáo', '分': 'fēn, fèn',
 '更': 'gèng, gēng', '间': 'jiān, jiàn', '将': 'jiāng, jiàng', '卷': 'juǎn, juàn',
 '累': 'lèi, lěi', '量': 'liàng, liáng', '切': 'qiē, qiè', '曲': 'qǔ, qū',
 '散': 'sàn, sǎn', '扫': 'sǎo, sào', '应': 'yīng, yìng', '只': 'zhǐ, zhī',
 '种': 'zhǒng, zhòng', '转': 'zhuǎn, zhuàn', '背': 'bèi, bēi', '藏': 'cáng, zàng',
 '传': 'chuán, zhuàn', '答': 'dá, dā', '弹': 'tán, dàn', '系': 'xì, jì',
 '相': 'xiāng, xiàng', '要': 'yào, yāo', '与': 'yǔ, yù', '脏': 'zāng, zàng',
 '朝': 'cháo, zhāo', '称': 'chēng, chèn', '冲': 'chōng, chòng', '待': 'dài, dāi',
 '担': 'dān, dàn', '提': 'tí, dī', '度': 'dù, duó', '恶': 'è, ě, wù',
 '缝': 'féng, fèng', '划': 'huá, huà', '混': 'hùn, hún', '禁': 'jìn, jīn',
 '尽': 'jǐn, jìn', '圈': 'quān, juàn', '落': 'luò, là, lào',
 '强': 'qiáng, qiǎng, jiàng', '塞': 'sāi, sài, sè', '省': 'shěng, xǐng',
 '似': 'sì, shì', '挑': 'tiāo, tiǎo', '吐': 'tǔ, tù', '咽': 'yàn, yān, yè',
 '折': 'zhé, shé, zhē', '正': 'zhèng, zhēng', '占': 'zhàn, zhān',
 '钻': 'zuān, zuàn', '便': 'biàn, pián', '会': 'huì, kuài', '觉': 'jué, jiào',
}

ACC = {'ā':'a','á':'a','ǎ':'a','à':'a','ē':'e','é':'e','ě':'e','è':'e',
       'ī':'i','í':'i','ǐ':'i','ì':'i','ō':'o','ó':'o','ǒ':'o','ò':'o',
       'ū':'u','ú':'u','ǔ':'u','ù':'u','ǖ':'v','ǘ':'v','ǚ':'v','ǜ':'v','ü':'v'}


def ascii_of(p):
    s = p.lower()
    for k, v in ACC.items():
        s = s.replace(k, v)
    return s


# 1) Dart word files: rewrite the pinyin of matching single-char rows.
files = [f'lib/core/constants/hsk{i}_words.dart' for i in range(1, 7)]
files.append('lib/core/constants/diger_words.dart')
changed_words = set()
for rel in files:
    path = os.path.join(ROOT, rel)
    src = open(path, encoding='utf-8').read()
    orig = src
    for ch, readings in P.items():
        pat = re.compile(r"(\['" + ch + r"',\s*')([^']*)(')")
        def repl(m, readings=readings, ch=ch):
            if m.group(2).strip() == readings:
                return m.group(0)
            changed_words.add(ch)
            return m.group(1) + readings + m.group(3)
        src = pat.sub(repl, src)
    if src != orig:
        open(path, 'w', encoding='utf-8').write(src)
        print(f'[dart] {rel} güncellendi')
print(f'[dart] {len(changed_words)} kelime: {"".join(sorted(changed_words))}')

# 2+3) DB: dictionary + path_word_slots.
tok = None
for line in open(os.path.join(ROOT, '.deploy.env'), encoding='utf-8'):
    if line.startswith('SUPABASE_ACCESS_TOKEN='):
        tok = line.split('=', 1)[1].strip()


def q(sql):
    r = requests.post(
        'https://api.supabase.com/v1/projects/pqyceostpukueydwuiut/database/query',
        headers={'Authorization': f'Bearer {tok}'}, json={'query': sql}, timeout=60)
    return r.json()


values = ', '.join(
    f"('{ch}', '{p}', '{ascii_of(p)}')" for ch, p in P.items())
res1 = q(f"""
update dictionary d set pinyin = v.p, pinyin_ascii = v.pa
from (values {values}) as v(ch, p, pa)
where d.id = v.ch and d.pinyin is distinct from v.p
returning d.id;
""")
print('[db] dictionary güncellenen:', len(res1) if isinstance(res1, list) else res1)
res2 = q(f"""
update path_word_slots s set pinyin = v.p
from (values {values}) as v(ch, p, pa)
where s.word = v.ch and s.pinyin is distinct from v.p
returning s.word;
""")
print('[db] path_word_slots güncellenen:', len(res2) if isinstance(res2, list) else res2)
