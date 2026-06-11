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

// Turkish exonyms for well-known cities; the rest read naturally in pinyin.
const Map<String, String> kCityTrNames = {
  'beijing': 'Pekin', 'shanghai': 'Şanghay', 'nanjing': 'Nankin',
  'guangzhou': 'Kanton', 'chongqing': 'Çunking', 'chengdu': 'Çengdu',
  'xian': 'Şian', 'tianjin': 'Tiençin', 'hangzhou': 'Hangcou',
  'wuhan': 'Vuhan', 'shenzhen': 'Şençen', 'suzhou': 'Sucou',
  'qingdao': 'Çingdao', 'urumqi': 'Urumçi', 'kashgar': 'Kaşgar',
  'hongkong': 'Hong Kong', 'macau': 'Makao',
};

// Locale-aware display name — banners/captions show ONLY this (no hanzi).
String cityDisplayName(City c, {required bool tr}) =>
    tr ? (kCityTrNames[c.slug] ?? c.pinyin) : c.pinyin;

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
