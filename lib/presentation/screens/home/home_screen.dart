import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/video_provider.dart';
import '../../widgets/common/section_sidebar.dart';

// ── HSK-level grammar mapping ─────────────────────────────────────────────────

class _HskGroup {
  final int level;
  final List<QuizCategory> cats;
  const _HskGroup(this.level, this.cats);
}

const _hskGroups = <_HskGroup>[
  _HskGroup(1, [QuizCategory.questions, QuizCategory.negation, QuizCategory.general]),
  _HskGroup(2, [QuizCategory.timeWords, QuizCategory.locationWords, QuizCategory.leCompletion]),
  _HskGroup(3, [QuizCategory.guoExperience, QuizCategory.baConstruct, QuizCategory.biComparison]),
  _HskGroup(4, [QuizCategory.beiPassive, QuizCategory.conditional, QuizCategory.contrast]),
  _HskGroup(5, [QuizCategory.shiDeEmphasis, QuizCategory.causeEffect,
                QuizCategory.huiNengKeyi, QuizCategory.yingDeiYao, QuizCategory.xiangDasuan]),
];

const _allLengths = <String?>[null, '1-5字', '6-10字', '11-15字', '16-20字', '21字+'];

// ── Home Screen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adServiceProvider);
      ref.read(fcmInitProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hskLevel = ref.watch(currentHskLevelProvider);
    final isAdmin  = ref.watch(isAdminProvider);
    final isGuest  = ref.watch(isGuestProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Sinoma'),
            actions: [
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
                  child: Text(
                    'HSK $hskLevel',
                    style: TextStyle(
                      color: AppColors.forHskLevel(hskLevel),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.manage_search),
                tooltip: 'Dictionary',
                onPressed: () => context.push('/dictionary/search'),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  tooltip: 'Admin Panel',
                  onPressed: () => context.push('/admin'),
                ),
              if (isGuest)
                TextButton(
                  onPressed: () => context.push('/profile'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onSurfaceMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Misafir'),
                )
              else
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  tooltip: 'Profil',
                  onPressed: () => context.push('/profile'),
                ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          body: const _VideoFeedTab(),
        ),
      ],
    );
  }
}

// ── Top filter menu ───────────────────────────────────────────────────────────

enum _TopMenu { hsk1, hsk2, hsk3, hsk4, hsk5, length }

extension _TopMenuX on _TopMenu {
  int? get hskLevel => switch (this) {
        _TopMenu.hsk1   => 1,
        _TopMenu.hsk2   => 2,
        _TopMenu.hsk3   => 3,
        _TopMenu.hsk4   => 4,
        _TopMenu.hsk5   => 5,
        _TopMenu.length => null,
      };

  _HskGroup? get hskGroup {
    final lv = hskLevel;
    if (lv == null) return null;
    return _hskGroups.firstWhere((g) => g.level == lv);
  }

  String get label => switch (this) {
        _TopMenu.hsk1   => 'HSK 1',
        _TopMenu.hsk2   => 'HSK 2',
        _TopMenu.hsk3   => 'HSK 3',
        _TopMenu.hsk4   => 'HSK 4',
        _TopMenu.hsk5   => 'HSK 5',
        _TopMenu.length => 'Uzunluk',
      };

  bool hasActiveCategory(String? selected) {
    final group = hskGroup;
    if (group == null) return false;
    return group.cats.any((c) => c.name == selected);
  }
}

// ── Video Feed Tab ────────────────────────────────────────────────────────────

class _VideoFeedTab extends ConsumerStatefulWidget {
  const _VideoFeedTab();

  @override
  ConsumerState<_VideoFeedTab> createState() => _VideoFeedTabState();
}

class _VideoFeedTabState extends ConsumerState<_VideoFeedTab> {
  _TopMenu? _openMenu;

  void _toggleMenu(_TopMenu menu) =>
      setState(() => _openMenu = _openMenu == menu ? null : menu);

  void _closeMenu() => setState(() => _openMenu = null);

  void _selectCategory(String? value) {
    ref.read(selectedCategoryProvider.notifier).state = value;
    ref.invalidate(videoFeedProvider);
    _closeMenu();
  }

  void _selectLength(String? value) {
    ref.read(selectedLengthProvider.notifier).state = value;
    ref.invalidate(videoFeedProvider);
    _closeMenu();
  }

