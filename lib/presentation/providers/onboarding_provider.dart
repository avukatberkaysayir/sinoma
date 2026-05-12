import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/analytics_service.dart';
import 'ai_provider.dart';
import 'user_provider.dart';

// ---------------------------------------------------------------------------
// Placement test data
// ---------------------------------------------------------------------------

class PlacementQuestion {
  final String text;
  final List<String> choices;
  final int correctIndex;
  final int hskLevel;

  const PlacementQuestion({
    required this.text,
    required this.choices,
    required this.correctIndex,
    required this.hskLevel,
  });
}

const kPlacementQuestions = <PlacementQuestion>[
  // HSK 1
  PlacementQuestion(text: '你好', choices: ['Hello', 'Goodbye', 'Thank you', 'Sorry'], correctIndex: 0, hskLevel: 1),
  PlacementQuestion(text: '水', choices: ['Fire', 'Earth', 'Water', 'Wind'], correctIndex: 2, hskLevel: 1),
  PlacementQuestion(text: '今天', choices: ['Yesterday', 'Tomorrow', 'Now', 'Today'], correctIndex: 3, hskLevel: 1),
  PlacementQuestion(text: '我', choices: ['He', 'She', 'They', 'I / Me'], correctIndex: 3, hskLevel: 1),
  // HSK 2
  PlacementQuestion(text: '高兴', choices: ['Sad', 'Happy', 'Tired', 'Angry'], correctIndex: 1, hskLevel: 2),
  PlacementQuestion(text: '明白', choices: ['Forget', 'Explain', 'Understand', 'Remember'], correctIndex: 2, hskLevel: 2),
  PlacementQuestion(text: '已经', choices: ['Still', 'Never', 'Often', 'Already'], correctIndex: 3, hskLevel: 2),
  // HSK 3
  PlacementQuestion(text: '环境', choices: ['Weather', 'Environment', 'Society', 'Space'], correctIndex: 1, hskLevel: 3),
  PlacementQuestion(text: '参加', choices: ['Leave', 'Refuse', 'Arrive', 'Participate'], correctIndex: 3, hskLevel: 3),
  PlacementQuestion(text: '变化', choices: ['Repeat', 'Progress', 'Change', 'Difference'], correctIndex: 2, hskLevel: 3),
  // HSK 4
  PlacementQuestion(text: '批评', choices: ['Praise', 'Criticize', 'Study', 'Accept'], correctIndex: 1, hskLevel: 4),
  PlacementQuestion(text: '不得不', choices: ['Want to', 'Prefer to', 'Have no choice but to', 'Refuse to'], correctIndex: 2, hskLevel: 4),
  PlacementQuestion(text: '尽管', choices: ['Because', 'Unless', 'Despite', 'Without'], correctIndex: 2, hskLevel: 4),
  // HSK 5
  PlacementQuestion(text: '辩论', choices: ['Agree', 'Confirm', 'Lecture', 'Debate'], correctIndex: 3, hskLevel: 5),
  PlacementQuestion(text: '顽固', choices: ['Gentle', 'Cautious', 'Brave', 'Stubborn'], correctIndex: 3, hskLevel: 5),
  PlacementQuestion(text: '迫不及待', choices: ['Reluctant', 'Eager / Can\'t wait', 'Hesitant', 'Indifferent'], correctIndex: 1, hskLevel: 5),
  PlacementQuestion(text: '模糊', choices: ['Clear', 'Accurate', 'Vague', 'Specific'], correctIndex: 2, hskLevel: 5),
  // HSK 6
  PlacementQuestion(text: '冠冕堂皇', choices: ['Humble', 'Sincere', 'Pompous / High-sounding', 'Eloquent'], correctIndex: 2, hskLevel: 6),
  PlacementQuestion(text: '出乎意料', choices: ['As planned', 'Disappointing', 'Intentional', 'Unexpected'], correctIndex: 3, hskLevel: 6),
  PlacementQuestion(text: '望而生畏', choices: ['Feel inspired', 'Feel attracted', 'Feel bored', 'Feel intimidated'], correctIndex: 3, hskLevel: 6),
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
  OnboardingNotifier(this._userRepository, this._analytics)
      : super(const OnboardingState(step: OnboardingStep.signIn)) {
    _checkExistingSession();
  }

  final UserRepository _userRepository;
  final AnalyticsService _analytics;

  GoTrueClient get _auth => Supabase.instance.client.auth;

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
          error: 'E-posta henüz doğrulanmadı. Gelen kutunuzu kontrol edin.',
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
      return 'Bu e-posta zaten kayıtlı. Giriş yapmayı deneyin.';
    }
    if (msg.contains('invalid email')) return 'Geçersiz e-posta adresi.';
    if (msg.contains('password') && msg.contains('short')) {
      return 'Şifre en az 6 karakter olmalıdır.';
    }
    if (msg.contains('invalid login') || msg.contains('wrong')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (msg.contains('too many')) {
      return 'Çok fazla deneme. Lütfen bir süre bekleyin.';
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

  void confirmDisplayName() {
    if (state.displayName.trim().isEmpty) return;
    state = state.copyWith(
      step: OnboardingStep.test,
      answers: List.filled(OnboardingState.totalQuestions, null),
    );
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
  ),
);
