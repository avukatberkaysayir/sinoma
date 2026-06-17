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

// Japanese readings for every path city; well-known cities use their common
// Japanese forms (often katakana approximating Mandarin), the rest the kanji
// on'yomi reading. The long tail falls back to pinyin like the other languages.
const Map<String, String> kCityJaNames = {
  'beijing': 'ペキン', 'shanghai': 'シャンハイ', 'nanjing': 'ナンキン',
  'guangzhou': 'コウシュウ', 'chongqing': 'じゅうけい', 'chengdu': 'せいと',
  'xian': 'シーアン', 'tianjin': 'テンシン', 'hangzhou': 'こうしゅう',
  'wuhan': 'ぶかん', 'shenzhen': 'シンセン', 'suzhou': 'そしゅう',
  'qingdao': 'チンタオ', 'urumqi': 'ウルムチ', 'kashgar': 'カシュガル',
  'hongkong': 'ホンコン', 'macau': 'マカオ',
  'changsha': 'ちょうさ', 'zhengzhou': 'ていしゅう', 'wuxi': 'むしゃく',
  'nanning': 'ナンネイ', 'nanchang': 'ナンショウ', 'yinchuan': 'ぎんせん',
  'lhasa': 'ラサ', 'zhuhai': 'しゅかい', 'yantai': 'えんだい',
  'datong': 'だいどう', 'baotou': 'パオトウ', 'weifang': 'いぼう',
  'dezhou': 'とくしゅう', 'xuzhou': 'じょしゅう', 'zhenjiang': 'ちんこう',
  'jiaxing': 'かこう', 'lishui': 'れいすい', 'anqing': 'あんけい',
  'ganzhou': 'かんしゅう', 'putian': 'ほでん', 'mudanjiang': 'ぼたんこう',
  'changzhou': 'じょうしゅう', 'shaoxing': 'しょうこう', 'bengbu': 'ホウフ',
  'jiujiang': 'きゅうこう', 'quanzhou': 'せんしゅう',
};

// Indonesian uses pinyin spelling for almost all Chinese cities; only a few
// have an established Indonesian exonym. The long tail falls back to pinyin.
const Map<String, String> kCityIdNames = {
  'beijing': 'Beijing', 'hongkong': 'Hong Kong', 'macau': 'Makau',
};

// Sino-Vietnamese (Hán-Việt) readings — Vietnamese uses these established
// exonyms for Chinese cities. The long tail falls back to pinyin.
const Map<String, String> kCityViNames = {
  'beijing': 'Bắc Kinh', 'shanghai': 'Thượng Hải', 'nanjing': 'Nam Kinh',
  'guangzhou': 'Quảng Châu', 'chongqing': 'Trùng Khánh', 'chengdu': 'Thành Đô',
  'xian': 'Tây An', 'tianjin': 'Thiên Tân', 'hangzhou': 'Hàng Châu',
  'wuhan': 'Vũ Hán', 'shenzhen': 'Thâm Quyến', 'suzhou': 'Tô Châu',
  'qingdao': 'Thanh Đảo', 'urumqi': 'Urumqi', 'kashgar': 'Kashgar',
  'hongkong': 'Hồng Kông', 'macau': 'Ma Cao',
  'changsha': 'Trường Sa', 'zhengzhou': 'Trịnh Châu', 'wuxi': 'Vô Tích',
  'nanning': 'Nam Ninh', 'nanchang': 'Nam Xương', 'yinchuan': 'Ngân Xuyên',
  'lhasa': 'Lhasa', 'zhuhai': 'Châu Hải', 'yantai': 'Yên Đài',
  'datong': 'Đại Đồng', 'baotou': 'Bao Đầu', 'weifang': 'Duy Phường',
  'dezhou': 'Đức Châu', 'xuzhou': 'Từ Châu', 'zhenjiang': 'Trấn Giang',
  'jiaxing': 'Gia Hưng', 'lishui': 'Lệ Thủy', 'anqing': 'An Khánh',
  'ganzhou': 'Cám Châu', 'putian': 'Bồ Điền', 'mudanjiang': 'Mẫu Đơn Giang',
  'changzhou': 'Thường Châu', 'shaoxing': 'Thiệu Hưng', 'bengbu': 'Bạng Phụ',
  'jiujiang': 'Cửu Giang', 'quanzhou': 'Tuyền Châu',
};

// Thai-script transcriptions of Chinese cities. The long tail falls back to pinyin.
const Map<String, String> kCityThNames = {
  'beijing': 'ปักกิ่ง', 'shanghai': 'เซี่ยงไฮ้', 'nanjing': 'หนานจิง',
  'guangzhou': 'กว่างโจว', 'chongqing': 'ฉงชิ่ง', 'chengdu': 'เฉิงตู',
  'xian': 'ซีอาน', 'tianjin': 'เทียนจิน', 'hangzhou': 'หางโจว',
  'wuhan': 'อู่ฮั่น', 'shenzhen': 'เซินเจิ้น', 'suzhou': 'ซูโจว',
  'qingdao': 'ชิงเต่า', 'urumqi': 'อุรุมชี', 'kashgar': 'คัชการ์',
  'hongkong': 'ฮ่องกง', 'macau': 'มาเก๊า',
  'changsha': 'ฉางซา', 'zhengzhou': 'เจิ้งโจว', 'wuxi': 'อู๋ซี',
  'nanning': 'หนานหนิง', 'nanchang': 'หนานชาง', 'yinchuan': 'อิ๋นชวน',
  'lhasa': 'ลาซา', 'zhuhai': 'จูไห่', 'yantai': 'เยียนไถ',
  'datong': 'ต้าถง', 'baotou': 'เปาโถว', 'weifang': 'เหวยฟาง',
  'dezhou': 'เต๋อโจว', 'xuzhou': 'สวีโจว', 'zhenjiang': 'เจิ้นเจียง',
  'jiaxing': 'เจียซิง', 'lishui': 'ลี่สุ่ย', 'anqing': 'อันชิ่ง',
  'ganzhou': 'ก้านโจว', 'putian': 'ผูเถียน', 'mudanjiang': 'มู่ตันเจียง',
  'changzhou': 'ฉางโจว', 'shaoxing': 'เซ่าซิง', 'bengbu': 'ปังปู้',
  'jiujiang': 'จิ่วเจียง', 'quanzhou': 'เฉวียนโจว',
};

