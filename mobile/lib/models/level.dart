enum DifficultyTier {
  easy('easy'),
  medium('medium'),
  hard('hard'),
  expert('expert');

  const DifficultyTier(this.wireValue);

  final String wireValue;

  static DifficultyTier parse(Object? value) {
    for (final DifficultyTier tier in DifficultyTier.values) {
      if (tier.wireValue == value) return tier;
    }
    return DifficultyTier.easy;
  }
}

/// design-spec §18H: three launch-supported question presentations sharing one
/// interaction model (4 taps, no keyboard).
enum VariantType {
  textQa('text_qa'),
  verseClue('verse_clue'),
  imageClue('image_clue');

  const VariantType(this.wireValue);

  final String wireValue;

  static VariantType parse(Object? value) {
    for (final VariantType type in VariantType.values) {
      if (type.wireValue == value) return type;
    }
    return VariantType.textQa;
  }
}

/// One node on the M-11 level map. Lock state is server-computed from progress
/// plus IAP status — the client never decides what is unlocked.
class LevelSummary {
  const LevelSummary({
    required this.levelNumber,
    required this.title,
    required this.difficultyTier,
    required this.timerSeconds,
    required this.isFreeTier,
    required this.locked,
    required this.completed,
    required this.bestScore,
    required this.isCurrent,
    required this.playable,
    required this.availableVariantTypes,
  });

  factory LevelSummary.fromJson(Map<String, dynamic> json) => LevelSummary(
        levelNumber: (json['level_number'] as num).toInt(),
        title: json['title'] as String?,
        difficultyTier: DifficultyTier.parse(json['difficulty_tier']),
        timerSeconds: (json['timer_seconds'] as num?)?.toInt() ?? 30,
        isFreeTier: json['is_free_tier'] == true,
        locked: json['locked'] == true,
        completed: json['completed'] == true,
        bestScore: (json['best_score'] as num?)?.toInt(),
        isCurrent: json['is_current'] == true,
        playable: json['playable'] == true,
        availableVariantTypes: _variants(json['available_variant_types']),
      );

  final int levelNumber;
  final String? title;
  final DifficultyTier difficultyTier;
  final int timerSeconds;
  final bool isFreeTier;
  final bool locked;
  final bool completed;
  final int? bestScore;
  final bool isCurrent;
  final bool playable;
  final List<VariantType> availableVariantTypes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'level_number': levelNumber,
        'title': title,
        'difficulty_tier': difficultyTier.wireValue,
        'timer_seconds': timerSeconds,
        'is_free_tier': isFreeTier,
        'locked': locked,
        'completed': completed,
        'best_score': bestScore,
        'is_current': isCurrent,
        'playable': playable,
        'available_variant_types':
            availableVariantTypes.map((VariantType type) => type.wireValue).toList(),
      };

  static List<VariantType> _variants(Object? raw) {
    if (raw is! List) return const <VariantType>[];
    return raw.map(VariantType.parse).toList();
  }
}

/// `GET /v1/game/levels` — M-11.
class LevelMap {
  const LevelMap({
    required this.levels,
    required this.highestLevelCompleted,
    required this.currentLevel,
    required this.hasUnlock,
    required this.freeTierMaxLevel,
    required this.totalLevels,
  });

  factory LevelMap.fromJson(Map<String, dynamic> json) => LevelMap(
        levels: ((json['levels'] as List<dynamic>? ?? const <dynamic>[]))
            .map((Object? item) => LevelSummary.fromJson(item as Map<String, dynamic>))
            .toList(),
        highestLevelCompleted: (json['highest_level_completed'] as num?)?.toInt() ?? 0,
        currentLevel: (json['current_level'] as num?)?.toInt() ?? 1,
        hasUnlock: json['has_unlock'] == true,
        freeTierMaxLevel: (json['free_tier_max_level'] as num?)?.toInt() ?? 5,
        totalLevels: (json['total_levels'] as num?)?.toInt() ?? 100,
      );

  final List<LevelSummary> levels;
  final int highestLevelCompleted;
  final int currentLevel;
  final bool hasUnlock;
  final int freeTierMaxLevel;
  final int totalLevels;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'levels': levels.map((LevelSummary level) => level.toJson()).toList(),
        'highest_level_completed': highestLevelCompleted,
        'current_level': currentLevel,
        'has_unlock': hasUnlock,
        'free_tier_max_level': freeTierMaxLevel,
        'total_levels': totalLevels,
      };
}

/// `GET /v1/game/levels/{n}` — the M-12 pre-level card.
class LevelDetail {
  const LevelDetail({
    required this.levelNumber,
    required this.title,
    required this.difficultyTier,
    required this.timerSeconds,
    required this.questionsPerAttempt,
    required this.isFreeTier,
    required this.locked,
    required this.completed,
    required this.bestScore,
    required this.availableVariantTypes,
    required this.poolSize,
    required this.playable,
  });

  factory LevelDetail.fromJson(Map<String, dynamic> json) => LevelDetail(
        levelNumber: (json['level_number'] as num).toInt(),
        title: json['title'] as String?,
        difficultyTier: DifficultyTier.parse(json['difficulty_tier']),
        timerSeconds: (json['timer_seconds'] as num?)?.toInt() ?? 30,
        questionsPerAttempt: (json['questions_per_attempt'] as num?)?.toInt() ?? 10,
        isFreeTier: json['is_free_tier'] == true,
        locked: json['locked'] == true,
        completed: json['completed'] == true,
        bestScore: (json['best_score'] as num?)?.toInt(),
        availableVariantTypes: LevelSummary._variants(json['available_variant_types']),
        poolSize: (json['pool_size'] as num?)?.toInt() ?? 0,
        playable: json['playable'] == true,
      );

  final int levelNumber;
  final String? title;
  final DifficultyTier difficultyTier;
  final int timerSeconds;
  final int questionsPerAttempt;
  final bool isFreeTier;
  final bool locked;
  final bool completed;
  final int? bestScore;
  final List<VariantType> availableVariantTypes;
  final int poolSize;
  final bool playable;
}
