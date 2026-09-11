import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Which bundled Kids Zone loop to play (`assets/audio/kids_zone/`).
enum KidsZoneBgm {
  /// Creation Level 1, and the opening Battle of Siddim archery rounds.
  interesting('audio/kids_zone/anointed_interesting.wav'),

  /// Creation Level 2, and the mid Battle of Siddim archery rounds.
  funky('audio/kids_zone/anointed_funky.wav'),

  /// Creation Level 3, and the Battle of Siddim King's Round.
  thrilling('audio/kids_zone/anointed_thrilling.wav');

  const KidsZoneBgm(this.assetPath);

  final String assetPath;
}

/// Looping BGM for Kids Zone **gameplay only** — never during story narration/TTS.
class KidsZoneAudioService {
  KidsZoneAudioService._();

  static final KidsZoneAudioService instance = KidsZoneAudioService._();

  static const double _ambientVolume = 0.42;

  final AudioPlayer _ambient = AudioPlayer();

  KidsZoneBgm? _currentTrack;
  bool _ambientPlaying = false;

  /// The two reasons a loaded track can be sitting paused, tracked separately
  /// because they overlap: leaving the app mid-narration sets both, and coming
  /// back must not restart the music the narration is still holding down.
  bool _pausedForSpeech = false;
  bool _pausedForBackground = false;

  /// Starts (or switches to) the given 60s loop. Call only from active game screens.
  Future<void> startCreationAmbience({required KidsZoneBgm track}) async {
    if (_ambientPlaying &&
        _currentTrack == track &&
        !_pausedForSpeech &&
        !_pausedForBackground) {
      return;
    }
    try {
      if (_ambientPlaying) {
        await _ambient.stop();
      }
      _currentTrack = track;
      _pausedForSpeech = false;
      _pausedForBackground = false;
      await _ambient.setReleaseMode(ReleaseMode.loop);
      await _ambient.setVolume(_ambientVolume);
      await _ambient.play(AssetSource(track.assetPath));
      _ambientPlaying = true;
    } on Object catch (error, stack) {
      if (kDebugMode) {
        debugPrint('Kids Zone BGM failed ($track): $error\n$stack');
      }
    }
  }

  Future<void> stopAmbience() async {
    if (!_ambientPlaying && !_pausedForSpeech && !_pausedForBackground) return;
    try {
      await _ambient.stop();
    } on Object {
      // Best-effort stop.
    }
    _ambientPlaying = false;
    _pausedForSpeech = false;
    _pausedForBackground = false;
    _currentTrack = null;
  }

  /// Fully pause BGM while narration or read-aloud is playing.
  Future<void> pauseForSpeech() async {
    if (!_ambientPlaying || _pausedForSpeech) return;
    _pausedForSpeech = true;
    if (_pausedForBackground) return;
    try {
      await _ambient.pause();
    } on Object {
      // Ignore pause errors.
    }
  }

  /// Resume gameplay BGM after narration ends.
  ///
  /// The background check is not defensive padding — it is on the direct path.
  /// Backgrounding the app stops speech, which completes the `speak()` that
  /// `ReadAloudButton._toggle` is awaiting, whose `finally` calls straight into
  /// here. Without the guard, locking the phone mid-narration would *start* the
  /// music rather than stop it. The game screens' own narration does the same
  /// thing (archery_game.dart, river_rescue_game.dart).
  Future<void> resumeAfterSpeech() async {
    if (!_ambientPlaying || !_pausedForSpeech) return;
    _pausedForSpeech = false;
    if (_pausedForBackground) return;
    try {
      await _ambient.resume();
    } on Object {
      // Ignore resume errors.
    }
  }

  /// The app is no longer in front of the user — a lock screen, a call, a
  /// switch to another app. Without this the loop plays on over whatever the
  /// phone is doing next, which on a children's title is the complaint you get
  /// rather than a bug anyone reports.
  ///
  /// The track is kept, not dropped: coming back should resume the level the
  /// child left, not restart its music from the top.
  Future<void> pauseForBackground() async {
    if (!_ambientPlaying || _pausedForBackground) return;
    _pausedForBackground = true;
    // Narration already has it paused; only the reason needs recording.
    if (_pausedForSpeech) return;
    try {
      await _ambient.pause();
    } on Object {
      // Ignore pause errors.
    }
  }

  /// Back in the foreground. Resumes only what this class put down: a game that
  /// was narrating when the child left stays quiet until the narration itself
  /// resumes it.
  Future<void> resumeFromBackground() async {
    if (!_pausedForBackground) return;
    _pausedForBackground = false;
    if (!_ambientPlaying || _pausedForSpeech) return;
    try {
      await _ambient.resume();
    } on Object {
      // Ignore resume errors.
    }
  }

  Future<void> playCorrect() async {
    await HapticFeedback.lightImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> playConnect() async {
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> playCelebrate() async {
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  Future<void> playSparkle() async {
    await HapticFeedback.selectionClick();
  }

  /// Bowstring release in the Battle of Siddim archery rounds.
  Future<void> playShoot() async {
    await HapticFeedback.selectionClick();
    await SystemSound.play(SystemSoundType.click);
  }

  // ------------------------------------------------- River Rescue (Moses)
  //
  // The runner needs its moves to feel different from each other by ear alone,
  // because the child is watching the river, not the buttons. These are still
  // haptics over system sounds like the rest of Kids Zone — the short custom
  // clips the design calls for are not authored yet, so each move gets its own
  // recognisable haptic signature in the meantime.

  /// Basket slides to a neighbouring lane.
  Future<void> playLaneSwitch() async {
    await HapticFeedback.selectionClick();
  }

  /// Basket hops a floating log.
  Future<void> playHop() async {
    await HapticFeedback.lightImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  /// Basket ducks under a vine.
  Future<void> playDuck() async {
    await HapticFeedback.lightImpact();
  }

  /// Bump — a splash and a wobble, never damage.
  Future<void> playBump() async {
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  /// A lotus is gathered.
  Future<void> playLotus() async {
    await HapticFeedback.selectionClick();
    await SystemSound.play(SystemSoundType.click);
  }

  /// An angel blessing settles on the basket, and when its shield runs out.
  Future<void> playBlessing() async {
    await HapticFeedback.heavyImpact();
  }

  Future<void> playShieldExpire() async {
    await HapticFeedback.selectionClick();
  }

  /// Where the `thrilling` loop's closing tension section is understood to
  /// begin, in a 60.07s track.
  ///
  /// Unverified by ear: this is the position the Sea Crossing brief describes
  /// ("a riser in the final six bars"), and nothing in the file itself can
  /// confirm it — the number is here, named and in one place, precisely so it
  /// can be retuned by whoever listens to it rather than hunted for.
  static const Duration thrillingClimaxStart = Duration(milliseconds: 52000);

  /// Switches to the `thrilling` loop and jumps to its closing section, for a
  /// phase that needs the music to lift under it.
  ///
  /// Seeking rather than waiting for the loop to come round: a phase is
  /// reached after an unpredictable amount of a child's own time, so its
  /// start bears no fixed relationship to where the loop happens to be.
  Future<void> playClimax() async {
    try {
      if (_currentTrack != KidsZoneBgm.thrilling) {
        await startCreationAmbience(track: KidsZoneBgm.thrilling);
      }
      await _ambient.seek(thrillingClimaxStart);
    } on Object catch (error, stack) {
      if (kDebugMode) {
        debugPrint('Kids Zone climax seek failed: $error\n$stack');
      }
    }
  }

  Future<void> dispose() async {
    await stopAmbience();
    await _ambient.dispose();
  }
}
