import 'level.dart';

enum AttemptStatus {
  inProgress('in_progress'),
  completed('completed'),
  failed('failed'),
  expired('expired'),
  invalid('invalid'),
  suspicious('suspicious'),
  abandoned('abandoned');

  const AttemptStatus(this.wireValue);

  final String wireValue;

  static AttemptStatus parse(Object? value) {
    for (final AttemptStatus status in AttemptStatus.values) {
      if (status.wireValue == value) return status;
    }
    return AttemptStatus.inProgress;
  }

  bool get isTerminal => this != AttemptStatus.inProgress;
}

enum RejectionReason {
  sequenceViolation('sequence_violation'),
  timeFloor('time_floor'),
  timeCeiling('time_ceiling'),
  expired('expired'),
  rateLimit('rate_limit');

  const RejectionReason(this.wireValue);

  final String wireValue;

  static RejectionReason? parse(Object? value) {
    if (value == null) return null;
    for (final RejectionReason reason in RejectionReason.values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}

/// A question as the client sees it: options are pre-shuffled server-side and the
/// correct answer is never included (design-spec §21).
class AttemptQuestion {
  const AttemptQuestion({
    required this.questionIndex,
    required this.questionId,
    required this.variantType,
    required this.questionText,
    required this.options,
    required this.verseReference,
    required this.verseExcerpt,
    required this.imageAssetKey,
    required this.imageAltText,
    required this.difficultyTier,
  });

  factory AttemptQuestion.fromJson(Map<String, dynamic> json) => AttemptQuestion(
        questionIndex: (json['question_index'] as num).toInt(),
        questionId: '${json['question_id']}',
        variantType: VariantType.parse(json['variant_type']),
        questionText: '${json['question_text'] ?? ''}',
        options: ((json['options'] as List<dynamic>? ?? const <dynamic>[]))
            .map((Object? item) => '$item')
            .toList(),
        verseReference: json['verse_reference'] as String?,
        verseExcerpt: json['verse_excerpt'] as String?,
        imageAssetKey: json['image_asset_key'] as String?,
        imageAltText: json['image_alt_text'] as String?,
        difficultyTier: DifficultyTier.parse(json['difficulty_tier']),
      );

  final int questionIndex;
  final String questionId;
  final VariantType variantType;
  final String questionText;
  final List<String> options;
  final String? verseReference;
  final String? verseExcerpt;
  final String? imageAssetKey;
  final String? imageAltText;
  final DifficultyTier difficultyTier;
}

/// `POST /v1/game/levels/{n}/attempts/start`.
class StartedAttempt {
  const StartedAttempt({
    required this.attemptId,
    required this.levelNumber,
    required this.timerSeconds,
    required this.attemptNumber,
    required this.expiresAt,
    required this.questions,
  });

  factory StartedAttempt.fromJson(Map<String, dynamic> json) => StartedAttempt(
        attemptId: '${json['attempt_id']}',
        levelNumber: (json['level_number'] as num).toInt(),
        timerSeconds: (json['timer_seconds'] as num?)?.toInt() ?? 30,
        attemptNumber: (json['attempt_number'] as num?)?.toInt() ?? 1,
        expiresAt: DateTime.tryParse('${json['expires_at']}')?.toUtc() ??
            DateTime.now().toUtc().add(const Duration(minutes: 10)),
        questions: ((json['questions'] as List<dynamic>? ?? const <dynamic>[]))
            .map((Object? item) => AttemptQuestion.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  final String attemptId;
  final int levelNumber;

  /// Per-question countdown, not a whole-level budget: the server's per-answer
  /// ceiling is `timer_seconds * 1000 + grace` and the attempt budget is
  /// `timer_seconds * questions_per_attempt + grace` (backend gameplay service).
  final int timerSeconds;
  final int attemptNumber;
  final DateTime expiresAt;
  final List<AttemptQuestion> questions;
}

/// `POST /v1/game/attempts/{id}/answers`.
class AnswerResult {
  const AnswerResult({
    required this.accepted,
    required this.correct,
    required this.attemptStatus,
    required this.expectedNextIndex,
    required this.rejectionReason,
    required this.timerRemainingMs,
    required this.score,
    required this.userRank,
    required this.nextLevelLocked,
    required this.nextLevelNumber,
    required this.adEligible,
  });

  factory AnswerResult.fromJson(Map<String, dynamic> json) => AnswerResult(
        accepted: json['accepted'] == true,
        correct: json['correct'] == true,
        attemptStatus: AttemptStatus.parse(json['attempt_status']),
        expectedNextIndex: (json['expected_next_index'] as num?)?.toInt() ?? 0,
        rejectionReason: RejectionReason.parse(json['rejection_reason']),
        timerRemainingMs: (json['timer_remaining_ms'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toInt(),
        userRank: (json['user_rank'] as num?)?.toInt(),
        nextLevelLocked: json['next_level_locked'] as bool?,
        nextLevelNumber: (json['next_level_number'] as num?)?.toInt(),
        adEligible: json['ad_eligible'] == true,
      );

  final bool accepted;
  final bool correct;
  final AttemptStatus attemptStatus;
  final int expectedNextIndex;
  final RejectionReason? rejectionReason;
  final int timerRemainingMs;
  final int? score;
  final int? userRank;
  final bool? nextLevelLocked;
  final int? nextLevelNumber;
  final bool adEligible;

  bool get levelPassed => attemptStatus == AttemptStatus.completed;
  bool get levelFailed =>
      attemptStatus == AttemptStatus.failed ||
      attemptStatus == AttemptStatus.expired ||
      attemptStatus == AttemptStatus.invalid ||
      attemptStatus == AttemptStatus.suspicious;
}

/// `GET /v1/game/attempts/{id}` — resync after a network drop mid-level.
class AttemptState {
  const AttemptState({
    required this.attemptId,
    required this.status,
    required this.expectedNextIndex,
    required this.score,
    required this.levelNumber,
  });

  factory AttemptState.fromJson(Map<String, dynamic> json) => AttemptState(
        attemptId: '${json['attempt_id']}',
        status: AttemptStatus.parse(json['status']),
        expectedNextIndex: (json['expected_next_index'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toInt(),
        levelNumber: (json['level_number'] as num?)?.toInt() ?? 1,
      );

  final String attemptId;
  final AttemptStatus status;
  final int expectedNextIndex;
  final int? score;
  final int levelNumber;
}
