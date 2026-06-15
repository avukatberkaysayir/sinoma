import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/analytics_service.dart';
import 'ai_provider.dart';
import 'locale_provider.dart';
import 'user_provider.dart';

// ---------------------------------------------------------------------------
// Placement test data
// ---------------------------------------------------------------------------

class PlacementQuestion {
  final String text;
  final List<String> choices; // English (also the fallback)
  final List<String> choicesTr;
  final List<String> choicesKo;
  final List<String> choicesJa;
  final List<String> choicesId;
  final List<String> choicesVi;
  final List<String> choicesTh;
  final int correctIndex;
  final int hskLevel;

  const PlacementQuestion({
    required this.text,
    required this.choices,
    this.choicesTr = const [],
    this.choicesKo = const [],
    this.choicesJa = const [],
    this.choicesId = const [],
    this.choicesVi = const [],
    this.choicesTh = const [],
    required this.correctIndex,
    required this.hskLevel,
  });

  // Same order in every language, so correctIndex stays valid.
  List<String> choicesFor(String lang) => switch (lang) {
        'tr' when choicesTr.length == choices.length => choicesTr,
        'ko' when choicesKo.length == choices.length => choicesKo,
        'ja' when choicesJa.length == choices.length => choicesJa,
        'id' when choicesId.length == choices.length => choicesId,
        'vi' when choicesVi.length == choices.length => choicesVi,
        'th' when choicesTh.length == choices.length => choicesTh,
        _ => choices,
      };
}

