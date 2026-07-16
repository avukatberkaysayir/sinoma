import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';

Future<void> showAuthDialog(
  BuildContext context, {
  bool startWithRegister = false,
}) {
  return showDialog(
    context: context,
    builder: (_) => AuthDialog(startWithRegister: startWithRegister),
  );
}

class AuthDialog extends ConsumerStatefulWidget {
  final bool startWithRegister;
  const AuthDialog({super.key, this.startWithRegister = false});

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _verificationSent = false;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.startWithRegister ? 1 : 0,
    );
    _tab.addListener(() {
      if (_tab.indexIsChanging) {
        setState(() {
          _error = null;
          _verificationSent = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppL10n l10n) async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    final client = Supabase.instance.client;

    try {
      if (_tab.index == 0) {
        final res = await client.auth.signInWithPassword(
          email: email,
          password: pass,
        );
        if (!mounted) return;
        final profile = await client
            .from('users')
            .select('id')
            .eq('id', res.user!.id)
            .maybeSingle();
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.pop(context);
        context.go(profile == null ? '/onboarding' : '/home');
      } else {
        await client.auth.signUp(email: email, password: pass);
        if (mounted) setState(() { _loading = false; _verificationSent = true; });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() { _loading = false; _error = _mapError(e); });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: '${Uri.base.origin}/splash',
        queryParams: {'prompt': 'select_account'},
      );
      // Page will navigate away; no need to setState
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String _mapError(AuthException e) {
    final l10n = AppL10n.fromCode(ref.read(localeProvider).languageCode);
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return l10n.errEmailTaken;
    }
    if (msg.contains('invalid login') ||
        msg.contains('wrong') ||
        msg.contains('invalid credentials')) {
      return l10n.errBadCredentials;
    }
    if (msg.contains('too many')) return l10n.errTooMany;
    if (msg.contains('password') && msg.contains('short')) {
      return l10n.errPasswordShort;
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2030) : Colors.white;
    final l10n = AppL10n.fromCode(ref.watch(localeProvider).languageCode);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.white54 : Colors.black45;
    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Image.asset('assets/mascot/mascot.png',
            filterQuality: FilterQuality.high,
                      width: 30, height: 30, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  Text(
                    'Sinoma',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: mutedColor),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: mutedColor,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: l10n.loginBtn),
                Tab(text: l10n.signUpBtn),
              ],
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _verificationSent
                    ? _VerificationSentView(l10n: l10n, isDark: isDark)
                    : _FormView(
                        key: ValueKey(_tab.index),
                        isDark: isDark,
                        textColor: textColor,
                        mutedColor: mutedColor,
                        fieldFill: fieldFill,
                        l10n: l10n,
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        obscurePass: _obscurePass,
                        onToggleObscure: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        loading: _loading,
                        error: _error,
                        tabIndex: _tab.index,
                        onSubmit: () => _submit(l10n),
                        onGoogle: _signInWithGoogle,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationSentView extends StatelessWidget {
  final AppL10n l10n;
  final bool isDark;
  const _VerificationSentView({required this.l10n, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.mark_email_read_outlined,
            size: 48, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          l10n.verifyEmailTitle,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.verifyEmailBody,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ),
      ],
    );
  }
}

class _FormView extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final Color fieldFill;
  final AppL10n l10n;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final VoidCallback onToggleObscure;
  final bool loading;
  final String? error;
  final int tabIndex;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;

  const _FormView({
    super.key,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.fieldFill,
    required this.l10n,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscurePass,
    required this.onToggleObscure,
    required this.loading,
    required this.error,
    required this.tabIndex,
    required this.onSubmit,
    required this.onGoogle,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final isLogin = tabIndex == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google button
        OutlinedButton.icon(
          icon: const Icon(Icons.g_mobiledata_rounded,
              size: 22, color: Color(0xFF4285F4)),
          label: Text(
            l10n.googleSignIn,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: borderColor),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: loading ? null : onGoogle,
        ),
        const SizedBox(height: 14),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'veya',
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: borderColor)),
          ],
        ),
        const SizedBox(height: 14),

        // Email field
        _Field(
          controller: emailCtrl,
          hint: l10n.emailLabel,
          keyboardType: TextInputType.emailAddress,
          fill: fieldFill,
          isDark: isDark,
          borderColor: borderColor,
          textColor: textColor,
        ),
        const SizedBox(height: 10),

        // Password field
        _Field(
          controller: passCtrl,
          hint: l10n.passwordLabel,
          obscure: obscurePass,
          fill: fieldFill,
          isDark: isDark,
          borderColor: borderColor,
          textColor: textColor,
          suffix: IconButton(
            icon: Icon(
              obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: mutedColor,
            ),
            onPressed: onToggleObscure,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          onSubmitted: (_) => onSubmit(),
        ),

        // Error
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],

        const SizedBox(height: 16),

        // Submit
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: loading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isLogin ? l10n.authSubmitLogin : l10n.authSubmitRegister,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Color fill;
  final bool isDark;
  final Color borderColor;
  final Color textColor;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _Field({
    required this.controller,
    required this.hint,
    required this.fill,
    required this.isDark,
    required this.borderColor,
    required this.textColor,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
        filled: true,
        fillColor: fill,
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
