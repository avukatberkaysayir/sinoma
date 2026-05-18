import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  return ref.watch(userRepositoryProvider).watchCurrentUser();
});

final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.isPremium ?? false;
});

final currentHskLevelProvider = Provider<int>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.hskLevel ?? 1;
});

// The user's chosen definition language ('tr', 'en', 'vi'). Falls back to 'tr'.
final currentLanguageProvider = Provider<String>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.motherTongue ?? 'tr';
});
