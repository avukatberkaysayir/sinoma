import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum PurchasePlan { monthly, annual }

enum PurchaseStatus { idle, loading, success, error }

class PurchaseState {
  final PurchasePlan selectedPlan;
  final PurchaseStatus status;
  final String? errorMessage;

  const PurchaseState({
    this.selectedPlan = PurchasePlan.annual,
    this.status = PurchaseStatus.idle,
    this.errorMessage,
  });

  PurchaseState copyWith({
    PurchasePlan? selectedPlan,
    PurchaseStatus? status,
    String? errorMessage,
  }) =>
      PurchaseState(
        selectedPlan: selectedPlan ?? this.selectedPlan,
        status: status ?? this.status,
        errorMessage: errorMessage,
      );
}

class PurchaseNotifier extends StateNotifier<PurchaseState> {
  PurchaseNotifier() : super(const PurchaseState());

  void selectPlan(PurchasePlan plan) {
    state = state.copyWith(selectedPlan: plan, status: PurchaseStatus.idle);
  }

  Future<void> initiatePurchase() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) {
      state = state.copyWith(
        status: PurchaseStatus.error,
        errorMessage: 'Please sign in to subscribe.',
      );
      return;
    }

    state = state.copyWith(status: PurchaseStatus.loading);

    try {
      final plan = state.selectedPlan == PurchasePlan.annual ? 'annual' : 'monthly';
      final res = await client.functions.invoke(
        'create-checkout-session',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {
          'plan': plan,
          'successUrl': 'https://sinoma-two.vercel.app/subscription?success=1',
          'cancelUrl': 'https://sinoma-two.vercel.app/subscription',
        },
      );

      if (res.status != 200) {
        throw Exception('Server error ${res.status}');
      }

      final url = (res.data as Map<String, dynamic>)['url'] as String?;
      if (url == null) throw Exception('No checkout URL returned');

      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open payment page.');
      }
      state = state.copyWith(status: PurchaseStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: PurchaseStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> openBillingPortal() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    state = state.copyWith(status: PurchaseStatus.loading);

    try {
      final res = await client.functions.invoke(
        'create-portal-session',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {'returnUrl': 'https://sinoma-two.vercel.app/subscription'},
      );

      if (res.status != 200) throw Exception('Server error ${res.status}');

      final url = (res.data as Map<String, dynamic>)['url'] as String?;
      if (url == null) throw Exception('No portal URL returned');

      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open billing portal.');
      }
      state = state.copyWith(status: PurchaseStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: PurchaseStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(
      status: PurchaseStatus.error,
      errorMessage: 'To restore access, use the Manage Subscription button or contact support@sinoma.app',
    );
  }

  void clearError() {
    state = state.copyWith(status: PurchaseStatus.idle, errorMessage: null);
  }
}

final purchaseProvider =
    StateNotifierProvider.autoDispose<PurchaseNotifier, PurchaseState>(
  (_) => PurchaseNotifier(),
);
