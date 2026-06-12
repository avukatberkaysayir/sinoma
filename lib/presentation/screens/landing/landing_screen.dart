import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/auth_dialog.dart';

// Landing palette follows the app theme (ink dark ↔ rice-paper light) so the
// public page and the app read as ONE product.
const _lpGreen = Color(0xFF2EC4B6);
Color get _lpBg => AppColors.surface;
Color get _lpBg2 =>
    AppColors.dark ? const Color(0xFF121A19) : const Color(0xFFFCFAF4);

// Public marketing landing page (root URL). Voscreen-style: top bar with a
// login on the right, a hero with the "watch → choose the sentence" pitch and a
// mock player, feature cards, a 3-step how-it-works, and a footer. Signing in
// (top-right) routes to /home (handled by the router redirect + splash).
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider); // AppColors statics need explicit rebuilds
    final lang = ref.watch(localeProvider).languageCode;
    final tr = lang == 'tr';
    final signedIn = ref.watch(currentUserProvider).valueOrNull != null;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    String t(String trText, String enText, String koText) =>
        tr ? trText : (lang == 'ko' ? koText : enText);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_lpBg, _lpBg2],
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
                    t: t,
                    signedIn: signedIn,
                    onSetLang: (code) => ref
                        .read(localeProvider.notifier)
                        .setLocale(Locale(code)),
                  ),
                  // Promo film right under the header — same footprint as the
                  // Öğren player (16:9, centred). The hero text moved below.
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(24, wide ? 36 : 24, 24, 12),
                    child: Center(
                      child: _PromoFrame(lang: lang),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                    child: _Hero(t: t, signedIn: signedIn),
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
  final String Function(String tr, String en, String ko) t;
  final bool signedIn;
  final void Function(String code) onSetLang;
  const _TopBar(
      {required this.t, required this.signedIn, required this.onSetLang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          const _Logo(),
          const Spacer(),
          _LangToggle(onSetLang: onSetLang),
          const SizedBox(width: 12),
          if (signedIn)
            FilledButton(
              onPressed: () => context.go('/home'),
              style: FilledButton.styleFrom(
                backgroundColor: _lpGreen,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(t('Uygulamaya Git', 'Enter app', '앱으로 이동'),
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
              child: Text(t('Giriş Yap', 'Log in', '로그인'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () =>
                  showAuthDialog(context, startWithRegister: true),
              style: FilledButton.styleFrom(
                backgroundColor: _lpGreen,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(t('Kayıt Ol', 'Sign up', '회원가입'),
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
        Image.asset('assets/mascot/mascot.png',
            width: 36, height: 36, fit: BoxFit.contain),
        const SizedBox(width: 10),
        const Text('Sinoma',
            style: TextStyle(
                color: _lpGreen,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _LangToggle extends ConsumerWidget {
  final void Function(String code) onSetLang;
  const _LangToggle({required this.onSetLang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    Widget chip(String code, String label) {
      final on = lang == code;
      return GestureDetector(
        onTap: () => onSetLang(code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? _lpGreen.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? _lpGreen : AppColors.onSurfaceMuted,
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      chip('tr', 'TR'),
      chip('en', 'EN'),
      chip('ko', '한국어'),
    ]);
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final String Function(String tr, String en, String ko) t;
  final bool signedIn;
  const _Hero({required this.t, required this.signedIn});

  @override
  Widget build(BuildContext context) {
    // Centred under the promo film — bold, high-contrast, theme-aware.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _lpGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
              t('🎬 Video ile Mandarin', '🎬 Mandarin through video',
                  '🎬 영상으로 배우는 중국어'),
              style: const TextStyle(
                  color: _lpGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 20),
        Text(
          t('Gerçek videolarla Mandarin öğren',
              'Learn Mandarin with real videos',
              '진짜 영상으로 중국어를 배우세요'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 44,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(
            t(
              'İzle, duyduğun cümleyi seç, anında öğren. Gerçek diyaloglar, '
                  'otomatik altyazı ve HSK 1-6 seviyeleri ile.',
              'Watch, pick the sentence you heard, and learn instantly. Real '
                  'dialogues, auto subtitles and HSK 1-6 levels.',
              '영상을 보고, 들은 문장을 고르고, 바로 배워요. '
                  '실제 대화와 자동 자막, HSK 1-6 레벨까지.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.text70,
                fontSize: 17,
                height: 1.5,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => signedIn
                  ? context.go('/home')
                  : showAuthDialog(context, startWithRegister: true),
              icon: Icon(
                  signedIn ? Icons.arrow_forward_rounded : Icons.rocket_launch,
                  size: 18),
              label: Text(signedIn
                  ? t('Uygulamaya Devam Et', 'Continue to app', '앱으로 이동')
                  : t('Ücretsiz Başla', 'Start free', '무료로 시작하기')),
              style: FilledButton.styleFrom(
                backgroundColor: _lpGreen,
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
                label: Text(
                    t('Videolara Göz At', 'Browse videos', '영상 둘러보기')),
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

// ── Promo frame ───────────────────────────────────────────────────────────────
// The scripted HTML promo (web/promo/sinoma_promo.html) embedded as an iframe
// platform view — it scrolls with the page and keeps its own play overlay.

class _PromoFrame extends StatelessWidget {
  // Per-language promo pages generated by tools/gen_promo_locales.py from the
  // English master — the frame follows the landing language live.
  final String lang;
  const _PromoFrame({required this.lang});

  static final Set<String> _registered = {};

  static void _register(String lang) {
    if (!_registered.add(lang)) return;
    ui_web.platformViewRegistry.registerViewFactory('sinoma-promo-$lang',
        (int id) {
      final el = web.document.createElement('iframe')
          as web.HTMLIFrameElement;
      el.src = lang == 'en'
          ? 'promo/sinoma_promo.html'
          : 'promo/sinoma_promo_$lang.html';
      el.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%'
        ..borderRadius = '18px';
      el.allow = 'autoplay';
      return el;
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = kSupportedUiLanguages.contains(lang) ? lang : 'en';
    _register(code);
    // Wide hero footprint: 16:9, centred, fills the content column.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          // Keyed by language so a locale switch tears the old iframe down and
          // mounts the matching promo.
          child: HtmlElementView(
              key: ValueKey(code), viewType: 'sinoma-promo-$code'),
        ),
      ),
    );
  }
}
// ── Feature cards ─────────────────────────────────────────────────────────────

class _Features extends StatelessWidget {
  final String Function(String tr, String en, String ko) t;
  const _Features({required this.t});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.movie_filter_outlined,
        t('Gerçek videolar', 'Authentic videos', '실제 영상'),
        t('Ezber değil; gerçek diyalog ve içeriklerle öğren.',
            'No rote drills — learn from real dialogue and content.',
            '암기식 훈련이 아닌, 실제 대화와 콘텐츠로 배워요.'),
      ),
      (
        Icons.hearing_outlined,
        t('Duy & Seç', 'Listen & choose', '듣고 고르기'),
        t('Klibi dinle, doğru cümleyi seç. Aktif dinleme.',
            'Hear the clip, pick the right sentence. Active listening.',
            '클립을 듣고 맞는 문장을 고르세요. 능동적인 듣기 연습이에요.'),
      ),
      (
        Icons.school_outlined,
        t('HSK 1-6 seviyeleri', 'HSK 1-6 levels', 'HSK 1-6 레벨'),
        t('Seviyene göre filtrele, adım adım ilerle.',
            'Filter by your level and progress step by step.',
            '내 레벨에 맞게 골라서 차근차근 나아가요.'),
      ),
      (
        Icons.translate_outlined,
        t('Kelime sözlüğü', 'Word dictionary', '단어 사전'),
        t('Her kelimeye dokun; anlam ve pinyin anında.',
            'Tap any word for meaning and pinyin instantly.',
            '아무 단어나 탭하면 뜻과 병음이 바로 나와요.'),
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
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(it.$1, color: _lpGreen, size: 28),
                  const SizedBox(height: 12),
                  Text(it.$2,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(it.$3,
                      style: TextStyle(
                          color: AppColors.text70,
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
  final String Function(String tr, String en, String ko) t;
  const _HowItWorks({required this.t});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', t('İzle', 'Watch', '보기'),
          t('Kısa bir klip oynat.', 'Play a short clip.', '짧은 클립을 재생해요.')),
      ('2', t('Seç', 'Choose', '고르기'),
          t('Duyduğun cümleyi seç.', 'Pick the sentence you heard.',
              '들은 문장을 골라요.')),
      ('3', t('Öğren', 'Learn', '배우기'),
          t('Puan kazan, kelimeleri kaydet.', 'Earn points, save words.',
              '점수를 얻고 단어를 저장해요.')),
    ];
    return Column(
      children: [
        Text(t('Nasıl çalışır?', 'How it works', '어떻게 진행되나요?'),
            style: TextStyle(
                color: AppColors.text,
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
                        color: _lpGreen,
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
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(s.$3,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.text70, fontSize: 13)),
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
  final String Function(String tr, String en, String ko) t;
  const _Footer({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        children: [
          Text('© Sinoma',
              style: TextStyle(color: AppColors.text70, fontSize: 13)),
          Wrap(
            spacing: 20,
            children: [
              _FooterLink(
                  label: t('Gizlilik', 'Privacy', '개인정보처리방침'),
                  onTap: () => context.go('/legal/privacy')),
              _FooterLink(
                  label: t('Şartlar', 'Terms', '이용약관'),
                  onTap: () => context.go('/legal/terms')),
              _FooterLink(
                  label: t('Giriş Yap', 'Log in', '로그인'),
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
          style: TextStyle(
              color: AppColors.text70,
              fontSize: 13,
              decoration: TextDecoration.underline)),
    );
  }
}
