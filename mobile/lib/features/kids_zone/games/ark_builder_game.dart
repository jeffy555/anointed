import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';

/// Level 1 — drag timber onto the glowing blueprint to build the Ark.
///
/// Three stages escalate from a few large beams to the small finishing pieces,
/// and everything placed in an earlier stage stays on screen, so the Ark visibly
/// grows the way Noah's did.
class ArkBuilderGame extends StatefulWidget {
  const ArkBuilderGame({
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
  State<ArkBuilderGame> createState() => _ArkBuilderGameState();
}

class _ArkBuilderGameState extends State<ArkBuilderGame> {
  /// How close a drop must land, as a fraction of the build area's short side.
  static const double _snapTolerance = 0.14;

  final KidsZoneAudioService _audio = KidsZoneAudioService.instance;
  final GlobalKey _buildAreaKey = GlobalKey();

  final Set<String> _placed = <String>{};
  int _stageIndex = 0;
  int _misses = 0;
  bool _stageCleared = false;

  /// Blueprint size, captured at layout time. The tray sizes its drag feedback
  /// from this, so it must never be read off the build area's RenderBox during
  /// build — on the first frame that box exists but has not been laid out yet.
  Size? _areaSize;

  /// The piece currently in the child's hand, and how close it is to home.
  ///
  /// A wide piece like the keel has a wide landing zone, but nothing on screen
  /// said so — the child had to guess. Now its outline lights up as they near
  /// it, turning "drop it exactly right" into "follow the glow".
  ArkPiece? _dragging;
  double _magnetism = 0;

  /// The drop is forgiving out to this multiple of the snap zone; the glow
  /// starts at twice that, so there is a run-up rather than a hard edge.
  static const double _magnetRange = 2.0;

  List<ArkBuildStage> get _stages => widget.definition.arkStages;

  ArkBuildStage get _stage => _stages[_stageIndex];

  bool get _isLastStage => _stageIndex >= _stages.length - 1;

  /// Every piece from this and earlier stages — the cumulative Ark.
  List<ArkPiece> get _visiblePieces => <ArkPiece>[
        for (int i = 0; i <= _stageIndex; i++) ..._stages[i].pieces,
      ];

  List<ArkPiece> get _trayPieces => _stage.pieces
      .where((ArkPiece p) => !_placed.contains(p.id))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _audio.startCreationAmbience(track: KidsZoneBgm.interesting);
  }

  @override
  void dispose() {
    _audio.stopAmbience();
    super.dispose();
  }

  /// [pointerGlobal] is the finger position at release. Because the tray uses
  /// [pointerDragAnchorStrategy] and centres the feedback on the pointer, that
  /// position is also the piece's centre — no half-size correction, which is
  /// what previously made wide pieces like the keel impossible to place.
  void _onDropped(ArkPiece piece, Offset pointerGlobal) {
    final RenderBox? box =
        _buildAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final Offset localCentre = box.globalToLocal(pointerGlobal);
    final Size area = box.size;
    final Offset target = Offset(
      piece.targetLeft * area.width,
      piece.targetTop * area.height,
    );
    // A generous target box: at least the base radius, and never smaller than
    // the piece's own footprint, so a long keel accepts a long landing zone
    // instead of demanding a pinpoint drop at its centre.
    final (double marginX, double marginY) = _snapMargins(piece, area);

    final bool onTarget = (localCentre.dx - target.dx).abs() <= marginX &&
        (localCentre.dy - target.dy).abs() <= marginY;

    if (onTarget) {
      _acceptPiece(piece);
    } else {
      _rejectPiece();
    }
  }

  void _acceptPiece(ArkPiece piece) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    _audio.playConnect();
    setState(() => _placed.add(piece.id));
    SemanticsService.announce(
      l10n.kidsZoneArkPiecePlaced(piece.label),
      Directionality.of(context),
    );

    final bool stageDone =
        _stage.pieces.every((ArkPiece p) => _placed.contains(p.id));
    if (!stageDone) return;

    _audio.playCelebrate();
    setState(() => _stageCleared = true);
  }

  void _rejectPiece() {
    _audio.playSparkle();
    setState(() => _misses += 1);
  }

