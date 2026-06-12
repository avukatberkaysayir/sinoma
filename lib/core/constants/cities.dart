// Chinese city names for the learning-path units (one per unit, 144 total).
// The first 96 are the most well-known cities — spread evenly across HSK 1-4
// (24 each) — and the remaining 48 fill HSK 5-6. Unit NAMING only; the grammar
// rules and words assigned to circles / gözat panels are unaffected.

class City {
  final String zh;
  final String pinyin;
  const City(this.zh, this.pinyin);

  // Asset slug: pinyin lowercased, only a-z0-9 (e.g. "Xi'an" → "xian").
  String get slug => pinyin.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

// Turkish display names. ONLY Pekin and Şanghay are real exonyms; every other
// city is the pinyin re-spelled with Turkish letters where the pinyin sound
// has no Turkish letter (w→v, x→ş, q→ç, zh→c, ch→ç, sh→ş, j→c). Cities whose
// pinyin already reads naturally in Turkish are omitted (fallback = pinyin).
const Map<String, String> kCityTrNames = {
  'beijing': 'Pekin', 'shanghai': 'Şanghay',
  'nanjing': 'Nancing', 'guangzhou': 'Guangcou', 'chongqing': 'Çungçing',
  'chengdu': 'Çengdu', 'xian': 'Şian', 'tianjin': 'Tiencin',
  'hangzhou': 'Hangcou', 'wuhan': 'Vuhan', 'shenzhen': 'Şencen',
  'suzhou': 'Sucou', 'qingdao': 'Çingdao', 'urumqi': 'Urumçi',
  'kashgar': 'Kaşgar', 'hongkong': 'Hong Kong', 'macau': 'Makao',
  'changsha': 'Çangşa', 'zhengzhou': 'Cengcou', 'wuxi': 'Vuşi',
  'nanchang': 'Nançang', 'yinchuan': 'Yinçuan', 'zhuhai': 'Cuhay',
  'yantai': 'Yantay', 'weifang': 'Veyfang', 'dezhou': 'Decou',
  'xuzhou': 'Şücou', 'zhenjiang': 'Cenciang', 'jiaxing': 'Ciaşing',
  'lishui': 'Lişuey', 'anqing': 'Ançing', 'ganzhou': 'Gancou',
  'putian': 'Putien', 'mudanjiang': 'Mudanciang', 'changzhou': 'Çangcou',
  'shaoxing': 'Şaoşing', 'jiujiang': 'Ciuciang', 'quanzhou': 'Çüencou',
};

// Korean transcriptions (국립국어원 중국어 표기법) for every path city; the
// long tail falls back to pinyin like the other languages.
const Map<String, String> kCityKoNames = {
  'beijing': '베이징', 'shanghai': '상하이', 'nanjing': '난징',
  'guangzhou': '광저우', 'chongqing': '충칭', 'chengdu': '청두',
  'xian': '시안', 'tianjin': '톈진', 'hangzhou': '항저우',
  'wuhan': '우한', 'shenzhen': '선전', 'suzhou': '쑤저우',
  'qingdao': '칭다오', 'urumqi': '우루무치', 'kashgar': '카슈가르',
  'hongkong': '홍콩', 'macau': '마카오',
  'changsha': '창사', 'zhengzhou': '정저우', 'wuxi': '우시',
  'nanning': '난닝', 'nanchang': '난창', 'yinchuan': '인촨',
  'lhasa': '라싸', 'zhuhai': '주하이', 'yantai': '옌타이',
  'datong': '다퉁', 'baotou': '바오터우', 'weifang': '웨이팡',
  'dezhou': '더저우', 'xuzhou': '쉬저우', 'zhenjiang': '전장',
  'jiaxing': '자싱', 'lishui': '리수이', 'anqing': '안칭',
  'ganzhou': '간저우', 'putian': '푸톈', 'mudanjiang': '무단장',
  'changzhou': '창저우', 'shaoxing': '사오싱', 'bengbu': '벙부',
  'jiujiang': '주장', 'quanzhou': '취안저우',
};

// Locale-aware display name — banners/captions show ONLY this (no hanzi).
String cityDisplayName(City c, {required bool tr}) =>
    tr ? (kCityTrNames[c.slug] ?? c.pinyin) : c.pinyin;

String cityNameFor(City c, String lang) => switch (lang) {
      'tr' => kCityTrNames[c.slug] ?? c.pinyin,
      'ko' => kCityKoNames[c.slug] ?? c.pinyin,
      _ => c.pinyin,
    };

// A landmark of a city: a flat icon (phase circle + banner), a real photo and a
// bilingual blurb (the info panel opened from the banner).
class Landmark {
  final String icon; // assets/cities/<slug>-<icon>.png
  final String photo; // assets/landmarks/<slug>-<photo>.jpg
  final String nameTr;
  final String nameEn;
  final String descTr;
  final String descEn;
  const Landmark({
    required this.icon,
    required this.photo,
    required this.nameTr,
    required this.nameEn,
    required this.descTr,
    required this.descEn,
  });
}

// Cities with a curated 4-landmark set: one per phase circle (in order), the same
// four in the unit banner, and introduced (photo + text) in the banner info panel.
// Cities not listed fall back to a generic themed icon + plain coloured banner.
const Map<String, List<Landmark>> kCityLandmarks = {
  // Chengdu — characteristic culture, not just places: panda, hotpot,
  // face-changing opera, Jinli street. Bundled icon/photo assets can be
  // overridden (or first supplied) per slot from Admin > Anasayfa > Öğren.
  'chengdu': [
    Landmark(
      icon: 'panda',
      photo: 'panda',
      nameTr: 'Dev Panda Üssü',
      nameEn: 'Giant Panda Base',
      descTr:
          'Chengdu Dev Panda Araştırma Üssü, dünyanın en büyük panda koruma ve üreme merkezi. Şehrin sembolü olan pandaları bambu ormanlarında yuvarlanırken görmek için her yıl milyonlarca ziyaretçi gelir.',
      descEn:
          "The Chengdu Research Base of Giant Panda Breeding is the world's largest panda conservation centre. Millions visit yearly to watch the city's beloved symbol tumble through bamboo groves.",
    ),
    Landmark(
      icon: 'hotpot',
      photo: 'hotpot',
      nameTr: 'Sichuan Hotpot',
      nameEn: 'Sichuan Hotpot',
      descTr:
          'Ağzı uyuşturan Sichuan biberi ve kıpkırmızı acı yağıyla kaynayan hotpot, Chengdu sofra kültürünün kalbidir. Masanın ortasındaki kazana herkes kendi lokmasını batırır — yemek burada paylaşılan bir oyundur.',
      descEn:
          'Bubbling with numbing Sichuan peppercorns and fiery red oil, hotpot is the heart of Chengdu dining. Everyone dips their own bite into the shared cauldron — eating here is a communal game.',
    ),
    Landmark(
      icon: 'bianlian',
      photo: 'bianlian',
      nameTr: 'Bian Lian (Yüz Değiştirme)',
      nameEn: 'Bian Lian (Face-Changing)',
      descTr:
          'Sichuan operasının büyülü sanatı Bian Lian\'da ustalar, bir el hareketiyle göz açıp kapayıncaya kadar renkli maskelerini değiştirir. Sırrı kuşaktan kuşağa yalnızca usta-çırak ilişkisiyle aktarılır.',
      descEn:
          'In Bian Lian, the magical art of Sichuan opera, masters swap vivid masks in the blink of an eye with a flick of the hand. The secret passes only from master to apprentice.',
    ),
    Landmark(
      icon: 'jinli',
      photo: 'jinli',
      nameTr: 'Jinli Antik Sokağı',
      nameEn: 'Jinli Ancient Street',
      descTr:
          'Kırmızı fenerlerle aydınlanan Jinli, Üç Krallık dönemine uzanan bir çarşı sokağıdır. Çay evleri, gölge oyunu ve şekerden ejderha çizen ustalarıyla Chengdu\'nun ağır akan yaşam ritmini en iyi burada hissedersin.',
      descEn:
          "Lit by red lanterns, Jinli is a market street tracing back to the Three Kingdoms era. With teahouses, shadow puppetry and sugar-painting masters, it's where Chengdu's famously slow rhythm of life is felt best.",
    ),
  ],
  'nanjing': [
    Landmark(icon: 'citywall', photo: 'citywall', nameTr: 'Ming Şehir Suru', nameEn: 'Ming City Wall', descTr: '600 yıllık Ming suru, dünyanın en uzun ayakta kalan şehir duvarıdır.', descEn: 'The 600-year-old Ming wall is the longest surviving city wall in the world.'),
    Landmark(icon: 'plum', photo: 'plum', nameTr: 'Erik Çiçeği', nameEn: 'Plum Blossom', descTr: 'Nankin\'in simge çiçeği; her şubatta Meihua Dağı erik çiçeğiyle pembeye boyanır.', descEn: 'Nanjing\'s emblem flower; every February Meihua Hill turns pink with plum blossom.'),
    Landmark(icon: 'duck', photo: 'duck', nameTr: 'Tuzlu Ördek', nameEn: 'Salted Duck', descTr: 'Yumuşacık tuzlanmış ördek, şehrin bin yıllık imza lezzetidir.', descEn: 'Tender brined duck is the city\'s thousand-year-old signature dish.'),
    Landmark(icon: 'bridge', photo: 'bridge', nameTr: 'Yangtze Köprüsü', nameEn: 'Yangtze Bridge', descTr: '1968\'de tamamen yerli mühendislikle kurulan köprü, modern Çin\'in gurur sembolüdür.', descEn: 'Built in 1968 entirely with local engineering, the bridge is a proud symbol of modern China.'),
  ],
  'qingdao': [
    Landmark(icon: 'beer', photo: 'beer', nameTr: 'Tsingtao Birası', nameEn: 'Tsingtao Beer', descTr: 'Çin\'in en ünlü birası 1903\'ten beri bu şehirde üretilir; ağustosta bira festivali kurulur.', descEn: 'China\'s most famous beer has been brewed here since 1903, celebrated each August with a festival.'),
    Landmark(icon: 'sailing', photo: 'sailing', nameTr: 'Yelken Kenti', nameEn: 'Sailing City', descTr: '2008 Olimpiyat yelken yarışlarına ev sahipliği yapan marina, kıyının kalbidir.', descEn: 'Host of the 2008 Olympic sailing races, the marina is the heart of the coast.'),
    Landmark(icon: 'beach', photo: 'beach', nameTr: 'Plajlar', nameEn: 'Beaches', descTr: 'Kızıl çatılı Alman mimarisinin önünde uzanan plajlar şehre Akdeniz havası verir.', descEn: 'Beaches stretching before red-roofed German architecture give the city a Mediterranean air.'),
    Landmark(icon: 'crab', photo: 'crab', nameTr: 'Deniz Ürünleri', nameEn: 'Seafood', descTr: 'İskelede taze deniz mahsulü tezgahları; midye ve deniz kestanesi şehrin klasiğidir.', descEn: 'Fresh seafood stalls line the piers; clams and sea urchin are local classics.'),
  ],
  'changsha': [
    Landmark(icon: 'pepper', photo: 'pepper', nameTr: 'Acı Biber', nameEn: 'Chili Pepper', descTr: 'Hunan mutfağının ruhu; Changsha sofrasında acısız tabak neredeyse yoktur.', descEn: 'The soul of Hunan cuisine — hardly a Changsha dish arrives without heat.'),
    Landmark(icon: 'tofu', photo: 'tofu', nameTr: 'Kokulu Tofu', nameEn: 'Stinky Tofu', descTr: 'Simsiyah kabuklu çıtır kokulu tofu, gece pazarlarının en meşhur atıştırmalığıdır.', descEn: 'Crisp black-shelled stinky tofu is the night markets\' most famous snack.'),
    Landmark(icon: 'fireworks', photo: 'fireworks', nameTr: 'Havai Fişek', nameEn: 'Fireworks', descTr: 'Komşu Liuyang dünyanın havai fişek başkentidir; nehir kıyısında gösteriler yapılır.', descEn: 'Neighbouring Liuyang is the fireworks capital of the world; shows light the riverfront.'),
    Landmark(icon: 'orange', photo: 'orange', nameTr: 'Portakal Adası', nameEn: 'Orange Isle', descTr: 'Xiang Nehri ortasındaki adada genç Mao\'nun dev heykeli yükselir.', descEn: 'On the isle in the Xiang River rises the giant statue of young Mao.'),
  ],
  'zhengzhou': [
    Landmark(icon: 'kungfu', photo: 'kungfu', nameTr: 'Shaolin Kung Fu', nameEn: 'Shaolin Kung Fu', descTr: 'Efsanevi Shaolin Tapınağı yakındadır; kung fu\'nun doğduğu topraklar burasıdır.', descEn: 'The legendary Shaolin Temple is nearby — these are the lands where kung fu was born.'),
    Landmark(icon: 'train', photo: 'train', nameTr: 'Demiryolu Kavşağı', nameEn: 'Railway Hub', descTr: 'Çin\'in kuzey-güney ve doğu-batı hatları bu dev kavşakta kesişir.', descEn: 'China\'s north-south and east-west rail lines cross at this giant hub.'),
    Landmark(icon: 'wheat', photo: 'wheat', nameTr: 'Buğday Ovası', nameEn: 'Wheat Plains', descTr: 'Sarı Nehir ovasının buğdayı, Çin mutfağının erişte ve mantısını besler.', descEn: 'Wheat from the Yellow River plain feeds China\'s noodles and dumplings.'),
    Landmark(icon: 'ding', photo: 'ding', nameTr: 'Tunç Kazanlar', nameEn: 'Bronze Ding', descTr: 'Shang hanedanı tunç kazanları burada bulundu; şehir Çin uygarlığının beşiğindedir.', descEn: 'Shang-dynasty bronze vessels were unearthed here, in the cradle of Chinese civilisation.'),
  ],
  'wuxi': [
    Landmark(icon: 'lake', photo: 'lake', nameTr: 'Taihu Gölü', nameEn: 'Lake Taihu', descTr: 'Çin\'in üçüncü büyük tatlı su gölü; gün batımı tekne turlarıyla ünlüdür.', descEn: 'China\'s third-largest freshwater lake, famous for sunset boat cruises.'),
    Landmark(icon: 'peach', photo: 'peach', nameTr: 'Yangshan Şeftalisi', nameEn: 'Yangshan Peach', descTr: 'Bal gibi sulu Yangshan şeftalisi her temmuzda festivalle kutlanır.', descEn: 'Honey-sweet Yangshan peaches are celebrated with a festival every July.'),
    Landmark(icon: 'figurine', photo: 'figurine', nameTr: 'Huishan Kil Bebekleri', nameEn: 'Huishan Clay Figurines', descTr: '400 yıllık kil bebek ustalığı; tombul A-Fu figürü şehrin maskotudur.', descEn: 'A 400-year craft of clay figurines; the chubby A-Fu doll is the city\'s mascot.'),
    Landmark(icon: 'boat', photo: 'boat', nameTr: 'Kanal Turları', nameEn: 'Canal Boats', descTr: 'Büyük Kanal şehrin içinden geçer; eski su kasabası sokakları tekneyle gezilir.', descEn: 'The Grand Canal runs through town; old water-town lanes are toured by boat.'),
  ],
  'nanning': [
    Landmark(icon: 'tree', photo: 'tree', nameTr: 'Yeşil Şehir', nameEn: 'Green City', descTr: 'Sokakları tropik ağaçlarla örtülü Nanning, \'Çin\'in Yeşil Başkenti\' diye anılır.', descEn: 'With streets canopied by tropical trees, Nanning is called China\'s Green City.'),
    Landmark(icon: 'noodle', photo: 'noodle', nameTr: 'Laoyou Eriştesi', nameEn: 'Laoyou Noodles', descTr: 'Ekşi-acı \'eski dost\' eriştesi, nemli günlerin şifalı klasiğidir.', descEn: 'Sour-spicy \'old friend\' noodles are the healing classic of humid days.'),
    Landmark(icon: 'song', photo: 'song', nameTr: 'Halk Şarkıları', nameEn: 'Folk Songs', descTr: 'Zhuang halkının karşılıklı türkü atışmaları her bahar festivale dönüşür.', descEn: 'Antiphonal Zhuang folk singing turns into a festival every spring.'),
    Landmark(icon: 'mango', photo: 'mango', nameTr: 'Tropik Meyveler', nameEn: 'Tropical Fruit', descTr: 'Mango, longan ve papaya tezgahları şehrin her köşesindedir.', descEn: 'Mango, longan and papaya stalls fill every corner of the city.'),
  ],
  'nanchang': [
    Landmark(icon: 'pavilion', photo: 'pavilion', nameTr: 'Tengwang Köşkü', nameEn: 'Tengwang Pavilion', descTr: 'Gan Nehri kıyısındaki bin yıllık köşk, Çin şiirinin en ünlü dizelerine ilham verdi.', descEn: 'The millennium-old pavilion on the Gan River inspired some of China\'s most famous verses.'),
    Landmark(icon: 'star', photo: 'star', nameTr: '1 Ağustos', nameEn: 'August 1st', descTr: '1927 Nanchang Ayaklanması burada başladı; şehir \'ordunun doğduğu yer\'dir.', descEn: 'The 1927 Nanchang Uprising began here — the city where the army was born.'),
    Landmark(icon: 'porcelain', photo: 'porcelain', nameTr: 'Porselen Diyarı', nameEn: 'Porcelain Land', descTr: 'Komşu Jingdezhen\'in porselen ustalığı bu bölgenin bin yıllık mirasıdır.', descEn: 'Neighbouring Jingdezhen\'s porcelain mastery is this region\'s thousand-year legacy.'),
    Landmark(icon: 'sunset', photo: 'sunset', nameTr: 'Gan Nehri Manzarası', nameEn: 'Gan River View', descTr: 'Akşamları nehir kıyısı ışık gösterileriyle bambaşka bir yüze bürünür.', descEn: 'At dusk the riverfront transforms with sweeping light shows.'),
  ],
  'yinchuan': [
    Landmark(icon: 'camel', photo: 'camel', nameTr: 'İpek Yolu', nameEn: 'Silk Road', descTr: 'Gobi\'nin kıyısındaki vaha şehri, kervanların batı kapısıydı.', descEn: 'An oasis on the Gobi\'s edge, the city was the caravans\' western gate.'),
    Landmark(icon: 'grapes', photo: 'grapes', nameTr: 'Helan Bağları', nameEn: 'Helan Vineyards', descTr: 'Helan Dağı etekleri Çin\'in en iyi şarap bağlarına ev sahipliği yapar.', descEn: 'The Helan foothills host China\'s finest wine vineyards.'),
    Landmark(icon: 'desert', photo: 'desert', nameTr: 'Shapotou Çölü', nameEn: 'Shapotou Desert', descTr: 'Kum kayağı ve deve safarisiyle Tengger Çölü\'nün ucu turizme açılır.', descEn: 'Sand-sledding and camel rides open the edge of the Tengger Desert to visitors.'),
    Landmark(icon: 'sheep', photo: 'sheep', nameTr: 'Hui Kuzusu', nameEn: 'Hui Lamb', descTr: 'Hui mutfağının kuzu kebabı ve el yapımı eriştesi şehrin gururudur.', descEn: 'Hui-style lamb skewers and hand-pulled noodles are the city\'s pride.'),
  ],
  'lhasa': [
    Landmark(icon: 'mountain', photo: 'mountain', nameTr: 'Potala Sarayı', nameEn: 'Potala Palace', descTr: '3.700 metrede yükselen kızıl-beyaz saray, Tibet\'in kalbidir.', descEn: 'Rising at 3,700 metres, the red-and-white palace is the heart of Tibet.'),
    Landmark(icon: 'prayer', photo: 'prayer', nameTr: 'Jokhang Tapınağı', nameEn: 'Jokhang Temple', descTr: 'Hacıların secdeyle ulaştığı tapınak, Tibet Budizminin en kutsal yeridir.', descEn: 'Reached by prostrating pilgrims, the temple is Tibetan Buddhism\'s holiest site.'),
    Landmark(icon: 'yak', photo: 'yak', nameTr: 'Yak Kültürü', nameEn: 'Yak Culture', descTr: 'Yak; sütü, yünü ve etiyle yayla yaşamının temelidir.', descEn: 'The yak — its milk, wool and meat — anchors highland life.'),
    Landmark(icon: 'tea', photo: 'tea', nameTr: 'Tereyağlı Çay', nameEn: 'Butter Tea', descTr: 'Tuzlu yak tereyağlı çay, soğuk platonun günlük içeceğidir.', descEn: 'Salty yak-butter tea is the daily drink of the cold plateau.'),
  ],
  'zhuhai': [
    Landmark(icon: 'shell', photo: 'shell', nameTr: 'Balıkçı Kız', nameEn: 'Fisher Girl', descTr: 'İnciyi göğe kaldıran Balıkçı Kız heykeli şehrin simgesidir.', descEn: 'The Fisher Girl statue lifting a pearl to the sky is the city\'s emblem.'),
    Landmark(icon: 'bridge', photo: 'bridge', nameTr: 'HZM Köprüsü', nameEn: 'HZM Bridge', descTr: '55 km\'lik dünyanın en uzun deniz köprüsü buradan başlar.', descEn: 'The world\'s longest sea crossing — 55 km — begins here.'),
    Landmark(icon: 'island', photo: 'island', nameTr: 'Yüz Ada', nameEn: 'A Hundred Islands', descTr: 'Kıyıya serpilmiş yüzü aşkın ada, tekne turlarıyla keşfedilir.', descEn: 'Over a hundred islands speckle the coast, explored by boat.'),
    Landmark(icon: 'lobster', photo: 'lobster', nameTr: 'Deniz Sofrası', nameEn: 'Seafood Table', descTr: 'Sahil lokantalarında ıstakoz ve karides günlük tutulur.', descEn: 'Beachfront eateries serve lobster and prawns caught daily.'),
  ],
  'yantai': [
    Landmark(icon: 'apple', photo: 'apple', nameTr: 'Yantai Elması', nameEn: 'Yantai Apple', descTr: 'Çin\'in en ünlü elması bu serin kıyı bahçelerinde yetişir.', descEn: 'China\'s most famous apples grow in these cool coastal orchards.'),
    Landmark(icon: 'wine', photo: 'wine', nameTr: 'Changyu Şarabı', nameEn: 'Changyu Wine', descTr: 'Çin\'in ilk modern şaraphanesi 1892\'de burada kuruldu.', descEn: 'China\'s first modern winery was founded here in 1892.'),
    Landmark(icon: 'wave', photo: 'wave', nameTr: 'Penglai Sahili', nameEn: 'Penglai Coast', descTr: 'Efsanelerin \'sekiz ölümsüzü\' denize bu kıyıdan açıldı; serap görülen sahildir.', descEn: 'Legend\'s Eight Immortals set to sea from this mirage-famous shore.'),
    Landmark(icon: 'cherry', photo: 'cherry', nameTr: 'Kiraz Bahçeleri', nameEn: 'Cherry Orchards', descTr: 'Haziranda kiraz toplama bahçeleri ziyaretçiye açılır.', descEn: 'In June the cherry orchards open for pick-your-own visits.'),
  ],
  'datong': [
    Landmark(icon: 'buddha', photo: 'buddha', nameTr: 'Yungang Mağaraları', nameEn: 'Yungang Grottoes', descTr: '5. yüzyıldan kalma 51.000 Buda oyması kaya mağaralarını doldurur.', descEn: '51,000 Buddha carvings from the 5th century fill the rock grottoes.'),
    Landmark(icon: 'citywall', photo: 'citywall', nameTr: 'Ming Suru', nameEn: 'Ming Walls', descTr: 'Restorasyonla ayağa kalkan surlarda gece feneri yürüyüşü yapılır.', descEn: 'The restored ramparts host lantern-lit night walks.'),
    Landmark(icon: 'noodle', photo: 'noodle', nameTr: 'Daoxiao Eriştesi', nameEn: 'Knife-Cut Noodles', descTr: 'Ustaların bıçakla havada uçurduğu erişte Shanxi\'nin gururudur.', descEn: 'Noodles shaved mid-air by knife-wielding masters are Shanxi\'s pride.'),
    Landmark(icon: 'lantern', photo: 'lantern', nameTr: 'Asma Manastır', nameEn: 'Hanging Temple', descTr: 'Uçurum yüzüne çakılı 1500 yıllık manastır nefes kesir.', descEn: 'The 1,500-year-old monastery pinned to a cliff face takes the breath away.'),
  ],
  'baotou': [
    Landmark(icon: 'horse', photo: 'horse', nameTr: 'Bozkır Atları', nameEn: 'Steppe Horses', descTr: 'Şehrin adı Moğolca \'geyikli yer\'dir; bozkır at kültürü hâlâ canlıdır.', descEn: 'The city\'s Mongolian name means \'place with deer\'; steppe horse culture lives on.'),
    Landmark(icon: 'deer', photo: 'deer', nameTr: 'Geyik Parkı', nameEn: 'Deer Park', descTr: 'Kent merkezindeki parkta serbest gezen geyikler şehrin simgesidir.', descEn: 'Free-roaming deer in the central park are the city\'s symbol.'),
    Landmark(icon: 'factory', photo: 'factory', nameTr: 'Çelik Kenti', nameEn: 'Steel City', descTr: 'Çin\'in en büyük çelik üreticilerinden biri burada yükselir.', descEn: 'One of China\'s biggest steel producers rises here.'),
    Landmark(icon: 'grass', photo: 'grass', nameTr: 'Bozkır Gezileri', nameEn: 'Grassland Trips', descTr: 'Bir saat ötede yurtlarda konaklanan uçsuz bozkırlar başlar.', descEn: 'An hour away begin endless grasslands with yurt stays.'),
  ],
  'weifang': [
    Landmark(icon: 'kite', photo: 'kite', nameTr: 'Uçurtma Başkenti', nameEn: 'Kite Capital', descTr: 'Dünyanın uçurtma başkenti; her nisanda uluslararası festival göğü doldurur.', descEn: 'The kite capital of the world — each April an international festival fills the sky.'),
    Landmark(icon: 'woodprint', photo: 'woodprint', nameTr: 'Yangjiabu Baskıları', nameEn: 'Yangjiabu Prints', descTr: 'Yeni yıl tahta baskı resimleri 600 yıldır bu köyde basılır.', descEn: 'New-year woodblock prints have been made in this village for 600 years.'),
    Landmark(icon: 'dragon', photo: 'dragon', nameTr: 'Ejderha Uçurtmalar', nameEn: 'Dragon Kites', descTr: 'Yüz metrelik ejderha uçurtmalar festivalin yıldızıdır.', descEn: 'Hundred-metre dragon kites are the stars of the festival.'),
    Landmark(icon: 'radish', photo: 'radish', nameTr: 'Weifang Turpu', nameEn: 'Weifang Radish', descTr: '\'Meyve gibi\' yenen yeşil turp şehrin meşhur ikramıdır.', descEn: 'The green radish, eaten like fruit, is the city\'s famous treat.'),
  ],
  'dezhou': [
    Landmark(icon: 'chicken', photo: 'chicken', nameTr: 'Dezhou Tavuğu', nameEn: 'Dezhou Chicken', descTr: 'Kemiğinden sıyrılan baharatlı haşlama tavuk, imparatorlara sunulurdu.', descEn: 'Fall-off-the-bone braised chicken was once served to emperors.'),
    Landmark(icon: 'sun', photo: 'sun', nameTr: 'Güneş Vadisi', nameEn: 'Solar Valley', descTr: 'Dünyanın en büyük güneş enerjisi kampüslerinden biri buradadır.', descEn: 'One of the world\'s largest solar-energy campuses stands here.'),
    Landmark(icon: 'grapes', photo: 'grapes', nameTr: 'Karpuz ve Bağlar', nameEn: 'Melons and Vines', descTr: 'Verimli ova yazın karpuz ve üzümle dolar.', descEn: 'The fertile plain brims with melons and grapes in summer.'),
    Landmark(icon: 'train', photo: 'train', nameTr: 'Kanal Limanı', nameEn: 'Canal Port', descTr: 'Büyük Kanal döneminin işlek tahıl limanıydı.', descEn: 'It was a bustling grain port of the Grand Canal era.'),
  ],
  'xuzhou': [
    Landmark(icon: 'stone', photo: 'stone', nameTr: 'Han Taş Kabartmaları', nameEn: 'Han Stone Reliefs', descTr: 'Han hanedanı mezar taşları, 2.000 yıllık günlük yaşamı resmeder.', descEn: 'Han-dynasty tomb stones picture daily life from 2,000 years ago.'),
    Landmark(icon: 'terracotta', photo: 'terracotta', nameTr: 'Pişmiş Toprak Ordu', nameEn: 'Terracotta Army', descTr: 'Xi\'an\'dakinden küçük ama daha eski bir pişmiş toprak ordu burada bulundu.', descEn: 'A smaller but older terracotta army was unearthed here.'),
    Landmark(icon: 'lake', photo: 'lake', nameTr: 'Yunlong Gölü', nameEn: 'Yunlong Lake', descTr: '\'Bulut-Ejderha\' gölü çevresi şehrin yeşil nefesidir.', descEn: 'The Cloud-Dragon lakefront is the city\'s green lung.'),
    Landmark(icon: 'skewer', photo: 'skewer', nameTr: 'Mangal Kültürü', nameEn: 'BBQ Culture', descTr: 'Çin\'in mangal başkenti; közde kuzu şişler gece boyu döner.', descEn: 'China\'s barbecue capital — lamb skewers turn over coals all night.'),
  ],
  'zhenjiang': [
    Landmark(icon: 'vinegar', photo: 'vinegar', nameTr: 'Zhenjiang Sirkesi', nameEn: 'Zhenjiang Vinegar', descTr: 'Çin\'in en ünlü kara pirinç sirkesi 1.400 yıldır burada mayalanır.', descEn: 'China\'s most famous black rice vinegar has fermented here for 1,400 years.'),
    Landmark(icon: 'temple', photo: 'temple', nameTr: 'Jinshan Tapınağı', nameEn: 'Jinshan Temple', descTr: 'Beyaz Yılan efsanesinin geçtiği tapınak nehre bakar.', descEn: 'The temple of the White Snake legend overlooks the river.'),
    Landmark(icon: 'pot', photo: 'pot', nameTr: 'Guogai Eriştesi', nameEn: 'Pot-Lid Noodles', descTr: 'Tencerede kapakla pişen \'kapak eriştesi\' yerel kahvaltı klasiğidir.', descEn: '\'Pot-lid noodles\', cooked under a floating lid, are the local breakfast classic.'),
    Landmark(icon: 'bridge', photo: 'bridge', nameTr: 'Yangtze Kıyısı', nameEn: 'Yangtze Banks', descTr: 'Üç tepeli nehir kıyısı yürüyüş parklarıyla çevrilidir.', descEn: 'The three-hill riverfront is ringed with walking parks.'),
  ],
  'jiaxing': [
    Landmark(icon: 'zongzi', photo: 'zongzi', nameTr: 'Zongzi', nameEn: 'Zongzi', descTr: 'Bambu yaprağına sarılı pirinç lokması zongzi\'nin başkenti burasıdır.', descEn: 'This is the capital of zongzi — rice parcels wrapped in bamboo leaves.'),
    Landmark(icon: 'boat', photo: 'boat', nameTr: 'Güney Gölü Kayığı', nameEn: 'South Lake Boat', descTr: '1921\'de ilk parti kongresi bu göldeki kayıkta toplandı.', descEn: 'In 1921 the first party congress met on a boat on this lake.'),
    Landmark(icon: 'silk', photo: 'silk', nameTr: 'İpek Diyarı', nameEn: 'Silk Country', descTr: 'Jiangnan ipeği yüzyıllardır bu kanal kasabalarında dokunur.', descEn: 'Jiangnan silk has been woven in these canal towns for centuries.'),
    Landmark(icon: 'canal', photo: 'canal', nameTr: 'Wuzhen Su Kasabası', nameEn: 'Wuzhen Water Town', descTr: 'Taş köprülü, fenerli su kasabaları bir tekne mesafesindedir.', descEn: 'Stone-bridged, lantern-lit water towns are a boat ride away.'),
  ],
  'lishui': [
    Landmark(icon: 'mountains', photo: 'mountains', nameTr: 'Yeşil Dağlar', nameEn: 'Green Peaks', descTr: 'Zhejiang\'ın en dağlık köşesi; teraslı köyler buluta değer.', descEn: 'Zhejiang\'s most mountainous corner — terraced villages touch the clouds.'),
    Landmark(icon: 'camera', photo: 'camera', nameTr: 'Fotoğraf Cenneti', nameEn: 'Photo Heaven', descTr: 'Sisli pirinç terasları Çin\'in en çok fotoğraflanan manzaralarındandır.', descEn: 'Misty rice terraces are among China\'s most photographed scenes.'),
    Landmark(icon: 'mushroom', photo: 'mushroom', nameTr: 'Mantar Diyarı', nameEn: 'Mushroom Land', descTr: 'Qingyuan ilçesi dünyanın mantar yetiştiriciliği beşiğidir.', descEn: 'Qingyuan county is the world\'s cradle of mushroom farming.'),
    Landmark(icon: 'raft', photo: 'raft', nameTr: 'Nehir Raftingi', nameEn: 'River Rafting', descTr: 'Ou Nehri\'nin yeşil vadilerinde bambu salla süzülürsün.', descEn: 'Drift on bamboo rafts through the green gorges of the Ou River.'),
  ],
  'anqing': [
    Landmark(icon: 'opera', photo: 'opera', nameTr: 'Huangmei Operası', nameEn: 'Huangmei Opera', descTr: 'Çin\'in en sevilen yerel operası bu topraklarda doğdu.', descEn: 'China\'s best-loved regional opera was born on these lands.'),
    Landmark(icon: 'pagoda', photo: 'pagoda', nameTr: 'Zhenfeng Pagodası', nameEn: 'Zhenfeng Pagoda', descTr: 'Yangtze\'ye bakan 400 yıllık pagoda \'nehrin ilk feneri\'dir.', descEn: 'The 400-year pagoda over the Yangtze is \'the river\'s first beacon\'.'),
    Landmark(icon: 'tea', photo: 'tea', nameTr: 'Yuexi Çayı', nameEn: 'Yuexi Tea', descTr: 'Dabie Dağları\'nın yamaçları kokulu yeşil çay verir.', descEn: 'The Dabie mountain slopes yield fragrant green tea.'),
    Landmark(icon: 'sail', photo: 'sail', nameTr: 'Nehir Kapısı', nameEn: 'River Gate', descTr: 'Anhui\'nin Yangtze limanı; adı \'huzurlu kutlama\' demektir.', descEn: 'Anhui\'s Yangtze port — its name means \'peaceful celebration\'.'),
  ],
  'ganzhou': [
    Landmark(icon: 'orange', photo: 'orange', nameTr: 'Gannan Portakalı', nameEn: 'Gannan Navel Orange', descTr: 'Çin\'in en tatlı göbekli portakalı bu kızıl topraklarda yetişir.', descEn: 'China\'s sweetest navel oranges grow in these red soils.'),
    Landmark(icon: 'house', photo: 'house', nameTr: 'Hakka Evleri', nameEn: 'Hakka Houses', descTr: 'Yuvarlak kale-evlerde Hakka kültürü yüzyıllardır yaşar.', descEn: 'Hakka culture has lived for centuries in round fortress homes.'),
    Landmark(icon: 'pavilion', photo: 'pavilion', nameTr: 'Yugu Köşkü', nameEn: 'Yugu Pavilion', descTr: 'Song şairlerinin dizelerine konu olan köşk nehir kavşağına bakar.', descEn: 'Sung by Song-dynasty poets, the pavilion overlooks the river fork.'),
    Landmark(icon: 'star', photo: 'star', nameTr: 'Uzun Yürüyüş', nameEn: 'Long March', descTr: 'Kızıl Ordu\'nun Uzun Yürüyüşü bu şehirden başladı.', descEn: 'The Red Army\'s Long March set out from this city.'),
  ],
  'putian': [
    Landmark(icon: 'shrine', photo: 'shrine', nameTr: 'Mazu Tapınağı', nameEn: 'Mazu Temple', descTr: 'Denizcilerin koruyucusu Tanrıça Mazu burada doğdu; ana tapınağı Meizhou adasındadır.', descEn: 'Goddess Mazu, protector of sailors, was born here; her mother temple stands on Meizhou Isle.'),
    Landmark(icon: 'lychee', photo: 'lychee', nameTr: 'Liçi Bahçeleri', nameEn: 'Lychee Groves', descTr: 'Bin yıllık liçi ağaçları şehre \'liçi diyarı\' adını verdi.', descEn: 'Thousand-year-old lychee trees earned the city its \'lychee land\' name.'),
    Landmark(icon: 'shoe', photo: 'shoe', nameTr: 'Ayakkabı Başkenti', nameEn: 'Shoe Capital', descTr: 'Dünya spor ayakkabılarının büyük bölümü bu atölyelerden çıkar.', descEn: 'A huge share of the world\'s sports shoes comes from these workshops.'),
    Landmark(icon: 'wave', photo: 'wave', nameTr: 'Meizhou Adası', nameEn: 'Meizhou Island', descTr: 'Feribotla ulaşılan ada, plajları ve tapınak şenlikleriyle ünlüdür.', descEn: 'Reached by ferry, the island is famed for beaches and temple festivals.'),
  ],
  'mudanjiang': [
    Landmark(icon: 'snow', photo: 'snow', nameTr: 'Çin Kar Kasabası', nameEn: 'China Snow Town', descTr: 'Kalın kar yastıklarıyla kaplı masal köyü, kışın ışıl ışıl parlar.', descEn: 'A fairy-tale village under thick pillows of snow, glowing in winter.'),
    Landmark(icon: 'lake', photo: 'lake', nameTr: 'Jingpo Gölü', nameEn: 'Jingpo Lake', descTr: 'Volkanik set gölü; Diaoshuilou şelalesi kışın bile dökülür.', descEn: 'A volcanic barrier lake whose Diaoshuilou falls pour even in winter.'),
    Landmark(icon: 'tiger', photo: 'tiger', nameTr: 'Sibirya Kaplanı Parkı', nameEn: 'Siberian Tiger Park', descTr: 'Dünyanın en büyük Sibirya kaplanı koruma merkezlerinden biri.', descEn: 'One of the world\'s largest Siberian tiger sanctuaries.'),
    Landmark(icon: 'ski', photo: 'ski', nameTr: 'Kayak Sezonu', nameEn: 'Ski Season', descTr: 'Uzun ve karlı kış, bölgeyi kayak tutkunlarının rotasına koyar.', descEn: 'Long snowy winters put the region on every skier\'s map.'),
  ],
  'changzhou': [
    Landmark(icon: 'dino', photo: 'dino', nameTr: 'Dinozor Parkı', nameEn: 'Dinosaur Park', descTr: 'Çin\'in en ünlü dinozor temalı parkı aileler için şehrin simgesidir.', descEn: 'China\'s most famous dinosaur theme park is the city\'s family icon.'),
    Landmark(icon: 'pagoda', photo: 'pagoda', nameTr: 'Tianning Pagodası', nameEn: 'Tianning Pagoda', descTr: '153 metreyle dünyanın en yüksek pagodası şehir merkezinde yükselir.', descEn: 'At 153 m, the world\'s tallest pagoda rises downtown.'),
    Landmark(icon: 'comb', photo: 'comb', nameTr: 'Tarak Ustalığı', nameEn: 'Comb Craft', descTr: 'Bin yıllık Changzhou tarağı, imparatorluk saraylarına hediye edilirdi.', descEn: 'Thousand-year Changzhou combs were once palace gifts.'),
    Landmark(icon: 'canal', photo: 'canal', nameTr: 'Büyük Kanal', nameEn: 'Grand Canal', descTr: 'Kanal kıyısı eski mahalleleri ve gece ışıklarıyla gezilir.', descEn: 'The canal banks are strolled for old quarters and night lights.'),
  ],
  'shaoxing': [
    Landmark(icon: 'wine', photo: 'wine', nameTr: 'Shaoxing Şarabı', nameEn: 'Shaoxing Wine', descTr: 'Çin mutfağının ünlü sarı pirinç şarabı binlerce yıldır burada mayalanır.', descEn: 'The famous yellow rice wine of Chinese cooking has been brewed here for millennia.'),
    Landmark(icon: 'bridge', photo: 'bridge', nameTr: 'Taş Köprüler', nameEn: 'Stone Bridges', descTr: 'Kanallar şehri Shaoxing\'de yüzlerce kavisli taş köprü vardır.', descEn: 'Canal-laced Shaoxing keeps hundreds of arched stone bridges.'),
    Landmark(icon: 'pen', photo: 'pen', nameTr: 'Kaligrafi Beşiği', nameEn: 'Calligraphy Cradle', descTr: 'Usta Wang Xizhi\'nin Orkide Köşkü, kaligrafinin kutsal mekanıdır.', descEn: 'Master Wang Xizhi\'s Orchid Pavilion is calligraphy\'s sacred site.'),
    Landmark(icon: 'boat', photo: 'boat', nameTr: 'Siyah Tenteli Kayık', nameEn: 'Black-Awning Boats', descTr: 'Ayakla kürek çekilen wupeng kayıkları kanalların klasiğidir.', descEn: 'Foot-rowed wupeng boats are the canals\' classic ride.'),
  ],
  'bengbu': [
    Landmark(icon: 'shell', photo: 'shell', nameTr: 'İnci Limanı', nameEn: 'Pearl Port', descTr: 'Adı \'istiridye iskelesi\'nden gelir; Huai Nehri incileriyle ünlüydü.', descEn: 'Its name means \'oyster wharf\' — once famed for Huai River pearls.'),
    Landmark(icon: 'train', photo: 'train', nameTr: 'Demiryolu Kapısı', nameEn: 'Rail Gateway', descTr: 'Kuzey-güney hattının Huai geçidi; şehir istasyonla büyüdü.', descEn: 'The north-south line\'s Huai crossing — the city grew with its station.'),
    Landmark(icon: 'river', photo: 'river', nameTr: 'Huai Nehri', nameEn: 'Huai River', descTr: 'Çin\'in kuzey-güney iklim sınırı kabul edilen nehir buradan akar.', descEn: 'The river held to divide China\'s north and south flows here.'),
    Landmark(icon: 'blossom', photo: 'blossom', nameTr: 'Bahar Şenlikleri', nameEn: 'Spring Fairs', descTr: 'Nehir kıyısı parkları baharda çiçek şenlikleriyle dolar.', descEn: 'Riverside parks fill with blossom fairs each spring.'),
  ],
  'jiujiang': [
    Landmark(icon: 'mountain', photo: 'mountain', nameTr: 'Lushan Dağı', nameEn: 'Mount Lu', descTr: 'UNESCO mirası Lushan\'ın sisli zirveleri şair ve ressamların ilhamıdır.', descEn: 'UNESCO-listed Mount Lu\'s misty peaks inspired poets and painters.'),
    Landmark(icon: 'tea', photo: 'tea', nameTr: 'Bulut-Sis Çayı', nameEn: 'Cloud-Mist Tea', descTr: 'Lushan\'ın yamaçlarında yetişen yunwu çayı Çin\'in en incelerindendir.', descEn: 'Yunwu tea from Lu\'s slopes is among China\'s most delicate.'),
    Landmark(icon: 'lake', photo: 'lake', nameTr: 'Poyang Gölü', nameEn: 'Poyang Lake', descTr: 'Çin\'in en büyük tatlı su gölü; kışın binlerce göçmen turna konaklar.', descEn: 'China\'s largest freshwater lake hosts thousands of wintering cranes.'),
    Landmark(icon: 'scroll', photo: 'scroll', nameTr: 'Şiir Şehri', nameEn: 'City of Poems', descTr: 'Bai Juyi ve Su Shi\'nin dizeleri bu nehir kapısında yazıldı.', descEn: 'Bai Juyi\'s and Su Shi\'s lines were written at this river gate.'),
  ],
  'quanzhou': [
    Landmark(icon: 'ship', photo: 'ship', nameTr: 'Deniz İpek Yolu', nameEn: 'Maritime Silk Road', descTr: 'Marco Polo\'nun \'Zayton\'u; ortaçağın en büyük limanı ve UNESCO mirası.', descEn: 'Marco Polo\'s \'Zayton\' — the medieval world\'s greatest port, UNESCO-listed.'),
    Landmark(icon: 'mosque', photo: 'mosque', nameTr: 'Qingjing Camii', nameEn: 'Qingjing Mosque', descTr: '1009 tarihli taş cami, Çin\'in en eski camilerindendir.', descEn: 'The stone mosque of 1009 is among China\'s oldest.'),
    Landmark(icon: 'puppet', photo: 'puppet', nameTr: 'Kukla Sanatı', nameEn: 'Marionette Art', descTr: 'Quanzhou ipli kuklaları bin yıllık sahne geleneğidir.', descEn: 'Quanzhou string puppetry is a thousand-year stage tradition.'),
    Landmark(icon: 'tea', photo: 'tea', nameTr: 'Tieguanyin Çayı', nameEn: 'Tieguanyin Tea', descTr: 'Komşu Anxi\'nin oolong\'u dünyaca ünlü \'Demir Tanrıça\' çayıdır.', descEn: 'Neighbouring Anxi\'s oolong is the world-famous \'Iron Goddess\' tea.'),
  ],
  'beijing': [
    Landmark(
      icon: 'great-wall',
      photo: 'great-wall',
      nameTr: 'Çin Seddi',
      nameEn: 'Great Wall',
      descTr:
          'Kuzey sınırlarını korumak için yüzyıllar boyunca inşa edilen, 20.000 km\'yi aşan dünyanın en uzun savunma yapısı. Pekin\'e en yakın Badaling kesimi; taş basamakları, surları ve sırtlar boyunca uzanan gözetleme kuleleriyle en çok ziyaret edilen bölümdür.',
      descEn:
          "The world's longest fortification — over 20,000 km built across centuries to guard China's northern frontier. The Badaling section near Beijing, with its stone steps and ridge-top watchtowers, is the most visited stretch.",
    ),
    Landmark(
      icon: 'temple',
      photo: 'temple',
      nameTr: 'Cennet Tapınağı',
      nameEn: 'Temple of Heaven',
      descTr:
          'Ming ve Qing imparatorlarının her yıl bol hasat için gökyüzüne dua ettiği kutsal tapınak kompleksi. Tek bir çivi kullanılmadan inşa edilen üç katmanlı yuvarlak mavi çatısı, Çin mimarisinin en tanınan simgelerinden biridir.',
      descEn:
          'A sacred complex where Ming and Qing emperors prayed to heaven each year for a good harvest. Its three-tiered round blue roof — built without a single nail — is one of the most recognised icons of Chinese architecture.',
    ),
    Landmark(
      icon: 'pagoda',
      photo: 'pagoda',
      nameTr: 'Tianning Pagodası',
      nameEn: 'Tianning Pagoda',
      descTr:
          'Liao Hanedanı\'ndan kalma, yaklaşık 57 metre yüksekliğinde 13 katlı tuğla pagoda. Oymalı kabartmaları ve sekizgen gövdesiyle Pekin\'in ayakta kalan en eski yapılarından biridir ve şehrin bin yıllık geçmişine tanıklık eder.',
      descEn:
          "A ~57 m, 13-tier brick pagoda from the Liao dynasty. With its carved reliefs and octagonal body, it is one of Beijing's oldest surviving structures — a witness to the city's thousand-year history.",
    ),
    Landmark(
      icon: 'opera',
      photo: 'opera',
      nameTr: 'Pekin Operası',
      nameEn: 'Beijing Opera',
      descTr:
          'Şarkı, konuşma, dövüş sanatları ve akrobasinin birleştiği 200 yıllık geleneksel Çin sahne sanatı. Oyuncuların renkli yüz makyajı (lianpu) her karakterin kişiliğini anlatır: kırmızı sadakati, beyaz kurnazlığı simgeler.',
      descEn:
          "A 200-year-old traditional Chinese theatre fusing song, speech, martial arts and acrobatics. The performers' painted faces (lianpu) reveal each character: red for loyalty, white for cunning.",
    ),
  ],
};

String cityIconAsset(String slug, String name) =>
    'assets/cities/$slug-$name.png';

String cityPhotoAsset(String slug, String photo) =>
    'assets/landmarks/$slug-$photo.jpg';

const List<City> kChineseCities = [
  // ── Most well-known (0-95) → HSK 1-4 ────────────────────────────────────────
  City('北京', 'Beijing'), City('上海', 'Shanghai'), City('广州', 'Guangzhou'),
  City('深圳', 'Shenzhen'), City('成都', 'Chengdu'), City('杭州', 'Hangzhou'),
  City('武汉', 'Wuhan'), City('西安', "Xi'an"), City('南京', 'Nanjing'),
  City('重庆', 'Chongqing'), City('天津', 'Tianjin'), City('苏州', 'Suzhou'),
  City('青岛', 'Qingdao'), City('大连', 'Dalian'), City('厦门', 'Xiamen'),
  City('昆明', 'Kunming'), City('长沙', 'Changsha'), City('沈阳', 'Shenyang'),
  City('哈尔滨', 'Harbin'), City('济南', 'Jinan'), City('郑州', 'Zhengzhou'),
  City('合肥', 'Hefei'), City('福州', 'Fuzhou'), City('宁波', 'Ningbo'),
  City('无锡', 'Wuxi'), City('佛山', 'Foshan'), City('东莞', 'Dongguan'),
  City('石家庄', 'Shijiazhuang'), City('南宁', 'Nanning'), City('贵阳', 'Guiyang'),
  City('兰州', 'Lanzhou'), City('太原', 'Taiyuan'), City('南昌', 'Nanchang'),
  City('长春', 'Changchun'), City('乌鲁木齐', 'Urumqi'), City('呼和浩特', 'Hohhot'),
  City('银川', 'Yinchuan'), City('西宁', 'Xining'), City('海口', 'Haikou'),
  City('三亚', 'Sanya'), City('拉萨', 'Lhasa'), City('桂林', 'Guilin'),
  City('洛阳', 'Luoyang'), City('扬州', 'Yangzhou'), City('珠海', 'Zhuhai'),
  City('温州', 'Wenzhou'), City('汕头', 'Shantou'), City('威海', 'Weihai'),
  City('烟台', 'Yantai'), City('唐山', 'Tangshan'), City('保定', 'Baoding'),
  City('邯郸', 'Handan'), City('大同', 'Datong'), City('鞍山', 'Anshan'),
  City('吉林', 'Jilin'), City('大庆', 'Daqing'), City('牡丹江', 'Mudanjiang'),
  City('包头', 'Baotou'), City('鄂尔多斯', 'Ordos'), City('淄博', 'Zibo'),
  City('潍坊', 'Weifang'), City('临沂', 'Linyi'), City('济宁', 'Jining'),
  City('泰安', "Tai'an"), City('德州', 'Dezhou'), City('沧州', 'Cangzhou'),
  City('廊坊', 'Langfang'), City('徐州', 'Xuzhou'), City('常州', 'Changzhou'),
  City('南通', 'Nantong'), City('盐城', 'Yancheng'), City('连云港', 'Lianyungang'),
  City('镇江', 'Zhenjiang'), City('泰州', 'Taizhou'), City('湖州', 'Huzhou'),
  City('嘉兴', 'Jiaxing'), City('绍兴', 'Shaoxing'), City('金华', 'Jinhua'),
  City('衢州', 'Quzhou'), City('丽水', 'Lishui'), City('蚌埠', 'Bengbu'),
  City('芜湖', 'Wuhu'), City('淮南', 'Huainan'), City('马鞍山', "Ma'anshan"),
  City('安庆', 'Anqing'), City('黄山', 'Huangshan'), City('景德镇', 'Jingdezhen'),
  City('赣州', 'Ganzhou'), City('九江', 'Jiujiang'), City('宜春', 'Yichun'),
  City('吉安', "Ji'an"), City('莆田', 'Putian'), City('泉州', 'Quanzhou'),
  City('漳州', 'Zhangzhou'), City('南平', 'Nanping'), City('龙岩', 'Longyan'),
  // ── Remaining (96-143) → HSK 5-6 ────────────────────────────────────────────
  City('三明', 'Sanming'), City('宁德', 'Ningde'), City('韶关', 'Shaoguan'),
  City('湛江', 'Zhanjiang'), City('茂名', 'Maoming'), City('肇庆', 'Zhaoqing'),
  City('惠州', 'Huizhou'), City('梅州', 'Meizhou'), City('江门', 'Jiangmen'),
  City('阳江', 'Yangjiang'), City('清远', 'Qingyuan'), City('潮州', 'Chaozhou'),
  City('揭阳', 'Jieyang'), City('云浮', 'Yunfu'), City('柳州', 'Liuzhou'),
  City('梧州', 'Wuzhou'), City('北海', 'Beihai'), City('钦州', 'Qinzhou'),
  City('贵港', 'Guigang'), City('玉林', 'Yulin'), City('百色', 'Baise'),
  City('河池', 'Hechi'), City('来宾', 'Laibin'), City('崇左', 'Chongzuo'),
  City('遵义', 'Zunyi'), City('六盘水', 'Liupanshui'), City('安顺', 'Anshun'),
  City('毕节', 'Bijie'), City('曲靖', 'Qujing'), City('玉溪', 'Yuxi'),
  City('大理', 'Dali'), City('丽江', 'Lijiang'), City('临沧', 'Lincang'),
  City('普洱', "Pu'er"), City('保山', 'Baoshan'), City('德阳', 'Deyang'),
  City('绵阳', 'Mianyang'), City('南充', 'Nanchong'), City('宜宾', 'Yibin'),
  City('泸州', 'Luzhou'), City('乐山', 'Leshan'), City('自贡', 'Zigong'),
  City('攀枝花', 'Panzhihua'), City('达州', 'Dazhou'), City('广元', 'Guangyuan'),
  City('雅安', "Ya'an"), City('咸阳', 'Xianyang'), City('宝鸡', 'Baoji'),
];

// City for a unit. HSK 1-4 draw round-robin from the 96 well-known cities so each
// level gets an even popularity spread; HSK 5-6 take the remaining 48 in order.
City cityForUnit(int hsk, int unitIndex) {
  final int idx;
  if (hsk <= 4) {
    idx = unitIndex * 4 + (hsk - 1);
  } else {
    idx = 96 + (hsk - 5) * 24 + unitIndex;
  }
  return kChineseCities[idx.clamp(0, kChineseCities.length - 1)];
}
