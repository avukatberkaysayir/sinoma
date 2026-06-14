enum VideoSourceType { youtube, selfHosted }

// Grammar focus points covering the teachable HSK 1-6 (HSK 3.0) syllabus.
// One entry per grammar point; displayName is just the word/pattern (no emoji,
// no description). A class (not an enum) so the ~95 entries stay a clean list.
// `name` is the stored id; const instances make `==` / Set membership work.
class QuizCategory {
  final String name;
  final String displayName;
  const QuizCategory._(this.name, this.displayName);

  // ── Aspect & structural particles ──
  static const le = QuizCategory._('le', '了');
  static const zhe = QuizCategory._('zhe', '着');
  static const guo = QuizCategory._('guo', '过');
  static const deStruct = QuizCategory._('deStruct', '的');
  static const deAdverbial = QuizCategory._('deAdverbial', '地');
  static const deComplement = QuizCategory._('deComplement', '得');
  static const ma = QuizCategory._('ma', '吗');
  static const ne = QuizCategory._('ne', '呢');
  static const baParticle = QuizCategory._('baParticle', '吧');
  static const a = QuizCategory._('a', '啊');
  static const dehua = QuizCategory._('dehua', '的话');
  // ── Special sentence patterns ──
  static const ba = QuizCategory._('ba', '把字句');
  static const bei = QuizCategory._('bei', '被动句');
  static const shiDe = QuizCategory._('shiDe', '是…的');
  static const shi = QuizCategory._('shi', '是字句');
  static const you = QuizCategory._('you', '有字句');
  static const cunxian = QuizCategory._('cunxian', '存现句');
  static const jianyu = QuizCategory._('jianyu', '兼语句');
  static const liandong = QuizCategory._('liandong', '连动句');
  static const chongdong = QuizCategory._('chongdong', '重动句');
  // ── Comparison ──
  static const bi = QuizCategory._('bi', '比');
  static const meiyou = QuizCategory._('meiyou', '没有 (比较)');
  static const genYiyang = QuizCategory._('genYiyang', '跟…一样');
  static const buru = QuizCategory._('buru', '不如');
  static const yuelaiyue = QuizCategory._('yuelaiyue', '越来越');
  static const yueyue = QuizCategory._('yueyue', '越…越');
  // ── Complements ──
  static const jieguo = QuizCategory._('jieguo', '结果补语');
  static const quxiang = QuizCategory._('quxiang', '趋向补语');
  static const keneng = QuizCategory._('keneng', '可能补语');
  static const chengdu = QuizCategory._('chengdu', '程度补语');
  static const dongliang = QuizCategory._('dongliang', '动量补语');
  static const shiliang = QuizCategory._('shiliang', '时量补语');
  // ── Aspect/progressive ──
  static const zai = QuizCategory._('zai', '在 (进行)');
  static const zhengzai = QuizCategory._('zhengzai', '正在');
  static const qilai = QuizCategory._('qilai', '起来');
  static const xiaqu = QuizCategory._('xiaqu', '下去');
  // ── Modal verbs ──
  static const hui = QuizCategory._('hui', '会');
  static const neng = QuizCategory._('neng', '能');
  static const keyi = QuizCategory._('keyi', '可以');
  static const yao = QuizCategory._('yao', '要');
  static const xiang = QuizCategory._('xiang', '想');
  static const yinggai = QuizCategory._('yinggai', '应该');
  static const dei = QuizCategory._('dei', '得 (děi)');
  static const gan = QuizCategory._('gan', '敢');
  static const xuyao = QuizCategory._('xuyao', '需要');
  static const bixu = QuizCategory._('bixu', '必须');
  static const dasuan = QuizCategory._('dasuan', '打算');
  // ── Question forms ──
  static const zhengfan = QuizCategory._('zhengfan', '正反问 (A不A)');
  static const haishi = QuizCategory._('haishi', '还是');
  static const zenme = QuizCategory._('zenme', '怎么');
  static const weishenme = QuizCategory._('weishenme', '为什么');
  static const zenmeyang = QuizCategory._('zenmeyang', '怎么样');
  // ── Negation ──
  static const bu = QuizCategory._('bu', '不');
  static const mei = QuizCategory._('mei', '没');
  // ── Adverbs ──
  static const jiu = QuizCategory._('jiu', '就');
  static const cai = QuizCategory._('cai', '才');
  static const dou = QuizCategory._('dou', '都');
  static const hai = QuizCategory._('hai', '还');
  static const zaiAgain = QuizCategory._('zaiAgain', '再');
  static const youAgain = QuizCategory._('youAgain', '又');
  static const yizhi = QuizCategory._('yizhi', '一直');
  static const yijing = QuizCategory._('yijing', '已经');
  static const changchang = QuizCategory._('changchang', '常常');
  static const zhongyu = QuizCategory._('zhongyu', '终于');
  static const nandao = QuizCategory._('nandao', '难道');
  static const tai = QuizCategory._('tai', '太');
  static const geng = QuizCategory._('geng', '更');
  static const zui = QuizCategory._('zui', '最');
  static const bijiao = QuizCategory._('bijiao', '比较');
  // ── Prepositions ──
  static const cong = QuizCategory._('cong', '从');
  static const dui = QuizCategory._('dui', '对');
  static const gei = QuizCategory._('gei', '给');
  static const gen = QuizCategory._('gen', '跟');
  static const xiangPrep = QuizCategory._('xiangPrep', '向');
  static const wei = QuizCategory._('wei', '为');
  static const weile = QuizCategory._('weile', '为了');
  static const li = QuizCategory._('li', '离');
  static const guanyu = QuizCategory._('guanyu', '关于');
  static const anzhao = QuizCategory._('anzhao', '按照');
  static const genju = QuizCategory._('genju', '根据');
  static const chule = QuizCategory._('chule', '除了');
  static const lian = QuizCategory._('lian', '连');
  // ── Complex-sentence connectors ──
  static const ruguo = QuizCategory._('ruguo', '如果');
  static const yaoshi = QuizCategory._('yaoshi', '要是');
  static const jiaru = QuizCategory._('jiaru', '假如');
  static const wanyi = QuizCategory._('wanyi', '万一');
  static const fouze = QuizCategory._('fouze', '否则');
  static const zhiyao = QuizCategory._('zhiyao', '只要');
  static const zhiyou = QuizCategory._('zhiyou', '只有');
  static const wulun = QuizCategory._('wulun', '无论');
  static const buguan = QuizCategory._('buguan', '不管');
  static const chufei = QuizCategory._('chufei', '除非');
  static const yinwei = QuizCategory._('yinwei', '因为');
  static const suoyi = QuizCategory._('suoyi', '所以');
  static const jiran = QuizCategory._('jiran', '既然');
  static const yinci = QuizCategory._('yinci', '因此');
  static const suiran = QuizCategory._('suiran', '虽然');
  static const danshi = QuizCategory._('danshi', '但是');
  static const que = QuizCategory._('que', '却');
  static const raner = QuizCategory._('raner', '然而');
  static const jishi = QuizCategory._('jishi', '即使');
  static const napa = QuizCategory._('napa', '哪怕');
  static const jinguan = QuizCategory._('jinguan', '尽管');
  static const budan = QuizCategory._('budan', '不但');
  static const erqie = QuizCategory._('erqie', '而且');
  static const bujin = QuizCategory._('bujin', '不仅');
  static const shenzhi = QuizCategory._('shenzhi', '甚至');
  static const huozhe = QuizCategory._('huozhe', '或者');
  static const yaome = QuizCategory._('yaome', '要么');
  static const ranhou = QuizCategory._('ranhou', '然后');
  static const yushi = QuizCategory._('yushi', '于是');
  static const yibian = QuizCategory._('yibian', '一边');
  // ── Emphasis ──
  static const liandou = QuizCategory._('liandou', '连…都');
  static const fanwen = QuizCategory._('fanwen', '反问句');
  static const shuangchong = QuizCategory._('shuangchong', '双重否定');
  // ── Fallback ──
  static const general = QuizCategory._('general', '一般');

