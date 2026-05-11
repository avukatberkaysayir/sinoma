import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // ── Logo / app name ─────────────────────────────────────────
              const Text(
                '語',
                style: TextStyle(
                  fontSize: 72,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sinoma',
                style: TextStyle(
                  fontSize: 32,
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),

              // ── Prompt ───────────────────────────────────────────────────
              Text(
                _selected == null
                    ? 'Dil Seçin / Choose Language'
                    : (_selected == 'tr' ? 'Dil Seçin' : 'Choose Language'),
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // ── Language cards ───────────────────────────────────────────
              _LanguageCard(
                flag: '🇹🇷',
                name: 'Türkçe',
                subtitle: 'Turkish',
                code: 'tr',
                selected: _selected == 'tr',
                onTap: () => setState(() => _selected = 'tr'),
              ),
              const SizedBox(height: 16),
              _LanguageCard(
                flag: '🇬🇧',
                name: 'English',
                subtitle: 'İngilizce',
                code: 'en',
                selected: _selected == 'en',
                onTap: () => setState(() => _selected = 'en'),
              ),

              const Spacer(),

              // ── Continue button ──────────────────────────────────────────
              AnimatedOpacity(
                opacity: _selected != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected == null ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _selected == 'tr' ? 'Devam Et' : 'Continue',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                _selected == 'tr'
                    ? 'İstediğin zaman ayarlardan değiştirebilirsin'
                    : _selected == 'en'
                        ? 'You can change this anytime in settings'
                        : 'Settings • Ayarlar',
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    await ref
        .read(localeProvider.notifier)
        .setLocale(Locale(_selected!));
    if (mounted) context.go('/onboarding');
  }
}

class _LanguageCard extends StatelessWidget {
  final String flag;
  final String name;
  final String subtitle;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Text(flag, style: const TextStyle(fontSize: 32)),
        title: Text(
          name,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 13,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 24)
            : const Icon(Icons.circle_outlined,
                color: AppColors.onSurfaceMuted, size: 24),
      ),
    );
  }
}