const kPlacementQuestions = <PlacementQuestion>[
  // HSK 1
  PlacementQuestion(text: '你好',
      choices: ['Hello', 'Goodbye', 'Thank you', 'Sorry'],
      choicesTr: ['Merhaba', 'Hoşça kal', 'Teşekkürler', 'Özür dilerim'],
      choicesKo: ['안녕하세요', '안녕히 가세요', '감사합니다', '죄송합니다'],
      choicesJa: ['こんにちは', 'さようなら', 'ありがとう', 'ごめんなさい'],
      choicesId: ['Halo', 'Selamat tinggal', 'Terima kasih', 'Maaf'],
      choicesVi: ['Xin chào', 'Tạm biệt', 'Cảm ơn', 'Xin lỗi'],
      choicesTh: ['สวัสดี', 'ลาก่อน', 'ขอบคุณ', 'ขอโทษ'],
      correctIndex: 0, hskLevel: 1),
  PlacementQuestion(text: '水',
      choices: ['Fire', 'Earth', 'Water', 'Wind'],
      choicesTr: ['Ateş', 'Toprak', 'Su', 'Rüzgâr'],
      choicesKo: ['불', '흙', '물', '바람'],
      choicesJa: ['火', '土', '水', '風'],
      choicesId: ['Api', 'Tanah', 'Air', 'Angin'],
      choicesVi: ['Lửa', 'Đất', 'Nước', 'Gió'],
      choicesTh: ['ไฟ', 'ดิน', 'น้ำ', 'ลม'],
      correctIndex: 2, hskLevel: 1),
  PlacementQuestion(text: '今天',
      choices: ['Yesterday', 'Tomorrow', 'Now', 'Today'],
      choicesTr: ['Dün', 'Yarın', 'Şimdi', 'Bugün'],
      choicesKo: ['어제', '내일', '지금', '오늘'],
      choicesJa: ['昨日', '明日', '今', '今日'],
      choicesId: ['Kemarin', 'Besok', 'Sekarang', 'Hari ini'],
      choicesVi: ['Hôm qua', 'Ngày mai', 'Bây giờ', 'Hôm nay'],
      choicesTh: ['เมื่อวาน', 'พรุ่งนี้', 'ตอนนี้', 'วันนี้'],
      correctIndex: 3, hskLevel: 1),
  PlacementQuestion(text: '我',
      choices: ['He', 'She', 'They', 'I / Me'],
      choicesTr: ['O (erkek)', 'O (kadın)', 'Onlar', 'Ben'],
      choicesKo: ['그', '그녀', '그들', '나 / 저'],
      choicesJa: ['彼', '彼女', '彼ら', '私'],
      choicesId: ['Dia (lk)', 'Dia (pr)', 'Mereka', 'Saya'],
      choicesVi: ['Anh ấy', 'Cô ấy', 'Họ', 'Tôi'],
      choicesTh: ['เขา (ชาย)', 'เธอ (หญิง)', 'พวกเขา', 'ฉัน'],
      correctIndex: 3, hskLevel: 1),
  // HSK 2
  PlacementQuestion(text: '高兴',
      choices: ['Sad', 'Happy', 'Tired', 'Angry'],
      choicesTr: ['Üzgün', 'Mutlu', 'Yorgun', 'Kızgın'],
      choicesKo: ['슬프다', '기쁘다', '피곤하다', '화나다'],
      choicesJa: ['悲しい', 'うれしい', '疲れている', '怒っている'],
      choicesId: ['Sedih', 'Senang', 'Lelah', 'Marah'],
      choicesVi: ['Buồn', 'Vui', 'Mệt', 'Giận'],
      choicesTh: ['เศร้า', 'มีความสุข', 'เหนื่อย', 'โกรธ'],
      correctIndex: 1, hskLevel: 2),
  PlacementQuestion(text: '明白',
      choices: ['Forget', 'Explain', 'Understand', 'Remember'],
      choicesTr: ['Unutmak', 'Açıklamak', 'Anlamak', 'Hatırlamak'],
      choicesKo: ['잊다', '설명하다', '이해하다', '기억하다'],
      choicesJa: ['忘れる', '説明する', '理解する', '覚える'],
      choicesId: ['Lupa', 'Menjelaskan', 'Mengerti', 'Mengingat'],
      choicesVi: ['Quên', 'Giải thích', 'Hiểu', 'Nhớ'],
      choicesTh: ['ลืม', 'อธิบาย', 'เข้าใจ', 'จำ'],
      correctIndex: 2, hskLevel: 2),
  PlacementQuestion(text: '已经',
      choices: ['Still', 'Never', 'Often', 'Already'],
      choicesTr: ['Hâlâ', 'Asla', 'Sık sık', 'Çoktan'],
      choicesKo: ['아직', '결코', '자주', '이미'],
      choicesJa: ['まだ', '決して', 'よく', 'すでに'],
      choicesId: ['Masih', 'Tidak pernah', 'Sering', 'Sudah'],
      choicesVi: ['Vẫn còn', 'Không bao giờ', 'Thường xuyên', 'Đã rồi'],
      choicesTh: ['ยัง', 'ไม่เคย', 'บ่อย ๆ', 'แล้ว'],
      correctIndex: 3, hskLevel: 2),
  // HSK 3
  PlacementQuestion(text: '环境',
      choices: ['Weather', 'Environment', 'Society', 'Space'],
      choicesTr: ['Hava durumu', 'Çevre', 'Toplum', 'Uzay'],
      choicesKo: ['날씨', '환경', '사회', '우주'],
      choicesJa: ['天気', '環境', '社会', '宇宙'],
      choicesId: ['Cuaca', 'Lingkungan', 'Masyarakat', 'Antariksa'],
      choicesVi: ['Thời tiết', 'Môi trường', 'Xã hội', 'Vũ trụ'],
      choicesTh: ['อากาศ', 'สิ่งแวดล้อม', 'สังคม', 'อวกาศ'],
      correctIndex: 1, hskLevel: 3),
  PlacementQuestion(text: '参加',
      choices: ['Leave', 'Refuse', 'Arrive', 'Participate'],
      choicesTr: ['Ayrılmak', 'Reddetmek', 'Varmak', 'Katılmak'],
      choicesKo: ['떠나다', '거절하다', '도착하다', '참가하다'],
      choicesJa: ['去る', '断る', '到着する', '参加する'],
      choicesId: ['Pergi', 'Menolak', 'Tiba', 'Ikut serta'],
      choicesVi: ['Rời đi', 'Từ chối', 'Đến nơi', 'Tham gia'],
      choicesTh: ['จากไป', 'ปฏิเสธ', 'มาถึง', 'เข้าร่วม'],
      correctIndex: 3, hskLevel: 3),
  PlacementQuestion(text: '变化',
      choices: ['Repeat', 'Progress', 'Change', 'Difference'],
      choicesTr: ['Tekrar', 'İlerleme', 'Değişim', 'Fark'],
      choicesKo: ['반복', '발전', '변화', '차이'],
      choicesJa: ['繰り返し', '発展', '変化', '違い'],
      choicesId: ['Pengulangan', 'Kemajuan', 'Perubahan', 'Perbedaan'],
      choicesVi: ['Lặp lại', 'Tiến bộ', 'Thay đổi', 'Khác biệt'],
      choicesTh: ['การทำซ้ำ', 'ความก้าวหน้า', 'การเปลี่ยนแปลง', 'ความแตกต่าง'],
      correctIndex: 2, hskLevel: 3),
  // HSK 4
  PlacementQuestion(text: '批评',
      choices: ['Praise', 'Criticize', 'Study', 'Accept'],
      choicesTr: ['Övmek', 'Eleştirmek', 'Çalışmak', 'Kabul etmek'],
      choicesKo: ['칭찬하다', '비판하다', '공부하다', '받아들이다'],
      choicesJa: ['ほめる', '批判する', '勉強する', '受け入れる'],
      choicesId: ['Memuji', 'Mengkritik', 'Belajar', 'Menerima'],
      choicesVi: ['Khen ngợi', 'Phê bình', 'Học tập', 'Chấp nhận'],
      choicesTh: ['ชมเชย', 'วิจารณ์', 'เรียน', 'ยอมรับ'],
      correctIndex: 1, hskLevel: 4),
  PlacementQuestion(text: '不得不',
      choices: ['Want to', 'Prefer to', 'Have no choice but to', 'Refuse to'],
      choicesTr: ['İstemek', 'Tercih etmek', 'Mecbur kalmak', 'Reddetmek'],
      choicesKo: ['~하고 싶다', '~을 선호하다', '어쩔 수 없이 ~하다', '~을 거부하다'],
      choicesJa: ['~したい', '~を好む', 'やむを得ず~する', '~を拒む'],
      choicesId: ['Ingin', 'Lebih suka', 'Terpaksa', 'Menolak'],
      choicesVi: ['Muốn', 'Thích hơn', 'Buộc phải', 'Từ chối'],
      choicesTh: ['อยาก', 'ชอบมากกว่า', 'จำใจต้อง', 'ปฏิเสธ'],
      correctIndex: 2, hskLevel: 4),
  PlacementQuestion(text: '尽管',
      choices: ['Because', 'Unless', 'Despite', 'Without'],
      choicesTr: ['Çünkü', 'Olmadıkça', 'Rağmen', 'Olmadan'],
      choicesKo: ['~때문에', '~하지 않는 한', '~에도 불구하고', '~없이'],
      choicesJa: ['~なので', '~しない限り', '~にもかかわらず', '~なしで'],
      choicesId: ['Karena', 'Kecuali', 'Meskipun', 'Tanpa'],
      choicesVi: ['Bởi vì', 'Trừ khi', 'Mặc dù', 'Không có'],
      choicesTh: ['เพราะว่า', 'เว้นแต่', 'ถึงแม้ว่า', 'โดยไม่มี'],
      correctIndex: 2, hskLevel: 4),
  // HSK 5
  PlacementQuestion(text: '辩论',
      choices: ['Agree', 'Confirm', 'Lecture', 'Debate'],
      choicesTr: ['Katılmak', 'Doğrulamak', 'Ders vermek', 'Tartışmak'],
      choicesKo: ['동의하다', '확인하다', '강의하다', '토론하다'],
      choicesJa: ['同意する', '確認する', '講義する', '討論する'],
      choicesId: ['Setuju', 'Memastikan', 'Memberi kuliah', 'Berdebat'],
      choicesVi: ['Đồng ý', 'Xác nhận', 'Giảng bài', 'Tranh luận'],
      choicesTh: ['เห็นด้วย', 'ยืนยัน', 'บรรยาย', 'โต้วาที'],
      correctIndex: 3, hskLevel: 5),
  PlacementQuestion(text: '顽固',
      choices: ['Gentle', 'Cautious', 'Brave', 'Stubborn'],
      choicesTr: ['Nazik', 'Tedbirli', 'Cesur', 'İnatçı'],
      choicesKo: ['온화하다', '신중하다', '용감하다', '완고하다'],
      choicesJa: ['温和だ', '慎重だ', '勇敢だ', '頑固だ'],
      choicesId: ['Lembut', 'Hati-hati', 'Berani', 'Keras kepala'],
      choicesVi: ['Hiền hòa', 'Thận trọng', 'Dũng cảm', 'Bướng bỉnh'],
      choicesTh: ['อ่อนโยน', 'ระมัดระวัง', 'กล้าหาญ', 'ดื้อรั้น'],
      correctIndex: 3, hskLevel: 5),
  PlacementQuestion(text: '迫不及待',
      choices: ['Reluctant', 'Eager / Can\'t wait', 'Hesitant', 'Indifferent'],
      choicesTr: ['İsteksiz', 'Sabırsız / Can atan', 'Kararsız', 'Kayıtsız'],
      choicesKo: ['내키지 않다', '몹시 기대되다', '망설이다', '무관심하다'],
      choicesJa: ['気が進まない', '待ちきれない', 'ためらう', '無関心だ'],
      choicesId: ['Enggan', 'Tak sabar', 'Ragu-ragu', 'Acuh tak acuh'],
      choicesVi: ['Miễn cưỡng', 'Nóng lòng', 'Do dự', 'Thờ ơ'],
      choicesTh: ['ไม่เต็มใจ', 'รอแทบไม่ไหว', 'ลังเล', 'เฉยเมย'],
      correctIndex: 1, hskLevel: 5),
  PlacementQuestion(text: '模糊',
      choices: ['Clear', 'Accurate', 'Vague', 'Specific'],
      choicesTr: ['Net', 'Doğru', 'Belirsiz', 'Belirli'],
      choicesKo: ['뚜렷하다', '정확하다', '모호하다', '구체적이다'],
      choicesJa: ['鮮明だ', '正確だ', '曖昧だ', '具体的だ'],
      choicesId: ['Jelas', 'Akurat', 'Samar', 'Spesifik'],
      choicesVi: ['Rõ ràng', 'Chính xác', 'Mơ hồ', 'Cụ thể'],
      choicesTh: ['ชัดเจน', 'แม่นยำ', 'คลุมเครือ', 'เฉพาะเจาะจง'],
      correctIndex: 2, hskLevel: 5),
  // HSK 6
  PlacementQuestion(text: '冠冕堂皇',
      choices: ['Humble', 'Sincere', 'Pompous / High-sounding', 'Eloquent'],
      choicesTr: ['Alçakgönüllü', 'Samimi', 'Gösterişli / Tumturaklı', 'Belagatli'],
      choicesKo: ['겸손하다', '진실하다', '겉만 번지르르하다', '언변이 좋다'],
      choicesJa: ['謙虚だ', '誠実だ', 'うわべだけ立派だ', '弁が立つ'],
      choicesId: ['Rendah hati', 'Tulus', 'Megah di luarnya saja', 'Pandai bicara'],
      choicesVi: ['Khiêm tốn', 'Chân thành', 'Hào nhoáng bề ngoài', 'Khéo ăn nói'],
      choicesTh: ['ถ่อมตัว', 'จริงใจ', 'ดีแต่เปลือกนอก', 'พูดเก่ง'],
      correctIndex: 2, hskLevel: 6),
  PlacementQuestion(text: '出乎意料',
      choices: ['As planned', 'Disappointing', 'Intentional', 'Unexpected'],
      choicesTr: ['Planlandığı gibi', 'Hayal kırıklığı', 'Kasıtlı', 'Beklenmedik'],
      choicesKo: ['계획대로', '실망스럽다', '의도적이다', '뜻밖이다'],
      choicesJa: ['計画通り', 'がっかりだ', '意図的だ', '予想外だ'],
      choicesId: ['Sesuai rencana', 'Mengecewakan', 'Disengaja', 'Tak terduga'],
      choicesVi: ['Đúng kế hoạch', 'Đáng thất vọng', 'Cố ý', 'Bất ngờ'],
      choicesTh: ['ตามแผน', 'น่าผิดหวัง', 'ตั้งใจ', 'ไม่คาดคิด'],
      correctIndex: 3, hskLevel: 6),
  PlacementQuestion(text: '望而生畏',
      choices: ['Feel inspired', 'Feel attracted', 'Feel bored', 'Feel intimidated'],
      choicesTr: ['İlham almak', 'Cezbedilmek', 'Sıkılmak', 'Gözü korkmak'],
      choicesKo: ['영감을 받다', '마음이 끌리다', '지루함을 느끼다', '보기만 해도 겁나다'],
      choicesJa: ['感銘を受ける', '心が引かれる', '退屈を感じる', '見ただけで怖くなる'],
      choicesId: ['Terinspirasi', 'Tertarik', 'Merasa bosan', 'Merasa gentar saat melihatnya'],
      choicesVi: ['Được truyền cảm hứng', 'Bị thu hút', 'Thấy chán', 'Thấy e sợ khi nhìn'],
      choicesTh: ['ได้รับแรงบันดาลใจ', 'รู้สึกถูกดึงดูด', 'รู้สึกเบื่อ', 'รู้สึกหวั่นเกรง'],
      correctIndex: 3, hskLevel: 6),
];

