import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Give Firebase Auth time to restore session from IndexedDB
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasLocale = prefs.containsKey('app_locale');

    if (!mounted) return;

    if (!hasLocale) {
      context.go('/language');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/onboarding');
      return;
    }

    context.go('/hub');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
