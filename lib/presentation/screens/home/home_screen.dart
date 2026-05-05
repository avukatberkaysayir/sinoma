import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/video_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Warm up AdService and initialize FCM token once user is signed in.
    ref.read(adServiceProvider);
    ref.read(fcmInitProvider);

    final feedAsync = ref.watch(videoFeedProvider);
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
      body: feedAsync.when(
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
