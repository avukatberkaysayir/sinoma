import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cities.dart';
import '../../../core/constants/landmarks/landmark_packs.dart';
import '../../providers/locale_provider.dart';
import '../../providers/path_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../dictionary/dictionary_screen.dart';
import '../profile/profile_screen.dart';
import 'path_sections.dart';
import 'phase_runner_screen.dart';

// Sinoma ink palette: deep ink ground, jade/turquoise accents, vermilion
// seal red and antique gold — deliberately NOT the Duolingo navy/green set.
const _duoGreen = Color(0xFF2EC4B6);
const _duoGreenDark = Color(0xFF21968B);
// Surfaces resolve per theme (ink ↔ rice paper) through AppColors.
Color get _duoBg => AppColors.surface;
Color get _duoPanel => AppColors.surfaceVariant;
Color get _duoLocked => AppColors.locked;
const _vermilion = Color(0xFFE0442C); // Chinese seal red

enum _Section {
  home, // post-login dashboard (no nav item highlighted)
  learn,
  dictionary,
  video,
  leaderboard,
  quests,
  shop,
  profile, // read-only profile view (nav)
  editProfile, // profile edit form (Settings > Profil)
  more,
}

// Each left-nav section is its own URL.
const Map<_Section, String> _sectionPaths = {
  _Section.home: '/home',
  _Section.learn: '/learn',
  _Section.profile: '/profile',
  _Section.editProfile: '/settings/profile',
  _Section.video: '/video',
  _Section.dictionary: '/dictionary',
  _Section.leaderboard: '/leaderboard',
  _Section.quests: '/quests',
  _Section.shop: '/shop',
  _Section.more: '/settings',
};

_Section _sectionFromLoc(String loc) {
  for (final e in _sectionPaths.entries) {
    if (e.value == loc) return e.key;
  }
  return _Section.learn;
}

// learnNavExpandedProvider lives in path_provider.dart (so BAŞLA can open it too).

class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Colors come from AppColors statics (no Theme dependency) — watching the
    // theme here rebuilds the WHOLE shell (nav + center + rails) the moment
    // the toggle flips, instead of only after the next navigation.
    ref.watch(themeModeProvider);
    final loc = GoRouterState.of(context).matchedLocation;
    final section = _sectionFromLoc(loc);
    final w = MediaQuery.sizeOf(context).width;
    final compactNav = w < 820;
    final tr = ref.watch(localeProvider).languageCode == 'tr';

    Widget center;
    switch (section) {
      case _Section.home:
        center = HomeDashboard(tr: tr, onStart: () {
          // BAŞLA: open the Öğren nav and jump to the level the learner left off
          // on, then show that level's path.
          final topics = ref.read(curriculumProvider).valueOrNull;
          final progress =
              ref.read(pathProgressProvider).valueOrNull ?? const {};
          final phase = topics == null
              ? null
              : currentPhaseFor(
                  topics, progress, ref.read(currentHskLevelProvider));
          if (phase != null) {
            ref.read(selectedTopicHskProvider.notifier).state = phase.hsk;
          }
          ref.read(learnNavExpandedProvider.notifier).state = true;
          context.go('/learn');
        });
        break;
      case _Section.video:
        center = VideoCenter(tr: tr);
        break;
      case _Section.dictionary:
        center = const DictionaryScreen();
        break;
      case _Section.leaderboard:
        center = LeaderboardCenter(tr: tr);
        break;
      case _Section.quests:
        center = QuestsCenter(tr: tr);
        break;
      case _Section.shop:
        center = ShopCenter(tr: tr);
        break;
      case _Section.profile:
        center = ProfileView(
            tr: tr, onEdit: () => context.go('/settings/profile'));
        break;
      case _Section.editProfile:
        final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
        center = ProfileScreen(uid: uid);
        break;
      case _Section.more:
        center = SettingsCenter(tr: tr);
        break;
      case _Section.learn:
        center = const _CenterPath();
        break;
    }

    final right = _rightFor(section, tr, context);

    return Scaffold(
      backgroundColor: _duoBg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LeftNav(
              compact: compactNav,
              section: section,
              tr: tr,
              onSelect: (s) => context.go(_sectionPaths[s]!),
              selectedHsk: ref.watch(selectedTopicHskProvider),
              learnExpanded: ref.watch(learnNavExpandedProvider),
              onToggleLearn: () => ref
                  .read(learnNavExpandedProvider.notifier)
                  .update((v) => !v),
              onSelectLevel: (h) {
                ref.read(selectedTopicHskProvider.notifier).state = h;
                if (loc != '/learn') context.go('/learn');
              },
            ),
            // The centre column of EVERY section sits on the learner-level
            // stationery page (Level 1 for new users; levels up with the
            // user, never with the browsed topic) — the plain cream centre
            // is gone. Painted in the shell so it is on screen from the very
            // first frame, before any section data loads.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _LevelPagePainter(
                          hsk: ref.watch(currentHskLevelProvider),
                          dark: AppColors.dark,
                        ),
                      ),
                    ),
                  ),
                  center,
                ],
              ),
            ),
            if (right != null && w >= 1100) right,
          ],
        ),
      ),
    );
  }

  // Each section gets its own right column (Duolingo-style).
  Widget? _rightFor(_Section s, bool tr, BuildContext context) {
    switch (s) {
      case _Section.home:
      case _Section.learn:
        return _RightSidebar(tr: tr);
      case _Section.video:
        return VideoFiltersRight(tr: tr);
      case _Section.dictionary:
        return const DictionaryRightRail();
      case _Section.leaderboard:
        return RightInfoCard(
            tr: tr,
            title: AppL10n.of(context).leagueHowTitle,
            body: AppL10n.of(context).leagueHowBody);
      case _Section.quests:
        return BadgesRight(tr: tr);
      case _Section.shop:
        return _RightSidebar(tr: tr);
      case _Section.profile:
        return ProfileListsRight(tr: tr);
      case _Section.more:
      case _Section.editProfile:
        return SettingsRight(
            tr: tr,
            onProfile: () => context.go('/settings/profile'),
            onPrefs: () => context.go('/settings'));
    }
  }
}

// ── Left navigation rail ──────────────────────────────────────────────────────

