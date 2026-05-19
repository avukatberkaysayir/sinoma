import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/common/section_sidebar.dart';

class GamesSectionScreen extends ConsumerWidget {
  const GamesSectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.fromCode(ref.watch(localeProvider).languageCode);
    return Stack(
      children: [
        Scaffold(
          body: ConstrainedPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(64, 24, 24, 24),
              children: [
                Text(
                  l10n.gamesTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.gamesSubtitle,
                  style: const TextStyle(color: AppColors.onSurfaceMuted),
                ),
                const SizedBox(height: 24),
                _GameCard(
                  icon: Icons.psychology,
                  title: 'Mandarin Duel',
                  subtitle: l10n.duelSubtitle,
                  color: const Color(0xFF6C63FF),
                  detail: l10n.duelDetail,
                  onTap: () => context.push('/games/duel'),
                ),
                const SizedBox(height: 16),
                _GameCard(
                  icon: Icons.auto_awesome_mosaic,
                  title: 'Hanzi Build',
                  subtitle: l10n.hanziBuildSubtitle,
                  color: const Color(0xFFFF6B6B),
                  detail: l10n.hanziBuildDetail,
                  onTap: () => context.push('/games/hanzi'),
                ),
              ],
            ),
          ),
        ),
        const SectionSidebarOverlay(current: AppSection.games),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
