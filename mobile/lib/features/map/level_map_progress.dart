import '../../models/level.dart';

enum ParchmentTileState { done, current, unlocked, locked }

/// Derives map UI state from [LevelMap] — single source for progress bar,
/// chapter counts, and tile states (no duplicated counters).
class LevelMapProgress {
  const LevelMapProgress({
    required this.currentLevel,
    required this.unlockedThrough,
    required this.totalLevels,
  });

  factory LevelMapProgress.fromMap(LevelMap map) {
    return LevelMapProgress(
      currentLevel: map.currentLevel,
      unlockedThrough: map.hasUnlock ? map.totalLevels : map.freeTierMaxLevel,
      totalLevels: map.totalLevels,
    );
  }

  final int currentLevel;
  final int unlockedThrough;
  final int totalLevels;

  int get completedCount => (currentLevel - 1).clamp(0, totalLevels);

  int get progressPercent =>
      totalLevels <= 0 ? 0 : ((completedCount / totalLevels) * 100).round();

  double get progressFraction => totalLevels <= 0
      ? 0
      : ((currentLevel - 1) / totalLevels).clamp(0.0, 1.0);

  ParchmentTileState tileState(int levelNumber) {
    if (levelNumber > unlockedThrough) return ParchmentTileState.locked;
    if (levelNumber < currentLevel) return ParchmentTileState.done;
    if (levelNumber == currentLevel) return ParchmentTileState.current;
    return ParchmentTileState.unlocked;
  }

  ParchmentTileState tileStateFor(LevelSummary level) =>
      tileState(level.levelNumber);

  bool isTappable(ParchmentTileState state) =>
      state == ParchmentTileState.done ||
      state == ParchmentTileState.current ||
      state == ParchmentTileState.unlocked;
}
