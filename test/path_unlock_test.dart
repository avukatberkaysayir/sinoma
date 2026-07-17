// The HSK test picks the entry point; progress opens the rest. These cases are
// the rule as Berkay stated it (2026-07-17), checked at EVERY level rather than
// at the HSK 4 example he happened to give.
import 'package:flutter_test/flutter_test.dart';
import 'package:sinoma/data/models/video_segment_model.dart';
import 'package:sinoma/presentation/providers/path_provider.dart';

PathPhase _phase(int hsk, int unit, int idx, {bool withVideo = true}) => PathPhase(
      hsk: hsk,
      stepIndex: unit,
      phaseIndex: idx,
      videos: withVideo ? [VideoSegmentModel.fromMap(const {})] : const [],
    );

List<PathTopic> _curriculum() => [
      for (var hsk = 1; hsk <= 6; hsk++)
        PathTopic(
          hsk: hsk,
          steps: [
            for (var u = 0; u < 3; u++)
              PathStep(
                hsk: hsk,
                index: u,
                title: 'u$u',
                grammarName: 'g',
                phases: [for (var p = 0; p < 2; p++) _phase(hsk, u, p)],
              ),
          ],
        ),
    ];

bool _unlocked(List<PathTopic> topics, int hsk, int unit, int phase,
        {required int userHsk,
        Map<String, dynamic> progress = const {},
        bool isAdmin = false}) =>
    isPhaseUnlocked(
      topics.firstWhere((t) => t.hsk == hsk),
      topics.firstWhere((t) => t.hsk == hsk).steps[unit].phases[phase],
      progress,
      userHsk,
      topics,
      isAdmin,
    );

void main() {
  final topics = _curriculum();

  test('no test result → only L1 Ünite 1 Bölüm 1', () {
    expect(_unlocked(topics, 1, 0, 0, userHsk: 1), isTrue);
    expect(_unlocked(topics, 1, 0, 1, userHsk: 1), isFalse);
    expect(_unlocked(topics, 1, 1, 0, userHsk: 1), isFalse);
    // The chain must cross levels: L2's first phase stays shut.
    expect(_unlocked(topics, 2, 0, 0, userHsk: 1), isFalse);
  });

  // Berkay named HSK 4, but the rule is the rule at every level.
  for (final lvl in [2, 3, 4, 5, 6]) {
    test('tested HSK $lvl → only L$lvl Ünite 1 Bölüm 1 opens', () {
      expect(_unlocked(topics, lvl, 0, 0, userHsk: lvl), isTrue);
      expect(_unlocked(topics, lvl, 0, 1, userHsk: lvl), isFalse);
      expect(_unlocked(topics, lvl, 1, 0, userHsk: lvl), isFalse);
      if (lvl < 6) {
        expect(_unlocked(topics, lvl + 1, 0, 0, userHsk: lvl), isFalse);
      }
      // Levels below the tested one stay open — the test proved them.
      for (var below = 1; below < lvl; below++) {
        expect(_unlocked(topics, below, 2, 1, userHsk: lvl), isTrue);
      }
    });
  }

  test('finishing a phase opens the next one', () {
    final progress = {'hsk3.s0.p0': {'done': true}};
    expect(_unlocked(topics, 3, 0, 1, userHsk: 3, progress: progress), isTrue);
    expect(_unlocked(topics, 3, 1, 0, userHsk: 3, progress: progress), isFalse);
  });

  test('a level opens only once the one before it is finished', () {
    final done = <String, dynamic>{
      for (var u = 0; u < 3; u++)
        for (var p = 0; p < 2; p++) 'hsk2.s$u.p$p': {'done': true},
    };
    expect(_unlocked(topics, 3, 0, 0, userHsk: 2, progress: done), isTrue);
    // One phase short → still shut.
    final almost = Map<String, dynamic>.from(done)..remove('hsk2.s2.p1');
    expect(_unlocked(topics, 3, 0, 0, userHsk: 2, progress: almost), isFalse);
  });

  test('admin sees the whole path at every level', () {
    for (final lvl in [1, 2, 3, 4, 5, 6]) {
      expect(_unlocked(topics, lvl, 2, 1, userHsk: 1, isAdmin: true), isTrue);
    }
  });

  test('entry phase follows the tested level', () {
    for (final lvl in [1, 2, 3, 4, 5, 6]) {
      expect(currentPhaseFor(topics, const {}, lvl)?.hsk, lvl);
      expect(currentPhaseFor(topics, const {}, lvl)?.key, 'hsk$lvl.s0.p0');
    }
  });
}
