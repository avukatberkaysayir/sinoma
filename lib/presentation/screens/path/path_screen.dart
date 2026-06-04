import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/video_segment_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/path_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/video_provider.dart';
import 'phase_runner_screen.dart';

// Duolingo-style colours.
const _duoGreen = Color(0xFF58CC02);
const _duoGreenDark = Color(0xFF4CAF00);
const _duoBg = Color(0xFF131F2A);
const _duoPanel = Color(0xFF1C2A35);
const _duoLocked = Color(0xFF37464F);

class PathScreen extends ConsumerStatefulWidget {
  const PathScreen({super.key});

  @override
  ConsumerState<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends ConsumerState<PathScreen> {
  bool _videoPanel = false;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final showRight = w >= 1100;
    final compactNav = w < 720;
    final tr = ref.watch(localeProvider).languageCode == 'tr';

    return Scaffold(
      backgroundColor: _duoBg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LeftNav(
              compact: compactNav,
              videoActive: _videoPanel,
              onLearn: () => setState(() => _videoPanel = false),
              onVideo: () => setState(() => _videoPanel = !_videoPanel),
              onDict: () => context.go('/dictionary'),
              onProfile: () => context.go('/profile'),
              tr: tr,
            ),
            Expanded(
              child: Stack(
                children: [
                  const _CenterPath(),
                  if (_videoPanel)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: _VideoSlideOut(
                        tr: tr,
                        onClose: () => setState(() => _videoPanel = false),
                      ),
                    ),
                ],
              ),
            ),
            if (showRight) _RightSidebar(tr: tr),
          ],
        ),
      ),
    );
  }
}

// ── Left navigation rail ──────────────────────────────────────────────────────

