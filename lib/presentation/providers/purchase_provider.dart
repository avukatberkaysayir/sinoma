import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// Web stub — in-app purchases are not available on the web platform.
// Payment processing will be integrated via a web payment provider in a future update.
class PurchaseNotifier extends StateNotifier<PurchaseState> {
  PurchaseNotifier() : super(const PurchaseState());

  void selectPlan(PurchasePlan plan) {
    state = state.copyWith(selectedPlan: plan, status: PurchaseStatus.idle);
  }

  Future<void> initiatePurchase() async {
    state = state.copyWith(
      status: PurchaseStatus.error,
      errorMessage: 'Web subscriptions are coming soon. Thank you for your interest!',
    );
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(
      status: PurchaseStatus.error,
      errorMessage: 'Purchase restore is not available on web.',
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
