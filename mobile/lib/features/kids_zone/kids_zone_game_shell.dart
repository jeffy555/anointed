import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/text_to_speech_service.dart';
import '../../widgets/read_aloud_button.dart';
import 'kids_zone_game_catalog.dart';
import 'kids_zone_tokens.dart';

String kidsZoneGameKindLabel(AppLocalizations l10n, KidsZoneGameKind kind) {
  return switch (kind) {
    KidsZoneGameKind.creationIntro => l10n.kidsZoneGameIntro,
    KidsZoneGameKind.battleIntro => l10n.kidsZoneGameIntro,
    KidsZoneGameKind.archery => l10n.kidsZoneGameArchery,
    KidsZoneGameKind.noahIntro => l10n.kidsZoneGameIntro,
    KidsZoneGameKind.arkBuilder => l10n.kidsZoneGameArkBuilder,
    KidsZoneGameKind.animalMatching => l10n.kidsZoneGameAnimalMatch,
    KidsZoneGameKind.animalCare => l10n.kidsZoneGameAnimalCare,
    KidsZoneGameKind.mosesIntro => l10n.kidsZoneGameIntro,
    KidsZoneGameKind.riverRescue => l10n.kidsZoneGameRiverRescue,
    KidsZoneGameKind.plagueSort => l10n.kidsZoneGamePlagueSort,
    KidsZoneGameKind.seaCrossing => l10n.kidsZoneGameSeaCrossing,
    KidsZoneGameKind.listenAndAnswer => l10n.kidsZoneGameListen,
    KidsZoneGameKind.connectCreations => l10n.kidsZoneGameConnect,
    KidsZoneGameKind.jumbledWords => l10n.kidsZoneGameJumble,
    KidsZoneGameKind.storyPath => l10n.kidsZoneGameStory,
    KidsZoneGameKind.matchPairs => l10n.kidsZoneGameMatch,
    KidsZoneGameKind.trailOrder => l10n.kidsZoneGameTrail,
    KidsZoneGameKind.explorer => l10n.kidsZoneGameExplorer,
  };
}

/// Shared chrome for Kids Zone mini-games.
class KidsZoneGameShell extends StatelessWidget {
  const KidsZoneGameShell({
    super.key,
    required this.stopTitle,
    required this.adventureTitle,
    required this.intro,
    required this.body,
    this.readAloudText,
    this.pauseKidsZoneBgm = false,
    this.bottom,
  });

  final String stopTitle;
  final String adventureTitle;
  final String intro;
  final Widget body;
  final String? readAloudText;
  final bool pauseKidsZoneBgm;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KidsZoneColors.skyBottom,
      appBar: AppBar(
        backgroundColor: KidsZoneColors.skyTop,
        foregroundColor: KidsZoneColors.ink,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(stopTitle, style: KidsZoneText.nunito(size: 16, weight: FontWeight.w800)),
            Text(
              adventureTitle,
              style: KidsZoneText.nunito(size: 12, weight: FontWeight.w600, color: KidsZoneColors.inkMuted),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints outer) {
            // The cue card and the action below it are both intrinsic height and
            // both grow with the text scale, while the game between them was an
            // `Expanded` that gave way first. Past a certain size the two of them
            // claimed the whole screen and the column ran off the bottom. Capping
            // each at a fraction of the height and scrolling inside the cap keeps
            // the game on screen at any scale — squeezed at 2.4x, but never
            // broken, and every word still reachable.
            final double introCap = outer.maxHeight * 0.38;
            final double bottomCap = outer.maxHeight * 0.40;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: introCap),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: KidsZoneColors.grass.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              intro,
                              style: KidsZoneText.nunito(
                                  size: 14, weight: FontWeight.w700),
                            ),
                            if (readAloudText != null &&
                                readAloudText!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: AppSpacing.sm),
                              ReadAloudButton(
                                text: readAloudText!,
                                pauseKidsZoneBgm: pauseKidsZoneBgm,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: body),
                if (bottom != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: bottomCap),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: bottom!,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Centres [child] while it fits, and scrolls it once it stops fitting.
///
/// Kids Zone overlays and story cards are centred blocks of text sized for a
/// phone at the default text scale. At 1.6 — reachable from the in-app "Large
/// text" switch on its own, well inside the app's 2.4 ceiling — several ran off
/// the bottom of the screen. Clamping the type down is the wrong trade in a
/// children's app, so the block scrolls instead and every word stays reachable.
class KidsZoneFitOrScroll extends StatelessWidget {
  const KidsZoneFitOrScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedHeight) {
          return Padding(padding: padding, child: child);
        }
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity),
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

/// A game body that is a block of chrome — a round label, a hint, a score — sat
/// above the board the child actually plays on.
///
/// The board is the part that has to keep working, so it is the part that gets
/// protected. The chrome is capped at [headerMaxFraction] of the height and
/// scrolls inside that cap; the board takes the rest and is never squeezed to
/// nothing. Before this, the chrome was fixed-height and the board was an
/// `Expanded` that gave way first: past a certain text scale the board hit zero
/// and the chrome carried on past the bottom of the screen.
class KidsZoneBoardLayout extends StatelessWidget {
  const KidsZoneBoardLayout({
    super.key,
    required this.header,
    required this.board,
    this.padding = EdgeInsets.zero,
    this.gap = AppSpacing.md,
    this.headerMaxFraction = 0.34,
  });

  final Widget header;
  final Widget board;
  final EdgeInsets padding;
  final double gap;
  final double headerMaxFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double inner =
            (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity);
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: inner * headerMaxFraction),
                child: SingleChildScrollView(child: header),
              ),
              SizedBox(height: gap),
              Expanded(child: board),
            ],
          ),
        );
      },
    );
  }
}

/// The text half of an adventure introduction: which scene this is, what
/// happened in it, a way to hear it again, and how far through the child is.
///
/// All four introductions had built this by hand and identically. They also
/// broke identically: the label and the replay button are fixed height and grow
/// with the text scale, so past a certain size they claimed the whole panel and
/// the narration's own scroll view was left with nothing to give back. Here the
/// three of them scroll as one block and only the progress bar — six pixels —
/// stays pinned.
class KidsZoneIntroPanel extends StatelessWidget {
  const KidsZoneIntroPanel({
    super.key,
    required this.sceneLabel,
    required this.narration,
    required this.progress,
    required this.progressColor,
    required this.progressTrackColor,
    this.voice = TtsVoice.friendly,
  });

  final String sceneLabel;
  final String narration;

  /// 0..1 — how much of the introduction is behind the child.
  final double progress;
  final Color progressColor;
  final Color progressTrackColor;

  /// Introductions that were narrated in the storyteller voice replay in it.
  final TtsVoice voice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    sceneLabel,
                    style: KidsZoneText.nunito(size: 22, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    narration,
                    style: KidsZoneText.nunito(size: 16, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ReadAloudButton(text: narration, voice: voice),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: progressTrackColor,
            color: progressColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

Widget kidsZonePrimaryButton({required String label, required VoidCallback? onPressed}) {
  return FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: KidsZoneColors.grass,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Text(label, style: KidsZoneText.nunito(size: 16, weight: FontWeight.w800, color: Colors.white)),
  );
}
