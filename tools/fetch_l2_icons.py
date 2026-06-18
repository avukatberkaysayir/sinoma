# Sets the L2 unit-city landmark icons (+ photo placeholders) to REAL,
# landmark-specific icons8 color art instead of generic Twemoji emoji. Every
# icon is an explicit, hand-verified icons8 commonName, chosen as the closest
# literal match for that landmark. Each icon is used AT MOST ONCE across the
# whole L2 set (hard uniqueness guard). Run after gen_l2_cities.py.
import os
import sys
import time
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IC_DIR = os.path.join(ROOT, "assets", "cities")
PH_DIR = os.path.join(ROOT, "assets", "landmarks")
CDN = "https://img.icons8.com/color/256/{}.png"
UA = "Mozilla/5.0 (sinoma-l2-icons)"

# (slug, icon) -> icons8 commonName. Literal landmark match first; each name
# globally unique (no icon reused). All verified present in icons8 color set.
ICONS = {
 ('shanghai', 'pearl'): 'cn-tower',          # Oriental Pearl Tower (sphered TV tower)
 ('shanghai', 'bund'): 'city-buildings',     # The Bund waterfront skyline
 ('shanghai', 'garden'): 'garden',           # Yu Garden
 ('shanghai', 'xlb'): 'dumplings',           # xiaolongbao soup dumplings

 ('hangzhou', 'lake'): 'lotus',              # West Lake (its famed lotus)
 ('hangzhou', 'tea'): 'green-tea',           # Longjing green tea
 ('hangzhou', 'temple'): 'temple',           # Lingyin Temple
 ('hangzhou', 'silk'): 'scarf',              # Hangzhou silk

 ('chongqing', 'hongya'): 'lantern',         # Hongya Cave — the glowing lantern-lit complex
 ('chongqing', 'hotpot'): 'fondue',          # Chongqing hotpot (communal simmering pot)
 ('chongqing', 'monorail'): 'train',         # mountain monorail / light rail
 ('chongqing', 'river'): 'cruise-ship',      # Yangtze gorges cruise

 ('dalian', 'square'): 'fountain',           # Xinghai Square
 ('dalian', 'beach'): 'beach',               # beaches
 ('dalian', 'football'): 'football',         # football city
 ('dalian', 'seafood'): 'prawn',             # seafood

 ('shenyang', 'palace'): 'castle',           # Mukden Palace
 ('shenyang', 'tomb'): 'cemetery',           # Qing tombs
 ('shenyang', 'factory'): 'factory',         # heavy industry
 ('shenyang', 'dumpling'): 'dim-sum',        # Laobian dumplings

 ('hefei', 'judge'): 'court-judge',          # Lord Bao the judge
 ('hefei', 'science'): 'microscope',         # science city
 ('hefei', 'lake'): 'fishing',               # Lake Chaohu (fishing)
 ('hefei', 'cake'): 'sesame',                # Lu sesame cake

 ('foshan', 'wingchun'): 'judo',             # Wing Chun martial arts
 ('foshan', 'lion'): 'lion',                 # lion dance
 ('foshan', 'ceramic'): 'pottery',           # Shiwan pottery
 ('foshan', 'opera'): 'opera',               # Cantonese opera (mask)

 ('guiyang', 'pavilion'): 'pavilion',        # Jiaxiu Pavilion
 ('guiyang', 'sourfish'): 'fish',            # sour soup fish
 ('guiyang', 'waterfall'): 'waterfall',      # Huangguoshu Falls
 ('guiyang', 'miao'): 'geisha',              # Miao traditional dress (folk costume)

 ('changchun', 'film'): 'film-reel',         # film city
 ('changchun', 'car'): 'car--v2',            # auto city
 ('changchun', 'palace'): 'crown',           # puppet emperor's palace
 ('changchun', 'snow'): 'snowflake',         # winter snow

 ('xining', 'lake'): 'lake',                 # Lake Qinghai
 ('xining', 'monastery'): 'monastery',       # Kumbum Monastery
 ('xining', 'flower'): 'canola',             # rapeseed blossom
 ('xining', 'lamb'): 'rack-of-lamb',         # yak & lamb

 ('guilin', 'karst'): 'mountain',            # Li River karst peaks
 ('guilin', 'elephant'): 'elephant',         # Elephant Trunk Hill
 ('guilin', 'terrace'): 'field',             # Longji rice terraces
 ('guilin', 'osmanthus'): 'sakura',          # osmanthus blossom

 ('wenzhou', 'merchant'): 'businessman',     # merchant spirit
 ('wenzhou', 'shoe'): 'shoes',               # leather shoes
 ('wenzhou', 'mountain'): 'cliff',           # Yandang Mountains
 ('wenzhou', 'seafood'): 'octopus',          # squid/seafood

 ('tangshan', 'memorial'): 'memorial-day',   # earthquake memorial
 ('tangshan', 'coal'): 'coal',               # coal & steel
 ('tangshan', 'ceramic'): 'plate',           # Tangshan ceramics (bone china)
 ('tangshan', 'lake'): 'park-bench',         # Nanhu Park

 ('anshan', 'steel'): 'steel-bars',          # steel city
 ('anshan', 'jade'): 'emerald',              # Xiuyan jade
 ('anshan', 'mountain'): 'mountain-city',    # Mount Qian
 ('anshan', 'spring'): 'hot-springs',        # Tanggangzi hot springs

 ('linyi', 'market'): 'stall',               # wholesale market
 ('linyi', 'brush'): 'paint-brush',          # Wang Xizhi calligraphy
 ('linyi', 'mountain'): 'alps',              # Mount Meng
 ('linyi', 'pancake'): 'pancake',            # jianbing

 ('cangzhou', 'lion'): 'lion-statue',        # Iron Lion
 ('cangzhou', 'martial'): 'taekwondo',       # wushu martial arts
 ('cangzhou', 'canal'): 'venice-canal',      # Grand Canal
 ('cangzhou', 'jujube'): 'date-fruit',       # golden jujube

 ('nantong', 'textile'): 'cotton',           # cotton textiles
 ('nantong', 'mountain'): 'pagoda',          # Langshan temple hill
 ('nantong', 'kite'): 'kite',                # whistling kite
 ('nantong', 'school'): 'graduation-cap',    # education pioneer

 ('taizhou', 'opera'): 'drama',              # Mei Lanfang / opera
 ('taizhou', 'tea'): 'teapot',               # morning tea
 ('taizhou', 'boat'): 'dragon-boat',         # Qintong boat festival
 ('taizhou', 'meatball'): 'miso-soup',       # lion's head meatball (in broth)

 ('jinhua', 'ham'): 'jamon',                 # Jinhua ham
 ('jinhua', 'film'): 'movie-projector',      # Hengdian studios
 ('jinhua', 'cave'): 'cave',                 # Shuanglong Cave
 ('jinhua', 'bridge'): 'bridge',             # ancient bridges

 ('wuhu', 'park'): 'roller-coaster',         # Fangte Wonderland
 ('wuhu', 'ironart'): 'hammer-and-anvil',    # iron painting
 ('wuhu', 'rice'): 'rice-bowl',              # rice port
 ('wuhu', 'river'): 'cargo-ship',            # Yangtze port

 ('huangshan', 'peak'): 'sunrise',           # Yellow Mountain sunrise
 ('huangshan', 'village'): 'village',        # Hongcun village
 ('huangshan', 'tea'): 'tea--v2',            # Maofeng tea
 ('huangshan', 'ink'): 'ink',                # Hui ink & arts

 ('yichun', 'moon'): 'moon',                 # Mount Mingyue (Bright Moon)
 ('yichun', 'spring'): 'spa',                # hot springs spa
 ('yichun', 'zen'): 'meditation-guru',       # Chan Buddhism
 ('yichun', 'rice'): 'wheat',                # rice/grain plain

 ('zhangzhou', 'narcissus'): 'flower',       # narcissus
 ('zhangzhou', 'tulou'): 'coliseum',         # Hakka round earth houses
 ('zhangzhou', 'banana'): 'banana',          # tropical fruit
 ('zhangzhou', 'coast'): 'island',           # Dongshan Island
}


def fetch(common_name):
    url = CDN.format(urllib.parse.quote(common_name))
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    return data if data[:8] == b"\x89PNG\r\n\x1a\n" else None


def main():
    # Hard uniqueness guard: a repeated commonName is a bug in the table.
    seen = {}
    for k, cn in ICONS.items():
        if cn in seen:
            raise SystemExit(f"DUPLICATE icon '{cn}': {seen[cn]} and {k}")
        seen[cn] = k
    ok = fail = 0
    for (slug, icon), cn in ICONS.items():
        data = fetch(cn)
        if data is None:
            print(f"MISS  {slug}-{icon}  ({cn})")
            fail += 1
            continue
        with open(os.path.join(IC_DIR, f"{slug}-{icon}.png"), "wb") as f:
            f.write(data)
        with open(os.path.join(PH_DIR, f"{slug}-{icon}.jpg"), "wb") as f:
            f.write(data)
        print(f"{slug}-{icon:11s} -> {cn}")
        ok += 1
        time.sleep(0.1)
    print(f"\nset {ok}, missing {fail}, {len(seen)} unique icons")


if __name__ == "__main__":
    main()
