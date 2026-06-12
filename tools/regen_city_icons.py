# Re-renders every non-Beijing unit-city icon at 256px (Twemoji SVG rasterized
# via images.weserv.nl — the old 72x72 PNGs pixelate at node size) and makes
# every icon UNIQUE across the whole path: duplicated emojis got distinct,
# concept-matched replacements. Beijing (unit 1, icons8 art) is untouched.
import os
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IC_DIR = os.path.join(ROOT, "assets", "cities")
PH_DIR = os.path.join(ROOT, "assets", "landmarks")

# (slug, icon) -> emoji. One emoji = one slot, globally unique.
ICONS = {
 # chengdu
 ('chengdu', 'panda'): '🐼', ('chengdu', 'hotpot'): '🍲',
 ('chengdu', 'bianlian'): '🎭', ('chengdu', 'jinli'): '🏮',
 # nanjing
 ('nanjing', 'citywall'): '🧱', ('nanjing', 'plum'): '🌸',
 ('nanjing', 'duck'): '🦆', ('nanjing', 'bridge'): '🌉',
 # qingdao
 ('qingdao', 'beer'): '🍺', ('qingdao', 'sailing'): '⛵',
 ('qingdao', 'beach'): '🏖', ('qingdao', 'crab'): '🦀',
 # changsha
 ('changsha', 'pepper'): '🌶', ('changsha', 'tofu'): '🍢',
 ('changsha', 'fireworks'): '🎆', ('changsha', 'orange'): '🍊',
 # zhengzhou
 ('zhengzhou', 'kungfu'): '🥋', ('zhengzhou', 'train'): '🚄',
 ('zhengzhou', 'wheat'): '🌾', ('zhengzhou', 'ding'): '🏺',
 # wuxi
 ('wuxi', 'lake'): '🌊', ('wuxi', 'peach'): '🍑',
 ('wuxi', 'figurine'): '🎎', ('wuxi', 'boat'): '🚣',
 # nanning
 ('nanning', 'tree'): '🌳', ('nanning', 'noodle'): '🍜',
 ('nanning', 'song'): '🎤', ('nanning', 'mango'): '🥭',
 # nanchang
 ('nanchang', 'pavilion'): '🏛', ('nanchang', 'star'): '⭐',
 ('nanchang', 'porcelain'): '🫖', ('nanchang', 'sunset'): '🌅',
 # yinchuan
 ('yinchuan', 'camel'): '🐫', ('yinchuan', 'grapes'): '🍇',
 ('yinchuan', 'desert'): '🏜', ('yinchuan', 'sheep'): '🐑',
 # lhasa
 ('lhasa', 'mountain'): '🏔', ('lhasa', 'prayer'): '🙏',
 ('lhasa', 'yak'): '🐂', ('lhasa', 'tea'): '🍵',
 # zhuhai
 ('zhuhai', 'shell'): '🧜', ('zhuhai', 'bridge'): '🌁',
 ('zhuhai', 'island'): '🏝', ('zhuhai', 'lobster'): '🦞',
 # yantai
 ('yantai', 'apple'): '🍎', ('yantai', 'wine'): '🍷',
 ('yantai', 'wave'): '🌫', ('yantai', 'cherry'): '🍒',
 # datong
 ('datong', 'buddha'): '🗿', ('datong', 'citywall'): '🏯',
 ('datong', 'noodle'): '🔪', ('datong', 'lantern'): '🧗',
 # baotou
 ('baotou', 'horse'): '🐎', ('baotou', 'deer'): '🦌',
 ('baotou', 'factory'): '🏭', ('baotou', 'grass'): '🌿',
 # weifang
 ('weifang', 'kite'): '🪁', ('weifang', 'woodprint'): '🎨',
 ('weifang', 'dragon'): '🐉', ('weifang', 'radish'): '🥬',
 # dezhou
 ('dezhou', 'chicken'): '🍗', ('dezhou', 'sun'): '☀',
 ('dezhou', 'grapes'): '🍉', ('dezhou', 'train'): '🚂',
 # xuzhou
 ('xuzhou', 'stone'): '🪨', ('xuzhou', 'terracotta'): '⚱',
 ('xuzhou', 'lake'): '🐲', ('xuzhou', 'skewer'): '🍖',
 # zhenjiang
 ('zhenjiang', 'vinegar'): '🫙', ('zhenjiang', 'temple'): '⛩',
 ('zhenjiang', 'pot'): '🥘', ('zhenjiang', 'bridge'): '🌄',
 # jiaxing
 ('jiaxing', 'zongzi'): '🍙', ('jiaxing', 'boat'): '🚩',
 ('jiaxing', 'silk'): '🧵', ('jiaxing', 'canal'): '🏘',
 # lishui
 ('lishui', 'mountains'): '⛰', ('lishui', 'camera'): '📷',
 ('lishui', 'mushroom'): '🍄', ('lishui', 'raft'): '🛶',
 # anqing
 ('anqing', 'opera'): '🪭', ('anqing', 'pagoda'): '🛕',
 ('anqing', 'tea'): '🍃', ('anqing', 'sail'): '🚢',
 # ganzhou
 ('ganzhou', 'orange'): '🍋', ('ganzhou', 'house'): '🏠',
 ('ganzhou', 'pavilion'): '🎑', ('ganzhou', 'star'): '🥾',
 # putian
 ('putian', 'shrine'): '👸', ('putian', 'lychee'): '🍓',
 ('putian', 'shoe'): '👟', ('putian', 'wave'): '⛴',
 # mudanjiang
 ('mudanjiang', 'snow'): '❄', ('mudanjiang', 'lake'): '🏞',
 ('mudanjiang', 'tiger'): '🐅', ('mudanjiang', 'ski'): '⛷',
 # changzhou
 ('changzhou', 'dino'): '🦕', ('changzhou', 'pagoda'): '🗼',
 ('changzhou', 'comb'): '🪮', ('changzhou', 'canal'): '🌃',
 # shaoxing
 ('shaoxing', 'wine'): '🍶', ('shaoxing', 'bridge'): '🪷',
 ('shaoxing', 'pen'): '🖌', ('shaoxing', 'boat'): '☂',
 # bengbu
 ('bengbu', 'shell'): '🦪', ('bengbu', 'train'): '🚉',
 ('bengbu', 'river'): '🧭', ('bengbu', 'blossom'): '💮',
 # jiujiang
 ('jiujiang', 'mountain'): '🗻', ('jiujiang', 'tea'): '☁',
 ('jiujiang', 'lake'): '🦢', ('jiujiang', 'scroll'): '📜',
 # quanzhou
 ('quanzhou', 'ship'): '⚓', ('quanzhou', 'mosque'): '🕌',
 ('quanzhou', 'puppet'): '🪆', ('quanzhou', 'tea'): '🍂',
}


