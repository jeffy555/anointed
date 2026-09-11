import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../models/level.dart';
import 'level_map_progress.dart';
import 'parchment_codex_tokens.dart';

/// Fixed header: ANOINTED / Level map + streak & points chips.
class ParchmentMapHeader extends StatelessWidget {
  const ParchmentMapHeader({
    super.key,
    required this.streak,
    required this.points,
  });

  final int streak;
  final int points;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ParchmentColors.page,
        border: Border(
          bottom: BorderSide(color: ParchmentColors.inkBorder(0.09)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'ANOINTED',
                    style: ParchmentText.karla(
                      size: 10,
                      weight: FontWeight.w700,
                      color: ParchmentColors.gold,
                      letterSpacing: 2.2,
                    ),
                  ),
                  Text(
                    'Level map',
                    style: ParchmentText.cormorant(size: 21),
                  ),
                ],
              ),
            ),
            Row(
              children: <Widget>[
                _StatChip(
                  value: '$streak',
                  leading: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      color: ParchmentColors.current,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  value: '$points',
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: ParchmentColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.leading});

  final String value;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: ParchmentColors.creamDark,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ParchmentColors.gold.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          leading,
          const SizedBox(width: 6),
          Text(
            value,
            style: ParchmentText.karla(
              size: 13,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark journey card with progress bar.
class ParchmentJourneyCard extends StatelessWidget {
  const ParchmentJourneyCard({
    super.key,
    required this.progress,
  });

  final LevelMapProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ParchmentColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            top: -28,
            right: -36,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ParchmentColors.goldLight.withOpacity(0.35),
                ),
              ),
            ),
          ),
          Positioned(
            top: -8,
            right: 18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ParchmentColors.goldLight.withOpacity(0.2),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'YOUR JOURNEY',
                style: ParchmentText.karla(
                  size: 11,
                  weight: FontWeight.w600,
                  color: ParchmentColors.goldLight,
                  letterSpacing: 1.76,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Level ${progress.currentLevel} of ${progress.totalLevels}',
                style: ParchmentText.cormorant(
                  size: 30,
                  color: ParchmentColors.page,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(color: ParchmentColors.page.withOpacity(0.16)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.progressFraction,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                ParchmentColors.goldLight,
                                ParchmentColors.goldPale,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '${progress.completedCount} completed',
                    style: ParchmentText.karla(
                      size: 12,
                      weight: FontWeight.w500,
                      color: ParchmentColors.parchmentMuted(),
                    ),
                  ),
                  Text(
                    '${progress.progressPercent}%',
                    style: ParchmentText.karla(
                      size: 12,
                      weight: FontWeight.w500,
                      color: ParchmentColors.parchmentMuted(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dashed unlock-all row below the journey card.
class ParchmentUnlockRow extends StatelessWidget {
  const ParchmentUnlockRow({
    super.key,
    required this.hasUnlock,
    required this.lockedFrom,
    required this.totalLevels,
    required this.onUnlockAll,
  });

  final bool hasUnlock;
  final int lockedFrom;
  final int totalLevels;
  final VoidCallback onUnlockAll;

  @override
  Widget build(BuildContext context) {
    final String status = hasUnlock
        ? 'All $totalLevels levels unlocked'
        : 'Levels $lockedFrom–$totalLevels locked';

    return Material(
      color: ParchmentColors.creamDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: hasUnlock ? null : onUnlockAll,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: ParchmentColors.gold.withOpacity(0.6),
            radius: 14,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: Row(
                children: <Widget>[
                  const _PadlockGlyph(
                    size: 14,
                    color: ParchmentColors.gold,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status,
                      style: ParchmentText.karla(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: ParchmentColors.brown,
                      ),
                    ),
                  ),
                  if (!hasUnlock)
                    Text(
                      'Unlock all',
                      style: ParchmentText.karla(
                        size: 12.5,
                        weight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: ParchmentColors.goldLight,
                        decorationThickness: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + 5;
        canvas.drawPath(
          metric.extractPath(distance, math.min(next, metric.length)),
          paint,
        );
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
/// All levels in one continuous grid.
///
/// The journey is a single run of numbered levels — no book/chapter grouping —
/// so the only structure a player has to hold is "where am I up to".
class ParchmentLevelGrid extends StatelessWidget {
  const ParchmentLevelGrid({
    super.key,
    required this.levels,
    required this.progress,
    required this.onLevelTap,
    this.perRow = 5,
  });

  final List<LevelSummary> levels;
  final LevelMapProgress progress;
  final ValueChanged<LevelSummary> onLevelTap;
  final int perRow;

  @override
  Widget build(BuildContext context) {
    final List<List<LevelSummary>> rows = <List<LevelSummary>>[];
    for (int i = 0; i < levels.length; i += perRow) {
      rows.add(levels.sublist(i, math.min(i + perRow, levels.length)));
    }

    return Container(
      decoration: BoxDecoration(
        color: ParchmentColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParchmentColors.inkBorder(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
        child: Column(
          children: <Widget>[
            for (int r = 0; r < rows.length; r++) ...<Widget>[
              if (r > 0) const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  for (int i = 0; i < perRow; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < perRow - 1 ? 8 : 0),
                        child: i < rows[r].length
                            ? ParchmentLevelNode(
                                level: rows[r][i],
                                state: progress.tileStateFor(rows[r][i]),
                                onTap: () => onLevelTap(rows[r][i]),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class ParchmentLevelNode extends StatefulWidget {
  const ParchmentLevelNode({
    super.key,
    required this.level,
    required this.state,
    required this.onTap,
  });

  final LevelSummary level;
  final ParchmentTileState state;
  final VoidCallback onTap;

  @override
  State<ParchmentLevelNode> createState() => _ParchmentLevelNodeState();
}

class _ParchmentLevelNodeState extends State<ParchmentLevelNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.state == ParchmentTileState.current) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(ParchmentLevelNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == ParchmentTileState.current && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (widget.state != ParchmentTileState.current) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showLabelBelow =
        widget.state != ParchmentTileState.locked &&
        widget.state != ParchmentTileState.current &&
        widget.state != ParchmentTileState.unlocked;

    Widget tile = SizedBox(
      height: 44,
      width: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Locked tiles stay tappable on purpose: the map screen answers that
          // tap with the unlock offer, which it could never do while the node
          // swallowed the gesture.
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: _buildTileBody(),
        ),
      ),
    );

    if (widget.state == ParchmentTileState.current) {
      tile = SizedBox(
        height: 44,
        width: 44,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            AnimatedBuilder(
              animation: _pulse,
              builder: (BuildContext context, Widget? child) {
                final double t = Curves.easeOut.transform(_pulse.value);
                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ParchmentColors.goldLight.withOpacity(0.55 * (1 - t)),
                      width: 2,
                    ),
                  ),
                  transform: Matrix4.identity()..scale(1 + t * 0.5),
                );
              },
            ),
            tile,
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        tile,
        if (showLabelBelow) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            '${widget.level.levelNumber}',
            style: ParchmentText.karla(
              size: 10,
              weight: FontWeight.w600,
              color: ParchmentColors.inkMuted(),
            ),
          ),
        ] else
          const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildTileBody() {
    switch (widget.state) {
      case ParchmentTileState.done:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: ParchmentColors.ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              '✓',
              style: ParchmentText.karla(
                size: 17,
                weight: FontWeight.w600,
                color: ParchmentColors.goldLight,
              ),
            ),
          ),
        );
      case ParchmentTileState.current:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: ParchmentColors.current,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: ParchmentColors.currentShadow,
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${widget.level.levelNumber}',
              style: ParchmentText.karla(
                size: 17,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        );
      case ParchmentTileState.unlocked:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: ParchmentColors.cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ParchmentColors.ink, width: 2),
          ),
          child: Center(
            child: Text(
              '${widget.level.levelNumber}',
              style: ParchmentText.karla(
                size: 16,
                weight: FontWeight.w700,
              ),
            ),
          ),
        );
      case ParchmentTileState.locked:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: ParchmentColors.lockedFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Opacity(
              opacity: 0.5,
              child: _PadlockGlyph(
                size: 16,
                color: ParchmentColors.brown,
              ),
            ),
          ),
        );
    }
  }
}

class _PadlockGlyph extends StatelessWidget {
  const _PadlockGlyph({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.15),
      painter: _PadlockPainter(color: color),
    );
  }
}

class _PadlockPainter extends CustomPainter {
  const _PadlockPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final double bodyTop = size.height * 0.42;
    canvas.drawArc(
      Rect.fromLTWH(1, 0, size.width - 2, size.height * 0.58),
      math.pi,
      math.pi,
      false,
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, bodyTop, size.width, size.height - bodyTop),
        const Radius.circular(2.5),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _PadlockPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Bottom tab bar — Parchment Codex direction 1a.
class ParchmentTabBar extends StatelessWidget {
  const ParchmentTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.labels,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ParchmentColors.cream,
        border: Border(top: BorderSide(color: ParchmentColors.inkBorder(0.1))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: Row(
          children: List<Widget>.generate(labels.length, (int index) {
            return Expanded(
              child: _ParchmentTabItem(
                label: labels[index],
                selected: index == selectedIndex,
                icon: _iconForIndex(index, index == selectedIndex),
                onTap: () => onSelected(index),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _iconForIndex(int index, bool selected) {
    switch (index) {
      case 0:
        return _TabIcon.square(filled: selected);
      case 1:
        return _TabIcon.circle(filled: selected);
      case 2:
        return _TabIcon.diamond(filled: selected);
      default:
        return _TabIcon.person(filled: selected);
    }
  }
}

class _ParchmentTabItem extends StatelessWidget {
  const _ParchmentTabItem({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? ParchmentColors.strip : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: icon,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: ParchmentText.karla(
                  size: 10.5,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? ParchmentColors.ink
                      : ParchmentColors.inkMuted(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon._({required this.child});

  factory _TabIcon.square({required bool filled}) {
    return _TabIcon._(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: filled ? ParchmentColors.current : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: filled
              ? null
              : Border.all(
                  color: ParchmentColors.inkMuted(0.35),
                  width: 2,
                ),
        ),
      ),
    );
  }

  factory _TabIcon.circle({required bool filled}) {
    return _TabIcon._(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? ParchmentColors.current : Colors.transparent,
          border: filled
              ? null
              : Border.all(
                  color: ParchmentColors.inkMuted(0.35),
                  width: 2,
                ),
        ),
      ),
    );
  }

  factory _TabIcon.diamond({required bool filled}) {
    return _TabIcon._(
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: filled ? ParchmentColors.current : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: filled
                ? null
                : Border.all(
                    color: ParchmentColors.inkMuted(0.35),
                    width: 2,
                  ),
          ),
        ),
      ),
    );
  }

  factory _TabIcon.person({required bool filled}) {
    return _TabIcon._(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CustomPaint(
          painter: _PersonIconPainter(
            color: filled ? ParchmentColors.current : ParchmentColors.inkMuted(0.35),
            filled: filled,
          ),
        ),
      ),
    );
  }

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _PersonIconPainter extends CustomPainter {
  const _PersonIconPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.32),
      size.width * 0.18,
      paint,
    );
    if (filled) {
      canvas.drawArc(
        Rect.fromLTWH(2, size.height * 0.52, size.width - 4, size.height * 0.42),
        math.pi,
        math.pi,
        true,
        paint,
      );
    } else {
      canvas.drawArc(
        Rect.fromLTWH(2, size.height * 0.5, size.width - 4, size.height * 0.46),
        math.pi * 1.05,
        math.pi * 0.9,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PersonIconPainter oldDelegate) =>
      color != oldDelegate.color || filled != oldDelegate.filled;
}