class _LeftNav extends StatelessWidget {
  final bool compact;
  final _Section section;
  final bool tr;
  final void Function(_Section) onSelect;
  final int selectedHsk;
  final bool learnExpanded;
  final VoidCallback onToggleLearn;
  final void Function(int) onSelectLevel;
  const _LeftNav({
    required this.compact,
    required this.section,
    required this.tr,
    required this.onSelect,
    required this.selectedHsk,
    required this.learnExpanded,
    required this.onToggleLearn,
    required this.onSelectLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 76 : 230,
      decoration: BoxDecoration(
        color: _duoBg,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo → back to the public landing page.
          InkWell(
            onTap: () => context.go('/'),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 24, top: 4),
              child: Row(
                children: [
                  Image.asset('assets/mascot/mascot.png',
                      width: 34, height: 34, fit: BoxFit.contain),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    const Text('Sinoma',
                        style: TextStyle(
                            color: _duoGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
          // Single muted icon colour + normal-case labels; the ACTIVE item
          // carries a vermilion "seal stamp" — our own nav language.
          _NavItem(
              icon: Icons.person_rounded,
              label: AppL10n.of(context).navProfile,
              active: section == _Section.profile,
              compact: compact,
              onTap: () => onSelect(_Section.profile)),
          _NavItem(
              icon: Icons.temple_buddhist_rounded,
              label: AppL10n.of(context).navLearn,
              active: section == _Section.learn,
              compact: compact,
              // Tapping Öğren both goes to the path and toggles the L1-L6 list.
              onTap: () {
                onSelect(_Section.learn);
                onToggleLearn();
              },
              trailing: compact
                  ? null
                  : Icon(
                      learnExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppColors.text54)),
          // L1-L6 level picker, expandable under "Öğren".
          if (learnExpanded)
            for (var h = 1; h <= 6; h++)
              _LevelNavItem(
                level: h,
                selected: section == _Section.learn && selectedHsk == h,
                compact: compact,
                onTap: () => onSelectLevel(h),
              ),
          _NavItem(
              icon: Icons.auto_stories_rounded,
              label: AppL10n.of(context).navDictionary,
              active: section == _Section.dictionary,
              compact: compact,
              onTap: () => onSelect(_Section.dictionary)),
          _NavItem(
              icon: Icons.play_circle_outline_rounded,
              label: AppL10n.of(context).navPractice,
              active: section == _Section.video,
              compact: compact,
              onTap: () => onSelect(_Section.video)),
          _NavItem(
              icon: Icons.workspace_premium_rounded,
              label: AppL10n.of(context).navRanks,
              active: section == _Section.leaderboard,
              compact: compact,
              onTap: () => onSelect(_Section.leaderboard)),
          _NavItem(
              icon: Icons.emoji_food_beverage_rounded,
              label: AppL10n.of(context).navTeaHouse,
              active: section == _Section.quests,
              compact: compact,
              onTap: () => onSelect(_Section.quests)),
          _NavItem(
              icon: Icons.storefront_rounded,
              label: AppL10n.of(context).navBazaar,
              active: section == _Section.shop,
              compact: compact,
              onTap: () => onSelect(_Section.shop)),
          _NavItem(
              icon: Icons.settings_rounded,
              label: AppL10n.of(context).navSettings,
              active: section == _Section.more,
              compact: compact,
              onTap: () => onSelect(_Section.more)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool compact;
  final VoidCallback onTap;
  final Widget? trailing;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.compact,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? _vermilion : AppColors.text60;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active
            ? _vermilion.withValues(alpha: 0.13)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 0 : 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // Seal-stamp accent: a vermilion bar on the left edge.
              border: Border(
                left: BorderSide(
                    color: active ? _vermilion : Colors.transparent,
                    width: 3),
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(icon, color: fg, size: 24),
                if (!compact) ...[
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            // Vermilion like the icon — readable on the
                            // tinted active pill in BOTH themes.
                            color: active ? _vermilion : AppColors.text70,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (trailing != null) trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// One L1-L6 entry under "Öğren" in the left nav.
class _LevelNavItem extends StatelessWidget {
  final int level;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  const _LevelNavItem({
    required this.level,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: 6, left: compact ? 0 : 18, right: compact ? 0 : 4),
      child: Material(
        color: selected ? _duoGreen : _duoPanel,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 34,
            alignment: compact ? Alignment.center : Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
            child: Text('L$level',
                style: TextStyle(
                    color: selected ? Colors.white : AppColors.text70,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

// ── Center path (learn) ───────────────────────────────────────────────────────

// Fixed height per unit section — taller than a typical viewport so the NEXT
// unit's top line only appears after a scroll.
const double _kUnitHeight = 900;

// An admin-uploaded image (network URL) when present, else the bundled asset.
// A missing bundled asset (e.g. a landmark set added before its art) degrades
// to an empty box instead of the red error widget.
Widget _slotImage(String? url, String assetPath, {BoxFit fit = BoxFit.contain}) {
  final asset = Image.asset(assetPath,
      fit: fit, errorBuilder: (_, __, ___) => const SizedBox.shrink());
  if (url != null && url.isNotEmpty) {
    return Image.network(url, fit: fit, errorBuilder: (_, __, ___) => asset);
  }
  return asset;
}

// Small corner badge on a node that marks its state (done = check, locked = lock).
Widget _nodeBadge(IconData ic, Color bg) => Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.text, width: 1.5),
      ),
      child: Icon(ic, size: 11, color: AppColors.text),
    );

// Generic themed landmark icons for cities without a bespoke asset.
const List<IconData> _genericCityIcons = [
  Icons.temple_buddhist,
  Icons.account_balance,
  Icons.location_city,
  Icons.castle,
  Icons.festival,
];

// A few scenic cities read better as mountains / water / coast than a building.
const Map<String, IconData> _cityIconOverrides = {
  'guilin': Icons.terrain, 'lhasa': Icons.terrain, 'lijiang': Icons.terrain,
  'dali': Icons.terrain, 'huangshan': Icons.terrain, 'kunming': Icons.terrain,
  'xining': Icons.terrain, 'panzhihua': Icons.terrain, 'leshan': Icons.terrain,
  'yaan': Icons.terrain, 'baoshan': Icons.terrain, 'liupanshui': Icons.terrain,
  'suzhou': Icons.water, 'hangzhou': Icons.water, 'wuxi': Icons.water,
  'shaoxing': Icons.water, 'zhenjiang': Icons.water, 'jiaxing': Icons.water,
  'huzhou': Icons.water, 'yangzhou': Icons.water, 'wenzhou': Icons.water,
  'ningbo': Icons.sailing, 'xiamen': Icons.sailing, 'qingdao': Icons.sailing,
  'dalian': Icons.sailing, 'zhuhai': Icons.sailing,
  'sanya': Icons.beach_access, 'haikou': Icons.beach_access,
  'beihai': Icons.beach_access,
};

// The icon for one phase circle: the city's curated landmark for that phase (4 per
// city, in order) when the city has a set, else a generic themed icon.
({String? asset, IconData icon}) _cityNodeIcon(
    int hsk, int unitIndex, int phaseIndex) {
  final c = cityForUnit(hsk, unitIndex);
  final set = kCityLandmarks[c.slug];
  final asset = set != null
      ? cityIconAsset(c.slug, set[phaseIndex % set.length].icon)
      : null;
  final generic = _cityIconOverrides[c.slug] ??
      _genericCityIcons[(hsk * 31 + unitIndex) % _genericCityIcons.length];
  return (asset: asset, icon: generic);
}

class _CenterPath extends ConsumerStatefulWidget {
  const _CenterPath();
  @override
  ConsumerState<_CenterPath> createState() => _CenterPathState();
}

class _CenterPathState extends ConsumerState<_CenterPath> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curriculum = ref.watch(curriculumProvider);
    final progressAsync = ref.watch(pathProgressProvider);
    final selectedHsk = ref.watch(selectedTopicHskProvider);
    final userHsk = ref.watch(currentHskLevelProvider);
    final tr = ref.watch(localeProvider).languageCode == 'tr';

    // Level is now chosen from the left nav: when it changes, jump back to the
    // top of the new level.
    ref.listen(selectedTopicHskProvider, (_, __) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });

    return curriculum.when(
      loading: () => const Center(child: _PathLoading()),
      error: (e, _) =>
          Center(child: Text('$e', style: TextStyle(color: AppColors.text54))),
      data: (topics) {
        final progress = progressAsync.valueOrNull ?? const {};
        final topic = topics.firstWhere((t) => t.hsk == selectedHsk,
            orElse: () => topics.first);
        // Centred loader until EVERY unit of the level has precached its
        // imagery (icons + mascot animation) — the reveal is one clean paint
        // of the whole level, capped by the per-unit 8s precache timeout.
        final entryRevealed = ref.watch(levelRevealedProvider(topic.hsk));

        // The single "current" phase across the topic.
        final flat = <PathPhase>[for (final s in topic.steps) ...s.phases];
        // No BAŞLAT pointer on levels the HSK test already passed — there is
        // nowhere to "continue" inside them.
        PathPhase? current;
        if (topic.hsk > userHsk) {
          for (final p in flat) {
            if (!progress.phase(p.key).done &&
                isPhaseUnlocked(topic, p, progress, userHsk)) {
              current = p;
              break;
            }
          }
        }

        // No sticky banner any more — each unit carries its own "X. Ünite"
        // title and the city info opens from the unit's side mascot.
        return Stack(children: [
          // (The stationery backdrop lives in the shell now — one page for
          // the whole site, keyed to the user's level.)
          ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 80),
            itemExtent: _kUnitHeight,
            // Precache THREE units ahead of the scroll — far enough that a
            // unit's batch lands before it enters the viewport, without the
            // 45MB download storm of building every unit up front (which
            // saturated the connection and slowed the whole app).
            cacheExtent: _kUnitHeight * 3,
            itemCount: topic.steps.length,
            itemBuilder: (_, i) => _UnitNodes(
              step: topic.steps[i],
              topic: topic,
              progress: progress,
              currentKey: current?.key,
              tr: tr,
            ),
          ),
          if (!entryRevealed)
            const Positioned.fill(
              child: IgnorePointer(child: Center(child: _PathLoading())),
            ),
        ]);
      },
    );
  }
}

// Centred "loading" mark shown while a level's entry unit precaches its
// imagery: a softly pulsing vermilion seal square over the localized word
// with cycling ink dots. Removed the moment the unit reveals.
class _PathLoading extends StatefulWidget {
  const _PathLoading();
  @override
  State<_PathLoading> createState() => _PathLoadingState();
}

class _PathLoadingState extends State<_PathLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = AppL10n.of(context).loading;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final pulse = 0.55 + 0.45 * (0.5 - 0.5 * cos(2 * pi * t));
        final dots = '·' * ((t * 3).floor() % 3 + 1);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: pulse,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0442C),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(word,
                    style: TextStyle(
                        color: AppColors.text.withValues(alpha: pulse),
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                SizedBox(
                  width: 18,
                  child: Text(' $dots',
                      style: TextStyle(
                          color: AppColors.text.withValues(alpha: pulse),
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// The 4 phase circles of a unit + the treasure chest, in a symmetric layout:
// ODD units (1, 3, 5…): node 2 swings RIGHT, node 4 LEFT, mascot on the LEFT.
// EVEN units (2, 4, 6…): the exact mirror. Nodes 1, 3 and the chest share the
// same vertical axis; tapping the mascot opens the unit-city info panel.
class _UnitNodes extends ConsumerStatefulWidget {
  final PathStep step;
  final PathTopic topic;
  final Map<String, dynamic> progress;
  final String? currentKey;
  final bool tr;
  const _UnitNodes({
    required this.step,
    required this.topic,
    required this.progress,
    required this.currentKey,
    required this.tr,
  });

  @override
  ConsumerState<_UnitNodes> createState() => _UnitNodesState();
}

class _UnitNodesState extends ConsumerState<_UnitNodes>
    with SingleTickerProviderStateMixin {
  bool _infoOpen = false;
  // Unit imagery (phase icons + static mascot) is precached as one batch and
  // the unit only paints once ALL of it is decoded — otherwise the seal nodes
  // land first and the icons pop in a beat later.
  bool _imagesReady = false;
  String? _precacheKey;
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(seconds: 5))
    ..repeat();

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  void _precacheUnitImages(UnitAssets assets) {
    final step = widget.step;
    final provs = <ImageProvider>[];
    for (var i = 0; i < 4; i++) {
      final url = assets.icon(i).url;
      final ni = _cityNodeIcon(step.hsk, step.index, i);
      if (url != null && url.isNotEmpty) {
        provs.add(NetworkImage(url));
      } else if (ni.asset != null) {
        provs.add(AssetImage(ni.asset!));
      }
    }
    // The mascot joins the batch too — animations from the standard pipeline
    // (mpdecimate + 1.5x + max webp compression) are small enough — so the
    // whole unit, mascot included, reveals in one synchronized paint.
    final mUrl = assets.mascot?.url;
    provs.add((mUrl != null && mUrl.isNotEmpty)
        ? NetworkImage(mUrl) as ImageProvider
        : const AssetImage('assets/mascot/mascot.png'));
    final key = provs.map((p) => p.toString()).join('|');
    if (_precacheKey == key) return;
    _precacheKey = key;
    _imagesReady = false;
    Future.wait([
      for (final p in provs)
        precacheImage(p, context, onError: (_, __) {}),
    ])
        // Safety valve: a stalled download must never hold the level's
        // one-frame reveal hostage — after 8s the unit reports in anyway
        // and any straggler image pops when it lands.
        .timeout(const Duration(seconds: 8), onTimeout: () => const [])
        .then((_) {
      if (mounted && _precacheKey == key) {
        setState(() => _imagesReady = true);
        ref
            .read(unitRevealedProvider(
                    (level: step.hsk, unit: step.index + 1))
                .notifier)
            .state = true;
      }
    });
  }

  Widget _mascot(double size, PathAsset? override) {
    final scaled = size * (override?.scale ?? 1.0);
    final url = override?.url;
    // Admin-uploaded unit animation (GIF/WebP) carries its own motion — show it
    // as-is; the synthetic sway/blink is only for the static bundled mascot.
    // Until the animation's first frame is decoded the slot stays EMPTY: no
    // stale/static stand-in flashes on top of the 3rd-row circle.
    final Widget img = (url != null && url.isNotEmpty)
        ? Image.network(url, width: scaled, height: scaled, fit: BoxFit.contain,
            frameBuilder: (_, child, frame, wasSync) =>
                (frame == null && !wasSync)
                    ? SizedBox(width: scaled, height: scaled)
                    : child)
        : AnimatedBuilder(
            animation: _idle,
            builder: (_, child) {
              final t = _idle.value;
              final blink = t > 0.94 ? 0.92 : 1.0;
              final sway = 0.05 * sin(2 * pi * t);
              return Transform.rotate(
                angle: sway,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(1, blink, 1),
                  child: child,
                ),
              );
            },
            child: Image.asset('assets/mascot/mascot.png',
                width: scaled, height: scaled, fit: BoxFit.contain),
          );
    // The slot keeps its fixed 120px footprint so the unit's row geometry and
    // the caravan route stay put; the scale only grows/shrinks the visual.
    return SizedBox(
      width: size,
      height: size,
      child: OverflowBox(
        maxWidth: scaled,
        maxHeight: scaled,
        child: img,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final tr = widget.tr;
    final mirror = step.index.isOdd; // Ünite 2, 4, … = mirrored layout
    final city = cityForUnit(step.hsk, step.index);
    final hasInfo = kCityLandmarks[city.slug] != null;
    // One synchronized reveal per unit: wait for the override rows, precache
    // every icon image, and only then paint nodes + icons + mascot together.
    final assetsAsync =
        ref.watch(pathAssetsProvider((level: step.hsk, unit: step.index + 1)));
    final assets =
        assetsAsync.hasError ? const UnitAssets() : assetsAsync.valueOrNull;
    if (assets != null) _precacheUnitImages(assets);
    // The unit paints when its own batch is ready AND the level's opening
    // screen has revealed — the first paint is one synchronized frame, and
    // units below land pre-loaded thanks to the list's cacheExtent.
    final levelReady = ref.watch(levelRevealedProvider(step.hsk));
    if (assets == null || !_imagesReady || !levelReady) {
      // Fixed-height blank cell (itemExtent) — only the separator shows.
      return Column(children: [
        if (step.index > 0)
          Container(height: 1.5, color: AppColors.text.withValues(alpha: 0.12)),
        const Expanded(child: SizedBox()),
      ]);
    }
    final mascotOverride = assets.mascot;

    // Visual rows top-to-bottom: phase1 (centre), phase2 (±112), MASCOT
    // (centre, tap → city info), phase3 (∓112), phase4 (centre).
    double dx(int i) => switch (i) {
          1 => mirror ? -112.0 : 112.0,
          2 => mirror ? 112.0 : -112.0,
          _ => 0.0,
        };

    Widget phaseRow(int i) => Transform.translate(
          offset: Offset(dx(i), 0),
          child: _PhaseNode(
            phase: step.phases[i],
            topic: widget.topic,
            progress: widget.progress,
            isCurrent: step.phases[i].key == widget.currentKey,
            tr: tr,
            // Gözat opens away from the centre — mirrored with the layout.
            browseLeft: mirror ? i < 2 : i >= 2,
          ),
        );

    final nodes = <Widget>[
      phaseRow(0),
      phaseRow(1),
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: GestureDetector(
          onTap: hasInfo ? () => setState(() => _infoOpen = true) : null,
          child: _mascot(120, mascotOverride),
        ),
      ),
      phaseRow(2),
      phaseRow(3),
    ];

    return Column(
      children: [
        // Units after the first carry the separator line at their very top;
        // at scroll 0 no line shows (unit 1 has none, unit 2's is a full
        // viewport away) — it appears only once you scroll into it.
        if (step.index > 0)
          Container(height: 1.5, color: AppColors.text.withValues(alpha: 0.12)),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  // Centre the node column — without this the Stack lays the
                  // column out top-LEFT and every unit drifts off-centre.
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Dashed caravan route weaving through the stops.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                            painter: _RoutePainter(mirror: mirror)),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title sits right at the unit top, well clear of
                          // the first circle: big display-size text.
                          Text(
                            AppL10n.of(context).unitTitle(step.index + 1),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 40,
                                height: 1.1,
                                fontWeight: FontWeight.w800),
                          ),
                          // Comfortable distance before the first circle.
                          const SizedBox(height: 36),
                          ...nodes,
                        ],
                      ),
                    ),
                    if (_infoOpen)
                      Positioned.fill(
                        // Tapping anywhere outside the card closes the panel.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _infoOpen = false),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: GestureDetector(
                              onTap: () {},
                              child: _UnitInfoPanel(
                                step: step,
                                tr: tr,
                                onClose: () =>
                                    setState(() => _infoOpen = false),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Dashed "caravan route" connecting a unit's stops (Silk-Road travel feel).
// Node centres follow the fixed row layout of _UnitNodes.
class _RoutePainter extends CustomPainter {
  final bool mirror;
  const _RoutePainter({required this.mirror});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final sgn = mirror ? -1.0 : 1.0;
    // Node centres of the COMPACT unit layout (title 44 + gap 36, rows
    // 78+34, mascot 120 + 24): everything fits one viewport at scroll 0.
    final pts = <Offset>[
      Offset(cx, 119),
      Offset(cx + sgn * 112, 231),
      Offset(cx, 364),
      Offset(cx - sgn * 112, 487),
      Offset(cx, 599),
    ];
    // Antique caravan route: inlaid stepping stones (gold lozenges alternating
    // with round pebbles) along a brush curve, with a small auspicious-cloud
    // curl (祥云) at each segment's midpoint.
    final stone = Paint()..color = const Color(0xFFD4A33D).withValues(alpha: 0.30);
    final pebble = Paint()..color = AppColors.text.withValues(alpha: 0.16);
    final cloud = Paint()
      ..color = const Color(0xFFD4A33D).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final mid = Offset((a.dx + b.dx) / 2 + sgn * 18 * (i.isEven ? 1 : -1),
          (a.dy + b.dy) / 2);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      for (final metric in path.computeMetrics()) {
        var d = 12.0;
        var n = 0;
        while (d < metric.length - 12) {
          final tan = metric.getTangentForOffset(d);
          if (tan == null) break;
          final p = tan.position;
          if (n % 2 == 0) {
            // Lozenge stone, rotated to follow the path.
            canvas.save();
            canvas.translate(p.dx, p.dy);
            canvas.rotate(tan.angle);
            canvas.drawRRect(
                RRect.fromRectAndRadius(
                    Rect.fromCenter(
                        center: Offset.zero, width: 9, height: 5),
                    const Radius.circular(2)),
                stone);
            canvas.restore();
          } else {
            canvas.drawCircle(p, 2.2, pebble);
          }
          d += 17;
          n++;
        }
        // 祥云 curl at the midpoint of the walk, offset off the path.
        final mTan = metric.getTangentForOffset(metric.length / 2);
        if (mTan != null) {
          final nrm = Offset(-sin(mTan.angle), cos(mTan.angle));
          final c = mTan.position + nrm * 14 * (i.isEven ? 1.0 : -1.0);
          const r = 5.0;
          final curl = Path()
            ..addArc(Rect.fromCircle(center: c, radius: r), pi * 0.2, pi * 1.4)
            ..addArc(
                Rect.fromCircle(
                    center: c.translate(r * 1.5, r * 0.2), radius: r * 0.6),
                pi * 0.4,
                pi * 1.2);
          canvas.drawPath(curl, cloud);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.mirror != mirror;
}

// Classical Chinese stationery page behind the path, filling the whole centre
// column (left nav ↔ right rail — no more, no less). Modeled on traditional
// framed letter papers: a quiet level-tinted paper ground, a running key-fret
// border down both edges with a gold rule, and per-level ornaments kept to
// the corners/edges so the middle stays clean under the nodes:
// 1 如意祥云 drifting clouds · 2 中国结 hanging knots · 3 海水纹 wave band ·
// 4 梅花 plum branches · 5 团花 edge medallions · 6 远山 ink mountains.
// Painted once per level/size — it does NOT track the scroll — so the list
// scrolls over a static framed page and the backdrop costs nothing per frame.
class _LevelPagePainter extends CustomPainter {
  final int hsk;
  final bool dark;
  const _LevelPagePainter({required this.hsk, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = AppColors.forHskLevel(hsk);
    const gold = Color(0xFFD4A33D);
    canvas.save();
    canvas.clipRect(Offset.zero & size); // edge art must not bleed outside

    // Paper ground over the full column.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Color.alphaBlend(
              base.withValues(alpha: dark ? 0.10 : 0.08),
              AppColors.surface));

    Paint stroke(Color c, double a, [double sw = 1.5]) => Paint()
      ..color = c.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    final ink = stroke(base, dark ? 0.40 : 0.34);
    final soft = stroke(base, dark ? 0.26 : 0.20);
    final goldRule = stroke(gold, dark ? 0.50 : 0.45, 1.2);
    final fill = Paint()..color = base.withValues(alpha: dark ? 0.22 : 0.18);

    // Frame: gold rule + running key-fret chain down both edges.
    for (final left in [true, false]) {
      final xRule = left ? 30.0 : w - 30.0;
      canvas.drawLine(Offset(xRule, 0), Offset(xRule, h), goldRule);
      final xf = left ? 15.0 : w - 15.0;
      for (var y = 17.0; y < h; y += 34) {
        _fret(canvas, soft, Offset(xf, y), 9);
      }
    }

    switch (hsk) {
      case 1: // clouds drifting along the margins
        _cloud(canvas, ink, Offset(86, h * 0.14), 1.3);
        _cloud(canvas, soft, Offset(w - 92, h * 0.30), 1.0);
        _cloud(canvas, soft, Offset(78, h * 0.56), 0.9);
        _cloud(canvas, ink, Offset(w - 86, h * 0.74), 1.2);
        _cloud(canvas, soft, Offset(110, h * 0.92), 1.0);
      case 2: // knots hanging into the page from the top corners
        _knot(canvas, ink, const Offset(92, 96));
        _knot(canvas, soft, Offset(w - 92, 132));
        _cloudRule(canvas, soft, Offset(w * 0.5, h * 0.55), 70);
      case 3: // sea band along the bottom, cloud rules above
        for (var row = 0; row < 3; row++) {
          final y = h - 16 - row * 22.0;
          final shift = row.isOdd ? 24.0 : 0.0;
          for (var x = shift; x < w + 24; x += 48) {
            for (var r = 8.0; r <= 22; r += 7) {
              canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: r),
                  pi, pi, false, row == 0 ? ink : soft);
            }
          }
        }
        _cloudRule(canvas, soft, Offset(w * 0.30, h * 0.32), 60);
        _cloudRule(canvas, soft, Offset(w * 0.72, h * 0.58), 60);
      case 4: // plum branches reaching in from two corners
        _plumBranch(canvas, ink, fill, const Offset(0, 70), 1.0, false);
        _plumBranch(canvas, soft, fill, Offset(w, h - 130), 0.8, true);
      case 5: // pierced medallions bleeding off both edges
        _medallion(canvas, ink, soft, Offset(4, h * 0.38), 92);
        _medallion(canvas, soft, soft, Offset(w - 4, h * 0.78), 64);
      default: // ink mountain range along the bottom
        final ridge = Path()..moveTo(-10, h - 26);
        final peaks = [
          (w * 0.10, h - 88.0),
          (w * 0.22, h - 44.0),
          (w * 0.38, h - 112.0),
          (w * 0.52, h - 52.0),
          (w * 0.66, h - 96.0),
          (w * 0.82, h - 40.0),
          (w * 0.94, h - 78.0),
        ];
        for (final (px, py) in peaks) {
          ridge.lineTo(px, py);
        }
        ridge.lineTo(w + 10, h - 30);
        canvas.drawPath(ridge, ink);
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
              Rect.fromCenter(
                  center: Offset(w * (0.25 + 0.25 * i), h - 18),
                  width: 90,
                  height: 18),
              pi * 0.1,
              pi * 0.8,
              false,
              soft);
        }
        _cloudRule(canvas, soft, Offset(w * 0.62, h * 0.24), 70);
    }
    canvas.restore();
  }

  // 回纹 key-fret spiral, half-extent s.
  void _fret(Canvas c, Paint p, Offset o, double s) {
    final k = s / 15.0;
    final m = Path()..moveTo(o.dx - 15 * k, o.dy + 15 * k);
    const pts = [
      (-15.0, -15.0), (15.0, -15.0), (15.0, 15.0), (-7.0, 15.0), //
      (-7.0, -7.0), (7.0, -7.0), (7.0, 7.0), (-1.0, 7.0),
      (-1.0, -1.0), (3.0, -1.0),
    ];
    for (final (dx, dy) in pts) {
      m.lineTo(o.dx + dx * k, o.dy + dy * k);
    }
    c.drawPath(m, p);
  }

  // 如意 cloud head with inner curls and a trailing tail, scaled by k.
  void _cloud(Canvas c, Paint p, Offset o, double k) {
    final cl = Path()
      ..moveTo(o.dx - 18 * k, o.dy + 5 * k)
      ..cubicTo(o.dx - 27 * k, o.dy + 5 * k, o.dx - 26 * k, o.dy - 9 * k,
          o.dx - 15 * k, o.dy - 8 * k)
      ..cubicTo(o.dx - 13 * k, o.dy - 17 * k, o.dx + 1 * k, o.dy - 18 * k,
          o.dx + 4 * k, o.dy - 9 * k)
      ..cubicTo(o.dx + 15 * k, o.dy - 13 * k, o.dx + 22 * k, o.dy - 3 * k,
          o.dx + 13 * k, o.dy + 5 * k)
      ..lineTo(o.dx - 18 * k, o.dy + 5 * k)
      ..addArc(
          Rect.fromCircle(center: o.translate(-15 * k, -2 * k), radius: 4 * k),
          pi * 0.2, pi * 1.5)
      ..addArc(
          Rect.fromCircle(center: o.translate(3 * k, -8 * k), radius: 4.5 * k),
          pi * 0.4, pi * 1.5)
      ..moveTo(o.dx + 13 * k, o.dy + 5 * k)
      ..quadraticBezierTo(
          o.dx + 26 * k, o.dy + 8 * k, o.dx + 34 * k, o.dy + 1 * k);
    c.drawPath(cl, p);
  }

  // The flat S-shaped "cloud rule" the reference papers scatter mid-page.
  void _cloudRule(Canvas c, Paint p, Offset o, double half) {
    final path = Path()
      ..moveTo(o.dx - half, o.dy)
      ..lineTo(o.dx + half * 0.55, o.dy)
      ..quadraticBezierTo(
          o.dx + half * 0.9, o.dy, o.dx + half * 0.9, o.dy - 9)
      ..quadraticBezierTo(
          o.dx + half * 0.9, o.dy - 16, o.dx + half * 0.62, o.dy - 16)
      ..moveTo(o.dx - half * 0.6, o.dy + 8)
      ..lineTo(o.dx + half, o.dy + 8);
    c.drawPath(path, p);
  }

  // 中国结 — cord from the top, diamond knot, side loops, tassels.
  void _knot(Canvas c, Paint p, Offset o) {
    c.drawLine(Offset(o.dx, 0), Offset(o.dx, o.dy - 22), p);
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(pi / 4);
    for (final r in [15.0, 10.0, 5.0]) {
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), p);
    }
    c.restore();
    c.drawCircle(o.translate(-25, 0), 5, p);
    c.drawCircle(o.translate(25, 0), 5, p);
    for (final dx in [-5.0, 0.0, 5.0]) {
      c.drawLine(o.translate(dx * 0.4, 22), o.translate(dx, 52), p);
    }
  }

  // 团花 pierced medallion bleeding off an edge: concentric rings, a petal
  // wreath and a coin heart.
  void _medallion(Canvas c, Paint p, Paint p2, Offset o, double r) {
    c.drawCircle(o, r, p);
    c.drawCircle(o, r * 0.86, p2);
    for (var i = 0; i < 14; i++) {
      final a = i * 2 * pi / 14;
      final pc = o + Offset(cos(a), sin(a)) * r * 0.66;
      c.drawCircle(pc, r * 0.13, p2);
    }
    c.drawCircle(o, r * 0.30, p);
    c.drawRect(
        Rect.fromCenter(center: o, width: r * 0.22, height: r * 0.22), p);
  }

  // 梅花 branch sweeping in from a corner with blossoms and buds.
  void _plumBranch(
      Canvas c, Paint p, Paint fill, Offset root, double k, bool mirror) {
    final s = mirror ? -1.0 : 1.0;
    final branch = Path()
      ..moveTo(root.dx, root.dy)
      ..quadraticBezierTo(root.dx + s * 90 * k, root.dy - 10 * k,
          root.dx + s * 150 * k, root.dy + 34 * k)
      ..quadraticBezierTo(root.dx + s * 205 * k, root.dy + 72 * k,
          root.dx + s * 262 * k, root.dy + 60 * k)
      ..moveTo(root.dx + s * 118 * k, root.dy + 16 * k)
      ..quadraticBezierTo(root.dx + s * 150 * k, root.dy - 26 * k,
          root.dx + s * 196 * k, root.dy - 34 * k);
    c.drawPath(branch, p);
    void blossom(Offset o, double r) {
      for (var i = 0; i < 5; i++) {
        final a = -pi / 2 + i * 2 * pi / 5;
        c.drawCircle(o + Offset(cos(a), sin(a)) * r, r * 0.72, fill);
      }
      c.drawCircle(o, r * 0.28, p);
    }

    blossom(root.translate(s * 150 * k, 34 * k), 8 * k);
    blossom(root.translate(s * 196 * k, -34 * k), 7 * k);
    blossom(root.translate(s * 250 * k, 58 * k), 6 * k);
    c.drawCircle(root.translate(s * 92 * k, -2 * k), 3 * k, fill);
    c.drawCircle(root.translate(s * 226 * k, 66 * k), 2.6 * k, fill);
  }

  @override
  bool shouldRepaint(_LevelPagePainter old) =>
      old.hsk != hsk || old.dark != dark;
}

// City info panel — opens over the unit (sized to it, never overflows):
// the unit-city's landmarks with photo + bilingual blurb.
class _UnitInfoPanel extends ConsumerWidget {
  final PathStep step;
  final bool tr;
  final VoidCallback onClose;
  const _UnitInfoPanel(
      {required this.step, required this.tr, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = cityForUnit(step.hsk, step.index);
    final landmarks = kCityLandmarks[city.slug] ?? const <Landmark>[];
    final assets = ref
            .watch(pathAssetsProvider((level: step.hsk, unit: step.index + 1)))
            .valueOrNull ??
        const UnitAssets();

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      cityNameFor(
                          city,
                          Localizations.maybeLocaleOf(context)
                                  ?.languageCode ??
                              (tr ? 'tr' : 'en')),
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                // Plain GestureDetector with a generous hit area: closing must
                // never depend on Material ink plumbing.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child:
                        Icon(Icons.close_rounded, color: AppColors.text70),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.text12, height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < landmarks.length; i++) ...[
                    Builder(builder: (context) {
                      final lm = landmarks[i];
                      final photo = assets.photo(i);
                      final lang = Localizations.maybeLocaleOf(context)
                              ?.languageCode ??
                          (tr ? 'tr' : 'en');
                      final name = landmarkName(city.slug, lm.icon, lang, lm);
                      // Admin per-language override wins; otherwise the bundled
                      // translation pack (English as the final fallback).
                      final ovr = photo.descFor(lang);
                      final desc = ovr.isNotEmpty
                          ? ovr
                          : landmarkDesc(city.slug, lm.icon, lang, lm);
                      return Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 110,
                              height: 96,
                              child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ColoredBox(color: AppColors.locked),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: _slotImage(photo.url,
                                          cityPhotoAsset(city.slug, lm.photo),
                                          fit: BoxFit.contain),
                                    ),
                                  ]),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: TextStyle(
                                            color: AppColors.text,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(desc,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: AppColors.text70,
                                            fontSize: 12,
                                            height: 1.3)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (i < landmarks.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseNode extends ConsumerWidget {
  final PathPhase phase;
  final PathTopic topic;
  final Map<String, dynamic> progress;
  final bool isCurrent;
  final bool tr;
  final bool browseLeft; // gözat button on the left of the circle
  const _PhaseNode({
    required this.phase,
    required this.topic,
    required this.progress,
    required this.isCurrent,
    required this.tr,
    this.browseLeft = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pp = progress.phase(phase.key);
    final unlocked = isPhaseUnlocked(
        topic, phase, progress, ref.watch(currentHskLevelProvider));
    final done = pp.done;

    // Cities with a real landmark icon drop the circle and show the icon alone
    // (a test for now); the rest keep the coloured circle with a generic themed
    // icon. State stays legible: a small corner badge (lock when locked, check
    // when done).
    final ni = _cityNodeIcon(phase.hsk, phase.stepIndex, phase.phaseIndex);
    // Admin-uploaded icon override for this circle (slot = phase index).
    final iconOverride = ref
            .watch(pathAssetsProvider(
                (level: phase.hsk, unit: phase.stepIndex + 1)))
            .valueOrNull
            ?.icon(phase.phaseIndex) ??
        const PathAsset();
    final iconUrl = iconOverride.url;
    final hasIcon = ni.asset != null || iconUrl != null;
    final available = done || unlocked;
    Widget? badge;
    if (done) {
      badge = _nodeBadge(Icons.check_rounded, _duoGreenDark);
    } else if (!unlocked && phase.hasVideos) {
      // Lock badge only on REAL locked content; empty slots just render dim
      // (a lock there reads as "you can't continue", which is wrong).
      badge = _nodeBadge(Icons.lock_rounded, const Color(0xFF2A363D));
    }

    Future<void> open() async {
      if (!unlocked) return;
      if (phase.videos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppL10n.of(context).noVideosInSet),
        ));
        return;
      }
      if (ref.read(pathMetaProvider).hearts <= 0) {
        final next = ref.read(pathMetaProvider).nextHeartAt;
        final mins = next?.difference(DateTime.now()).inMinutes.clamp(0, 9999);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppL10n.of(context).outOfHearts(mins)),
        ));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PhaseRunnerScreen(
          phase: phase,
          title:
              'L${phase.hsk} · ${AppL10n.of(context).phaseLbl} ${phase.phaseIndex + 1}',
        ),
      ));
      ref.invalidate(pathProgressProvider);
    }

    final Widget art;
    if (hasIcon) {
      // Real/uploaded landmark icon — shown alone, no circle behind it. The admin
      // scale lets the size be tuned per slot.
      final sz = (78.0 * iconOverride.scale).clamp(36.0, 150.0);
      // A landmark set without its bundled art yet (icons come later or via
      // admin upload) falls back to the generic coloured circle.
      Widget genericCircle() => Container(
            width: sz,
            height: sz * 0.94,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: available ? _duoGreen : _duoLocked,
              borderRadius: BorderRadius.circular(sz / 2),
              boxShadow: [
                BoxShadow(
                    color: available
                        ? _duoGreenDark
                        : const Color(0xFF2A363D),
                    offset: const Offset(0, 7)),
              ],
            ),
            child: Icon(ni.icon,
                size: sz * 0.46,
                color: available ? Colors.white : AppColors.text30),
          );
      final assetImg = ni.asset != null
          ? Image.asset(ni.asset!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => genericCircle())
          : genericCircle();
      final img = SizedBox(
        width: sz,
        height: sz,
        child: iconUrl != null
            ? Image.network(iconUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => assetImg)
            : assetImg,
      );
      art = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (available)
            img
          else ...[
            // Matte locked look: flat grey icon (no backing disc — only the
            // pedestal ellipse below the icon stays).
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 28, //
                0.2126, 0.7152, 0.0722, 0, 32, //
                0.2126, 0.7152, 0.0722, 0, 30, //
                0, 0, 0, 1, 0,
              ]),
              child: img,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Text('🔒',
                  style: TextStyle(
                      fontSize: (sz * 0.24).clamp(13.0, 22.0))),
            ),
          ],
          if (done && badge != null)
            Positioned(right: 8, bottom: 8, child: badge),
        ],
      );
    } else {
      // Generic city icon on the coloured circle (until a real icon is added).
      final topColor = available ? _duoGreen : _duoLocked;
      final shadow = available ? _duoGreenDark : const Color(0xFF2A363D);
      // Seal-stamp square (not a circle): rounded square with an inner line,
      // like a carved chop; locked slots read as faded ink.
      art = Container(
        width: 78,
        height: 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: topColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 6))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 64,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.text.withValues(
                        alpha: available ? 0.45 : 0.15),
                    width: 1.5),
              ),
            ),
            Opacity(
              opacity: available ? 1 : 0.55,
              child: Icon(ni.icon,
                  size: 34,
                  color: available ? Colors.white : AppColors.text54),
            ),
            if (!available)
              const Positioned(
                right: -4,
                bottom: -4,
                child: Text('🔒', style: TextStyle(fontSize: 16)),
              )
            else if (badge != null)
              Positioned(right: -3, bottom: -3, child: badge),
          ],
        ),
      );
    }
    // Uniform node footprint: the layout box is the SAME for every slot no
    // matter how large the icon art is (admin scale only changes the drawing,
    // which may overflow) — so the gözat button sits at the SAME distance from
    // the node centre everywhere, mirrored right (1-2) / left (3-4).
    final node = _NodeFx(
      available: available,
      isCurrent: isCurrent,
      tr: tr,
      onTap: open,
      child: OverflowBox(
        maxWidth: 220,
        maxHeight: 220,
        child: art,
      ),
    );

    // Every slot carries vocabulary; the popup opens to the side away from the
    // path centre: right-side gözat opens right, left-side opens left.
    final browse = _BrowseButton(
      tr: tr,
      toRight: !browseLeft,
      level: phase.hsk,
      unit: phase.stepIndex + 1,
      phase: phase.phaseIndex + 1,
    );

    // Keep the NODE centred on its offset (a matching spacer balances the
    // gözat) so circles at the same offset line up vertically. Same gap + the
    // same lowered gözat position on every circle.
    const gap = 10.0;
    const browseW = 21.0;
    final lowered = Transform.translate(
      offset: const Offset(0, 16),
      child: browse,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: browseLeft
            ? [
                lowered,
                const SizedBox(width: gap),
                node,
                const SizedBox(width: gap),
                const SizedBox(width: browseW),
              ]
            : [
                const SizedBox(width: browseW),
                const SizedBox(width: gap),
                node,
                const SizedBox(width: gap),
                lowered,
              ],
      ),
    );
  }
}