  static const List<QuizCategory> values = [
    le, zhe, guo, deStruct, deAdverbial, deComplement, ma, ne, baParticle, a, dehua,
    ba, bei, shiDe, shi, you, cunxian, jianyu, liandong, chongdong,
    bi, meiyou, genYiyang, buru, yuelaiyue, yueyue,
    jieguo, quxiang, keneng, chengdu, dongliang, shiliang,
    zai, zhengzai, qilai, xiaqu,
    hui, neng, keyi, yao, xiang, yinggai, dei, gan, xuyao, bixu, dasuan,
    zhengfan, haishi, zenme, weishenme, zenmeyang,
    bu, mei,
    jiu, cai, dou, hai, zaiAgain, youAgain, yizhi, yijing, changchang, zhongyu,
    nandao, tai, geng, zui, bijiao,
    cong, dui, gei, gen, xiangPrep, wei, weile, li, guanyu, anzhao, genju, chule, lian,
    ruguo, yaoshi, jiaru, wanyi, fouze, zhiyao, zhiyou, wulun, buguan, chufei,
    yinwei, suoyi, jiran, yinci, suiran, danshi, que, raner,
    jishi, napa, jinguan, budan, erqie, bujin, shenzhi,
    huozhe, yaome, ranhou, yushi, yibian,
    liandou, fanwen, shuangchong,
    general,
  ];

  static QuizCategory fromString(String value) =>
      values.firstWhere((c) => c.name == value, orElse: () => general);

  int get index => values.indexOf(this);

  String get emoji => this == general ? '📖' : '📝';
}

