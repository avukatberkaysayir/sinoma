import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/video_provider.dart';
import 'inline_player_section.dart';

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
  String? _expandedGroup;
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

  void _toggleGroup(String id) =>
      setState(() => _expandedGroup = _expandedGroup == id ? null : id);

  void _resetAll() {
    ref.read(selectedCategoryProvider.notifier).state     = {};
    ref.read(selectedLengthProvider.notifier).state       = {};
    ref.read(selectedHskFilterProvider.notifier).state    = {};
    ref.read(selectedLifeCategoryProvider.notifier).state = {};
    ref.read(selectedSearchProvider.notifier).state       = null;
    _searchCtrl.clear();
    ref.invalidate(videoFeedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync        = ref.watch(filteredVideoFeedProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedLength   = ref.watch(selectedLengthProvider);
    final hskFilter        = ref.watch(selectedHskFilterProvider);
    final lifeCategories   = ref.watch(selectedLifeCategoryProvider);
    final search           = ref.watch(selectedSearchProvider);

    final feedWidget = feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
          final l10n =
              AppL10n.fromCode(ref.watch(localeProvider).languageCode);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.video_library_outlined,
                    size: 56,
                    color: AppColors.primary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(
                  selectedCategory.isNotEmpty ||
                          selectedLength.isNotEmpty ||
                          hskFilter.isNotEmpty ||
                          lifeCategories.isNotEmpty ||
                          search != null
                      ? l10n.noVideosFilter
                      : l10n.noVideosLevel,
                  style: const TextStyle(color: AppColors.onSurfaceMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return InlinePlayerSection(segments: segments);
      },
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: _FilterSidebar(
            expandedGroup: _expandedGroup,
            onGroupToggle: _toggleGroup,
            onReset: _resetAll,
            searchCtrl: _searchCtrl,
          ),
        ),
        Expanded(child: feedWidget),
      ],
    );
  }
}

// ── Filter sidebar (vertical left accordion, multi-select) ────────────────────

class _FilterSidebar extends ConsumerWidget {
  final String? expandedGroup;
  final void Function(String) onGroupToggle;
  final VoidCallback onReset;
  final TextEditingController searchCtrl;