// ── Node effects (Duolingo-style) ─────────────────────────────────────────────
// One looping controller drives everything: the bouncing BAŞLAT pill on the
// current node, a soft pulsing glow + twinkling stars around unlocked nodes,
// a translucent pedestal disc under every icon, and a hover grow.

class _NodeFx extends StatefulWidget {
  final bool available;
  final bool isCurrent;
  final bool tr;
  final VoidCallback onTap;
  final Widget child;
  const _NodeFx({
    required this.available,
    required this.isCurrent,
    required this.tr,
    required this.onTap,
    required this.child,
  });

  static const double w = 86;
  static const double h = 78;

  @override
  State<_NodeFx> createState() => _NodeFxState();
}

class _NodeFxState extends State<_NodeFx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  bool _hover = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // A drifting plum-blossom petal near the node; [phase] staggers them —
  // our replacement for generic sparkle stars.
  Widget _star(double dx, double dy, double phase, double size) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = (_c.value + phase / (2 * pi)) % 1.0;
        final a = 0.5 + 0.5 * sin(_c.value * 2 * pi + phase);
        return Transform.translate(
          offset: Offset(dx + 4 * sin(t * 2 * pi), dy + 8 * t),
          child: Transform.rotate(
            angle: t * 1.4,
            child: Opacity(
              opacity: 0.2 + 0.6 * a,
              child: Text('🌸', style: TextStyle(fontSize: size)),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.available
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _NodeFx.w,
          height: _NodeFx.h,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Translucent pedestal disc under the icon.
              Positioned(
                bottom: -4,
                child: Container(
                  width: 66,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.text
                        .withValues(alpha: widget.available ? 0.10 : 0.05),
                    borderRadius: const BorderRadius.all(
                        Radius.elliptical(43, 10)),
                  ),
                ),
              ),
              // Soft pulsing light behind unlocked nodes — a faint turquoise
              // halo: visible as light, but well short of a spotlight.
              if (widget.available)
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final a =
                        0.04 + 0.05 * (0.5 + 0.5 * sin(_c.value * 2 * pi));
                    return Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2EC4B6)
                                .withValues(alpha: a),
                            blurRadius: 26,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              // Hover: the icon grows slightly — "about to be selected".
              AnimatedScale(
                scale: _hover && widget.available ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: widget.child,
              ),
              // Twinkling stars around unlocked nodes.
              if (widget.available) ...[
                _star(-36, -24, 0.0, 11),
                _star(38, -16, 2.1, 9),
                _star(-32, 18, 4.2, 8),
                _star(34, 24, 1.3, 10),
              ],
              // Vermilion 开始 seal stamp over the current node (replaces the
              // Duolingo-style START balloon): slightly tilted, gently
              // pulsing like a fresh ink stamp.
              if (widget.isCurrent)
                Positioned(
                  top: -46,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, child) => Transform.rotate(
                      angle: -0.12,
                      child: Transform.scale(
                        scale: 1 + 0.04 * sin(_c.value * 2 * pi),
                        child: child,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _vermilion,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFF6E7D7), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('开始',
                              style: TextStyle(
                                  color: Color(0xFFF6E7D7),
                                  fontSize: 15,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800)),
                          Text(AppL10n.of(context).startStamp,
                              style: const TextStyle(
                                  color: Color(0xFFF6E7D7),
                                  fontSize: 8,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Round "gözat" button next to a circle. Tapping opens the words popup anchored
// to the side away from the path centre (right-side button → right, left → left).
class _BrowseButton extends StatefulWidget {
  final bool tr;
  final bool toRight;
  final int level;
  final int unit;
  final int phase;
  const _BrowseButton({
    required this.tr,
    required this.toRight,
    required this.level,
    required this.unit,
    required this.phase,
  });

  @override
  State<_BrowseButton> createState() => _BrowseButtonState();
}

class _BrowseButtonState extends State<_BrowseButton> {
  OverlayEntry? _entry;

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  void _toggle() {
    if (_entry != null) {
      _close();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final sz = box.size;
    final ov = overlayBox.size;
    const pw = 300.0, ph = 340.0;
    final maxLeft = (ov.width - pw - 8).clamp(8.0, double.infinity);
    final top =
        (pos.dy - 6).clamp(8.0, (ov.height - ph - 8).clamp(8.0, double.infinity));
    double? left, right;
    if (widget.toRight) {
      left = (pos.dx + sz.width + 8).clamp(8.0, maxLeft);
    } else {
      right = (ov.width - pos.dx + 8).clamp(8.0, maxLeft);
    }
    _entry = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: _close),
        ),
        Positioned(
          top: top,
          left: left,
          right: right,
          child: _SlotWordPanel(
            level: widget.level,
            unit: widget.unit,
            phase: widget.phase,
            tr: widget.tr,
            onClose: _close,
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Just the "?" icon (it already has its own coloured circle) — no extra ring.
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 21,
        height: 21,
        child: Image.asset('assets/icons/gozat.png'),
      ),
    );
  }
}

// Small square panel listing a slot's words + dictionary meaning, fetched on
// demand. Up to ~5 rows visible, the rest scroll; X (top-right) closes it.
class _SlotWordPanel extends ConsumerWidget {
  final int level;
  final int unit;
  final int phase;
  final bool tr;
  final VoidCallback onClose;
  const _SlotWordPanel(
      {required this.level,
      required this.unit,
      required this.phase,
      required this.tr,
      required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
        slotWordsProvider((level: level, unit: unit, phase: phase)));
    // A unit can teach several grammar rules; they're distributed across the 4
    // circles' gözat boxes in this order: 1st→circle1, 2nd→circle3, 3rd→circle4,
    // 4th→circle2 (and wrap for >4). Only the grammars for THIS circle show here.
    final unitG = (ref.watch(grammarByLevelProvider)[level] ?? const [])
        .where((g) => g.unit == unit)
        .toList();
    const order = [1, 3, 4, 2];
    final myG = [
      for (var i = 0; i < unitG.length; i++)
        if (order[i % 4] == phase) unitG[i]
    ];
    return Material(
      color: _duoPanel,
      elevation: 10,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 300,
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        AppL10n.of(context).wordsInSet,
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.text60, size: 20),
                    onPressed: onClose,
                    tooltip: AppL10n.of(context).closeLabel,
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.text12, height: 1),
            // "Gramer: …" header — only on the circles this unit's grammar(s) are
            // assigned to.
            if (myG.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _duoGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _duoGreen.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${AppL10n.of(context).grammarLbl}: ${myG.map((g) => g.zh).join(' · ')}',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800),
                ),
              ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: _duoGreen)),
                error: (e, _) => Center(
                    child: Text(AppL10n.of(context).failedLbl,
                        style: TextStyle(color: AppColors.text54))),
                data: (words) => words.isEmpty
                    ? Center(
                        child: Text(AppL10n.of(context).noWordsLbl,
                            style: TextStyle(color: AppColors.text54)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: words.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: AppColors.text10, height: 14),
                        itemBuilder: (_, i) {
                          final w = words[i];
                          final meaning = w.meaningFor(
                              Localizations.maybeLocaleOf(context)
                                      ?.languageCode ??
                                  (tr ? 'tr' : 'en'));
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w.word,
                                  style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (w.pinyin.isNotEmpty)
                                      Text(w.pinyin,
                                          style: const TextStyle(
                                              color: _duoGreen,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    Text(meaning.isNotEmpty ? meaning : '—',
                                        style: TextStyle(
                                            color: AppColors.text70,
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Right sidebar (stats) ─────────────────────────────────────────────────────

class _RightSidebar extends ConsumerWidget {
  final bool tr;
  const _RightSidebar({required this.tr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score =
        ref.watch(currentUserProvider).valueOrNull?.stats.totalScore ?? 0;
    final meta = ref.watch(pathMetaProvider);
    final curriculum = ref.watch(curriculumProvider).valueOrNull ?? const [];
    final progress = ref.watch(pathProgressProvider).valueOrNull ?? const {};
    var totalPhases = 0, donePhases = 0;
    for (final t in curriculum) {
      for (final s in t.steps) {
        for (final p in s.phases) {
          totalPhases++;
          if (progress.phase(p.key).done) donePhases++;
        }
      }
    }

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Lantern = streak, copper coin = gold, jade bead = lives — our own
          // counter iconography.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat(emoji: '🏮', color: _vermilionS, value: '${meta.streak}'),
              _Stat(emoji: '🪙', color: _goldS, value: '$score'),
              _Stat(emoji: '🟢', color: _jadeS, value: '${meta.hearts}'),
            ],
          ),
          const SizedBox(height: 20),
          _Card(
            title: AppL10n.of(context).yourProgress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppL10n.of(context).phasesDone(donePhases, totalPhases),
                    style: TextStyle(color: AppColors.text70, fontSize: 14)),
                const SizedBox(height: 10),
                BrushBar(
                  value: totalPhases == 0 ? 0 : donePhases / totalPhases,
                  color: _duoGreen,
                  height: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: AppL10n.of(context).dailyQuest,
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFFFC800), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(AppL10n.of(context).completeOnePhase,
                      style:
                          TextStyle(color: AppColors.text70, fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _vermilionS = Color(0xFFE0442C);
const _goldS = Color(0xFFD4A33D);
const _jadeS = Color(0xFF3FB58E);

class _Stat extends StatelessWidget {
  final String emoji;
  final Color color;
  final String value;
  const _Stat(
      {required this.emoji, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 19)),
      const SizedBox(width: 6),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _duoPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
