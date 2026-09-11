import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/local_store.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/kids_zone_audio_service.dart';
import '../../services/kids_zone_repository.dart';
import '../../widgets/state_views.dart';
import 'kids_zone_adventures.dart';
import 'kids_zone_game_catalog.dart';
import 'kids_zone_game_shell.dart';
import 'kids_zone_strings.dart';
import 'kids_zone_tokens.dart';

/// Kids Zone hub — adventure worlds with mini-games instead of Q/A.
class KidsZoneHubScreen extends StatefulWidget {
  const KidsZoneHubScreen({super.key});

  @override
  State<KidsZoneHubScreen> createState() => _KidsZoneHubScreenState();
}

class _KidsZoneHubScreenState extends State<KidsZoneHubScreen> {
  Set<String> _completed = <String>{};
  Map<String, int> _stars = <String, int>{};

  @override
  void initState() {
    super.initState();
    // Kids Zone is drawn for a portrait phone throughout: the adventure worlds,
    // the archery field and the ark's drag-and-drop blueprint all assume a tall
    // frame, and in landscape six of the stops ran off the bottom of the screen.
    // Both manifests permit landscape and nothing had ever asked otherwise.
    //
    // Scoped to the zone rather than the app: the main journey has deliberate
    // tablet and landscape layouts (Layout.useWideLayout, AdaptiveTwoPane) and
    // keeps them. The lock lifts in dispose, on the way back to the level map.
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AnalyticsService>().track('kids_zone_entered');
      _loadProgress();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    KidsZoneAudioService.instance.stopAmbience();
    super.dispose();
  }

  /// Paints from the device first, then reconciles with the server.
  ///
  /// The local read is synchronous and always happens, so the hub never shows a
  /// child a spinner or an empty board while the network decides — Kids Zone is
  /// the part of the app most likely to be played offline. The sync that follows
  /// is what restores stars after a sign-out wipe, a reinstall, or a move to a
  /// different phone; when it fails it returns null and the local view stands.
  void _loadProgress() {
    final LocalStore store = context.read<LocalStore>();
    setState(() {
      _completed = store.kidsZoneCompletedStops;
      _stars = store.kidsZoneStars;
    });

    unawaited(_syncProgress());
  }

  Future<void> _syncProgress() async {
    final Map<String, int>? merged =
        await context.read<KidsZoneRepository>().sync();
    if (!mounted || merged == null) return;
    setState(() {
      _completed = merged.keys.toSet();
      _stars = merged;
    });
  }

  bool _isStopUnlocked(KidsAdventure adventure, int stopIndex) {
    if (stopIndex == 0) return true;
    final String priorId = adventure.stops[stopIndex - 1].id;
    return _completed.contains(priorId);
  }

