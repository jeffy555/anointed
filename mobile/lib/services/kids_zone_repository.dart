import '../core/api_client.dart';
import '../core/local_store.dart';
import '../features/kids_zone/kids_zone_adventures.dart';

/// `/v1/kids-zone/*` — Kids Zone progress sync.
///
/// Offline-first on purpose. Kids Zone is the part of the app most likely to be
/// played with no connection (a car, a waiting room), so the device stays the
/// thing the UI reads and a failed sync is never shown to a child. There is no
/// pending-write queue: the endpoint merges, so retrying just means sending
/// current local state again, and [sync] posts the whole set every time.
///
/// Unlike [GameRepository], this one does send a score the client computed.
/// That is not an oversight — Kids Zone mini-games run entirely on-device and
/// have no leaderboard or ranked standing, so nothing server-side can judge a
/// star. The server clamps the range and keeps the best of the two sides. The
/// ranked path must never work this way.
class KidsZoneRepository {
  KidsZoneRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  /// Pushes local progress, merges in whatever the server already had, and
  /// writes the union back to the device.
  ///
  /// Returns the merged stars by stop id, or null when the sync could not
  /// happen (offline, signed out, consent pending). Null means "nothing
  /// changed" — local progress is untouched and remains playable.
  Future<Map<String, int>?> sync() async {
    final Map<String, int> local = _store.kidsZoneStars;
    final List<Map<String, Object?>> stops = <Map<String, Object?>>[];

    for (final String stopId in _store.kidsZoneCompletedStops) {
      final KidsAdventure? adventure = kidsZoneAdventureForStop(stopId);
      // A stop id with no adventure is one the catalogue no longer has. Skip it
      // rather than inventing an adventure id the server would store forever.
      if (adventure == null) continue;
      stops.add(<String, Object?>{
        'stop_id': stopId,
        'adventure_id': adventure.id,
        'stars': local[stopId] ?? 0,
      });
    }

    try {
      final Map<String, dynamic> json = await _api.postJson(
        '/v1/kids-zone/progress/sync',
        body: <String, Object?>{'stops': stops},
      );
      final Map<String, int> merged = _parse(json);
      await _store.applyKidsZoneProgress(merged);
      return merged;
    } on ApiException {
      // Offline, or an account that cannot sync yet. The child keeps playing
      // against local progress and the next sync carries the same state.
      return null;
    }
  }

  Map<String, int> _parse(Map<String, dynamic> json) {
    final Object? rows = json['stops'];
    if (rows is! List) return <String, int>{};
    return <String, int>{
      for (final Object? row in rows)
        if (row is Map && row['stop_id'] is String)
          row['stop_id'] as String:
              (row['stars'] is num) ? (row['stars'] as num).toInt() : 0,
    };
  }
}
