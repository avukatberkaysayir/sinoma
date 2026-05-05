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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0; // 0=Feed, 1=Games, 2=Community

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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Mandarin Academy'),
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
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _VideoFeedTab(),
          _GamesTab(),
          _SocialTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: AppColors.surfaceVariant,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: 'Games',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}

// ── Category Filter Bar ───────────────────────────────────────────────────────

// All categories + "All" sentinel.
const _allCategories = <QuizCategory?>[
  null, // "All"
  QuizCategory.conversation,
  QuizCategory.vocabulary,
  QuizCategory.grammar,
  QuizCategory.listening,
  QuizCategory.culture,
  QuizCategory.characters,
];

class _CategoryFilterBar extends ConsumerWidget {
  const _CategoryFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _allCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _allCategories[i];
          final isSelected = selected == (cat?.name);
          final label = cat == null ? 'All' : '${cat.emoji} ${cat.displayName}';

          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) {
              ref.read(selectedCategoryProvider.notifier).state =
                  cat?.name;
              ref.invalidate(videoFeedProvider);
            },
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.onSurfaceMuted,
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: AppColors.surfaceVariant,
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.surfaceVariant,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          );
        },
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

    return Column(
      children: [
        const SizedBox(height: 8),
        const _CategoryFilterBar(),
        const SizedBox(height: 8),
        Expanded(
          child: feedAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.wrongAnswer, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load videos\n$e',
                    style:
                        const TextStyle(color: AppColors.onSurface),
                    textAlign: TextAlign.center,
                  ),
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
                          color: AppColors.primary
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        selectedCategory != null
                            ? 'No videos in this category yet.'
                            : 'No videos available at your level.',
                        style: const TextStyle(
                            color: AppColors.onSurfaceMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // Group by quiz category when showing all.
              if (selectedCategory == null) {
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

// ── Grouped feed (All categories) ────────────────────────────────────────────

class _GroupedFeed extends StatelessWidget {
  final List<VideoSegmentModel> segments;
  const _GroupedFeed({required this.segments});

  @override
  Widget build(BuildContext context) {
    // Group segments by quiz category, preserving category order.
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
              Text(cat.emoji,
                  style: const TextStyle(fontSize: 18)),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${list.length}',
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12),
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
              itemBuilder: (_, i) => _VideoCard(segment: list[i], feed: segments),
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

// ── Flat feed (single category selected) ─────────────────────────────────────

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
            .read(feedProvider.notifier)
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
            // Thumbnail
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
                  // Play overlay
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
                  // Duration badge
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
                  // HSK badge
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
            // Info row
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
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
            subtitle:
                'Real-time 1v1 quiz battles across 6 categories',
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
                        style:
                            TextStyle(color: AppColors.onSurfaceMuted),
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
                      color:
                          AppColors.primary.withValues(alpha: 0.35)),
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
