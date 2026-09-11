import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/api_client.dart';
import '../models/commerce.dart';
import 'analytics_service.dart';

enum PurchaseFlowStatus {
  success,
  alreadyOwned,
  cancelled,
  failed,
  nothingToRestore,
  storeUnavailable,
}

class PurchaseFlowResult {
  const PurchaseFlowResult(this.status, {this.errorCode});

  final PurchaseFlowStatus status;

  /// Store or backend error code, for the M-24 support path. Never shown raw.
  final String? errorCode;

  bool get unlocked =>
      status == PurchaseFlowStatus.success || status == PurchaseFlowStatus.alreadyOwned;
}

/// IAP for the single levels 6-100 unlock SKU (design-spec §20).
///
/// The store is the source of the *localised* price; the backend is the source of
/// truth for the SKU id and for entitlement. A receipt is never trusted on-device:
/// it is replayed through `POST /v1/iap/validate` and the unlock only exists once
/// the server says so.
class IapService extends ChangeNotifier {
  IapService({
    required ApiClient api,
    required AnalyticsService analytics,
    InAppPurchase? iap,
  })  : _api = api,
        _analytics = analytics,
        _iap = iap ?? InAppPurchase.instance;

  final ApiClient _api;
  final AnalyticsService _analytics;
  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  IapProduct? _serverProduct;
  ProductDetails? _storeProduct;
  bool _storeAvailable = false;
  bool _initialised = false;

  /// Set while a buy or restore is awaiting a store callback.
  Completer<PurchaseFlowResult>? _pending;
  String _pendingTrigger = 'locked_level_tap';
  bool _pendingIsRestore = false;

  /// How long a silent `restorePurchases()` is given before it is read as
  /// "nothing to restore". See [_restoreTimedOut].
  static const Duration _restoreSilenceBudget = Duration(seconds: 8);

  /// Held so it can be cancelled the moment any flow resolves, rather than
  /// left armed over whatever comes next.
  Timer? _restoreTimeout;

  IapProduct? get serverProduct => _serverProduct;
  ProductDetails? get storeProduct => _storeProduct;
  bool get storeAvailable => _storeAvailable;

  /// True when M-22 should still show its price spinner.
  bool get priceLoading => _serverProduct == null && _storeProduct == null;

  /// Store price when the store answered, server fallback otherwise.
  String get displayPrice =>
      _storeProduct?.price ?? _serverProduct?.priceDisplay ?? '';

  bool get storePriceLoaded => _storeProduct != null;

  int get unlockFrom => _serverProduct?.unlocksLevelsFrom ?? 6;
  int get unlockTo => _serverProduct?.unlocksLevelsTo ?? 100;

  String get storeName => Platform.isIOS ? 'app_store' : 'google_play';

