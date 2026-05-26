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
    _route();
  }

  Future<void> _route() async {
    // PKCE OAuth callback: Supabase.initialize() exchanges the code before main()
    // finishes, but give a short buffer for session propagation.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasLocale = prefs.containsKey('app_locale');
    if (!mounted) return;

    if (!hasLocale) {
      context.go('/language');
      return;
    }

    // If the URL still has a PKCE code param, the exchange may still be
    // in progress — wait for the auth state to settle (up to 4 s).
    var user = Supabase.instance.client.auth.currentUser;
    if (user == null && Uri.base.queryParameters.containsKey('code')) {
      try {
        final event = await Supabase.instance.client.auth.onAuthStateChange
            .where((s) => s.event == AuthChangeEvent.signedIn ||
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
    final profile = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    if (profile == null) {
      context.go('/onboarding');
    } else {
      context.go('/home');
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
