import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../widgets/celebration_animation.dart';
import 'kids_zone_adventures.dart';
import 'kids_zone_strings.dart';
import 'kids_zone_tokens.dart';

/// Celebration after finishing a Kids Zone adventure stop.
class KidsZoneCompleteScreen extends StatefulWidget {
  const KidsZoneCompleteScreen({super.key, required this.args});

  final KidsZoneCompleteArgs args;

  @override
  State<KidsZoneCompleteScreen> createState() => _KidsZoneCompleteScreenState();
}

class _KidsZoneCompleteScreenState extends State<KidsZoneCompleteScreen> {
  /// Stop at the Kids Zone hub — or at the root, if the hub is somehow not on
  /// the stack. `popUntil` with a predicate that never matches pops *every*
  /// route and leaves a black screen; `isFirst` is the floor that stops that.
  static bool _backToHub(Route<dynamic> route) =>
      route.settings.name == Routes.kidsZone || route.isFirst;

  void _nextStop() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final KidsAdventure? adventure = kidsZoneAdventureById(widget.args.adventureId);
    final String? nextId = widget.args.nextStopId;
    if (adventure == null || nextId == null) {
      Navigator.of(context).popUntil(_backToHub);
      return;
    }

    KidsAdventureStop? stop;
    for (final KidsAdventureStop candidate in adventure.stops) {
      if (candidate.id == nextId) {
        stop = candidate;
        break;
      }
    }
    if (stop == null) {
      Navigator.of(context).popUntil(_backToHub);
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      Routes.kidsZoneGameplay,
      arguments: KidsZoneGameplayArgs(
        adventureId: adventure.id,
        stopId: stop.id,
        stopTitle: kidsZoneStopTitle(l10n, stop.id),
        adventureTitle: kidsZoneAdventureTitle(l10n, adventure.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool hasNext = widget.args.nextStopId != null;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: KidsZoneColors.skyGradient),
        child: SafeArea(
          child: Center(
            child: ContentColumn(
              maxWidth: 420,
              child: Padding(
                padding: EdgeInsets.all(Layout.pageInset(context)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const CelebrationAnimation(size: 100),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.kidsZoneCompleteTitle,
                      textAlign: TextAlign.center,
                      style: KidsZoneText.nunito(size: 26, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.args.stopTitle,
                      textAlign: TextAlign.center,
                      style: KidsZoneText.nunito(
                        size: 16,
                        weight: FontWeight.w600,
                        color: KidsZoneColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(3, (int i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.star_rounded,
                            size: 40,
                            color: i < widget.args.stars
                                ? KidsZoneColors.star
                                : KidsZoneColors.inkMuted.withOpacity(0.25),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.kidsZoneCompleteStars(widget.args.stars),
                      style: KidsZoneText.nunito(size: 15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (hasNext)
                      FilledButton(
                        onPressed: _nextStop,
                        style: FilledButton.styleFrom(
                          backgroundColor: KidsZoneColors.grass,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(l10n.kidsZoneCompleteNext),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil(_backToHub),
                      child: Text(
                        hasNext ? l10n.kidsZoneCompleteExplore : l10n.kidsZoneBackToMain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
