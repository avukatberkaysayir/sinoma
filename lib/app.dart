import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_colors.dart';

final _router = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(path: '/onboarding', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/home', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/video/:id', builder: (_, state) => const Placeholder()),
    GoRoute(path: '/dictionary/:wordId', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/games/duel', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/games/hanzi', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/social', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/subscription', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/settings', builder: (_, __) => const Placeholder()),
  ],
  redirect: (context, state) {
    // Auth guard added in ADIM 13 (Onboarding).
    return null;
  },
);

class MandarinAcademyApp extends ConsumerWidget {
  const MandarinAcademyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Mandarin Academy',
      debugShowCheckedModeBanner: false,
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
      // fontFamily: 'NotoSansSC',  // Enable after adding font files
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceVariant,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
    );
  }
}
