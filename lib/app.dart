import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_colors.dart';
import 'presentation/providers/auth_provider.dart' show adminEmail;
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/admin/admin_screen.dart';
import 'presentation/screens/dictionary/dictionary_screen.dart';
import 'presentation/screens/games/games_section_screen.dart';
import 'presentation/screens/games/hanzi_build/hanzi_build_screen.dart';
import 'presentation/screens/games/mandarin_duel/mandarin_duel_screen.dart';
import 'presentation/screens/landing/landing_screen.dart';
import 'presentation/screens/path/path_screen.dart';
import 'presentation/widgets/common/section_sidebar.dart';
import 'presentation/screens/language/language_selection_screen.dart';
import 'presentation/screens/legal/privacy_policy_screen.dart';
import 'presentation/screens/legal/terms_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/onboarding/hsk_retest_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/social/social_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/subscription/subscription_screen.dart';
import 'presentation/screens/video_player/video_player_screen.dart';
import 'presentation/screens/video_player/voscreen_player_screen.dart';
import 'presentation/widgets/common/connectivity_banner.dart';
import 'presentation/widgets/common/sinoma_top_bar.dart';

// ── Shell ─────────────────────────────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  static const _sectionRoutes = {'/video', '/home', '/dictionary', '/social', '/games'};

  static AppSection _sectionFromRoute(String loc) => switch (loc) {
    '/dictionary' => AppSection.dictionary,
    '/social'     => AppSection.social,
    '/games'      => AppSection.games,
    _             => AppSection.video,
  };

  @override
  Widget build(BuildContext context) {
    final loc      = GoRouterState.of(context).matchedLocation;
    final showTabs = _sectionRoutes.contains(loc);
    final section  = _sectionFromRoute(loc);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(showTabs ? 104 : 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SinomaTopBar(),
            if (showTabs) SectionTabBar(current: section),
          ],
        ),
      ),
      body: ConnectivityBanner(child: child),
    );
  }
}

// ── Router ────────────────────────────────────────────────────────────────────

class _AuthRefreshStream extends ChangeNotifier {
  _AuthRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _router = GoRouter(
  initialLocation: '/',
  refreshListenable: _AuthRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final user = Supabase.instance.client.auth.currentUser;

    if (loc.startsWith('/admin')) {
      if (user?.email != adminEmail) return '/home';
    }

    return null;
  },
  routes: [
    // ── Full-screen (no persistent top bar) ──────────────────────────────────
    GoRoute(path: '/',           builder: (_, __) => const LandingScreen()),
    GoRoute(path: '/splash',     builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/language',   builder: (_, __) => const LanguageSelectionScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/hsk-test',   builder: (_, __) => const HskRetestScreen()),
    GoRoute(
      path: '/video/:id',
      builder: (_, state) =>
          VideoPlayerScreen(videoId: state.pathParameters['id']!),
    ),
    // Learning-path sections — each is its own URL, all render PathScreen
    // (which picks the active section from the location).
    GoRoute(path: '/home',             builder: (_, __) => const PathScreen()),
    GoRoute(path: '/profile',          builder: (_, __) => const PathScreen()),
    GoRoute(path: '/settings',         builder: (_, __) => const PathScreen()),
    GoRoute(path: '/settings/profile', builder: (_, __) => const PathScreen()),
    GoRoute(path: '/video',            builder: (_, __) => const PathScreen()),
    GoRoute(path: '/dictionary',       builder: (_, __) => const PathScreen()),
    GoRoute(path: '/leaderboard',      builder: (_, __) => const PathScreen()),
    GoRoute(path: '/quests',           builder: (_, __) => const PathScreen()),
    GoRoute(path: '/shop',             builder: (_, __) => const PathScreen()),
    GoRoute(path: '/play',          builder: (_, __) => const VoscreenPlayerScreen()),
    GoRoute(path: '/games/duel',    builder: (_, __) => const MandarinDuelScreen()),
    GoRoute(path: '/games/hanzi',   builder: (_, __) => const HanziBuildScreen()),
    GoRoute(path: '/legal/terms',   builder: (_, __) => const TermsScreen()),
    GoRoute(path: '/legal/privacy', builder: (_, __) => const PrivacyPolicyScreen()),
    // ── Shell routes (persistent SinomaTopBar) ────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(path: '/hub',   redirect: (_, __) => '/home'),
        GoRoute(path: '/games', builder: (_, __) => const GamesSectionScreen()),
        GoRoute(path: '/social', builder: (_, __) => const SocialScreen()),
        GoRoute(path: '/admin',           builder: (_, __) => const AdminScreen()),
        GoRoute(path: '/admin/add-video', builder: (_, __) => const AddVideoScreen()),
        GoRoute(
          path: '/dictionary/:wordId',
          builder: (_, state) => DictionaryScreen(
            initialWordId: state.pathParameters['wordId'],
          ),
        ),
        GoRoute(
          path: '/profile/:uid',
          builder: (_, state) =>
              ProfileScreen(uid: state.pathParameters['uid']!),
        ),
        GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
      ],
    ),
  ],
);

// ── App ───────────────────────────────────────────────────────────────────────

class SinomaApp extends ConsumerWidget {
  const SinomaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale    = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Sinoma',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceVariant,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F3F7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