// ── HSK grammar curriculum ────────────────────────────────────────────────────
// Every grammar point (QuizCategory) assigned to its HSK level (HSK 3.0 ordered
// progression). Drives: the admin "Gramer" filter (grouped by HSK level) and the
// learning path (each level L1-L6 = these grammar points, one per unit, in order).
const Map<int, List<QuizCategory>> kGrammarByHsk = {
  1: [
    QuizCategory.shi, QuizCategory.deStruct, QuizCategory.you, QuizCategory.le,
    QuizCategory.ma, QuizCategory.ne, QuizCategory.baParticle, QuizCategory.a,
    QuizCategory.bu, QuizCategory.mei, QuizCategory.zai, QuizCategory.hui,
    QuizCategory.neng, QuizCategory.keyi, QuizCategory.yao, QuizCategory.xiang,
    QuizCategory.dou, QuizCategory.zenme, QuizCategory.zhengfan, QuizCategory.tai,
    QuizCategory.dui, QuizCategory.gei, QuizCategory.gen, QuizCategory.zaiAgain,
  ],
  2: [
    QuizCategory.guo, QuizCategory.zhe, QuizCategory.deComplement,
    QuizCategory.deAdverbial, QuizCategory.jiu, QuizCategory.hai,
    QuizCategory.yijing, QuizCategory.cai, QuizCategory.bi,
    QuizCategory.weishenme, QuizCategory.zenmeyang, QuizCategory.yinwei,
    QuizCategory.suoyi, QuizCategory.qilai, QuizCategory.jieguo,
    QuizCategory.cong, QuizCategory.li, QuizCategory.wei,
    QuizCategory.changchang, QuizCategory.bijiao, QuizCategory.youAgain,
    QuizCategory.geng, QuizCategory.zui, QuizCategory.haishi,
  ],
  3: [
    QuizCategory.ba, QuizCategory.bei, QuizCategory.shiDe, QuizCategory.yinggai,
    QuizCategory.dei, QuizCategory.dasuan, QuizCategory.ruguo,
    QuizCategory.danshi, QuizCategory.suiran, QuizCategory.genYiyang,
    QuizCategory.quxiang, QuizCategory.weile, QuizCategory.guanyu,
    QuizCategory.chule, QuizCategory.yizhi, QuizCategory.gan,
    QuizCategory.xuyao, QuizCategory.yibian, QuizCategory.ranhou,
    QuizCategory.yueyue, QuizCategory.yuelaiyue, QuizCategory.dehua,
    QuizCategory.zhongyu, QuizCategory.nandao,
  ],
  4: [
    QuizCategory.keneng, QuizCategory.chengdu, QuizCategory.dongliang,
    QuizCategory.shiliang, QuizCategory.zhengzai, QuizCategory.xiaqu,
    QuizCategory.meiyou, QuizCategory.buru, QuizCategory.zhiyao,
    QuizCategory.zhiyou, QuizCategory.wulun, QuizCategory.buguan,
    QuizCategory.jiran, QuizCategory.budan, QuizCategory.erqie,
    QuizCategory.huozhe, QuizCategory.lian, QuizCategory.liandou,
    QuizCategory.genju, QuizCategory.anzhao, QuizCategory.jiaru,
    QuizCategory.yaoshi, QuizCategory.yinci, QuizCategory.que,
  ],
  5: [
    QuizCategory.cunxian, QuizCategory.jianyu, QuizCategory.liandong,
    QuizCategory.chongdong, QuizCategory.bixu, QuizCategory.fouze,
    QuizCategory.raner, QuizCategory.jishi, QuizCategory.bujin,
    QuizCategory.shenzhi, QuizCategory.yaome, QuizCategory.yushi,
    QuizCategory.wanyi, QuizCategory.xiangPrep,
  ],
  6: [
    QuizCategory.napa, QuizCategory.jinguan, QuizCategory.chufei,
    QuizCategory.fanwen, QuizCategory.shuangchong,
  ],
};

// Units shown per level on the learning path.
const int kUnitsPerLevel = 24;

