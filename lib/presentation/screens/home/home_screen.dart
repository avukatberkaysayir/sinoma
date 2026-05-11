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
    final hskLevel   = ref.watch(currentHskLevelProvider);
    final isAdmin    = ref.watch(isAdminProvider);
    final isGuest    = ref.watch(isGuestProvider);
    final filterOpen = ref.watch(filterPanelOpenProvider);

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
          body: Stack(
            children: [
              const _VideoFeedTab(),

              // Section sidebar (below scrim and filter panel)
              const SectionSidebarOverlay(current: AppSection.video),

              // Scrim behind filter panel
              IgnorePointer(
                ignoring: !filterOpen,
                child: AnimatedOpacity(
                  opacity: filterOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(filterPanelOpenProvider.notifier).state = false,
                    child: Container(color: Colors.black54),
                  ),
                ),
              ),

              // Sliding filter panel (on top of sidebar and scrim)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: filterOpen ? 0 : -320,
                top: 0,
                bottom: 0,
                width: 300,
                child: const _FilterPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Filter Panel (slides in from left within body) ────────────────────────────

class _FilterPanel extends ConsumerStatefulWidget {
  const _FilterPanel();

  @override
  ConsumerState<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends ConsumerState<_FilterPanel> {
  void _close() =>
      ref.read(filterPanelOpenProvider.notifier).state = false;

  void _selectCat(String? value) {
    ref.read(selectedCategoryProvider.notifier).state = value;
    ref.invalidate(videoFeedProvider);
  }

  void _selectLen(String? value) {
    ref.read(selectedLengthProvider.notifier).state = value;
    ref.invalidate(videoFeedProvider);
  }

  void _resetAll() {
    ref.read(selectedCategoryProvider.notifier).state = null;
    ref.read(selectedLengthProvider.notifier).state = null;
    ref.invalidate(videoFeedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = ref.watch(selectedCategoryProvider);
    final selectedLen = ref.watch(selectedLengthProvider);
    final hasFilters = selectedCat != null || selectedLen != null;

    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.tune, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Filtreler',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasFilters)
                  TextButton(
                    onPressed: _resetAll,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Temizle'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.onSurfaceMuted,
                  onPressed: _close,
                ),
              ],
            ),
          ),
            const Divider(color: AppColors.surfaceVariant, height: 1),

            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Tüm videolar ─────────────────────────────────────
                    _FilterOption(
                      emoji: '✦',
                      label: '全部  Tüm Videolar',
                      isSelected: selectedCat == null && selectedLen == null,
                      onTap: _resetAll,
                    ),
                    const _SectionHeader(
                      icon: Icons.school_outlined,
                      label: '文法  GRAMER SEVİYELERİ',
                    ),

                    // ── HSK 1–5 accordion ────────────────────────────────
                    ..._hskGroups.map((group) {
                      final hasActive =
                          group.cats.any((c) => c.name == selectedCat);
                      final hskColor = AppColors.forHskLevel(group.level);
                      return ExpansionTile(
                        initiallyExpanded: hasActive,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: hasActive
                                ? hskColor.withValues(alpha: 0.2)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasActive ? hskColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${group.level}',
                              style: TextStyle(
                                color: hasActive ? hskColor : AppColors.onSurfaceMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'HSK ${group.level}',
                          style: TextStyle(
                            color: hasActive ? hskColor : AppColors.onSurface,
                            fontSize: 15,
                            fontWeight: hasActive ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          _hskSublabel(group.level),
                          style: const TextStyle(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 11,
                          ),
                        ),
                        trailing: hasActive
                            ? Icon(Icons.circle, size: 8, color: hskColor)
                            : null,
                        children: group.cats.map((cat) => _FilterOption(
                          emoji: cat.emoji,
                          label: cat.displayName,
                          isSelected: selectedCat == cat.name,
                          onTap: () => _selectCat(cat.name),
                          indent: 60,
                        )).toList(),
                      );
                    }),

                    // ── Cümle uzunluğu ────────────────────────────────────
                    const Divider(color: AppColors.surfaceVariant, height: 32),
                    const _SectionHeader(
                      icon: Icons.text_fields_outlined,
                      label: '字数  CÜMLE UZUNLUĞU',
                    ),
                    _FilterOption(
                      emoji: '↔',
                      label: '全部  Tümü',
                      isSelected: selectedLen == null,
                      onTap: () => _selectLen(null),
                    ),
                    ..._allLengths.skip(1).map((len) => _FilterOption(
                          emoji: '─',
                          label: len!,
                          isSelected: selectedLen == len,
                          onTap: () => _selectLen(len),
                        )),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }

  String _hskSublabel(int level) => switch (level) {
    1 => 'Başlangıç',
    2 => 'Temel',
    3 => 'Orta',
    4 => 'Orta-İleri',
    5 => 'İleri',
    _ => '',
  };
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double indent;

  const _FilterOption({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.indent = 20,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            EdgeInsets.only(left: indent, right: 20, top: 11, bottom: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.onSurface,
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Video Feed ───────────────────────────────────────────────────────────

class _VideoFeedTab extends ConsumerWidget {
  const _VideoFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(videoFeedProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedLength = ref.watch(selectedLengthProvider);
    final activeFilters =
        (selectedCategory != null ? 1 : 0) + (selectedLength != null ? 1 : 0);

    return Column(
      children: [
        // ── Filter bar (below tab bar) ──────────────────────────────────────
        InkWell(
            onTap: () => ref.read(filterPanelOpenProvider.notifier).state = true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surfaceVariant,
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 18,
                    color: activeFilters > 0
                        ? AppColors.primary
                        : AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    activeFilters > 0
                        ? 'Filtreler ($activeFilters aktif)'
                        : 'Filtrele',
                    style: TextStyle(
                      color: activeFilters > 0
                          ? AppColors.primary
                          : AppColors.onSurfaceMuted,
                      fontSize: 13,
                      fontWeight: activeFilters > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (selectedCategory != null) ...[
                    const SizedBox(width: 8),
                    _ActiveFilterChip(label: selectedCategory),
                  ],
                  if (selectedLength != null) ...[
                    const SizedBox(width: 6),
                    _ActiveFilterChip(label: selectedLength),
                  ],
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.onSurfaceMuted),
                ],
              ),
            ),
          ),

        // ── Feed content ────────────────────────────────────────────────────
        Expanded(
          child: feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.wrongAnswer, size: 40),
            const SizedBox(height: 12),
            Text(
              'Failed to load videos\n$e',
              style: const TextStyle(color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(videoFeedProvider),
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.primary),
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
                    color: AppColors.primary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(
                  selectedCategory != null || selectedLength != null
                      ? 'No videos match the selected filters.'
                      : 'No videos available at your level.',
                  style: const TextStyle(color: AppColors.onSurfaceMuted),
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
        ),
      ],
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  const _ActiveFilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500),
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

