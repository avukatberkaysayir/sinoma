import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';

enum AppSection { video, dictionary, social, games }

extension AppSectionX on AppSection {
  String localizedLabel(AppL10n l10n) => switch (this) {
    AppSection.video       => l10n.videoTab,
    AppSection.dictionary  => l10n.dictionaryTab,
    AppSection.social      => l10n.socialTab,
    AppSection.games       => l10n.gamesTab,
  };

  IconData get icon => switch (this) {
    AppSection.video       => Icons.play_circle_outline,
    AppSection.dictionary  => Icons.menu_book_outlined,
    AppSection.social      => Icons.group_outlined,
    AppSection.games       => Icons.sports_esports_outlined,
  };

  String get route => switch (this) {
    AppSection.video       => '/home',
    AppSection.dictionary  => '/dictionary/search',
    AppSection.social      => '/social',
    AppSection.games       => '/games',
  };
}

// Hover-based slide-out sidebar. Place inside a Stack positioned to fill the
// parent, then add this as the last child so it renders above content.
class SectionSidebarOverlay extends ConsumerStatefulWidget {
  final AppSection current;
  const SectionSidebarOverlay({super.key, required this.current});

  @override
  ConsumerState<SectionSidebarOverlay> createState() =>
      _SectionSidebarOverlayState();
}

class _SectionSidebarOverlayState
    extends ConsumerState<SectionSidebarOverlay> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.fromCode(ref.watch(localeProvider).languageCode);
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: _hovered ? 200 : 48,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: _hovered ? 0.82 : 0.35),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppSection.values.map((section) {
              final isCurrent = section == widget.current;
              return _SidebarItem(
                section: section,
                label: section.localizedLabel(l10n),
                isCurrent: isCurrent,
                onTap: isCurrent ? null : () => context.go(section.route),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final AppSection section;
  final String label;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.section,
    required this.label,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCurrent ? AppColors.primary : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 60,
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          border: isCurrent
              ? const Border(
                  left: BorderSide(color: AppColors.primary, width: 3))
              : null,
        ),
        child: Row(
          children: [
            Icon(section.icon, color: color, size: 24),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight:
                      isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.clip,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