def codepoints(e):
    return '-'.join(f'{ord(c):x}' for c in e if ord(c) != 0xFE0F)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def render(cp):
    # weserv rasterizes the Twemoji SVG at 256px (sharp at any node size).
    svg = (f"cdn.jsdelivr.net/gh/jdecked/twemoji@15.1.0/assets/svg/{cp}.svg")
    for url in (
        f"https://images.weserv.nl/?url={svg}&w=256&h=256&output=png",
        f"https://images.weserv.nl/?url=cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/svg/{cp}.svg&w=256&h=256&output=png",
    ):
        try:
            data = fetch(url)
            if data[:8] == b"\x89PNG\r\n\x1a\n":
                return data
        except Exception as ex:
            print("  fetch fail", cp, ex)
    return None


def main():
    # Uniqueness guard: a repeated emoji is a bug in the table above.
    seen = {}
    for k, e in ICONS.items():
        if e in seen:
            raise SystemExit(f"DUPLICATE emoji {e}: {seen[e]} and {k}")
        seen[e] = k
    ok = fail = 0
    for (slug, icon), emoji in ICONS.items():
        cp = codepoints(emoji)
        data = render(cp)
        if data is None:
            print("MISS", slug, icon, emoji, cp)
            fail += 1
            continue
        with open(os.path.join(IC_DIR, f"{slug}-{icon}.png"), "wb") as f:
            f.write(data)
        # Photo placeholder shares the art until a real photo is uploaded.
        with open(os.path.join(PH_DIR, f"{slug}-{icon}.jpg"), "wb") as f:
            f.write(data)
        ok += 1
        time.sleep(0.15)
    print(f"rendered {ok}, failed {fail}")


if __name__ == "__main__":
    main()
