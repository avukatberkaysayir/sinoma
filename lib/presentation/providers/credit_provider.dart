import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_provider.dart';

final aiCreditsProvider = Provider<int>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.aiCredits ?? 0;
});

final canUseAiProvider = Provider<bool>((ref) {
  final isPremium = ref.watch(isPremiumProvider);
  final credits = ref.watch(aiCreditsProvider);
  return isPremium || credits > 0;
});
