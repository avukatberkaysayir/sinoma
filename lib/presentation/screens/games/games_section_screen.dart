import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../widgets/common/section_sidebar.dart';

class GamesSectionScreen extends StatelessWidget {
  const GamesSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: ConstrainedPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(64, 24, 24, 24),
              children: [
                const Text(
                  'Oyunlar',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kendini sına ve arkadaşlarınla yarış',
                  style: TextStyle(color: AppColors.onSurfaceMuted),
                ),
                const SizedBox(height: 24),
                _GameCard(
                  icon: Icons.psychology,
                  title: 'Mandarin Duel',
                  subtitle: 'Gerçek zamanlı 1v1 soru yarışması — 6 kategori',
                  color: const Color(0xFF6C63FF),
                  detail: '10 tur • 10s süre • 3 can',
                  onTap: () => context.push('/games/duel'),
                ),
                const SizedBox(height: 16),
                _GameCard(
                  icon: Icons.auto_awesome_mosaic,
                  title: 'Hanzi Build',
                  subtitle: 'Kökenlerden karakter yeniden oluştur',
                  color: const Color(0xFFFF6B6B),
                  detail: '10 kelime • 20s süre • ipuçları mevcut',
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
