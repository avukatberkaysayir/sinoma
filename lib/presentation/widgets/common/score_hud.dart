import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/video_provider.dart';

class ScoreHud extends StatelessWidget {
  final VideoPlaybackState state;

  const ScoreHud({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildHearts(),
          _buildScore(),
          _buildCombo(),
        ],
      ),
    );
  }

  Widget _buildHearts() {
    return Row(
      children: List.generate(3, (i) {
        return Icon(
          i < state.hearts ? Icons.favorite : Icons.favorite_border,
          color: AppColors.wrongAnswer,
          size: 20,
        );
      }),
    );
  }

  Widget _buildScore() {
    return Text(
      '${state.score}',
      style: TextStyle(
        color: AppColors.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCombo() {
    if (state.combo < 2) return const SizedBox(width: 60);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '×${state.comboMultiplier} COMBO',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
