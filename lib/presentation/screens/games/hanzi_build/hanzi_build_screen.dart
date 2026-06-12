import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/user_provider.dart';

class HanziBuildScreen extends ConsumerStatefulWidget {
  const HanziBuildScreen({super.key});

  @override
  ConsumerState<HanziBuildScreen> createState() => _HanziBuildScreenState();
}

class _HanziBuildScreenState extends ConsumerState<HanziBuildScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hskLevel = ref.read(currentHskLevelProvider);
      ref.read(hanziBuildProvider(hskLevel).notifier).startGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hskLevel = ref.watch(currentHskLevelProvider);
    final state = ref.watch(hanziBuildProvider(hskLevel));
    final notifier = ref.read(hanziBuildProvider(hskLevel).notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Hanzi Build'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: switch (state.status) {
          HanziBuildStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          HanziBuildStatus.error => _ErrorView(
              message: state.error ?? 'Unknown error',
              onRetry: notifier.startGame,
            ),
          HanziBuildStatus.finished => _FinishedView(
              state: state,
              onPlayAgain: notifier.startGame,
              onHome: () => context.go('/learn'),
            ),
          _ => _GameView(
              state: state,
              onToggle: notifier.toggleTile,
              onSubmit: notifier.submitAnswer,
              onNext: notifier.advanceRound,
              onHint: notifier.requestHint,
              onDismissHint: notifier.dismissHint,
            ),
        },
      ),
    );
  }
}

// =============================================================================
// Game View
// =============================================================================

class _GameView extends StatelessWidget {
  final HanziBuildState state;
  final void Function(String) onToggle;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final VoidCallback onHint;
  final VoidCallback onDismissHint;

  const _GameView({
    required this.state,
    required this.onToggle,
    required this.onSubmit,
    required this.onNext,
    required this.onHint,
    required this.onDismissHint,
  });

  @override
  Widget build(BuildContext context) {
    final round = state.currentRound;
    if (round == null) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context).languageCode;
    final definition = switch (locale) {
      'tr' => round.definitions.tr,
      'ko' => round.definitions.ko.isNotEmpty
          ? round.definitions.ko
          : round.definitions.en,
      'vi' => round.definitions.vi.isNotEmpty
          ? round.definitions.vi
          : round.definitions.en,
      _ => round.definitions.en,
    };

