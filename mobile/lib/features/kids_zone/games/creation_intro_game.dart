import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/tokens.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/kids_zone_audio_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../kids_zone_game_catalog.dart';
import '../kids_zone_game_shell.dart';
import '../kids_zone_tokens.dart';
import '../widgets/creation_world_view.dart';

/// Introduction — animated creation world with day-by-day narration.
class CreationIntroGame extends StatefulWidget {
  const CreationIntroGame({
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
  State<CreationIntroGame> createState() => _CreationIntroGameState();
}

class _CreationIntroGameState extends State<CreationIntroGame> {
  int _dayIndex = 0;
  bool _speaking = false;

  CreationDayIntro get _day => widget.definition.introDays[_dayIndex];

  bool get _isLast => _dayIndex >= widget.definition.introDays.length - 1;

  late final TextToSpeechService _tts;

  @override
  void initState() {
    super.initState();
    // Captured here: looking the service up in dispose() is invalid once the
    // element is unmounting, which left narration playing on after leaving.
    _tts = context.read<TextToSpeechService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _narrateDay());
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _narrateDay() async {
    setState(() => _speaking = true);
    await _tts.speak('${_day.dayLabel}. ${_day.narration}');
    if (mounted) setState(() => _speaking = false);
  }

  void _next(AppLocalizations l10n) {
    if (_isLast) {
      KidsZoneAudioService.instance.playCelebrate();
      widget.onComplete(3);
      return;
    }
    setState(() => _dayIndex += 1);
    _narrateDay();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CreationDayIntro day = _day;

    return KidsZoneGameShell(
      stopTitle: widget.stopTitle,
      adventureTitle: widget.adventureTitle,
      intro: l10n.kidsZoneIntroSceneHint,
      readAloudText: day.narration,
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CreationWorldView(day: day.day),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: KidsZoneIntroPanel(
              sceneLabel: day.dayLabel,
              narration: day.narration,
              progress: (_dayIndex + 1) / widget.definition.introDays.length,
              progressColor: KidsZoneColors.grass,
              progressTrackColor: KidsZoneColors.grass.withOpacity(0.2),
            ),
          ),
        ],
      ),
      bottom: kidsZonePrimaryButton(
        label: _isLast ? l10n.kidsZoneIntroBeginLevel1 : l10n.kidsZoneListenNext,
        onPressed: _speaking ? null : () => _next(l10n),
      ),
    );
  }
}
