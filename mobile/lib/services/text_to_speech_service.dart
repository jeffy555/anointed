import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// How a line should sound.
///
/// The platform engine gives us pitch and rate and nothing else — there is no
/// second voice to switch to — so a "different voice" has to be built out of
/// those two dials. Dropping the pitch and slowing the delivery is what turns
/// the ordinary read-aloud voice into something that carries a story.
enum TtsVoice {
  /// The default: bright and brisk, for questions and gameplay prompts.
  friendly(rate: 0.45, pitch: 1.05),

  /// Deep and unhurried, for story narration — the voice telling a child what
  /// happened long ago, rather than the voice asking them a question.
  narrator(rate: 0.36, pitch: 0.72);

  const TtsVoice({required this.rate, required this.pitch});

  final double rate;
  final double pitch;
}

/// Read-aloud for question text — kids 6–12 (design-spec OQ-03).
class TextToSpeechService extends ChangeNotifier {
  TextToSpeechService() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  bool _speaking = false;

  /// What the engine is currently configured for, so a line only pays for a
  /// pitch/rate change when it actually needs a different voice.
  TtsVoice _current = TtsVoice.friendly;

  bool get isSpeaking => _speaking;

  Future<void> init() async {
    if (_ready) return;
    await _tts.setLanguage('en-US');
    await _applyVoice(TtsVoice.friendly, force: true);
    _tts.setCompletionHandler(_onDone);
    _tts.setCancelHandler(_onDone);
    _ready = true;
  }

  Future<void> _applyVoice(TtsVoice voice, {bool force = false}) async {
    if (!force && _current == voice) return;
    await _tts.setSpeechRate(voice.rate);
    await _tts.setPitch(voice.pitch);
    _current = voice;
  }

  void _onDone() {
    _speaking = false;
    notifyListeners();
  }

  Future<void> speak(String text, {TtsVoice voice = TtsVoice.friendly}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await init();
    await stop();
    await _applyVoice(voice);
    _speaking = true;
    notifyListeners();
    try {
      await _tts.speak(trimmed);
    } catch (error, stack) {
      _speaking = false;
      notifyListeners();
      if (kDebugMode) {
        debugPrint('TTS failed: $error\n$stack');
      }
    }
  }

  Future<void> stop() async {
    if (!_ready) return;
    await _tts.stop();
    _speaking = false;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await stop();
    super.dispose();
  }
}
