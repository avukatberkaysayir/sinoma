import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/cities.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/path_provider.dart';
import '../../providers/user_provider.dart';
import '../dictionary/dictionary_screen.dart';
import '../profile/profile_screen.dart';
import 'path_sections.dart';
import 'phase_runner_screen.dart';

// Duolingo-style colours.
const _duoGreen = Color(0xFF58CC02);
const _duoGreenDark = Color(0xFF4CAF00);
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
        center = HomeDashboard(tr: tr, onStart: () => context.go('/learn'));
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
        return RightInfoCard(
            tr: tr,
            title: tr ? 'Etkinlik' : 'Activity',
            body: tr
                ? 'Arkadaş etkinliği yakında burada görünecek.'
                : 'Friend activity will appear here soon.');
      case _Section.more:
      case _Section.editProfile:
        return SettingsRight(
            tr: tr, onProfile: () => context.go('/settings/profile'));
      default:
        return null;
    }
  }
}

// ── Left navigation rail ──────────────────────────────────────────────────────

class _LeftNav extends StatelessWidget {
  final bool compact;
  final _Section section;
  final bool tr;
  final void Function(_Section) onSelect;
  const _LeftNav({
    required this.compact,
    required this.section,
    required this.tr,
    required this.onSelect,
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
                  const Icon(Icons.play_circle_fill,
                      color: _duoGreen, size: 28),
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
              onTap: () => onSelect(_Section.learn)),
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
  const _NavItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.active,
    required this.compact,
    required this.onTap,
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
                  Text(label,
                      style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Center path (learn) ───────────────────────────────────────────────────────

const double _kUnitHeight = 520; // fixed height per unit section (5 nodes)
// Switch the banner exactly when the boundary line between two units reaches the
// top of the list (right under the banner). 0 = align the switch with the line.
const double _kBannerLead = 0;

Color _unitColor(PathStep step) {
  if (step.title == '—') return _duoLocked; // truly empty placeholder
  const palette = [
    Color(0xFF58CC02), // green
    Color(0xFFCE82FF), // purple
    Color(0xFF1CB0F6), // blue
    Color(0xFFFF9600), // orange
    Color(0xFFFF4B4B), // red
    Color(0xFF2BC4C4), // teal
    Color(0xFFFFC800), // yellow
  ];
  return palette[step.index % palette.length];
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

// The icon for a unit's nodes: a real landmark asset when one is bundled, else a
// generic themed icon (override > deterministic spread).
({String? asset, IconData icon}) _cityNodeIcon(int hsk, int unitIndex) {
  final c = cityForUnit(hsk, unitIndex);
  final asset =
      kCityIconAssets.contains(c.slug) ? 'assets/cities/${c.slug}.png' : null;
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
  int _topUnit = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // Switch the banner once the next unit's title rises to just under it
    // (the boundary), not after a full unit has scrolled past.
    final u = ((_scroll.offset + _kBannerLead) / _kUnitHeight)
        .floor()
        .clamp(0, kUnitsPerLevel - 1);
    if (u != _topUnit) setState(() => _topUnit = u);
  }

  @override
  Widget build(BuildContext context) {
    final curriculum = ref.watch(curriculumProvider);
    final progressAsync = ref.watch(pathProgressProvider);
    final selectedHsk = ref.watch(selectedTopicHskProvider);
    final tr = ref.watch(localeProvider).languageCode == 'tr';

    return curriculum.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _duoGreen)),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: Colors.white54))),
      data: (topics) {
        final progress = progressAsync.valueOrNull ?? const {};
        final topic = topics.firstWhere((t) => t.hsk == selectedHsk,
            orElse: () => topics.first);
        final withContent = {
          for (final t in topics)
            if (t.steps.any((s) => s.hasContent)) t.hsk
        };

        // The single "current" phase across the topic.
        final flat = <PathPhase>[for (final s in topic.steps) ...s.phases];
        PathPhase? current;
        for (final p in flat) {
          if (!progress.phase(p.key).done &&
              isPhaseUnlocked(topic, p, progress)) {
            current = p;
            break;
          }
        }

        final topUnit = _topUnit.clamp(0, topic.steps.length - 1);
        final bannerStep = topic.steps[topUnit];

        return Column(
          children: [
            _HskSelector(
              selected: selectedHsk,
              withContent: withContent,
              onSelect: (h) {
                ref.read(selectedTopicHskProvider.notifier).state = h;
                if (_scroll.hasClients) _scroll.jumpTo(0);
                setState(() => _topUnit = 0);
              },
            ),
            // Single banner that swaps to the unit currently at the top — no
            // stacking/overlap.
            _UnitBanner(step: bannerStep, tr: tr, color: _unitColor(bannerStep)),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                // Trailing space so the LAST unit can scroll up into the banner
                // trigger zone — otherwise the final unit (e.g. Ünite 24) could
                // never become the top unit and never show in the banner.
                final tail = (constraints.maxHeight - _kUnitHeight + _kBannerLead)
                    .clamp(60.0, double.infinity);
                return ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.only(bottom: tail),
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
              }),
            ),
          ],
        );
      },
    );
  }
}

