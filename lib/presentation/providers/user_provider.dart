import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import 'locale_provider.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  return ref.watch(userRepositoryProvider).watchCurrentUser();
});

// Wraps currentUserProvider and never exposes null/empty-photoUrl transients.
// On AsyncLoading / AsyncError → keeps previous value.
// On AsyncData(null) → clears (logout).
// On AsyncData(user) with empty photoUrl → preserves last known photoUrl.
// Use this everywhere a stable avatar is needed (SinomaTopBar, etc.).
class _StableUserNotifier extends StateNotifier<UserModel?> {
  _StableUserNotifier(Ref ref) : super(null) {
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, next) {
      if (next is AsyncData<UserModel?>) {
        final incoming = next.value;
        if (incoming == null) {
          state = null; // explicit logout
        } else {
          final prev = state;
          state = (incoming.photoUrl.isEmpty && prev?.photoUrl.isNotEmpty == true)
              ? incoming.copyWith(photoUrl: prev!.photoUrl)
              : incoming;
        }
      }
      // AsyncLoading / AsyncError → keep current state, avatar stays visible
    });
  }
}

final stableCurrentUserProvider =
    StateNotifierProvider<_StableUserNotifier, UserModel?>((ref) {
  return _StableUserNotifier(ref);
});

final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.isPremium ?? false;
});

final currentHskLevelProvider = Provider<int>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.hskLevel ?? 1;
});

// Definition language — follows the app locale ("Uygulama Dili" in profile).
// Changing the locale dropdown takes effect immediately without a save.
final currentLanguageProvider = Provider<String>((ref) {
  return ref.watch(localeProvider).languageCode;
});
