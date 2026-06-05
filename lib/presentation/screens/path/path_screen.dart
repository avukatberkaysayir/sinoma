import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
              label: 'VIDEO',
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

class _CenterPath extends ConsumerWidget {
  const _CenterPath();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        return Column(
          children: [
            _HskSelector(
              selected: selectedHsk,
              withContent: withContent,
              onSelect: (h) =>
                  ref.read(selectedTopicHskProvider.notifier).state = h,
            ),
            Expanded(
              // Pinned colored banner per unit (Duolingo-style): as you scroll
              // into a unit its banner stays at the top and its colour changes.
              child: CustomScrollView(
                slivers: [
                  for (final step in topic.steps) ...[
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _UnitBannerDelegate(
                          step: step, tr: tr, color: _unitColor(step)),
                    ),
                    SliverToBoxAdapter(
                      child: _UnitNodes(
                        step: step,
                        topic: topic,
                        progress: progress,
                        currentKey: current?.key,
                        tr: tr,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Color _unitColor(PathStep step) {
    if (step.grammarName == null) return _duoLocked;
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

// Pinned, colored unit banner (changes per unit as you scroll).
class _UnitBannerDelegate extends SliverPersistentHeaderDelegate {
  final PathStep step;
  final bool tr;
  final Color color;
  _UnitBannerDelegate(
      {required this.step, required this.tr, required this.color});

  @override
  double get minExtent => 86;
  @override
  double get maxExtent => 86;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final hasGrammar = step.grammarName != null;
    final title =
        hasGrammar ? grammarLabel(step.grammarName, tr: tr) : (tr ? 'Yakında' : 'Soon');
    return Container(
      color: _duoBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'L${step.hsk} · ${tr ? 'ÜNİTE' : 'UNIT'} ${step.index + 1}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 3),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {},
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.menu_book_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 5),
                      Text('REHBER',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _UnitBannerDelegate old) =>
      old.step.hsk != step.hsk ||
      old.step.index != step.index ||
      old.color != color ||
      old.tr != tr;
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

  static const _offsets = [0.0, 48.0, 70.0, 48.0, 0.0, -48.0, -70.0, -48.0];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            const SizedBox(height: 14),
            for (var i = 0; i < step.phases.length; i++)
              Transform.translate(
                offset: Offset(_offsets[i % _offsets.length], 0),
                child: _PhaseNode(
                  phase: step.phases[i],
                  topic: topic,
                  progress: progress,
                  isCurrent: step.phases[i].key == currentKey,
                  tr: tr,
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
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
  const _PhaseNode({
    required this.phase,
    required this.topic,
    required this.progress,
    required this.isCurrent,
    required this.tr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pp = progress.phase(phase.key);
    final unlocked = isPhaseUnlocked(topic, phase, progress);
    final done = pp.done;

    final Color top;
    final Color shadow;
    final Widget icon;
    if (done) {
      top = _duoGreen;
      shadow = _duoGreenDark;
      icon = const Icon(Icons.check_rounded, color: Colors.white, size: 34);
    } else if (unlocked) {
      top = _duoGreen;
      shadow = _duoGreenDark;
      icon = const Icon(Icons.star_rounded, color: Colors.white, size: 38);
    } else {
      top = _duoLocked;
      shadow = const Color(0xFF2A363D);
      icon = const Icon(Icons.lock_rounded, color: Colors.white38, size: 26);
    }

    Future<void> open() async {
      if (!unlocked) return;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          if (isCurrent) const _StartBubble(),
          GestureDetector(
            onTap: open,
            child: Container(
              width: 74,
              height: 70,
              decoration: BoxDecoration(
                color: top,
                borderRadius: BorderRadius.circular(38),
                boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 6))],
              ),
              child: icon,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartBubble extends StatelessWidget {
  const _StartBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Text('BAŞLAT',
          style: TextStyle(
              color: _duoGreen, fontSize: 14, fontWeight: FontWeight.w800)),
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