class _LeftNav extends StatelessWidget {
  final bool compact;
  final bool videoActive;
  final VoidCallback onLearn;
  final VoidCallback onVideo;
  final VoidCallback onDict;
  final VoidCallback onProfile;
  final bool tr;
  const _LeftNav({
    required this.compact,
    required this.videoActive,
    required this.onLearn,
    required this.onVideo,
    required this.onDict,
    required this.onProfile,
    required this.tr,
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
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 24, top: 4),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill, color: _duoGreen, size: 28),
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
          _NavItem(
              icon: Icons.home_rounded,
              label: tr ? 'ÖĞREN' : 'LEARN',
              active: !videoActive,
              compact: compact,
              onTap: onLearn),
          _NavItem(
              icon: Icons.menu_book_rounded,
              label: tr ? 'SÖZLÜK' : 'DICTIONARY',
              active: false,
              compact: compact,
              onTap: onDict),
          _NavItem(
              icon: Icons.play_circle_outline_rounded,
              label: 'VIDEO',
              active: videoActive,
              compact: compact,
              onTap: onVideo),
          _NavItem(
              icon: Icons.person_rounded,
              label: tr ? 'PROFİL' : 'PROFILE',
              active: false,
              compact: compact,
              onTap: onProfile),
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
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _duoGreen : const Color(0xFFAFAFAF);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active ? _duoGreen.withValues(alpha: 0.15) : Colors.transparent,
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
                  color: active ? _duoGreen.withValues(alpha: 0.6) : Colors.transparent,
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
                          color: color,
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

// ── Center path ───────────────────────────────────────────────────────────────

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
      error: (e, _) => Center(
          child: Text('$e',
              style: const TextStyle(color: Colors.white54))),
      data: (topics) {
        final progress = progressAsync.valueOrNull ?? const {};
        final topic = topics.firstWhere((t) => t.hsk == selectedHsk,
            orElse: () => topics.first);
        final withContent = {
          for (final t in topics)
            if (t.steps.isNotEmpty) t.hsk
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
        final currentStep = current == null
            ? (topic.steps.isNotEmpty ? topic.steps.first : null)
            : topic.steps[current.stepIndex];

        return Column(
          children: [
            _HskSelector(
              selected: selectedHsk,
              withContent: withContent,
              onSelect: (h) =>
                  ref.read(selectedTopicHskProvider.notifier).state = h,
            ),
            Expanded(
              child: topic.steps.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          tr
                              ? 'HSK $selectedHsk için içerik yakında.'
                              : 'Content for HSK $selectedHsk coming soon.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 15),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Column(
                              children: [
                                if (currentStep != null)
                                  _UnitHeader(step: currentStep, tr: tr),
                                for (final step in topic.steps)
                                  _StepBlock(
                                    step: step,
                                    topic: topic,
                                    progress: progress,
                                    currentKey: current?.key,
                                    tr: tr,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  opacity: withContent.contains(h) || selected == h ? 1 : 0.4,
                  child: GestureDetector(
                    onTap: () => onSelect(h),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected == h ? _duoGreen : _duoPanel,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('HSK $h',
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

// Green unit header card (Duolingo "1. KISIM, 1. ÜNİTE" + title + REHBER).
class _UnitHeader extends StatelessWidget {
  final PathStep step;
  final bool tr;
  const _UnitHeader({required this.step, required this.tr});

  @override
  Widget build(BuildContext context) {
    final theme = LifeCategory.labelFor(step.themeKey, isTr: tr);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _duoGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: _duoGreenDark, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tr ? 'HSK ${step.hsk}, ADIM' : 'HSK ${step.hsk}, STEP'} ${step.index + 1}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(theme,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
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
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('REHBER',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// One step: a section label + its phase nodes in a gentle zigzag.
class _StepBlock extends StatelessWidget {
  final PathStep step;
  final PathTopic topic;
  final Map<String, dynamic> progress;
  final String? currentKey;
  final bool tr;
  const _StepBlock({
    required this.step,
    required this.topic,
    required this.progress,
    required this.currentKey,
    required this.tr,
  });

  // Zigzag horizontal offsets, Duolingo-like.
  static const _offsets = [0.0, 48.0, 70.0, 48.0, 0.0, -48.0, -70.0, -48.0];

  @override
  Widget build(BuildContext context) {
    final theme = LifeCategory.labelFor(step.themeKey, isTr: tr);
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Divider(color: Color(0xFF2C3B45))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('${tr ? 'Adım' : 'Step'} ${step.index + 1} · $theme',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const Expanded(child: Divider(color: Color(0xFF2C3B45))),
        ]),
        const SizedBox(height: 8),
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
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PhaseRunnerScreen(
          phase: phase,
          title: 'HSK ${phase.hsk} · ${tr ? 'Faz' : 'Phase'} ${phase.phaseIndex + 1}',
        ),
      ));
      ref.invalidate(pathProgressProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          if (isCurrent)
            _StartBubble(tr: tr),
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
  final bool tr;
  const _StartBubble({required this.tr});

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
      child: Text(tr ? 'BAŞLAT' : 'START',
          style: const TextStyle(
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
    final score = ref.watch(currentUserProvider).valueOrNull?.stats.totalScore ?? 0;
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
          // Stat row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Stat(icon: Icons.local_fire_department_rounded,
                  color: Color(0xFFFF9600), value: '0'),
              _Stat(icon: Icons.diamond_rounded,
                  color: const Color(0xFF1CB0F6), value: '$score'),
              const _Stat(icon: Icons.favorite_rounded,
                  color: Color(0xFFFF4B4B), value: '5'),
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
                const Icon(Icons.bolt_rounded,
                    color: Color(0xFFFFC800), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      tr ? 'Bir faz tamamla' : 'Complete one phase',
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
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Video slide-out panel ─────────────────────────────────────────────────────

class _VideoSlideOut extends ConsumerWidget {
  final bool tr;
  final VoidCallback onClose;
  const _VideoSlideOut({required this.tr, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hsk = ref.watch(selectedHskFilterProvider);
    final life = ref.watch(selectedLifeCategoryProvider);

    void toggleHsk(int h) {
      final n = Set<int>.from(hsk);
      n.contains(h) ? n.remove(h) : n.add(h);
      ref.read(selectedHskFilterProvider.notifier).state = n;
      ref.invalidate(videoFeedProvider);
    }

    void toggleLife(String c) {
      final n = Set<String>.from(life);
      n.contains(c) ? n.remove(c) : n.add(c);
      ref.read(selectedLifeCategoryProvider.notifier).state = n;
      ref.invalidate(videoFeedProvider);
    }

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: _duoPanel,
        border: Border(right: BorderSide(color: Color(0xFF24333D))),
        boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(children: [
              Text(tr ? 'Serbest İzle' : 'Free watch',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: onClose),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FilterTitle('HSK'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var h = 1; h <= 6; h++)
                      _Chip(
                          label: 'HSK $h',
                          selected: hsk.contains(h),
                          onTap: () => toggleHsk(h)),
                  ]),
                  const SizedBox(height: 18),
                  _FilterTitle(tr ? 'Konu' : 'Topic'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in LifeCategory.values)
                      _Chip(
                          label: LifeCategory.labelFor(c.name, isTr: tr),
                          selected: life.contains(c.name),
                          onTap: () => toggleLife(c.name)),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: () => context.go('/video'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(tr ? 'İzlemeye Başla' : 'Start watching'),
                style: FilledButton.styleFrom(
                  backgroundColor: _duoGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTitle extends StatelessWidget {
  final String text;
  const _FilterTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _duoGreen : _duoBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _duoGreen : const Color(0xFF3A4A54)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