  const _FilterSidebar({
    required this.expandedGroup,
    required this.onGroupToggle,
    required this.onReset,
    required this.searchCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n          = AppL10n.fromCode(ref.watch(localeProvider).languageCode);
    final hskFilters    = ref.watch(selectedHskFilterProvider);
    final categories    = ref.watch(selectedCategoryProvider);
    final lengths       = ref.watch(selectedLengthProvider);
    final lifeCategories = ref.watch(selectedLifeCategoryProvider);
    final search        = ref.watch(selectedSearchProvider);
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final hasFilter     = hskFilters.isNotEmpty ||
        categories.isNotEmpty || lengths.isNotEmpty ||
        lifeCategories.isNotEmpty || search != null;

    void toggleHsk(int level) {
      final next = Set<int>.from(hskFilters);
      next.contains(level) ? next.remove(level) : next.add(level);
      ref.read(selectedHskFilterProvider.notifier).state = next;
      ref.invalidate(videoFeedProvider);
    }

    void toggleLife(String cat) {
      final next = Set<String>.from(lifeCategories);
      next.contains(cat) ? next.remove(cat) : next.add(cat);
      ref.read(selectedLifeCategoryProvider.notifier).state = next;
      ref.invalidate(videoFeedProvider);
    }

    void toggleCategory(String cat) {
      final next = Set<String>.from(categories);
      next.contains(cat) ? next.remove(cat) : next.add(cat);
      ref.read(selectedCategoryProvider.notifier).state = next;
      ref.invalidate(videoFeedProvider);
    }

    void toggleLength(String len) {
      final next = Set<String>.from(lengths);
      next.contains(len) ? next.remove(len) : next.add(len);
      ref.read(selectedLengthProvider.notifier).state = next;
      ref.invalidate(videoFeedProvider);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariant : Colors.white,
        border: Border(
          right: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Search field ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: searchCtrl,
                style: const TextStyle(
                    color: AppColors.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  hintStyle: const TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 12),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surface
                      : const Color(0xFFF2F3F7),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.primary)),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.onSurfaceMuted, size: 16),
                  suffixIcon: search != null && search.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            searchCtrl.clear();
                            ref
                                .read(selectedSearchProvider.notifier)
                                .state = null;
                          },
                          child: const Icon(Icons.close,
                              color: AppColors.onSurfaceMuted, size: 14),
                        )
                      : null,
                ),
              ),
            ),
          ),
          // ── Active filter chips ───────────────────────────────────────────
          if (hasFilter)
            _ActiveFilterChips(
              hskFilters: hskFilters,
              categories: categories,
              lengths: lengths,
              lifeCategories: lifeCategories,
              onRemoveHsk: (lvl) {
                final next = Set<int>.from(hskFilters)..remove(lvl);
                ref.read(selectedHskFilterProvider.notifier).state = next;
                ref.invalidate(videoFeedProvider);
              },
              onRemoveCategory: (cat) {
                final next = Set<String>.from(categories)..remove(cat);
                ref.read(selectedCategoryProvider.notifier).state = next;
                ref.invalidate(videoFeedProvider);
              },
              onRemoveLength: (len) {
                final next = Set<String>.from(lengths)..remove(len);
                ref.read(selectedLengthProvider.notifier).state = next;
                ref.invalidate(videoFeedProvider);
              },
              onRemoveLifeCategory: (cat) {
                final next = Set<String>.from(lifeCategories)..remove(cat);
                ref.read(selectedLifeCategoryProvider.notifier).state = next;
                ref.invalidate(videoFeedProvider);
              },
              onClearAll: onReset,
              isDark: isDark,
            ),
          Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white10 : Colors.black12),
          // ── Accordion groups ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _SidebarGroup(
                    id: 'life',
                    label: l10n.lifeSection,
                    expandedGroup: expandedGroup,
                    onToggle: onGroupToggle,
                    hasActive: lifeCategories.isNotEmpty,
                    isDark: isDark,
                    children: [
                      _SidebarItem(
                        label: l10n.dailyLife,
                        selected: lifeCategories.contains('daily_life'),
                        onTap: () => toggleLife('daily_life'),
                        isDark: isDark,
                      ),
                      _SidebarItem(
                        label: l10n.businessLife,
                        selected: lifeCategories.contains('business'),
                        onTap: () => toggleLife('business'),
                        isDark: isDark,
                      ),
                      _SidebarItem(
                        label: l10n.childrenLife,
                        selected: lifeCategories.contains('children'),
                        onTap: () => toggleLife('children'),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  _SidebarGroup(
                    id: 'hsk',
                    label: 'HSK',
                    expandedGroup: expandedGroup,
                    onToggle: onGroupToggle,
                    hasActive: hskFilters.isNotEmpty,
                    isDark: isDark,
                    children: [
                      for (int i = 1; i <= 6; i++)
                        _SidebarItem(
                          label: 'HSK $i',
                          selected: hskFilters.contains(i),
                          color: AppColors.forHskLevel(i),
                          onTap: () => toggleHsk(i),
                          isDark: isDark,
                        ),
                    ],
                  ),
                  _SidebarGroup(
                    id: 'grammar',
                    label: l10n.grammarSection,
                    expandedGroup: expandedGroup,
                    onToggle: onGroupToggle,
                    hasActive: categories.isNotEmpty,
                    isDark: isDark,
                    children: [
                      for (final cat in QuizCategory.values)
                        _SidebarItem(
                          label: cat.displayName,
                          selected: categories.contains(cat.name),
                          onTap: () => toggleCategory(cat.name),
                          isDark: isDark,
                        ),
                    ],
                  ),
                  _SidebarGroup(
                    id: 'sinorhythm',
                    label: 'SinoRhythm',
                    expandedGroup: expandedGroup,
                    onToggle: onGroupToggle,
                    hasActive: lengths.isNotEmpty,
                    isDark: isDark,
                    children: [
                      for (final len in [
                        '1-5字',
                        '6-10字',
                        '11-15字',
                        '16-20字',
                        '21字+',
                      ])
                        _SidebarItem(
                          label: len,
                          selected: lengths.contains(len),
                          onTap: () => toggleLength(len),
                          isDark: isDark,
                        ),
                    ],
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

// ── Active filter chips ───────────────────────────────────────────────────────

class _ActiveFilterChips extends ConsumerWidget {
  final Set<int> hskFilters;
  final Set<String> categories;
  final Set<String> lengths;
  final Set<String> lifeCategories;
  final void Function(int) onRemoveHsk;
  final void Function(String) onRemoveCategory;
  final void Function(String) onRemoveLength;
  final void Function(String) onRemoveLifeCategory;
  final VoidCallback onClearAll;
  final bool isDark;

  const _ActiveFilterChips({
    required this.hskFilters,
    required this.categories,
    required this.lengths,
    required this.lifeCategories,
    required this.onRemoveHsk,
    required this.onRemoveCategory,
    required this.onRemoveLength,
    required this.onRemoveLifeCategory,
    required this.onClearAll,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n  = AppL10n.fromCode(ref.watch(localeProvider).languageCode);
    final chips = <Widget>[];

    for (final lvl in (hskFilters.toList()..sort())) {
      chips.add(_RemovableChip(
        label: 'HSK $lvl',
        color: AppColors.forHskLevel(lvl),
        onRemove: () => onRemoveHsk(lvl),
        isDark: isDark,
      ));
    }

    for (final cat in lifeCategories) {
      final label = switch (cat) {
        'daily_life' => l10n.dailyLife,
        'business'   => l10n.businessLife,
        'children'   => l10n.childrenLife,
        _            => cat,
      };
      chips.add(_RemovableChip(
        label: label,
        onRemove: () => onRemoveLifeCategory(cat),
        isDark: isDark,
      ));
    }

    for (final cat in categories) {
      final qc = QuizCategory.values.firstWhere(
        (c) => c.name == cat,
        orElse: () => QuizCategory.general,
      );
      chips.add(_RemovableChip(
        label: qc.displayName,
        onRemove: () => onRemoveCategory(cat),
        isDark: isDark,
      ));
    }

    for (final len in lengths) {
      chips.add(_RemovableChip(
        label: len,
        onRemove: () => onRemoveLength(len),
        isDark: isDark,
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Aktif filtreler',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClearAll,
                child: const Text(
                  'Tümünü temizle',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: chips,
          ),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onRemove;
  final bool isDark;

  const _RemovableChip({
    required this.label,
    required this.onRemove,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 12, color: c),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar accordion group ───────────────────────────────────────────────────

class _SidebarGroup extends StatelessWidget {
  final String id;
  final String label;
  final String? expandedGroup;
  final void Function(String) onToggle;
  final bool hasActive;
  final bool isDark;
  final List<Widget> children;

  const _SidebarGroup({
    required this.id,
    required this.label,
    required this.expandedGroup,
    required this.onToggle,
    required this.hasActive,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = expandedGroup == id;
    final fg = hasActive
        ? AppColors.primary
        : (isDark ? Colors.white70 : Colors.black54);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => onToggle(id),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                if (hasActive)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight:
                          hasActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.keyboard_arrow_down,
                      size: 16,
                      color: isDark ? Colors.white38 : Colors.black38),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isOpen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                )
              : const SizedBox.shrink(),
        ),
        Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : Colors.black12),
      ],
    );
  }
}

// ── Sidebar item (checkmark-style, multi-select) ──────────────────────────────

class _SidebarItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final bool isDark;

  const _SidebarItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: selected ? c.withValues(alpha: 0.10) : Colors.transparent,
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
                  color: selected
                      ? c
                      : (isDark ? Colors.white70 : Colors.black54),
                  fontSize: 13,
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

