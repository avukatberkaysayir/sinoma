import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_colors.dart';
import 'data/services/notification_service.dart';
import 'presentation/providers/auth_provider.dart' show adminEmail;
import 'presentation/providers/locale_provider.dart';
import 'presentation/screens/admin/admin_screen.dart';
import 'presentation/screens/dictionary/dictionary_screen.dart';
import 'presentation/screens/games/hanzi_build/hanzi_build_screen.dart';
import 'presentation/screens/games/mandarin_duel/mandarin_duel_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/language/language_selection_screen.dart';
import 'presentation/screens/legal/privacy_policy_screen.dart';
import 'presentation/screens/legal/terms_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/social/social_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/subscription/subscription_screen.dart';
import 'presentation/screens/video_player/video_player_screen.dart';
import 'presentation/screens/video_player/voscreen_player_screen.dart';

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
  initialLocation: '/splash',
  refreshListenable: _AuthRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final user = FirebaseAuth.instance.currentUser;

    // Admin-only guard
    if (loc.startsWith('/admin')) {
      if (user?.email != adminEmail) return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/splash',     builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/language',   builder: (_, __) => const LanguageSelectionScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/home',       builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/video/:id',
      builder: (_, state) =>
          VideoPlayerScreen(videoId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/play',       builder: (_, __) => const VoscreenPlayerScreen()),
    GoRoute(
      path: '/dictionary/:wordId',
      builder: (_, state) => DictionaryScreen(
        initialWordId: state.pathParameters['wordId'],
      ),
    ),
    GoRoute(path: '/games/duel',    builder: (_, __) => const MandarinDuelScreen()),
    GoRoute(path: '/games/hanzi',   builder: (_, __) => const HanziBuildScreen()),
    GoRoute(path: '/social',        builder: (_, __) => const SocialScreen()),
    GoRoute(path: '/subscription',  builder: (_, __) => const SubscriptionScreen()),
    GoRoute(path: '/settings',      builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/legal/terms',   builder: (_, __) => const TermsScreen()),
    GoRoute(path: '/legal/privacy', builder: (_, __) => const PrivacyPolicyScreen()),
    GoRoute(path: '/admin',         builder: (_, __) => const AdminScreen()),
    GoRoute(path: '/admin/add-video', builder: (_, __) => const AddVideoScreen()),
  ],
);

class SinomaApp extends ConsumerWidget {
  const SinomaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    NotificationService.setNavigationCallback(_router.go);
    final locale = ref.watch(localeProvider);

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
      theme: _buildTheme(),
      routerConfig: _router,
    );
  }

  ThemeData _buildTheme() {
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
}
