import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../providers/ai_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/user_provider.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final queryParams = GoRouterState.of(context).uri.queryParameters;
    final justPurchased = queryParams['success'] == '1';

    ref.read(analyticsServiceProvider).logSubscriptionScreenViewed();

    if (justPurchased && !isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Your premium access is being activated.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      });
    }

    return Scaffold(
      body: ConstrainedPage(
        maxWidth: 640,
        child: isPremium ? const _PremiumActiveView() : const _PaywallView(),
      ),
    );
  }
}

// ── Premium Active ─────────────────────────────────────────────────────────────

class _PremiumActiveView extends StatelessWidget {
  const _PremiumActiveView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium,
                size: 80, color: AppColors.premiumGold),
            const SizedBox(height: 16),
            Text(
              'You\'re Premium! 🎉',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All features are unlocked. Enjoy your learning journey!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceMuted),
            ),
            const SizedBox(height: 32),
            ..._features.map((f) => _FeatureRow(feature: f, unlocked: true)),
            const SizedBox(height: 32),
            Consumer(
              builder: (context, ref, _) {
                final status = ref.watch(purchaseProvider).status;
                final loading = status == PurchaseStatus.loading;
                return OutlinedButton(
                  onPressed: loading
                      ? null
                      : () => ref.read(purchaseProvider.notifier).openBillingPortal(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.onSurfaceMuted),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Manage Subscription',
                          style: TextStyle(color: AppColors.onSurfaceMuted)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Paywall ────────────────────────────────────────────────────────────────────

class _PaywallView extends ConsumerWidget {
  const _PaywallView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PremiumHeader(),
          const SizedBox(height: 8),
          const _FeatureTable(),
          const SizedBox(height: 24),
          _PlanSelector(state: state),
          const SizedBox(height: 24),
          _SubscribeButton(state: state),
          const SizedBox(height: 12),
          _RestoreButton(state: state),
          const SizedBox(height: 16),
          const _Footer(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF2D1B00)],
        ),
      ),
      // Fixed light text: the banner gradient stays dark in both themes.
      child: const Column(
        children: [
          Icon(Icons.workspace_premium,
              size: 56, color: AppColors.premiumGold),
          SizedBox(height: 12),
          Text(
            'Unlock Full Access',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEEEEEE),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Unlimited AI explanations, no ads, all games unlocked.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9E9E9E), height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Feature Table ──────────────────────────────────────────────────────────────

const _features = [
  (label: 'Ad-free experience', free: 'Ads between clips', premium: '✓ No ads'),
  (label: 'AI Dictionary', free: '5 credits/day', premium: '✓ Unlimited'),
  (label: 'Mandarin Duel', free: '10 games/day', premium: '✓ Unlimited'),
  (label: 'Hanzi Build', free: '10 games/day', premium: '✓ Unlimited'),
  (label: 'Offline mode', free: '✗', premium: '✓ Coming soon'),
  (label: 'Priority support', free: '✗', premium: '✓'),
];

class _FeatureTable extends StatelessWidget {
  const _FeatureTable();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const _FeatureTableHeader(),
            Divider(height: 1, color: AppColors.surface),
            ..._features.asMap().entries.map((e) => _FeatureTableRow(
                  feature: e.value,
                  isLast: e.key == _features.length - 1,
                )),
          ],
        ),
      ),
    );
  }
}

class _FeatureTableHeader extends StatelessWidget {
  const _FeatureTableHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(flex: 3, child: SizedBox()),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'Free',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.premiumGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Premium',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.premiumGold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTableRow extends StatelessWidget {
  final ({String label, String free, String premium}) feature;
  final bool isLast;
  const _FeatureTableRow({required this.feature, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isLast) Divider(height: 1, color: AppColors.surface),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  feature.label,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    feature.free,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    feature.premium,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.premiumGold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final ({String label, String free, String premium}) feature;
  final bool unlocked;
  const _FeatureRow({required this.feature, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: unlocked ? AppColors.correctAnswer : AppColors.wrongAnswer,
          ),
          const SizedBox(width: 8),
          Text(feature.label,
              style: TextStyle(color: AppColors.onSurface)),
          const Spacer(),
          Text(
            unlocked ? feature.premium : feature.free,
            style: TextStyle(
              color:
                  unlocked ? AppColors.premiumGold : AppColors.onSurfaceMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan Selector ──────────────────────────────────────────────────────────────

class _PlanSelector extends ConsumerWidget {
  final PurchaseState state;
  const _PlanSelector({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _PlanCard(
              plan: PurchasePlan.monthly,
              price: '\$9.99',
              period: 'per month',
              badge: null,
              selected: state.selectedPlan == PurchasePlan.monthly,
              onTap: () => ref
                  .read(purchaseProvider.notifier)
                  .selectPlan(PurchasePlan.monthly),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PlanCard(
              plan: PurchasePlan.annual,
              price: '\$69.99',
              period: 'per year',
              badge: 'Save 42%',
              selected: state.selectedPlan == PurchasePlan.annual,
              onTap: () => ref
                  .read(purchaseProvider.notifier)
                  .selectPlan(PurchasePlan.annual),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PurchasePlan plan;
  final String price;
  final String period;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.price,
    required this.period,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              )
            else
              const SizedBox(height: 22),
            Text(
              price,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color:
                    selected ? AppColors.onSurface : AppColors.onSurfaceMuted,
              ),
            ),
            Text(
              period,
              style: TextStyle(
                  fontSize: 12, color: AppColors.onSurfaceMuted),
            ),
            if (plan == PurchasePlan.annual)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '= \$5.83/mo',
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? AppColors.correctAnswer
                        : AppColors.onSurfaceMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Subscribe Button ───────────────────────────────────────────────────────────

class _SubscribeButton extends ConsumerWidget {
  final PurchaseState state;
  const _SubscribeButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = state.status == PurchaseStatus.loading;
    final notifier = ref.read(purchaseProvider.notifier);

    if (state.status == PurchaseStatus.error && state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              action: SnackBarAction(
                label: 'OK',
                onPressed: notifier.clearError,
              ),
            ),
          );
          notifier.clearError();
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FilledButton(
        onPressed: loading ? null : notifier.initiatePurchase,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                state.selectedPlan == PurchasePlan.annual
                    ? 'Start Annual Plan — \$69.99/yr'
                    : 'Start Monthly Plan — \$9.99/mo',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}

// ── Restore Button ─────────────────────────────────────────────────────────────

class _RestoreButton extends ConsumerWidget {
  final PurchaseState state;
  const _RestoreButton({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = state.status == PurchaseStatus.loading;
    return Center(
      child: TextButton(
        onPressed:
            loading ? null : ref.read(purchaseProvider.notifier).restorePurchases,
        child: Text(
          'Restore Purchases',
          style: TextStyle(color: AppColors.onSurfaceMuted),
        ),
      ),
    );
  }
}

// ── Footer ─────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Subscription auto-renews. Cancel any time via Manage Subscription.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.push('/legal/terms'),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(
                  'Terms of Service',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.onSurfaceMuted),
                ),
              ),
              Text(' · ',
                  style: TextStyle(color: AppColors.onSurfaceMuted)),
              TextButton(
                onPressed: () => context.push('/legal/privacy'),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.onSurfaceMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