// Localized name + core symbol for each grammar point. Unit titles read
// "{meaning} ({zh})" → e.g. "Geçmiş Zaman (了)" / "Past Tense (了)".
const Map<String, ({String tr, String en, String zh})> kGrammarMeaning = {
  // HSK 1
  'shi': (tr: 'Olmak', en: 'To be', zh: '是'),
  'deStruct': (tr: 'İyelik / Sıfat', en: 'Possessive / Attributive', zh: '的'),
  'you': (tr: 'Sahiplik', en: 'To have', zh: '有'),
  'le': (tr: 'Geçmiş Zaman', en: 'Past Tense', zh: '了'),
  'ma': (tr: 'Soru', en: 'Question', zh: '吗'),
  'ne': (tr: 'Soru / Devam', en: 'And you? / Continuation', zh: '呢'),
  'baParticle': (tr: 'Öneri / Rica', en: 'Suggestion', zh: '吧'),
  'a': (tr: 'Ünlem', en: 'Exclamation', zh: '啊'),
  'bu': (tr: 'Olumsuzluk', en: 'Negation', zh: '不'),
  'mei': (tr: 'Olumsuzluk (geçmiş)', en: 'Negation (past)', zh: '没'),
  'zai': (tr: 'Şimdiki Zaman', en: 'Present Continuous', zh: '在'),
  'hui': (tr: '-ebilmek / Gelecek', en: 'Can / Will', zh: '会'),
  'neng': (tr: '-ebilmek', en: 'Can / Able', zh: '能'),
  'keyi': (tr: 'İzin / -ebilmek', en: 'May / Can', zh: '可以'),
  'yao': (tr: 'İstemek / Gelecek', en: 'Want / Will', zh: '要'),
  'xiang': (tr: 'İstemek / Düşünmek', en: 'Want / Think', zh: '想'),
  'dou': (tr: 'Hepsi / Tümü', en: 'All / Both', zh: '都'),
  'zenme': (tr: 'Nasıl', en: 'How', zh: '怎么'),
  'zhengfan': (tr: 'Olumlu-Olumsuz Soru', en: 'A-not-A Question', zh: 'A不A'),
  'tai': (tr: 'Çok / Aşırı', en: 'Too', zh: '太'),
  'dui': (tr: '-e / -a', en: 'Toward / To', zh: '对'),
  'gei': (tr: '-e Vermek', en: 'To / For', zh: '给'),
  'gen': (tr: 'İle', en: 'With', zh: '跟'),
  'zaiAgain': (tr: 'Tekrar / Sonra', en: 'Again / Then', zh: '再'),
  // HSK 2
  'guo': (tr: 'Deneyim', en: 'Experience', zh: '过'),
  'zhe': (tr: 'Süreklilik', en: 'Durative', zh: '着'),
  'deComplement': (tr: 'Tamlayıcı', en: 'Complement', zh: '得'),
  'deAdverbial': (tr: 'Zarf', en: 'Adverbial', zh: '地'),
  'jiu': (tr: 'Hemen / -ince', en: 'Then / Right away', zh: '就'),
  'hai': (tr: 'Hâlâ / Ayrıca', en: 'Still / Also', zh: '还'),
  'yijing': (tr: 'Zaten / Çoktan', en: 'Already', zh: '已经'),
  'cai': (tr: 'Ancak / -ince', en: 'Only Then', zh: '才'),
  'bi': (tr: 'Karşılaştırma', en: 'Comparison', zh: '比'),
  'weishenme': (tr: 'Neden', en: 'Why', zh: '为什么'),
  'zenmeyang': (tr: 'Ne Dersin', en: 'How About', zh: '怎么样'),
  'yinwei': (tr: 'Çünkü', en: 'Because', zh: '因为'),
  'suoyi': (tr: 'Bu Yüzden', en: 'Therefore', zh: '所以'),
  'qilai': (tr: 'Başlama', en: 'Start / Up', zh: '起来'),
  'jieguo': (tr: 'Sonuç Tamlayıcı', en: 'Result Complement', zh: '结果补语'),
  'cong': (tr: '-den', en: 'From', zh: '从'),
  'li': (tr: '-e Uzaklık', en: 'Distance From', zh: '离'),
  'wei': (tr: 'İçin', en: 'For', zh: '为'),
  'changchang': (tr: 'Sık Sık', en: 'Often', zh: '常常'),
  'bijiao': (tr: 'Oldukça', en: 'Relatively', zh: '比较'),
  'youAgain': (tr: 'Yine', en: 'Again', zh: '又'),
  'geng': (tr: 'Daha', en: 'More', zh: '更'),
  'zui': (tr: 'En', en: 'Most', zh: '最'),
  'haishi': (tr: 'Yoksa', en: 'Or', zh: '还是'),
  // HSK 3
  'ba': (tr: '把 Yapısı', en: '把 Construction', zh: '把'),
  'bei': (tr: 'Edilgen', en: 'Passive', zh: '被'),
  'shiDe': (tr: 'Vurgu', en: 'Emphasis', zh: '是…的'),
  'yinggai': (tr: '-meli / Gerekir', en: 'Should', zh: '应该'),
  'dei': (tr: 'Zorunluluk', en: 'Must', zh: '得'),
  'dasuan': (tr: 'Planlamak', en: 'Plan To', zh: '打算'),
  'ruguo': (tr: 'Eğer', en: 'If', zh: '如果'),
  'danshi': (tr: 'Ama', en: 'But', zh: '但是'),
  'suiran': (tr: '-e Rağmen', en: 'Although', zh: '虽然'),
  'genYiyang': (tr: 'Aynı', en: 'Same As', zh: '跟…一样'),
  'quxiang': (tr: 'Yön Tamlayıcı', en: 'Directional Complement', zh: '趋向补语'),
  'weile': (tr: 'İçin / Amacıyla', en: 'In Order To', zh: '为了'),
  'guanyu': (tr: 'Hakkında', en: 'About', zh: '关于'),
  'chule': (tr: 'Dışında', en: 'Except / Besides', zh: '除了'),
  'yizhi': (tr: 'Sürekli', en: 'Continuously', zh: '一直'),
  'gan': (tr: 'Cesaret Etmek', en: 'Dare', zh: '敢'),
  'xuyao': (tr: 'İhtiyaç', en: 'Need', zh: '需要'),
  'yibian': (tr: 'Hem…Hem', en: 'While', zh: '一边'),
  'ranhou': (tr: 'Sonra', en: 'Then', zh: '然后'),
  'yueyue': (tr: '-dikçe', en: 'The More…', zh: '越…越'),
  'yuelaiyue': (tr: 'Gitgide', en: 'More and More', zh: '越来越'),
  'dehua': (tr: '-se / ise', en: 'If', zh: '的话'),
  'zhongyu': (tr: 'Sonunda', en: 'Finally', zh: '终于'),
  'nandao': (tr: 'Yoksa… mı', en: "Don't Tell Me", zh: '难道'),
  // HSK 4
  'keneng': (tr: 'Olasılık Tamlayıcı', en: 'Potential Complement', zh: '可能补语'),
  'chengdu': (tr: 'Derece Tamlayıcı', en: 'Degree Complement', zh: '程度补语'),
  'dongliang': (tr: 'Eylem-Sayı Tamlayıcı', en: 'Action-Measure Complement', zh: '动量补语'),
  'shiliang': (tr: 'Süre Tamlayıcı', en: 'Duration Complement', zh: '时量补语'),
  'zhengzai': (tr: 'Tam Şimdi', en: 'Right Now', zh: '正在'),
  'xiaqu': (tr: 'Sürdürme', en: 'Continue', zh: '下去'),
  'meiyou': (tr: '…Kadar Değil', en: 'Not As… As', zh: '没有'),
  'buru': (tr: '…den İyi Değil', en: 'Not As Good As', zh: '不如'),
  'zhiyao': (tr: 'Yeter ki', en: 'As Long As', zh: '只要'),
  'zhiyou': (tr: 'Ancak / Yalnızca', en: 'Only If', zh: '只有'),
  'wulun': (tr: 'Ne Olursa Olsun', en: 'No Matter', zh: '无论'),
  'buguan': (tr: 'Fark Etmez', en: 'Regardless', zh: '不管'),
  'jiran': (tr: 'Madem', en: 'Since', zh: '既然'),
  'budan': (tr: 'Sadece Değil', en: 'Not Only', zh: '不但'),
  'erqie': (tr: 'Ayrıca', en: 'Moreover', zh: '而且'),
  'huozhe': (tr: 'Veya', en: 'Or', zh: '或者'),
  'lian': (tr: 'Bile', en: 'Even', zh: '连'),
  'liandou': (tr: '…Bile', en: 'Even…', zh: '连…都'),
  'genju': (tr: '-e Göre', en: 'According To', zh: '根据'),
  'anzhao': (tr: '-e Uygun', en: 'In Accordance With', zh: '按照'),
  'jiaru': (tr: 'Şayet', en: 'Supposing', zh: '假如'),
  'yaoshi': (tr: 'Eğer', en: 'If', zh: '要是'),
  'yinci': (tr: 'Bu Nedenle', en: 'Therefore', zh: '因此'),
  'que': (tr: 'Oysa', en: 'Yet / However', zh: '却'),
  // HSK 5
  'cunxian': (tr: 'Varoluş Cümlesi', en: 'Existential Sentence', zh: '存现句'),
  'jianyu': (tr: 'Geçişli Özne', en: 'Pivotal Sentence', zh: '兼语句'),
  'liandong': (tr: 'Ardışık Eylem', en: 'Serial Verb', zh: '连动句'),
  'chongdong': (tr: 'Yinelenen Fiil', en: 'Verb-Copying', zh: '重动句'),
  'bixu': (tr: 'Mutlaka', en: 'Must', zh: '必须'),
  'fouze': (tr: 'Aksi Halde', en: 'Otherwise', zh: '否则'),
  'raner': (tr: 'Ancak', en: 'However', zh: '然而'),
  'jishi': (tr: 'Olsa Bile', en: 'Even If', zh: '即使'),
  'bujin': (tr: 'Sadece Değil', en: 'Not Only', zh: '不仅'),
  'shenzhi': (tr: 'Hatta', en: 'Even', zh: '甚至'),
  'yaome': (tr: 'Ya…Ya', en: 'Either…Or', zh: '要么'),
  'yushi': (tr: 'Böylece', en: 'Thereupon', zh: '于是'),
  'wanyi': (tr: 'Olur da', en: 'In Case', zh: '万一'),
  'xiangPrep': (tr: '-e Doğru', en: 'Toward', zh: '向'),
  // HSK 6
  'napa': (tr: 'Olsa da', en: 'Even If', zh: '哪怕'),
  'jinguan': (tr: '-e Rağmen', en: 'Despite', zh: '尽管'),
  'chufei': (tr: '-medikçe', en: 'Unless', zh: '除非'),
  'fanwen': (tr: 'Retorik Soru', en: 'Rhetorical Question', zh: '反问句'),
  'shuangchong': (tr: 'İkili Olumsuzluk', en: 'Double Negation', zh: '双重否定'),
  'general': (tr: 'Genel', en: 'General', zh: '一般'),
};

