import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../widgets/battlefield_view.dart';

/// Battle of Siddim introduction — narrated Genesis 14 story over an animated
/// valley, beat by beat.
class BattleIntroGame extends StatefulWidget {
  const BattleIntroGame({
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
  State<BattleIntroGame> createState() => _BattleIntroGameState();
}

class _BattleIntroGameState extends State<BattleIntroGame> {
  int _sceneIndex = 0;
  bool _speaking = false;
  List<BattleVisualLayer> _visibleLayers = <BattleVisualLayer>[];

  BattleIntroScene get _scene => widget.definition.battleScenes[_sceneIndex];

  bool get _isLast => _sceneIndex >= widget.definition.battleScenes.length - 1;

  late final TextToSpeechService _tts;

  @override
  void initState() {
    super.initState();
    // Captured here: looking the service up in dispose() is invalid once the
    // element is unmounting, which left narration playing on after leaving.
    _tts = context.read<TextToSpeechService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _narrateScene());
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _narrateScene() async {
    setState(() {
      _speaking = true;
      _visibleLayers = _scene.visualLayers;
    });
    await _tts.speak('${_scene.sceneLabel}. ${_scene.narration}');
    if (mounted) setState(() => _speaking = false);
  }

  void _next() {
    if (_isLast) {
      KidsZoneAudioService.instance.playCelebrate();
      widget.onComplete(3);
      return;
    }
    setState(() => _sceneIndex += 1);
    _narrateScene();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BattleIntroScene scene = _scene;

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: l10n.kidsZoneSiddimIntroHint,
      readAloudText: scene.narration,
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BattlefieldView(
                  layers: _visibleLayers,
                  marchingSoldiers: scene.marchingSoldiers,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: KidsZoneIntroPanel(
              sceneLabel: scene.sceneLabel,
              narration: scene.narration,
              progress: (_sceneIndex + 1) /
              widget.definition.battleScenes.length,
              progressColor: SiddimColors.banner,
              progressTrackColor: SiddimColors.duskMid.withOpacity(0.2),
            ),
          ),
        ],
      ),
      bottom: kidsZonePrimaryButton(
        label: _isLast
            ? l10n.kidsZoneSiddimBeginLevel1
            : l10n.kidsZoneListenNext,
        onPressed: _speaking ? null : _next,
      ),
    );
  }
}