    return Stack(
      children: [
        Column(
          children: [
            _BuildHud(state: state),
            _TimerBar(
              seconds: state.secondsRemaining,
              maxSeconds: 20,
              playing: state.status == HanziBuildStatus.playing,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    Text(
                      round.simplified,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 88,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      round.pinyin,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      definition,
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (state.status == HanziBuildStatus.answered)
                      _ResultBanner(
                        wasCorrect: state.wasCorrect ?? false,
                        correctRadicals: round.correctRadicals,
                      ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select the radicals that form this character:',
                        style: TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SelectedRow(selectedTiles: state.selectedTiles),
                    const SizedBox(height: 20),
                    _TileGrid(
                      tiles: round.tiles,
                      selectedTiles: state.selectedTiles,
                      enabled: state.status == HanziBuildStatus.playing,
                      onTap: onToggle,
                    ),
                    const SizedBox(height: 28),
                    if (state.status == HanziBuildStatus.playing)
                      Row(
                        children: [
                          Expanded(
                            child: _SubmitButton(
                              enabled: state.selectedTiles.isNotEmpty,
                              onTap: onSubmit,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _HintButton(onTap: onHint),
                        ],
                      )
                    else
                      _NextButton(
                        isLast: state.currentRoundIndex >=
                            state.totalRounds - 1,
                        onTap: onNext,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Round ${state.currentRoundIndex + 1} / ${state.totalRounds}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Hint overlay
        if (state.showingHint)
          _HintOverlay(
            definition: definition,
            pinyin: round.pinyin,
            onDismiss: onDismissHint,
          ),
      ],
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _BuildHud extends StatelessWidget {
  final HanziBuildState state;
  const _BuildHud({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: Color(0x229E9E9E))),
      ),
      child: Row(
        children: [
          Text(
            '${state.score}',
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          const Text('pts',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
          const Spacer(),
          if (state.combo >= 2)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🔥 ×${state.combo}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimerBar extends StatelessWidget {
  final int seconds;
  final int maxSeconds;
  final bool playing;

  const _TimerBar({
    required this.seconds,
    required this.maxSeconds,
    required this.playing,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (seconds / maxSeconds).clamp(0.0, 1.0);
    final color = seconds > 10
        ? AppColors.primary
        : seconds > 5
            ? Colors.orange
            : AppColors.wrongAnswer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        LinearProgressIndicator(
          value: fraction,
          backgroundColor: const Color(0x229E9E9E),
          valueColor: AlwaysStoppedAnimation<Color>(
              playing ? color : const Color(0x229E9E9E)),
          minHeight: 4,
        ),
        if (playing)
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: Text(
              '${seconds}s',
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _SelectedRow extends StatelessWidget {
  final List<String> selectedTiles;
  const _SelectedRow({required this.selectedTiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x339E9E9E)),
      ),
      child: selectedTiles.isEmpty
          ? const Text(
              'Tap radicals below to select them',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
              textAlign: TextAlign.center,
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedTiles
                  .map((t) =>
                      _TileChip(radical: t, selected: true, enabled: false))
                  .toList(),
            ),
    );
  }
}

class _TileGrid extends StatelessWidget {
  final List<String> tiles;
  final List<String> selectedTiles;
  final bool enabled;
  final void Function(String) onTap;

  const _TileGrid({
    required this.tiles,
    required this.selectedTiles,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: tiles
          .map((t) => _TileChip(
                radical: t,
                selected: selectedTiles.contains(t),
                enabled: enabled,
                onTap: enabled ? () => onTap(t) : null,
              ))
          .toList(),
    );
  }
}

class _TileChip extends StatelessWidget {
  final String radical;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _TileChip({
    required this.radical,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withAlpha(40)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected ? AppColors.primary : const Color(0x449E9E9E),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            radical,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final bool wasCorrect;
  final List<String> correctRadicals;

  const _ResultBanner({
    required this.wasCorrect,
    required this.correctRadicals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: wasCorrect ? AppColors.correctAnswer : AppColors.wrongAnswer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                wasCorrect ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                wasCorrect ? '正确！ Correct!' : '错了！ Wrong!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (!wasCorrect && correctRadicals.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Radicals: ${correctRadicals.join('  ')}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HintButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x449E9E9E)),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.lightbulb_outline, color: AppColors.premiumGold),
        tooltip: 'Hint',
      ),
    );
  }
}

class _HintOverlay extends StatelessWidget {
  final String definition;
  final String pinyin;
  final VoidCallback onDismiss;

  const _HintOverlay({
    required this.definition,
    required this.pinyin,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // Prevent dismiss when tapping the card itself.
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.premiumGold),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lightbulb,
                          color: AppColors.premiumGold, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Hint',
                        style: TextStyle(
                          color: AppColors.premiumGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    pinyin,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    definition,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text(
                      'Got it',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _SubmitButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: const Color(0x449E9E9E),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text(
        'Submit',
        style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final bool isLast;
  final VoidCallback onTap;
  const _NextButton({required this.isLast, required this.onTap});

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
              fontSize: 16),
        ),
      ),
    );
  }
}

// =============================================================================
// Finished + Error screens
// =============================================================================

class _FinishedView extends StatelessWidget {
  final HanziBuildState state;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  const _FinishedView({
    required this.state,
    required this.onPlayAgain,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            '完成了！',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Build Complete!',
              style:
                  TextStyle(color: AppColors.onSurfaceMuted, fontSize: 16)),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _StatRow(label: 'Score', value: '${state.score}'),
                const SizedBox(height: 10),
                _StatRow(
                    label: 'Rounds', value: '${state.totalRounds}'),
              ],
            ),
          ),
          const SizedBox(height: 40),
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
