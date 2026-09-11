import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';

/// Tap hidden items in a scene to collect them all.
class ExplorerGame extends StatefulWidget {
  const ExplorerGame({
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
  State<ExplorerGame> createState() => _ExplorerGameState();
}

class _ExplorerGameState extends State<ExplorerGame> {
  final Set<String> _found = <String>{};
  int _missTaps = 0;

  void _tapTarget(ExplorerTarget target) {
    if (_found.contains(target.id)) return;
    setState(() => _found.add(target.id));
    if (_found.length == widget.definition.explorerTargets.length) {
      final int stars = _missTaps == 0 ? 3 : (_missTaps <= 2 ? 2 : 1);
      widget.onComplete(stars);
    }
  }

  void _missTap() {
    setState(() => _missTaps += 1);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int total = widget.definition.explorerTargets.length;

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: widget.definition.intro,
      body: KidsZoneBoardLayout(
        padding: const EdgeInsets.all(AppSpacing.lg),
        header: Text(
          l10n.kidsZoneGameExplorerProgress(_found.length, total),
          textAlign: TextAlign.center,
          style: KidsZoneText.nunito(size: 15, weight: FontWeight.w800),
        ),
        board: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return GestureDetector(
                    onTap: _missTap,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            const Color(0xFF81D4FA),
                            KidsZoneColors.grass.withOpacity(0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: KidsZoneColors.grass, width: 3),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Positioned(
                            left: 16,
                            top: 16,
                            child: Text(
                              widget.definition.explorerSceneTitle,
                              style: KidsZoneText.nunito(
                                size: 16,
                                weight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 20,
                            top: 40,
                            child: Icon(Icons.wb_sunny_rounded, size: 48, color: KidsZoneColors.sun.withOpacity(0.9)),
                          ),
                          for (final ExplorerTarget target in widget.definition.explorerTargets)
                            Positioned(
                              left: target.leftFraction * constraints.maxWidth,
                              top: target.topFraction * constraints.maxHeight,
                              child: _ExplorerBubble(
                                target: target,
                                found: _found.contains(target.id),
                                onTap: () => _tapTarget(target),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Loose, so the checklist takes only the rows it needs and scrolls
            // rather than growing into the scene when the type is large.
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: widget.definition.explorerTargets.map((ExplorerTarget target) {
                final bool found = _found.contains(target.id);
                return Chip(
                  avatar: Icon(
                    found ? Icons.check_circle_rounded : target.icon,
                    size: 18,
                    color: found ? KidsZoneColors.grass : KidsZoneColors.inkMuted,
                  ),
                  label: Text(
                    target.label,
                    style: KidsZoneText.nunito(
                      size: 12,
                      weight: FontWeight.w700,
                      color: found ? KidsZoneColors.ink : KidsZoneColors.inkMuted,
                    ),
                  ),
                  backgroundColor: found ? KidsZoneColors.grass.withOpacity(0.15) : KidsZoneColors.card,
                );
              }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorerBubble extends StatefulWidget {
  const _ExplorerBubble({required this.target, required this.found, required this.onTap});

  final ExplorerTarget target;
  final bool found;
  final VoidCallback onTap;

  @override
  State<_ExplorerBubble> createState() => _ExplorerBubbleState();
}

class _ExplorerBubbleState extends State<_ExplorerBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.found) {
      return Icon(Icons.star_rounded, color: KidsZoneColors.star, size: 36);
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
        ),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: widget.target.color.withOpacity(0.35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(color: widget.target.color.withOpacity(0.4), blurRadius: 12),
            ],
          ),
          child: Icon(widget.target.icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
