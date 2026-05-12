import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const adminEmail = 'berkaysayir@gmail.com';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUidProvider) != null;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.email == adminEmail;
});

final isGuestProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user?.isAnonymous ?? false;
});