// Unit title: "{meaning} ({zh})" in the active language, e.g. "Geçmiş Zaman (了)".
String grammarLabel(String? name, {required bool tr}) {
  final m = name == null ? null : kGrammarMeaning[name];
  if (m == null) return '—';
  return '${tr ? m.tr : m.en} (${m.zh})';
}

// Reverse lookup: which level (L = HSK 1-6) a grammar point belongs to. Drives
// the auto "L" badge in the admin and the path placement of a tagged video.
final Map<String, int> _grammarHsk = {
  for (final e in kGrammarByHsk.entries)
    for (final c in e.value) c.name: e.key,
};

int? hskOfGrammar(String? name) => name == null ? null : _grammarHsk[name];

// The 1-based unit number a grammar point occupies within its level (its
// position in kGrammarByHsk). Drives the admin's auto unit assignment.
int? unitOfGrammar(String? name) {
  if (name == null) return null;
  final l = _grammarHsk[name];
  if (l == null) return null;
  final list = kGrammarByHsk[l]!;
  final i = list.indexWhere((c) => c.name == name);
  return i < 0 ? null : i + 1;
}

// Life / topic categories a clip can belong to (multi-label). `name` is the
// stored id; tr/en are the labels. Auto-assigned at import (python classifier),
// editable in the admin, filterable on the home feed.
class LifeCategory {
  final String name;
  final String tr;
  final String en;
  const LifeCategory._(this.name, this.tr, this.en);