class _HskSelector extends StatelessWidget {
  final int selected;
  final Set<int> withContent;
  final void Function(int) onSelect;
  const _HskSelector({
    required this.selected,
    required this.withContent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var h = 1; h <= 6; h++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Opacity(
                  opacity: withContent.contains(h) || selected == h ? 1 : 0.5,
                  child: GestureDetector(
                    onTap: () => onSelect(h),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected == h ? _duoGreen : _duoPanel,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('L$h',
                          style: TextStyle(
                              color:
                                  selected == h ? Colors.white : Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Single colored unit banner (the one currently at the top of the scroll).
class _UnitBanner extends StatelessWidget {
  final PathStep step;
  final bool tr;
  final Color color;
  const _UnitBanner(
      {required this.step, required this.tr, required this.color});

  @override
  Widget build(BuildContext context) {
    final city = cityForUnit(step.hsk, step.index);
    final bannerAsset = kCityBannerAssets.contains(city.slug)
        ? 'assets/banners/${city.slug}.png'
        : null;
    const shadow = [Shadow(color: Color(0xCC000000), blurRadius: 6)];
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('L${step.hsk} · ${tr ? 'ÜNİTE' : 'UNIT'} ${step.index + 1}',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  shadows: bannerAsset != null ? shadow : null)),
          const SizedBox(height: 3),
          Text('${city.zh}  ${city.pinyin}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: bannerAsset != null ? shadow : null)),
        ],
      ),
    );
    return Container(
      color: _duoBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  offset: const Offset(0, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: bannerAsset == null
                ? Container(
                    width: double.infinity, color: color, child: content)
                : Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(bannerAsset, fit: BoxFit.cover),
                      ),
                      // Left-weighted dark gradient so the city name stays legible
                      // over the illustration.
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.62),
                                Colors.black.withValues(alpha: 0.12),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: double.infinity, child: content),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// The 4 phase circles of a unit (zigzag).
class _UnitNodes extends StatelessWidget {
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

  // Zigzag x-offsets for the 5 nodes per unit: phase1(center) → phase2(right) →
  // REWARD(center) → phase3(left) → phase4(center). First & last circle aligned.
  static const _r = 74.0;
  static const _slots = [0.0, _r, 0.0, -_r, 0.0];

  @override
  Widget build(BuildContext context) {
    final city = cityForUnit(step.hsk, step.index);
    final label = '${city.zh}  ${city.pinyin}';
    // Interleave the 4 phase steps with a reward node in the middle (index 2).
    final nodes = <Widget>[];
    var slot = 0;
    for (var i = 0; i < step.phases.length; i++) {
      if (i == 2) {
        nodes.add(Transform.translate(
          offset: Offset(_slots[slot++], 0),
          child: _RewardNode(rewardKey: 'r.hsk${step.hsk}.u${step.index}'),
        ));
      }
      nodes.add(Transform.translate(
        offset: Offset(_slots[slot++], 0),
        child: _PhaseNode(
          phase: step.phases[i],
          topic: topic,
          progress: progress,
          isCurrent: step.phases[i].key == currentKey,
          tr: tr,
          browseLeft: i >= 2, // 3rd & 4th circles: gözat on the left
        ),
      ));
    }
    // The unit's content fills the fixed item height; a divider sits at the very
    // bottom = the boundary line between this unit and the next. The banner swaps
    // to the next unit exactly when this line reaches the top (see _onScroll).
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              // Full width so the zigzag-translated nodes stay inside the bounds
              // and remain tappable (a shrink-wrapped column clipped hit area).
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    // Per-unit caption (the city name for this unit).
                    Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...nodes,
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(height: 1.5, color: Colors.white.withValues(alpha: 0.12)),
      ],
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
    final unlocked = isPhaseUnlocked(topic, phase, progress);
    final done = pp.done;

    // Cities with a real landmark icon drop the circle and show the icon alone
    // (a test for now); the rest keep the coloured circle with a generic themed
    // icon. State stays legible: a small corner badge (lock when locked, check
    // when done).
    final ni = _cityNodeIcon(phase.hsk, phase.stepIndex);
    final available = done || unlocked;
    Widget? badge;
    if (done) {
      badge = _nodeBadge(Icons.check_rounded, _duoGreenDark);
    } else if (!unlocked) {
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

    final Widget circle;
    if (ni.asset != null) {
      // Real landmark icon — no circle behind it.
      final img =
          Image.asset(ni.asset!, width: 72, height: 72, fit: BoxFit.contain);
      circle = GestureDetector(
        onTap: open,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 76,
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              available ? img : Opacity(opacity: 0.4, child: img),
              if (badge != null)
                Positioned(right: 4, bottom: 4, child: badge),
            ],
          ),
        ),
      );
    } else {
      // Generic city icon on the coloured circle (until a real icon is added).
      final topColor = available ? _duoGreen : _duoLocked;
      final shadow = available ? _duoGreenDark : const Color(0xFF2A363D);
      circle = GestureDetector(
        onTap: open,
        child: Container(
          width: 74,
          height: 70,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: topColor,
            borderRadius: BorderRadius.circular(38),
            boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 6))],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(ni.icon,
                  size: 34,
                  color: available ? Colors.white : Colors.white30),
              if (badge != null)
                Positioned(right: -3, bottom: -3, child: badge),
            ],
          ),
        ),
      );
    }
    // Every slot carries vocabulary; words are fetched when opened.
    final browse = _BrowseButton(
      tr: tr,
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => _SlotWordPanel(
          level: phase.hsk,
          unit: phase.stepIndex + 1,
          phase: phase.phaseIndex + 1,
          tr: tr,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: browseLeft
                ? [browse, const SizedBox(width: 8), circle]
                : [circle, const SizedBox(width: 8), browse],
          ),
        ],
      ),
    );
  }
}

