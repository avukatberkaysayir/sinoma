# One-shot generator: downloads Twemoji landmark icons for every HSK-1 unit
# city and injects the Landmark data into lib/core/constants/cities.dart.
import requests, os, sys, shutil
sys.stdout.reconfigure(encoding='utf-8')

# (icon-slug, emoji, nameTr, nameEn, descTr, descEn) x4 per city.
C = {
 'chengdu': [
  ('panda', '\U0001F43C', '', '', '', ''), ('hotpot', '\U0001F372', '', '', '', ''),
  ('bianlian', '\U0001F3AD', '', '', '', ''), ('jinli', '\U0001F3EE', '', '', '', '')],
 'nanjing': [
  ('citywall', '\U0001F3EF', 'Ming Şehir Suru', 'Ming City Wall', "600 yıllık Ming suru, dünyanın en uzun ayakta kalan şehir duvarıdır.", "The 600-year-old Ming wall is the longest surviving city wall in the world."),
  ('plum', '\U0001F338', 'Erik Çiçeği', 'Plum Blossom', "Nankin'in simge çiçeği; her şubatta Meihua Dağı erik çiçeğiyle pembeye boyanır.", "Nanjing's emblem flower; every February Meihua Hill turns pink with plum blossom."),
  ('duck', '\U0001F986', 'Tuzlu Ördek', 'Salted Duck', "Yumuşacık tuzlanmış ördek, şehrin bin yıllık imza lezzetidir.", "Tender brined duck is the city's thousand-year-old signature dish."),
  ('bridge', '\U0001F309', 'Yangtze Köprüsü', 'Yangtze Bridge', "1968'de tamamen yerli mühendislikle kurulan köprü, modern Çin'in gurur sembolüdür.", "Built in 1968 entirely with local engineering, the bridge is a proud symbol of modern China.")],
 'qingdao': [
  ('beer', '\U0001F37A', 'Tsingtao Birası', 'Tsingtao Beer', "Çin'in en ünlü birası 1903'ten beri bu şehirde üretilir; ağustosta bira festivali kurulur.", "China's most famous beer has been brewed here since 1903, celebrated each August with a festival."),
  ('sailing', '⛵', 'Yelken Kenti', 'Sailing City', "2008 Olimpiyat yelken yarışlarına ev sahipliği yapan marina, kıyının kalbidir.", "Host of the 2008 Olympic sailing races, the marina is the heart of the coast."),
  ('beach', '\U0001F3D6', 'Plajlar', 'Beaches', "Kızıl çatılı Alman mimarisinin önünde uzanan plajlar şehre Akdeniz havası verir.", "Beaches stretching before red-roofed German architecture give the city a Mediterranean air."),
  ('crab', '\U0001F980', 'Deniz Ürünleri', 'Seafood', "İskelede taze deniz mahsulü tezgahları; midye ve deniz kestanesi şehrin klasiğidir.", "Fresh seafood stalls line the piers; clams and sea urchin are local classics.")],
 'changsha': [
  ('pepper', '\U0001F336', 'Acı Biber', 'Chili Pepper', "Hunan mutfağının ruhu; Changsha sofrasında acısız tabak neredeyse yoktur.", "The soul of Hunan cuisine — hardly a Changsha dish arrives without heat."),
  ('tofu', '\U0001F362', 'Kokulu Tofu', 'Stinky Tofu', "Simsiyah kabuklu çıtır kokulu tofu, gece pazarlarının en meşhur atıştırmalığıdır.", "Crisp black-shelled stinky tofu is the night markets' most famous snack."),
  ('fireworks', '\U0001F386', 'Havai Fişek', 'Fireworks', "Komşu Liuyang dünyanın havai fişek başkentidir; nehir kıyısında gösteriler yapılır.", "Neighbouring Liuyang is the fireworks capital of the world; shows light the riverfront."),
  ('orange', '\U0001F34A', 'Portakal Adası', 'Orange Isle', "Xiang Nehri ortasındaki adada genç Mao'nun dev heykeli yükselir.", "On the isle in the Xiang River rises the giant statue of young Mao.")],
 'zhengzhou': [
  ('kungfu', '\U0001F94B', 'Shaolin Kung Fu', 'Shaolin Kung Fu', "Efsanevi Shaolin Tapınağı yakındadır; kung fu'nun doğduğu topraklar burasıdır.", "The legendary Shaolin Temple is nearby — these are the lands where kung fu was born."),
  ('train', '\U0001F684', 'Demiryolu Kavşağı', 'Railway Hub', "Çin'in kuzey-güney ve doğu-batı hatları bu dev kavşakta kesişir.", "China's north-south and east-west rail lines cross at this giant hub."),
  ('wheat', '\U0001F33E', 'Buğday Ovası', 'Wheat Plains', "Sarı Nehir ovasının buğdayı, Çin mutfağının erişte ve mantısını besler.", "Wheat from the Yellow River plain feeds China's noodles and dumplings."),
  ('ding', '\U0001F3FA', 'Tunç Kazanlar', 'Bronze Ding', "Shang hanedanı tunç kazanları burada bulundu; şehir Çin uygarlığının beşiğindedir.", "Shang-dynasty bronze vessels were unearthed here, in the cradle of Chinese civilisation.")],
 'wuxi': [
  ('lake', '\U0001F30A', 'Taihu Gölü', 'Lake Taihu', "Çin'in üçüncü büyük tatlı su gölü; gün batımı tekne turlarıyla ünlüdür.", "China's third-largest freshwater lake, famous for sunset boat cruises."),
  ('peach', '\U0001F351', 'Yangshan Şeftalisi', 'Yangshan Peach', "Bal gibi sulu Yangshan şeftalisi her temmuzda festivalle kutlanır.", "Honey-sweet Yangshan peaches are celebrated with a festival every July."),
  ('figurine', '\U0001F38E', 'Huishan Kil Bebekleri', 'Huishan Clay Figurines', "400 yıllık kil bebek ustalığı; tombul A-Fu figürü şehrin maskotudur.", "A 400-year craft of clay figurines; the chubby A-Fu doll is the city's mascot."),
  ('boat', '\U0001F6A3', 'Kanal Turları', 'Canal Boats', "Büyük Kanal şehrin içinden geçer; eski su kasabası sokakları tekneyle gezilir.", "The Grand Canal runs through town; old water-town lanes are toured by boat.")],
 'nanning': [
  ('tree', '\U0001F333', 'Yeşil Şehir', 'Green City', "Sokakları tropik ağaçlarla örtülü Nanning, 'Çin'in Yeşil Başkenti' diye anılır.", "With streets canopied by tropical trees, Nanning is called China's Green City."),
  ('noodle', '\U0001F35C', 'Laoyou Eriştesi', 'Laoyou Noodles', "Ekşi-acı 'eski dost' eriştesi, nemli günlerin şifalı klasiğidir.", "Sour-spicy 'old friend' noodles are the healing classic of humid days."),
  ('song', '\U0001F3A4', 'Halk Şarkıları', 'Folk Songs', "Zhuang halkının karşılıklı türkü atışmaları her bahar festivale dönüşür.", "Antiphonal Zhuang folk singing turns into a festival every spring."),
  ('mango', '\U0001F96D', 'Tropik Meyveler', 'Tropical Fruit', "Mango, longan ve papaya tezgahları şehrin her köşesindedir.", "Mango, longan and papaya stalls fill every corner of the city.")],
 'nanchang': [
  ('pavilion', '\U0001F3EF', 'Tengwang Köşkü', 'Tengwang Pavilion', "Gan Nehri kıyısındaki bin yıllık köşk, Çin şiirinin en ünlü dizelerine ilham verdi.", "The millennium-old pavilion on the Gan River inspired some of China's most famous verses."),
  ('star', '⭐', '1 Ağustos', 'August 1st', "1927 Nanchang Ayaklanması burada başladı; şehir 'ordunun doğduğu yer'dir.", "The 1927 Nanchang Uprising began here — the city where the army was born."),
  ('porcelain', '\U0001F3FA', 'Porselen Diyarı', 'Porcelain Land', "Komşu Jingdezhen'in porselen ustalığı bu bölgenin bin yıllık mirasıdır.", "Neighbouring Jingdezhen's porcelain mastery is this region's thousand-year legacy."),
  ('sunset', '\U0001F305', 'Gan Nehri Manzarası', 'Gan River View', "Akşamları nehir kıyısı ışık gösterileriyle bambaşka bir yüze bürünür.", "At dusk the riverfront transforms with sweeping light shows.")],
 'yinchuan': [
  ('camel', '\U0001F42B', 'İpek Yolu', 'Silk Road', "Gobi'nin kıyısındaki vaha şehri, kervanların batı kapısıydı.", "An oasis on the Gobi's edge, the city was the caravans' western gate."),
  ('grapes', '\U0001F347', 'Helan Bağları', 'Helan Vineyards', "Helan Dağı etekleri Çin'in en iyi şarap bağlarına ev sahipliği yapar.", "The Helan foothills host China's finest wine vineyards."),
  ('desert', '\U0001F3DC', 'Shapotou Çölü', 'Shapotou Desert', "Kum kayağı ve deve safarisiyle Tengger Çölü'nün ucu turizme açılır.", "Sand-sledding and camel rides open the edge of the Tengger Desert to visitors."),
  ('sheep', '\U0001F411', 'Hui Kuzusu', 'Hui Lamb', "Hui mutfağının kuzu kebabı ve el yapımı eriştesi şehrin gururudur.", "Hui-style lamb skewers and hand-pulled noodles are the city's pride.")],
 'lhasa': [
  ('mountain', '\U0001F3D4', 'Potala Sarayı', 'Potala Palace', "3.700 metrede yükselen kızıl-beyaz saray, Tibet'in kalbidir.", "Rising at 3,700 metres, the red-and-white palace is the heart of Tibet."),
  ('prayer', '\U0001F64F', 'Jokhang Tapınağı', 'Jokhang Temple', "Hacıların secdeyle ulaştığı tapınak, Tibet Budizminin en kutsal yeridir.", "Reached by prostrating pilgrims, the temple is Tibetan Buddhism's holiest site."),
  ('yak', '\U0001F402', 'Yak Kültürü', 'Yak Culture', "Yak; sütü, yünü ve etiyle yayla yaşamının temelidir.", "The yak — its milk, wool and meat — anchors highland life."),
  ('tea', '\U0001F375', 'Tereyağlı Çay', 'Butter Tea', "Tuzlu yak tereyağlı çay, soğuk platonun günlük içeceğidir.", "Salty yak-butter tea is the daily drink of the cold plateau.")],
 'zhuhai': [
  ('shell', '\U0001F41A', 'Balıkçı Kız', 'Fisher Girl', "İnciyi göğe kaldıran Balıkçı Kız heykeli şehrin simgesidir.", "The Fisher Girl statue lifting a pearl to the sky is the city's emblem."),
  ('bridge', '\U0001F309', 'HZM Köprüsü', 'HZM Bridge', "55 km'lik dünyanın en uzun deniz köprüsü buradan başlar.", "The world's longest sea crossing — 55 km — begins here."),
  ('island', '\U0001F3DD', 'Yüz Ada', 'A Hundred Islands', "Kıyıya serpilmiş yüzü aşkın ada, tekne turlarıyla keşfedilir.", "Over a hundred islands speckle the coast, explored by boat."),
  ('lobster', '\U0001F99E', 'Deniz Sofrası', 'Seafood Table', "Sahil lokantalarında ıstakoz ve karides günlük tutulur.", "Beachfront eateries serve lobster and prawns caught daily.")],
 'yantai': [
  ('apple', '\U0001F34E', 'Yantai Elması', 'Yantai Apple', "Çin'in en ünlü elması bu serin kıyı bahçelerinde yetişir.", "China's most famous apples grow in these cool coastal orchards."),
  ('wine', '\U0001F377', 'Changyu Şarabı', 'Changyu Wine', "Çin'in ilk modern şaraphanesi 1892'de burada kuruldu.", "China's first modern winery was founded here in 1892."),
  ('wave', '\U0001F30A', 'Penglai Sahili', 'Penglai Coast', "Efsanelerin 'sekiz ölümsüzü' denize bu kıyıdan açıldı; serap görülen sahildir.", "Legend's Eight Immortals set to sea from this mirage-famous shore."),
  ('cherry', '\U0001F352', 'Kiraz Bahçeleri', 'Cherry Orchards', "Haziranda kiraz toplama bahçeleri ziyaretçiye açılır.", "In June the cherry orchards open for pick-your-own visits.")],
 'datong': [
  ('buddha', '\U0001F5FF', 'Yungang Mağaraları', 'Yungang Grottoes', "5. yüzyıldan kalma 51.000 Buda oyması kaya mağaralarını doldurur.", "51,000 Buddha carvings from the 5th century fill the rock grottoes."),
  ('citywall', '\U0001F3EF', 'Ming Suru', 'Ming Walls', "Restorasyonla ayağa kalkan surlarda gece feneri yürüyüşü yapılır.", "The restored ramparts host lantern-lit night walks."),
  ('noodle', '\U0001F35C', 'Daoxiao Eriştesi', 'Knife-Cut Noodles', "Ustaların bıçakla havada uçurduğu erişte Shanxi'nin gururudur.", "Noodles shaved mid-air by knife-wielding masters are Shanxi's pride."),
  ('lantern', '\U0001F3EE', 'Asma Manastır', 'Hanging Temple', "Uçurum yüzüne çakılı 1500 yıllık manastır nefes kesir.", "The 1,500-year-old monastery pinned to a cliff face takes the breath away.")],
 'baotou': [
  ('horse', '\U0001F40E', 'Bozkır Atları', 'Steppe Horses', "Şehrin adı Moğolca 'geyikli yer'dir; bozkır at kültürü hâlâ canlıdır.", "The city's Mongolian name means 'place with deer'; steppe horse culture lives on."),
  ('deer', '\U0001F98C', 'Geyik Parkı', 'Deer Park', "Kent merkezindeki parkta serbest gezen geyikler şehrin simgesidir.", "Free-roaming deer in the central park are the city's symbol."),
  ('factory', '\U0001F3ED', 'Çelik Kenti', 'Steel City', "Çin'in en büyük çelik üreticilerinden biri burada yükselir.", "One of China's biggest steel producers rises here."),
  ('grass', '\U0001F33F', 'Bozkır Gezileri', 'Grassland Trips', "Bir saat ötede yurtlarda konaklanan uçsuz bozkırlar başlar.", "An hour away begin endless grasslands with yurt stays.")],
 'weifang': [
  ('kite', '\U0001FA81', 'Uçurtma Başkenti', 'Kite Capital', "Dünyanın uçurtma başkenti; her nisanda uluslararası festival göğü doldurur.", "The kite capital of the world — each April an international festival fills the sky."),
  ('woodprint', '\U0001F3A8', 'Yangjiabu Baskıları', 'Yangjiabu Prints', "Yeni yıl tahta baskı resimleri 600 yıldır bu köyde basılır.", "New-year woodblock prints have been made in this village for 600 years."),
  ('dragon', '\U0001F409', 'Ejderha Uçurtmalar', 'Dragon Kites', "Yüz metrelik ejderha uçurtmalar festivalin yıldızıdır.", "Hundred-metre dragon kites are the stars of the festival."),
  ('radish', '\U0001F96C', 'Weifang Turpu', 'Weifang Radish', "'Meyve gibi' yenen yeşil turp şehrin meşhur ikramıdır.", "The green radish, eaten like fruit, is the city's famous treat.")],
 'dezhou': [
  ('chicken', '\U0001F357', 'Dezhou Tavuğu', 'Dezhou Chicken', "Kemiğinden sıyrılan baharatlı haşlama tavuk, imparatorlara sunulurdu.", "Fall-off-the-bone braised chicken was once served to emperors."),
  ('sun', '☀', 'Güneş Vadisi', 'Solar Valley', "Dünyanın en büyük güneş enerjisi kampüslerinden biri buradadır.", "One of the world's largest solar-energy campuses stands here."),
  ('grapes', '\U0001F347', 'Karpuz ve Bağlar', 'Melons and Vines', "Verimli ova yazın karpuz ve üzümle dolar.", "The fertile plain brims with melons and grapes in summer."),
  ('train', '\U0001F682', 'Kanal Limanı', 'Canal Port', "Büyük Kanal döneminin işlek tahıl limanıydı.", "It was a bustling grain port of the Grand Canal era.")],
 'xuzhou': [
  ('stone', '\U0001F5FF', 'Han Taş Kabartmaları', 'Han Stone Reliefs', "Han hanedanı mezar taşları, 2.000 yıllık günlük yaşamı resmeder.", "Han-dynasty tomb stones picture daily life from 2,000 years ago."),
  ('terracotta', '\U0001F3FA', 'Pişmiş Toprak Ordu', 'Terracotta Army', "Xi'an'dakinden küçük ama daha eski bir pişmiş toprak ordu burada bulundu.", "A smaller but older terracotta army was unearthed here."),
  ('lake', '\U0001F30A', 'Yunlong Gölü', 'Yunlong Lake', "'Bulut-Ejderha' gölü çevresi şehrin yeşil nefesidir.", "The Cloud-Dragon lakefront is the city's green lung."),
  ('skewer', '\U0001F362', 'Mangal Kültürü', 'BBQ Culture', "Çin'in mangal başkenti; közde kuzu şişler gece boyu döner.", "China's barbecue capital — lamb skewers turn over coals all night.")],
 'zhenjiang': [
  ('vinegar', '\U0001F376', 'Zhenjiang Sirkesi', 'Zhenjiang Vinegar', "Çin'in en ünlü kara pirinç sirkesi 1.400 yıldır burada mayalanır.", "China's most famous black rice vinegar has fermented here for 1,400 years."),
  ('temple', '⛩', 'Jinshan Tapınağı', 'Jinshan Temple', "Beyaz Yılan efsanesinin geçtiği tapınak nehre bakar.", "The temple of the White Snake legend overlooks the river."),
  ('pot', '\U0001F372', 'Guogai Eriştesi', 'Pot-Lid Noodles', "Tencerede kapakla pişen 'kapak eriştesi' yerel kahvaltı klasiğidir.", "'Pot-lid noodles', cooked under a floating lid, are the local breakfast classic."),
  ('bridge', '\U0001F309', 'Yangtze Kıyısı', 'Yangtze Banks', "Üç tepeli nehir kıyısı yürüyüş parklarıyla çevrilidir.", "The three-hill riverfront is ringed with walking parks.")],
 'jiaxing': [
  ('zongzi', '\U0001F359', 'Zongzi', 'Zongzi', "Bambu yaprağına sarılı pirinç lokması zongzi'nin başkenti burasıdır.", "This is the capital of zongzi — rice parcels wrapped in bamboo leaves."),
  ('boat', '\U0001F6A3', 'Güney Gölü Kayığı', 'South Lake Boat', "1921'de ilk parti kongresi bu göldeki kayıkta toplandı.", "In 1921 the first party congress met on a boat on this lake."),
  ('silk', '\U0001F9F5', 'İpek Diyarı', 'Silk Country', "Jiangnan ipeği yüzyıllardır bu kanal kasabalarında dokunur.", "Jiangnan silk has been woven in these canal towns for centuries."),
  ('canal', '\U0001F309', 'Wuzhen Su Kasabası', 'Wuzhen Water Town', "Taş köprülü, fenerli su kasabaları bir tekne mesafesindedir.", "Stone-bridged, lantern-lit water towns are a boat ride away.")],
 'lishui': [
  ('mountains', '⛰', 'Yeşil Dağlar', 'Green Peaks', "Zhejiang'ın en dağlık köşesi; teraslı köyler buluta değer.", "Zhejiang's most mountainous corner — terraced villages touch the clouds."),
  ('camera', '\U0001F4F7', 'Fotoğraf Cenneti', 'Photo Heaven', "Sisli pirinç terasları Çin'in en çok fotoğraflanan manzaralarındandır.", "Misty rice terraces are among China's most photographed scenes."),
  ('mushroom', '\U0001F344', 'Mantar Diyarı', 'Mushroom Land', "Qingyuan ilçesi dünyanın mantar yetiştiriciliği beşiğidir.", "Qingyuan county is the world's cradle of mushroom farming."),
  ('raft', '\U0001F6F6', 'Nehir Raftingi', 'River Rafting', "Ou Nehri'nin yeşil vadilerinde bambu salla süzülürsün.", "Drift on bamboo rafts through the green gorges of the Ou River.")],
 'anqing': [
  ('opera', '\U0001F3AD', 'Huangmei Operası', 'Huangmei Opera', "Çin'in en sevilen yerel operası bu topraklarda doğdu.", "China's best-loved regional opera was born on these lands."),
  ('pagoda', '\U0001F5FC', 'Zhenfeng Pagodası', 'Zhenfeng Pagoda', "Yangtze'ye bakan 400 yıllık pagoda 'nehrin ilk feneri'dir.", "The 400-year pagoda over the Yangtze is 'the river's first beacon'."),
  ('tea', '\U0001F375', 'Yuexi Çayı', 'Yuexi Tea', "Dabie Dağları'nın yamaçları kokulu yeşil çay verir.", "The Dabie mountain slopes yield fragrant green tea."),
  ('sail', '⛵', 'Nehir Kapısı', 'River Gate', "Anhui'nin Yangtze limanı; adı 'huzurlu kutlama' demektir.", "Anhui's Yangtze port — its name means 'peaceful celebration'.")],
 'ganzhou': [
  ('orange', '\U0001F34A', 'Gannan Portakalı', 'Gannan Navel Orange', "Çin'in en tatlı göbekli portakalı bu kızıl topraklarda yetişir.", "China's sweetest navel oranges grow in these red soils."),
  ('house', '\U0001F3E0', 'Hakka Evleri', 'Hakka Houses', "Yuvarlak kale-evlerde Hakka kültürü yüzyıllardır yaşar.", "Hakka culture has lived for centuries in round fortress homes."),
  ('pavilion', '\U0001F3EF', 'Yugu Köşkü', 'Yugu Pavilion', "Song şairlerinin dizelerine konu olan köşk nehir kavşağına bakar.", "Sung by Song-dynasty poets, the pavilion overlooks the river fork."),
  ('star', '⭐', 'Uzun Yürüyüş', 'Long March', "Kızıl Ordu'nun Uzun Yürüyüşü bu şehirden başladı.", "The Red Army's Long March set out from this city.")],
 'putian': [
  ('shrine', '⛩', 'Mazu Tapınağı', 'Mazu Temple', "Denizcilerin koruyucusu Tanrıça Mazu burada doğdu; ana tapınağı Meizhou adasındadır.", "Goddess Mazu, protector of sailors, was born here; her mother temple stands on Meizhou Isle."),
  ('lychee', '\U0001F352', 'Liçi Bahçeleri', 'Lychee Groves', "Bin yıllık liçi ağaçları şehre 'liçi diyarı' adını verdi.", "Thousand-year-old lychee trees earned the city its 'lychee land' name."),
  ('shoe', '\U0001F45F', 'Ayakkabı Başkenti', 'Shoe Capital', "Dünya spor ayakkabılarının büyük bölümü bu atölyelerden çıkar.", "A huge share of the world's sports shoes comes from these workshops."),
  ('wave', '\U0001F30A', 'Meizhou Adası', 'Meizhou Island', "Feribotla ulaşılan ada, plajları ve tapınak şenlikleriyle ünlüdür.", "Reached by ferry, the island is famed for beaches and temple festivals.")],
}


def codepoints(e):
    return '-'.join(f'{ord(c):x}' for c in e if ord(c) != 0xFE0F)


ic_dir, ph_dir = 'assets/cities', 'assets/landmarks'
os.makedirs(ic_dir, exist_ok=True)
os.makedirs(ph_dir, exist_ok=True)
ok = fail = 0
for slug, lms in C.items():
    for (icon, emoji, *_rest) in lms:
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
        # photo placeholder = same art (PNG bytes behind a .jpg name decode fine)
        pdst = f'{ph_dir}/{slug}-{icon}.jpg'
        if os.path.exists(dst) and not os.path.exists(pdst):
            shutil.copy(dst, pdst)
print('downloaded:', ok, 'missing:', fail)


def esc(s):
    return s.replace('\\', '\\\\').replace("'", "\\'")


out = []
for slug, lms in C.items():
    if slug == 'chengdu':
        continue  # data already in cities.dart (only icons were needed)
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
assert marker in src, 'beijing marker not found'
if "'nanjing': [" not in src:
    src = src.replace(marker, dart + marker, 1)
    open(p, 'w', encoding='utf-8').write(src)
    print('cities.dart updated')
else:
    print('cities.dart already contains nanjing — skipped')
