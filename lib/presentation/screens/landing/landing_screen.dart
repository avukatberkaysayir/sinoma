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

    String t(String trText, String enText, String koText,
            [String? jaText, String? idText, String? viText, String? thText]) =>
        tr
            ? trText
            : (lang == 'ko'
                ? koText
                : (lang == 'ja'
                    ? (jaText ?? enText)
                    : (lang == 'id'
                        ? (idText ?? enText)
                        : (lang == 'vi'
                            ? (viText ?? enText)
                            : (lang == 'th' ? (thText ?? enText) : enText)))));

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
                    // Defer setLocale to after this frame: changing the locale
                    // rebuilds MaterialApp.router, and doing that synchronously
                    // while the popup menu route is popping throws
                    // "markNeedsBuild during build" (red screen, which also
                    // blocks sign-in). Post-frame avoids it.
                    onSetLang: (code) =>
                        WidgetsBinding.instance.addPostFrameCallback((_) => ref
                            .read(localeProvider.notifier)
                            .setLocale(Locale(code))),
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

class _TopBar extends ConsumerWidget {
  final String Function(String tr, String en, String ko, [String? ja, String? id, String? vi, String? th]) t;
  final bool signedIn;
  final void Function(String code) onSetLang;
  const _TopBar(
      {required this.t, required this.signedIn, required this.onSetLang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              child: Text(t('Uygulamaya Git', 'Enter app', '앱으로 이동', 'アプリへ', 'Buka aplikasi', 'Vào ứng dụng', 'เข้าแอป'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            )
          else ...[
            OutlinedButton(
              onPressed: () => _openAuth(ref, context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                side: BorderSide(
                    color: AppColors.onSurfaceMuted.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(t('Giriş Yap', 'Log in', '로그인', 'ログイン', 'Masuk', 'Đăng nhập', 'เข้าสู่ระบบ'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => _openAuth(ref, context, register: true),
              style: FilledButton.styleFrom(
                backgroundColor: _lpGreen,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(t('Kayıt Ol', 'Sign up', '회원가입', '新規登録', 'Daftar', 'Đăng ký', 'สมัครสมาชิก'),
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

// The promo is an HTML iframe (platform view). On web an iframe paints ABOVE
// Flutter's overlay layer, so a centered dialog (sign-in) or a dropdown menu
// (language) that overlaps the promo region renders BEHIND it and becomes
// unusable. We hide the iframe (swap in a static poster) whenever such an
// overlay is open, then restore it — keeping both the promo and the overlays
// working. (Inline chips never hit this; routed overlays do.)
final _landingPromoVisible = StateProvider<bool>((ref) => true);

// Opens the auth dialog with the promo iframe hidden so the dialog is not
// occluded by it; always restores the promo afterwards.
Future<void> _openAuth(WidgetRef ref, BuildContext context,
    {bool register = false}) async {
  ref.read(_landingPromoVisible.notifier).state = false;
  try {
    await showAuthDialog(context, startWithRegister: register);
  } finally {
    if (context.mounted) ref.read(_landingPromoVisible.notifier).state = true;
  }
}

// Live UI languages shown in the landing language dropdown, in launch order.
const List<(String code, String label, String flag)> _kLangChoices = [
  ('tr', 'Türkçe', '🇹🇷'),
  ('en', 'English', '🇬🇧'),
  ('ko', '한국어', '🇰🇷'),
  ('ja', '日本語', '🇯🇵'),
  ('id', 'Bahasa Indonesia', '🇮🇩'),
  ('vi', 'Tiếng Việt', '🇻🇳'),
  ('th', 'ภาษาไทย', '🇹🇭'),
];

// Five rows visible; the rest scroll. 44px per item + 16px menu padding.
const double _kLangMenuMaxHeight = 5 * 44 + 16;

class _LangToggle extends ConsumerWidget {
  final void Function(String code) onSetLang;
  const _LangToggle({required this.onSetLang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    final current = _kLangChoices.firstWhere(
      (c) => c.$1 == lang,
      orElse: () => _kLangChoices[1], // English fallback
    );

    return PopupMenuButton<String>(
      tooltip: 'Language',
      // Hide the promo iframe while the menu is open so it isn't occluded by it.
      onOpened: () => ref.read(_landingPromoVisible.notifier).state = false,
      onCanceled: () => ref.read(_landingPromoVisible.notifier).state = true,
      onSelected: (code) {
        ref.read(_landingPromoVisible.notifier).state = true;
        onSetLang(code);
      },
      offset: const Offset(0, 40), // open downward, below the trigger
      color: AppColors.surface,
      // Cap the menu at five rows; the remaining languages scroll into view.
      constraints: const BoxConstraints(
          minWidth: 180, maxWidth: 260, maxHeight: _kLangMenuMaxHeight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final c in _kLangChoices)
          PopupMenuItem<String>(
            value: c.$1,
            height: 44,
            child: Row(children: [
              Text(c.$3, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(c.$2,
                    style: TextStyle(
                        color: c.$1 == lang ? _lpGreen : AppColors.onSurface,
                        fontSize: 14,
                        fontWeight:
                            c.$1 == lang ? FontWeight.w700 : FontWeight.w500)),
              ),
              if (c.$1 == lang)
                const Icon(Icons.check_rounded, size: 16, color: _lpGreen),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.onSurfaceMuted.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(current.$3, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(current.$2,
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Icon(Icons.arrow_drop_down_rounded,
              size: 20, color: AppColors.onSurfaceMuted),
        ]),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _Hero extends ConsumerWidget {
  final String Function(String tr, String en, String ko, [String? ja, String? id, String? vi, String? th]) t;
  final bool signedIn;
  const _Hero({required this.t, required this.signedIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  '🎬 영상으로 배우는 중국어', '🎬 動画で学ぶ中国語', '🎬 Mandarin lewat video', '🎬 Học tiếng Trung qua video', '🎬 เรียนภาษาจีนผ่านวิดีโอ'),
              style: const TextStyle(
                  color: _lpGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 20),
        Text(
          t('Gerçek videolarla Mandarin öğren',
              'Learn Mandarin with real videos',
              '진짜 영상으로 중국어를 배우세요', '本物の動画で中国語を学ぼう', 'Belajar Mandarin dengan video nyata', 'Học tiếng Trung bằng video thật', 'เรียนภาษาจีนด้วยวิดีโอจริง'),
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
              '動画を見て、聞こえた文を選び、すぐに学べます。'
                  '本物の会話と自動字幕、HSK1〜6のレベルまで。',
              'Tonton, pilih kalimat yang kamu dengar, langsung paham. '
                  'Dengan dialog nyata, subtitel otomatis, dan level HSK 1-6.',
              'Xem, chọn câu bạn nghe được, hiểu ngay lập tức. '
                  'Với hội thoại thật, phụ đề tự động và cấp độ HSK 1-6.',
              'ดูคลิป เลือกประโยคที่ได้ยิน แล้วเรียนรู้ทันที '
                  'พร้อมบทสนทนาจริง คำบรรยายอัตโนมัติ และระดับ HSK 1-6',
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
                  : _openAuth(ref, context, register: true),
              icon: Icon(
                  signedIn ? Icons.arrow_forward_rounded : Icons.rocket_launch,
                  size: 18),
              label: Text(signedIn
                  ? t('Uygulamaya Devam Et', 'Continue to app', '앱으로 이동', 'アプリへ進む', 'Lanjut ke aplikasi', 'Tiếp tục vào ứng dụng', 'ไปยังแอปต่อ')
                  : t('Ücretsiz Başla', 'Start free', '무료로 시작하기', '無料で始める', 'Mulai gratis', 'Bắt đầu miễn phí', 'เริ่มฟรี')),
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
                    t('Videolara Göz At', 'Browse videos', '영상 둘러보기', '動画を見てみる', 'Lihat video', 'Xem video', 'ดูวิดีโอ')),
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

class _PromoFrame extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final code = kSupportedUiLanguages.contains(lang) ? lang : 'en';
    final visible = ref.watch(_landingPromoVisible);
    if (visible) _register(code);
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
          // While an overlay (sign-in dialog / language menu) is open the iframe
          // is swapped for a static poster so it cannot paint over the overlay;
          // it remounts (and replays) when the overlay closes. Keyed by language
          // so a locale switch tears the old iframe down and mounts the match.
          child: visible
              ? HtmlElementView(
                  key: ValueKey(code), viewType: 'sinoma-promo-$code')
              : const _PromoPoster(),
        ),
      ),
    );
  }
}

// Static stand-in shown in place of the promo iframe while an overlay is open.
class _PromoPoster extends StatelessWidget {
  const _PromoPoster();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1414),
      alignment: Alignment.center,
      child: Image.asset('assets/mascot/mascot.png',
          width: 72, height: 72, fit: BoxFit.contain),
    );
  }
}
// ── Feature cards ─────────────────────────────────────────────────────────────

class _Features extends StatelessWidget {
  final String Function(String tr, String en, String ko, [String? ja, String? id, String? vi, String? th]) t;
  const _Features({required this.t});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.movie_filter_outlined,
        t('Gerçek videolar', 'Authentic videos', '실제 영상', '本物の動画', 'Video asli', 'Video thật', 'วิดีโอจริง'),
        t('Ezber değil; gerçek diyalog ve içeriklerle öğren.',
            'No rote drills — learn from real dialogue and content.',
            '암기식 훈련이 아닌, 실제 대화와 콘텐츠로 배워요.',
            '丸暗記ではなく、本物の会話とコンテンツで学べます。',
            'Bukan hafalan — belajar dari dialog dan konten nyata.',
            'Không học vẹt — học từ hội thoại và nội dung thật.',
            'ไม่ใช่การท่องจำ — เรียนจากบทสนทนาและเนื้อหาจริง'),
      ),
      (
        Icons.hearing_outlined,
        t('Duy & Seç', 'Listen & choose', '듣고 고르기', '聞いて選ぶ', 'Dengar & pilih', 'Nghe & chọn', 'ฟัง & เลือก'),
        t('Klibi dinle, doğru cümleyi seç. Aktif dinleme.',
            'Hear the clip, pick the right sentence. Active listening.',
            '클립을 듣고 맞는 문장을 고르세요. 능동적인 듣기 연습이에요.',
            'クリップを聞いて正しい文を選ぶ。能動的なリスニングです。',
            'Dengar klipnya, pilih kalimat yang tepat. Menyimak aktif.',
            'Nghe clip, chọn câu đúng. Luyện nghe chủ động.',
            'ฟังคลิป เลือกประโยคที่ถูกต้อง ฝึกการฟังเชิงรุก'),
      ),
      (
        Icons.school_outlined,
        t('HSK 1-6 seviyeleri', 'HSK 1-6 levels', 'HSK 1-6 레벨', 'HSK1〜6レベル', 'Level HSK 1-6', 'Cấp độ HSK 1-6', 'ระดับ HSK 1-6'),
        t('Seviyene göre filtrele, adım adım ilerle.',
            'Filter by your level and progress step by step.',
            '내 레벨에 맞게 골라서 차근차근 나아가요.',
            '自分のレベルで絞り込み、一歩ずつ進めます。',
            'Saring sesuai levelmu, maju selangkah demi selangkah.',
            'Lọc theo cấp độ của bạn, tiến từng bước một.',
            'กรองตามระดับของคุณ แล้วก้าวหน้าทีละขั้น'),
      ),
      (
        Icons.translate_outlined,
        t('Kelime sözlüğü', 'Word dictionary', '단어 사전', '単語辞書', 'Kamus kata', 'Từ điển từ', 'พจนานุกรมคำศัพท์'),
        t('Her kelimeye dokun; anlam ve pinyin anında.',
            'Tap any word for meaning and pinyin instantly.',
            '아무 단어나 탭하면 뜻과 병음이 바로 나와요.',
            'どの単語もタップで意味とピンインがすぐに表示。',
            'Ketuk kata mana pun; arti dan pinyin langsung muncul.',
            'Chạm vào từ bất kỳ; nghĩa và pinyin hiện ra ngay.',
            'แตะคำใดก็ได้ ดูความหมายและพินอินทันที'),
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
  final String Function(String tr, String en, String ko, [String? ja, String? id, String? vi, String? th]) t;
  const _HowItWorks({required this.t});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', t('İzle', 'Watch', '보기', '見る', 'Tonton', 'Xem', 'ดู'),
          t('Kısa bir klip oynat.', 'Play a short clip.', '짧은 클립을 재생해요.', '短いクリップを再生します。', 'Putar klip pendek.', 'Phát một clip ngắn.', 'เล่นคลิปสั้น ๆ')),
      ('2', t('Seç', 'Choose', '고르기', '選ぶ', 'Pilih', 'Chọn', 'เลือก'),
          t('Duyduğun cümleyi seç.', 'Pick the sentence you heard.',
              '들은 문장을 골라요.', '聞こえた文を選びます。', 'Pilih kalimat yang kamu dengar.', 'Chọn câu bạn nghe được.', 'เลือกประโยคที่ได้ยิน')),
      ('3', t('Öğren', 'Learn', '배우기', '学ぶ', 'Belajar', 'Học', 'เรียน'),
          t('Puan kazan, kelimeleri kaydet.', 'Earn points, save words.',
              '점수를 얻고 단어를 저장해요.', 'ポイントを獲得し、単語を保存します。', 'Dapatkan poin, simpan kata.', 'Nhận điểm, lưu từ vựng.', 'รับคะแนน บันทึกคำศัพท์')),
    ];
    return Column(
      children: [
        Text(t('Nasıl çalışır?', 'How it works', '어떻게 진행되나요?', '使い方', 'Cara kerjanya', 'Cách hoạt động', 'วิธีการทำงาน'),
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
  final String Function(String tr, String en, String ko, [String? ja, String? id, String? vi, String? th]) t;
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
                  label: t('Gizlilik', 'Privacy', '개인정보처리방침', 'プライバシー', 'Privasi', 'Quyền riêng tư', 'ความเป็นส่วนตัว'),
                  onTap: () => context.go('/legal/privacy')),
              _FooterLink(
                  label: t('Şartlar', 'Terms', '이용약관', '利用規約', 'Ketentuan', 'Điều khoản', 'ข้อกำหนด'),
                  onTap: () => context.go('/legal/terms')),
              _FooterLink(
                  label: t('Giriş Yap', 'Log in', '로그인', 'ログイン', 'Masuk', 'Đăng nhập', 'เข้าสู่ระบบ'),
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