const Map<String, String> kCityRuNames = {
  'beijing': 'Пекин', 'shanghai': 'Шанхай', 'nanjing': 'Нанкин',
  'guangzhou': 'Гуанчжоу', 'chongqing': 'Чунцин', 'chengdu': 'Чэнду',
  'xian': 'Сиань', 'tianjin': 'Тяньцзинь', 'hangzhou': 'Ханчжоу',
  'wuhan': 'Ухань', 'shenzhen': 'Шэньчжэнь', 'suzhou': 'Сучжоу',
  'qingdao': 'Циндао', 'urumqi': 'Урумчи', 'kashgar': 'Кашгар',
  'hongkong': 'Гонконг', 'macau': 'Макао',
  'changsha': 'Чанша', 'zhengzhou': 'Чжэнчжоу', 'wuxi': 'Уси',
  'nanning': 'Наньнин', 'nanchang': 'Наньчан', 'yinchuan': 'Иньчуань',
  'lhasa': 'Лхаса', 'zhuhai': 'Чжухай', 'yantai': 'Яньтай',
  'datong': 'Датун', 'baotou': 'Баотоу', 'weifang': 'Вэйфан',
  'dezhou': 'Дэчжоу', 'xuzhou': 'Сюйчжоу', 'zhenjiang': 'Чжэньцзян',
  'jiaxing': 'Цзясин', 'lishui': 'Лишуй', 'anqing': 'Аньцин',
  'ganzhou': 'Ганьчжоу', 'putian': 'Путянь', 'mudanjiang': 'Муданьцзян',
  'changzhou': 'Чанчжоу', 'shaoxing': 'Шаосин', 'bengbu': 'Бэнбу',
  'jiujiang': 'Цзюцзян', 'quanzhou': 'Цюаньчжоу',
};

const Map<String, String> kCityEsNames = {
  'beijing': 'Pekín', 'shanghai': 'Shanghái', 'nanjing': 'Nankín',
  'guangzhou': 'Cantón', 'chongqing': 'Chongqing', 'chengdu': 'Chengdú',
  'xian': 'Xi\'an', 'tianjin': 'Tianjin', 'hangzhou': 'Hangzhou',
  'wuhan': 'Wuhan', 'shenzhen': 'Shenzhen', 'suzhou': 'Suzhou',
  'qingdao': 'Qingdao', 'urumqi': 'Ürümqi', 'kashgar': 'Kasgar',
  'hongkong': 'Hong Kong', 'macau': 'Macao',
  'changsha': 'Changsha', 'zhengzhou': 'Zhengzhou', 'wuxi': 'Wuxi',
  'nanning': 'Nanning', 'nanchang': 'Nanchang', 'yinchuan': 'Yinchuan',
  'lhasa': 'Lhasa', 'zhuhai': 'Zhuhai', 'yantai': 'Yantai',
  'datong': 'Datong', 'baotou': 'Baotou', 'weifang': 'Weifang',
  'dezhou': 'Dezhou', 'xuzhou': 'Xuzhou', 'zhenjiang': 'Zhenjiang',
  'jiaxing': 'Jiaxing', 'lishui': 'Lishui', 'anqing': 'Anqing',
  'ganzhou': 'Ganzhou', 'putian': 'Putian', 'mudanjiang': 'Mudanjiang',
  'changzhou': 'Changzhou', 'shaoxing': 'Shaoxing', 'bengbu': 'Bengbu',
  'jiujiang': 'Jiujiang', 'quanzhou': 'Quanzhou',
};

const Map<String, String> kCityPtNames = {
  'beijing': 'Pequim', 'shanghai': 'Xangai', 'nanjing': 'Nanquim',
  'guangzhou': 'Cantão', 'chongqing': 'Chongqing', 'chengdu': 'Chengdu',
  'xian': 'Xian', 'tianjin': 'Tianjin', 'hangzhou': 'Hangzhou',
  'wuhan': 'Wuhan', 'shenzhen': 'Shenzhen', 'suzhou': 'Suzhou',
  'qingdao': 'Qingdao', 'urumqi': 'Urumqi', 'kashgar': 'Kashgar',
  'hongkong': 'Hong Kong', 'macau': 'Macau',
  'changsha': 'Changsha', 'zhengzhou': 'Zhengzhou', 'wuxi': 'Wuxi',
  'nanning': 'Nanning', 'nanchang': 'Nanchang', 'yinchuan': 'Yinchuan',
  'lhasa': 'Lhasa', 'zhuhai': 'Zhuhai', 'yantai': 'Yantai',
  'datong': 'Datong', 'baotou': 'Baotou', 'weifang': 'Weifang',
  'dezhou': 'Dezhou', 'xuzhou': 'Xuzhou', 'zhenjiang': 'Zhenjiang',
  'jiaxing': 'Jiaxing', 'lishui': 'Lishui', 'anqing': 'Anqing',
  'ganzhou': 'Ganzhou', 'putian': 'Putian', 'mudanjiang': 'Mudanjiang',
  'changzhou': 'Changzhou', 'shaoxing': 'Shaoxing', 'bengbu': 'Bengbu',
  'jiujiang': 'Jiujiang', 'quanzhou': 'Quanzhou',
};

const Map<String, String> kCityFrNames = {
  'beijing': 'Pékin', 'shanghai': 'Shanghai', 'nanjing': 'Nankin',
  'guangzhou': 'Canton', 'chongqing': 'Chongqing', 'chengdu': 'Chengdu',
  'xian': 'Xi\'an', 'tianjin': 'Tianjin', 'hangzhou': 'Hangzhou',
  'wuhan': 'Wuhan', 'shenzhen': 'Shenzhen', 'suzhou': 'Suzhou',
  'qingdao': 'Qingdao', 'urumqi': 'Ürümqi', 'kashgar': 'Kachgar',
  'hongkong': 'Hong Kong', 'macau': 'Macao',
  'changsha': 'Changsha', 'zhengzhou': 'Zhengzhou', 'wuxi': 'Wuxi',
  'nanning': 'Nanning', 'nanchang': 'Nanchang', 'yinchuan': 'Yinchuan',
  'lhasa': 'Lhassa', 'zhuhai': 'Zhuhai', 'yantai': 'Yantai',
  'datong': 'Datong', 'baotou': 'Baotou', 'weifang': 'Weifang',
  'dezhou': 'Dezhou', 'xuzhou': 'Xuzhou', 'zhenjiang': 'Zhenjiang',
  'jiaxing': 'Jiaxing', 'lishui': 'Lishui', 'anqing': 'Anqing',
  'ganzhou': 'Ganzhou', 'putian': 'Putian', 'mudanjiang': 'Mudanjiang',
  'changzhou': 'Changzhou', 'shaoxing': 'Shaoxing', 'bengbu': 'Bengbu',
  'jiujiang': 'Jiujiang', 'quanzhou': 'Quanzhou',
};

