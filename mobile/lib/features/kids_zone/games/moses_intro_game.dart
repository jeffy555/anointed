import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../widgets/moses_intro_view.dart';

/// Baby Moses introduction — Exodus 1–2 over an animated Egypt and Nile.
///
/// Narrated in [TtsVoice.narrator] rather than the ordinary read-aloud voice:
/// deeper and slower, so the story arrives as something being *told* to the
/// child rather than another prompt asking them for an answer. The story is
/// stop 0 of the adventure, so River Rescue stays locked until it is heard —
/// the child meets the basket in the reeds before they are asked to steer it.
class MosesIntroGame extends StatefulWidget {
  const MosesIntroGame({
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
  State<MosesIntroGame> createState() => _MosesIntroGameState();
}

class _MosesIntroGameState extends State<MosesIntroGame> {
  /// How long the Next button stays disabled on a beat, measured from the
  /// text rather than from the speech engine.
  ///
  /// The button is held briefly so a child hears a beat before skipping it.
  /// The obvious way to do that — wait for `speak()` to report finishing —
  /// is a trap: it returns when speech *starts*, and on a device with no TTS
  /// engine the completion may never arrive at all, which would leave the
  /// child locked in the introduction with a dead button and no way to the
  /// level. Timing the hold off the word count instead is deterministic,
  /// works identically whether or not the engine answers, and cannot strand
  /// anyone. Narration still plays; it just is not what the UI waits on.
  static Duration _holdFor(String text) {
    final int words = text.trim().split(RegExp(r'\s+')).length;
    final int ms = 1200 + words * 60;
    return Duration(milliseconds: ms.clamp(2000, 9000));
  }

  int _sceneIndex = 0;
  bool _speaking = false;
  List<MosesFigure> _visibleFigures = <MosesFigure>[];
  Timer? _holdTimer;

  late final TextToSpeechService _tts;

  List<MosesIntroScene> get _scenes => widget.definition.mosesScenes;
  MosesIntroScene get _scene => _scenes[_sceneIndex];
  bool get _isLast => _sceneIndex >= _scenes.length - 1;

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
    _holdTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _narrateScene() {
    _holdTimer?.cancel();
    final String line = '${_scene.sceneLabel}. ${_scene.narration}';
    setState(() {
      _speaking = true;
      _visibleFigures = _scene.figures;
    });

    // Fired, not awaited: the narration must never be the thing the UI is
    // blocked on. Whether it succeeds, fails or never answers, the timer
    // below is what re-enables the button.
    unawaited(
        _tts.speak(line, voice: TtsVoice.narrator).catchError((Object _) {}));
    _holdTimer = Timer(_holdFor(line), _release);
  }

  void _release() {
    _holdTimer?.cancel();
    if (mounted && _speaking) setState(() => _speaking = false);
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
    final MosesIntroScene scene = _scene;

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: l10n.kidsZoneMosesIntroHint,
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
                child: MosesIntroView(
                  era: scene.era,
                  figures: _visibleFigures,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: KidsZoneIntroPanel(
              sceneLabel: scene.sceneLabel,
              narration: scene.narration,
              progress: (_sceneIndex + 1) / _scenes.length,
              progressColor: MosesColors.blessing,
              progressTrackColor: MosesColors.water.withOpacity(0.2),
              voice: TtsVoice.narrator,
            ),
          ),
        ],
      ),
      bottom: kidsZonePrimaryButton(
        label:
            _isLast ? l10n.kidsZoneMosesBeginLevel1 : l10n.kidsZoneListenNext,
        onPressed: _speaking ? null : _next,
      ),
    );
  }
}
