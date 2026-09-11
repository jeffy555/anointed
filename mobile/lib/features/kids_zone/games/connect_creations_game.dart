import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';

/// Level 2 — connect each creation day to what God made (wire matching).
class ConnectCreationsGame extends StatefulWidget {
  const ConnectCreationsGame({
    super.key,
    required this.definition,
    required this.stopTitle,
    required this.adventureTitle,
    required this.onComplete,
  });

  final KidsZoneGameDefinition definition;
  final String stopTitle;
  final String adventureTitle;
  final ValueChanged<int> onComplete;

  @override
  State<ConnectCreationsGame> createState() => _ConnectCreationsGameState();
}

/// Vertical gap between rows, and the channel the wires run through.
const double _rowGap = AppSpacing.sm;
const double _columnGap = AppSpacing.lg;

/// Rows never shrink below a comfortable tap target; the board scrolls instead.
const double _minRowHeight = 44;

class _ConnectCreationsGameState extends State<ConnectCreationsGame> {
  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;

  late final List<DayCreationPair> _days;
  late final List<DayCreationPair> _creationsShuffled;
  late final Set<String> _dayIds;
  final Map<String, String> _connections = <String, String>{};
  String? _selectedDayId;
  int _attempts = 0;
  String? _feedback;
  final GlobalKey _stackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _audio.startCreationAmbience(track: KidsZoneBgm.funky);
    _days = List<DayCreationPair>.of(widget.definition.dayCreations);
    _dayIds = _days.map((DayCreationPair d) => d.dayId).toSet();