const Map<String, String> kCityArNames = {
  'beijing': 'بكين', 'shanghai': 'شنغهاي', 'nanjing': 'نانجينغ',
  'guangzhou': 'قوانغجو', 'chongqing': 'تشونغتشينغ', 'chengdu': 'تشنغدو',
  'xian': 'شيان', 'tianjin': 'تيانجين', 'hangzhou': 'هانغجو',
  'wuhan': 'ووهان', 'shenzhen': 'شنجن', 'suzhou': 'سوجو',
  'qingdao': 'تشينغداو', 'urumqi': 'أورومتشي', 'kashgar': 'كاشغر',
  'hongkong': 'هونغ كونغ', 'macau': 'ماكاو',
  'changsha': 'تشانغشا', 'zhengzhou': 'تشنغجو', 'wuxi': 'ووشي',
  'nanning': 'نانينغ', 'nanchang': 'نانتشانغ', 'yinchuan': 'ينتشوان',
  'lhasa': 'لاسا', 'zhuhai': 'تشوهاي', 'yantai': 'يانتاي',
  'datong': 'داتونغ', 'baotou': 'باوتو', 'weifang': 'ويفانغ',
  'dezhou': 'دجو', 'xuzhou': 'شوجو', 'zhenjiang': 'تشنجيانغ',
  'jiaxing': 'جياشينغ', 'lishui': 'ليشوي', 'anqing': 'آنتشينغ',
  'ganzhou': 'قانجو', 'putian': 'بوتيان', 'mudanjiang': 'مودانجيانغ',
  'changzhou': 'تشانغجو', 'shaoxing': 'شاوشينغ', 'bengbu': 'بنغبو',
  'jiujiang': 'جيوجيانغ', 'quanzhou': 'تشيوانجو',
};

// Locale-aware display name — banners/captions show ONLY this (no hanzi).
String cityDisplayName(City c, {required bool tr}) =>
    tr ? (kCityTrNames[c.slug] ?? c.pinyin) : c.pinyin;

