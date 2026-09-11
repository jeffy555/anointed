/// design-spec §21: read-only board. Entries are written server-side from
/// validated attempts; there is no client submit endpoint.
enum LeaderboardWindow {
  allTime('all_time'),
  weekly('weekly'),
  daily('daily');

  const LeaderboardWindow(this.wireValue);

  final String wireValue;
}

class LeaderboardRow {
  const LeaderboardRow({
    required this.rank,
    required this.displayName,
    required this.score,
    required this.levelId,
    required this.recordedAt,
    required this.isCurrentUser,
  });

  factory LeaderboardRow.fromJson(Map<String, dynamic> json) => LeaderboardRow(
        rank: (json['rank'] as num).toInt(),
        // Already masked to first name + last initial for under-13 players
        // server-side (design-spec §21 COPPA-06).
        displayName: '${json['display_name'] ?? ''}',
        score: (json['score'] as num?)?.toInt() ?? 0,
        levelId: (json['level_id'] as num?)?.toInt() ?? 0,
        recordedAt: DateTime.tryParse('${json['recorded_at']}')?.toUtc(),
        isCurrentUser: json['is_current_user'] == true,
      );

  final int rank;
  final String displayName;
  final int score;
  final int levelId;
  final DateTime? recordedAt;
  final bool isCurrentUser;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rank': rank,
        'display_name': displayName,
        'score': score,
        'level_id': levelId,
        'recorded_at': recordedAt?.toIso8601String(),
        'is_current_user': isCurrentUser,
      };
}

class YourRank {
  const YourRank({
    required this.rank,
    required this.score,
    required this.displayName,
    required this.levelId,
  });

  factory YourRank.fromJson(Map<String, dynamic> json) => YourRank(
        rank: (json['rank'] as num?)?.toInt(),
        score: (json['score'] as num?)?.toInt(),
        displayName: '${json['display_name'] ?? ''}',
        levelId: (json['level_id'] as num?)?.toInt(),
      );

  final int? rank;
  final int? score;
  final String displayName;
  final int? levelId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rank': rank,
        'score': score,
        'display_name': displayName,
        'level_id': levelId,
      };
}

class LeaderboardPage {
  const LeaderboardPage({
    required this.window,
    required this.rows,
    required this.yourRank,
    required this.totalEntries,
    required this.generatedAt,
  });

  factory LeaderboardPage.fromJson(Map<String, dynamic> json) => LeaderboardPage(
        window: '${json['window'] ?? 'all_time'}',
        rows: ((json['rows'] as List<dynamic>? ?? const <dynamic>[]))
            .map((Object? item) => LeaderboardRow.fromJson(item as Map<String, dynamic>))
            .toList(),
        yourRank: YourRank.fromJson(
          (json['your_rank'] as Map<String, dynamic>?) ?? <String, dynamic>{},
        ),
        totalEntries: (json['total_entries'] as num?)?.toInt() ?? 0,
        generatedAt: DateTime.tryParse('${json['generated_at']}')?.toUtc(),
      );

  final String window;
  final List<LeaderboardRow> rows;
  final YourRank yourRank;
  final int totalEntries;
  final DateTime? generatedAt;

  bool get isEmpty => rows.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'window': window,
        'rows': rows.map((LeaderboardRow row) => row.toJson()).toList(),
        'your_rank': yourRank.toJson(),
        'total_entries': totalEntries,
        'generated_at': generatedAt?.toIso8601String(),
      };
}
