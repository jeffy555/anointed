import '../core/api_client.dart';
import '../core/local_store.dart';
import '../models/leaderboard.dart';

/// `GET /v1/leaderboard` — read-only (design-spec §21).
class LeaderboardRepository {
  LeaderboardRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  Future<LeaderboardPage> fetch({
    LeaderboardWindow window = LeaderboardWindow.allTime,
    int limit = 50,
    String entrySource = 'nav_tab',
  }) async {
    final Map<String, dynamic> json = await _api.getJson(
      '/v1/leaderboard',
      query: <String, dynamic>{
        'window': window.wireValue,
        'limit': limit,
        'entry_source': entrySource,
      },
    );
    final LeaderboardPage page = LeaderboardPage.fromJson(json);
    // design-spec §15 M-17: on a later API error the cached board is shown with
    // a "Last updated" label rather than an empty screen.
    if (window == LeaderboardWindow.allTime) {
      await _store.setCachedLeaderboard(page.toJson());
    }
    return page;
  }

  LeaderboardPage? cached() {
    final Map<String, dynamic>? json = _store.cachedLeaderboard;
    if (json == null) return null;
    return LeaderboardPage.fromJson(json);
  }

  DateTime? get cachedAt => _store.leaderboardCachedAt;
}
