import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// On-device persistence.
///
/// Two tiers on purpose: the session token is a bearer credential and lives in
/// the platform keychain/keystore, while everything else is non-sensitive UI and
/// cache state in SharedPreferences. design-spec §19 keeps `local_content_version`
/// and `last_manifest_check_at` on-device only.
class LocalStore {
  LocalStore(this._prefs, this._secure);

  static const String _kSessionToken = 'session_token';
  static const String _kInstallId = 'install_id';
  static const String _kThemeMode = 'theme_mode';
  static const String _kLargeText = 'large_text';
  static const String _kNotificationsOptIn = 'notifications_opt_in';
  static const String _kNotifyPromptShown = 'notify_prompt_shown';
  static const String _kContentVersion = 'local_content_version';
  static const String _kLastManifestCheck = 'last_manifest_check_at';
  static const String _kPackPublishedAt = 'pack_published_at';
  static const String _kFreshnessBannerVersion = 'freshness_banner_seen_version';
  static const String _kAnalyticsQueue = 'analytics_queue';
  static const String _kCachedProfile = 'cached_profile';
  static const String _kCachedLevelMap = 'cached_level_map';
  static const String _kCachedLeaderboard = 'cached_leaderboard';
  static const String _kLeaderboardCachedAt = 'leaderboard_cached_at';
  static const String _kForceUpgradeCache = 'force_upgrade_cache';
  static const String _kDevOAuthSubject = 'dev_oauth_subject_';
  static const String _kLastSessionAt = 'last_session_at';
  static const String _kCurrentLevel = 'current_level';
  static const String _kKidsZoneCompletedStops = 'kids_zone_completed_stops';
  static const String _kKidsZoneStars = 'kids_zone_stars';
  static const String _kKidsZoneTutorialPrefix = 'kids_zone_tutorial_';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static Future<LocalStore> open() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return LocalStore(
      prefs,
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      ),
    );
  }

  // ----------------------------------------------------------------- session

  Future<String?> readSessionToken() async {
    try {
      return await _secure.read(key: _kSessionToken);
    } on Object {
      // A keystore that cannot be read (device migration, corrupted keychain
      // entry) must degrade to "signed out" rather than crashing the launch path.
      return null;
    }
  }

  Future<void> writeSessionToken(String token) async {
    try {
      await _secure.write(key: _kSessionToken, value: token);
    } on Object {
      // Nothing useful to do: the in-memory token still serves this session.
    }
  }

  Future<void> clearSessionToken() async {
    try {
      await _secure.delete(key: _kSessionToken);
    } on Object {
      // Ignored — sign-out still clears in-memory state.
    }
  }

  /// Random per-install UUID used for the abuse controls in design-spec §21.
  /// Deliberately not a device fingerprint: it resets on reinstall, which is the
  /// documented tradeoff for not fingerprinting children.
  String installId() {
    final String? existing = _prefs.getString(_kInstallId);
    if (existing != null && existing.isNotEmpty) return existing;
    final String generated = const Uuid().v4();
    _prefs.setString(_kInstallId, generated);
    return generated;
  }

  /// Stable dev-mode OAuth subject per provider, so a dev sign-in restores the
  /// same account across app restarts instead of creating a new one each time.
  String devOAuthSubject(String provider) {
    final String key = '$_kDevOAuthSubject$provider';
    final String? existing = _prefs.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final String generated = const Uuid().v4().substring(0, 8);
    _prefs.setString(key, generated);
    return generated;
  }

  // ---------------------------------------------------------------- settings

  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String value) => _prefs.setString(_kThemeMode, value);

  bool get largeText => _prefs.getBool(_kLargeText) ?? false;
  Future<void> setLargeText(bool value) => _prefs.setBool(_kLargeText, value);

  bool get notificationsOptIn => _prefs.getBool(_kNotificationsOptIn) ?? false;
  Future<void> setNotificationsOptIn(bool value) =>
      _prefs.setBool(_kNotificationsOptIn, value);

  bool get notifyPromptShown => _prefs.getBool(_kNotifyPromptShown) ?? false;
  Future<void> setNotifyPromptShown(bool value) =>
      _prefs.setBool(_kNotifyPromptShown, value);

  int get currentLevel => _prefs.getInt(_kCurrentLevel) ?? 1;
  Future<void> setCurrentLevel(int value) => _prefs.setInt(_kCurrentLevel, value);

  DateTime? get lastSessionAt {
    final String? raw = _prefs.getString(_kLastSessionAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastSessionAt(DateTime value) =>
      _prefs.setString(_kLastSessionAt, value.toIso8601String());

  // ------------------------------------------------------- content pack state

  int get localContentVersion => _prefs.getInt(_kContentVersion) ?? 0;
  Future<void> setLocalContentVersion(int value) =>
      _prefs.setInt(_kContentVersion, value);

  DateTime? get lastManifestCheckAt {
    final String? raw = _prefs.getString(_kLastManifestCheck);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastManifestCheckAt(DateTime value) =>
      _prefs.setString(_kLastManifestCheck, value.toIso8601String());

  DateTime? get packPublishedAt {
    final String? raw = _prefs.getString(_kPackPublishedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setPackPublishedAt(DateTime? value) async {
    if (value == null) {
      await _prefs.remove(_kPackPublishedAt);
      return;
    }
    await _prefs.setString(_kPackPublishedAt, value.toIso8601String());
  }

  int get freshnessBannerSeenVersion =>
      _prefs.getInt(_kFreshnessBannerVersion) ?? 0;
  Future<void> setFreshnessBannerSeenVersion(int value) =>
      _prefs.setInt(_kFreshnessBannerVersion, value);

  // ------------------------------------------------------------ offline cache

  List<String> get analyticsQueue => _prefs.getStringList(_kAnalyticsQueue) ?? const <String>[];
  Future<void> setAnalyticsQueue(List<String> value) =>
      _prefs.setStringList(_kAnalyticsQueue, value);

  Map<String, dynamic>? get cachedProfile => _readJson(_kCachedProfile);
  Future<void> setCachedProfile(Map<String, dynamic> value) =>
      _writeJson(_kCachedProfile, value);

  Map<String, dynamic>? get cachedLevelMap => _readJson(_kCachedLevelMap);
  Future<void> setCachedLevelMap(Map<String, dynamic> value) =>
      _writeJson(_kCachedLevelMap, value);

  Map<String, dynamic>? get cachedLeaderboard => _readJson(_kCachedLeaderboard);
  Future<void> setCachedLeaderboard(Map<String, dynamic> value) async {
    await _writeJson(_kCachedLeaderboard, value);
    await _prefs.setString(_kLeaderboardCachedAt, DateTime.now().toIso8601String());
  }

  DateTime? get leaderboardCachedAt {
    final String? raw = _prefs.getString(_kLeaderboardCachedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// design-spec §15 M-01: when the version check cannot reach the server, the
  /// app opens normally — but a *known* force-upgrade verdict from a previous
  /// launch is still honoured so a blocked build cannot be used by going offline.
  Map<String, dynamic>? get cachedForceUpgrade => _readJson(_kForceUpgradeCache);
  Future<void> setCachedForceUpgrade(Map<String, dynamic>? value) async {
    if (value == null) {
      await _prefs.remove(_kForceUpgradeCache);
      return;
    }
    await _writeJson(_kForceUpgradeCache, value);
  }

  /// Best stars earned per Kids Zone stop id (device-local, not synced).
  ///
  /// Every mini-game already judged a considered 1-3 stars and the celebration
  /// screen showed it, but only the stop id was ever kept — so the hub could
  /// say nothing beyond "done", and there was nothing for a child to come back
  /// and beat. The star is the replay loop; it needs to survive the screen.
  Map<String, int> get kidsZoneStars {
    final Map<String, dynamic>? raw = _readJson(_kKidsZoneStars);
    if (raw == null) return <String, int>{};
    return <String, int>{
      for (final MapEntry<String, dynamic> e in raw.entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    };
  }

  /// Kids Zone stop ids the player has finished.
  Set<String> get kidsZoneCompletedStops {
    final List<String>? raw = _prefs.getStringList(_kKidsZoneCompletedStops);
    return raw == null ? <String>{} : Set<String>.from(raw);
  }

  bool isKidsZoneStopComplete(String stopId) =>
      kidsZoneCompletedStops.contains(stopId);

  /// Stars earned on [stopId], or 0 if it has never been finished.
  int kidsZoneStarsFor(String stopId) => kidsZoneStars[stopId] ?? 0;

  /// Records a finished stop, keeping the best result rather than the latest —
  /// replaying a stop and doing worse should never cost a child a star they
  /// have already earned.
  Future<void> markKidsZoneStopComplete(String stopId, {int stars = 0}) async {
    final Set<String> completed = Set<String>.from(kidsZoneCompletedStops)
      ..add(stopId);
    await _prefs.setStringList(_kKidsZoneCompletedStops, completed.toList());

    final Map<String, int> best = kidsZoneStars;
    if (stars > (best[stopId] ?? 0)) {
      best[stopId] = stars;
      await _writeJson(_kKidsZoneStars, best);
    }
  }

  /// Applies a merged progress set from the server.
  ///
  /// Replaces rather than merges, because the caller has already merged: the
  /// sync endpoint is given the device's whole local set and returns the union,
  /// so what arrives here is a superset of what is already stored. Writing it
  /// wholesale is what restores a child's stars after the sign-out wipe, and
  /// after a reinstall or a move to a new phone.
  Future<void> applyKidsZoneProgress(Map<String, int> starsByStopId) async {
    await _prefs.setStringList(
      _kKidsZoneCompletedStops,
      starsByStopId.keys.toList(),
    );
    await _writeJson(_kKidsZoneStars, starsByStopId);
  }

  /// Whether a Kids Zone how-to-play card has already been shown. Tutorials
  /// appear unprompted only the first time; after that they stay behind a help
  /// button so a returning child can look again without being lectured.
  bool isKidsZoneTutorialSeen(String tutorialId) =>
      _prefs.getBool('$_kKidsZoneTutorialPrefix$tutorialId') ?? false;

  Future<void> markKidsZoneTutorialSeen(String tutorialId) async {
    await _prefs.setBool('$_kKidsZoneTutorialPrefix$tutorialId', true);
  }

  /// Wipes account-scoped state on sign-out and deletion. The install id and the
  /// practice pack survive: the pack is not personal data and re-downloading it
  /// on every sign-out would waste the user's data allowance.
  Future<void> clearAccountScopedState() async {
    await clearSessionToken();
    await _prefs.remove(_kCachedProfile);
    await _prefs.remove(_kCachedLevelMap);
    await _prefs.remove(_kCachedLeaderboard);
    await _prefs.remove(_kLeaderboardCachedAt);
    await _prefs.remove(_kNotificationsOptIn);
    await _prefs.remove(_kNotifyPromptShown);
    await _prefs.remove(_kAnalyticsQueue);
    await _prefs.remove(_kCurrentLevel);

    // Kids Zone progress is a child's own play record, and it belongs to the
    // account that made it. Left behind, the next child to sign in on a shared
    // family device found their adventures already completed and unlocked — and
    // a deletion request left play data on the device.
    await _prefs.remove(_kKidsZoneCompletedStops);
    await _prefs.remove(_kKidsZoneStars);
    for (final String key in _prefs.getKeys()) {
      if (key.startsWith(_kKidsZoneTutorialPrefix)) {
        await _prefs.remove(key);
      }
    }
  }

  Map<String, dynamic>? _readJson(String key) {
    final String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));
}