  static const dailyLife =
      LifeCategory._('daily_life', 'Günlük Hayat', 'Daily Life');
  static const family = LifeCategory._('family', 'Aile', 'Family');
  static const food = LifeCategory._('food', 'Yemek & İçecek', 'Food & Drink');
  static const shopping = LifeCategory._('shopping', 'Alışveriş', 'Shopping');
  static const travel =
      LifeCategory._('travel', 'Seyahat & Ulaşım', 'Travel & Transport');
  static const business =
      LifeCategory._('business', 'İş & Kariyer', 'Work & Business');
  static const school =
      LifeCategory._('school', 'Eğitim & Okul', 'Education & School');
  static const health = LifeCategory._('health', 'Sağlık', 'Health');
  static const technology =
      LifeCategory._('technology', 'Teknoloji & Bilim', 'Tech & Science');
  static const entertainment =
      LifeCategory._('entertainment', 'Eğlence & Sanat', 'Entertainment & Arts');
  static const sports = LifeCategory._('sports', 'Spor', 'Sports');
  static const children = LifeCategory._('children', 'Çocuk', 'Children');

  static const List<LifeCategory> values = [
    dailyLife, family, food, shopping, travel, business,
    school, health, technology, entertainment, sports, children,
  ];

  static String labelFor(String name, {bool isTr = true}) {
    for (final c in values) {
      if (c.name == name) return isTr ? c.tr : c.en;
    }
    return name;
  }
}

// Sentinel inserted between sentences inside target_words for multi-sentence
// clips. Joining target_words then yields stacked lines; word-chip renderers
// and counts must skip it (see spokenWords).
const String kWordLineBreak = '\n';

class VideoSegmentModel {
  final String videoId;
  final VideoSourceType sourceType;
  final String? youtubeId;
  final String? videoUrl;
  final double startTime;
  final double endTime;
  final int hskLevel;
  final String transcription;
  final String pinyin;
  final List<String> targetWords;
  final QuizData quiz;
  final QuizCategory quizCategory;
  final String lifeCategory; // 'daily_life' | 'business' | 'children'
  // Multi-tag classification (admin-editable). The single fields above stay as
  // the "primary" (first tag) for backward compatibility; these drive filtering.
  final List<int> hskLevels;
  final List<String> quizCategories;
  final List<String> lifeCategories;
  // Manual learning-path placement (admin-set). Level (L1-L6) defaults to the
  // grammar rule's level but can be overridden; unit (1-30) and phase circle
  // (1-4, 0 = "Diğer") are picked by hand.
  final int? level;
  final int? unit;
  final int? phase;
  final bool isActive;
  final DateTime createdAt;

  const VideoSegmentModel({
    required this.videoId,
    required this.sourceType,
    this.youtubeId,
    this.videoUrl,
    required this.startTime,
    required this.endTime,
    required this.hskLevel,
    required this.transcription,
    required this.pinyin,
    required this.targetWords,
    required this.quiz,
    this.quizCategory = QuizCategory.general,
    this.lifeCategory = 'daily_life',
    this.hskLevels = const [],
    this.quizCategories = const [],
    this.lifeCategories = const [],
    this.level,
    this.unit,
    this.phase,
    this.isActive = true,
    required this.createdAt,
  });

  // Effective tag lists — fall back to the single primary value when the
  // multi-tag arrays are empty (older rows / cache).
  List<int> get hskLevelTags => hskLevels.isNotEmpty ? hskLevels : [hskLevel];
  List<String> get categoryTags =>
      quizCategories.isNotEmpty ? quizCategories : [quizCategory.name];
  List<String> get lifeTags =>
      lifeCategories.isNotEmpty ? lifeCategories : [lifeCategory];

  // Confirmed words without the line-break sentinel — for counts, word chips,
  // and "save to dictionary".
  List<String> get spokenWords =>
      targetWords.where((w) => w != kWordLineBreak).toList();