int computeHskLevel(List<int?> answers) {
  var correct = 0;
  for (var i = 0; i < kPlacementQuestions.length; i++) {
    if (i < answers.length &&
        answers[i] == kPlacementQuestions[i].correctIndex) {
      correct++;
    }
  }
  if (correct <= 3) return 1;
  if (correct <= 6) return 2;
  if (correct <= 9) return 3;
  if (correct <= 13) return 4;
  if (correct <= 17) return 5;
  return 6;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum OnboardingStep { welcome, signIn, emailVerification, profile, test, results }

class OnboardingState {
  final OnboardingStep step;
  final int questionIndex;
  final List<int?> answers;
  final int? hskLevel;
  final bool isLoading;
  final String? error;
  final String displayName;
  final bool isComplete;
  final String? pendingVerificationEmail;

  static const totalQuestions = 20;

  const OnboardingState({
    this.step = OnboardingStep.welcome,
    this.questionIndex = 0,
    this.answers = const [],
    this.hskLevel,
    this.isLoading = false,
    this.error,
    this.displayName = '',
    this.isComplete = false,
    this.pendingVerificationEmail,
  });

  double get testProgress =>
      totalQuestions == 0 ? 0 : questionIndex / totalQuestions;

  List<PlacementQuestion> get questions => kPlacementQuestions;

  PlacementQuestion? get currentQuestion =>
      questionIndex < totalQuestions ? kPlacementQuestions[questionIndex] : null;

  OnboardingState copyWith({
    OnboardingStep? step,
    int? questionIndex,
    List<int?>? answers,
    int? hskLevel,
    bool? isLoading,
    String? error,
    String? displayName,
    bool? isComplete,
    String? pendingVerificationEmail,
  }) =>
      OnboardingState(
        step: step ?? this.step,
        questionIndex: questionIndex ?? this.questionIndex,
        answers: answers ?? this.answers,
        hskLevel: hskLevel ?? this.hskLevel,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        displayName: displayName ?? this.displayName,
        isComplete: isComplete ?? this.isComplete,
        pendingVerificationEmail:
            pendingVerificationEmail ?? this.pendingVerificationEmail,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._userRepository, this._analytics, this._ref)
      : super(const OnboardingState(step: OnboardingStep.signIn)) {
    _checkExistingSession();
  }

  final UserRepository _userRepository;
  final AnalyticsService _analytics;
  final Ref _ref;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  AppL10n get _l10n =>
      AppL10n.fromCode(_ref.read(localeProvider).languageCode);

  // If the user is already signed in (e.g. after OAuth redirect), skip directly
  // to profile setup or mark complete if they already have a DB record.
  Future<void> _checkExistingSession() async {
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      state = state.copyWith(isLoading: true);
      await _handlePostSignIn(user, '');
    }
  }

  void advanceToSignIn() {
    state = state.copyWith(step: OnboardingStep.signIn);
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: '${Uri.base.origin}/splash',
        queryParams: {'prompt': 'select_account'},
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithDevAccount() async {
    if (!kDebugMode) return;
    state = state.copyWith(isLoading: true, error: null);
    const email = 'dev@sinoma.local';
    const password = 'dev-local-123';
    try {
      AuthResponse result;
      try {
        result = await _auth.signInWithPassword(
            email: email, password: password);
      } on AuthException catch (e) {
        if (e.message.toLowerCase().contains('invalid') ||
            e.statusCode == '400') {
          result = await _auth.signUp(email: email, password: password);
        } else {
          rethrow;
        }
      }
      if (result.user != null) {
        await _analytics.logSignIn('dev');
        await _handlePostSignIn(result.user!, 'Dev User');
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> registerWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _auth.signUp(email: email.trim(), password: password);
      await _analytics.logSignIn('email_register');
      state = state.copyWith(
        isLoading: false,
        step: OnboardingStep.emailVerification,
        pendingVerificationEmail: email.trim(),
      );
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _emailAuthError(e));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _auth.signInWithPassword(
          email: email.trim(), password: password);
      await _analytics.logSignIn('email');
      final name = result.user?.userMetadata?['display_name'] as String? ??
          email.trim().split('@').first;
      await _handlePostSignIn(result.user!, name);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _emailAuthError(e));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> checkEmailVerified() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _auth.refreshSession();
      final user = _auth.currentUser;
      if (user?.emailConfirmedAt != null) {
        final name = user?.userMetadata?['display_name'] as String? ??
            (state.pendingVerificationEmail?.split('@').first ?? '');
        await _handlePostSignIn(user!, name);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: _l10n.errVerifyPending,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      if (state.pendingVerificationEmail != null) {
        await _auth.resend(
          type: OtpType.signup,
          email: state.pendingVerificationEmail!,
        );
      }
    } catch (_) {}
  }

  String _emailAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return _l10n.errEmailTaken;
    }
    if (msg.contains('invalid email')) return _l10n.errInvalidEmail;
    if (msg.contains('password') && msg.contains('short')) {
      return _l10n.errPasswordShort;
    }
    if (msg.contains('invalid login') || msg.contains('wrong')) {
      return _l10n.errBadCredentials;
    }
    if (msg.contains('too many')) {
      return _l10n.errTooMany;
    }
    return e.message;
  }

  Future<void> signInAnonymously() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _auth.signInAnonymously();
      await _analytics.logSignIn('anonymous');
      await _handlePostSignIn(result.user!, '');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _handlePostSignIn(User user, String suggestedName) async {
    final existing = await _userRepository.loadUser(user.id);
    if (existing != null) {
      state = state.copyWith(isLoading: false, isComplete: true);
    } else {
      final name = user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['display_name'] as String? ??
          suggestedName;
      state = state.copyWith(
        isLoading: false,
        step: OnboardingStep.profile,
        displayName: name,
      );
    }
  }

  void updateDisplayName(String name) {
    state = state.copyWith(displayName: name);
  }

  // The placement test no longer runs at signup — the account starts at HSK 1
  // and the user takes the test later via "HSK Testine Başla" on the practice
  // page (/hsk-test), which saves the level the same way.
  void confirmDisplayName() {
    if (state.displayName.trim().isEmpty) return;
    completeOnboarding();
  }

  void selectAnswer(int answerIndex) {
    final updated = List<int?>.from(state.answers);
    updated[state.questionIndex] = answerIndex;
    final nextIndex = state.questionIndex + 1;

    if (nextIndex >= OnboardingState.totalQuestions) {
      state = state.copyWith(
        answers: updated,
        questionIndex: nextIndex,
        step: OnboardingStep.results,
        hskLevel: _computeLevel(updated),
      );
    } else {
      state = state.copyWith(answers: updated, questionIndex: nextIndex);
    }
  }

  Future<void> completeOnboarding() async {
    final user = _auth.currentUser;
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final userDoc = UserModel(
        uid: user.id,
        displayName: state.displayName.trim(),
        email: user.email ?? '',
        photoUrl: user.userMetadata?['avatar_url'] as String? ?? '',
        hskLevel: state.hskLevel ?? 1,
        isPremium: false,
        aiCredits: 5,
        followers: const [],
        following: const [],
        learnedWords: const [],
        stats: const UserStats(),
        createdAt: DateTime.now(),
      );
      await _userRepository.createUser(userDoc);
      await _recordGdprConsent(user.id);
      await _analytics.logOnboardingCompleted(state.hskLevel ?? 1);
      state = state.copyWith(isLoading: false, isComplete: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _recordGdprConsent(String uid) async {
    await Supabase.instance.client.from('gdpr_consent').upsert({
      'uid': uid,
      'consent_given': true,
      'consent_timestamp': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'consent_version': '2026-05',
    });
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  int _computeLevel(List<int?> answers) => computeHskLevel(answers);
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final onboardingProvider =
    StateNotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(
    ref.read(userRepositoryProvider),
    ref.read(analyticsServiceProvider),
    ref,
  ),
);
