import 'level.dart';

/// `GET /v1/content/manifest` — the cheap freshness check from design-spec §19.
class ContentManifest {
  const ContentManifest({
    required this.contentVersion,
    required this.publishedAt,
    required this.packSizeBytes,
    required this.checksum,
    required this.minAppBuild,
    required this.changeSummary,
  });

  factory ContentManifest.fromJson(Map<String, dynamic> json) => ContentManifest(
        contentVersion: (json['content_version'] as num?)?.toInt() ?? 0,
        publishedAt: DateTime.tryParse('${json['published_at']}'),
        packSizeBytes: (json['pack_size_bytes'] as num?)?.toInt() ?? 0,
        checksum: json['checksum'] as String?,
        minAppBuild: (json['min_app_build'] as num?)?.toInt() ?? 1,
        changeSummary: json['change_summary'] as String?,
      );

  final int contentVersion;
  final DateTime? publishedAt;
  final int packSizeBytes;
  final String? checksum;
  final int minAppBuild;
  final String? changeSummary;
}

/// A practice question. Unlike a ranked [AttemptQuestion] this *does* carry the
/// correct answer, because practice is offline and never touches the leaderboard
/// (deliberate tradeoff documented in the backend content_pack service).
class PackQuestion {
  const PackQuestion({
    required this.id,
    required this.levelNumber,
    required this.variantType,
    required this.questionText,
    required this.answerOptions,
    required this.correctAnswer,
    required this.difficultyTier,
    required this.verseReference,
    required this.verseExcerpt,
    required this.imageAssetKey,
    required this.imageAltText,
  });

  factory PackQuestion.fromJson(Map<String, dynamic> json) => PackQuestion(
        id: '${json['id']}',
        levelNumber: (json['level_number'] as num?)?.toInt() ?? 0,
        variantType: VariantType.parse(json['variant_type']),
        questionText: '${json['question_text'] ?? ''}',
        answerOptions: ((json['answer_options'] as List<dynamic>? ?? const <dynamic>[]))
            .map((Object? item) => '$item')
            .toList(),
        correctAnswer: '${json['correct_answer'] ?? ''}',
        difficultyTier: DifficultyTier.parse(json['difficulty_tier']),
        verseReference: json['verse_reference'] as String?,
        verseExcerpt: json['verse_excerpt'] as String?,
        imageAssetKey: json['image_asset_key'] as String?,
        imageAltText: json['image_alt_text'] as String?,
      );

  final String id;
  final int levelNumber;
  final VariantType variantType;
  final String questionText;
  final List<String> answerOptions;
  final String correctAnswer;
  final DifficultyTier difficultyTier;
  final String? verseReference;
  final String? verseExcerpt;
  final String? imageAssetKey;
  final String? imageAltText;
}

class PackLevel {
  const PackLevel({
    required this.levelNumber,
    required this.title,
    required this.timerSeconds,
    required this.difficultyTier,
    required this.isFreeTier,
  });

  factory PackLevel.fromJson(Map<String, dynamic> json) => PackLevel(
        levelNumber: (json['level_number'] as num?)?.toInt() ?? 0,
        title: json['title'] as String?,
        timerSeconds: (json['timer_seconds'] as num?)?.toInt() ?? 30,
        difficultyTier: DifficultyTier.parse(json['difficulty_tier']),
        isFreeTier: json['is_free_tier'] == true,
      );

  final int levelNumber;
  final String? title;
  final int timerSeconds;
  final DifficultyTier difficultyTier;
  final bool isFreeTier;
}

/// The on-device Practice Content Pack (design-spec §19).
///
/// Practice mode reads only from this — M-19 never calls a question API.
class ContentPack {
  ContentPack({
    required this.contentVersion,
    required this.publishedAt,
    required this.minAppBuild,
    required this.levels,
    required this.questions,
  });

  factory ContentPack.fromJson(Map<String, dynamic> json) {
    final List<PackLevel> levels =
        ((json['levels'] as List<dynamic>? ?? const <dynamic>[]))
            .map((Object? item) => PackLevel.fromJson(item as Map<String, dynamic>))
            .toList();
    final List<PackQuestion> questions =
        ((json['questions'] as List<dynamic>? ?? const <dynamic>[]))
            .map((Object? item) => PackQuestion.fromJson(item as Map<String, dynamic>))
            .toList();
    return ContentPack(
      contentVersion: (json['content_version'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.tryParse('${json['published_at']}'),
      minAppBuild: (json['min_app_build'] as num?)?.toInt() ?? 1,
      levels: levels,
      questions: questions,
    );
  }

  final int contentVersion;
  final DateTime? publishedAt;
  final int minAppBuild;
  final List<PackLevel> levels;
  final List<PackQuestion> questions;

  Map<int, List<PackQuestion>>? _byLevelCache;

  Map<int, List<PackQuestion>> get questionsByLevel {
    final Map<int, List<PackQuestion>>? cached = _byLevelCache;
    if (cached != null) return cached;
    final Map<int, List<PackQuestion>> grouped = <int, List<PackQuestion>>{};
    for (final PackQuestion question in questions) {
      grouped.putIfAbsent(question.levelNumber, () => <PackQuestion>[]).add(question);
    }
    _byLevelCache = grouped;
    return grouped;
  }

  List<PackQuestion> questionsFor(int levelNumber) =>
      questionsByLevel[levelNumber] ?? const <PackQuestion>[];

  PackLevel? levelFor(int levelNumber) {
    for (final PackLevel level in levels) {
      if (level.levelNumber == levelNumber) return level;
    }
    return null;
  }

  bool get isUsable => levels.isNotEmpty && questions.isNotEmpty;
}
