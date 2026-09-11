import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/map/parchment_codex_tokens.dart';
import '../l10n/gen/app_localizations.dart';
import '../services/text_to_speech_service.dart';
import '../services/kids_zone_audio_service.dart';

/// Tap-to-hear control shown for younger players during gameplay.
class ReadAloudButton extends StatefulWidget {
  const ReadAloudButton({
    super.key,
    required this.text,
    this.verseReference,
    this.verseExcerpt,
    this.pauseKidsZoneBgm = false,
    this.voice = TtsVoice.friendly,
  });

  final String text;
  final String? verseReference;
  final String? verseExcerpt;

  /// Which voice to read in. Story screens pass [TtsVoice.narrator] so the
  /// replay button sounds like the narration it is replaying.
  final TtsVoice voice;

  /// When true, Kids Zone gameplay BGM pauses for the duration of read-aloud.
  final bool pauseKidsZoneBgm;

  @override
  State<ReadAloudButton> createState() => _ReadAloudButtonState();
}

class _ReadAloudButtonState extends State<ReadAloudButton> {
  bool _busy = false;

  String get _spokenText {
    final StringBuffer buffer = StringBuffer();
    if (widget.verseReference != null && widget.verseReference!.isNotEmpty) {
      buffer.write('${widget.verseReference}. ');
    }
    if (widget.verseExcerpt != null && widget.verseExcerpt!.isNotEmpty) {
      buffer.write('${widget.verseExcerpt} ');
    }
    buffer.write(widget.text);
    return buffer.toString().trim();
  }

  Future<void> _toggle() async {
    final TextToSpeechService tts = context.read<TextToSpeechService>();
    final KidsZoneAudioService? kidsBgm =
        widget.pauseKidsZoneBgm ? KidsZoneAudioService.instance : null;

    if (tts.isSpeaking) {
      await tts.stop();
      await kidsBgm?.resumeAfterSpeech();
      if (mounted) setState(() => _busy = false);
      return;
    }
    setState(() => _busy = true);
    await kidsBgm?.pauseForSpeech();
    try {
      await tts.speak(_spokenText, voice: widget.voice);
    } finally {
      await kidsBgm?.resumeAfterSpeech();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextToSpeechService tts = context.watch<TextToSpeechService>();
    final bool active = tts.isSpeaking || _busy;

    return Semantics(
      button: true,
      label: l10n.gameplayReadAloudSemantics,
      child: TextButton.icon(
        onPressed: _toggle,
        icon: Icon(
          active ? Icons.volume_up_rounded : Icons.volume_up_outlined,
          size: 20,
          color: ParchmentColors.brown,
        ),
        label: Text(
          active ? l10n.gameplayReadAloudStop : l10n.gameplayReadAloud,
          style: ParchmentText.karla(
            size: 13,
            weight: FontWeight.w600,
            color: ParchmentColors.brown,
            decoration: TextDecoration.underline,
            decorationColor: ParchmentColors.gold,
          ),
        ),
      ),
    );
  }
}
