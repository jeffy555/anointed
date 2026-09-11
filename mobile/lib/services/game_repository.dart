import '../core/api_client.dart';
import '../core/local_store.dart';
import '../models/attempt.dart';
import '../models/level.dart';

/// `/v1/game/*` — server-authoritative gameplay (design-spec §21).
///
/// There is deliberately no "submit score" method here: the score is computed
/// server-side from validated answers and the leaderboard entry is written by
/// the backend. A client-side scoring path must never be added.
class GameRepository {
  GameRepository(this._api, this._store);

  final ApiClient _api;
  final LocalStore _store;

  /// M-11. Cached so design-spec §15's "show last saved map + sync-failed
  /// banner" state has real data to render instead of an empty screen.
  Future<LevelMap> levelMap() async {
    final Map<String, dynamic> json = await _api.getJson('/v1/game/levels');
    final LevelMap map = LevelMap.fromJson(json);
    await _store.setCachedLevelMap(map.toJson());
    return map;
  }

  LevelMap? cachedLevelMap() {
    final Map<String, dynamic>? json = _store.cachedLevelMap;
    if (json == null) return null;
    return LevelMap.fromJson(json);
  }

  /// M-12.
  Future<LevelDetail> levelDetail(int levelNumber) async {
    final Map<String, dynamic> json = await _api.getJson('/v1/game/levels/$levelNumber');
    return LevelDetail.fromJson(json);
  }

  /// Opens a ranked attempt. Correct answers are never in the response.
  Future<StartedAttempt> startAttempt(int levelNumber, {String mode = 'ranked'}) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/game/levels/$levelNumber/attempts/start',
      body: <String, Object?>{'mode': mode},
    );
    return StartedAttempt.fromJson(json);
  }

  /// Per-answer validation. The client sends an option index and its own elapsed
  /// time; the server decides correctness, plausibility, and score.
  Future<AnswerResult> submitAnswer({
    required String attemptId,
    required int questionIndex,
    required int selectedOptionIndex,
    required int clientTimeTakenMs,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/game/attempts/$attemptId/answers',
      body: <String, Object?>{
        'question_index': questionIndex,
        'selected_option_index': selectedOptionIndex,
        'client_time_taken_ms': clientTimeTakenMs,
      },
    );
    return AnswerResult.fromJson(json);
  }

  /// M-16 — reported so the attempt is closed as a fail with no leaderboard entry.
  Future<AttemptState> reportTimerExpired({
    required String attemptId,
    required int questionIndex,
  }) async {
    final Map<String, dynamic> json = await _api.postJson(
      '/v1/game/attempts/$attemptId/timer-expired',
      body: <String, Object?>{'question_index': questionIndex},
    );
    return AttemptState.fromJson(json);
  }

  /// User backed out of a level mid-attempt.
  Future<AttemptState> abandonAttempt(String attemptId) async {
    final Map<String, dynamic> json =
        await _api.postJson('/v1/game/attempts/$attemptId/abandon');
    return AttemptState.fromJson(json);
  }

  /// Resync after a network drop mid-level (design-spec §15 M-13).
  Future<AttemptState> attemptState(String attemptId) async {
    final Map<String, dynamic> json = await _api.getJson('/v1/game/attempts/$attemptId');
    return AttemptState.fromJson(json);
  }

  /// Level numbers already cleared, used to rehydrate the map when the level
  /// endpoint is unreachable.
  Future<List<int>> completions() async {
    final List<dynamic> json = await _api.getJsonList('/v1/account/completions');
    return json.map((Object? item) => (item as num).toInt()).toList();
  }
}
