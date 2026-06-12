import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/ai_provider.dart';

enum _RewardStatus { idle, watching, granted, noAd }

class RewardAdWidget extends ConsumerStatefulWidget {
  const RewardAdWidget({super.key});

  @override
  ConsumerState<RewardAdWidget> createState() => _RewardAdWidgetState();
}

class _RewardAdWidgetState extends ConsumerState<RewardAdWidget> {
  _RewardStatus _status = _RewardStatus.idle;

  /// Tracks whether the user earned the reward so onDismissed doesn't
  /// override the granted state while the CF call is still in-flight.
  bool _rewardEarned = false;

  Future<void> _watchAd() async {
    final adService = ref.read(adServiceProvider);

    if (!adService.isRewardedAdReady) {
      setState(() => _status = _RewardStatus.noAd);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _status == _RewardStatus.noAd) {
          setState(() => _status = _RewardStatus.idle);
        }
      });
      return;
    }

    _rewardEarned = false;
    setState(() => _status = _RewardStatus.watching);

    await adService.showRewardedAd(
      onReward: () async {
        _rewardEarned = true;
        ref.read(analyticsServiceProvider).logRewardedAdWatched('ai_credits');
        try {
          await ref.read(creditServiceProvider).grantCreditsFromAd(amount: 10);
          if (mounted) setState(() => _status = _RewardStatus.granted);
        } catch (_) {
          // CF failed — credits not granted, return to idle so user can retry.
          if (mounted) setState(() => _status = _RewardStatus.idle);
        }
      },
      onDismissed: () {
        // Only reset if reward was NOT earned (user dismissed early).
        if (mounted && !_rewardEarned) {
          setState(() => _status = _RewardStatus.idle);
        }
        _rewardEarned = false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _RewardStatus.idle => _buildIdle(),
      _RewardStatus.watching => _buildWatching(),
      _RewardStatus.granted => _buildGranted(),
      _RewardStatus.noAd => _buildNoAd(),
    };
  }

  Widget _buildIdle() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _watchAd,
        icon: const Icon(Icons.play_circle_outline, size: 18),
        label: const Text('Watch Ad for +10 credits'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2E4A7A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildWatching() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: const Text('Ad playing…'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2E4A7A),
          foregroundColor: Colors.white54,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildGranted() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x224CAF50),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.hsk1, size: 18),
          SizedBox(width: 8),
          Text(
            '+10 credits added!',
            style: TextStyle(
              color: AppColors.hsk1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAd() {
    return Text(
      'No ad available right now. Try again in a moment.',
      style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
      textAlign: TextAlign.center,
    );
  }
}