  void _resetAll() {
    ref.read(selectedCategoryProvider.notifier).state = null;
    ref.read(selectedLengthProvider.notifier).state = null;
    ref.invalidate(videoFeedProvider);
    _closeMenu();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync        = ref.watch(videoFeedProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedLength   = ref.watch(selectedLengthProvider);

    return Column(
      children: [
        _TopFilterBar(
          openMenu: _openMenu,
          selectedCategory: selectedCategory,
          selectedLength: selectedLength,
          onMenuTap: _toggleMenu,
          onReset: _resetAll,
        ),
        Expanded(
          child: Stack(
            children: [
              feedAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.wrongAnswer, size: 40),
                      const SizedBox(height: 12),
                      Text('Failed to load videos\n$e',
                          style: const TextStyle(color: AppColors.onSurface),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(videoFeedProvider),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (segments) {
                  if (segments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.video_library_outlined,
                              size: 56,
                              color:
                                  AppColors.primary.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text(
                            selectedCategory != null || selectedLength != null
                                ? 'No videos match the selected filters.'
                                : 'No videos available at your level.',
                            style: const TextStyle(
                                color: AppColors.onSurfaceMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  if (selectedCategory == null && selectedLength == null) {
                    return _GroupedFeed(segments: segments);
                  }
                  return _FlatFeed(segments: segments);
                },
              ),
              // Section sidebar — vertically centered within feed area
              const SectionSidebarOverlay(current: AppSection.video),
              // Tap-outside dismisses the open dropdown
              if (_openMenu != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeMenu,
                  ),
                ),
              // Dropdown panel (overlays top of feed)
              if (_openMenu != null)
                _DropdownPanel(
                  menu: _openMenu!,
                  selectedCategory: selectedCategory,
                  selectedLength: selectedLength,
                  onSelectCategory: _selectCategory,
                  onSelectLength: _selectLength,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Top filter bar ────────────────────────────────────────────────────────────

class _TopFilterBar extends StatelessWidget {
  final _TopMenu? openMenu;
  final String? selectedCategory;
  final String? selectedLength;
  final void Function(_TopMenu) onMenuTap;
  final VoidCallback onReset;

  const _TopFilterBar({
    required this.openMenu,
    required this.selectedCategory,
    required this.selectedLength,
    required this.onMenuTap,
    required this.onReset,
  });

  bool get _hasFilters => selectedCategory != null || selectedLength != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _MenuButton(
              label: 'Tümü',
              isActive: !_hasFilters,
              isOpen: false,
              showArrow: false,
              onTap: onReset,
            ),
            const SizedBox(width: 8),
            for (final menu in _TopMenu.values) ...[
              if (menu == _TopMenu.length)
                _MenuButton(
                  label: 'Uzunluk',
                  isActive: selectedLength != null,
                  isOpen: openMenu == _TopMenu.length,
                  onTap: () => onMenuTap(_TopMenu.length),
                )
              else
                _MenuButton(
                  label: menu.label,
                  isActive: menu.hasActiveCategory(selectedCategory),
                  isOpen: openMenu == menu,
                  color: AppColors.forHskLevel(menu.hskLevel!),
                  onTap: () => onMenuTap(menu),
                ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isOpen;
  final bool showArrow;
  final Color? color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.isActive,
    required this.isOpen,
    this.showArrow = true,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final highlighted = isActive || isOpen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: highlighted ? c.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlighted ? c : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: highlighted ? c : AppColors.onSurfaceMuted,
                fontSize: 13,
                fontWeight:
                    highlighted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (showArrow) ...[
              const SizedBox(width: 4),
              Icon(
                isOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 14,
                color: highlighted ? c : AppColors.onSurfaceMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Dropdown panel ────────────────────────────────────────────────────────────

class _DropdownPanel extends StatelessWidget {
  final _TopMenu menu;
  final String? selectedCategory;
  final String? selectedLength;
  final void Function(String?) onSelectCategory;
  final void Function(String?) onSelectLength;

  const _DropdownPanel({
    required this.menu,
    required this.selectedCategory,
    required this.selectedLength,
    required this.onSelectCategory,
    required this.onSelectLength,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        color: AppColors.surfaceVariant,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: menu == _TopMenu.length
              ? _buildLengthOptions()
              : _buildCategoryOptions(),
        ),
      ),
    );
  }

  Widget _buildCategoryOptions() {
    final group    = menu.hskGroup!;
    final hskColor = AppColors.forHskLevel(group.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hskColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'HSK ${group.level}',
                style: TextStyle(
                    color: hskColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _sublabel(group.level),
              style: const TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: group.cats.map((cat) {
            final sel = selectedCategory == cat.name;
            return _Chip(
              emoji: cat.emoji,
              label: cat.displayName,
              isSelected: sel,
              color: hskColor,
              onTap: () => onSelectCategory(sel ? null : cat.name),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLengthOptions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _allLengths.skip(1).map((len) {
        final sel = selectedLength == len;
        return _Chip(
          emoji: '─',
          label: len!,
          isSelected: sel,
          color: AppColors.primary,
          onTap: () => onSelectLength(sel ? null : len),
        );
      }).toList(),
    );
  }

  String _sublabel(int level) => switch (level) {
        1 => 'Başlangıç',
        2 => 'Temel',
        3 => 'Orta',
        4 => 'Orta-İleri',
        5 => 'İleri',
        _ => '',
      };
}

class _Chip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? color
                : AppColors.onSurfaceMuted.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.onSurface,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Grouped feed (no filter active) ──────────────────────────────────────────

class _GroupedFeed extends StatelessWidget {
  final List<VideoSegmentModel> segments;
  const _GroupedFeed({required this.segments});

  @override
  Widget build(BuildContext context) {
    final grouped = <QuizCategory, List<VideoSegmentModel>>{};
    for (final s in segments) {
      grouped.putIfAbsent(s.quizCategory, () => []).add(s);
    }

    final columns = ResponsiveLayout.feedColumnCount(context);
    final padding = ResponsiveLayout.pagePadding(context);

    final sections = <Widget>[];
    for (final cat in QuizCategory.values) {
      final list = grouped[cat];
      if (list == null || list.isEmpty) continue;

      sections.add(
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 16, padding, 8),
          child: Row(
            children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                cat.displayName,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${list.length}',
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );

      if (columns == 1) {
        for (final seg in list) {
          sections.add(
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 0, padding, 10),
              child: _VideoCard(segment: seg, feed: segments),
            ),
          );
        }
      } else {
        sections.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) =>
                  _VideoCard(segment: list[i], feed: segments),
            ),
          ),
        );
      }
    }

    return ConstrainedPage(
      child: ListView(
        padding: EdgeInsets.only(bottom: padding),
        children: sections,
      ),
    );
  }
}

// ── Flat feed (filter active) ─────────────────────────────────────────────────

class _FlatFeed extends StatelessWidget {
  final List<VideoSegmentModel> segments;
  const _FlatFeed({required this.segments});

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveLayout.feedColumnCount(context);
    final padding = ResponsiveLayout.pagePadding(context);

    return ConstrainedPage(
      child: columns == 1
          ? ListView.separated(
              padding: EdgeInsets.all(padding),
              itemCount: segments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _VideoCard(segment: segments[i], feed: segments),
            )
          : GridView.builder(
              padding: EdgeInsets.all(padding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
              ),
              itemCount: segments.length,
              itemBuilder: (_, i) =>
                  _VideoCard(segment: segments[i], feed: segments),
            ),
    );
  }
}

// ── Video Card ────────────────────────────────────────────────────────────────

class _VideoCard extends ConsumerWidget {
  final VideoSegmentModel segment;
  final List<VideoSegmentModel> feed;

  const _VideoCard({required this.segment, required this.feed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbUrl = segment.isYouTube
        ? 'https://img.youtube.com/vi/${segment.youtubeId}/mqdefault.jpg'
        : null;

    return InkWell(
      onTap: () {
        final index = feed.indexOf(segment);
        ref
            .read(videoPlaylistProvider.notifier)
            .loadFeed(feed, index < 0 ? 0 : index);
        context.push('/play');
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbUrl != null)
                    CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF0F0F0F),
                        child: const Icon(Icons.play_circle_outline,
                            color: Colors.white38, size: 40),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF0F0F0F),
                        child: const Icon(Icons.play_circle_outline,
                            color: Colors.white38, size: 40),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF0F0F0F),
                      child: const Icon(Icons.play_circle_outline,
                          color: Colors.white38, size: 40),
                    ),
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 28),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${segment.durationSeconds.toInt()}s',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.forHskLevel(segment.hskLevel),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'HSK ${segment.hskLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.transcription,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    segment.pinyin,
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${segment.quizCategory.emoji} ${segment.quizCategory.displayName}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

