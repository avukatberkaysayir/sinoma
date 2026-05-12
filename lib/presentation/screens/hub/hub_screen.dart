import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hskLevel = ref.watch(currentHskLevelProvider);
    final isAdmin  = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinoma'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Admin',
              onPressed: () => context.push('/admin'),
            ),
          GestureDetector(
            onTap: () => context.push('/hsk-test'),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.forHskLevel(hskLevel).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.forHskLevel(hskLevel).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'HSK $hskLevel',
                    style: TextStyle(
                      color: AppColors.forHskLevel(hskLevel),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.refresh, size: 13,
                      color: AppColors.forHskLevel(hskLevel)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Logo + level badge
            Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.language,
                      size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                const Text(
                  '普通话学院',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // 2×2 grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = (constraints.maxWidth - 16) / 2;
                    final cardSize = size.clamp(120.0, 240.0);
                    return Center(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          _HubCard(
                            size: cardSize,
                            icon: Icons.play_circle_outline,
                            label: 'Video',
                            color: AppColors.primary,
                            onTap: () => context.go('/home'),
                          ),
                          _HubCard(
                            size: cardSize,
                            icon: Icons.menu_book_outlined,
                            label: 'Sözlük',
                            color: const Color(0xFF2196F3),
                            onTap: () => context.go('/dictionary/search'),
                          ),
                          _HubCard(
                            size: cardSize,
                            icon: Icons.group_outlined,
                            label: 'Sosyal',
                            color: const Color(0xFF4CAF50),
                            onTap: () => context.go('/social'),
                          ),
                          _HubCard(
                            size: cardSize,
                            icon: Icons.sports_esports_outlined,
                            label: 'Oyun',
                            color: const Color(0xFF9C27B0),
                            onTap: () => context.go('/games'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatefulWidget {
  final double size;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.size,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.18)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hovered ? widget.color : Colors.transparent,
              width: 2,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 48, color: widget.color),
              const SizedBox(height: 14),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _hovered ? widget.color : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