// Round speech-bubble "gözat" button (icon only) next to a circle.
class _BrowseButton extends StatelessWidget {
  final bool tr;
  final VoidCallback onTap;
  const _BrowseButton({required this.tr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _duoPanel,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black54,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.12), width: 1.5),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: Colors.white70, size: 19),
        ),
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
  const _SlotWordPanel(
      {required this.level,
      required this.unit,
      required this.phase,
      required this.tr});

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
    return Dialog(
      backgroundColor: _duoPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                    onPressed: () => Navigator.of(context).pop(),
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

// Reward chest in the middle of each unit. Tap (once) to claim points.
const _rewardGold = Color(0xFFFFC800);
const _rewardGoldDark = Color(0xFFE0A800);

class _RewardNode extends ConsumerWidget {
  final String rewardKey;
  const _RewardNode({required this.rewardKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(pathProgressProvider).valueOrNull ?? const {};
    final rewards = progress['__rewards'];
    final claimed = rewards is Map && rewards[rewardKey] == true;
    final tr = ref.watch(localeProvider).languageCode == 'tr';

    Future<void> claim() async {
      final ok = await ref.read(userRepositoryProvider).claimReward(rewardKey);
      if (!context.mounted) return;
      if (ok) {
        ref.invalidate(pathProgressProvider);
        ref.invalidate(currentUserProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(tr ? '+20 puan kazandın! 🎉' : '+20 points! 🎉'),
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: claimed ? null : claim,
        child: Container(
          width: 64,
          height: 60,
          decoration: BoxDecoration(
            color: claimed ? _duoLocked : _rewardGold,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: claimed ? const Color(0xFF2A363D) : _rewardGoldDark,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Icon(
            claimed ? Icons.redeem_rounded : Icons.card_giftcard_rounded,
            color: claimed ? Colors.white30 : Colors.white,
            size: 32,
          ),
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
