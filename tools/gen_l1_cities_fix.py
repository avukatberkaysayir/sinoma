# Fix pass: the six L1 unit cities the first run mapped wrongly
# (units 15/18/20/21/23/24 = Mudanjiang, Changzhou, Shaoxing, Bengbu,
# Jiujiang, Quanzhou). Same pattern: Twemoji icons + Landmark data.
import requests, os, sys, shutil
sys.stdout.reconfigure(encoding='utf-8')

C = {
 'mudanjiang': [
  ('snow', '❄', 'Çin Kar Kasabası', 'China Snow Town', "Kalın kar yastıklarıyla kaplı masal köyü, kışın ışıl ışıl parlar.", "A fairy-tale village under thick pillows of snow, glowing in winter."),
  ('lake', '\U0001F30A', 'Jingpo Gölü', 'Jingpo Lake', "Volkanik set gölü; Diaoshuilou şelalesi kışın bile dökülür.", "A volcanic barrier lake whose Diaoshuilou falls pour even in winter."),
  ('tiger', '\U0001F405', 'Sibirya Kaplanı Parkı', 'Siberian Tiger Park', "Dünyanın en büyük Sibirya kaplanı koruma merkezlerinden biri.", "One of the world's largest Siberian tiger sanctuaries."),
  ('ski', '⛷', 'Kayak Sezonu', 'Ski Season', "Uzun ve karlı kış, bölgeyi kayak tutkunlarının rotasına koyar.", "Long snowy winters put the region on every skier's map.")],
 'changzhou': [
  ('dino', '\U0001F996', 'Dinozor Parkı', 'Dinosaur Park', "Çin'in en ünlü dinozor temalı parkı aileler için şehrin simgesidir.", "China's most famous dinosaur theme park is the city's family icon."),
  ('pagoda', '\U0001F5FC', 'Tianning Pagodası', 'Tianning Pagoda', "153 metreyle dünyanın en yüksek pagodası şehir merkezinde yükselir.", "At 153 m, the world's tallest pagoda rises downtown."),
  ('comb', '\U0001FAAE', 'Tarak Ustalığı', 'Comb Craft', "Bin yıllık Changzhou tarağı, imparatorluk saraylarına hediye edilirdi.", "Thousand-year Changzhou combs were once palace gifts."),
  ('canal', '\U0001F6A3', 'Büyük Kanal', 'Grand Canal', "Kanal kıyısı eski mahalleleri ve gece ışıklarıyla gezilir.", "The canal banks are strolled for old quarters and night lights.")],
 'shaoxing': [
  ('wine', '\U0001F376', 'Shaoxing Şarabı', 'Shaoxing Wine', "Çin mutfağının ünlü sarı pirinç şarabı binlerce yıldır burada mayalanır.", "The famous yellow rice wine of Chinese cooking has been brewed here for millennia."),
  ('bridge', '\U0001F309', 'Taş Köprüler', 'Stone Bridges', "Kanallar şehri Shaoxing'de yüzlerce kavisli taş köprü vardır.", "Canal-laced Shaoxing keeps hundreds of arched stone bridges."),
  ('pen', '\U0001F58C', 'Kaligrafi Beşiği', 'Calligraphy Cradle', "Usta Wang Xizhi'nin Orkide Köşkü, kaligrafinin kutsal mekanıdır.", "Master Wang Xizhi's Orchid Pavilion is calligraphy's sacred site."),
  ('boat', '\U0001F6F6', 'Siyah Tenteli Kayık', 'Black-Awning Boats', "Ayakla kürek çekilen wupeng kayıkları kanalların klasiğidir.", "Foot-rowed wupeng boats are the canals' classic ride.")],
 'bengbu': [
  ('shell', '\U0001F41A', 'İnci Limanı', 'Pearl Port', "Adı 'istiridye iskelesi'nden gelir; Huai Nehri incileriyle ünlüydü.", "Its name means 'oyster wharf' — once famed for Huai River pearls."),
  ('train', '\U0001F682', 'Demiryolu Kapısı', 'Rail Gateway', "Kuzey-güney hattının Huai geçidi; şehir istasyonla büyüdü.", "The north-south line's Huai crossing — the city grew with its station."),
  ('river', '\U0001F30A', 'Huai Nehri', 'Huai River', "Çin'in kuzey-güney iklim sınırı kabul edilen nehir buradan akar.", "The river held to divide China's north and south flows here."),
  ('blossom', '\U0001F338', 'Bahar Şenlikleri', 'Spring Fairs', "Nehir kıyısı parkları baharda çiçek şenlikleriyle dolar.", "Riverside parks fill with blossom fairs each spring.")],
 'jiujiang': [
  ('mountain', '\U0001F3D4', 'Lushan Dağı', 'Mount Lu', "UNESCO mirası Lushan'ın sisli zirveleri şair ve ressamların ilhamıdır.", "UNESCO-listed Mount Lu's misty peaks inspired poets and painters."),
  ('tea', '\U0001F375', 'Bulut-Sis Çayı', 'Cloud-Mist Tea', "Lushan'ın yamaçlarında yetişen yunwu çayı Çin'in en incelerindendir.", "Yunwu tea from Lu's slopes is among China's most delicate."),
  ('lake', '\U0001F30A', 'Poyang Gölü', 'Poyang Lake', "Çin'in en büyük tatlı su gölü; kışın binlerce göçmen turna konaklar.", "China's largest freshwater lake hosts thousands of wintering cranes."),
  ('scroll', '\U0001F4DC', 'Şiir Şehri', 'City of Poems', "Bai Juyi ve Su Shi'nin dizeleri bu nehir kapısında yazıldı.", "Bai Juyi's and Su Shi's lines were written at this river gate.")],
 'quanzhou': [
  ('ship', '⛵', 'Deniz İpek Yolu', 'Maritime Silk Road', "Marco Polo'nun 'Zayton'u; ortaçağın en büyük limanı ve UNESCO mirası.", "Marco Polo's 'Zayton' — the medieval world's greatest port, UNESCO-listed."),
  ('mosque', '\U0001F54C', 'Qingjing Camii', 'Qingjing Mosque', "1009 tarihli taş cami, Çin'in en eski camilerindendir.", "The stone mosque of 1009 is among China's oldest."),
  ('puppet', '\U0001F38E', 'Kukla Sanatı', 'Marionette Art', "Quanzhou ipli kuklaları bin yıllık sahne geleneğidir.", "Quanzhou string puppetry is a thousand-year stage tradition."),
  ('tea', '\U0001F375', 'Tieguanyin Çayı', 'Tieguanyin Tea', "Komşu Anxi'nin oolong'u dünyaca ünlü 'Demir Tanrıça' çayıdır.", "Neighbouring Anxi's oolong is the world-famous 'Iron Goddess' tea.")],
}


