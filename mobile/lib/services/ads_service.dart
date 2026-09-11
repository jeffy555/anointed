import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../models/commerce.dart';
import '../models/session.dart';

/// Interstitial ads for 13+ players only (design-spec §20).
///
/// The single most important property of this class: for an under-13 account the
/// AdMob SDK is never initialised and no ad object is ever constructed. The
/// server also withholds the ad unit ids for those accounts, so there are two
/// independent barriers rather than one flag.
///
/// Server-side policy gate: under-13 never sees ads; production ads require
/// `ADMOB_PRODUCTION_ACK` on the backend (see docs/admob_coppa_checklist.md).
/// Live AdMob account configuration still requires human verification (C-11).
class AdsService extends ChangeNotifier {
  AdsService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  AdConfig _config = const AdConfig.disabled();
  bool _sdkInitialised = false;
  InterstitialAd? _loadedAd;
  bool _loading = false;

  /// Session cap from design-spec §20 ("max 2 interstitials per app session").
  /// Lives here rather than on the server because the server has no concept of
  /// an app session.
  int _adsShownThisSession = 0;

  AdConfig get config => _config;
  bool get sdkInitialised => _sdkInitialised;
  int get adsShownThisSession => _adsShownThisSession;

  /// Fetches the ad policy and, only if ads are permitted for this account,
  /// initialises the SDK. Called after the session is known.
  Future<void> configureFor(SessionUser user) async {
    if (!user.adsPermitted) {
      // Under-13 or not-yet-consented: do not even ask the server for a config,
      // and make sure any previously loaded ad is discarded.
      _config = const AdConfig.disabled();
      await disposeAd();
      notifyListeners();
      return;
    }

    try {
      final Map<String, dynamic> json = await _api.getJson('/v1/ads/config');
      _config = AdConfig.fromJson(json);
    } on ApiException catch (error) {
      if (kDebugMode) debugPrint('ad config fetch failed: ${error.code}');
      _config = const AdConfig.disabled();
    }

    if (!_config.isServable) {
      // No ad unit configured yet: ads are simply skipped. This is the expected
      // state until real AdMob unit ids are set in the backend environment.
      notifyListeners();
      return;
    }

    await _initialiseSdk();
    notifyListeners();
  }

  Future<void> _initialiseSdk() async {
    if (_sdkInitialised) return;
    try {
      // Request configuration must be set *before* initialize() so the very first
      // ad request already carries the child-directed treatment flag.
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          tagForChildDirectedTreatment: _config.tagForChildDirectedTreatment
              ? TagForChildDirectedTreatment.yes
              : TagForChildDirectedTreatment.no,
          maxAdContentRating: MaxAdContentRating.g,
        ),
      );
      await MobileAds.instance.initialize();
      _sdkInitialised = true;
    } on Object catch (error) {
      // A missing/invalid AdMob app id in the native manifest throws here. Ads
      // then stay off for the session; gameplay is unaffected.
      if (kDebugMode) debugPrint('AdMob init failed: $error');
      _sdkInitialised = false;
    }
  }

  /// design-spec §20 frequency rules, all of which must hold: the server says
  /// this completion is ad-eligible, the level is at or above the onboarding-grace
  /// floor, it is an Nth level, and the session cap is not yet reached.
  ///
  /// "Every 3rd level complete" is evaluated on the level number rather than a
  /// per-session completion count, because the spec's own worked example is
  /// "levels 3, 6, 9, 12…" — a player who replays level 4 repeatedly should not
  /// accumulate ad breaks.
  bool shouldShowInterstitial({
    required SessionUser user,
    required int levelNumber,
    required bool serverAdEligible,
  }) {
    if (!user.adsPermitted) return false;
    if (!serverAdEligible) return false;
    if (!_config.isServable) return false;
    if (levelNumber < _config.minLevel) return false;
    if (_config.everyNthLevel <= 0) return false;
    if (levelNumber % _config.everyNthLevel != 0) return false;
    if (_adsShownThisSession >= _config.maxPerSession) return false;
    return true;
  }

  /// Preloads an interstitial. Returns false if nothing could be loaded within
  /// the design-spec §15 two-second budget, in which case M-21 is skipped.
  Future<bool> loadInterstitial() async {
    if (!_config.isServable || !_sdkInitialised) return false;
    if (_loadedAd != null) return true;
    if (_loading) return false;

    _loading = true;
    final Completer<bool> completer = Completer<bool>();

    try {
      await InterstitialAd.load(
        adUnitId: _config.interstitialUnitId!,
        request: AdRequest(nonPersonalizedAds: !_config.personalizedAds),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _loadedAd = ad;
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (LoadAdError error) {
            // No-fill is normal and must stay invisible to the player.
            if (kDebugMode) debugPrint('interstitial no-fill: ${error.code}');
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } on Object catch (error) {
      if (kDebugMode) debugPrint('interstitial load threw: $error');
      if (!completer.isCompleted) completer.complete(false);
    }

    final bool loaded = await completer.future
        .timeout(AppConfig.adLoadTimeout, onTimeout: () => false);
    _loading = false;
    return loaded;
  }

  /// Shows the preloaded interstitial and resolves when it is dismissed.
  /// Returns false when there was nothing to show.
  Future<bool> showInterstitial({required int levelNumber}) async {
    final InterstitialAd? ad = _loadedAd;
    if (ad == null) return false;
    _loadedAd = null;

    final Completer<void> dismissed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (InterstitialAd _) {
        _adsShownThisSession++;
        _reportEvent('viewed', levelNumber: levelNumber);
      },
      onAdClicked: (InterstitialAd _) => _reportEvent('clicked', levelNumber: levelNumber),
      onAdDismissedFullScreenContent: (InterstitialAd disposed) {
        disposed.dispose();
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd disposed, AdError error) {
        if (kDebugMode) debugPrint('interstitial show failed: ${error.code}');
        disposed.dispose();
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );

    try {
      await ad.show();
    } on Object {
      ad.dispose();
      return false;
    }

    // Guard against a callback that never arrives so the player is not stranded
    // on the M-21 transition screen.
    await dismissed.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {},
    );
    return true;
  }

  /// Mirrors the impression into `AdImpressionLog` + analytics. The backend
  /// rejects these outright for under-13 accounts, which is what makes a client
  /// bug in the age gate loud instead of silent.
  void _reportEvent(String event, {required int levelNumber}) {
    _api
        .postJson('/v1/ads/events', body: <String, Object?>{
          'event': event,
          'ad_unit_id': _config.interstitialUnitId,
          'ad_format': 'interstitial',
          'placement': 'M-21_ad_break',
          'level_id': levelNumber,
        })
        .catchError((Object error) {
          if (kDebugMode) debugPrint('ad event report failed: $error');
          return <String, dynamic>{};
        });
  }

  Future<void> disposeAd() async {
    _loadedAd?.dispose();
    _loadedAd = null;
  }

  @override
  void dispose() {
    _loadedAd?.dispose();
    _loadedAd = null;
    super.dispose();
  }
}