  // Per-sentence groups (split on the sentinel) — for line-by-line display.
  List<List<String>> get wordLines {
    final lines = <List<String>>[];
    var cur = <String>[];
    for (final w in targetWords) {
      if (w == kWordLineBreak) {
        lines.add(cur);
        cur = [];
      } else {
        cur.add(w);
      }
    }
    lines.add(cur);
    return lines.where((l) => l.isNotEmpty).toList();
  }

  // Subtitle text honouring confirmed word order + line breaks; falls back to
  // the raw transcription when no words are confirmed.
  String get subtitleText {
    final joined = targetWords.join('');
    return joined.isNotEmpty ? joined : transcription;
  }

  factory VideoSegmentModel.fromMap(Map<String, dynamic> data) {
    final sourceStr = data['source_type'] as String? ?? 'youtube';
    return VideoSegmentModel(
      videoId: data['id'] as String? ?? '',
      sourceType: sourceStr == 'self_hosted'
          ? VideoSourceType.selfHosted
          : VideoSourceType.youtube,
      youtubeId: data['youtube_id'] as String?,
      videoUrl: data['video_url'] as String?,
      startTime: (data['start_time'] as num?)?.toDouble() ?? 0,
      endTime: (data['end_time'] as num?)?.toDouble() ?? 0,
      hskLevel: (data['hsk_level'] as num?)?.toInt() ?? 1,
      transcription: data['transcription'] as String? ?? '',
      pinyin: data['pinyin'] as String? ?? '',
      targetWords: List<String>.from(data['target_words'] ?? []),
      quiz: QuizData.fromMap(data['quiz'] as Map<String, dynamic>? ?? {}),
      quizCategory: QuizCategory.fromString(data['quiz_category'] as String? ?? 'general'),
      lifeCategory: data['life_category'] as String? ?? 'daily_life',
      hskLevels: ((data['hsk_levels'] as List<dynamic>?) ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      quizCategories: ((data['quiz_categories'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      lifeCategories: ((data['life_categories'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      level: (data['level'] as num?)?.toInt(),
      unit: (data['unit'] as num?)?.toInt(),
      phase: (data['phase'] as num?)?.toInt(),
      isActive: data['is_active'] as bool? ?? true,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
    );
  }

  factory VideoSegmentModel.fromCache(String id, Map<String, dynamic> data) {
    final sourceStr = data['sourceType'] as String? ?? 'youtube';
    return VideoSegmentModel(
      videoId: id,
      sourceType: sourceStr == 'self_hosted'
          ? VideoSourceType.selfHosted
          : VideoSourceType.youtube,
      youtubeId: data['youtubeId'] as String?,
      videoUrl: data['videoUrl'] as String?,
      startTime: (data['startTime'] as num?)?.toDouble() ?? 0,
      endTime: (data['endTime'] as num?)?.toDouble() ?? 0,
      hskLevel: (data['hskLevel'] as num?)?.toInt() ?? 1,
      transcription: data['transcription'] as String? ?? '',
      pinyin: data['pinyin'] as String? ?? '',
      targetWords: List<String>.from(data['targetWords'] ?? []),
      quiz: QuizData.fromMap(data['quiz'] as Map<String, dynamic>? ?? {}),
      quizCategory: QuizCategory.fromString(data['quizCategory'] as String? ?? 'general'),
      lifeCategory: data['lifeCategory'] as String? ?? 'daily_life',
      hskLevels: ((data['hskLevels'] as List<dynamic>?) ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      quizCategories: ((data['quizCategories'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      lifeCategories: ((data['lifeCategories'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      level: (data['level'] as num?)?.toInt(),
      unit: (data['unit'] as num?)?.toInt(),
      phase: (data['phase'] as num?)?.toInt(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: data['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': videoId,
        'source_type': sourceType == VideoSourceType.youtube ? 'youtube' : 'self_hosted',
        'youtube_id': youtubeId,
        'video_url': videoUrl,
        'start_time': startTime,
        'end_time': endTime,
        'hsk_level': hskLevel,
        'transcription': transcription,
        'pinyin': pinyin,
        'target_words': targetWords,
        'quiz': quiz.toMap(),
        'quiz_category': quizCategory.name,
        'life_category': lifeCategory,
        'hsk_levels': hskLevels,
        'quiz_categories': quizCategories,
        'life_categories': lifeCategories,
        'level': level,
        'unit': unit,
        'phase': phase,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toCacheMap() => {
        'sourceType': sourceType == VideoSourceType.youtube ? 'youtube' : 'self_hosted',
        'youtubeId': youtubeId,
        'videoUrl': videoUrl,
        'startTime': startTime,
        'endTime': endTime,
        'hskLevel': hskLevel,
        'transcription': transcription,
        'pinyin': pinyin,
        'targetWords': targetWords,
        'quiz': quiz.toMap(),
        'quizCategory': quizCategory.name,
        'lifeCategory': lifeCategory,
        'hskLevels': hskLevels,
        'quizCategories': quizCategories,
        'lifeCategories': lifeCategories,
        'level': level,
        'unit': unit,
        'phase': phase,
        'isActive': isActive,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  double get durationSeconds => endTime - startTime;
  bool get isYouTube => sourceType == VideoSourceType.youtube;
  bool get isSelfHosted => sourceType == VideoSourceType.selfHosted;

  int get hanCount =>
      RegExp(r'[一-鿿]').allMatches(transcription).length;

  String get sentenceLength {
    if (hanCount <= 5) return '1-5字';
    if (hanCount <= 10) return '6-10字';
    if (hanCount <= 15) return '11-15字';
    if (hanCount <= 20) return '16-20字';
    return '21字+';
  }
}

class QuizData {
  final String question;
  final String correctAnswer; // tr (top-level)
  final String wrongAnswer; // tr
  final String correctAnswerEn;
  final String wrongAnswerEn;
  final String correctAnswerKo;
  final String wrongAnswerKo;
  final String correctAnswerJa;
  final String wrongAnswerJa;
  final String correctAnswerId;
  final String wrongAnswerId;

  const QuizData({
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswer,
    this.correctAnswerEn = '',
    this.wrongAnswerEn = '',
    this.correctAnswerKo = '',
    this.wrongAnswerKo = '',
    this.correctAnswerJa = '',
    this.wrongAnswerJa = '',
    this.correctAnswerId = '',
    this.wrongAnswerId = '',
  });

  factory QuizData.fromMap(Map<String, dynamic> map) {
    final en = (map['en'] as Map<String, dynamic>?) ?? const {};
    final ko = (map['ko'] as Map<String, dynamic>?) ?? const {};
    final ja = (map['ja'] as Map<String, dynamic>?) ?? const {};
    final idn = (map['id'] as Map<String, dynamic>?) ?? const {};
    return QuizData(
      question: map['question'] as String? ?? '',
      correctAnswer: map['correctAnswer'] as String? ?? '',
      wrongAnswer: map['wrongAnswer'] as String? ?? '',
      correctAnswerEn: en['correctAnswer'] as String? ?? '',
      wrongAnswerEn: en['wrongAnswer'] as String? ?? '',
      correctAnswerKo: ko['correctAnswer'] as String? ?? '',
      wrongAnswerKo: ko['wrongAnswer'] as String? ?? '',
      correctAnswerJa: ja['correctAnswer'] as String? ?? '',
      wrongAnswerJa: ja['wrongAnswer'] as String? ?? '',
      correctAnswerId: idn['correctAnswer'] as String? ?? '',
      wrongAnswerId: idn['wrongAnswer'] as String? ?? '',
    );
  }

  // Resolve options for the UI language. Korean/Japanese/Indonesian fall back to
  // English (closer for those readers than Turkish), everything else to Turkish
  // (the always-saved top-level fields).
  String correctFor(String lang) => switch (lang) {
        'en' when correctAnswerEn.isNotEmpty => correctAnswerEn,
        'ko' when correctAnswerKo.isNotEmpty => correctAnswerKo,
        'ko' when correctAnswerEn.isNotEmpty => correctAnswerEn,
        'ja' when correctAnswerJa.isNotEmpty => correctAnswerJa,
        'ja' when correctAnswerEn.isNotEmpty => correctAnswerEn,
        'id' when correctAnswerId.isNotEmpty => correctAnswerId,
        'id' when correctAnswerEn.isNotEmpty => correctAnswerEn,
        _ => correctAnswer,
      };
  String wrongFor(String lang) => switch (lang) {
        'en' when wrongAnswerEn.isNotEmpty => wrongAnswerEn,
        'ko' when wrongAnswerKo.isNotEmpty => wrongAnswerKo,
        'ko' when wrongAnswerEn.isNotEmpty => wrongAnswerEn,
        'ja' when wrongAnswerJa.isNotEmpty => wrongAnswerJa,
        'ja' when wrongAnswerEn.isNotEmpty => wrongAnswerEn,
        'id' when wrongAnswerId.isNotEmpty => wrongAnswerId,
        'id' when wrongAnswerEn.isNotEmpty => wrongAnswerEn,
        _ => wrongAnswer,
      };

  Map<String, dynamic> toMap() => {
        'question': question,
        'correctAnswer': correctAnswer,
        'wrongAnswer': wrongAnswer,
        if (correctAnswerEn.isNotEmpty || wrongAnswerEn.isNotEmpty)
          'en': {'correctAnswer': correctAnswerEn, 'wrongAnswer': wrongAnswerEn},
        if (correctAnswerKo.isNotEmpty || wrongAnswerKo.isNotEmpty)
          'ko': {'correctAnswer': correctAnswerKo, 'wrongAnswer': wrongAnswerKo},
        if (correctAnswerJa.isNotEmpty || wrongAnswerJa.isNotEmpty)
          'ja': {'correctAnswer': correctAnswerJa, 'wrongAnswer': wrongAnswerJa},
        if (correctAnswerId.isNotEmpty || wrongAnswerId.isNotEmpty)
          'id': {'correctAnswer': correctAnswerId, 'wrongAnswer': wrongAnswerId},
      };
}
