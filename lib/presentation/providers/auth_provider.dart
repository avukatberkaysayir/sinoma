import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const adminEmail = 'berkaysayir@gmail.com';

final authStateProvider = StreamProvider<Session?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session);
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.user.id;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUidProvider) != null;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.user.email == adminEmail;
});

final isGuestProvider = Provider<bool>((ref) {
  final session = ref.watch(authStateProvider).valueOrNull;
  return session?.user.isAnonymous ?? false;
});