String cityNameFor(City c, String lang) => switch (lang) {
      'tr' => kCityTrNames[c.slug] ?? c.pinyin,
      'ko' => kCityKoNames[c.slug] ?? c.pinyin,
      'ja' => kCityJaNames[c.slug] ?? c.pinyin,
      'id' => kCityIdNames[c.slug] ?? c.pinyin,
      'vi' => kCityViNames[c.slug] ?? c.pinyin,
      'th' => kCityThNames[c.slug] ?? c.pinyin,
      'ru' => kCityRuNames[c.slug] ?? c.pinyin,
      'es' => kCityEsNames[c.slug] ?? c.pinyin,
      'pt' => kCityPtNames[c.slug] ?? c.pinyin,
      'fr' => kCityFrNames[c.slug] ?? c.pinyin,
      'ar' => kCityArNames[c.slug] ?? c.pinyin,
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
  'shanghai': [
    Landmark(icon: 'pearl', photo: 'pearl', nameTr: 'Oryantal İnci Kulesi', nameEn: 'Oriental Pearl Tower', descTr: 'Huangpu kıyısında yükselen pembe küreli kule, modern Şanghay\'ın simgesidir.', descEn: 'Rising over the Huangpu with its pink spheres, the tower is the icon of modern Shanghai.'),
    Landmark(icon: 'bund', photo: 'bund', nameTr: 'Bund', nameEn: 'The Bund', descTr: 'Nehir kıyısındaki tarihî banka ve otel cepheleri, eski Şanghay\'ın görkemini yansıtır.', descEn: 'The riverfront\'s historic bank and hotel façades reflect old Shanghai\'s grandeur.'),
    Landmark(icon: 'garden', photo: 'garden', nameTr: 'Yuyuan Bahçesi', nameEn: 'Yu Garden', descTr: 'Ming döneminden kalma klasik bahçe, kayalıkları ve havuzlarıyla şehrin kalbinde bir vahadır.', descEn: 'A Ming-era classical garden, its rockeries and ponds form an oasis in the city\'s heart.'),
    Landmark(icon: 'xlb', photo: 'xlb', nameTr: 'Xiaolongbao', nameEn: 'Soup Dumplings', descTr: 'İçi sıcak çorbayla dolu buğulama hamur lokması, Şanghay kahvaltısının başyapıtıdır.', descEn: 'Steamed parcels filled with hot broth are the masterpiece of Shanghai breakfast.'),
  ],
  'hangzhou': [
    Landmark(icon: 'lake', photo: 'lake', nameTr: 'Batı Gölü', nameEn: 'West Lake', descTr: 'Söğütleri, adacıkları ve kemerli köprüleriyle Çin şiirinin en çok övdüğü göldür.', descEn: 'With willows, islets and arched bridges, it is the lake most praised in Chinese poetry.'),
    Landmark(icon: 'tea', photo: 'tea', nameTr: 'Longjing Çayı', nameEn: 'Longjing Tea', descTr: 'Göl çevresi yamaçlarda yetişen \'Ejderha Kuyusu\' yeşil çayı Çin\'in en ünlüsüdür.', descEn: 'Grown on the slopes around the lake, \'Dragon Well\' green tea is China\'s most famous.'),
    Landmark(icon: 'temple', photo: 'temple', nameTr: 'Lingyin Tapınağı', nameEn: 'Lingyin Temple', descTr: '1700 yıllık \'Ruhların İnzivası\' tapınağı, kaya oymaları ve dev Buda heykeliyle ünlüdür.', descEn: 'The 1,700-year-old \'Temple of the Soul\'s Retreat\' is famed for rock carvings and a giant Buddha.'),
    Landmark(icon: 'silk', photo: 'silk', nameTr: 'İpek Şehri', nameEn: 'Silk City', descTr: 'Hangzhou ipeği bin yıldır dokunur; şehir İpek Yolu\'nun doğu ucunun zenginliğidir.', descEn: 'Hangzhou silk has been woven for a thousand years — the wealth of the Silk Road\'s eastern end.'),
  ],
  'chongqing': [
    Landmark(icon: 'hongya', photo: 'hongya', nameTr: 'Hongya Mağarası', nameEn: 'Hongya Cave', descTr: 'Uçuruma asılı ışıl ışıl ahşap teras yapısı, gece nehir kıyısında masal gibi parlar.', descEn: 'A glowing stilt-house complex clinging to the cliff, it shines like a fairytale over the river at night.'),
    Landmark(icon: 'hotpot', photo: 'hotpot', nameTr: 'Chongqing Hotpotu', nameEn: 'Chongqing Hotpot', descTr: 'Kıpkırmızı acı yağ ve uyuşturan biberle kaynayan hotpot, dağ şehrinin ateşli ruhudur.', descEn: 'Bubbling with fiery oil and numbing pepper, hotpot is the fiery soul of the mountain city.'),
    Landmark(icon: 'monorail', photo: 'monorail', nameTr: 'Dağ Şehri Metrosu', nameEn: 'Mountain Monorail', descTr: 'Binaların içinden geçen hafif metro, tepelere kurulu şehrin simge manzarasıdır.', descEn: 'The light-rail threading through a building is the signature sight of this city built on hills.'),
    Landmark(icon: 'river', photo: 'river', nameTr: 'Yangtze Geçidi', nameEn: 'Yangtze Gorges', descTr: 'Üç Vadi gemi turları bu limandan başlar; iki nehrin birleştiği yerde şehir yükselir.', descEn: 'Three Gorges cruises depart from this port, where the city rises at the meeting of two rivers.'),
  ],
  'dalian': [
    Landmark(icon: 'square', photo: 'square', nameTr: 'Xinghai Meydanı', nameEn: 'Xinghai Square', descTr: 'Asya\'nın en büyük şehir meydanı, deniz kıyısında festival ve gösterilerle dolar.', descEn: 'Asia\'s largest city square fills with festivals and shows along the seafront.'),
    Landmark(icon: 'beach', photo: 'beach', nameTr: 'Sahiller', nameEn: 'Beaches', descTr: 'Kayalık koyları ve serin yazlarıyla Dalian, kuzeyin gözde tatil kıyısıdır.', descEn: 'With rocky coves and cool summers, Dalian is the north\'s favourite seaside resort.'),
    Landmark(icon: 'football', photo: 'football', nameTr: 'Futbol Şehri', nameEn: 'Football City', descTr: 'Çin\'in \'futbol beşiği\'; ülkenin en çok şampiyonluk kazanan kulüpleri burada doğdu.', descEn: 'China\'s \'cradle of football\' — the nation\'s most decorated clubs were born here.'),
    Landmark(icon: 'seafood', photo: 'seafood', nameTr: 'Deniz Ürünleri', nameEn: 'Seafood', descTr: 'Soğuk Sarı Deniz\'in deniz tarağı, karides ve deniz kestanesi şehrin sofrasını süsler.', descEn: 'Cold Yellow Sea scallops, prawns and sea urchin grace the city\'s tables.'),
  ],
  'shenyang': [
    Landmark(icon: 'palace', photo: 'palace', nameTr: 'Mukden Sarayı', nameEn: 'Mukden Palace', descTr: 'Qing hanedanının ilk sarayı; Pekin\'deki Yasak Şehir\'in küçük kardeşidir.', descEn: 'The Qing dynasty\'s first palace — a smaller sibling of Beijing\'s Forbidden City.'),
    Landmark(icon: 'tomb', photo: 'tomb', nameTr: 'Qing Türbeleri', nameEn: 'Qing Tombs', descTr: 'Şehri çevreleyen Doğu ve Kuzey türbeleri, hanedan kurucularının anıt mezarlarıdır.', descEn: 'The East and North tombs ringing the city are the monumental mausoleums of the dynasty\'s founders.'),
    Landmark(icon: 'factory', photo: 'factory', nameTr: 'Sanayi Beşiği', nameEn: 'Industrial Cradle', descTr: 'Çin\'in ağır sanayisi burada doğdu; dev fabrikalar \'Doğu\'nun Ruhr\'u\' lakabını kazandırdı.', descEn: 'China\'s heavy industry was born here; vast factories earned it the name \'Ruhr of the East\'.'),
    Landmark(icon: 'dumpling', photo: 'dumpling', nameTr: 'Laobian Mantısı', nameEn: 'Laobian Dumplings', descTr: '200 yıllık Laobian buğulama mantısı, kuzey sofrasının imza lezzetidir.', descEn: 'Two-hundred-year-old Laobian steamed dumplings are the signature dish of the northern table.'),
  ],
  'hefei': [
    Landmark(icon: 'judge', photo: 'judge', nameTr: 'Bao Gong Türbesi', nameEn: 'Lord Bao\'s Shrine', descTr: 'Adaletin simgesi yargıç Bao Zheng burada doğdu; anıtı dürüstlüğün tapınağıdır.', descEn: 'Born here, the upright judge Bao Zheng is justice incarnate; his shrine is a temple to integrity.'),
    Landmark(icon: 'science', photo: 'science', nameTr: 'Bilim Şehri', nameEn: 'Science City', descTr: 'Çin\'in önde gelen üniversite ve laboratuvarlarına ev sahipliği yapan teknoloji merkezidir.', descEn: 'A tech hub hosting some of China\'s leading universities and laboratories.'),
    Landmark(icon: 'lake', photo: 'lake', nameTr: 'Chaohu Gölü', nameEn: 'Lake Chaohu', descTr: 'Çin\'in beş büyük tatlı su gölünden biri; beyaz balığı ve yengeciyle ünlüdür.', descEn: 'One of China\'s five great freshwater lakes, famed for its whitefish and crab.'),
    Landmark(icon: 'cake', photo: 'cake', nameTr: 'Lu Susam Çöreği', nameEn: 'Lu Sesame Cake', descTr: 'Tatlı dolgulu susam çöreği, eski Luzhou şehrinin asırlık ikramıdır.', descEn: 'A sweet-filled sesame cake is the age-old treat of old Luzhou.'),
  ],
  'foshan': [
    Landmark(icon: 'wingchun', photo: 'wingchun', nameTr: 'Wing Chun', nameEn: 'Wing Chun', descTr: 'Yip Man ve Bruce Lee\'nin kökleri buraya uzanır; Wing Chun dövüş sanatının yuvasıdır.', descEn: 'Home of Wing Chun martial art — the roots of Ip Man and Bruce Lee reach here.'),
    Landmark(icon: 'lion', photo: 'lion', nameTr: 'Aslan Dansı', nameEn: 'Lion Dance', descTr: 'Güney aslan dansının başkenti; festivallerde rengârenk aslanlar sütunlarda zıplar.', descEn: 'The capital of southern lion dance; festival lions leap across poles in dazzling colour.'),
    Landmark(icon: 'ceramic', photo: 'ceramic', nameTr: 'Shiwan Seramiği', nameEn: 'Shiwan Pottery', descTr: 'Bin yıllık çömlek ocakları, canlı figürlü Shiwan seramiğini hâlâ pişirir.', descEn: 'Thousand-year kilns still fire the lively figurines of Shiwan pottery.'),
    Landmark(icon: 'opera', photo: 'opera', nameTr: 'Kanton Operası', nameEn: 'Cantonese Opera', descTr: 'Güney Çin\'in en sevilen sahne sanatı bu topraklarda olgunlaştı.', descEn: 'Southern China\'s best-loved stage art matured on these lands.'),
  ],
  'guiyang': [
    Landmark(icon: 'pavilion', photo: 'pavilion', nameTr: 'Jiaxiu Köşkü', nameEn: 'Jiaxiu Pavilion', descTr: 'Nanming Nehri üzerindeki üç katlı köşk, 400 yıldır şehrin simgesidir.', descEn: 'The three-tiered pavilion on the Nanming River has been the city\'s emblem for 400 years.'),
    Landmark(icon: 'sourfish', photo: 'sourfish', nameTr: 'Ekşi Çorbalı Balık', nameEn: 'Sour Soup Fish', descTr: 'Domates ve ekşi mayalı kırmızı çorbada pişen balık, Guizhou\'nun imza yemeğidir.', descEn: 'Fish simmered in a tangy fermented-tomato red broth is Guizhou\'s signature dish.'),
    Landmark(icon: 'waterfall', photo: 'waterfall', nameTr: 'Huangguoshu Şelalesi', nameEn: 'Huangguoshu Falls', descTr: 'Asya\'nın en büyük şelalelerinden biri, gürül gürül dökülerek gökkuşakları yaratır.', descEn: 'One of Asia\'s largest waterfalls thunders down, throwing up rainbows.'),
    Landmark(icon: 'miao', photo: 'miao', nameTr: 'Miao Kültürü', nameEn: 'Miao Culture', descTr: 'Gümüş başlıklı Miao halkının şenlikleri ve nakışları dağ köylerini renklendirir.', descEn: 'The silver-crowned Miao people\'s festivals and embroidery brighten the mountain villages.'),
  ],
  'changchun': [
    Landmark(icon: 'film', photo: 'film', nameTr: 'Film Şehri', nameEn: 'Film City', descTr: 'Çin sinemasının doğduğu stüdyolar burada; \'Doğu\'nun Hollywood\'u\' diye anılır.', descEn: 'The studios where Chinese cinema was born stand here — the \'Hollywood of the East\'.'),
    Landmark(icon: 'car', photo: 'car', nameTr: 'Otomobil Şehri', nameEn: 'Auto City', descTr: 'Çin\'in ilk yerli otomobili bu fabrikalardan çıktı; ülkenin araba başkentidir.', descEn: 'China\'s first home-built car rolled out of these factories — the nation\'s auto capital.'),
    Landmark(icon: 'palace', photo: 'palace', nameTr: 'Kukla Mançu Sarayı', nameEn: 'Puppet Palace', descTr: 'Son imparatorun yaşadığı saray, dalgalı bir tarihin sessiz tanığıdır.', descEn: 'The palace where the last emperor lived is a silent witness to a turbulent history.'),
    Landmark(icon: 'snow', photo: 'snow', nameTr: 'Kış ve Kar', nameEn: 'Winter Snow', descTr: 'Uzun, bembeyaz kışlarıyla şehir, buz heykelleri ve kayak pistleriyle parlar.', descEn: 'Through long, white winters the city sparkles with ice sculptures and ski runs.'),
  ],
  'xining': [
    Landmark(icon: 'lake', photo: 'lake', nameTr: 'Qinghai Gölü', nameEn: 'Lake Qinghai', descTr: 'Çin\'in en büyük tuz gölü, yazın çevresini saran sarı kolza tarlalarıyla ünlüdür.', descEn: 'China\'s largest salt lake is famed for the yellow rapeseed fields that ring it in summer.'),
    Landmark(icon: 'monastery', photo: 'monastery', nameTr: 'Kumbum Manastırı', nameEn: 'Kumbum Monastery', descTr: 'Tibet Budizminin altı büyük manastırından biri; tereyağı heykelleriyle meşhurdur.', descEn: 'One of the six great monasteries of Tibetan Buddhism, renowned for its yak-butter sculptures.'),
    Landmark(icon: 'flower', photo: 'flower', nameTr: 'Kolza Çiçeği', nameEn: 'Rapeseed Blossom', descTr: 'Temmuzda plato altın sarısı kolza tarlalarıyla ufka kadar kaplanır.', descEn: 'In July the plateau is blanketed to the horizon in golden rapeseed fields.'),
    Landmark(icon: 'lamb', photo: 'lamb', nameTr: 'Yak ve Kuzu', nameEn: 'Yak & Lamb', descTr: 'Hui ve Tibet mutfağının elle çekilmiş eriştesi ve kuzu şişi yaylanın lezzetidir.', descEn: 'Hand-pulled noodles and lamb skewers of Hui and Tibetan cooking are the flavours of the plateau.'),
  ],
  'guilin': [
    Landmark(icon: 'karst', photo: 'karst', nameTr: 'Li Nehri Dağları', nameEn: 'Li River Karst', descTr: 'Sis içinde yükselen kireçtaşı tepeler, \'20 yuan\'lık banknotun manzarasıdır.', descEn: 'Limestone peaks rising from the mist are the scene printed on the 20-yuan note.'),
    Landmark(icon: 'elephant', photo: 'elephant', nameTr: 'Fil Hortumu Tepesi', nameEn: 'Elephant Trunk Hill', descTr: 'Hortumunu nehre daldıran fil biçimli kaya, şehrin sevilen simgesidir.', descEn: 'The elephant-shaped rock dipping its trunk into the river is the city\'s beloved emblem.'),
    Landmark(icon: 'terrace', photo: 'terrace', nameTr: 'Longji Pirinç Terasları', nameEn: 'Longji Rice Terraces', descTr: 'Dağ yamaçlarını saran \'Ejderha Sırtı\' terasları, asırlık emeğin merdivenidir.', descEn: 'The \'Dragon\'s Backbone\' terraces wrapping the slopes are a staircase of centuries of toil.'),
    Landmark(icon: 'osmanthus', photo: 'osmanthus', nameTr: 'Tatlı Osmanthus', nameEn: 'Osmanthus Blossom', descTr: 'Adı \'osmanthus ormanı\' demektir; sonbaharda şehir tatlı çiçek kokusuna boğulur.', descEn: 'Its name means \'osmanthus forest\'; in autumn the city drowns in sweet blossom scent.'),
  ],
  'wenzhou': [
    Landmark(icon: 'merchant', photo: 'merchant', nameTr: 'Tüccar Ruhu', nameEn: 'Merchant Spirit', descTr: '\'Çin\'in Yahudileri\' denen Wenzhoulu girişimciler dünyaya yayılmış iş ağı kurar.', descEn: 'Called \'China\'s Jews\', Wenzhou entrepreneurs build business networks across the globe.'),
    Landmark(icon: 'shoe', photo: 'shoe', nameTr: 'Ayakkabı ve Deri', nameEn: 'Shoes & Leather', descTr: 'Dünyanın deri ayakkabılarının büyük kısmı bu fabrika şehrinden çıkar.', descEn: 'A huge share of the world\'s leather shoes comes from this factory city.'),
    Landmark(icon: 'mountain', photo: 'mountain', nameTr: 'Yandang Dağları', nameEn: 'Yandang Mountains', descTr: 'Şelaleleri ve sivri zirveleriyle ünlü dağlar, \'denizin üstündeki ilk dağ\' sayılır.', descEn: 'Famed for waterfalls and jagged peaks, these are hailed as \'the first mountain by the sea\'.'),
    Landmark(icon: 'seafood', photo: 'seafood', nameTr: 'Deniz Ürünleri', nameEn: 'Seafood', descTr: 'Doğu Çin Denizi\'nin kalamar, deniz tarağı ve balığı yerel sofranın temelidir.', descEn: 'Squid, scallops and fish from the East China Sea are the base of the local table.'),
  ],
  'tangshan': [
    Landmark(icon: 'memorial', photo: 'memorial', nameTr: 'Deprem Anıtı', nameEn: 'Earthquake Memorial', descTr: '1976 büyük depreminin anısına kurulan park, yeniden doğan şehrin simgesidir.', descEn: 'The memorial park to the great 1976 quake is the emblem of a city reborn.'),
    Landmark(icon: 'coal', photo: 'coal', nameTr: 'Kömür ve Çelik', nameEn: 'Coal & Steel', descTr: 'Çin\'in ilk modern kömür madeni ve demiryolu burada açıldı; sanayinin beşiğidir.', descEn: 'China\'s first modern coal mine and railway opened here — a cradle of industry.'),
    Landmark(icon: 'ceramic', photo: 'ceramic', nameTr: 'Tangshan Seramiği', nameEn: 'Tangshan Ceramics', descTr: '\'Kuzeyin porselen şehri\'; kemik porseleni masaları zarafetle donatır.', descEn: 'The \'porcelain city of the north\' — its bone china graces tables with elegance.'),
    Landmark(icon: 'lake', photo: 'lake', nameTr: 'Nanhu Parkı', nameEn: 'Nanhu Park', descTr: 'Eski maden çukurundan doğan göl-park, şehrin yeşil ciğeri oldu.', descEn: 'A lake-park born from an old mining pit became the city\'s green lung.'),
  ],
  'anshan': [
    Landmark(icon: 'steel', photo: 'steel', nameTr: 'Çelik Şehri', nameEn: 'Steel City', descTr: 'Çin\'in en büyük çelik kombinası burada kuruldu; ülkenin \'çelik başkenti\'dir.', descEn: 'China\'s largest steel works was founded here — the nation\'s \'steel capital\'.'),
    Landmark(icon: 'jade', photo: 'jade', nameTr: 'Xiuyan Yeşimi', nameEn: 'Xiuyan Jade', descTr: 'Dünyanın en büyük yeşim heykeli buradadır; şehir Çin\'in yeşim diyarıdır.', descEn: 'The world\'s largest jade carving is here; the city is China\'s land of jade.'),
    Landmark(icon: 'mountain', photo: 'mountain', nameTr: 'Qianshan Dağı', nameEn: 'Mount Qian', descTr: '\'Bin Lotus Zirvesi\' dağı, tapınakları ve kayalarıyla kuzeyin kutsal dorukudur.', descEn: 'The \'Thousand Lotus Peaks\', with its temples and crags, is the north\'s sacred summit.'),
    Landmark(icon: 'spring', photo: 'spring', nameTr: 'Tanggangzi Kaplıcası', nameEn: 'Tanggangzi Springs', descTr: 'Bin yıldır şifa aranan sıcak su kaplıcaları imparatorları bile ağırladı.', descEn: 'Hot springs sought for healing for a thousand years once hosted emperors too.'),
  ],
  'linyi': [
    Landmark(icon: 'market', photo: 'market', nameTr: 'Toptan Çarşı', nameEn: 'Wholesale Market', descTr: 'Kuzey Çin\'in en büyük toptan ticaret merkezi, mallarını tüm ülkeye dağıtır.', descEn: 'Northern China\'s largest wholesale hub ships its goods across the whole country.'),
    Landmark(icon: 'brush', photo: 'brush', nameTr: 'Wang Xizhi', nameEn: 'Master Calligrapher', descTr: 'Çin\'in \'kaligrafi bilgesi\' Wang Xizhi burada doğdu; şehir mürekkebin diyarıdır.', descEn: 'China\'s \'sage of calligraphy\' Wang Xizhi was born here; the city is the land of ink.'),
    Landmark(icon: 'mountain', photo: 'mountain', nameTr: 'Mengshan Dağı', nameEn: 'Mount Meng', descTr: 'Şandong\'un ikinci yüksek dağı, temiz havası ve şelaleleriyle \'oksijen barı\'dır.', descEn: 'Shandong\'s second-highest mountain is an \'oxygen bar\' of clean air and waterfalls.'),
    Landmark(icon: 'pancake', photo: 'pancake', nameTr: 'Jianbing', nameEn: 'Yimeng Pancake', descTr: 'İnce mısır gözlemesi \'jianbing\', Yimeng dağ halkının asırlık temel ekmeğidir.', descEn: 'The thin corn pancake \'jianbing\' is the age-old staple of the Yimeng mountain folk.'),
  ],
  'cangzhou': [
    Landmark(icon: 'lion', photo: 'lion', nameTr: 'Demir Aslan', nameEn: 'Iron Lion', descTr: '1100 yıllık dev dökme demir aslan heykeli, şehrin gururlu nişanıdır.', descEn: 'The 1,100-year-old giant cast-iron lion is the city\'s proud badge.'),
    Landmark(icon: 'martial', photo: 'martial', nameTr: 'Dövüş Sanatları', nameEn: 'Martial Arts', descTr: 'Çin\'in \'wushu memleketi\'; ünlü ustalar ve dövüş okulları buradan çıktı.', descEn: 'China\'s \'home of wushu\' — famed masters and fighting schools came from here.'),
    Landmark(icon: 'canal', photo: 'canal', nameTr: 'Büyük Kanal', nameEn: 'Grand Canal', descTr: 'Pekin-Hangzhou Büyük Kanalı şehrin içinden geçer; eski iskeleler hâlâ durur.', descEn: 'The Beijing-Hangzhou Grand Canal runs through the city; old wharves still stand.'),
    Landmark(icon: 'jujube', photo: 'jujube', nameTr: 'Altın Hünnap', nameEn: 'Golden Jujube', descTr: 'İnce kabuklu tatlı \'altın iplik\' hünnabı, kuru meyvenin kralı sayılır.', descEn: 'The thin-skinned, sweet \'golden-thread\' jujube is hailed as the king of dried fruit.'),
  ],
  'nantong': [
    Landmark(icon: 'textile', photo: 'textile', nameTr: 'Tekstil Şehri', nameEn: 'Textile City', descTr: 'Çin\'in ev tekstili başkenti; pamuklu kumaşları dünya pazarlarına yayılır.', descEn: 'China\'s home-textile capital — its cotton cloth reaches markets worldwide.'),
    Landmark(icon: 'mountain', photo: 'mountain', nameTr: 'Langshan', nameEn: 'Mount Lang', descTr: 'Yangtze ağzında yükselen beş tepeli kutsal dağ, hac ve manzara yeridir.', descEn: 'Rising at the Yangtze\'s mouth, the five-peaked sacred hill is a place of pilgrimage and views.'),
    Landmark(icon: 'kite', photo: 'kite', nameTr: 'Banyao Uçurtması', nameEn: 'Whistling Kite', descTr: 'Gökte uğuldayan düdüklü \'banyao\' uçurtmaları şehrin asırlık zanaatıdır.', descEn: 'The humming, whistle-fitted \'banyao\' kites are the city\'s age-old craft.'),
    Landmark(icon: 'school', photo: 'school', nameTr: 'Eğitim Öncüsü', nameEn: 'Education Pioneer', descTr: 'Sanayici Zhang Jian burada Çin\'in ilk modern okul ve müzelerini kurdu.', descEn: 'The industrialist Zhang Jian founded China\'s first modern schools and museum here.'),
  ],
  'taizhou': [
    Landmark(icon: 'opera', photo: 'opera', nameTr: 'Mei Lanfang', nameEn: 'Mei Lanfang', descTr: 'Pekin operasının efsanevi ustası Mei Lanfang\'ın memleketi burasıdır.', descEn: 'This is the hometown of Mei Lanfang, legendary master of Peking opera.'),
    Landmark(icon: 'tea', photo: 'tea', nameTr: 'Sabah Çayı', nameEn: 'Morning Tea', descTr: 'Buğulama börek ve demli çayla başlayan \'zaocha\' kahvaltısı şehrin ritüelidir.', descEn: 'The \'zaocha\' breakfast of steamed buns and brewed tea is the city\'s ritual.'),
    Landmark(icon: 'boat', photo: 'boat', nameTr: 'Qintong Kayık Şenliği', nameEn: 'Qintong Boat Festival', descTr: 'Baharda yüzlerce kürekçinin yarıştığı sandal şenliği nehri canlandırır.', descEn: 'In spring a festival of hundreds of rowers racing brings the river to life.'),
    Landmark(icon: 'meatball', photo: 'meatball', nameTr: 'Aslan Başı Köfte', nameEn: 'Lion\'s Head Meatball', descTr: 'İri, yumuşacık domuz köftesi \'aslan başı\', Huaiyang mutfağının klasiğidir.', descEn: 'The big, tender pork meatball \'lion\'s head\' is a classic of Huaiyang cuisine.'),
  ],
  'jinhua': [
    Landmark(icon: 'ham', photo: 'ham', nameTr: 'Jinhua Jambonu', nameEn: 'Jinhua Ham', descTr: 'Asırlık tuzlama yöntemiyle olgunlaşan kırmızı jambon, Çin\'in en ünlüsüdür.', descEn: 'Cured by a centuries-old method, the red ham is the most famous in China.'),
    Landmark(icon: 'film', photo: 'film', nameTr: 'Hengdian Stüdyoları', nameEn: 'Hengdian Studios', descTr: 'Dünyanın en büyük açık hava film platosu; sayısız tarihî dizi burada çekilir.', descEn: 'The world\'s largest outdoor film set — countless period dramas are shot here.'),
    Landmark(icon: 'cave', photo: 'cave', nameTr: 'Shuanglong Mağarası', nameEn: 'Shuanglong Cave', descTr: 'Tekneyle alçak bir kaya kapısından girilen yeraltı mağarası nefes kesir.', descEn: 'An underground cavern entered by boat through a low rock gate takes the breath away.'),
    Landmark(icon: 'bridge', photo: 'bridge', nameTr: 'Eski Köprüler', nameEn: 'Ancient Bridges', descTr: 'Wuzhou\'nun kemerli taş köprüleri ve su kasabaları Jiangnan\'ın inceliğini taşır.', descEn: 'Arched stone bridges and water towns carry the grace of Jiangnan.'),
  ],
  'wuhu': [
    Landmark(icon: 'park', photo: 'park', nameTr: 'Fangte Lunaparkı', nameEn: 'Fangte Wonderland', descTr: 'Çin\'in en büyük tema parklarından biri; ailelere heyecan dolu günler sunar.', descEn: 'One of China\'s largest theme parks offers families days full of thrills.'),
    Landmark(icon: 'ironart', photo: 'ironart', nameTr: 'Wuhu Demir Resmi', nameEn: 'Iron Painting', descTr: 'Demiri döverek yapılan zarif \'demir resim\' tabloları, 300 yıllık bir zanaattır.', descEn: 'Elegant \'iron paintings\' forged from wrought iron are a 300-year-old craft.'),
    Landmark(icon: 'rice', photo: 'rice', nameTr: 'Pirinç Limanı', nameEn: 'Rice Port', descTr: 'Yangtze kıyısındaki şehir, tarih boyunca Çin\'in en büyük pirinç pazarıydı.', descEn: 'The Yangtze-side city was historically China\'s largest rice market.'),
    Landmark(icon: 'river', photo: 'river', nameTr: 'Yangtze Limanı', nameEn: 'Yangtze Port', descTr: 'İşlek nehir limanı, şehri Anhui\'nin denize açılan kapısı yapar.', descEn: 'A busy river port makes the city Anhui\'s gateway to the sea.'),
  ],
  'huangshan': [
    Landmark(icon: 'peak', photo: 'peak', nameTr: 'Sarı Dağ', nameEn: 'Yellow Mountain', descTr: 'Granit zirveleri, bulut denizi ve eğri çamlarıyla Çin\'in en ünlü dağıdır.', descEn: 'With granite peaks, a sea of clouds and gnarled pines, it is China\'s most famous mountain.'),
    Landmark(icon: 'village', photo: 'village', nameTr: 'Hongcun Köyü', nameEn: 'Hongcun Village', descTr: 'Su kanallı, beyaz duvarlı Hui köyleri UNESCO mirasıdır; resimlerden fırlamış gibidir.', descEn: 'The water-laced, white-walled Hui villages are UNESCO-listed and look straight out of a painting.'),
    Landmark(icon: 'tea', photo: 'tea', nameTr: 'Huangshan Maofeng', nameEn: 'Maofeng Tea', descTr: 'Sisli yamaçlarda toplanan tüylü uçlu yeşil çay, Çin\'in on ünlü çayından biridir.', descEn: 'Picked on misty slopes, the downy-tipped green tea is one of China\'s ten famous teas.'),
    Landmark(icon: 'ink', photo: 'ink', nameTr: 'Hui Mürekkep ve Mimari', nameEn: 'Huizhou Ink & Arts', descTr: 'Hui mürekkebi, oymalı ahşap evleri ve hat sanatı bölgenin kültür hazinesidir.', descEn: 'Hui ink, carved timber houses and calligraphy are the region\'s cultural treasure.'),
  ],
  'yichun': [
    Landmark(icon: 'moon', photo: 'moon', nameTr: 'Mingyue Dağı', nameEn: 'Mount Mingyue', descTr: '\'Parlak Ay\' dağı, sıcak su kaynakları ve teleferik manzaralarıyla ünlüdür.', descEn: 'The \'Bright Moon\' mountain is famed for hot springs and cable-car views.'),
    Landmark(icon: 'spring', photo: 'spring', nameTr: 'Selenyum Kaplıcaları', nameEn: 'Hot Springs', descTr: 'Nadir selenyumlu sıcak su kaynakları, şehri Çin\'in şifa-banyo merkezi yaptı.', descEn: 'Rare selenium-rich hot springs made the city China\'s spa-bathing centre.'),
    Landmark(icon: 'zen', photo: 'zen', nameTr: 'Zen Budizmi', nameEn: 'Chan Buddhism', descTr: 'Çin Zen mezheplerinin köklerini taşıyan dağ tapınakları sessizliğe çağırır.', descEn: 'Mountain temples rooted in China\'s Chan sects call one to stillness.'),
    Landmark(icon: 'rice', photo: 'rice', nameTr: 'Pirinç Ovası', nameEn: 'Rice Plain', descTr: 'Verimli Yuan-He ovası, tarih boyunca Jiangxi\'nin tahıl ambarı olmuştur.', descEn: 'The fertile Yuan-He plain has long been Jiangxi\'s granary.'),
  ],
  'zhangzhou': [
    Landmark(icon: 'narcissus', photo: 'narcissus', nameTr: 'Nergis Çiçeği', nameEn: 'Narcissus', descTr: 'Çin\'in en ünlü nergis soğanları burada yetişir; bahar şenliklerinin simgesidir.', descEn: 'China\'s most famous narcissus bulbs grow here — the emblem of spring festivals.'),
    Landmark(icon: 'tulou', photo: 'tulou', nameTr: 'Hakka Tulou', nameEn: 'Hakka Earth Houses', descTr: 'Dev yuvarlak topraktan kale-evler UNESCO mirasıdır; bir köyü tek çatı altında toplar.', descEn: 'Giant round rammed-earth fortresses are UNESCO-listed, gathering a village under one roof.'),
    Landmark(icon: 'banana', photo: 'banana', nameTr: 'Tropik Meyveler', nameEn: 'Tropical Fruit', descTr: 'Muz, longan ve mandalina bahçeleri sıcak deltayı yıl boyu yeşertir.', descEn: 'Banana, longan and tangerine groves keep the warm delta green year-round.'),
    Landmark(icon: 'coast', photo: 'coast', nameTr: 'Dongshan Adası', nameEn: 'Dongshan Island', descTr: 'Altın kumlu plajları ve balıkçı köyleriyle ada, güney kıyısının incisidir.', descEn: 'With golden beaches and fishing villages, the island is the pearl of the southern coast.'),
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