def codepoints(e):
    return '-'.join(f'{ord(c):x}' for c in e if ord(c) != 0xFE0F)


ic_dir, ph_dir = 'assets/cities', 'assets/landmarks'
ok = fail = 0
for slug, lms in C.items():
    for (icon, emoji, *_r) in lms:
        cp = codepoints(emoji)
        dst = f'{ic_dir}/{slug}-{icon}.png'
        if not os.path.exists(dst):
            r = requests.get(
                f'https://cdn.jsdelivr.net/gh/jdecked/twemoji@15.1.0/assets/72x72/{cp}.png',
                timeout=20)
            if r.status_code != 200:
                r = requests.get(
                    f'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/{cp}.png',
                    timeout=20)
            if r.status_code == 200:
                open(dst, 'wb').write(r.content)
                ok += 1
            else:
                print('MISS', slug, icon, cp)
                fail += 1
        pdst = f'{ph_dir}/{slug}-{icon}.jpg'
        if os.path.exists(dst) and not os.path.exists(pdst):
            shutil.copy(dst, pdst)
print('downloaded:', ok, 'missing:', fail)


def esc(s):
    return s.replace('\\', '\\\\').replace("'", "\\'")


out = []
for slug, lms in C.items():
    out.append(f"  '{slug}': [")
    for (icon, _e, nt, ne, dt, de) in lms:
        out.append(
            f"    Landmark(icon: '{icon}', photo: '{icon}', nameTr: '{esc(nt)}', "
            f"nameEn: '{esc(ne)}', descTr: '{esc(dt)}', descEn: '{esc(de)}'),")
    out.append('  ],')
dart = '\n'.join(out) + '\n'

p = 'lib/core/constants/cities.dart'
src = open(p, encoding='utf-8').read()
marker = "  'beijing': ["
assert marker in src
if "'quanzhou': [" not in src:
    src = src.replace(marker, dart + marker, 1)
    open(p, 'w', encoding='utf-8').write(src)
    print('cities.dart updated')
else:
    print('already present — skipped')
