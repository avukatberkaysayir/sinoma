import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart' as iap;

// IAP product IDs — must match Play Console / App Store Connect exactly.
const kProductMonthly = 'mandarin_academy_premium_monthly';
const kProductAnnual = 'mandarin_academy_premium_annual';

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
  PurchaseNotifier() : super(const PurchaseState()) {
    if (!kIsWeb) _init();
  }

  StreamSubscription<List<iap.PurchaseDetails>>? _purchaseSub;
  List<iap.ProductDetails> _products = [];

  Future<void> _init() async {
    final available = await iap.InAppPurchase.instance.isAvailable();
    if (!available) return;

    _purchaseSub = iap.InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object e) {
        if (mounted) {
          state = state.copyWith(
            status: PurchaseStatus.error,
            errorMessage: e.toString(),
          );
        }
      },
    );

    final response = await iap.InAppPurchase.instance
        .queryProductDetails({kProductMonthly, kProductAnnual});
    _products = response.productDetails;
  }

  void selectPlan(PurchasePlan plan) {
    state = state.copyWith(selectedPlan: plan, status: PurchaseStatus.idle);
  }

  Future<void> initiatePurchase() async {
    if (kIsWeb) {
      state = state.copyWith(
        status: PurchaseStatus.error,
        errorMessage: 'Purchases are only available in the Android app.',
      );
      return;
    }

    final productId = state.selectedPlan == PurchasePlan.monthly
        ? kProductMonthly
        : kProductAnnual;

    final details = _products.cast<iap.ProductDetails?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );

    if (details == null) {
      state = state.copyWith(
        status: PurchaseStatus.error,
        errorMessage: 'Product not available. Please try again later.',
      );
      return;
    }

    state = state.copyWith(status: PurchaseStatus.loading);
    final purchaseParam = iap.PurchaseParam(productDetails: details);
    await iap.InAppPurchase.instance
        .buyNonConsumable(purchaseParam: purchaseParam);
    // Result arrives via purchaseStream → _handlePurchaseUpdates
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    state = state.copyWith(status: PurchaseStatus.loading);
    await iap.InAppPurchase.instance.restorePurchases();
    // Restored purchases arrive via purchaseStream → _handlePurchaseUpdates
  }

  Future<void> _handlePurchaseUpdates(
      List<iap.PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == iap.PurchaseStatus.pending) continue;

      if (purchase.status == iap.PurchaseStatus.error) {
        if (mounted) {
          state = state.copyWith(
            status: PurchaseStatus.error,
            errorMessage: purchase.error?.message ?? 'Purchase failed.',
          );
        }
      } else if (purchase.status == iap.PurchaseStatus.purchased ||
          purchase.status == iap.PurchaseStatus.restored) {
        await _verifyAndActivate(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await iap.InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndActivate(iap.PurchaseDetails purchase) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyPurchase');
      await callable.call({
        'productId': purchase.productID,
        'purchaseToken': purchase.verificationData.serverVerificationData,
        'source': purchase.verificationData.source,
      });
      // CF sets isPremium=true in Firestore; currentUserProvider stream auto-updates.
      if (mounted) {
        state = state.copyWith(status: PurchaseStatus.success);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        state = state.copyWith(
          status: PurchaseStatus.error,
          errorMessage: e.message ?? 'Verification failed.',
        );
      }
    }
  }

  void clearError() {
    state = state.copyWith(status: PurchaseStatus.idle);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}

final purchaseProvider =
    StateNotifierProvider.autoDispose<PurchaseNotifier, PurchaseState>(
  (_) => PurchaseNotifier(),
);
