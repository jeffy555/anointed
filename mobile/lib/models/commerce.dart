/// `GET /v1/iap/product` — M-22 pricing fallback and the SKU id source of truth.
/// The store SDK supplies the localised display price on-device; these values are
/// what M-22 shows if the store lookup fails.
class IapProduct {
  const IapProduct({
    required this.productId,
    required this.priceDisplay,
    required this.priceAmountMinor,
    required this.priceCurrency,
    required this.unlocksLevelsFrom,
    required this.unlocksLevelsTo,
    required this.freeTierMaxLevel,
    required this.alreadyPurchased,
  });

  factory IapProduct.fromJson(Map<String, dynamic> json) => IapProduct(
        productId: '${json['product_id']}',
        priceDisplay: '${json['price_display'] ?? ''}',
        priceAmountMinor: (json['price_amount_minor'] as num?)?.toInt() ?? 0,
        priceCurrency: '${json['price_currency'] ?? 'INR'}',
        unlocksLevelsFrom: (json['unlocks_levels_from'] as num?)?.toInt() ?? 6,
        unlocksLevelsTo: (json['unlocks_levels_to'] as num?)?.toInt() ?? 100,
        freeTierMaxLevel: (json['free_tier_max_level'] as num?)?.toInt() ?? 5,
        alreadyPurchased: json['already_purchased'] == true,
      );

  final String productId;
  final String priceDisplay;
  final int priceAmountMinor;
  final String priceCurrency;
  final int unlocksLevelsFrom;
  final int unlocksLevelsTo;
  final int freeTierMaxLevel;
  final bool alreadyPurchased;
}

enum PurchaseOutcome {
  success('success'),
  nothingToRestore('nothing_to_restore'),
  alreadyOwned('already_owned'),
  invalid('invalid');

  const PurchaseOutcome(this.wireValue);

  final String wireValue;

  static PurchaseOutcome parse(Object? value) {
    for (final PurchaseOutcome outcome in PurchaseOutcome.values) {
      if (outcome.wireValue == value) return outcome;
    }
    return PurchaseOutcome.invalid;
  }
}

/// `GET /v1/iap/status` and the response to `POST /v1/iap/validate`.
/// Named `EntitlementStatus` rather than `PurchaseStatus` because the
/// in_app_purchase plugin exports its own `PurchaseStatus` enum, and the IAP
/// service needs both in one library.
class EntitlementStatus {
  const EntitlementStatus({
    required this.hasUnlock,
    required this.unlockStatus,
    required this.store,
    required this.transactionId,
    required this.validatedAt,
    required this.validatedByProvider,
    required this.outcome,
  });

  factory EntitlementStatus.fromJson(Map<String, dynamic> json) => EntitlementStatus(
        hasUnlock: json['has_unlock'] == true,
        unlockStatus: json['unlock_status'] as String?,
        store: json['store'] as String?,
        transactionId: json['transaction_id'] as String?,
        validatedAt: DateTime.tryParse('${json['validated_at']}'),
        validatedByProvider: json['validated_by_provider'] == true,
        outcome: PurchaseOutcome.parse(json['outcome']),
      );

  final bool hasUnlock;
  final String? unlockStatus;
  final String? store;
  final String? transactionId;
  final DateTime? validatedAt;

  /// False when the backend accepted the receipt through its dev validation path
  /// rather than a real store call. Surfaced so the Implementation Agent handoff
  /// on receipt edge cases has something concrete to assert against.
  final bool validatedByProvider;
  final PurchaseOutcome outcome;
}

/// `GET /v1/ads/config` — the client asks the server whether to initialise the ad
/// SDK at all. Under-13 accounts get `ads_enabled: false` and no unit ids
/// (design-spec §20), so a client that ignored the flag would still have nothing
/// to request an ad with.
class AdConfig {
  const AdConfig({
    required this.adsEnabled,
    required this.tagForChildDirectedTreatment,
    required this.personalizedAds,
    required this.appId,
    required this.interstitialUnitId,
    required this.everyNthLevel,
    required this.maxPerSession,
    required this.minLevel,
  });

  const AdConfig.disabled()
      : adsEnabled = false,
        tagForChildDirectedTreatment = true,
        personalizedAds = false,
        appId = null,
        interstitialUnitId = null,
        everyNthLevel = 3,
        maxPerSession = 0,
        minLevel = 4;

  factory AdConfig.fromJson(Map<String, dynamic> json) => AdConfig(
        adsEnabled: json['ads_enabled'] == true,
        tagForChildDirectedTreatment: json['tag_for_child_directed_treatment'] == true,
        personalizedAds: json['personalized_ads'] == true,
        appId: json['app_id'] as String?,
        interstitialUnitId: json['interstitial_unit_id'] as String?,
        everyNthLevel: (json['every_nth_level'] as num?)?.toInt() ?? 3,
        maxPerSession: (json['max_per_session'] as num?)?.toInt() ?? 2,
        minLevel: (json['min_level'] as num?)?.toInt() ?? 4,
      );

  final bool adsEnabled;
  final bool tagForChildDirectedTreatment;
  final bool personalizedAds;
  final String? appId;
  final String? interstitialUnitId;
  final int everyNthLevel;
  final int maxPerSession;
  final int minLevel;

  /// True only when ads are permitted *and* a real ad unit exists. Without a unit
  /// id there is nothing to load, so M-21 is skipped silently rather than showing
  /// an empty ad shell (design-spec §15 M-21 no-fill row).
  bool get isServable =>
      adsEnabled && interstitialUnitId != null && interstitialUnitId!.isNotEmpty;
}
