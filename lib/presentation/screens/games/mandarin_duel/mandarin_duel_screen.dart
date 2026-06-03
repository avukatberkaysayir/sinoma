import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/video_segment_model.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../providers/user_provider.dart';

// Maps each grammar category to a wheel-segment colour by index, so the palette
// works regardless of how many categories exist.
const _categoryPalette = [
  Color(0xFF2196F3), Color(0xFF3F51B5), Color(0xFF9C27B0), Color(0xFF009688),
  Color(0xFF00BCD4), Color(0xFF4CAF50), Color(0xFF8BC34A), Color(0xFFFF9800),
  Color(0xFF795548), Color(0xFFFF5722), Color(0xFFE91E63), Color(0xFFF44336),
  Color(0xFF607D8B), Color(0xFF673AB7), Color(0xFF03A9F4), Color(0xFF9E9E9E),
];

Color _categoryColor(QuizCategory c) =>
    c == QuizCategory.general
        ? const Color(0xFF9E9E9E)
        : _categoryPalette[c.index % _categoryPalette.length];

// =============================================================================
// Screen
// =============================================================================

class MandarinDuelScreen extends ConsumerStatefulWidget {
  const MandarinDuelScreen({super.key});

  @override
  ConsumerState<MandarinDuelScreen> createState() => _MandarinDuelScreenState();
}

class _MandarinDuelScreenState extends ConsumerState<MandarinDuelScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hskLevel = ref.read(currentHskLevelProvider);
      ref.read(mandarinDuelProvider(hskLevel).notifier).startGame();
    });
  }

  // Returns a callback for rewarded-ad life restore, or null if unavailable.
  VoidCallback? _buildRestoreLifeCallback(
      WidgetRef ref, MandarinDuelNotifier notifier) {
    final isPremium = ref.read(subscriptionProvider).isPremium;
    final adService = ref.read(adServiceProvider);
    if (isPremium || !adService.isRewardedAdReady) return null;
    return () {
      adService.showRewardedAd(
        onReward: () async => notifier.restoreOneLife(),
        onDismissed: () {},
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    final hskLevel = ref.watch(currentHskLevelProvider);
    final state = ref.watch(mandarinDuelProvider(hskLevel));
    final notifier = ref.read(mandarinDuelProvider(hskLevel).notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Mandarin Duel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: switch (state.status) {
          DuelStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          DuelStatus.error => _ErrorView(
              message: state.error ?? 'Unknown error',
              onRetry: notifier.startGame,
            ),
          DuelStatus.finished => _FinishedView(
              state: state,
              onPlayAgain: notifier.startGame,
              onHome: () => context.go('/home'),
              onRestoreLife: _buildRestoreLifeCallback(ref, notifier),
            ),
          DuelStatus.wheelSpinning => _WheelSection(
              key: ValueKey(state.currentRoundIndex),
              targetCategory:
                  state.currentRound?.category ?? QuizCategory.general,
              onSpinComplete: notifier.beginQuestion,
            ),
          _ => _GameView(
              state: state,
              onAnswer: notifier.submitAnswer,
              onNext: notifier.advanceRound,
              onSaveWords: notifier.saveTargetWords,
            ),
        },
      ),
    );
  }
}

// =============================================================================
// Category Wheel
// =============================================================================

class _WheelSection extends StatefulWidget {
  final QuizCategory targetCategory;
  final VoidCallback onSpinComplete;

  const _WheelSection({
    super.key,
    required this.targetCategory,
    required this.onSpinComplete,
  });

  @override
  State<_WheelSection> createState() => _WheelSectionState();
}

