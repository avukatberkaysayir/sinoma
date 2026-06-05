import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';

enum AppSection { video, dictionary, social, games }

// Sections surfaced in navigation. Social + Games are HIDDEN for now (no content
// yet — will revisit). Their routes/screens still exist, just not shown in nav.
const List<AppSection> visibleSections = [
  AppSection.video,
  AppSection.dictionary,
];

extension AppSectionX on AppSection {
  String localizedLabel(AppL10n l10n) => switch (this) {
    AppSection.video       => l10n.videoTab,
    AppSection.dictionary  => l10n.dictionaryTab,
    AppSection.social      => l10n.socialTab,
    AppSection.games       => l10n.gamesTab,
  };

  IconData get icon => switch (this) {
    AppSection.video       => Icons.school_outlined,
    AppSection.dictionary  => Icons.menu_book_outlined,
    AppSection.social      => Icons.group_outlined,
    AppSection.games       => Icons.sports_esports_outlined,
  };

  String get route => switch (this) {
    AppSection.video       => '/learn', // learning path is the primary screen
    AppSection.dictionary  => '/dictionary',
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
            children: visibleSections.map((section) {
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

// ── Left navigation rail (wide screens ≥ 900px) ──────────────────────────────

class SectionNavRail extends ConsumerWidget {
  final AppSection current;
  const SectionNavRail({super.key, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n   = AppL10n.fromCode(ref.watch(localeProvider).languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idx    = visibleSections.indexOf(current);

    return NavigationRail(
      selectedIndex: idx < 0 ? 0 : idx,
      onDestinationSelected: (i) {
        final section = visibleSections[i];
        if (section != current) context.go(section.route);
      },
      labelType: NavigationRailLabelType.all,
      backgroundColor: isDark ? AppColors.surfaceVariant : Colors.white,
      selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 22),
      unselectedIconTheme: IconThemeData(
        color: isDark ? Colors.white38 : Colors.black38,
        size: 22,
      ),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.black38,
        fontSize: 11,
      ),
      destinations: visibleSections.map((s) => NavigationRailDestination(
        icon: Icon(s.icon),
        label: Text(s.localizedLabel(l10n)),
      )).toList(),
    );
  }
}

// ── Horizontal section tab bar ────────────────────────────────────────────────

class SectionTabBar extends ConsumerWidget {
  final AppSection current;
  const SectionTabBar({super.key, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n   = AppL10n.fromCode(ref.watch(localeProvider).languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariant : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Row(
        children: visibleSections.map((section) {
          return _SectionTab(
            section: section,
            label: section.localizedLabel(l10n),
            isActive: section == current,
            isDark: isDark,
            onTap: section == current ? null : () => context.go(section.route),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionTab extends StatefulWidget {
  final AppSection section;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback? onTap;

  const _SectionTab({
    required this.section,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SectionTab> createState() => _SectionTabState();
}

class _SectionTabState extends State<_SectionTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const activeColor   = AppColors.primary;
    final inactiveColor = widget.isDark ? Colors.white54 : Colors.black45;
    final fg            = widget.isActive ? activeColor : inactiveColor;

    return MouseRegion(
      cursor: widget.isActive
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isActive ? activeColor : Colors.transparent,
                width: 2,
              ),
            ),
            color: _hovered && !widget.isActive
                ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04))
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.section.icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: widget.isActive
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