  /// Margins that decide whether a drop lands. Shared by the drop test and the
  /// glow, so what the child is shown is exactly what will be accepted.
  (double, double) _snapMargins(ArkPiece piece, Size area) {
    final double base = math.min(area.width, area.height) * _snapTolerance;
    final Size pieceSize = _pieceSize(piece, area);
    return (
      math.max(base, pieceSize.width * 0.55),
      math.max(base, pieceSize.height * 0.9),
    );
  }

  void _onDragMoved(ArkPiece piece, Offset globalPosition) {
    final RenderBox? box =
        _buildAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final Size area = box.size;
    final Offset local = box.globalToLocal(globalPosition);
    final Offset target = Offset(
      piece.targetLeft * area.width,
      piece.targetTop * area.height,
    );
    final (double marginX, double marginY) = _snapMargins(piece, area);

    // How far into the approach we are: 0 outside the glow, 1 inside the zone
    // where the piece will actually snap.
    final double dx = (local.dx - target.dx).abs() / (marginX * _magnetRange);
    final double dy = (local.dy - target.dy).abs() / (marginY * _magnetRange);
    final double reach = math.max(dx, dy);
    final double next = (1 - reach).clamp(0.0, 1.0);

    if ((next - _magnetism).abs() < 0.01) return;
    setState(() => _magnetism = next);
  }