class _WheelSectionState extends State<_WheelSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // CW rotation formula: theta = 5 * 2π - targetIndex * (2π/6)
    // Wheel has 6 slices; map all 17 categories onto them with modulo.
    final idx = QuizCategory.values.indexOf(widget.targetCategory) % 6;
    final targetRad = 10 * pi - idx * (pi / 3);

    _rotation = Tween<double>(begin: 0, end: targetRad).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _ctrl.forward().whenComplete(() {
      // Brief pause so the user sees the wheel land before the question loads.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && !_fired) {
          _fired = true;
          widget.onSpinComplete();
        }
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.targetCategory;
    final catColor = _categoryColor(cat);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Spinning for category…',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          // Pointer arrow sits just above the wheel rim.
          const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 32),
          AnimatedBuilder(
            animation: _rotation,
            builder: (_, __) => Transform.rotate(
              angle: _rotation.value,
              child: const SizedBox(
                width: 240,
                height: 240,
                child: CustomPaint(painter: _WheelPainter()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final done = _ctrl.isCompleted;
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: done ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: catColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat.emoji,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Text(
                        cat.displayName,
                        style: TextStyle(
                          color: catColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  // 6 representative colours for the visual wheel (categories mapped with % 6).
  static const List<Color> _colors = [
    Color(0xFF2196F3), // baConstruct
    Color(0xFF3F51B5), // beiPassive
    Color(0xFF9C27B0), // shiDeEmphasis
    Color(0xFF009688), // conditional
    Color(0xFF00BCD4), // contrast
    Color(0xFF4CAF50), // causeEffect
  ];

  // Show emojis for the first 6 categories on the wheel.
  static final List<String> _emojis =
      QuizCategory.values.take(6).map((c) => c.emoji).toList();

  const _WheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const n = 6;
    const sweep = 2 * pi / n;

    final dividerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < n; i++) {
      // Segment i is centred at angle (-π/2 + i*sweep) from 12 o'clock.
      final start = -pi / 2 - sweep / 2 + i * sweep;

      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = _colors[i],
      );

      // Dividing line at the start edge.
      canvas.drawLine(
        centre,
        Offset(centre.dx + radius * cos(start), centre.dy + radius * sin(start)),
        dividerPaint,
      );

      // Emoji in the centre of the slice.
      final textAngle = start + sweep / 2;
      final tr = radius * 0.62;
      final tp = TextPainter(
        text: TextSpan(
            text: _emojis[i], style: const TextStyle(fontSize: 22)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          centre.dx + tr * cos(textAngle) - tp.width / 2,
          centre.dy + tr * sin(textAngle) - tp.height / 2,
        ),
      );
    }

    // White centre hub.
    canvas.drawCircle(centre, 18, Paint()..color = Colors.white);
    canvas.drawCircle(
        centre,
        18,
        Paint()
          ..color = AppColors.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// =============================================================================
// Game view (playing + answered)
// =============================================================================

class _GameView extends StatelessWidget {
  final DuelState state;
  final void Function(String) onAnswer;
  final VoidCallback onNext;
  final Future<void> Function() onSaveWords;

  const _GameView({
    required this.state,
    required this.onAnswer,
    required this.onNext,
    required this.onSaveWords,
  });

  @override
  Widget build(BuildContext context) {
    final round = state.currentRound;
    if (round == null) return const SizedBox.shrink();

    return Column(
      children: [
        _DuelHud(state: state),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              children: [
                if (state.status == DuelStatus.playing)
                  _TimerRing(seconds: state.secondsRemaining)
                else
                  const SizedBox(height: 72),
                const SizedBox(height: 16),
                _CategoryBadge(category: round.category),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    round.question,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                ...round.choices.map(
                  (choice) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AnswerButton(
                      answer: choice,
                      correctAnswer: round.correctAnswer,
                      selectedAnswer: state.selectedAnswer,
                      onTap: state.status == DuelStatus.playing
                          ? () => onAnswer(choice)
                          : null,
                    ),
                  ),
                ),
                if (state.status == DuelStatus.answered &&
                    state.wasCorrect == false &&
                    round.targetWords.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SaveWordButton(
                      saved: state.wordsSavedForCurrentRound,
                      onTap: onSaveWords,
                    ),
                  ),
                const Spacer(),
                if (state.status == DuelStatus.answered)
                  _NextButton(
                    onTap: onNext,
                    isLast: state.isLastRound,
                  ),
                const SizedBox(height: 10),
                Text(
                  'Round ${state.currentRoundIndex + 1} / ${state.totalRounds}',
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _DuelHud extends StatelessWidget {
  final DuelState state;
  const _DuelHud({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: Color(0x229E9E9E))),
      ),
      child: Row(
        children: [
          // Player score
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You',
                  style: TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 11)),
              Text(
                '${state.score}',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Lives
          Row(
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Icon(
                  i < state.livesRemaining
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: AppColors.wrongAnswer,
                  size: 18,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Bot score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🤖 Bot',
                  style: TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 11)),
              Text(
                '${state.botScore}',
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (state.combo >= 2) ...[
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🔥×${state.combo}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final QuizCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            category.displayName,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  final int seconds;
  const _TimerRing({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final fraction = seconds / 10.0;
    final color = seconds > 4
        ? AppColors.primary
        : seconds > 2
            ? Colors.orange
            : AppColors.wrongAnswer;

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: fraction,
            strokeWidth: 5,
            backgroundColor: const Color(0x229E9E9E),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '$seconds',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String answer;
  final String correctAnswer;
  final String? selectedAnswer;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.answer,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.surfaceVariant;
    Color textColor = AppColors.onSurface;

    if (selectedAnswer != null) {
      if (answer == correctAnswer) {
        bgColor = AppColors.correctAnswer;
        textColor = Colors.white;
      } else if (answer == selectedAnswer) {
        bgColor = AppColors.wrongAnswer;
        textColor = Colors.white;
      }
    }

    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Text(
                answer,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveWordButton extends StatelessWidget {
  final bool saved;
  final Future<void> Function() onTap;

  const _SaveWordButton({required this.saved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (saved) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.correctAnswer, size: 16),
          SizedBox(width: 6),
          Text(
            'Saved to Dictionary',
            style: TextStyle(
              color: AppColors.correctAnswer,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.bookmark_add_outlined, size: 16),
        label: const Text('Save to Dictionary'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withAlpha(180)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLast;
  const _NextButton({required this.onTap, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          isLast ? 'See Results' : 'Next →',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Finished screen
// =============================================================================

class _FinishedView extends StatelessWidget {
  final DuelState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;
  final VoidCallback? onRestoreLife;

  const _FinishedView({
    required this.state,
    required this.onPlayAgain,
    required this.onHome,
    this.onRestoreLife,
  });

  @override
  Widget build(BuildContext context) {
    final won = state.score > state.botScore && state.livesRemaining > 0;
    final survived = state.livesRemaining > 0;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            won ? '🏆' : survived ? '🎯' : '💔',
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            won
                ? '你赢了！'
                : survived
                    ? '对决完成！'
                    : '游戏结束',
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            won
                ? 'You beat the bot!'
                : survived
                    ? 'Duel Complete!'
                    : 'Game Over',
            style: const TextStyle(
                color: AppColors.onSurfaceMuted, fontSize: 16),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _StatRow(label: 'Your Score', value: '${state.score}'),
                const SizedBox(height: 10),
                _StatRow(label: 'Bot Score', value: '${state.botScore}'),
                const SizedBox(height: 10),
                _StatRow(
                    label: 'Lives Left', value: '${state.livesRemaining} / 3'),
                const SizedBox(height: 10),
                _StatRow(
                  label: 'Rounds',
                  value:
                      '${state.currentRoundIndex + 1} / ${state.totalRounds}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          if (!survived && onRestoreLife != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRestoreLife,
                icon: const Icon(Icons.play_circle_outline, color: Colors.white),
                label: const Text(
                  'Watch Ad — Restore 1 Life',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPlayAgain,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Play Again',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onHome,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurfaceMuted,
                side: const BorderSide(color: Color(0x449E9E9E)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Go Home'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.wrongAnswer, size: 48),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    color: AppColors.onSurface, fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('Try Again',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceMuted, fontSize: 15)),
        Text(value,
            style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
