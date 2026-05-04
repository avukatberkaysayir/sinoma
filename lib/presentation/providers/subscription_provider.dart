import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_provider.dart';

// Single source of truth for premium status across the entire app.
// All ad visibility and feature gate logic reads from here.
final subscriptionProvider = Provider<SubscriptionState>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return const SubscriptionState.loading();
  if (user.isPremium) return const SubscriptionState.premium();
  return const SubscriptionState.free();
});

sealed class SubscriptionState {
  const SubscriptionState();
  const factory SubscriptionState.loading() = _Loading;
  const factory SubscriptionState.free() = _Free;
  const factory SubscriptionState.premium() = _Premium;
}

class _Loading extends SubscriptionState { const _Loading(); }
class _Free extends SubscriptionState { const _Free(); }
class _Premium extends SubscriptionState { const _Premium(); }

extension SubscriptionStateX on SubscriptionState {
  bool get showAds => this is _Free;
  bool get isLoading => this is _Loading;
  bool get isPremium => this is _Premium;
}
