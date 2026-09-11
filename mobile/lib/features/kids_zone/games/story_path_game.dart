import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';

/// Interactive story adventure — tap through scenes and make choices.
class StoryPathGame extends StatefulWidget {
  const StoryPathGame({
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
  State<StoryPathGame> createState() => _StoryPathGameState();
}

class _StoryPathGameState extends State<StoryPathGame> {
  int _sceneIndex = 0;
  String? _choiceResponse;
  int _choiceCount = 0;

  StoryScene get _scene => widget.definition.storyScenes[_sceneIndex];

  bool get _isLastScene => _sceneIndex >= widget.definition.storyScenes.length - 1;

  void _advance() {
    if (_choiceResponse != null) {
      setState(() => _choiceResponse = null);
      if (_isLastScene) {
        widget.onComplete(_choiceCount <= 1 ? 3 : 2);
      }
      return;
    }
    if (_isLastScene) {
      widget.onComplete(_choiceCount <= 1 ? 3 : 2);
      return;
    }
    setState(() => _sceneIndex += 1);
  }

  void _pick(StoryChoice choice) {
    setState(() {
      _choiceCount += 1;
      _choiceResponse = choice.response;
      _sceneIndex = choice.nextSceneIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StoryScene scene = _scene;
    final bool hasChoices = scene.choices.isNotEmpty && _choiceResponse == null;

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: widget.definition.intro,
      readAloudText: _choiceResponse ?? scene.narration,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: KidsZoneColors.card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: scene.iconColor.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: KidsZoneFitOrScroll(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(scene.icon, size: 96, color: scene.iconColor),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _choiceResponse ?? scene.narration,
                          textAlign: TextAlign.center,
                          style: KidsZoneText.nunito(size: 18, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: hasChoices
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: scene.choices
                  .map(
                    (StoryChoice choice) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: kidsZonePrimaryButton(
                        label: choice.label,
                        onPressed: () => _pick(choice),
                      ),
                    ),
                  )
                  .toList(),
            )
          : kidsZonePrimaryButton(
              label: _isLastScene ? l10n.kidsZoneGameFinish : l10n.actionContinue,
              onPressed: _advance,
            ),
    );
  }
}
