import '../core/api_client.dart';
import '../core/device_context.dart';
import '../core/local_store.dart';
import '../models/version_info.dart';

/// `GET /v1/version/minimum` — called before any other API call on cold launch
/// (design-spec §16).
class VersionRepository {
  VersionRepository(this._api, this._device, this._store);

  final ApiClient _api;
  final DeviceContext _device;
  final LocalStore _store;

  /// Returns null when the check could not be completed.
  ///
  /// design-spec §16 edge case: a version check that times out must let the app
  /// open, because a requirement cannot be confirmed without connectivity. A
  /// *previously confirmed* block is still honoured from cache, so going offline
  /// is not a way around an upgrade gate.
  Future<MinimumVersion?> check() async {
    try {
      final Map<String, dynamic> json = await _api.getJson(
        '/v1/version/minimum',
        query: <String, dynamic>{'installed_version': _device.appVersion},
      );
      final MinimumVersion result = MinimumVersion.fromJson(json);
      await _store.setCachedForceUpgrade(
        result.forceUpgradeRequired ? result.toJson() : null,
      );
      return result;
    } on ApiException {
      return cachedBlock();
    }
  }

  MinimumVersion? cachedBlock() {
    final Map<String, dynamic>? json = _store.cachedForceUpgrade;
    if (json == null) return null;
    final MinimumVersion cached = MinimumVersion.fromJson(json);
    return cached.forceUpgradeRequired ? cached : null;
  }
}