  void _nextStage() {
    if (_isLastStage) {
      // Twenty-four pieces across four stages, so allow a few stray drops.
      final int stars = _misses <= 3 ? 3 : (_misses <= 9 ? 2 : 1);
      widget.onComplete(stars);
      return;
    }
    setState(() {
      _stageIndex += 1;
      _stageCleared = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: _stage.cue,
      readAloudText: _stage.cue,
      pauseKidsZoneBgm: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                // Both the chip and the title give way before the counter: the
                // count of pieces placed is the shortest and the one the child
                // checks, so it is the one that must stay whole.
                Flexible(
                  child: _StageChip(
                    label: l10n.kidsZoneArkStageLabel(
                      _stage.stage,
                      _stages.length,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  flex: 2,
                  child: Text(
                    _stage.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KidsZoneText.nunito(size: 15, weight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${_placed.length}/${_visiblePieces.length}',
                  style: KidsZoneText.nunito(
                    size: 14,
                    weight: FontWeight.w800,
                    color: ArkColors.timberDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _buildArea(),
                    if (_stageCleared)
                      _StageClearedOverlay(
                        title: _isLastStage
                            ? l10n.kidsZoneArkBuiltTitle
                            : l10n.kidsZoneArkStageDone,
                        body: _isLastStage
                            ? l10n.kidsZoneArkBuiltBody
                            : l10n.kidsZoneArkStageNext,
                        actionLabel: _isLastStage
                            ? l10n.kidsZoneGameFinish
                            : l10n.kidsZoneArkKeepBuilding,
                        onAction: _nextStage,
                        finale: _isLastStage,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 92,
              child: _trayPieces.isEmpty
                  ? Center(
                      child: Text(
                        l10n.kidsZoneArkTrayEmpty,
                        style: KidsZoneText.nunito(
                          size: 13,
                          weight: FontWeight.w700,
                          color: KidsZoneColors.inkMuted,
                        ),
                      ),
                    )
                  : _buildTray(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArea() {
    return DragTarget<ArkPiece>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (DragTargetDetails<ArkPiece> details) =>
          _onDropped(details.data, details.offset),
      builder: (BuildContext context, _, __) {
        return LayoutBuilder(
          key: _buildAreaKey,
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size area = Size(constraints.maxWidth, constraints.maxHeight);
            _rememberAreaSize(area);
            return Stack(
              key: const ValueKey<String>('ark-build-area'),
              fit: StackFit.expand,
              children: <Widget>[
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: _blueprintGradient),
                ),
                CustomPaint(painter: _BlueprintGridPainter()),
                for (final ArkPiece piece in _visiblePieces)
                  _positioned(
                    piece,
                    area,
                    _PieceView(
                      piece: piece,
                      ghost: !_placed.contains(piece.id),
                      // Only the outline of the piece in hand lights up.
                      magnetism:
                          _dragging?.id == piece.id ? _magnetism : 0,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// LayoutBuilder runs during layout, so the rebuild is deferred to the next
  /// frame rather than calling setState mid-layout.
  void _rememberAreaSize(Size area) {
    if (_areaSize == area) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _areaSize != area) setState(() => _areaSize = area);
    });
  }

  Widget _buildTray() {
    final Size? area = _areaSize;
    // Before the blueprint has been laid out there is no real scale to drag
    // against, so hold the tray back one frame rather than guess a size.
    if (area == null) return const SizedBox.shrink();

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _trayPieces.length,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        final ArkPiece piece = _trayPieces[index];
        return _TrayPiece(
          piece: piece,
          fullSize: _pieceSize(piece, area),
          onCancelled: _rejectPiece,
          onDragStarted: () => setState(() {
            _dragging = piece;
            _magnetism = 0;
          }),
          onDragMoved: (Offset global) => _onDragMoved(piece, global),
          onDragStopped: () => setState(() {
            _dragging = null;
            _magnetism = 0;
          }),
        );
      },
    );
  }

  Size _pieceSize(ArkPiece piece, Size area) =>
      Size(piece.width * area.width, piece.height * area.height);

  Widget _positioned(ArkPiece piece, Size area, Widget child) {
    final Size size = _pieceSize(piece, area);
    return Positioned(
      left: piece.targetLeft * area.width - size.width / 2,
      top: piece.targetTop * area.height - size.height / 2,
      width: size.width,
      height: size.height,
      child: piece.rotation == 0
          ? child
          : Transform.rotate(angle: piece.rotation, child: child),
    );
  }
}

const LinearGradient _blueprintGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[Color(0xFF16405E), Color(0xFF1E5B7E)],
);

/// Draggable timber in the tray, sized to its finished footprint while dragging
/// so children can judge the fit before letting go.
class _TrayPiece extends StatelessWidget {
  const _TrayPiece({
    required this.piece,
    required this.fullSize,
    required this.onCancelled,
    required this.onDragStarted,
    required this.onDragMoved,
    required this.onDragStopped,
  });

  final ArkPiece piece;
  final Size fullSize;
  final VoidCallback onCancelled;
  final VoidCallback onDragStarted;
  final ValueChanged<Offset> onDragMoved;
  final VoidCallback onDragStopped;

  @override
  Widget build(BuildContext context) {
    final Widget feedback = Transform.rotate(
      angle: piece.rotation,
      child: SizedBox(
        width: fullSize.width,
        height: fullSize.height,
        child: _PieceView(piece: piece, ghost: false),
      ),
    );

    return Draggable<ArkPiece>(
      data: piece,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.translate(
          offset: Offset(-fullSize.width / 2, -fullSize.height / 2),
          child: feedback,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _TrayChip(piece: piece),
      ),
      onDragStarted: onDragStarted,
      onDragUpdate: (DragUpdateDetails d) => onDragMoved(d.globalPosition),
      onDragEnd: (_) => onDragStopped(),
      onDraggableCanceled: (_, __) {
        onDragStopped();
        onCancelled();
      },
      child: _TrayChip(piece: piece),
    );
  }
}

class _TrayChip extends StatelessWidget {
  const _TrayChip({required this.piece});

  final ArkPiece piece;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: piece.label,
      button: true,
      child: Container(
        width: 92,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ArkColors.timberDark.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              height: 34,
              width: 68,
              child: _PieceView(piece: piece, ghost: false, compact: true),
            ),
            const SizedBox(height: 4),
            Text(
              piece.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: KidsZoneText.nunito(size: 11, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints one plank/beam/fitting, either as solid timber or as a target ghost.
class _PieceView extends StatelessWidget {
  const _PieceView({
    required this.piece,
    required this.ghost,
    this.compact = false,
    this.magnetism = 0,
  });

  final ArkPiece piece;
  final bool ghost;

  /// 0 → 1 as the piece being dragged approaches this outline.
  final double magnetism;

  /// Tray thumbnails skip the grain detail so they stay legible when small.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArkPiecePainter(
        shape: piece.shape,
        ghost: ghost,
        compact: compact,
        magnetism: magnetism,
      ),
    );
  }
}

class _ArkPiecePainter extends CustomPainter {
  _ArkPiecePainter({
    required this.shape,
    required this.ghost,
    required this.compact,
    this.magnetism = 0,
  });

  final ArkPieceShape shape;
  final bool ghost;
  final bool compact;

  /// 0 → 1 closeness of the piece in hand; brightens the outline.
  final double magnetism;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _pathFor(shape, size);

    if (ghost) {
      // As the piece nears home the outline warms from blueprint blue to gold
      // and fills in — the child can see the landing zone accepting them.
      final Color tint = Color.lerp(
        ArkColors.blueprint,
        ArkColors.straw,
        magnetism,
      )!;

      if (magnetism > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = tint.withOpacity(0.35 * magnetism)
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, 6 + 10 * magnetism),
        );
      }

      canvas.drawPath(
        path,
        Paint()..color = tint.withOpacity(0.14 + 0.30 * magnetism),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = tint.withOpacity(0.85 + 0.15 * magnetism)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 2.5 * magnetism,
      );
      return;
    }

    canvas.drawPath(path, Paint()..color = ArkColors.timber);
    canvas.drawPath(
      path,
      Paint()
        ..color = ArkColors.timberDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (compact) return;
    _paintDetail(canvas, size);
  }

  void _paintDetail(Canvas canvas, Size size) {
    final Paint grain = Paint()
      ..color = ArkColors.timberDark.withOpacity(0.35)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    switch (shape) {
      case ArkPieceShape.beam:
      case ArkPieceShape.plank:
      case ArkPieceShape.rib:
        final bool horizontal = size.width >= size.height;
        final int lines = horizontal ? 2 : 1;
        for (int i = 1; i <= lines; i++) {
          final double f = i / (lines + 1);
          if (horizontal) {
            canvas.drawLine(
              Offset(size.width * 0.08, size.height * f),
              Offset(size.width * 0.92, size.height * f),
              grain,
            );
          } else {
            canvas.drawLine(
              Offset(size.width * f, size.height * 0.08),
              Offset(size.width * f, size.height * 0.92),
              grain,
            );
          }
        }
      case ArkPieceShape.ramp:
        for (int i = 1; i <= 3; i++) {
          final double x = size.width * (i / 4);
          canvas.drawLine(
            Offset(x, size.height * 0.15),
            Offset(x, size.height * 0.85),
            grain,
          );
        }
      case ArkPieceShape.roof:
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.1),
          Offset(size.width * 0.5, size.height * 0.9),
          grain,
        );
      case ArkPieceShape.mast:
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.12),
          Offset(size.width * 0.5, size.height * 0.88),
          grain,
        );
      case ArkPieceShape.door:
        canvas.drawCircle(
          Offset(size.width * 0.75, size.height * 0.5),
          math.max(2.0, size.width * 0.07),
          Paint()..color = ArkColors.straw,
        );
      case ArkPieceShape.window:
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.12),
          Offset(size.width * 0.5, size.height * 0.88),
          grain,
        );
        canvas.drawLine(
          Offset(size.width * 0.12, size.height * 0.5),
          Offset(size.width * 0.88, size.height * 0.5),
          grain,
        );
    }
  }

  Path _pathFor(ArkPieceShape shape, Size size) {
    final Radius radius = Radius.circular(
      math.min(size.width, size.height) * 0.28,
    );

    switch (shape) {
      case ArkPieceShape.roof:
        // Trapezoid — wider at the eaves.
        return Path()
          ..moveTo(size.width * 0.12, 0)
          ..lineTo(size.width * 0.88, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
      case ArkPieceShape.window:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Offset.zero & size,
              Radius.circular(math.min(size.width, size.height) * 0.16),
            ),
          );
      case ArkPieceShape.door:
        // Rounded at the top like an ark hatch.
        return Path()
          ..addRRect(
            RRect.fromRectAndCorners(
              Offset.zero & size,
              topLeft: Radius.circular(size.width * 0.45),
              topRight: Radius.circular(size.width * 0.45),
              bottomLeft: const Radius.circular(3),
              bottomRight: const Radius.circular(3),
            ),
          );
      case ArkPieceShape.mast:
        // Tapered pole — wider at the foot than the tip.
        return Path()
          ..moveTo(size.width * 0.32, 0)
          ..lineTo(size.width * 0.68, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
      case ArkPieceShape.beam:
      case ArkPieceShape.plank:
      case ArkPieceShape.rib:
      case ArkPieceShape.ramp:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    }
  }

  @override
  bool shouldRepaint(covariant _ArkPiecePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.ghost != ghost ||
      oldDelegate.compact != compact ||
      oldDelegate.magnetism != magnetism;
}

class _BlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = ArkColors.blueprint.withOpacity(0.10)
      ..strokeWidth = 1;
    const int cells = 12;
    for (int i = 1; i < cells; i++) {
      final double x = size.width * i / cells;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (int i = 1; i < cells; i++) {
      final double y = size.height * i / cells;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ArkColors.timber.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: KidsZoneText.nunito(size: 12, weight: FontWeight.w800),
      ),
    );
  }
}

/// The breather between stages.
///
/// Twenty-four pieces is a long build for a five-year-old, and going straight
/// from one stage into the next gave attention nowhere to reset. The ark rocks,
/// birds come down to land on it, and — on the final stage — a rainbow previews
/// the promise still to come.
class _StageClearedOverlay extends StatefulWidget {
  const _StageClearedOverlay({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.finale,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  /// The last stage earns the rainbow.
  final bool finale;

  @override
  State<_StageClearedOverlay> createState() => _StageClearedOverlayState();
}

class _StageClearedOverlayState extends State<_StageClearedOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _celebration = Duration(milliseconds: 3000);

  /// The button arrives well before the animation ends, so an impatient child
  /// is never held hostage by the reward.
  static const double _buttonAt = 0.42;

  late final AnimationController _play;

  @override
  void initState() {
    super.initState();
    _play = AnimationController(vsync: this, duration: _celebration)..forward();
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _play,
      builder: (BuildContext context, _) {
        final double t = _play.value;
        return _body(context, t);
      },
    );
  }

