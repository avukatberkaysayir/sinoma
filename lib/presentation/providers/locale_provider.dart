import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

// UI languages the app actually ships.
const kSupportedUiLanguages = ['tr', 'en', 'ko'];

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier([Locale? initial]) : super(initial ?? const Locale('tr'));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (code != null && kSupportedUiLanguages.contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  Future<bool> hasSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kLocaleKey);
  }
}

// ── Inline translations (TR / EN / KO) ───────────────────────────────────────
// Korean follows natural app conventions (해요체 for sentences, noun-form for
// buttons/labels) — written as a Korean product would phrase it, not as a
// literal translation.

class AppL10n {
  final String languageCode;
  const AppL10n._(this.languageCode);

  static AppL10n of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'tr';
    return AppL10n._(code);
  }

  static AppL10n fromCode(String code) => AppL10n._(code);

  bool get _isTr => languageCode == 'tr';
  bool get _isKo => languageCode == 'ko';

  String _t(String tr, String en, String ko) =>
      _isTr ? tr : (_isKo ? ko : en);

  // ── Language screen ─────────────────────────────────────────────────────────
  String get chooseLanguage   => _t('Dil Seçin', 'Choose Language', '언어 선택');
  String get continueBtn      => _t('Devam Et', 'Continue', '계속하기');
  String get languageSubtitle => _t('İstediğin zaman ayarlardan değiştirebilirsin',
      'You can change this anytime in settings', '설정에서 언제든지 변경할 수 있어요');

  // ── Home ────────────────────────────────────────────────────────────────────
  String get learn            => _t('Öğren', 'Learn', '학습');
  String get games            => _t('Oyunlar', 'Games', '게임');
  String get community        => _t('Topluluk', 'Community', '커뮤니티');
  String get filters          => _t('Filtreler', 'Filters', '필터');
  String get resetAll         => _t('Temizle', 'Reset All', '초기화');
  String get grammarPatterns  => _t('文法  GRAMER', '文法  GRAMMAR', '文法  문법');
  String get sentenceLength   => _t('字数  CÜMLE UZUNLUĞU', '字数  SENTENCE LENGTH', '字数  문장 길이');
  String get allCategories    => _t('全部  Tümü', '全部  All', '全部  전체');
  String get noVideos         => _t('Bu seviyede video yok.', 'No videos at your level.', '내 레벨에 맞는 영상이 없어요.');
  String get noVideosFiltered => _t('Filtreyle eşleşen video yok.', 'No videos match filters.', '필터에 맞는 영상이 없어요.');
  String get retry            => _t('Tekrar Dene', 'Retry', '다시 시도');
  String get failedToLoad     => _t('Videolar yüklenemedi', 'Failed to load videos', '영상을 불러오지 못했어요');
  String get activeFilters    => _t('Aktif filtreler', 'Active filters', '적용된 필터');
  String get clearAllLbl      => _t('Tümünü temizle', 'Clear all', '모두 지우기');
  String get subtitlesOn      => _t('Altyazılı', 'Subtitles On', '자막 보기');
  String get subtitlesOff     => _t('Altyazısız', 'Subtitles Off', '자막 없이');
  String get subtitleTitle    => _t('Altyazı', 'Subtitle', '자막');

  // ── Practice: playlists + reports ───────────────────────────────────────────
  String get addToPlaylist      => _t('Listeye Ekle', 'Add to Playlist', '재생목록에 추가');
  String get myPlaylists        => _t('LİSTELERİM', 'MY LISTS', '내 재생목록');
  String get newPlaylistHint    => _t('Yeni liste adı…', 'New playlist name…', '새 재생목록 이름…');
  String get createAndAdd       => _t('Oluştur ve Ekle', 'Create & Add', '만들고 추가');
  String get noPlaylistsYet     => _t('Henüz listen yok — aşağıdan oluştur.',
      'No playlists yet — create one below.', '아직 재생목록이 없어요 — 아래에서 만들어 보세요.');
  String get signInForPlaylists => _t('Liste oluşturmak için giriş yap.',
      'Sign in to use playlists.', '재생목록을 만들려면 로그인하세요.');
  String get closeLabel         => _t('Kapat', 'Close', '닫기');
  String get reportProblem      => _t('Sorun Bildir', 'Report a Problem', '문제 신고');
  String get reportHint         => _t('Bu videodaki sorunu kısaca anlat… (en fazla 300 karakter)',
      'Briefly describe the problem… (max 300 characters)', '이 영상의 문제를 간단히 알려 주세요… (최대 300자)');
  String get reportSend         => _t('Gönder', 'Send', '보내기');
  String get reportThanks       => _t('✓ Bildirimin alındı, teşekkürler!',
      '✓ Report received, thanks!', '✓ 신고가 접수되었어요. 감사합니다!');

  // ── Practice extras ─────────────────────────────────────────────────────────
  String get startHskTest   => _t('HSK TESTİNE BAŞLA', 'START HSK TEST', 'HSK 테스트 시작');
  String get topicGroup     => _t('KONU', 'TOPIC', '주제');
  String get noListsRail    => _t('Henüz listen yok — player altındaki "Listeye Ekle" ile oluştur.',
      'No lists yet — use "Add to Playlist" under the player.',
      '아직 재생목록이 없어요 — 플레이어 아래 "재생목록에 추가"로 만들어 보세요.');
  String get prevTooltip    => _t('Önceki', 'Previous', '이전');
  String get replayTooltip  => _t('Tekrar oynat', 'Replay', '다시 재생');
  String get soundOnTip     => _t('Sesi aç', 'Sound on', '소리 켜기');
  String get qualityDownTip => _t('Kaliteyi düşür', 'Lower quality', '화질 낮추기');
  String get qualityUpTip   => _t('Kaliteyi yükselt', 'Raise quality', '화질 높이기');
  String get soundOffTip    => _t('Sesi kapat', 'Sound off', '소리 끄기');
  String get notInDict      => _t('Sözlükte bulunamadı.', 'Not found in the dictionary.', '사전에 없는 단어예요.');
  String get videosWord     => _t('video', 'videos', '개 영상');
  // Korean counters attach to the number ("영상 3개"), so count goes inside.
  String videosCount(int n) => _t('$n video', '$n videos', '영상 $n개');

  // ── Dictionary discover panel ───────────────────────────────────────────────
  String get wordOfDay         => _t('GÜNÜN KELİMESİ', 'WORD OF THE DAY', '오늘의 단어');
  String get idiomOfWeek       => _t('HAFTANIN DEYİMİ', 'IDIOM OF THE WEEK', '이번 주 성어');
  String get trendingNow       => _t('POPÜLER ARAMALAR', 'TRENDING NOW', '인기 검색어');
  String get newlyAdded        => _t('YENİ EKLENENLER', 'NEWLY ADDED', '새로 추가된 단어');
  String get testYourChinese   => _t('Çinceni Test Et', 'Test Your Chinese', '중국어 실력 테스트');
  String get testYourChineseSub => _t('20 soruluk HSK seviye testiyle kendini dene.',
      'Try the 20-question HSK placement test.', 'HSK 레벨 테스트(20문항)에 도전해 보세요.');
  String get dictSearchHint    => _t('Çince karakter veya kelime ara…',
      'Search Chinese characters…', '한자나 단어를 검색하세요…');
  String get noResultsFound    => _t('Sonuç bulunamadı', 'No results found', '검색 결과가 없어요');
  String get suggestThisWord   => _t('Bu kelimeyi öner', 'Suggest this word', '이 단어 제안하기');
  String get suggestedLbl      => _t('Önerildi', 'Suggested', '제안 완료');
  String get genericError      => _t('Bir hata oluştu', 'Something went wrong', '문제가 발생했어요');
  String get offlineBanner     => _t('İnternet bağlantısı yok — önbellek gösteriliyor',
      'No internet connection — showing cached data', '인터넷 연결이 없어요 — 캐시된 데이터를 표시 중');
  String get errEmailTaken     => _t('Bu e-posta zaten kayıtlı. Giriş yapmayı deneyin.',
      'This email is already registered. Try signing in.', '이미 가입된 이메일이에요. 로그인해 보세요.');
  String get errBadCredentials => _t('E-posta veya şifre hatalı.',
      'Incorrect email or password.', '이메일 또는 비밀번호가 올바르지 않아요.');
  String get errTooMany        => _t('Çok fazla deneme. Lütfen bekleyin.',
      'Too many attempts. Please wait.', '시도 횟수가 너무 많아요. 잠시 후 다시 시도해 주세요.');
  String get errPasswordShort  => _t('Şifre en az 6 karakter olmalıdır.',
      'Password must be at least 6 characters.', '비밀번호는 6자 이상이어야 해요.');
  String get errInvalidEmail   => _t('Geçersiz e-posta adresi.',
      'Invalid email address.', '올바르지 않은 이메일 주소예요.');
  String get errVerifyPending  => _t('E-posta henüz doğrulanmadı. Gelen kutunuzu kontrol edin.',
      'Email not verified yet. Check your inbox.', '아직 이메일 인증이 안 됐어요. 받은편지함을 확인해 주세요.');
  String get suggestNeedLogin  => _t('Öneri yapmak için giriş yapınız',
      'Sign in to suggest words', '단어를 제안하려면 로그인하세요');

  // ── HSK levels ──────────────────────────────────────────────────────────────
  String hskLabel(int level) => level >= 7 ? _t('Diğer', 'Other', '기타') : 'HSK $level';
  String hskSublabel(int level) => switch (level) {
    1 => _t('Başlangıç', 'Beginner', '입문'),
    2 => _t('Temel', 'Elementary', '초급'),
    3 => _t('Orta', 'Intermediate', '중급'),
    4 => _t('Orta-İleri', 'Upper-Intermediate', '중상급'),
    5 => _t('İleri', 'Advanced', '고급'),
    6 => _t('Uzman', 'Expert', '최상급'),
    _ => '',
  };

  // ── Sidebar / hub ───────────────────────────────────────────────────────────
  String get videoTab      => _t('Öğren', 'Learn', '학습');
  String get dictionaryTab => _t('Sözlük', 'Dictionary', '사전');
  String get socialTab     => _t('Sosyal', 'Social', '소셜');
  String get gamesTab      => _t('Oyun', 'Games', '게임');
  String get hubDictionary => _t('Sözlük', 'Dictionary', '사전');
  String get hubSocial     => _t('Sosyal', 'Social', '소셜');
  String get hubGames      => _t('Oyun', 'Games', '게임');

  // ── Left navigation (path shell) ────────────────────────────────────────────
  String get navProfile    => _t('Profil', 'Profile', '프로필');
  String get navLearn      => _t('Öğren', 'Learn', '학습');
  String get navDictionary => _t('Sözlük', 'Dictionary', '사전');
  String get navPractice   => _t('Alıştırma', 'Practice', '연습');
  String get navRanks      => _t('Rütbeler', 'Ranks', '랭킹');
  String get navTeaHouse   => _t('Çayevi', 'Tea House', '찻집');
  String get navBazaar     => _t('Çarşı', 'Bazaar', '상점');
  String get navSettings   => _t('Ayarlar', 'Settings', '설정');
  String unitTitle(int n)  => _t('$n. Ünite', 'Unit $n', '유닛 $n');
  String get startStamp    => _t('BAŞLA', 'START', '시작');

  // ── Right sidebar ───────────────────────────────────────────────────────────
  String get yourProgress     => _t('İlerlemen', 'Your progress', '내 진행 상황');
  String phasesDone(int d, int t) =>
      _t('$d / $t faz tamamlandı', '$d / $t phases done', '$d / $t 단계 완료');
  String get dailyQuest       => _t('Günlük Görev', 'Daily quest', '오늘의 주문');
  String get completeOnePhase => _t('Bir faz tamamla', 'Complete one phase', '한 단계 완료하기');

  // ── Leaderboard / leagues ───────────────────────────────────────────────────
  String get myLeague       => _t('Ligim', 'My League', '내 랭크');
  String get friendsTab     => _t('Arkadaşlarım', 'Friends', '친구');
  String leagueOf(String n) => _t('$n Ligi', '$n League', '$n 리그');
  // 12 zodiac (生肖) league tiers, bottom-up; the Dragon is the diamond top.
  String leagueName(int tier) => switch (tier) {
        1 => _t('Fare', 'Rat', '쥐'),
        2 => _t('Öküz', 'Ox', '소'),
        3 => _t('Kaplan', 'Tiger', '호랑이'),
        4 => _t('Tavşan', 'Rabbit', '토끼'),
        5 => _t('Yılan', 'Snake', '뱀'),
        6 => _t('At', 'Horse', '말'),
        7 => _t('Keçi', 'Goat', '양'),
        8 => _t('Maymun', 'Monkey', '원숭이'),
        9 => _t('Horoz', 'Rooster', '닭'),
        10 => _t('Köpek', 'Dog', '개'),
        11 => _t('Domuz', 'Pig', '돼지'),
        _ => _t('Ejderha', 'Dragon', '용'),
      };
  String get dragonTab      => _t('Ejderha', 'Dragon', '용');
  String get leagueRules    => _t('Bu haftanın sıralaması — ilk 6 yükselir, son 6 düşer',
      "This week's ranking — top 6 promote, bottom 6 demote",
      '이번 주 순위 — 상위 6명 승급, 하위 6명 강등');
  String get findFriends    => _t('ARKADAŞ ARA', 'FIND FRIENDS', '친구 찾기');
  String get noFriendsYet   => _t('Henüz arkadaşın yok — kullanıcı adıyla arayıp ekleyebilirsin.',
      'No friends yet — search by username and add them.',
      '아직 친구가 없어요 — 사용자 이름으로 검색해서 추가해 보세요.');
  String get typeUsername   => _t('Kullanıcı adı yaz…', 'Type a username…', '사용자 이름 입력…');
  String get addLbl         => _t('Ekle', 'Add', '추가');
  String get friendRequests => _t('Arkadaşlık İstekleri', 'Friend Requests', '친구 요청');
  String get streakTitle    => _t('Seri', 'Streak', '스트릭');
  String streakDays(int n)  => _t('$n gün', '$n days', '$n일');
  String get streakWeek     => _t('1 hafta', '1 week', '1주');
  String get streakMonth    => _t('1 ay', '1 month', '1개월');
  String get streak100      => _t('100 gün', '100 days', '100일');
  String get streak6Months  => _t('6 ay', '6 months', '6개월');
  String get streakHint     => _t('Her gün bir soru cevapla, seri büyüsün.',
      'Answer one question a day to grow the streak.', '매일 한 문제만 풀어도 스트릭이 자라요.');
  String get requestSent    => _t('İstek gönderildi', 'Request sent', '요청 보냄');
  String get acceptLbl      => _t('Onayla', 'Accept', '수락');
  String get declineRequest => _t('Reddet', 'Decline', '거절');
  String get noRequests     => _t('Bekleyen istek yok.', 'No pending requests.', '대기 중인 요청이 없어요.');
  String get removeLbl      => _t('Çıkar', 'Remove', '삭제');
  String get noResultsLbl   => _t('Sonuç yok', 'No results', '결과 없음');
  String get zhuangyuanTitle => _t('Ejderha Sıralaması', 'Dragon Ranking', '용 리그 랭킹');
  String get zhuangyuanDesc => _t('Ejderha Ligi\'nde geçirilen her hafta +1 elmas; dışında kalınan her hafta −1.',
      'Each week in the Dragon League earns +1 diamond; each week outside costs −1.',
      '용 리그에서 보낸 주마다 다이아 +1, 벗어난 주마다 −1이에요.');
  String get noDiamondsYet  => _t('Henüz elmas kazanan yok — Ejderha Ligi\'ne ilk ulaşan sen ol!',
      'No diamonds earned yet — be the first to reach the Dragon League!',
      '아직 다이아를 얻은 사람이 없어요 — 첫 용 리그에 도전해 보세요!');
  String get leagueHowTitle => _t('Lig Nasıl Çalışır?', 'How ranks work', '랭크 안내');
  String get leagueHowBody  => _t('Ders tamamladıkça puan kazanır, haftalık sıralamada yükselirsin.',
      'Earn points by completing lessons and climb the weekly ranking.',
      '학습을 완료하면 점수를 얻고 주간 순위가 올라가요.');

  // ── Tea house (quests) ──────────────────────────────────────────────────────
  String get teaHouseTitle  => _t('Çayevi Siparişleri ☕', 'Tea House Orders ☕', '찻집 주문 ☕');
  String teaHouseSub(int n) => _t('Siparişleri tamamla, hongbao 🧧 kazan! Bugün 3 siparişin $n tanesi hazır.',
      'Fill the orders, earn hongbao 🧧! $n of 3 ready today.',
      '주문을 완료하고 홍바오 🧧 를 받아 보세요! 오늘 3개 중 $n개 완료.');
  String get todaysOrders   => _t('Günün Siparişleri', "Today's Orders", '오늘의 주문');
  String hoursLeftLbl(int h) => _t('$h SAAT', '$h HOURS', '$h시간 남음');
  String get hongbaoToast   => _t('🧧 Hongbao açıldı: +20 altın!', '🧧 Hongbao: +20 gold!', '🧧 홍바오 획득: 금화 +20!');
  String questEarnPoints(int n)  => _t('$n puan kazan', 'Earn $n points', '$n점 모으기');
  String questAnswerN(int n)     => _t('$n soru cevapla', 'Answer $n questions', '문제 $n개 풀기');
  String questCorrectN(int n)    => _t('$n doğru cevap ver', 'Get $n correct answers', '정답 $n개 맞히기');
  String get questKeepStreak     => _t('Seriyi sürdür (bugün 1 soru)', 'Keep the streak (1 today)', '연속 기록 잇기 (오늘 1문제)');
  String get monthlyBadges  => _t('Aylık Rozetler', 'Monthly badges', '이달의 배지');

  // ── Badges (rozetler): Three Kingdoms + mythology achievement ladder ───────
  String get badgesTitle    => _t('Rozetler', 'Badges', '배지');
  String get badgesSub      => _t('Üç Krallık kahramanları ve Çin mitolojisinin efsaneleri — başarılarınla mühürlerini kazan.',
      'Heroes of the Three Kingdoms and legends of Chinese mythology — earn their seals with your progress.',
      '삼국지 영웅과 중국 신화의 전설 — 학습 성과로 인장을 모아 보세요.');
  String get badgeCatSages    => _t('Bilgeler — izleme', 'Sages — watch time', '책사 — 시청 시간');
  String get badgeCatWarriors => _t('Savaşçılar — doğru cevap', 'Warriors — correct answers', '무장 — 정답 수');
  String get badgeCatRulers   => _t('Hükümdarlar — üniteler', 'Rulers — units', '군주 — 유닛');
  String get badgeCatLegends  => _t('Efsaneler — seviyeler', 'Legends — levels', '전설 — 레벨');
  String badgeWatchCond(int m)  => _t('$m dk video izle', 'Watch $m min', '영상 $m분 시청');
  String badgeCorrectCond(int n) => _t('$n doğru cevap ver', '$n correct answers', '정답 $n개 달성');
  String badgeUnitsCond(int n)  => _t('$n ünite bitir', 'Finish $n units', '유닛 $n개 완료');
  String badgeLevelsCond(int n) => _t('$n seviye bitir', 'Finish $n levels', '레벨 $n개 완료');
  // Figure display names: pinyin for TR/EN, established Korean readings for KO.
  String badgeFigure(String id) => switch (id) {
        'xushu' => _t('Xu Shu', 'Xu Shu', '서서'),
        'pangtong' => _t('Pang Tong', 'Pang Tong', '방통'),
        'zhugeliang' => _t('Zhuge Liang', 'Zhuge Liang', '제갈량'),
        'jiangziya' => _t('Jiang Ziya', 'Jiang Ziya', '강태공'),
        'zhaoyun' => _t('Zhao Yun', 'Zhao Yun', '조운'),
        'guanyu' => _t('Guan Yu', 'Guan Yu', '관우'),
        'lvbu' => _t('Lü Bu', 'Lü Bu', '여포'),
        'nezha' => _t('Nezha', 'Nezha', '나타'),
        'liubei' => _t('Liu Bei', 'Liu Bei', '유비'),
        'sunquan' => _t('Sun Quan', 'Sun Quan', '손권'),
        'caocao' => _t('Cao Cao', 'Cao Cao', '조조'),
        'pangu' => _t('Pangu', 'Pangu', '반고'),
        'zhangfei' => _t('Zhang Fei', 'Zhang Fei', '장비'),
        'zhouyu' => _t('Zhou Yu', 'Zhou Yu', '주유'),
        'simayi' => _t('Sima Yi', 'Sima Yi', '사마의'),
        'nuwa' => _t('Nüwa', 'Nüwa', '여와'),
        _ => id,
      };
  String get monthlyBadgesBody => _t('Görevleri tamamla, bu ayın rozetini kazan.',
      "Complete quests to earn this month's badge.", '주문을 완료하고 이달의 배지를 받아 보세요.');

  // ── Bazaar (shop) ───────────────────────────────────────────────────────────
  String get heartsTitle    => _t('Canlar', 'Hearts', '하트');
  String get refillHearts   => _t('Canları Yenile', 'Refill hearts', '하트 충전');
  String refillSub(int h, int m) => _t('Canlarını tekrar doldur ($h/$m)',
      'Refill your hearts ($h/$m)', '하트를 다시 채워요 ($h/$m)');
  String get fullLbl        => _t('TAM', 'FULL', '가득 참');
  String get refillLbl      => _t('YENİLE', 'REFILL', '충전');
  String get unlimitedHearts => _t('Sınırsız Can', 'Unlimited hearts', '무제한 하트');
  String get premiumSub     => _t('Premium ile canın hiç tükenmesin', 'Never run out with Premium', '프리미엄으로 하트 걱정 없이!');
  String get powerUps       => _t('Güçlendiriciler', 'Power-ups', '아이템');
  String get streakFreeze   => _t('Seri Dondurma', 'Streak freeze', '연속 기록 보호');
  String get streakFreezeSub => _t('Bir gün ara verince serin bozulmasın (yakında)',
      'Protect your streak for a day (soon)', '하루 쉬어도 연속 기록을 지켜줘요 (출시 예정)');
  String get soonLbl        => _t('YAKINDA', 'SOON', '준비 중');

  // ── Settings ────────────────────────────────────────────────────────────────
  String get preferences    => _t('Tercihler', 'Preferences', '환경설정');
  String get appearance     => _t('Görünüm', 'Appearance', '화면');
  String get darkMode       => _t('Karanlık mod', 'Dark mode', '다크 모드');
  String get appLanguage    => _t('Uygulama dili', 'App language', '앱 언어');
  String get accountLbl     => _t('Hesap', 'Account', '계정');
  String get subscriptionLbl => _t('Abonelik', 'Subscription', '구독');
  String get logoutLbl      => _t('Çıkış Yap', 'Log out', '로그아웃');
  String get deleteForever  => _t('Hesabı Kalıcı Sil', 'Delete account', '계정 영구 삭제');
  String get deleteForeverMsg => _t('Hesabın ve tüm verilerin kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      'Your account and all data will be permanently deleted. This cannot be undone.',
      '계정과 모든 데이터가 영구적으로 삭제됩니다. 되돌릴 수 없어요.');
  String get giveUp         => _t('Vazgeç', 'Cancel', '취소');
  String get deleteLbl      => _t('Sil', 'Delete', '삭제');
  String get privacySettings => _t('Gizlilik ayarları', 'Privacy settings', '개인정보 설정');
  String get choosePlan     => _t('Bir plan seç', 'Choose a plan', '플랜 선택');
  String get supportLbl     => _t('Destek', 'Support', '지원');
  String get helpCenter     => _t('Yardım Merkezi', 'Help Center', '고객센터');
  String get logoutCaps     => _t('OTURUMU KAPAT', 'LOG OUT', '로그아웃');

  // ── Profile view ────────────────────────────────────────────────────────────
  String get pleaseSignIn   => _t('Giriş yapın', 'Please sign in', '로그인해 주세요');
  String joinedOn(int m, int y) {
    const trM = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    if (_isTr) return '${trM[m]} $y tarihinde katıldı';
    if (_isKo) return '$y년 $m월에 가입';
    return 'Joined $m/$y';
  }
  String get statistics     => _t('İstatistikler', 'Statistics', '통계');
  String get dayStreakLbl   => _t('Günlük seri', 'Day streak', '연속 학습');
  String get totalXpLbl     => _t('Toplam Puan', 'Total XP', '총 점수');
  String get heartsLbl      => _t('Can', 'Hearts', '하트');
  String get answeredLbl    => _t('Cevaplanan', 'Answered', '푼 문제');
  String get passportTitle  => _t('Pasaport 🛂', 'Passport 🛂', '여권 🛂');
  String get passportEmpty  => _t('Pasaportun henüz boş — bir üniteyi tamamla, şehrin mührünü kazan!',
      'Your passport is empty — finish a unit to earn its city seal!',
      '아직 여권이 비어 있어요 — 유닛을 완료하고 도시 도장을 모아 보세요!');
  String get scoresRanking  => _t('Puan ve Sıralama', 'Scores & Ranking', '점수와 순위');
  String get globalRank     => _t('Genel Sıralama', 'Global Rank', '전체 순위');
  String get myListsTitle   => _t('Listelerim', 'My Lists', '내 재생목록');
  String get noListsProfile => _t('Henüz listen yok — Alıştırma sekmesinde "Listeye Ekle" ile oluşturabilirsin.',
      'No lists yet — create one with "Add to Playlist" in Practice.',
      '아직 재생목록이 없어요 — 연습 탭의 "재생목록에 추가"로 만들 수 있어요.');
  String get newListHint    => _t('Yeni liste adı…', 'New list name…', '새 재생목록 이름…');
  String get dailyStatsTitle => _t('Günlük İstatistikler', 'Daily Stats', '일일 통계');
  String get noStatsYet     => _t('Henüz istatistik yok — soru cevapladıkça burada birikecek.',
      'No stats yet — they build up as you answer questions.',
      '아직 통계가 없어요 — 문제를 풀면 여기에 쌓여요.');
  String get colDate        => _t('Tarih', 'Date', '날짜');
  String get colTotal       => _t('Toplam', 'Total', '전체');
  String get colSuccess     => _t('Doğru', 'Success', '정답');
  String get colFail        => _t('Yanlış', 'Fail', '오답');
  String get myFriendsTitle => _t('Arkadaşlarım', 'My Friends', '내 친구');
  String get noFriendsHint  => _t('Henüz arkadaşın yok — Puan Tabloları > Arkadaş Ara.',
      'No friends yet — Leaderboards > Find Friends.', '아직 친구가 없어요 — 랭킹 > 친구 찾기.');
  String get deleteListTip  => _t('Listeyi sil', 'Delete list', '재생목록 삭제');
  String get pointsLbl      => _t('puan', 'points', '점');
  String get studentFallback => _t('Öğrenci', 'Student', '학습자');
  String get editTip        => _t('Düzenle', 'Edit', '편집');
  String get startCaps      => _t('BAŞLA', 'START', '시작하기');
  String welcomeName(String? n) => n == null
      ? _t('Hoş geldin!', 'Welcome!', '환영해요!')
      : _t('Hoş geldin, $n!', 'Welcome, $n!', '$n님, 환영해요!');
  String get continueLearning => _t('Öğrenmeye kaldığın yerden devam et.',
      'Continue learning where you left off.', '마지막으로 학습한 곳부터 이어서 시작해요.');

  // ── Phase runner ────────────────────────────────────────────────────────────
  String get phasePassed    => _t('Tebrikler! Faz tamamlandı', 'Well done! Phase complete', '축하해요! 단계 완료');
  String get phaseFailed    => _t('Bu sefer olmadı', 'Not this time', '아쉽지만 다음 기회에!');
  String correctOf(int c, int t) => _t('$c / $t doğru', '$c / $t correct', '$t문제 중 $c개 정답');
  String passReq(int p)     => _t('Geçmek için en az %$p', 'Need at least $p%', '통과하려면 $p% 이상 필요해요');
  String get continueCaps   => _t('DEVAM ET', 'CONTINUE', '계속하기');
  String get goBackCaps     => _t('GERİ DÖN', 'GO BACK', '돌아가기');
  String get phaseLbl       => _t('Faz', 'Phase', '단계');
  String get noVideosInSet  => _t('Bu bölümde henüz video yok.', 'No videos in this set yet.', '이 단계에는 아직 영상이 없어요.');
  String outOfHearts(int? mins) => mins == null
      ? _t('Canın kalmadı. Yenilenmesini bekle.', 'Out of hearts. Wait to refill.', '하트가 다 떨어졌어요. 충전될 때까지 기다려 주세요.')
      : _t('Canın kalmadı. ~$mins dk sonra bir can dolacak.',
          'Out of hearts. A heart refills in ~$mins min.', '하트가 다 떨어졌어요. 약 $mins분 후에 하나 충전돼요.');
  String get wordsInSet     => _t('Bu bölümün kelimeleri', 'Words in this set', '이 단계의 단어');
  String get grammarLbl     => _t('Gramer', 'Grammar', '문법');
  String get noWordsLbl     => _t('Kelime yok', 'No words', '단어 없음');
  String get failedLbl      => _t('Yüklenemedi', 'Failed', '불러오지 못했어요');

  // ── Sign-in / onboarding ────────────────────────────────────────────────────
  String get signInTitle    => _t('Oturum Aç', 'Sign In', '로그인');
  String get createAccount  => _t('Hesap Oluştur', 'Create Account', '계정 만들기');
  String get kaydolCaps     => _t('KAYDOL', 'SIGN UP', '회원가입');
  String get oturumAcCaps   => _t('OTURUM AÇ', 'SIGN IN', '로그인');
  String get hesapOlusturCaps => _t('HESAP OLUŞTUR', 'CREATE ACCOUNT', '계정 만들기');
  String get emailHint      => _t('E-posta', 'Email', '이메일');
  String get passwordHint   => _t('Parola', 'Password', '비밀번호');
  String get passwordHintMin => _t('Parola (en az 6 karakter)', 'Password (min 6 characters)', '비밀번호 (6자 이상)');
  String get orDivider      => _t('VEYA', 'OR', '또는');
  String get continueAsGuest => _t('Misafir olarak devam et', 'Continue as guest', '게스트로 둘러보기');
  String get whatToCallYou  => _t('Sana nasıl\nhitap edelim?', 'What should we\ncall you?', '어떻게\n불러 드릴까요?');
  String get displayNameHint => _t('Görünen ad', 'Display name', '닉네임');
  String get verifyTitle    => _t('E-postanı Doğrula', 'Verify your email', '이메일 인증');
  String verifyBody(String email) => _t(
      '$email adresine bir doğrulama bağlantısı gönderdik.\nE-postanı doğruladıktan sonra aşağıdaki butona bas.',
      'We sent a verification link to $email.\nTap the button below once verified.',
      '$email 주소로 인증 링크를 보냈어요.\n인증을 마친 뒤 아래 버튼을 눌러 주세요.');
  String get verifiedContinue => _t('Doğruladım, Devam Et', 'Verified, Continue', '인증 완료, 계속하기');
  String get resendLbl      => _t('Tekrar gönder', 'Resend', '다시 보내기');
  String get byContinuing   => _t('Devam ederek ', 'By continuing you accept the ', '계속하면 ');
  String get termsWord      => _t('Şartlar', 'Terms', '이용약관');
  String get andThe         => _t("'ı ve ", ' and ', '과 ');
  String get privacyWord    => _t('Gizlilik', 'Privacy', '개인정보처리방침');
  String get policyAccept   => _t(' politikasını kabul edersin.', ' policy.', '에 동의하게 됩니다.');

  // ── HSK retest ──────────────────────────────────────────────────────────────
  String get hskTestTitle   => _t('HSK Testi', 'HSK Test', 'HSK 테스트');
  String get resultTitle    => _t('Sonuç', 'Result', '결과');
  String get saveAndReturn  => _t('Kaydet ve Geri Dön', 'Save & Return', '저장하고 돌아가기');
  String get whatMeans      => _t('Bu ne anlama geliyor?', 'What does this mean?', '무슨 뜻일까요?');
  String questionOf(int i, int t) => _t('Soru $i / $t', 'Question $i / $t', '문제 $i / $t');
  String yourLevelInfo(int l) => _t('Mevcut seviyen: HSK $l', 'Your level: HSK $l', '내 레벨: HSK $l');

  // ── Onboarding (welcome + placement result) ─────────────────────────────────
  String get onbTagline     => _t(
      'Gerçek video klipler, yapay zekâ açıklamaları ve\neğlenceli oyunlarla Mandarin öğren.',
      'Learn Mandarin through real video clips,\nAI explanations, and fun games.',
      '실제 영상 클립과 AI 설명, 재미있는 게임으로\n중국어를 배워 보세요.');
  String get getStarted     => _t('Başlayalım', 'Get Started', '시작하기');
  String get yourLevelLbl   => _t('Seviyen', 'Your Level', '내 레벨');
  String get startLearning  => _t('Öğrenmeye Başla', 'Start Learning', '학습 시작하기');
  String hskLevelDesc(int l) => switch (l) {
        1 => _t(
            'Daha yeni başlıyorsun. Temel kelime ve kalıplarla sağlam bir temel kuracağız.',
            'You\'re just starting out. We\'ll build your foundation with essential words and phrases.',
            '이제 막 시작하는 단계예요. 필수 단어와 표현으로 기초를 탄탄히 다져 드릴게요.'),
        2 => _t(
            'Temelleri biliyorsun. Şimdi kelime dağarcığını ve cümle kalıplarını genişletme zamanı.',
            'You know the basics. Time to expand your vocabulary and sentence patterns.',
            '기초는 알고 있어요. 이제 어휘와 문형을 넓혀 볼 차례예요.'),
        3 => _t(
            'Orta seviye — günlük konuşmaları rahatça yürütebiliyorsun. Biraz daha ileri gidelim.',
            'Intermediate level — you can handle everyday conversations. Let\'s push further.',
            '중급 수준 — 일상 대화는 무리 없이 할 수 있어요. 한 단계 더 나아가 봐요.'),
        4 => _t(
            'Orta-üstü — karmaşık konularda rahatsın. Akıcılığını inceltelim.',
            'Upper-intermediate — you\'re comfortable with complex topics. Let\'s refine your fluency.',
            '중상급 — 복잡한 주제도 편하게 다뤄요. 유창함을 더 다듬어 봐요.'),
        5 => _t(
            'İleri — soyut fikirleri tartışabiliyorsun. Nüans ve kesinliğini zorlayacağız.',
            'Advanced — you can discuss abstract ideas. We\'ll challenge your nuance and precision.',
            '고급 — 추상적인 주제도 토론할 수 있어요. 뉘앙스와 정확성을 갈고닦아 봐요.'),
        6 => _t(
            'Ustalık — ana dile yakın bir yeterliliktesin. Seni yalnızca en seçkin meydan okumalar bekliyor.',
            'Mastery level — you\'re at near-native proficiency. Only the finest challenges await.',
            '마스터 수준 — 원어민에 가까운 실력이에요. 이제 최고 난이도의 도전만 남았어요.'),
        _ => '',
      };

  // ── Misc / legacy keys (kept for existing call sites) ───────────────────────
  String get filterAll      => _t('Tümü', 'All', '전체');
  String get filterActive   => _t('Filtre aktif', 'Filter active', '필터 적용됨');
  String get filterLabel    => _t('Filtrele', 'Filter', '필터');
  String get lifeSection    => _t('Hayat', 'Life', '생활');
  String get dailyLife      => _t('Günlük Hayat', 'Daily Life', '일상생활');
  String get businessLife   => _t('İş', 'Business', '비즈니스');
  String get childrenLife   => _t('Çocuk', 'Children', '어린이');
  String get levelSection   => _t('Adım', 'Level', '단계');
  String get grammarSection => _t('Gramer Kuralları', 'Grammar Patterns', '문법 패턴');
  String get retryBtn       => _t('Tekrar Dene', 'Retry', '다시 시도');
  String get noVideosLevel  => _t('Seviyenizde video bulunamadı.', 'No videos at your level.', '내 레벨에 맞는 영상이 없어요.');
  String get noVideosFilter => _t('Seçili filtrelere uygun video yok.', 'No videos match filters.', '선택한 필터에 맞는 영상이 없어요.');
  String get statsWatched   => _t('izlendi', 'watched', '시청');
  String get statsPoints    => _t('puan', 'points', '점');
  String get statsDays      => _t('gün', 'days', '일');
  String get searchHint     => _t('Ara…', 'Search…', '검색…');
  String get gamesTitle     => _t('Oyunlar', 'Games', '게임');
  String get gamesSubtitle  => _t('Kendini sına ve arkadaşlarınla yarış',
      'Test yourself and compete with friends', '실력을 시험하고 친구와 겨뤄 보세요');
  String get duelSubtitle   => _t('Gerçek zamanlı 1v1 soru yarışması — 6 kategori',
      'Real-time 1v1 quiz — 6 categories', '실시간 1:1 퀴즈 대결 — 6개 카테고리');
  String get duelDetail     => _t('10 tur • 10s süre • 3 can', '10 rounds • 10s each • 3 lives', '10라운드 • 10초 제한 • 목숨 3개');
  String get hanziBuildSubtitle => _t('Kökenlerden karakter yeniden oluştur',
      'Reconstruct characters from radicals', '부수로 한자를 조립해 보세요');
  String get hanziBuildDetail => _t('10 kelime • 20s süre • ipuçları mevcut',
      '10 words • 20s each • hints available', '10단어 • 20초 제한 • 힌트 제공');
  String get userFallback   => _t('Kullanıcı', 'User', '사용자');
  String get scoreLabel     => _t('Skor', 'Score', '점수');
  String get hskLevelTest   => _t('HSK Seviye Testi', 'HSK Level Test', 'HSK 레벨 테스트');
  String get settingsLabel  => _t('Ayarlar', 'Settings', '설정');
  String get adminPanel     => _t('Admin Paneli', 'Admin Panel', '관리자 패널');
  String get darkTheme      => _t('Koyu Tema', 'Dark Theme', '다크 테마');
  String get signOut        => _t('Çıkış Yap', 'Sign Out', '로그아웃');
  String get loginBtn       => _t('Giriş Yap', 'Log In', '로그인');
  String get signUpBtn      => _t('Kayıt Ol', 'Sign Up', '회원가입');
  String get emailLabel     => _t('E-posta', 'Email', '이메일');
  String get passwordLabel  => _t('Şifre', 'Password', '비밀번호');
  String get googleSignIn   => _t('Google ile Giriş', 'Sign in with Google', 'Google로 로그인');
  String get authSubmitLogin => _t('Giriş Yap', 'Log In', '로그인');
  String get authSubmitRegister => _t('Hesap Oluştur', 'Create Account', '계정 만들기');
  String get verifyEmailTitle => _t('E-postanı doğrula', 'Verify your email', '이메일을 인증해 주세요');
  String get verifyEmailBody => _t('Doğrulama bağlantısı gönderildi. Gelen kutunuzu kontrol edin.',
      'A verification link has been sent. Check your inbox.', '인증 링크를 보냈어요. 받은편지함을 확인해 주세요.');
  String get profilePhoto   => _t('Profil Fotoğrafı', 'Profile Photo', '프로필 사진');
  String get changePhoto    => _t('Fotoğrafı Değiştir', 'Change Photo', '사진 변경');
  String get photoSelected  => _t('Fotoğraf seçildi ✓', 'Photo selected ✓', '사진 선택됨 ✓');
  String get profileSection => _t('Profil', 'Profile', '프로필');
  String get firstName      => _t('Ad', 'First Name', '이름');
  String get usernameLabel  => _t('Kullanıcı adı', 'Username', '사용자 이름');
  String get lastName       => _t('Soyad', 'Last Name', '성');
  String get selectHint     => _t('Seçiniz', 'Select', '선택');
  String get dateOfBirth    => _t('Doğum Tarihi', 'Date of Birth', '생년월일');
  String get genderLabel    => _t('Cinsiyet', 'Gender', '성별');
  String get male           => _t('Erkek', 'Male', '남성');
  String get female         => _t('Kadın', 'Female', '여성');
  String get otherGender    => _t('Diğer', 'Other', '기타');
  String get languageLabel  => _t('Dil', 'Language', '언어');
  String get saveChanges    => _t('Değişiklikleri Kaydet', 'Save Changes', '변경사항 저장');
  String get profileSaved   => _t('Profil kaydedildi.', 'Profile saved.', '프로필이 저장되었어요.');
  String get saveError      => _t('Kayıt hatası: ', 'Save error: ', '저장 오류: ');
  String get accountSection => _t('Hesap', 'Account', '계정');
  String get darkThemeToggle => _t('Karanlık Tema', 'Dark Theme', '다크 테마');
  String get lightThemeToggle => _t('Açık Tema', 'Light Theme', '라이트 테마');
  String get deleteAccount  => _t('Hesabı Sil', 'Delete Account', '계정 삭제');
  String get passwordSection => _t('Şifre', 'Password', '비밀번호');
  String get currentPassword => _t('Mevcut Şifre', 'Current Password', '현재 비밀번호');
  String get newPassword    => _t('Yeni Şifre', 'New Password', '새 비밀번호');
  String get confirmPassword => _t('Yeni Şifre Tekrar', 'Confirm Password', '새 비밀번호 확인');
  String get updatePassword => _t('Şifreyi Güncelle', 'Update Password', '비밀번호 변경');
  String get passwordUpdated => _t('Şifre güncellendi.', 'Password updated.', '비밀번호가 변경되었어요.');
  String get fillAllPassFields => _t('Tüm şifre alanlarını doldurun.', 'Fill in all password fields.', '모든 비밀번호 항목을 입력해 주세요.');
  String get passwordMismatch => _t('Yeni şifreler eşleşmiyor.', "New passwords don't match.", '새 비밀번호가 일치하지 않아요.');
  String get passwordTooShort => _t('Şifre en az 6 karakter olmalıdır.',
      'Password must be at least 6 characters.', '비밀번호는 6자 이상이어야 해요.');
  String get guestCannotEdit => _t('Misafir kullanıcılar profil düzenleyemez.',
      'Guest users cannot edit their profile.', '게스트는 프로필을 수정할 수 없어요.');
  String get signUpOrIn     => _t('Hesap Oluştur / Giriş Yap', 'Sign Up / Sign In', '회원가입 / 로그인');
  String get cancel         => _t('İptal', 'Cancel', '취소');
  String get signOutConfirmMsg => _t('Hesabınızdan çıkmak istediğinizden emin misiniz?',
      'Are you sure you want to sign out?', '정말 로그아웃하시겠어요?');
  String get deleteAccountMsg => _t('Hesabınız ve tüm verileriniz kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      'Your account and all your data will be permanently deleted. This action cannot be undone.',
      '계정과 모든 데이터가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없어요.');
}
