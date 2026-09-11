import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/local_store.dart';
import '../models/content_pack.dart';
import 'analytics_service.dart';

/// Why a pack update failed, matching the `error_code` values in
/// analytics-spec §6A `content_cache_update_failed`.
enum PackUpdateError { network, checksumMismatch, diskFull, corruptPack }

class PackSyncOutcome {
  const PackSyncOutcome.upToDate()
      : updated = false,
        error = null,
        fromVersion = 0,
        toVersion = 0;

  const PackSyncOutcome.updated({required this.fromVersion, required this.toVersion})
      : updated = true,
        error = null;

  const PackSyncOutcome.failed(this.error, {required this.fromVersion, required this.toVersion})
      : updated = false;

  final bool updated;
  final PackUpdateError? error;
  final int fromVersion;
  final int toVersion;
}

/// Practice Content Pack storage and sync (design-spec §19).
///
/// Delivery has two paths on purpose: ranked play always fetches questions live,
/// while practice reads only from the local pack. This service owns the local
/// side — seed pack from the app bundle on first install, background refresh when
/// the server's `content_version` is newer, checksum verify, atomic swap.
class ContentService extends ChangeNotifier {
  ContentService({
    required ApiClient api,
    required LocalStore store,
    required AnalyticsService analytics,
  })  : _api = api,
        _store = store,
        _analytics = analytics;

  static const String _seedAssetPath = 'assets/content/seed_pack.json';
  static const String _packFileName = 'practice_pack.json';

  final ApiClient _api;
  final LocalStore _store;
  final AnalyticsService _analytics;

  ContentPack? _pack;
  bool _loading = false;
  bool _downloading = false;
  bool _corrupt = false;
  PackUpdateError? _lastError;

  ContentPack? get pack => _pack;
  bool get isLoading => _loading;

  /// True while a newer pack is downloading. M-18 shows a non-blocking
  /// "Updating practice questions…" banner and stays playable on the old pack.
  bool get isDownloading => _downloading;

  /// The local pack exists but could not be parsed — M-18 blocking error state.
  bool get isCorrupt => _corrupt;

  PackUpdateError? get lastError => _lastError;

  bool get hasUsablePack => _pack?.isUsable == true;

  /// Questions available for practice on a level. Empty means the pack has no
  /// authored questions for it yet, which M-18 surfaces rather than opening an
  /// unplayable level.
  List<PackQuestion> questionsFor(int levelNumber) =>
      _pack?.questionsFor(levelNumber) ?? const <PackQuestion>[];

  PackLevel? levelFor(int levelNumber) => _pack?.levelFor(levelNumber);

  /// Levels included in the on-device offline practice pack (1…[offlinePracticeMaxLevel]).
  List<PackLevel> get practiceLevels {
    final ContentPack? active = _pack;
    if (active == null) return const <PackLevel>[];
    return active.levels
        .where(
          (PackLevel level) =>
              level.levelNumber >= 1 &&
              level.levelNumber <= AppConfig.offlinePracticeMaxLevel,
        )
        .toList()
      ..sort((PackLevel a, PackLevel b) => a.levelNumber.compareTo(b.levelNumber));
  }

  bool isOfflinePracticeLevel(int levelNumber) =>
      levelNumber >= 1 && levelNumber <= AppConfig.offlinePracticeMaxLevel;

  int get localContentVersion => _store.localContentVersion;

  DateTime? get packPublishedAt => _store.packPublishedAt;

  /// design-spec §19: banner is shown once per version, then dismissed.
  bool get shouldShowFreshnessBanner =>
      localContentVersion > 0 &&
      _store.freshnessBannerSeenVersion < localContentVersion;

  Future<void> dismissFreshnessBanner() async {
    await _store.setFreshnessBannerSeenVersion(localContentVersion);
    notifyListeners();
  }

  /// Loads the active pack: the downloaded one if present, otherwise the seed
  /// shipped in the binary so practice works on a first install with no network.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _corrupt = false;
    notifyListeners();

