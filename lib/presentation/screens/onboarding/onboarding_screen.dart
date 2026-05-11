import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/onboarding_provider.dart';

// Tappable inline span for ToS/PP links.
class _LegalLink extends StatelessWidget {
  final String label;
  final String route;
  const _LegalLink({required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
        ),
      ),
    );
  }
}

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    ref.listen(onboardingProvider, (_, next) {
      if (next.isComplete) context.go('/home');
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (state.step) {
          OnboardingStep.welcome => _WelcomePage(
              key: const ValueKey('welcome'),
              onStart: notifier.advanceToSignIn,
            ),
          OnboardingStep.signIn => _SignInPage(
              key: const ValueKey('signIn'),
              isLoading: state.isLoading,
              error: state.error,
              onGoogle: notifier.signInWithGoogle,
              onAnonymous: notifier.signInAnonymously,
              onDevLogin: notifier.signInWithDevAccount,
              onRegisterWithEmail: notifier.registerWithEmail,
              onSignInWithEmail: notifier.signInWithEmail,
              onClearError: notifier.clearError,
            ),
          OnboardingStep.emailVerification => _EmailVerificationPage(
              key: const ValueKey('emailVerification'),
              email: state.pendingVerificationEmail ?? '',
              isLoading: state.isLoading,
              error: state.error,
              onCheckVerified: notifier.checkEmailVerified,
              onResend: notifier.resendVerificationEmail,
              onClearError: notifier.clearError,
            ),
          OnboardingStep.profile => _ProfilePage(
              key: const ValueKey('profile'),
              initialName: state.displayName,
              isLoading: state.isLoading,
              error: state.error,
              onNameChanged: notifier.updateDisplayName,
              onConfirm: notifier.confirmDisplayName,
              onClearError: notifier.clearError,
            ),
          OnboardingStep.test => _TestPage(
              key: const ValueKey('test'),
              state: state,
              onAnswer: notifier.selectAnswer,
            ),
          OnboardingStep.results => _ResultsPage(
              key: const ValueKey('results'),
              hskLevel: state.hskLevel ?? 1,
              isLoading: state.isLoading,
              error: state.error,
              onComplete: notifier.completeOnboarding,
              onClearError: notifier.clearError,
            ),
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  final VoidCallback onStart;
  const _WelcomePage({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.language, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            const Text(
              '普通话学院',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mandarin Academy',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Learn Mandarin through real video clips,\nAI explanations, and fun games.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Get Started', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign In
// ---------------------------------------------------------------------------

class _SignInPage extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback onGoogle;
  final VoidCallback onAnonymous;
  final VoidCallback onDevLogin;
  final void Function(String email, String password) onRegisterWithEmail;
  final void Function(String email, String password) onSignInWithEmail;
  final VoidCallback onClearError;

  const _SignInPage({
    super.key,
    required this.isLoading,
    required this.error,
    required this.onGoogle,
    required this.onAnonymous,
    required this.onDevLogin,
    required this.onRegisterWithEmail,
    required this.onSignInWithEmail,
    required this.onClearError,
  });

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.login_rounded, size: 56, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'Hesap Oluştur / Giriş Yap',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'İlerlemeni kaydet, cihazlar arasında senkronize et.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(
                  message: widget.error!, onDismiss: widget.onClearError),
            ],
            const SizedBox(height: 32),

            // ── Google ──────────────────────────────────────────────────────
            if (!widget.isLoading) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onGoogle,
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                  label: const Text('Google ile Devam Et',
                      style: TextStyle(fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side:
                        const BorderSide(color: AppColors.onSurfaceMuted),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              // ── Divider ─────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white12)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'VEYA E-POSTA İLE',
                        style: TextStyle(
                            color: AppColors.onSurfaceMuted, fontSize: 11),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),
              ),

              // ── Email field ─────────────────────────────────────────────
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'E-posta',
                  hintStyle:
                      const TextStyle(color: AppColors.onSurfaceMuted),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: AppColors.onSurfaceMuted, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(
                    color: AppColors.onSurface, fontSize: 15),
              ),
              const SizedBox(height: 10),

              // ── Password field ──────────────────────────────────────────
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Şifre (en az 6 karakter)',
                  hintStyle:
                      const TextStyle(color: AppColors.onSurfaceMuted),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppColors.onSurfaceMuted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.onSurfaceMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(
                    color: AppColors.onSurface, fontSize: 15),
              ),
              const SizedBox(height: 12),

              // ── Email action buttons ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => widget.onSignInWithEmail(
                          _emailCtrl.text, _passwordCtrl.text),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                            color: AppColors.onSurfaceMuted),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Giriş Yap',
                          style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => widget.onRegisterWithEmail(
                          _emailCtrl.text, _passwordCtrl.text),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Kayıt Ol',
                          style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.onAnonymous,
                child: const Text(
                  'Misafir olarak devam et',
                  style: TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 13),
                ),
              ),
            ] else
              const CircularProgressIndicator(),

            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Devam ederek ',
                  style: TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 11),
                ),
                _LegalLink(label: 'Şartlar', route: '/legal/terms'),
                Text(
                  "'ı ve ",
                  style: TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 11),
                ),
                _LegalLink(
                    label: 'Gizlilik', route: '/legal/privacy'),
                Text(
                  " politikasını kabul edersin.",
                  style: TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Email Verification
// ---------------------------------------------------------------------------

class _EmailVerificationPage extends StatelessWidget {
  final String email;
  final bool isLoading;
  final String? error;
  final VoidCallback onCheckVerified;
  final VoidCallback onResend;
  final VoidCallback onClearError;

  const _EmailVerificationPage({
    super.key,
    required this.email,
    required this.isLoading,
    required this.error,
    required this.onCheckVerified,
    required this.onResend,
    required this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            const Text(
              'E-postanı Doğrula',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$email adresine bir doğrulama bağlantısı gönderdik.\nE-postanı doğruladıktan sonra aşağıdaki butona bas.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 14,
                  height: 1.5),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: error!, onDismiss: onClearError),
            ],
            const Spacer(flex: 2),
            if (isLoading)
              const CircularProgressIndicator()
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCheckVerified,
                  icon: const Icon(Icons.verified_outlined, size: 20),
                  label: const Text('Doğruladım, Devam Et',
                      style: TextStyle(fontSize: 15)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onResend,
                child: const Text(
                  'Tekrar gönder',
                  style: TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Setup
// ---------------------------------------------------------------------------

class _ProfilePage extends StatefulWidget {
  final String initialName;
  final bool isLoading;
  final String? error;
  final void Function(String) onNameChanged;
  final VoidCallback onConfirm;
  final VoidCallback onClearError;

  const _ProfilePage({
    super.key,
    required this.initialName,
    required this.isLoading,
    required this.error,
    required this.onNameChanged,
    required this.onConfirm,
    required this.onClearError,
  });

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            const Text(
              'What should we\ncall you?',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 24,
              onChanged: widget.onNameChanged,
              decoration: InputDecoration(
                hintText: 'Display name',
                hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: AppColors.onSurfaceMuted),
              ),
              style: const TextStyle(color: AppColors.onSurface, fontSize: 16),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: widget.error!, onDismiss: widget.onClearError),
            ],
            const Spacer(flex: 2),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.isLoading ? null : widget.onConfirm,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placement Test
// ---------------------------------------------------------------------------

class _TestPage extends StatelessWidget {
  final OnboardingState state;
  final void Function(int) onAnswer;

  const _TestPage({super.key, required this.state, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final question = state.currentQuestion;
    if (question == null) return const SizedBox.shrink();

    return SafeArea(
      child: Column(
        children: [
          // Progress
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${state.questionIndex + 1} / ${OnboardingState.totalQuestions}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 13,
                      ),
                    ),
                    _HskLevelDot(level: question.hskLevel),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: state.testProgress,
                  backgroundColor: AppColors.surfaceVariant,
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ],
            ),
          ),
          // Chinese word
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        question.text,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'What does this mean?',
                      style: TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Answer choices
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              children: List.generate(
                question.choices.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => onAnswer(i),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                            color: AppColors.onSurfaceMuted, width: 0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        question.choices[i],
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

class _ResultsPage extends StatelessWidget {
  final int hskLevel;
  final bool isLoading;
  final String? error;
  final VoidCallback onComplete;
  final VoidCallback onClearError;

  const _ResultsPage({
    super.key,
    required this.hskLevel,
    required this.isLoading,
    required this.error,
    required this.onComplete,
    required this.onClearError,
  });

  static const _descriptions = {
    1: 'You\'re just starting out. We\'ll build your foundation with essential words and phrases.',
    2: 'You know the basics. Time to expand your vocabulary and sentence patterns.',
    3: 'Intermediate level — you can handle everyday conversations. Let\'s push further.',
    4: 'Upper-intermediate — you\'re comfortable with complex topics. Let\'s refine your fluency.',
    5: 'Advanced — you can discuss abstract ideas. We\'ll challenge your nuance and precision.',
    6: 'Mastery level — you\'re at near-native proficiency. Only the finest challenges await.',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.forHskLevel(hskLevel).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'HSK $hskLevel',
                  style: TextStyle(
                    color: AppColors.forHskLevel(hskLevel),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Level',
              style: TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'HSK $hskLevel',
              style: TextStyle(
                color: AppColors.forHskLevel(hskLevel),
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _descriptions[hskLevel] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: error!, onDismiss: onClearError),
            ],
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : onComplete,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.forHskLevel(hskLevel),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start Learning',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _HskLevelDot extends StatelessWidget {
  final int level;
  const _HskLevelDot({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.forHskLevel(level).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'HSK $level',
        style: TextStyle(
          color: AppColors.forHskLevel(level),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.wrongAnswer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.wrongAnswer.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.wrongAnswer, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.wrongAnswer, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                color: AppColors.wrongAnswer, size: 16),
          ),
        ],
      ),
    );
  }
}
