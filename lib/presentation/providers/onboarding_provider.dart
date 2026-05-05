import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

const _questions = <PlacementQuestion>[
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

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum OnboardingStep { welcome, signIn, profile, test, results }

class OnboardingState {
  final OnboardingStep step;
  final int questionIndex;
  final List<int?> answers;
  final int? hskLevel;
  final bool isLoading;
  final String? error;
  final String displayName;
  final bool isComplete;

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
  });

  double get testProgress =>
      totalQuestions == 0 ? 0 : questionIndex / totalQuestions;

  List<PlacementQuestion> get questions => _questions;

  PlacementQuestion? get currentQuestion =>
      questionIndex < totalQuestions ? _questions[questionIndex] : null;

  OnboardingState copyWith({
    OnboardingStep? step,
    int? questionIndex,
    List<int?>? answers,
    int? hskLevel,
    bool? isLoading,
    String? error,
    String? displayName,
    bool? isComplete,
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
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier(this._userRepository, this._analytics)
      : super(const OnboardingState());

  final UserRepository _userRepository;
  final AnalyticsService _analytics;
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  void advanceToSignIn() {
    state = state.copyWith(step: OnboardingStep.signIn);
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      UserCredential result;
      if (kIsWeb) {
        // On web, use Firebase's built-in popup flow (emulator-compatible).
        result = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          state = state.copyWith(isLoading: false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        result = await _auth.signInWithCredential(credential);
      }
      await _analytics.logSignIn('google');
      final name = result.user?.displayName ?? '';
      await _handlePostSignIn(result.user!, name);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
    final existing = await _userRepository.loadUser(user.uid);
    if (existing != null) {
      state = state.copyWith(isLoading: false, isComplete: true);
    } else {
      state = state.copyWith(
        isLoading: false,
        step: OnboardingStep.profile,
        displayName: user.displayName ?? suggestedName,
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
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final userDoc = UserModel(
        uid: uid,
        displayName: state.displayName.trim(),
        email: _auth.currentUser?.email ?? '',
        photoUrl: _auth.currentUser?.photoURL ?? '',
        hskLevel: state.hskLevel ?? 1,
        isPremium: false,
        aiCredits: 5,
        followers: const [],
        following: const [],
        learnedWords: const [],
        stats: const UserStats(),
        createdAt: now,
      );
      await _userRepository.createUser(userDoc);
      await _recordGdprConsent(uid);
      await _analytics.logOnboardingCompleted(state.hskLevel ?? 1);
      state = state.copyWith(isLoading: false, isComplete: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _recordGdprConsent(String uid) async {
    // Record that the user accepted the Terms of Service / Privacy Policy
    // during onboarding. Required for GDPR Art. 7 (demonstrable consent).
    await FirebaseFirestore.instance.collection('gdprConsent').doc(uid).set({
      'uid': uid,
      'consentGiven': true,
      'consentTimestamp': Timestamp.now(),
      'appVersion': '1.0.0',
      'consentVersion': '2026-05',
    }, SetOptions(merge: true));
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  int _computeLevel(List<int?> answers) {
    var correct = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (i < answers.length && answers[i] == _questions[i].correctIndex) {
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