    // The right-hand column mixes the real creations with things God did not
    // make in the creation week, so the level asks a judgment rather than only
    // rewarding a memorised list of seven.
    _creationsShuffled = <DayCreationPair>[
      ..._days,
      ...widget.definition.creationDistractors,
    ]..shuffle(Random());
  }

  /// A creation card that belongs to no day.
  bool _isDistractor(String creationId) => !_dayIds.contains(creationId);

  void _tapDay(String dayId) {
    setState(() {
      _selectedDayId = dayId;
      _feedback = null;
    });
  }

  void _tapCreation(DayCreationPair creation) {
    if (_selectedDayId == null) return;
    setState(() {
      _connections[_selectedDayId!] = creation.dayId;
      _selectedDayId = null;
    });
    _audio.playConnect();
  }

  void _check(AppLocalizations l10n) {
    _attempts += 1;
    bool allCorrect = true;
    for (final DayCreationPair day in _days) {
      if (_connections[day.dayId] != day.dayId) {
        allCorrect = false;
        break;
      }
    }
    if (allCorrect && _connections.length == _days.length) {
      _audio.playCelebrate();
      final int stars = _attempts <= 1 ? 3 : (_attempts <= 3 ? 2 : 1);
      widget.onComplete(stars);
      return;
    }

    // Wiring up a car or a building is a different mistake from mixing up two
    // days, and deserves to be named as such.
    final bool usedDistractor = _connections.values.any(_isDistractor);
    setState(() => _feedback = usedDistractor
        ? l10n.kidsZoneConnectDistractor
        : l10n.kidsZoneConnectWrong);
  }

  void _reset() {
    setState(() {
      _connections.clear();
      _selectedDayId = null;
      _feedback = null;
    });
  }

  /// Stacks equal-height rows separated by [_rowGap].
  Widget _column({required double rowHeight, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          SizedBox(height: rowHeight, child: children[i]),
          if (i != children.length - 1) const SizedBox(height: _rowGap),
        ],
      ],
    );
  }

  Widget _dayCard(DayCreationPair day) {
    final bool selected = _selectedDayId == day.dayId;
    final bool connected = _connections.containsKey(day.dayId);

    return Material(
      color: selected
          ? day.color.withOpacity(0.35)
          : connected
              ? day.color.withOpacity(0.2)
              : KidsZoneColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _tapDay(day.dayId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              day.dayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KidsZoneText.nunito(size: 14, weight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _creationCard(DayCreationPair creation) {
    final bool isTarget = _connections.values.contains(creation.dayId);

    return Material(
      color: isTarget
          ? creation.color.withOpacity(0.25)
          : KidsZoneColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _tapCreation(creation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Icon(creation.icon, color: creation.color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  creation.creationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KidsZoneText.nunito(size: 13, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: widget.definition.intro,
      body: KidsZoneBoardLayout(
        padding: const EdgeInsets.all(AppSpacing.lg),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.kidsZoneConnectHint,
              style: KidsZoneText.nunito(size: 14, weight: FontWeight.w600, color: KidsZoneColors.inkMuted),
            ),
            if (_feedback != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _feedback!,
                style: KidsZoneText.nunito(size: 14, weight: FontWeight.w700, color: const Color(0xFFE65100)),
              ),
            ],
          ],
        ),
        board: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Both columns share one row height so rows line up across
            // the gap and the wire anchors stay exact. The creation
            // column is longer than the day column once distractors are
            // mixed in, so the taller of the two sets the row count.
            final int rows =
                max(_days.length, _creationsShuffled.length);
            final double fitted =
                (constraints.maxHeight - _rowGap * (rows - 1)) / rows;
            // Fill the space when everything fits; otherwise keep rows a
            // comfortable tap size and let the board scroll.
            final double rowHeight = max(fitted, _minRowHeight);
            final double boardHeight =
                rows * rowHeight + _rowGap * (rows - 1);
            final double leftWidth =
                (constraints.maxWidth - _columnGap) * 0.36;
            final double rightWidth =
                constraints.maxWidth - _columnGap - leftWidth;

            return SingleChildScrollView(
              child: SizedBox(
                height: boardHeight,
                child: Stack(
              key: _stackKey,
              children: <Widget>[
                CustomPaint(
                  size: Size.infinite,
                  painter: _ConnectionLinesPainter(
                    connections: Map<String, String>.of(_connections),
                    days: _days,
                    creations: _creationsShuffled,
                    rowHeight: rowHeight,
                    rowGap: _rowGap,
                    leftEdge: leftWidth,
                    rightEdge: leftWidth + _columnGap,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: leftWidth,
                      child: _column(
                        rowHeight: rowHeight,
                        children: <Widget>[
                          for (final DayCreationPair day in _days)
                            _dayCard(day),
                        ],
                      ),
                    ),
                    SizedBox(width: _columnGap),
                    SizedBox(
                      width: rightWidth,
                      child: _column(
                        rowHeight: rowHeight,
                        children: <Widget>[
                          for (final DayCreationPair creation
                              in _creationsShuffled)
                            _creationCard(creation),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
                ),
              ),
            );
          },
        ),
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          kidsZonePrimaryButton(
            label: l10n.kidsZoneConnectCheck,
            onPressed: _connections.length == _days.length ? () => _check(l10n) : null,
          ),
          TextButton(onPressed: _reset, child: Text(l10n.kidsZoneConnectReset)),
        ],
      ),
    );
  }
}

class _ConnectionLinesPainter extends CustomPainter {
  _ConnectionLinesPainter({
    required this.connections,
    required this.days,
    required this.creations,
    required this.rowHeight,
    required this.rowGap,
    required this.leftEdge,
    required this.rightEdge,
  });

  final Map<String, String> connections;
  final List<DayCreationPair> days;
  final List<DayCreationPair> creations;

  /// Measured row geometry — the wires anchor to the real cards rather than to
  /// an assumed row size, which previously left the lines pointing nowhere once
  /// a label wrapped onto a second line.
  final double rowHeight;
  final double rowGap;

  /// Right edge of the day column and left edge of the creation column.
  final double leftEdge;
  final double rightEdge;

  double _centreOf(int index) => index * (rowHeight + rowGap) + rowHeight / 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (connections.isEmpty) return;

    for (final MapEntry<String, String> entry in connections.entries) {
      final int dayIndex =
          days.indexWhere((DayCreationPair d) => d.dayId == entry.key);
      final int creationIndex =
          creations.indexWhere((DayCreationPair c) => c.dayId == entry.value);
      if (dayIndex < 0 || creationIndex < 0) continue;

      final DayCreationPair day = days[dayIndex];
      final Offset start = Offset(leftEdge, _centreOf(dayIndex));
      final Offset end = Offset(rightEdge, _centreOf(creationIndex));

      // A gentle S-curve through the channel reads far better than a straight
      // diagonal when several wires cross.
      final double midX = (start.dx + end.dx) / 2;
      final Path wire = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);

      canvas.drawPath(
        wire,
        Paint()
          ..color = day.color.withOpacity(0.85)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      // Little collars so it is obvious which cards a wire joins.
      canvas.drawCircle(start, 4, Paint()..color = day.color);
      canvas.drawCircle(end, 4, Paint()..color = day.color);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionLinesPainter oldDelegate) =>
      !mapEquals(oldDelegate.connections, connections) ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.rowGap != rowGap ||
      oldDelegate.leftEdge != leftEdge ||
      oldDelegate.rightEdge != rightEdge;
}
