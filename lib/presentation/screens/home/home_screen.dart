import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/video_provider.dart';
import '../../widgets/common/section_sidebar.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: _VideoFeedTab(),
    );
  }
}

// ── Video Feed Tab ────────────────────────────────────────────────────────────

class _VideoFeedTab extends ConsumerStatefulWidget {
  const _VideoFeedTab();

  @override
  ConsumerState<_VideoFeedTab> createState() => _VideoFeedTabState();
}

class _VideoFeedTabState extends ConsumerState<_VideoFeedTab> {
  bool _panelOpen = false;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final q = _searchCtrl.text.trim();
      ref.read(selectedSearchProvider.notifier).state = q.isEmpty ? null : q;
    });
  }

  void _togglePanel() => setState(() => _panelOpen = !_panelOpen);
  void _closePanel()  => setState(() => _panelOpen = false);

  void _resetAll() {
    ref.read(selectedCategoryProvider.notifier).state  = null;
    ref.read(selectedLengthProvider.notifier).state    = null;
    ref.read(selectedHskFilterProvider.notifier).state = null;
    ref.read(selectedSearchProvider.notifier).state    = null;
    _searchCtrl.clear();
    ref.invalidate(videoFeedProvider);
    setState(() => _panelOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync        = ref.watch(filteredVideoFeedProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedLength   = ref.watch(selectedLengthProvider);
    final hskFilter        = ref.watch(selectedHskFilterProvider);
    final search           = ref.watch(selectedSearchProvider);

    return Column(
      children: [
        _FilterHeader(
          panelOpen: _panelOpen,
          onToggle: _togglePanel,
          onReset: _resetAll,
          searchCtrl: _searchCtrl,
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
                    final l10n = AppL10n.fromCode(
                        ref.watch(localeProvider).languageCode);
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
                            selectedCategory != null ||
                                    selectedLength != null ||
                                    hskFilter != null ||
                                    search != null
                                ? l10n.noVideosFilter
                                : l10n.noVideosLevel,
                            style: const TextStyle(
                                color: AppColors.onSurfaceMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  final hasFilter = selectedCategory != null ||
                      selectedLength != null ||
                      hskFilter != null ||
                      search != null;
                  return hasFilter
                      ? _FlatFeed(segments: segments)
                      : _GroupedFeed(segments: segments);
                },
              ),
              const SectionSidebarOverlay(current: AppSection.video),
              if (_panelOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closePanel,
                  ),
                ),
              if (_panelOpen) _MegaPanel(onClose: _closePanel),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Filter header ─────────────────────────────────────────────────────────────

class _FilterHeader extends ConsumerWidget {
  final bool panelOpen;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final TextEditingController searchCtrl;

  const _FilterHeader({
    required this.panelOpen,
    required this.onToggle,
    required this.onReset,
    required this.searchCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hskFilter = ref.watch(selectedHskFilterProvider);
    final category  = ref.watch(selectedCategoryProvider);
    final length    = ref.watch(selectedLengthProvider);
    final search    = ref.watch(selectedSearchProvider);
    final user      = ref.watch(currentUserProvider).valueOrNull;
    final l10n      = AppL10n.fromCode(ref.watch(localeProvider).languageCode);

    final hasFilter =
        hskFilter != null || category != null || length != null || search != null;

    final label = hasFilter
        ? [
            if (hskFilter != null) 'HSK $hskFilter',
            if (category != null)
              QuizCategory.values
                  .firstWhere(
                    (c) => c.name == category,
                    orElse: () => QuizCategory.general,
                  )
                  .displayName,
            if (length != null) length,
            if (search != null && search.isNotEmpty) '🔍 $search',
          ].join(' · ')
        : l10n.filterAll;

    return Container(
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ── Filter toggle ────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: hasFilter
                              ? AppColors.primary
                              : AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        hasFilter ? l10n.filterActive : l10n.filterLabel,
                        style: const TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    panelOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.onSurfaceMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close,
                    color: AppColors.onSurfaceMuted, size: 16),
              ),
            ),
          ],
          const Spacer(),
          // ── Search field ─────────────────────────────────────────────────
          SizedBox(
            width: 190,
            height: 34,
            child: TextField(
              controller: searchCtrl,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                hintStyle:
                    const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
                filled: true,
                fillColor: AppColors.surface,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary)),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.onSurfaceMuted, size: 16),
                suffixIcon: search != null && search.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          searchCtrl.clear();
                          ref.read(selectedSearchProvider.notifier).state = null;
                        },
                        child: const Icon(Icons.close,
                            color: AppColors.onSurfaceMuted, size: 14),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // ── Stats ────────────────────────────────────────────────────────
          if (user != null) ...[
            _StatChip(
              icon: Icons.play_circle_outline,
              value: '${user.stats.videosWatched}',
              label: l10n.statsWatched,
            ),
            const SizedBox(width: 16),
            _StatChip(
              icon: Icons.emoji_events_outlined,
              value: _fmt(user.stats.totalScore),
              label: l10n.statsPoints,
            ),
            const SizedBox(width: 16),
            _StatChip(
              icon: Icons.local_fire_department,
              value: '${user.stats.currentStreak}',
              label: l10n.statsDays,
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.onSurfaceMuted),
            const SizedBox(width: 3),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ── Mega panel — 5 columns, click-based ──────────────────────────────────────

class _MegaPanel extends ConsumerWidget {
  final VoidCallback onClose;
  const _MegaPanel({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hskFilter = ref.watch(selectedHskFilterProvider);
    final category  = ref.watch(selectedCategoryProvider);
    final length    = ref.watch(selectedLengthProvider);
    final l10n      = AppL10n.fromCode(ref.watch(localeProvider).languageCode);

    void setHsk(int? level) {
      ref.read(selectedHskFilterProvider.notifier).state = level;
      ref.invalidate(videoFeedProvider);
      onClose();
    }

    void setCategory(String? cat) {
      ref.read(selectedCategoryProvider.notifier).state = cat;
      ref.invalidate(videoFeedProvider);
      onClose();
    }

    void setLength(String? len) {
      ref.read(selectedLengthProvider.notifier).state = len;
      ref.invalidate(videoFeedProvider);
      onClose();
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 12,
        color: AppColors.surfaceVariant,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ① Life
                _PanelColumn(
                  title: l10n.lifeSection,
                  children: [
                    _PanelItem(
                      label: l10n.dailyLife,
                      selected: hskFilter == null &&
                          category == null &&
                          length == null,
                      onTap: onClose,
                    ),
                  ],
                ),
                const _ColumnDivider(),
                // ② Level
                _PanelColumn(
                  title: l10n.levelSection,
                  children: [
                    for (int lvl = 1; lvl <= 6; lvl++)
                      _PanelItem(
                        label: l10n.hskSublabel(lvl),
                        selected: hskFilter == lvl,
                        onTap: () => setHsk(hskFilter == lvl ? null : lvl),
                      ),
                  ],
                ),
                const _ColumnDivider(),
                // ③ HSK
                _PanelColumn(
                  title: 'HSK',
                  children: [
                    for (int i = 1; i <= 6; i++)
                      _PanelItem(
                        label: 'HSK $i',
                        selected: hskFilter == i,
                        color: AppColors.forHskLevel(i),
                        onTap: () => setHsk(hskFilter == i ? null : i),
                      ),
                  ],
                ),
                const _ColumnDivider(),
                // ④ Grammar
                _PanelColumn(
                  title: l10n.grammarSection,
                  children: [
                    for (final cat in QuizCategory.values)
                      _PanelItem(
                        label: '${cat.emoji}  ${cat.displayName}',
                        selected: category == cat.name,
                        onTap: () => setCategory(
                          category == cat.name ? null : cat.name,
                        ),
                      ),
                  ],
                ),
                const _ColumnDivider(),
                // ⑤ SinoRhythm
                _PanelColumn(
                  title: 'SinoRhythm',
                  children: [
                    for (final len in [
                      '1-5字',
                      '6-10字',
                      '11-15字',
                      '16-20字',
                      '21字+',
                    ])
                      _PanelItem(
                        label: len,
                        selected: length == len,
                        onTap: () => setLength(length == len ? null : len),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PanelColumn({required this.title, required this.children});

  static const double _listHeight = 232.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _listHeight,
            child: ListView(
              padding: EdgeInsets.zero,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnDivider extends StatelessWidget {
  const _ColumnDivider();

  static const double _height = 258.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: _height,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.surface,
    );
  }
}

class _PanelItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _PanelItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: selected
                  ? Icon(Icons.check, size: 13, color: c)
                  : null,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? c : AppColors.onSurfaceMuted,
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
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
                  Row(
                    children: [
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
                      if (segment.targetWords.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            segment.targetWords.take(3).join(' · '),
                            style: const TextStyle(
                              color: AppColors.onSurfaceMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
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
