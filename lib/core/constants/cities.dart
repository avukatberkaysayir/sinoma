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

// Cities that ship a real landmark icon at assets/cities/<slug>.png. Others fall
// back to a generic themed icon (see _cityNodeIcon in path_screen). Add a slug
// here once its PNG is dropped into assets/cities/.
const Set<String> kCityIconAssets = {
  'beijing',
};

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
