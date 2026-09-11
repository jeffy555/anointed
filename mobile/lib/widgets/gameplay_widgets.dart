import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../core/tokens.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/level.dart';
import 'character_image.dart';

/// Countdown display for M-13/M-19.
///
/// design-spec §8 requires the remaining time to be *announced* at 30s, 10s and
/// 5s rather than only shown, and design-spec §7 changes its colour at the 10s
/// and 5s thresholds.
class TimerDisplay extends StatefulWidget {
  const TimerDisplay({
    super.key,
    required this.secondsRemaining,
    required this.totalSeconds,
  });

  final int secondsRemaining;
  final int totalSeconds;

  @override
  State<TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<TimerDisplay> {
  static const Set<int> _announceAt = <int>{30, 10, 5};
  int? _lastAnnounced;

  @override
  void didUpdateWidget(TimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int seconds = widget.secondsRemaining;
    if (_announceAt.contains(seconds) && _lastAnnounced != seconds) {
      _lastAnnounced = seconds;
      SemanticsService.announce(
        AppLocalizations.of(context).gameplayTimerSemantics(seconds),
        Directionality.of(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = timerColorFor(widget.secondsRemaining, isDark: isDark);
    final double progress = widget.totalSeconds <= 0
        ? 0
        : (widget.secondsRemaining / widget.totalSeconds).clamp(0.0, 1.0);

    return Semantics(
      label: l10n.gameplayTimerSemantics(widget.secondsRemaining),
      excludeSemantics: true,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                backgroundColor: color.withOpacity(0.16),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '${widget.secondsRemaining}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The prompt area of M-13/M-19. Only this part changes between variant types;
/// the four answer buttons are identical for all three (design-spec §18H).
class QuestionPrompt extends StatelessWidget {
  const QuestionPrompt({
    super.key,
    required this.variantType,
    required this.questionText,
    this.verseReference,
    this.verseExcerpt,
    this.imageAssetKey,
    this.imageAltText,
  });

  final VariantType variantType;
  final String questionText;
  final String? verseReference;
  final String? verseExcerpt;
  final String? imageAssetKey;
  final String? imageAltText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    switch (variantType) {
      case VariantType.verseClue:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (verseReference != null && verseReference!.isNotEmpty)
              Text(
                verseReference!,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.secondary),
              ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: AppRadius.cardRadius,
                border: Border(
                  left: BorderSide(color: theme.colorScheme.secondary, width: 4),
                ),
              ),
              child: Text(
                verseExcerpt ?? '',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              questionText.isEmpty ? l10n.gameplayVersePrompt : questionText,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        );

      case VariantType.imageClue:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CharacterImage(
              imageAssetKey: imageAssetKey,
              imageAltText: imageAltText,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              questionText.isEmpty ? l10n.gameplayImagePrompt : questionText,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        );

      case VariantType.textQa:
        return Text(questionText, style: theme.textTheme.bodyLarge);
    }
  }
}

/// One of four answer choices. 48dp minimum target (design-spec §8) and the
/// correct/wrong result is conveyed by icon + announcement, never colour alone.
class AnswerOptionButton extends StatelessWidget {
  const AnswerOptionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.state = AnswerOptionState.idle,
  });

  final String label;
  final VoidCallback? onPressed;
  final AnswerOptionState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final (Color border, Color background, IconData? icon) = switch (state) {
      AnswerOptionState.idle => (
          theme.colorScheme.onSurface.withOpacity(0.24),
          theme.cardColor,
          null,
        ),
      AnswerOptionState.correct => (
          AppColors.success,
          AppColors.success.withOpacity(0.12),
          Icons.check_circle_rounded,
        ),
      AnswerOptionState.wrong => (
          theme.colorScheme.error,
          theme.colorScheme.error.withOpacity(0.12),
          Icons.cancel_rounded,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
        child: Material(
          color: background,
          borderRadius: AppRadius.cardRadius,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadius.cardRadius,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: border,
                  width: state == AnswerOptionState.idle ? 1 : 2,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                  if (icon != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(icon, color: border),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum AnswerOptionState { idle, correct, wrong }

/// "Question X of 10", announced on every transition (design-spec §8).
class QuestionProgressLabel extends StatelessWidget {
  const QuestionProgressLabel({
    super.key,
    required this.index,
    required this.total,
  });

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final String text = AppLocalizations.of(context).gameplayProgress(index, total);
    return Semantics(
      liveRegion: true,
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// Label for a question variant type, used by the M-12 question-mix preview.
String variantTypeLabel(AppLocalizations l10n, VariantType type) {
  switch (type) {
    case VariantType.textQa:
      return l10n.variantTextQa;
    case VariantType.verseClue:
      return l10n.variantVerseClue;
    case VariantType.imageClue:
      return l10n.variantImageClue;
  }
}

IconData variantTypeIcon(VariantType type) {
  switch (type) {
    case VariantType.textQa:
      return Icons.help_outline_rounded;
    case VariantType.verseClue:
      return Icons.menu_book_rounded;
    case VariantType.imageClue:
      return Icons.image_outlined;
  }
}

String difficultyLabel(AppLocalizations l10n, DifficultyTier tier) {
  switch (tier) {
    case DifficultyTier.easy:
      return l10n.difficultyEasy;
    case DifficultyTier.medium:
      return l10n.difficultyMedium;
    case DifficultyTier.hard:
      return l10n.difficultyHard;
    case DifficultyTier.expert:
      return l10n.difficultyExpert;
  }
}
