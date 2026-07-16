import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../providers/onboarding_provider.dart';

// Duo palette - matches /home.
const _obBg = Color(0xFF0E1414);
const _obPanel = Color(0xFF161E1D);
const _obAccent = Color(0xFF2EC4B6);

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
          color: _obAccent,
          fontSize: 11,
          decoration: TextDecoration.underline,
          decorationColor: _obAccent,
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
      if (next.isComplete) context.go('/learn');
    });

    return Scaffold(
      backgroundColor: _obBg,
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
            Image.asset('assets/mascot/mascot.png',
            filterQuality: FilterQuality.high,
                width: 110, height: 110, fit: BoxFit.contain),
            const SizedBox(height: 28),
            const Text(
              '普通话学院',
              style: TextStyle(
                color: _obAccent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sinoma',
              style: TextStyle(
                color: Color(0xFFEEEEEE),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppL10n.of(context).onbTagline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
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
                child: Text(AppL10n.of(context).getStarted,
                    style: const TextStyle(fontSize: 16)),
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
  bool _registerMode = false; // top-right button flips Oturum Aç ↔ Kaydol

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        filled: true,
        fillColor: _obPanel,
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF263230), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _obAccent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  void _submit() {
    if (_registerMode) {
      widget.onRegisterWithEmail(_emailCtrl.text, _passwordCtrl.text);
    } else {
      widget.onSignInWithEmail(_emailCtrl.text, _passwordCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final title = _registerMode ? l10n.createAccount : l10n.signInTitle;
    return SafeArea(
      child: Stack(
        children: [
          // Top-left close → public landing.
          Positioned(
            top: 12,
            left: 12,
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Color(0xFF9E9E9E), size: 26),
              onPressed: () => context.go('/'),
            ),
          ),
          // Top-right mode toggle (Duolingo-style).
          Positioned(
            top: 14,
            right: 16,
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _registerMode = !_registerMode),
              style: OutlinedButton.styleFrom(
                foregroundColor: _obAccent,
                side: const BorderSide(color: Color(0xFF263230), width: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_registerMode ? l10n.oturumAcCaps : l10n.kaydolCaps,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/mascot/mascot.png',
            filterQuality: FilterQuality.high,
                          width: 64, height: 64, fit: BoxFit.contain),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFEEEEEE),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (widget.error != null) ...[
                        const SizedBox(height: 14),
                        _ErrorBanner(
                            message: widget.error!,
                            onDismiss: widget.onClearError),
                      ],
                      const SizedBox(height: 22),
                      if (!widget.isLoading) ...[
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                              color: Color(0xFFEEEEEE), fontSize: 15),
                          decoration: _dec(l10n.emailHint),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _submit(),
                          style: const TextStyle(
                              color: Color(0xFFEEEEEE), fontSize: 15),
                          decoration: _dec(
                            _registerMode
                                ? l10n.passwordHintMin
                                : l10n.passwordHint,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF9E9E9E),
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _obAccent,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                              _registerMode
                                  ? l10n.hesapOlusturCaps
                                  : l10n.oturumAcCaps,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Row(
                            children: [
                              const Expanded(
                                  child: Divider(color: Colors.white12)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text(
                                  l10n.orDivider,
                                  style: const TextStyle(
                                      color: Color(0xFF9E9E9E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1),
                                ),
                              ),
                              const Expanded(
                                  child: Divider(color: Colors.white12)),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.onGoogle,
                          icon: const Icon(Icons.g_mobiledata_rounded,
                              size: 28, color: _obAccent),
                          label: const Text('GOOGLE',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEEEEEE),
                            side: const BorderSide(
                                color: Color(0xFF263230), width: 2),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: widget.onAnonymous,
                          child: Text(
                            l10n.continueAsGuest,
                            style: const TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontSize: 13),
                          ),
                        ),
                      ] else
                        const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.byContinuing,
                            style: const TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontSize: 11),
                          ),
                          _LegalLink(
                              label: l10n.termsWord, route: '/legal/terms'),
                          Text(
                            l10n.andThe,
                            style: const TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontSize: 11),
                          ),
                          _LegalLink(
                              label: l10n.privacyWord,
                              route: '/legal/privacy'),
                          Text(
                            l10n.policyAccept,
                            style: const TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ],
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
                color: _obAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined,
                  size: 44, color: _obAccent),
            ),
            const SizedBox(height: 28),
            Text(
              AppL10n.of(context).verifyTitle,
              style: const TextStyle(
                color: Color(0xFFEEEEEE),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppL10n.of(context).verifyBody(email),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF9E9E9E),
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
                  label: Text(AppL10n.of(context).verifiedContinue,
                      style: const TextStyle(fontSize: 15)),
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
                child: Text(
                  AppL10n.of(context).resendLbl,
                  style: const TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 13),
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
            Text(
              AppL10n.of(context).whatToCallYou,
              style: const TextStyle(
                color: Color(0xFFEEEEEE),
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
                hintText: AppL10n.of(context).displayNameHint,
                hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                filled: true,
                fillColor: _obPanel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: Color(0xFF9E9E9E)),
              ),
              style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 16),
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
                    : Text(AppL10n.of(context).continueBtn,
                        style: const TextStyle(fontSize: 16)),
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
    final choices = question
        .choicesFor(Localizations.maybeLocaleOf(context)?.languageCode ?? 'en');

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
                      AppL10n.of(context).questionOf(state.questionIndex + 1,
                          OnboardingState.totalQuestions),
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 13,
                      ),
                    ),
                    _HskLevelDot(level: question.hskLevel),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: state.testProgress,
                  backgroundColor: _obPanel,
                  color: _obAccent,
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
                        color: _obPanel,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        question.text,
                        style: const TextStyle(
                          color: Color(0xFFEEEEEE),
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppL10n.of(context).whatMeans,
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
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
                choices.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => onAnswer(i),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                            color: Color(0xFF9E9E9E), width: 0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        choices[i],
                        style: const TextStyle(
                          color: Color(0xFFEEEEEE),
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
            Text(
              AppL10n.of(context).yourLevelLbl,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
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
              AppL10n.of(context).hskLevelDesc(hskLevel),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
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
                    : Text(
                        AppL10n.of(context).startLearning,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
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
