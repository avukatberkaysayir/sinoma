import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/cities.dart';
import '../../providers/locale_provider.dart';
import '../../providers/path_provider.dart';
import '../../providers/user_provider.dart';
import '../dictionary/dictionary_screen.dart';
import '../profile/profile_screen.dart';
import 'path_sections.dart';
import 'phase_runner_screen.dart';

// Duolingo-style colours.
const _duoGreen = Color(0xFF2EC4B6);
const _duoGreenDark = Color(0xFF21968B);
const _duoBg = Color(0xFF131F2A);
const _duoPanel = Color(0xFF1C2A35);
const _duoLocked = Color(0xFF37464F);

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
            Expanded(child: center),
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
            title: tr ? 'Lig Nasıl Çalışır?' : 'How leagues work',
            body: tr
                ? 'Ders tamamladıkça puan kazanır, haftalık sıralamada yükselirsin.'
                : 'Earn points by completing lessons and climb the weekly ranking.');
      case _Section.quests:
        return RightInfoCard(
            tr: tr,
            title: tr ? 'Aylık Rozetler' : 'Monthly badges',
            body: tr
                ? 'Görevleri tamamla, bu ayın rozetini kazan.'
                : 'Complete quests to earn this month\'s badge.');
      case _Section.shop:
        return _RightSidebar(tr: tr);
      case _Section.profile:
        return ProfileListsRight(tr: tr);
      case _Section.more:
      case _Section.editProfile:
        return SettingsRight(
            tr: tr, onProfile: () => context.go('/settings/profile'));
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
      decoration: const BoxDecoration(
        color: _duoBg,
        border: Border(right: BorderSide(color: Color(0xFF24333D))),
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
          _NavItem(
              icon: Icons.person_rounded,
              color: const Color(0xFF1CB0F6),
              label: tr ? 'PROFİL' : 'PROFILE',
              active: section == _Section.profile,
              compact: compact,
              onTap: () => onSelect(_Section.profile)),
          _NavItem(
              icon: Icons.home_rounded,
              color: const Color(0xFFFF4B4B),
              label: tr ? 'ÖĞREN' : 'LEARN',
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
                      color: Colors.white54)),
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
              icon: Icons.menu_book_rounded,
              color: const Color(0xFF1CB0F6),
              label: tr ? 'SÖZLÜK' : 'DICTIONARY',
              active: section == _Section.dictionary,
              compact: compact,
              onTap: () => onSelect(_Section.dictionary)),
          _NavItem(
              icon: Icons.play_circle_outline_rounded,
              color: const Color(0xFFCE82FF),
              label: tr ? 'ALIŞTIRMA' : 'PRACTICE',
              active: section == _Section.video,
              compact: compact,
              onTap: () => onSelect(_Section.video)),
          _NavItem(
              icon: Icons.shield_rounded,
              color: const Color(0xFFFFC800),
              label: tr ? 'PUAN TABLOLARI' : 'LEADERBOARDS',
              active: section == _Section.leaderboard,
              compact: compact,
              onTap: () => onSelect(_Section.leaderboard)),
          _NavItem(
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFFFF9600),
              label: tr ? 'GÖREVLER' : 'QUESTS',
              active: section == _Section.quests,
              compact: compact,
              onTap: () => onSelect(_Section.quests)),
          _NavItem(
              icon: Icons.storefront_rounded,
              color: const Color(0xFFFF4B4B),
              label: tr ? 'MAĞAZA' : 'SHOP',
              active: section == _Section.shop,
              compact: compact,
              onTap: () => onSelect(_Section.shop)),
          _NavItem(
              icon: Icons.settings_rounded,
              color: const Color(0xFFCE82FF),
              label: tr ? 'AYARLAR' : 'SETTINGS',
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
  final Color color;
  final String label;
  final bool active;
  final bool compact;
  final VoidCallback onTap;
  final Widget? trailing;
  const _NavItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.active,
    required this.compact,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = active ? const Color(0xFF1CB0F6) : const Color(0xFFAFAFAF);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active ? const Color(0xFF1CB0F6).withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 0 : 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active
                      ? const Color(0xFF1CB0F6).withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 2),
            ),
            child: Row(
              mainAxisAlignment:
                  compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 26),
                if (!compact) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color: labelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
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
                    color: selected ? Colors.white : Colors.white70,
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
const double _kUnitHeight = 980;

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
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(ic, size: 11, color: Colors.white),
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
      loading: () => const Center(child: CircularProgressIndicator(color: _duoGreen)),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: Colors.white54))),
      data: (topics) {
        final progress = progressAsync.valueOrNull ?? const {};
        final topic = topics.firstWhere((t) => t.hsk == selectedHsk,
            orElse: () => topics.first);

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
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemExtent: _kUnitHeight,
          itemCount: topic.steps.length,
          itemBuilder: (_, i) => _UnitNodes(
            step: topic.steps[i],
            topic: topic,
            progress: progress,
            currentKey: current?.key,
            tr: tr,
          ),
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
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(seconds: 5))
    ..repeat();

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  Widget _mascot(double size) {
    return AnimatedBuilder(
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
          width: size, height: size, fit: BoxFit.contain),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final tr = widget.tr;
    final mirror = step.index.isOdd; // Ünite 2, 4, … = mirrored layout
    final city = cityForUnit(step.hsk, step.index);
    final hasInfo = kCityLandmarks[city.slug] != null;

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
        padding: const EdgeInsets.only(bottom: 36),
        child: GestureDetector(
          onTap: hasInfo ? () => setState(() => _infoOpen = true) : null,
          child: _mascot(156),
        ),
      ),
      phaseRow(2),
      phaseRow(3),
    ];

    return Column(
      children: [
        // Every unit — including Ünite 1 — starts with the horizontal line.
        Container(height: 1.5, color: Colors.white.withValues(alpha: 0.12)),
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
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 14),
                          Text(
                            tr
                                ? '${step.index + 1}. Ünite'
                                : 'Unit ${step.index + 1}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800),
                          ),
                          // Comfortable distance before the first circle.
                          const SizedBox(height: 44),
                          ...nodes,
                        ],
                      ),
                    ),
                    if (_infoOpen)
                      Positioned.fill(
                        child: _UnitInfoPanel(
                          step: step,
                          tr: tr,
                          onClose: () => setState(() => _infoOpen = false),
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
        color: const Color(0xFF18242F), // fully opaque
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C3B45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(cityDisplayName(city, tr: tr),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white60, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < landmarks.length; i++) ...[
                    Builder(builder: (_) {
                      final lm = landmarks[i];
                      final photo = assets.photo(i);
                      final descTr = photo.descTr?.isNotEmpty == true
                          ? photo.descTr!
                          : lm.descTr;
                      final descEn = photo.descEn?.isNotEmpty == true
                          ? photo.descEn!
                          : lm.descEn;
                      return Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFF101A22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 110,
                              height: 96,
                              child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const ColoredBox(
                                        color: Color(0xFF26323F)),
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
                                    Text(tr ? lm.nameTr : lm.nameEn,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(tr ? descTr : descEn,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white70,
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
          content: Text(tr
              ? 'Bu bölümde henüz video yok.'
              : 'No videos in this set yet.'),
        ));
        return;
      }
      if (ref.read(pathMetaProvider).hearts <= 0) {
        final next = ref.read(pathMetaProvider).nextHeartAt;
        final mins = next?.difference(DateTime.now()).inMinutes.clamp(0, 9999);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr
              ? 'Canın kalmadı. ${mins != null ? '~$mins dk sonra bir can dolacak.' : 'Yenilenmesini bekle.'}'
              : 'Out of hearts. ${mins != null ? 'A heart refills in ~$mins min.' : 'Wait to refill.'}'),
        ));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PhaseRunnerScreen(
          phase: phase,
          title:
              'L${phase.hsk} · ${tr ? 'Faz' : 'Phase'} ${phase.phaseIndex + 1}',
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
                color: available ? Colors.white : Colors.white30),
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
          available ? img : Opacity(opacity: 0.4, child: img),
          if (badge != null) Positioned(right: 8, bottom: 8, child: badge),
        ],
      );
    } else {
      // Generic city icon on the coloured circle (until a real icon is added).
      final topColor = available ? _duoGreen : _duoLocked;
      final shadow = available ? _duoGreenDark : const Color(0xFF2A363D);
      art = Container(
        width: 78,
        height: 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: topColor,
          borderRadius: BorderRadius.circular(39),
          boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 6))],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(ni.icon,
                size: 36,
                color: available ? Colors.white : Colors.white30),
            if (badge != null)
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
      padding: const EdgeInsets.only(bottom: 52),
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

  // A twinkling star at [dx,dy] from the node centre; [phase] staggers them.
  Widget _star(double dx, double dy, double phase, double size) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final a = 0.5 + 0.5 * sin(_c.value * 2 * pi + phase);
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: 0.15 + 0.75 * a,
            child: Icon(Icons.auto_awesome_rounded,
                size: size, color: const Color(0xFFFFE9A8)),
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
                    color: Colors.white
                        .withValues(alpha: widget.available ? 0.10 : 0.05),
                    borderRadius: const BorderRadius.all(
                        Radius.elliptical(43, 10)),
                  ),
                ),
              ),
              // Soft pulsing light behind unlocked nodes.
              if (widget.available)
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final a =
                        0.10 + 0.10 * (0.5 + 0.5 * sin(_c.value * 2 * pi));
                    return Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _duoGreen.withValues(alpha: a),
                            blurRadius: 28,
                            spreadRadius: 8,
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
              // Bouncing BAŞLAT pill above the current node.
              if (widget.isCurrent)
                Positioned(
                  top: -44,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, child) => Transform.translate(
                      offset:
                          Offset(0, 4 * sin(_c.value * 2 * pi)),
                      child: child,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _duoBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _duoGreen, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 8),
                        ],
                      ),
                      child: Text(
                        widget.tr ? 'BAŞLAT' : 'START',
                        style: const TextStyle(
                          color: _duoGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
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
                        tr ? 'Bu bölümün kelimeleri' : 'Words in this set',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white60, size: 20),
                    onPressed: onClose,
                    tooltip: tr ? 'Kapat' : 'Close',
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
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
                  '${tr ? 'Gramer' : 'Grammar'}: ${myG.map((g) => g.zh).join(' · ')}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800),
                ),
              ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: _duoGreen)),
                error: (e, _) => Center(
                    child: Text(tr ? 'Yüklenemedi' : 'Failed',
                        style: const TextStyle(color: Colors.white54))),
                data: (words) => words.isEmpty
                    ? Center(
                        child: Text(tr ? 'Kelime yok' : 'No words',
                            style: const TextStyle(color: Colors.white54)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: words.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 14),
                        itemBuilder: (_, i) {
                          final w = words[i];
                          final meaning = tr ? w.tr : w.en;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w.word,
                                  style: const TextStyle(
                                      color: Colors.white,
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
                                        style: const TextStyle(
                                            color: Colors.white70,
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
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF24333D))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat(icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF9600), value: '${meta.streak}'),
              _Stat(icon: Icons.diamond_rounded,
                  color: const Color(0xFF1CB0F6), value: '$score'),
              _Stat(icon: Icons.favorite_rounded,
                  color: const Color(0xFFFF4B4B), value: '${meta.hearts}'),
            ],
          ),
          const SizedBox(height: 20),
          _Card(
            title: tr ? 'İlerlemen' : 'Your progress',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '$donePhases / $totalPhases ${tr ? 'faz tamamlandı' : 'phases done'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalPhases == 0 ? 0 : donePhases / totalPhases,
                    minHeight: 10,
                    backgroundColor: _duoLocked,
                    valueColor: const AlwaysStoppedAnimation(_duoGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: tr ? 'Günlük Görev' : 'Daily quest',
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFFFC800), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tr ? 'Bir faz tamamla' : 'Complete one phase',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  const _Stat({required this.icon, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 22),
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
        border: Border.all(color: const Color(0xFF2C3B45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
