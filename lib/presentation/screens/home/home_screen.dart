import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/video_provider.dart';

// ── Grammar group data ────────────────────────────────────────────────────────

class _GrammarGroup {
  final String label;
  final String sublabel;
  final List<QuizCategory> cats;
  const _GrammarGroup(this.label, this.sublabel, this.cats);
}

const _grammarGroups = <_GrammarGroup>[
  _GrammarGroup('结构', 'Structural', [
    QuizCategory.baConstruct,
    QuizCategory.beiPassive,
    QuizCategory.shiDeEmphasis,
  ]),
  _GrammarGroup('条件/转折', 'Condition · Contrast', [
    QuizCategory.conditional,
    QuizCategory.contrast,
    QuizCategory.causeEffect,
  ]),
  _GrammarGroup('体貌', 'Aspect Markers', [
    QuizCategory.guoExperience,
    QuizCategory.leCompletion,
  ]),
  _GrammarGroup('情态', 'Modal Verbs', [
    QuizCategory.huiNengKeyi,
    QuizCategory.yingDeiYao,
    QuizCategory.xiangDasuan,
  ]),
  _GrammarGroup('句型', 'Sentence Types', [
    QuizCategory.questions,
    QuizCategory.negation,
    QuizCategory.biComparison,
  ]),
  _GrammarGroup('时间/地点', 'Time · Place', [
    QuizCategory.timeWords,
    QuizCategory.locationWords,
  ]),
  _GrammarGroup('一般', 'General', [QuizCategory.general]),
];

const _allLengths = <String?>[null, '1-5字', '6-10字', '11-15字', '16-20字', '21字+'];

// ── Home Screen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adServiceProvider);
      ref.read(fcmInitProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hskLevel = ref.watch(currentHskLevelProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedLength = ref.watch(selectedLengthProvider);
    final activeFilters =
        (selectedCategory != null ? 1 : 0) + (selectedLength != null ? 1 : 0);

    return Scaffold(
      backgroundColor: AppColors.surface,
      drawer: const _FilterDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => Badge(
            isLabelVisible: activeFilters > 0,
            label: Text('$activeFilters'),
            child: IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Filters',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ),
        title: const Text('Sinoma'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                'HSK $hskLevel',
                style: TextStyle(
                  color: AppColors.forHskLevel(hskLevel),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.manage_search),
            tooltip: 'Dictionary',
            onPressed: () => context.push('/dictionary/search'),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Admin Panel',
            onPressed: () => context.push('/admin'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Learn'),
            Tab(text: 'Games'),
            Tab(text: 'Community'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _VideoFeedTab(),
          _GamesTab(),
          _SocialTab(),
        ],
      ),
    );
  }
}

// ── Filter Drawer ─────────────────────────────────────────────────────────────

class _FilterDrawer extends ConsumerStatefulWidget {
  const _FilterDrawer();

  @override
  ConsumerState<_FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends ConsumerState<_FilterDrawer> {
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

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Filters',
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
                      child: const Text('Reset All'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.onSurfaceMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceVariant, height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(
                      icon: Icons.auto_awesome_outlined,
                      label: '文法  GRAMMAR PATTERNS',
                    ),
                    _FilterOption(
                      emoji: '✦',
                      label: '全部  All',
                      isSelected: selectedCat == null,
                      onTap: () => _selectCat(null),
                    ),
                    // Grammar group expansion tiles
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: Column(
                        children: List.generate(_grammarGroups.length, (i) {
                          final group = _grammarGroups[i];
                          final hasActive =
                              group.cats.any((c) => c.name == selectedCat);
                          return ExpansionTile(
                            initiallyExpanded: hasActive,
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            childrenPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: hasActive
                                    ? AppColors.primary
                                    : AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              group.label,
                              style: TextStyle(
                                color: hasActive
                                    ? AppColors.primary
                                    : AppColors.onSurface,
                                fontSize: 15,
                                fontWeight: hasActive
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              group.sublabel,
                              style: const TextStyle(
                                color: AppColors.onSurfaceMuted,
                                fontSize: 11,
                              ),
                            ),
                            children: group.cats
                                .map((cat) => _FilterOption(
                                      emoji: cat.emoji,
                                      label: cat.displayName,
                                      isSelected: selectedCat == cat.name,
                                      onTap: () => _selectCat(cat.name),
                                      indent: 48,
                                    ))
                                .toList(),
                          );
                        }),
                      ),
                    ),
                    const Divider(color: AppColors.surfaceVariant, height: 32),
                    const _SectionHeader(
                      icon: Icons.text_fields_outlined,
                      label: '字数  SENTENCE LENGTH',
                    ),
                    _FilterOption(
                      emoji: '↔',
                      label: '全部  All',
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
      ),
    );
  }
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

    return feedAsync.when(
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
            .read(videoPlaybackProvider.notifier)
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

// ── Tab: Games ────────────────────────────────────────────────────────────────

class _GamesTab extends StatelessWidget {
  const _GamesTab();

  @override
  Widget build(BuildContext context) {
    return ConstrainedPage(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 12),
          const Text(
            'Games',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Challenge yourself and compete with friends',
            style: TextStyle(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 24),
          _GameCard(
            icon: Icons.psychology,
            title: 'Mandarin Duel',
            subtitle: 'Real-time 1v1 quiz battles across 6 categories',
            color: const Color(0xFF6C63FF),
            detail: '10 rounds • 10s timer • 3 lives',
            onTap: () => context.push('/games/duel'),
          ),
          const SizedBox(height: 16),
          _GameCard(
            icon: Icons.auto_awesome_mosaic,
            title: 'Hanzi Build',
            subtitle: 'Reconstruct characters from radicals',
            color: const Color(0xFFFF6B6B),
            detail: '10 words • 20s timer • hints available',
            onTap: () => context.push('/games/hanzi'),
          ),
        ],
      ),
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
                      color: AppColors.onSurface,
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

// ── Tab: Social ───────────────────────────────────────────────────────────────

class _SocialTab extends StatelessWidget {
  const _SocialTab();

  @override
  Widget build(BuildContext context) {
    return ConstrainedPage(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Posts • Leaderboard • Friends • Challenges',
                        style: TextStyle(color: AppColors.onSurfaceMuted),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => context.push('/social'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.surfaceVariant, height: 1),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group,
                      size: 64,
                      color: AppColors.primary.withValues(alpha: 0.35)),
                  const SizedBox(height: 16),
                  const Text(
                    'Connect with other Mandarin learners.\nSee who is learning the same level.',
                    style: TextStyle(color: AppColors.onSurfaceMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/social'),
                    icon: const Icon(Icons.leaderboard,
                        color: AppColors.primary),
                    label: const Text('View Leaderboard',
                        style: TextStyle(color: AppColors.primary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
