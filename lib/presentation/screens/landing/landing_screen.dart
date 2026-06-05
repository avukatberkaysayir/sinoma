import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/auth_dialog.dart';

// Public marketing landing page (root URL). Voscreen-style: top bar with a
// login on the right, a hero with the "watch → choose the sentence" pitch and a
// mock player, feature cards, a 3-step how-it-works, and a footer. Signing in
// (top-right) routes to /home (handled by the router redirect + splash).
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    final tr = lang == 'tr';
    final signedIn = ref.watch(currentUserProvider).valueOrNull != null;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    String t(String trText, String enText) => tr ? trText : enText;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surface, AppColors.surfaceVariant],
          ),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    tr: tr,
                    signedIn: signedIn,
                    onSetLang: (code) => ref
                        .read(localeProvider.notifier)
                        .setLocale(Locale(code)),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, wide ? 48 : 28, 24, 40),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _Hero(t: t, signedIn: signedIn)),
                              const SizedBox(width: 48),
                              const Expanded(child: _MockPlayer()),
                            ],
                          )
                        : Column(
                            children: [
                              _Hero(t: t, signedIn: signedIn),
                              const SizedBox(height: 36),
                              const _MockPlayer(),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _Features(t: t),
                  ),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _HowItWorks(t: t),
                  ),
                  const SizedBox(height: 56),
                  _Footer(t: t),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool tr;
  final bool signedIn;
  final void Function(String code) onSetLang;
  const _TopBar(
      {required this.tr, required this.signedIn, required this.onSetLang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          const _Logo(),
          const Spacer(),
          _LangToggle(tr: tr, onSetLang: onSetLang),
          const SizedBox(width: 12),
          if (signedIn)
            FilledButton(
              onPressed: () => context.go('/profile'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(tr ? 'Uygulamaya Git' : 'Enter app',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            )
          else ...[
            OutlinedButton(
              onPressed: () => showAuthDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                side: BorderSide(
                    color: AppColors.onSurfaceMuted.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(tr ? 'Giriş Yap' : 'Log in',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () =>
                  showAuthDialog(context, startWithRegister: true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(tr ? 'Kayıt Ol' : 'Sign up',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.play_circle_fill,
              color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 10),
        const Text('Sinoma',
            style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _LangToggle extends StatelessWidget {
  final bool tr;
  final void Function(String code) onSetLang;
  const _LangToggle({required this.tr, required this.onSetLang});

  @override
  Widget build(BuildContext context) {
    Widget chip(String code, String label) {
      final on = tr ? code == 'tr' : code == 'en';
      return GestureDetector(
        onTap: () => onSetLang(code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? AppColors.primary.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? AppColors.primary : AppColors.onSurfaceMuted,
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      chip('tr', 'TR'),
      chip('en', 'EN'),
    ]);
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final String Function(String tr, String en) t;
  final bool signedIn;
  const _Hero({required this.t, required this.signedIn});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(t('🎬 Video ile Mandarin', '🎬 Mandarin through video'),
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 20),
        Text(
          t('Gerçek videolarla\nMandarin öğren',
              'Learn Mandarin with\nreal videos'),
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 44,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          t(
            'İzle, duyduğun cümleyi seç, anında öğren. Gerçek diyaloglar, '
                'otomatik altyazı ve HSK 1-6 seviyeleri ile.',
            'Watch, pick the sentence you heard, and learn instantly. Real '
                'dialogues, auto subtitles and HSK 1-6 levels.',
          ),
          style: const TextStyle(
              color: AppColors.onSurfaceMuted, fontSize: 17, height: 1.5),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => signedIn
                  ? context.go('/profile')
                  : showAuthDialog(context, startWithRegister: true),
              icon: Icon(
                  signedIn ? Icons.arrow_forward_rounded : Icons.rocket_launch,
                  size: 18),
              label: Text(signedIn
                  ? t('Uygulamaya Devam Et', 'Continue to app')
                  : t('Ücretsiz Başla', 'Start free')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (!signedIn)
              OutlinedButton.icon(
                onPressed: () => context.go('/learn'),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(t('Videolara Göz At', 'Browse videos')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                  side: BorderSide(
                      color: AppColors.onSurfaceMuted.withValues(alpha: 0.4)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Mock player (illustration of the product) ────────────────────────────────

class _MockPlayer extends StatelessWidget {
  const _MockPlayer();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fake video frame
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF26314F), Color(0xFF101626)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 34),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('HSK 3',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Chinese subtitle bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C2E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('你今天打算做什么？',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 10),
          // Two answer options
          const Row(
            children: [
              Expanded(
                  child: _MockOption(
                      text: 'What are you doing today?', correct: true)),
              SizedBox(width: 10),
              Expanded(
                  child: _MockOption(
                      text: 'Where did you go yesterday?', correct: false)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockOption extends StatelessWidget {
  final String text;
  final bool correct;
  const _MockOption({required this.text, required this.correct});

  @override
  Widget build(BuildContext context) {
    final c = correct ? AppColors.correctAnswer : AppColors.onSurfaceMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: correct ? c.withValues(alpha: 0.14) : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (correct)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.check_circle,
                  color: AppColors.correctAnswer, size: 16),
            ),
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: correct ? AppColors.correctAnswer : AppColors.onSurfaceMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Feature cards ─────────────────────────────────────────────────────────────

class _Features extends StatelessWidget {
  final String Function(String tr, String en) t;
  const _Features({required this.t});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.movie_filter_outlined,
        t('Gerçek videolar', 'Authentic videos'),
        t('Ezber değil; gerçek diyalog ve içeriklerle öğren.',
            'No rote drills — learn from real dialogue and content.'),
      ),
      (
        Icons.hearing_outlined,
        t('Duy & Seç', 'Listen & choose'),
        t('Klibi dinle, doğru cümleyi seç. Aktif dinleme.',
            'Hear the clip, pick the right sentence. Active listening.'),
      ),
      (
        Icons.school_outlined,
        t('HSK 1-6 seviyeleri', 'HSK 1-6 levels'),
        t('Seviyene göre filtrele, adım adım ilerle.',
            'Filter by your level and progress step by step.'),
      ),
      (
        Icons.translate_outlined,
        t('Kelime sözlüğü', 'Word dictionary'),
        t('Her kelimeye dokun; anlam ve pinyin anında.',
            'Tap any word for meaning and pinyin instantly.'),
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        for (final it in items)
          SizedBox(
            width: 250,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(it.$1, color: AppColors.primary, size: 28),
                  const SizedBox(height: 12),
                  Text(it.$2,
                      style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(it.$3,
                      style: const TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 13,
                          height: 1.4)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── How it works ──────────────────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  final String Function(String tr, String en) t;
  const _HowItWorks({required this.t});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', t('İzle', 'Watch'),
          t('Kısa bir klip oynat.', 'Play a short clip.')),
      ('2', t('Seç', 'Choose'),
          t('Duyduğun cümleyi seç.', 'Pick the sentence you heard.')),
      ('3', t('Öğren', 'Learn'),
          t('Puan kazan, kelimeleri kaydet.', 'Earn points, save words.')),
    ];
    return Column(
      children: [
        Text(t('Nasıl çalışır?', 'How it works'),
            style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 24,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            for (final s in steps)
              SizedBox(
                width: 220,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(s.$1,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    Text(s.$2,
                        style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(s.$3,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.onSurfaceMuted, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final String Function(String tr, String en) t;
  const _Footer({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        children: [
          const Text('© Sinoma',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
          Wrap(
            spacing: 20,
            children: [
              _FooterLink(
                  label: t('Gizlilik', 'Privacy'),
                  onTap: () => context.go('/legal/privacy')),
              _FooterLink(
                  label: t('Şartlar', 'Terms'),
                  onTap: () => context.go('/legal/terms')),
              _FooterLink(
                  label: t('Giriş Yap', 'Log in'),
                  onTap: () => showAuthDialog(context)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 13,
              decoration: TextDecoration.underline)),
    );
  }
}