  void _playStop(KidsAdventure adventure, KidsAdventureStop stop, bool unlocked) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!unlocked) {
      showAppSnack(context, l10n.kidsZoneStopLocked);
      return;
    }

    if (kidsZoneGameForStop(stop.id) == null) {
      showAppSnack(context, l10n.kidsZoneGameMissing);
      return;
    }

    context.read<AnalyticsService>().track(
      'kids_zone_stop_started',
      properties: <String, Object?>{
        'adventure_id': adventure.id,
        'stop_id': stop.id,
        'game_kind': stop.gameKind.name,
      },
    );

    Navigator.of(context)
        .pushNamed(
          Routes.kidsZoneGameplay,
          arguments: KidsZoneGameplayArgs(
            adventureId: adventure.id,
            stopId: stop.id,
            stopTitle: kidsZoneStopTitle(l10n, stop.id),
            adventureTitle: kidsZoneAdventureTitle(l10n, adventure.id),
          ),
        )
        .then((_) {
      if (mounted) _loadProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: KidsZoneColors.ink,
        title: Text(
          l10n.kidsZoneHubTitle,
          style: KidsZoneText.nunito(size: 18, weight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: l10n.kidsZoneBackToMain,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: KidsZoneColors.skyGradient),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              Layout.pageInset(context),
              AppSpacing.sm,
              Layout.pageInset(context),
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Text(
                l10n.kidsZoneHubSubhead,
                style: KidsZoneText.nunito(
                  size: 15,
                  weight: FontWeight.w600,
                  color: KidsZoneColors.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final KidsAdventure adventure in kKidsAdventures)
                _AdventureCard(
                  adventure: adventure,
                  completed: _completed,
                  stars: _stars,
                  isStopUnlocked: (int index) => _isStopUnlocked(adventure, index),
                  onPlayStop: (KidsAdventureStop stop, bool unlocked) =>
                      _playStop(adventure, stop, unlocked),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdventureCard extends StatelessWidget {
  const _AdventureCard({
    required this.adventure,
    required this.completed,
    required this.stars,
    required this.isStopUnlocked,
    required this.onPlayStop,
  });

  final KidsAdventure adventure;
  final Set<String> completed;
  final Map<String, int> stars;
  final bool Function(int stopIndex) isStopUnlocked;
  final void Function(KidsAdventureStop stop, bool unlocked) onPlayStop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int doneCount =
        adventure.stops.where((KidsAdventureStop s) => completed.contains(s.id)).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Material(
        color: KidsZoneColors.card,
        borderRadius: BorderRadius.circular(20),
        elevation: 2,
        shadowColor: adventure.color.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: adventure.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(adventure.icon, color: adventure.color, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          kidsZoneAdventureTitle(l10n, adventure.id),
                          style: KidsZoneText.nunito(size: 18, weight: FontWeight.w800),
                        ),
                        Text(
                          kidsZoneAdventureSubtitle(l10n, adventure.id),
                          style: KidsZoneText.nunito(
                            size: 13,
                            weight: FontWeight.w600,
                            color: KidsZoneColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$doneCount/${adventure.stops.length}',
                    style: KidsZoneText.nunito(
                      size: 14,
                      weight: FontWeight.w700,
                      color: adventure.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ...List<Widget>.generate(adventure.stops.length, (int index) {
                final KidsAdventureStop stop = adventure.stops[index];
                final bool done = completed.contains(stop.id);
                final bool unlocked = isStopUnlocked(index);
                return _StopTile(
                  stop: stop,
                  color: adventure.color,
                  done: done,
                  stars: stars[stop.id] ?? 0,
                  unlocked: unlocked,
                  gameLabel: kidsZoneGameKindLabel(l10n, stop.gameKind),
                  actionLabel: done ? l10n.kidsZoneStopReplay : l10n.kidsZoneStopPlay,
                  onTap: () => onPlayStop(stop, unlocked || done),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.color,
    required this.done,
    required this.stars,
    required this.unlocked,
    required this.gameLabel,
    required this.actionLabel,
    required this.onTap,
  });

  final KidsAdventureStop stop;
  final Color color;
  final bool done;

  /// Best stars earned here, 0 until the stop has been finished.
  final int stars;
  final bool unlocked;
  final String gameLabel;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool playable = unlocked || done;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Opacity(
        opacity: playable ? 1 : 0.55,
        child: Material(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: playable ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    done ? Icons.star_rounded : stop.icon,
                    color: done ? KidsZoneColors.star : color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          kidsZoneStopTitle(l10n, stop.id),
                          style: KidsZoneText.nunito(size: 15, weight: FontWeight.w700),
                        ),
                        Text(
                          done
                              ? l10n.kidsZoneStopComplete
                              : '$gameLabel · ${kidsZoneStopTeaser(l10n, stop.id)}',
                          style: KidsZoneText.nunito(
                            size: 12,
                            weight: FontWeight.w600,
                            color: KidsZoneColors.inkMuted,
                          ),
                        ),
                        // What was earned here, and — from the hollow ones —
                        // what is still there to go back for.
                        if (done) ...<Widget>[
                          const SizedBox(height: 2),
                          Semantics(
                            label: l10n.kidsZoneCompleteStars(stars),
                            excludeSemantics: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                for (int i = 0; i < 3; i++)
                                  Icon(
                                    i < stars
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 16,
                                    color: i < stars
                                        ? KidsZoneColors.star
                                        : KidsZoneColors.inkMuted.withOpacity(0.4),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (playable)
                    TextButton(onPressed: onTap, child: Text(actionLabel))
                  else
                    Icon(Icons.lock_rounded, color: KidsZoneColors.inkMuted, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
