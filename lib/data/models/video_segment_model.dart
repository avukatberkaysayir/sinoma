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

  const QuizData({
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswer,
    this.correctAnswerEn = '',
    this.wrongAnswerEn = '',
  });

  factory QuizData.fromMap(Map<String, dynamic> map) {
    final en = (map['en'] as Map<String, dynamic>?) ?? const {};
    return QuizData(
      question: map['question'] as String? ?? '',
      correctAnswer: map['correctAnswer'] as String? ?? '',
      wrongAnswer: map['wrongAnswer'] as String? ?? '',
      correctAnswerEn: en['correctAnswer'] as String? ?? '',
      wrongAnswerEn: en['wrongAnswer'] as String? ?? '',
    );
  }

  // Resolve options for the UI language; fall back to Turkish (the always-saved
  // top-level fields) when the requested language has no saved text.
  String correctFor(String lang) =>
      (lang == 'en' && correctAnswerEn.isNotEmpty) ? correctAnswerEn : correctAnswer;
  String wrongFor(String lang) =>
      (lang == 'en' && wrongAnswerEn.isNotEmpty) ? wrongAnswerEn : wrongAnswer;

  Map<String, dynamic> toMap() => {
        'question': question,
        'correctAnswer': correctAnswer,
        'wrongAnswer': wrongAnswer,
        if (correctAnswerEn.isNotEmpty || wrongAnswerEn.isNotEmpty)
          'en': {'correctAnswer': correctAnswerEn, 'wrongAnswer': wrongAnswerEn},
      };
}