  Widget _body(BuildContext context, double t) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 96,
            width: 200,
            child: CustomPaint(
              painter: _CheckpointPainter(t: t, finale: widget.finale),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: KidsZoneText.nunito(
              size: 22,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.body,
            textAlign: TextAlign.center,
            style: KidsZoneText.nunito(
              size: 15,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedOpacity(
            opacity: t >= _buttonAt ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: t < _buttonAt,
              child: FilledButton.icon(
                onPressed: widget.onAction,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(widget.actionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: ArkColors.timber,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three-second checkpoint: the ark rocks on new water, birds settle onto
/// it, and the last stage gets a glimpse of the rainbow.
class _CheckpointPainter extends CustomPainter {
  _CheckpointPainter({required this.t, required this.finale});

  final double t;
  final bool finale;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.62;

    if (finale) {
      const List<Color> bow = <Color>[
        Color(0xFFE53935),
        Color(0xFFFF9800),
        Color(0xFFFFEB3B),
        Color(0xFF66BB6A),
        Color(0xFF42A5F5),
      ];
      // Sweeps in over the first two thirds.
      final double reveal = (t / 0.66).clamp(0.0, 1.0);
      for (int i = 0; i < bow.length; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: 76 - i * 7.0),
          math.pi,
          math.pi * reveal,
          false,
          Paint()
            ..color = bow[i].withOpacity(0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
      }
    }

    // The ark rides a gentle swell.
    final double rock = math.sin(t * math.pi * 3) * 0.06 * (1 - t);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rock);

    final Path hull = Path()
      ..moveTo(-52, -6)
      ..lineTo(52, -6)
      ..lineTo(38, 20)
      ..lineTo(-38, 20)
      ..close();
    canvas.drawPath(hull, Paint()..color = ArkColors.timber);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, -30, 52, 24),
        const Radius.circular(4),
      ),
      Paint()..color = ArkColors.timberLight,
    );
    canvas.restore();

    // Birds come down and land along the roofline.
    final Paint wing = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final double start = 0.15 + i * 0.12;
      final double p = ((t - start) / 0.45).clamp(0.0, 1.0);
      if (p <= 0) continue;

      final double x = cx - 34 + i * 30 + (1 - p) * 60;
      final double y = cy - 34 - (1 - p) * 46;
      // Wings still once landed.
      final double flap = p >= 1 ? 2 : 7 * math.sin(t * 26 + i);
      canvas.drawPath(
        Path()
          ..moveTo(x - 8, y)
          ..quadraticBezierTo(x - 4, y - flap, x, y)
          ..quadraticBezierTo(x + 4, y - flap, x + 8, y),
        wing,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CheckpointPainter old) =>
      old.t != t || old.finale != finale;
}
