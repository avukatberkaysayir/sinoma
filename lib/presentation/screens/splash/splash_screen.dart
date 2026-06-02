import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route().timeout(const Duration(seconds: 10)).catchError((_) {
      if (mounted) context.go('/home');
    });
  }

  Future<void> _route() async {
    // Wait for Supabase to confirm session state. On web, the JS SDK reads
    // localStorage asynchronously; checking currentUser immediately after
    // Supabase.initialize() can race with token restoration. We check
    // synchronously first; if null, wait up to 2 s for the initial-session
    // event before giving up and treating the user as logged out.
    var user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      try {
        final event = await Supabase.instance.client.auth.onAuthStateChange
            .where((s) =>
                s.event == AuthChangeEvent.initialSession ||
                s.event == AuthChangeEvent.signedIn ||
                s.event == AuthChangeEvent.signedOut)
            .first
            .timeout(const Duration(seconds: 2));
        user = event.session?.user;
      } catch (_) {}
    }
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasLocale = prefs.containsKey('app_locale');
    if (!mounted) return;

    if (!hasLocale) {
      context.go('/language');
      return;
    }

    // PKCE OAuth callback: if the code param is still present, the exchange
    // may still be completing — wait a bit longer.
    if (user == null && Uri.base.queryParameters.containsKey('code')) {
      try {
        final event = await Supabase.instance.client.auth.onAuthStateChange
            .where((s) =>
                s.event == AuthChangeEvent.signedIn ||
                s.event == AuthChangeEvent.initialSession)
            .first
            .timeout(const Duration(seconds: 4));
        user = event.session?.user;
      } catch (_) {}
      if (!mounted) return;
    }

    if (user == null) {
      context.go('/home');
      return;
    }

    // Check if the user has completed onboarding (has a DB profile)
    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      context.go(profile == null ? '/onboarding' : '/home');
    } catch (_) {
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}