    try {
      final File file = await _packFile();
      if (file.existsSync()) {
        final String raw = await file.readAsString();
        _pack = _parse(raw);
        if (_pack == null) {
          // A downloaded pack that will not parse is not fatal: fall back to the
          // seed rather than blocking practice entirely.
          _pack = await _loadSeed();
          _corrupt = _pack == null;
        }
      } else {
        _pack = await _loadSeed();
        _corrupt = _pack == null;
      }
    } on Object catch (error) {
      if (kDebugMode) debugPrint('content pack load failed: $error');
      _pack = await _loadSeed();
      _corrupt = _pack == null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Manifest check + background download. Never blocks launch (design-spec §19
  /// sync rule 2) and never throws: a failed sync leaves practice on the old pack.
  Future<PackSyncOutcome> syncIfStale({bool force = false}) async {
    final int localVersion = localContentVersion;

    if (!force) {
      final DateTime? lastCheck = _store.lastManifestCheckAt;
      if (lastCheck != null &&
          DateTime.now().difference(lastCheck) < AppConfig.manifestRecheckInterval) {
        return const PackSyncOutcome.upToDate();
      }
    }

    ContentManifest manifest;
    try {
      final Map<String, dynamic> json = await _api.getJson(
        '/v1/content/manifest',
        query: <String, dynamic>{'local_content_version': localVersion},
      );
      manifest = ContentManifest.fromJson(json);
      await _store.setLastManifestCheckAt(DateTime.now());
    } on ApiException {
      // The manifest event is emitted server-side inside the request, so there is
      // nothing to report here when the request itself never landed.
      return PackSyncOutcome.failed(
        PackUpdateError.network,
        fromVersion: localVersion,
        toVersion: localVersion,
      );
    }

    if (manifest.contentVersion <= localVersion) {
      return const PackSyncOutcome.upToDate();
    }

    return _download(manifest, fromVersion: localVersion);
  }

  Future<PackSyncOutcome> _download(
    ContentManifest manifest, {
    required int fromVersion,
  }) async {
    if (_downloading) {
      return const PackSyncOutcome.upToDate();
    }
    _downloading = true;
    _lastError = null;
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final ApiBytes response = await _api.getBytes(
        '/v1/content/practice-pack',
        query: <String, dynamic>{'since_version': fromVersion},
      );

      if (response.isNoContent) {
        return const PackSyncOutcome.upToDate();
      }

      // The backend gzips the body itself; dart:io may or may not have already
      // inflated it depending on whether it honoured Content-Encoding, so detect
      // the gzip magic bytes rather than trusting the header either way.
      final List<int> canonicalBytes = _inflateIfNeeded(response.bytes);

      // The published checksum is the SHA-256 of the canonical pack JSON, and the
      // gzip body is exactly those bytes compressed — so hashing the inflated
      // bytes verifies the pack without reimplementing the server's canonical
      // JSON encoding on the client.
      final String? expected = manifest.checksum ??
          response.headers['x-content-checksum'];
      if (expected != null && expected.isNotEmpty) {
        final String actual = sha256.convert(canonicalBytes).toString();
        if (actual != expected) {
          return _fail(
            PackUpdateError.checksumMismatch,
            fromVersion: fromVersion,
            toVersion: manifest.contentVersion,
          );
        }
      }

      final String raw = utf8.decode(canonicalBytes);
      final ContentPack? parsed = _parse(raw);
      if (parsed == null || !parsed.isUsable) {
        return _fail(
          PackUpdateError.corruptPack,
          fromVersion: fromVersion,
          toVersion: manifest.contentVersion,
        );
      }

      // Atomic swap: write to a temp file first so a crash mid-write can never
      // leave a truncated pack as the active one (design-spec §19 sync rule 3).
      final File target = await _packFile();
      final File temp = File('${target.path}.tmp');
      await temp.writeAsString(raw, flush: true);
      if (target.existsSync()) {
        await target.delete();
      }
      await temp.rename(target.path);

      _pack = parsed;
      _corrupt = false;
      await _store.setLocalContentVersion(parsed.contentVersion);
      await _store.setPackPublishedAt(parsed.publishedAt);

      stopwatch.stop();
      _analytics.track('content_cache_updated', properties: <String, Object?>{
        'from_version': fromVersion,
        'to_version': parsed.contentVersion,
        'download_size_bytes': response.bytes.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });

      return PackSyncOutcome.updated(
        fromVersion: fromVersion,
        toVersion: parsed.contentVersion,
      );
    } on ApiException {
      return _fail(
        PackUpdateError.network,
        fromVersion: fromVersion,
        toVersion: manifest.contentVersion,
      );
    } on FileSystemException {
      return _fail(
        PackUpdateError.diskFull,
        fromVersion: fromVersion,
        toVersion: manifest.contentVersion,
      );
    } on Object {
      return _fail(
        PackUpdateError.corruptPack,
        fromVersion: fromVersion,
        toVersion: manifest.contentVersion,
      );
    } finally {
      _downloading = false;
      notifyListeners();
    }
  }

  PackSyncOutcome _fail(
    PackUpdateError error, {
    required int fromVersion,
    required int toVersion,
  }) {
    _lastError = error;
    _analytics.track('content_cache_update_failed', properties: <String, Object?>{
      'local_content_version': fromVersion,
      'attempted_version': toVersion,
      'error_code': error.name == 'checksumMismatch'
          ? 'checksum_mismatch'
          : error.name == 'diskFull'
              ? 'disk_full'
              : error.name == 'corruptPack'
                  ? 'corrupt_pack'
                  : 'network',
    });
    return PackSyncOutcome.failed(error, fromVersion: fromVersion, toVersion: toVersion);
  }

  List<int> _inflateIfNeeded(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      return gzip.decode(bytes);
    }
    return bytes;
  }

  ContentPack? _parse(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return ContentPack.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<ContentPack?> _loadSeed() async {
    try {
      final String raw = await rootBundle.loadString(_seedAssetPath);
      final ContentPack? seed = _parse(raw);
      if (seed != null && seed.contentVersion > _store.localContentVersion) {
        // A store update can ship a newer embedded seed than the pack this device
        // last downloaded; the manifest check reconciles from here (§19).
        await _store.setLocalContentVersion(seed.contentVersion);
        await _store.setPackPublishedAt(seed.publishedAt);
      }
      return seed;
    } on Object catch (error) {
      if (kDebugMode) debugPrint('seed pack load failed: $error');
      return null;
    }
  }

  Future<File> _packFile() async {
    final Directory dir = await getApplicationSupportDirectory();
    final Directory contentDir = Directory('${dir.path}/content');
    if (!contentDir.existsSync()) {
      contentDir.createSync(recursive: true);
    }
    return File('${contentDir.path}/$_packFileName');
  }
}
