import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/level.dart';

/// One node on the M-11 level map.
class LevelNode extends StatelessWidget {
  const LevelNode({
    super.key,
    required this.level,
    required this.onTap,
    this.diameter = 64,
  });

  final LevelSummary level;
  final VoidCallback onTap;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    final String stateLabel = level.completed
        ? l10n.levelNodeStateCompleted
        : level.locked
            ? l10n.levelNodeStateLocked
            : l10n.levelNodeStateUnlocked;

    final Gradient? fillGradient = level.completed
        ? AppColors.completedNodeGradient
        : level.locked
            ? null
            : AppColors.unlockedNodeGradient;

    final Color flatColor = level.locked ? AppColors.locked : theme.colorScheme.primary;

    final Color foreground = level.locked && !level.completed
        ? Colors.white.withOpacity(0.85)
        : Colors.white;

    return Semantics(
      button: true,
      label: l10n.levelNodeSemantics(level.levelNumber, stateLabel),
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.levelNodeSemantics(level.levelNumber, stateLabel),
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Material(
            elevation: level.isCurrent ? 8 : level.locked ? 0 : 4,
            shadowColor: level.locked
                ? Colors.transparent
                : (level.completed ? AppColors.success : AppColors.primary)
                    .withOpacity(0.55),
            shape: const CircleBorder(),
            color: fillGradient == null ? flatColor : Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Ink(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: fillGradient,
                  color: fillGradient == null ? flatColor : null,
                  border: level.isCurrent
                      ? Border.all(color: AppColors.tertiary, width: 4)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (level.completed)
                        Icon(Icons.check_rounded, size: 18, color: foreground)
                      else if (level.locked)
                        Icon(Icons.lock_rounded, size: 16, color: foreground),
                      Text(
                        '${level.levelNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// M-18 variant — practice levels use the purple-to-cyan gradient.
class PracticeLevelNode extends StatelessWidget {
  const PracticeLevelNode({
    super.key,
    required this.levelNumber,
    required this.ready,
    required this.onTap,
    this.diameter = 64,
  });

  final int levelNumber;
  final bool ready;
  final VoidCallback onTap;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      label: l10n.levelNodeLabel(levelNumber),
      excludeSemantics: true,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Material(
          elevation: ready ? 4 : 0,
          shadowColor: AppColors.secondary.withOpacity(0.45),
          color: ready ? Colors.transparent : AppColors.locked,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Ink(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: ready ? AppColors.practiceNodeGradient : null,
                color: ready ? null : AppColors.locked,
              ),
              child: Center(
                child: Text(
                  '$levelNumber',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LevelNodeSkeleton extends StatelessWidget {
  const LevelNodeSkeleton({super.key, this.diameter = 64});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.secondary.withOpacity(0.15),
        ),
      ),
    );
  }
}
