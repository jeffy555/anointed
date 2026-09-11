import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../widgets/ark_scene_view.dart';

/// Noah's Ark introduction — the Genesis 6–9 story over an animated seascape.
class NoahIntroGame extends StatefulWidget {
  const NoahIntroGame({
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
  State<NoahIntroGame> createState() => _NoahIntroGameState();
}

class _NoahIntroGameState extends State<NoahIntroGame> {
  int _sceneIndex = 0;
  bool _speaking = false;
  List<ArkVisualLayer> _visibleLayers = <ArkVisualLayer>[];

  ArkIntroScene get _scene => widget.definition.arkScenes[_sceneIndex];

  bool get _isLast => _sceneIndex >= widget.definition.arkScenes.length - 1;

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
    final ArkIntroScene scene = _scene;

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: l10n.kidsZoneArkIntroHint,
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
                child: ArkSceneView(
                  weather: scene.weather,
                  layers: _visibleLayers,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: KidsZoneIntroPanel(
              sceneLabel: scene.sceneLabel,
              narration: scene.narration,
              progress: (_sceneIndex + 1) / widget.definition.arkScenes.length,
              progressColor: ArkColors.timber,
              progressTrackColor: ArkColors.water.withOpacity(0.2),
            ),
          ),
        ],
      ),
      bottom: kidsZonePrimaryButton(
        label: _isLast ? l10n.kidsZoneArkBeginLevel1 : l10n.kidsZoneListenNext,
        onPressed: _speaking ? null : _next,
      ),
    );
  }
}