  /// Loads the SKU from the backend and then from the store, and subscribes to
  /// the purchase stream. Safe to call more than once.
  Future<void> ensureReady() async {
    if (_initialised) return;
    _initialised = true;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) {
        _completePending(PurchaseFlowResult(
          PurchaseFlowStatus.failed,
          errorCode: '$error',
        ));
      },
    );

    await refreshProduct();
  }

  Future<void> refreshProduct() async {
    try {
      final Map<String, dynamic> json = await _api.getJson('/v1/iap/product');
      _serverProduct = IapProduct.fromJson(json);
    } on ApiException catch (error) {
      if (kDebugMode) debugPrint('iap product fetch failed: ${error.code}');
    }
    notifyListeners();

    final IapProduct? product = _serverProduct;
    if (product == null) return;

    try {
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) {
        notifyListeners();
        return;
      }
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(<String>{product.productId});
      if (response.productDetails.isNotEmpty) {
        _storeProduct = response.productDetails.first;
      }
    } on Object catch (error) {
      // No store connection (emulator without Play Services, unconfigured
      // App Store Connect product). M-22 stays usable on the server price and
      // the buy button reports storeUnavailable rather than crashing.
      _storeAvailable = false;
      if (kDebugMode) debugPrint('store product lookup failed: $error');
    }
    notifyListeners();
  }

  /// Current entitlement straight from the server.
  Future<EntitlementStatus?> serverStatus() async {
    try {
      final Map<String, dynamic> json = await _api.getJson('/v1/iap/status');
      return EntitlementStatus.fromJson(json);
    } on ApiException {
      return null;
    }
  }

  /// M-22 "Unlock now".
  Future<PurchaseFlowResult> buy({required String trigger}) async {
    await ensureReady();

    final ProductDetails? details = _storeProduct;
    if (!_storeAvailable || details == null) {
      return const PurchaseFlowResult(PurchaseFlowStatus.storeUnavailable);
    }
    if (_pending != null) {
      return const PurchaseFlowResult(PurchaseFlowStatus.failed, errorCode: 'in_progress');
    }

    _analytics.track('purchase_initiated', properties: <String, Object?>{
      'store': storeName,
      'product_id': details.id,
      'price_local': details.price,
      'trigger': trigger,
    });

    final Completer<PurchaseFlowResult> completer = Completer<PurchaseFlowResult>();
    _pending = completer;
    _pendingTrigger = trigger;
    _pendingIsRestore = false;

    try {
      final bool started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started) {
        _completePending(const PurchaseFlowResult(
          PurchaseFlowStatus.failed,
          errorCode: 'buy_not_started',
        ));
      }
    } on Object catch (error) {
      _completePending(PurchaseFlowResult(
        PurchaseFlowStatus.failed,
        errorCode: '$error',
      ));
    }

    return completer.future;
  }

  /// M-25 Restore purchase. The store replays owned purchases through the same
  /// stream, and each one is validated by the backend with `trigger: restore`.
  Future<PurchaseFlowResult> restore() async {
    await ensureReady();

    if (!_storeAvailable) {
      // Falling back to the server entitlement matters here: a user who bought on
      // another device and signed in with Google/Apple already owns the unlock
      // server-side even if this device's store connection is unavailable.
      final EntitlementStatus? status = await serverStatus();
      if (status?.hasUnlock == true) {
        return const PurchaseFlowResult(PurchaseFlowStatus.alreadyOwned);
      }
      return const PurchaseFlowResult(PurchaseFlowStatus.storeUnavailable);
    }

    if (_pending != null) {
      return const PurchaseFlowResult(PurchaseFlowStatus.failed, errorCode: 'in_progress');
    }

    final Completer<PurchaseFlowResult> completer = Completer<PurchaseFlowResult>();
    _pending = completer;
    _pendingTrigger = 'restore';
    _pendingIsRestore = true;

    try {
      await _iap.restorePurchases();
    } on Object catch (error) {
      _completePending(PurchaseFlowResult(
        PurchaseFlowStatus.failed,
        errorCode: '$error',
      ));
      return completer.future;
    }

    _restoreTimeout?.cancel();
    _restoreTimeout = Timer(_restoreSilenceBudget, () => _restoreTimedOut(completer));

    return completer.future;
  }

  /// `restorePurchases()` emits nothing at all when the store account owns no
  /// matching purchase, so an absence of events has to be interpreted on a
  /// timer; without this the M-25 spinner would hang forever.
  ///
  /// Bound to the completer it was armed for, because the flow it was started
  /// for is not necessarily the flow that is running when it fires. A restore
  /// that fails at 2s completes and clears `_pending`; if the user then taps
  /// Buy, `_pending` is a *purchase* by the time this runs — and answering it
  /// with `nothingToRestore` would route them away from a transaction the store
  /// sheet may still be completing.
  Future<void> _restoreTimedOut(Completer<PurchaseFlowResult> owner) async {
    if (!identical(_pending, owner) || owner.isCompleted) return;
    final EntitlementStatus? status = await serverStatus();
    // serverStatus() is a round trip of its own; re-check rather than assume the
    // flow stood still across it.
    if (!identical(_pending, owner) || owner.isCompleted) return;
    _completePending(status?.hasUnlock == true
        ? const PurchaseFlowResult(PurchaseFlowStatus.alreadyOwned)
        : const PurchaseFlowResult(PurchaseFlowStatus.nothingToRestore));
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Store sheet is open or payment is deferred; nothing to do until it
          // resolves into one of the terminal states below.
          break;

        case PurchaseStatus.canceled:
          _analytics.track('purchase_cancelled', properties: <String, Object?>{
            'store': storeName,
            'trigger': _pendingTrigger,
          });
          await _finish(purchase);
          _completePending(const PurchaseFlowResult(PurchaseFlowStatus.cancelled));
          break;

        case PurchaseStatus.error:
          _analytics.track('purchase_failed', properties: <String, Object?>{
            'store': storeName,
            'error_code': purchase.error?.code ?? 'store_error',
            'trigger': _pendingTrigger,
          });
          await _finish(purchase);
          _completePending(PurchaseFlowResult(
            PurchaseFlowStatus.failed,
            errorCode: purchase.error?.code,
          ));
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final PurchaseFlowResult result = await _validate(purchase);
          await _finish(purchase);
          _completePending(result);
          break;
      }
    }
  }

  Future<PurchaseFlowResult> _validate(PurchaseDetails purchase) async {
    // Backend validates receipts (including Apple refunds via cancellation_date and
    // Google acknowledge within the 3-day window). Duplicate receipts on another
    // account return 409 receipt_already_used — surfaced to the user below.
    try {
      final String receipt = purchase.verificationData.serverVerificationData;
      final Map<String, dynamic> json = await _api.postJson(
        '/v1/iap/validate',
        body: <String, Object?>{
          'store': storeName,
          'receipt': receipt,
          'product_id': purchase.productID,
          'trigger': _pendingIsRestore ? 'restore' : _pendingTrigger,
        },
      );
      final EntitlementStatus status = EntitlementStatus.fromJson(json);

      switch (status.outcome) {
        case PurchaseOutcome.success:
          return const PurchaseFlowResult(PurchaseFlowStatus.success);
        case PurchaseOutcome.alreadyOwned:
          return const PurchaseFlowResult(PurchaseFlowStatus.alreadyOwned);
        case PurchaseOutcome.nothingToRestore:
          return const PurchaseFlowResult(PurchaseFlowStatus.nothingToRestore);
        case PurchaseOutcome.invalid:
          return const PurchaseFlowResult(
            PurchaseFlowStatus.failed,
            errorCode: 'validation_failed',
          );
      }
    } on ApiException catch (error) {
      if (error.code == 'receipt_already_used') {
        return const PurchaseFlowResult(
          PurchaseFlowStatus.failed,
          errorCode: 'receipt_already_used',
        );
      }
      return PurchaseFlowResult(PurchaseFlowStatus.failed, errorCode: error.code);
    }
  }

  Future<void> _finish(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('completePurchase failed: $error');
    }
  }

  void _completePending(PurchaseFlowResult result) {
    // Whatever resolved this flow, the restore fallback has nothing left to
    // answer for — disarm it here so it can never outlive the flow it belongs to.
    _restoreTimeout?.cancel();
    _restoreTimeout = null;

    final Completer<PurchaseFlowResult>? pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(result);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _restoreTimeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
