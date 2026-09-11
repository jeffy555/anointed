import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../kids_zone_tokens.dart';
import '../levels/moses_exodus_level.dart';

/// Pharaoh's heart, cracking.
///
/// The one thing that spans the whole level. Without it each round is a
/// self-contained sorting exercise with nothing carrying over — this makes the
/// three rounds chapters of a single story instead, and it is a direct reading
/// of the text rather than decoration: *"Pharaoh's heart was hardened... until
/// he let the people go."*
///
/// It only ever moves forward. A wrong placement does not crack it and does not
/// un-crack it, so the meter reads as progress and can never be experienced as
/// damage the child has taken.
class PharaohResolveMeter extends StatefulWidget {
  const PharaohResolveMeter({
    super.key,
    required this.cracks,
    this.shattered = false,
  });

  /// Correct placements so far, 0..[kPharaohResolveCracks].
  final int cracks;

  /// The tenth placement has landed. Set by the same event that tips the
  /// crown off the palace, so the two payoffs cannot drift apart.
  final bool shattered;

  @override
  State<PharaohResolveMeter> createState() => _PharaohResolveMeterState();
}

class _PharaohResolveMeterState extends State<PharaohResolveMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chip;

  @override
  void initState() {
    super.initState();
    _chip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  @override
  void didUpdateWidget(PharaohResolveMeter old) {
    super.didUpdateWidget(old);
    if (widget.cracks != old.cracks) _chip.forward(from: 0);
  }

  @override
  void dispose() {
    _chip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double share = widget.cracks / kPharaohResolveCracks;

    return Semantics(
      label: l10n.kidsZonePlagueResolveSemantics(
          widget.cracks, kPharaohResolveCracks),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedBuilder(
                animation: _chip,
                builder: (BuildContext context, _) {
                  return SizedBox(
                    width: 26,
                    height: 26,
                    child: CustomPaint(
                      painter: _ResolveHeartPainter(
                        cracks: widget.cracks,
                        shattered: widget.shattered,
                        chip: _chip.value,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.shattered
                        ? l10n.kidsZonePlagueResolveBroken
                        : l10n.kidsZonePlagueResolveLabel,
                    style: KidsZoneText.nunito(
                      size: 11,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        // Fills as resolve *breaks*, so the bar growing is
                        // always the child winning.
                        value: share,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.shattered
                              ? MosesColors.blessing
                              : MosesColors.heart,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolveHeartPainter extends CustomPainter {
  _ResolveHeartPainter({
    required this.cracks,
    required this.shattered,
    required this.chip,
  });

  final int cracks;
  final bool shattered;

  /// 0..1 for the chip animation on the most recent crack.
  final double chip;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = math.min(size.width, size.height) * 0.46;

    // A stone heart, not an anatomical one — it is Pharaoh's resolve, and it
    // should look like something that could crack.
    final Path heart = Path()
      ..moveTo(c.dx, c.dy + r * 0.85)
      ..cubicTo(c.dx - r * 1.6, c.dy - r * 0.25, c.dx - r * 0.55,
          c.dy - r * 1.15, c.dx, c.dy - r * 0.35)
      ..cubicTo(c.dx + r * 0.55, c.dy - r * 1.15, c.dx + r * 1.6,
          c.dy - r * 0.25, c.dx, c.dy + r * 0.85)
      ..close();

    if (shattered) {
      // Broken open: the halves drift apart and the gap glows.
      canvas.drawCircle(
        c,
        r * 1.3,
        Paint()
          ..color = MosesColors.blessing.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      for (final double side in <double>[-1, 1]) {
        canvas.save();
        canvas.translate(side * r * 0.28, 0);
        canvas.rotate(side * 0.22);
        canvas.clipRect(Rect.fromLTWH(
            side < 0 ? 0 : c.dx, 0, side < 0 ? c.dx : size.width, size.height));
        canvas.drawPath(heart, Paint()..color = const Color(0xFF8A6A6A));
        canvas.restore();
      }
      return;
    }

    canvas.drawPath(
      heart,
      Paint()
        ..color = Color.lerp(const Color(0xFF6E5A5A), MosesColors.heart,
            cracks / kPharaohResolveCracks)!,
    );

    // One fissure per correct placement, fanned out from the centre. The
    // newest one is drawn brighter and slightly longer while it chips in.
    for (int i = 0; i < cracks; i++) {
      final bool newest = i == cracks - 1;
      final double a = -math.pi / 2 + (i - cracks / 2) * 0.52 + (i % 2) * 0.3;
      final double len =
          r * (0.75 + (i % 3) * 0.12) * (newest ? 0.7 + 0.5 * chip : 1);
      final Path fissure = Path()..moveTo(c.dx, c.dy);
      Offset p = c;
      // A jagged line rather than a straight one — a straight crack reads as
      // a scratch.
      for (int seg = 1; seg <= 3; seg++) {
        final double f = seg / 3;
        p = Offset(
          c.dx + math.cos(a) * len * f + math.sin(seg * 2.1) * r * 0.10,
          c.dy + math.sin(a) * len * f + math.cos(seg * 1.7) * r * 0.08,
        );
        fissure.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        fissure,
        Paint()
          ..color = (newest ? Colors.white : const Color(0xFF33202A))
              .withOpacity(newest ? 0.55 + 0.45 * (1 - chip) : 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = newest ? 1.8 : 1.3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ResolveHeartPainter old) =>
      old.cracks != cracks || old.shattered != shattered || old.chip != chip;
}
