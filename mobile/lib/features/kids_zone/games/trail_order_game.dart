import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';

/// Drag story stones into the correct order along a trail.
class TrailOrderGame extends StatefulWidget {
  const TrailOrderGame({
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
  State<TrailOrderGame> createState() => _TrailOrderGameState();
}

class _TrailOrderGameState extends State<TrailOrderGame> {
  late List<TrailStep> _order;
  int _attempts = 0;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    _order = List<TrailStep>.of(widget.definition.trailSteps)..shuffle();
    _feedback = null;
  }

  void _check(AppLocalizations l10n) {
    _attempts += 1;
    final List<String> expected =
        widget.definition.trailSteps.map((TrailStep s) => s.id).toList();
    final List<String> current = _order.map((TrailStep s) => s.id).toList();

    if (expected.join() == current.join()) {
      final int stars = _attempts <= 1 ? 3 : (_attempts <= 3 ? 2 : 1);
      widget.onComplete(stars);
      return;
    }

    setState(() => _feedback = l10n.kidsZoneGameTrailWrong);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: widget.definition.intro,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.kidsZoneGameTrailHint,
              style: KidsZoneText.nunito(size: 14, weight: FontWeight.w600, color: KidsZoneColors.inkMuted),
            ),
            if (_feedback != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _feedback!,
                style: KidsZoneText.nunito(size: 14, weight: FontWeight.w700, color: const Color(0xFFE65100)),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: _order.length,
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final TrailStep item = _order.removeAt(oldIndex);
                    _order.insert(newIndex, item);
                    _feedback = null;
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  final TrailStep step = _order[index];
                  return Card(
                    key: ValueKey<String>(step.id),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    color: KidsZoneColors.card,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: KidsZoneColors.grass.withOpacity(0.2),
                        child: Text('${index + 1}', style: KidsZoneText.nunito(size: 14, weight: FontWeight.w800)),
                      ),
                      title: Text(step.label, style: KidsZoneText.nunito(size: 15, weight: FontWeight.w700)),
                      trailing: Icon(step.icon, color: KidsZoneColors.grass),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          kidsZonePrimaryButton(label: l10n.kidsZoneGameTrailCheck, onPressed: () => _check(l10n)),
          TextButton(onPressed: () => setState(_shuffle), child: Text(l10n.kidsZoneGameShuffle)),
        ],
      ),
    );
  }
}
