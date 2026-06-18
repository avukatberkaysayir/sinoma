# Single source of truth for EVERY landmark icon across ALL path levels.
# Assigns each of the 212 landmark slots (53 cities x 4) a UNIQUE icons8 color
# icon — no icon is EVER reused anywhere across any level. Each name below is a
# hand-picked, verified icons8 color commonName, the closest literal match for
# that landmark given icons8's catalogue. A hard uniqueness guard rejects any
# accidental repeat. Downloads the icon to assets/cities/<slug>-<icon>.png and a
# photo placeholder to assets/landmarks/<slug>-<icon>.jpg.
import json
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
UA = "Mozilla/5.0 (sinoma-icons)"

# (slug, icon) -> icons8 color commonName. Globally unique.
ICONS = {
 # ---- Beijing ----
 ('beijing', 'great-wall'): 'great-wall',
 ('beijing', 'temple'): 'temple',                  # Temple of Heaven
 ('beijing', 'pagoda'): 'pagoda',                  # Tianning Pagoda
 ('beijing', 'opera'): 'theatre-mask',             # Beijing opera

 # ---- L1 / original cities ----
 ('chengdu', 'panda'): 'panda',
 ('chengdu', 'hotpot'): 'cooking-pot',
 ('chengdu', 'bianlian'): 'venetian-mask',         # face-changing
 ('chengdu', 'jinli'): 'street',

 ('nanjing', 'citywall'): 'brick-wall',            # Ming city wall
 ('nanjing', 'plum'): 'plum',
 ('nanjing', 'duck'): 'duck',
 ('nanjing', 'bridge'): '25-de-abril-bridge',      # Yangtze suspension bridge

 ('qingdao', 'beer'): 'beer',
 ('qingdao', 'sailing'): 'sailing-ship-small',
 ('qingdao', 'beach'): 'sun-lounger',
 ('qingdao', 'crab'): 'crab',

 ('changsha', 'pepper'): 'chili-pepper',
 ('changsha', 'tofu'): 'soy',
 ('changsha', 'fireworks'): 'firework-explosion',
 ('changsha', 'orange'): 'orange',

 ('zhengzhou', 'kungfu'): 'ninja',                 # Shaolin martial arts
 ('zhengzhou', 'train'): 'train',                  # railway hub
 ('zhengzhou', 'wheat'): 'wheat',
 ('zhengzhou', 'ding'): 'trophy',                  # bronze ding vessel

 ('wuxi', 'lake'): 'water',                         # Lake Taihu
 ('wuxi', 'peach'): 'peach',
 ('wuxi', 'figurine'): 'doll',                      # Huishan clay doll
 ('wuxi', 'boat'): 'gondola',

 ('nanning', 'tree'): 'deciduous-tree',             # green city
 ('nanning', 'noodle'): 'noodles',
 ('nanning', 'song'): 'microphone',
 ('nanning', 'mango'): 'mango',

 ('nanchang', 'pavilion'): 'pavilion',              # Tengwang Pavilion
 ('nanchang', 'star'): 'star',                      # August 1st
 ('nanchang', 'porcelain'): 'plate',
 ('nanchang', 'sunset'): 'sunset',

 ('yinchuan', 'camel'): '--camel',                  # Silk Road
 ('yinchuan', 'grapes'): 'grapes',
 ('yinchuan', 'desert'): 'desert-landscape',
 ('yinchuan', 'sheep'): 'sheep',

 ('lhasa', 'mountain'): 'palace',                   # Potala Palace
 ('lhasa', 'prayer'): 'prayer',                     # Jokhang Temple
 ('lhasa', 'yak'): 'yak',
 ('lhasa', 'tea'): 'tea',                           # butter tea

 ('zhuhai', 'shell'): 'mermaid',                    # Fisher Girl
 ('zhuhai', 'bridge'): 'road-bridge',               # HZM sea bridge
 ('zhuhai', 'island'): 'island-on-water',           # Hundred Islands
 ('zhuhai', 'lobster'): 'lobster',

 ('yantai', 'apple'): 'apple',
 ('yantai', 'wine'): 'wine-bottle',
 ('yantai', 'wave'): 'sea-waves',                   # Penglai coast
 ('yantai', 'cherry'): 'cherry',

 ('datong', 'buddha'): 'buddha',                    # Yungang Grottoes
 ('datong', 'citywall'): 'sand-castle',             # Ming walls
 ('datong', 'noodle'): 'spaghetti',                 # knife-cut noodles
 ('datong', 'lantern'): 'church',                   # Hanging Temple

 ('baotou', 'horse'): 'horse',
 ('baotou', 'deer'): 'deer',
 ('baotou', 'factory'): 'factory-emissions',        # steel city
 ('baotou', 'grass'): 'grass',

 ('weifang', 'kite'): 'kite',                        # kite capital
 ('weifang', 'woodprint'): 'rubber-stamp',          # Yangjiabu prints
 ('weifang', 'dragon'): 'dragon',
 ('weifang', 'radish'): 'radish',

 ('dezhou', 'chicken'): 'chicken',
 ('dezhou', 'sun'): 'solar-panel',                  # Solar Valley
 ('dezhou', 'grapes'): 'watermelon',                # melons & vines
 ('dezhou', 'train'): 'anchor',                     # canal port

 ('xuzhou', 'stone'): 'stone-inscription',          # Han stone reliefs
 ('xuzhou', 'terracotta'): 'statue',                # terracotta army
 ('xuzhou', 'lake'): 'swan',                         # Yunlong Lake
 ('xuzhou', 'skewer'): 'roast',                      # BBQ

 ('zhenjiang', 'vinegar'): 'sauce-bottle',
 ('zhenjiang', 'temple'): 'basilica',               # Jinshan Temple
 ('zhenjiang', 'pot'): 'soup-plate',                # pot-lid noodles
 ('zhenjiang', 'bridge'): 'walking-bridge',         # Yangtze banks

 ('jiaxing', 'zongzi'): 'sushi',                    # zongzi (wrapped rice)
 ('jiaxing', 'boat'): 'canoe-slalom',               # South Lake boat
 ('jiaxing', 'silk'): 'sewing-machine',
 ('jiaxing', 'canal'): 'water-wheel',               # Wuzhen water town

 ('lishui', 'mountains'): 'valley',                 # green peaks
 ('lishui', 'camera'): 'camera',
 ('lishui', 'mushroom'): 'mushroom',
 ('lishui', 'raft'): 'rafting',

 ('anqing', 'opera'): 'actor',                      # Huangmei opera
 ('anqing', 'pagoda'): 'lighthouse',                # Zhenfeng Pagoda (river beacon)
 ('anqing', 'tea'): 'chamomile-tea',
 ('anqing', 'sail'): 'yacht',                       # river gate

 ('ganzhou', 'orange'): 'citrus',                   # navel orange
 ('ganzhou', 'house'): 'hut',                        # Hakka houses
 ('ganzhou', 'pavilion'): 'monument',               # Yugu Pavilion
 ('ganzhou', 'star'): 'trekking',                    # Long March

 ('putian', 'shrine'): 'torii',                      # Mazu Temple
 ('putian', 'lychee'): 'lychee',
 ('putian', 'shoe'): 'trainers',
 ('putian', 'wave'): 'palm-tree',                    # Meizhou Island

 ('mudanjiang', 'snow'): 'snowman',
 ('mudanjiang', 'lake'): 'spring-lake-park',         # Jingpo Lake
 ('mudanjiang', 'tiger'): 'year-of-tiger',           # Siberian tiger
 ('mudanjiang', 'ski'): 'skiing',

 ('changzhou', 'dino'): 'dinosaur',
 ('changzhou', 'pagoda'): 'museum',                  # Tianning Pagoda (tall)
 ('changzhou', 'comb'): 'comb',
 ('changzhou', 'canal'): 'dinghy',

 ('shaoxing', 'wine'): 'sake',                       # yellow rice wine
 ('shaoxing', 'bridge'): 'rope-bridge',              # stone bridges
 ('shaoxing', 'pen'): 'quill-with-ink',              # calligraphy cradle
 ('shaoxing', 'boat'): 'drag-boat',                  # black-awning boats

 ('bengbu', 'shell'): 'diamond',                     # Pearl Port
 ('bengbu', 'train'): 'train-station',
 ('bengbu', 'river'): 'catamaran',                   # Huai River
 ('bengbu', 'blossom'): 'spring',                    # spring fairs

 ('jiujiang', 'mountain'): 'volcano',                # Mount Lu
 ('jiujiang', 'tea'): 'matcha',                      # cloud-mist tea
 ('jiujiang', 'lake'): 'crane-bird',                 # Poyang Lake cranes
 ('jiujiang', 'scroll'): 'scroll',                   # city of poems

 ('quanzhou', 'ship'): 'sailing-ship-large',         # Maritime Silk Road
 ('quanzhou', 'mosque'): 'mosque',
 ('quanzhou', 'puppet'): 'puppet-2',
 ('quanzhou', 'tea'): 'bubble-tea-',                 # Tieguanyin

 # ---- L2 cities ----
 ('shanghai', 'pearl'): 'cn-tower',
 ('shanghai', 'bund'): 'city-buildings',
 ('shanghai', 'garden'): 'garden',
 ('shanghai', 'xlb'): 'dumplings',

 ('hangzhou', 'lake'): 'lotus',                      # West Lake
 ('hangzhou', 'tea'): 'green-tea',                   # Longjing
 ('hangzhou', 'temple'): 'angkor-wat',               # Lingyin Temple
 ('hangzhou', 'silk'): 'scarf',

 ('chongqing', 'hongya'): 'lantern',
 ('chongqing', 'hotpot'): 'fondue',
 ('chongqing', 'monorail'): 'tram',
 ('chongqing', 'river'): 'cruise-ship',

 ('dalian', 'square'): 'fountain',
 ('dalian', 'beach'): 'beach',
 ('dalian', 'football'): 'football',
 ('dalian', 'seafood'): 'prawn',

 ('shenyang', 'palace'): 'castle',                   # Mukden Palace
 ('shenyang', 'tomb'): 'cemetery',
 ('shenyang', 'factory'): 'factory',
 ('shenyang', 'dumpling'): 'dim-sum',

 ('hefei', 'judge'): 'court-judge',
 ('hefei', 'science'): 'microscope',
 ('hefei', 'lake'): 'fishing',
 ('hefei', 'cake'): 'sesame',

 ('foshan', 'wingchun'): 'judo',
 ('foshan', 'lion'): 'lion',
 ('foshan', 'ceramic'): 'pottery',
 ('foshan', 'opera'): 'opera',

 ('guiyang', 'pavilion'): 'taj-mahal',               # Jiaxiu Pavilion
 ('guiyang', 'sourfish'): 'fish',
 ('guiyang', 'waterfall'): 'waterfall',
 ('guiyang', 'miao'): 'geisha',

 ('changchun', 'film'): 'film-reel',
 ('changchun', 'car'): 'car--v2',
 ('changchun', 'palace'): 'crown',
 ('changchun', 'snow'): 'snowflake',

 ('xining', 'lake'): 'lake',                         # Lake Qinghai
 ('xining', 'monastery'): 'monastery',
 ('xining', 'flower'): 'canola',
 ('xining', 'lamb'): 'rack-of-lamb',

 ('guilin', 'karst'): 'mountain',
 ('guilin', 'elephant'): 'elephant',
 ('guilin', 'terrace'): 'field',
 ('guilin', 'osmanthus'): 'sakura',

 ('wenzhou', 'merchant'): 'businessman',
 ('wenzhou', 'shoe'): 'shoes',
 ('wenzhou', 'mountain'): 'cliff',
 ('wenzhou', 'seafood'): 'octopus',

 ('tangshan', 'memorial'): 'memorial-day',
 ('tangshan', 'coal'): 'coal',
 ('tangshan', 'ceramic'): 'tableware',
 ('tangshan', 'lake'): 'park-bench',

 ('anshan', 'steel'): 'steel-bars',
 ('anshan', 'jade'): 'emerald',
 ('anshan', 'mountain'): 'mountain-city',
 ('anshan', 'spring'): 'hot-springs',

 ('linyi', 'market'): 'stall',
 ('linyi', 'brush'): 'paint-brush',
 ('linyi', 'mountain'): 'alps',
 ('linyi', 'pancake'): 'pancake',

 ('cangzhou', 'lion'): 'lion-statue',
 ('cangzhou', 'martial'): 'taekwondo',
 ('cangzhou', 'canal'): 'venice-canal',
 ('cangzhou', 'jujube'): 'date-fruit',

 ('nantong', 'textile'): 'cotton',
 ('nantong', 'mountain'): 'chapel',                  # Langshan temple hill
 ('nantong', 'kite'): 'kite-shape',
 ('nantong', 'school'): 'graduation-cap',

 ('taizhou', 'opera'): 'drama',                      # Mei Lanfang
 ('taizhou', 'tea'): 'teapot',
 ('taizhou', 'boat'): 'dragon-boat',
 ('taizhou', 'meatball'): 'miso-soup',

 ('jinhua', 'ham'): 'jamon',
 ('jinhua', 'film'): 'movie-projector',
 ('jinhua', 'cave'): 'cave',
 ('jinhua', 'bridge'): 'bridge',

 ('wuhu', 'park'): 'roller-coaster',
 ('wuhu', 'ironart'): 'hammer-and-anvil',
 ('wuhu', 'rice'): 'rice-bowl',
 ('wuhu', 'river'): 'cargo-ship',

 ('huangshan', 'peak'): 'sunrise',
 ('huangshan', 'village'): 'village',
 ('huangshan', 'tea'): 'tea--v2',
 ('huangshan', 'ink'): 'ink',

 ('yichun', 'moon'): 'moon',
 ('yichun', 'spring'): 'spa',
 ('yichun', 'zen'): 'meditation-guru',
 ('yichun', 'rice'): 'grains-of-rice',

 ('zhangzhou', 'narcissus'): 'flower',
 ('zhangzhou', 'tulou'): 'coliseum',
 ('zhangzhou', 'banana'): 'banana',
 ('zhangzhou', 'coast'): 'island',

 # ---- L3 cities ----
 ('guangzhou', 'tower'): 'tower',                  # Canton Tower
 ('guangzhou', 'dimsum'): 'gyoza',                 # morning tea / dim sum
 ('guangzhou', 'academy'): 'courthouse',           # Chen Clan Academy
 ('guangzhou', 'flower'): 'rose',                  # Flower City
 ('wuhan', 'crane'): 'stork',                      # Yellow Crane Tower
 ('wuhan', 'noodle'): 'ladle',                     # hot-dry noodles
 ('wuhan', 'duckneck'): 'flying-duck',             # spicy duck neck
 ('wuhan', 'university'): 'university',             # campus cherry blossoms
 ('tianjin', 'eye'): 'ferris-wheel',               # Tianjin Eye
 ('tianjin', 'baozi'): 'bao-bun',                  # Goubuli buns
 ('tianjin', 'crosstalk'): 'stand-up',             # xiangsheng comedy
 ('tianjin', 'architecture'): 'house-with-a-garden',  # European quarter
 ('xiamen', 'island'): 'paradise',                 # Gulangyu Island
 ('xiamen', 'piano'): 'piano',                     # Piano Island
 ('xiamen', 'egret'): 'pelican',                   # white egret
 ('xiamen', 'oyster'): 'sunny-side-up-eggs',       # oyster omelette
 ('harbin', 'ice'): 'iceberg',                     # Ice Festival
 ('harbin', 'cathedral'): 'orthodox-church',       # St Sophia Cathedral
 ('harbin', 'sausage'): 'salami',                  # red sausage
 ('harbin', 'accordion'): 'accordion',             # Music City
 ('fuzhou', 'alley'): 'curvy-street',              # Three Lanes Seven Alleys
 ('fuzhou', 'banyan'): 'growing-tree',             # Banyan City
 ('fuzhou', 'hotspring'): 'jacuzzi',               # hot springs
 ('fuzhou', 'soup'): 'stir',                       # Buddha Jumps Over the Wall
 ('dongguan', 'robot'): 'delivery-robot',          # world's factory
 ('dongguan', 'basketball'): 'basketball',         # basketball city
 ('dongguan', 'keyuan'): 'bonsai',                 # Keyuan Garden
 ('dongguan', 'cannon'): 'cannon',                 # Humen forts
 ('lanzhou', 'beefnoodle'): 'bowl',                # Lanzhou beef noodles
 ('lanzhou', 'waterwheel'): 'windmill',            # Yellow River waterwheels
 ('lanzhou', 'statue'): 'modern-statue',           # Mother Yellow River
 ('lanzhou', 'raft'): 'rafting-skin-type-4',       # sheepskin raft
 ('urumqi', 'bazaar'): 'market-square',            # Grand Bazaar
 ('urumqi', 'tianshan'): 'winter-landscape',       # Heavenly Lake
 ('urumqi', 'kebab'): 'kebab',                     # lamb kebab
 ('urumqi', 'dance'): 'dancing',                   # Uyghur dance
 ('haikou', 'coconut'): 'coconut',                 # Coconut City
 ('haikou', 'arcade'): 'arch',                     # Qilou arcades
 ('haikou', 'crater'): 'fuji-volcano',             # volcanic craters
 ('haikou', 'turtle'): 'turtle',                   # tropical sea
 ('luoyang', 'grotto'): 'dharmacakra',             # Longmen Grottoes
 ('luoyang', 'peony'): 'violet-flower',            # Peony Capital
 ('luoyang', 'whitehorse'): 'pony',                # White Horse Temple
 ('luoyang', 'capital'): 'ruins',                  # ancient capital
 ('shantou', 'gongfutea'): 'tea-tin',             # gongfu tea
 ('shantou', 'beefpot'): 'steak-medium',           # beef hotpot
 ('shantou', 'opera'): 'comedy',                   # Teochew opera
 ('shantou', 'harbor'): 'port',                    # port city
 ('baoding', 'mansion'): 'mansion',                # Governor's Mansion
 ('baoding', 'donkeyburger'): 'sandwich',          # donkey burger
 ('baoding', 'balls'): 'sphere',                   # health balls
 ('baoding', 'reeds'): 'dragonfly',                # Baiyangdian marsh
 ('jilin', 'rime'): 'light-snow',                  # rime ice
 ('jilin', 'snowboard'): 'snowboarding',           # ski resort
 ('jilin', 'meteorite'): 'asteroid',               # meteorite museum
 ('jilin', 'skate'): 'ice-skate',                  # frozen Songhua
 ('ordos', 'khan'): 'knight',                      # Genghis Khan Mausoleum
 ('ordos', 'cashmere'): 'goat',                    # cashmere
 ('ordos', 'sanddune'): 'cactus',                  # singing sands
 ('ordos', 'yurt'): 'tent',                        # Mongolian yurt
 ('jining', 'confucius'): 'wise-old-man',          # Confucius Temple
 ('jining', 'barge'): 'ferry',                     # Grand Canal
 ('jining', 'sword'): 'sword',                     # Liangshan heroes
 ('jining', 'fishnet'): 'fishing-hook',            # Weishan Lake
 ('langfang', 'culture'): 'concert',               # Silk Road Culture Center
 ('langfang', 'furniture'): 'sofa',                # furniture city
 ('langfang', 'tunnel'): 'tunnel',                 # ancient war tunnels
 ('langfang', 'themepark'): 'theme-park',          # No.1 City park
 ('yancheng', 'salt'): 'salt',                     # City of Salt
 ('yancheng', 'crane'): 'flamingo',                # red-crowned crane
 ('yancheng', 'elk'): 'reindeer',                  # Père David's deer
 ('yancheng', 'wetland'): 'swamp',                 # coastal wetland
 ('huzhou', 'brush'): 'paint-palette-with-brush',  # Hu writing brush
 ('huzhou', 'bamboo'): 'bamboo',                   # Anji bamboo sea
 ('huzhou', 'silkworm'): 'caterpillar',            # silk worm
 ('huzhou', 'whitetea'): 'tea-pair',               # Anji white tea
 ('quzhou', 'go'): 'board-game',                   # Go (weiqi)
 ('quzhou', 'peaks'): 'obelisk',                   # Mount Jianglang pillars
 ('quzhou', 'ponkan'): 'clementine',               # ponkan tangerine
 ('quzhou', 'cake'): 'naan',                       # baked flatbread
 ('huainan', 'tofu'): 'silken-tofu',               # birthplace of tofu
 ('huainan', 'coalmine'): 'mine',                  # coal city
 ('huainan', 'oldtown'): 'brandenburg-gate',       # Shou County old town gate
 ('huainan', 'classic'): 'book',                   # the Huainanzi
 ('jingdezhen', 'porcelain'): 'potters-wheel',     # porcelain capital
 ('jingdezhen', 'kiln'): 'pottery-workshop',       # ancient kiln
 ('jingdezhen', 'bluewhite'): 'cookie-jar',        # blue & white porcelain
 ('jingdezhen', 'painting'): 'easel',              # porcelain painting
 ('jian', 'jinggang'): 'forest',                   # Jinggang Mountains
 ('jian', 'torch'): 'olympic-torch',               # revolutionary spark
 ('jian', 'academy'): 'library',                   # Bailuzhou Academy
 ('jian', 'pine'): 'coniferous-tree',              # Jinggang pines
 ('nanping', 'wuyi'): 'grand-canyon',              # Wuyi Mountains
 ('nanping', 'rocktea'): 'tea-cup',                # Da Hong Pao rock tea
 ('nanping', 'bambooraft'): 'rafting-skin-type-2', # Nine-Bend raft
 ('nanping', 'scholar'): 'teacher',                # Zhu Xi
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
    misses = []
    for (slug, icon), cn in ICONS.items():
        try:
            data = fetch(cn)
        except Exception as ex:
            data = None
            print("  err", cn, ex)
        if data is None:
            misses.append((slug, icon, cn))
            print(f"MISS  {slug}-{icon}  ({cn})")
            fail += 1
            continue
        with open(os.path.join(IC_DIR, f"{slug}-{icon}.png"), "wb") as f:
            f.write(data)
        with open(os.path.join(PH_DIR, f"{slug}-{icon}.jpg"), "wb") as f:
            f.write(data)
        ok += 1
        time.sleep(0.05)
    print(f"\nset {ok}, missing {fail}, {len(seen)} unique icons")
    if misses:
        print("MISSES:", misses)
    with open(os.path.join(os.path.dirname(__file__), "icons_resolved.json"),
              "w", encoding="utf-8") as f:
        json.dump({f"{s}/{i}": cn for (s, i), cn in ICONS.items()}, f,
                  ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
