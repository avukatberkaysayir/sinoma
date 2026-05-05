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
  int _tab = 0; // 0=Feed 1=Games 2=Social

  @override
  void initState() {
    super.initState();
    // Warm up AdService and FCM once user is signed in.
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

// ── Tab: Video Feed ──────────────────────────────────────────────────────────

class _VideoFeedTab extends ConsumerWidget {
  const _VideoFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(videoFeedProvider);

    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Failed to load videos\n$e',
          style: const TextStyle(color: AppColors.onSurface),
          textAlign: TextAlign.center,
        ),
      ),
      data: (segments) {
        if (segments.isEmpty) {
          return const Center(
            child: Text(
              'No videos available at your level.',
              style: TextStyle(color: AppColors.onSurfaceMuted),
            ),
          );
        }

        final columns = ResponsiveLayout.feedColumnCount(context);
        final padding = ResponsiveLayout.pagePadding(context);

        return ConstrainedPage(
          child: columns == 1
              ? ListView.separated(
                  padding: EdgeInsets.all(padding),
                  itemCount: segments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _VideoCard(
                    segment: segments[i],
                    onTap: () => context.push('/video/${segments[i].videoId}'),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.all(padding),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3.2,
                  ),
                  itemCount: segments.length,
                  itemBuilder: (context, i) => _VideoCard(
                    segment: segments[i],
                    onTap: () => context.push('/video/${segments[i].videoId}'),
                  ),
                ),
        );
      },
    );
  }
}

// ── Tab: Games ───────────────────────────────────────────────────────────────

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
            subtitle: 'Real-time 1v1 quiz battles',
            color: const Color(0xFF6C63FF),
            onTap: () => context.push('/games/duel'),
          ),
          const SizedBox(height: 16),
          _GameCard(
            icon: Icons.auto_awesome_mosaic,
            title: 'Hanzi Build',
            subtitle: 'Reconstruct characters from radicals',
            color: const Color(0xFFFF6B6B),
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
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
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
                      color: AppColors.onSurfaceMuted,
                      fontSize: 13,
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

// ── Tab: Social (inline preview) ─────────────────────────────────────────────

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
                        'Friends, leaderboard & challenges',
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
                  Icon(Icons.group, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'Tap Open to see your feed,\nleaderboard and challenges.',
                    style: TextStyle(color: AppColors.onSurfaceMuted),
                    textAlign: TextAlign.center,
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

class _VideoCard extends StatelessWidget {
  final VideoSegmentModel segment;
  final VoidCallback onTap;

  const _VideoCard({required this.segment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.forHskLevel(segment.hskLevel),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    segment.transcription,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    segment.pinyin,
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${segment.durationSeconds.toInt()}s',
              style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
