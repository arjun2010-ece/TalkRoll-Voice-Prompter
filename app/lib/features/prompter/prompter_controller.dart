import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/matching/script_tracker.dart';
import '../../core/narration/alignment.dart';
import '../../core/progress/reading_progress.dart';
import '../../core/script/text.dart';
import '../../core/settings/prompt_settings.dart';
import '../../services/audio/audio_input.dart';
import '../../services/audio/reference_clock.dart';
import '../../services/narration/narration_store.dart';
import '../../services/providers.dart';
import '../../services/speech/native_speech_recognizer.dart';
import '../../services/speech/speech_languages.dart';

/// Voice and Audio mode's recogniser: the platform's own (Android, iOS, macOS, Windows); null elsewhere.
/// A device without one is told so.
final nativeSpeechProvider = Provider<NativeSpeechRecognizer?>(
  (_) => Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows ? NativeSpeechRecognizer() : null,
);
final audioInputProvider = Provider<AudioInput>((_) => RecordAudioInput());

/// Builds the clock for a take; overridden in tests.
final referenceClockFactoryProvider =
    Provider<ReferenceClock Function({required bool audible})>((ref) {
      return ({required bool audible}) =>
          audible ? AudiblePlayback() : SilentClock(durationOf: (path) async {
            final c = AudiblePlayback();
            try {
              return await c.load(path);
            } finally {
              await c.dispose();
            }
          });
    });

class PrompterState {
  const PrompterState({
    this.progress = PromptReadingProgress.inactive,
    this.playing = false,
    this.preparing = false,
    this.status = '',
    this.finished = false,
    this.lost = false,
    this.voiceUnsupported = false,
    this.resetToken = 0,
  });
  final PromptReadingProgress progress;
  final bool playing;
  final bool preparing;
  final String status;
  final bool finished;

  /// Voice mode: speech is being heard but has not matched the script for a
  /// few seconds. Cleared as soon as the highlight moves.
  final bool lost;

  /// Mobile Voice mode: this device has no on-device speech recognition to follow the reader
  /// with. The Read and Record screens tell the reader once each time this turns on.
  final bool voiceUnsupported;

  /// Bumped by [PrompterController.begin] and restart; the text surface resets
  /// its scroll position when it changes.
  final int resetToken;

  PrompterState copyWith({
    PromptReadingProgress? progress,
    bool? playing,
    bool? preparing,
    String? status,
    bool? finished,
    bool? lost,
    bool? voiceUnsupported,
    int? resetToken,
  }) => PrompterState(
    progress: progress ?? this.progress,
    playing: playing ?? this.playing,
    preparing: preparing ?? this.preparing,
    status: status ?? this.status,
    finished: finished ?? this.finished,
    lost: lost ?? this.lost,
    voiceUnsupported: voiceUnsupported ?? this.voiceUnsupported,
    resetToken: resetToken ?? this.resetToken,
  );
}

/// Drives one prompting session. [begin] is called with a new session id on
/// every Start; that is the only signal that resets progress and playback.
class PrompterController extends Notifier<PrompterState> {
  late final AudioInput _input;
  int _session = -1;
  PromptControlMode _mode = PromptControlMode.normal;
  ScriptTracker? _tracker;
  String _script = '';
  StreamSubscription<Object?>? _voiceSub;
  bool _nativeVoice = false;
  final _trackerClock = Stopwatch()..start();
  Timer? _lostTimer;
  static const _lostAfter = Duration(seconds: 4);
  ReferenceClock? _clock;
  StreamSubscription<void>? _completedSub;
  AlignmentMap? _alignment;
  Timer? _narrationTicker;
  double? _audioSeconds;
  int _wordCount = 0;

  @override
  PrompterState build() {
    _input = ref.read(audioInputProvider);
    ref.onDispose(_teardown);
    return const PrompterState();
  }

  int get wordCount => _wordCount;

  /// Audio mode: the recording's length and how far playback has got, for the time left.
  double? get audioSeconds => _audioSeconds;
  Duration get audioPosition => _clock?.position ?? Duration.zero;

  Future<void> begin({
    required int sessionId,
    required String script,
    required PromptControlMode mode,
    String? audioPath,
    Stream<Float32List>? externalSamples,
  }) async {
    if (sessionId == _session && mode == _mode) return;
    await _teardown();
    _session = sessionId;
    _mode = mode;
    _script = script;
    _wordCount = scriptWords(script).length;
    _tracker = ScriptTracker(scriptWords(script));
    state = PrompterState(resetToken: state.resetToken + 1);
    _externalSamples = externalSamples;
    _audioPath = audioPath;
    if (mode == PromptControlMode.recordedAudio) await _prepareAudio();
  }

  Stream<Float32List>? _externalSamples;
  String? _audioPath;

  Future<void> togglePlay() => state.playing ? pause() : play();

  Future<void> play() async {
    switch (_mode) {
      case PromptControlMode.normal:
        state = state.copyWith(playing: true, finished: false);
      case PromptControlMode.voice:
        await _startVoice();
      case PromptControlMode.recordedAudio:
        // Narration scrolls by the playback position alone: no microphone, no recogniser.
        final clock = _clock;
        if (clock == null || _alignment == null) return;
        state = state.copyWith(playing: true, finished: false, status: 'Playing');
        // just_audio's play() future only completes on pause/end, so don't await it.
        unawaited(clock.play());
        _startNarrationTicker();
    }
  }

  Future<void> pause() async {
    switch (_mode) {
      case PromptControlMode.normal:
        break;
      case PromptControlMode.voice:
        await _stopVoice();
      case PromptControlMode.recordedAudio:
        _narrationTicker?.cancel();
        await _clock?.pause();
    }
    _clearLost();
    state = state.copyWith(
      playing: false,
      lost: false,
      status: _mode == PromptControlMode.recordedAudio && !state.finished ? 'Paused' : state.status,
    );
  }

  Future<void> restart() async {
    final wasMode = _mode;
    await pause();
    state = PrompterState(preparing: state.preparing, status: state.status, resetToken: state.resetToken + 1);
    if (wasMode == PromptControlMode.recordedAudio) await _clock?.seekToStart();
  }

  /// Jump to a tapped word (Voice: the matcher continues from there; Narration: the audio moves to that word).
  void seekTo(int index) {
    if (index < 0 || index >= _wordCount) return;
    _clearLost();
    final map = _alignment;
    if (_mode == PromptControlMode.recordedAudio && map != null) {
      unawaited(_clock?.seek(_clockPositionFor(map.timeOfWord(index))));
    }
    state = state.copyWith(
      lost: false,
      progress: PromptReadingProgress.synchronized(
        confirmed: index,
        predicted: index + 1 < _wordCount ? index + 1 : null,
      ),
    );
  }

  /// Normal mode reached the end of the script.
  void markFinished() => state = state.copyWith(playing: false, finished: true);

  // --- Voice ---------------------------------------------------------------

  Future<void> _startVoice() async {
    final native = ref.read(nativeSpeechProvider);
    state = state.copyWith(voiceUnsupported: false);
    // There is no other recogniser: a device without speech recognition is told so.
    if (native != null && await _safeAvailable(native)) return _startNativeVoice(native);
    return _voiceUnsupported('Speech recognition is not available on this device');
  }

  void _voiceUnsupported(String message) =>
      state = state.copyWith(playing: false, status: message, voiceUnsupported: true);

  Future<bool> _safeAvailable(NativeSpeechRecognizer native) async {
    try {
      return await native.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Voice mode on the platform recogniser: it reports the whole running hypothesis, which
  /// [ScriptTracker] follows on every change. It records the microphone itself.
  Future<void> _startNativeVoice(NativeSpeechRecognizer native) async {
    if (!await _input.hasPermission()) {
      state = state.copyWith(status: 'Microphone access is needed for Voice control');
      return;
    }
    _nativeVoice = true;
    _tracker?.syncTo(state.progress.confirmedWordIndex);
    await _sendBias(native);
    state = state.copyWith(playing: true, status: 'Listening', voiceUnsupported: false);
    // The Record screen records the microphone, so the recogniser may not open it itself (reference: Video mode).
    final setting = ref.read(settingsProvider).speechLanguage;
    final auto = setting == autoSpeechLanguage;
    final language = resolveSpeechLanguage(
      setting: setting,
      script: _script,
      deviceTag: PlatformDispatcher.instance.locale.toLanguageTag(),
      detected: auto ? await native.detectLanguage(_script) : null,
      supported: auto ? await native.supportedLanguages() : const [],
    );
    _voiceSub = native.hypotheses(micFallback: _externalSamples == null, headsetMic: _mode != PromptControlMode.recordedAudio, language: language).listen(_onHypothesis, onError: (Object e) {
      final sub = _voiceSub;
      _nativeVoice = false;
      _voiceSub = null;
      unawaited(sub?.cancel());
      if (_mode == PromptControlMode.recordedAudio) unawaited(_clock?.pause());
      if (e is NativeRecognizerUnavailable) {
        // `isAvailable` can be true while the language's pack is still missing.
        _voiceUnsupported(e.message);
        return;
      }
      state = state.copyWith(playing: false, status: '$e');
    });
  }

  Future<void> _sendBias(NativeSpeechRecognizer native) async {
    final words = _tracker?.biasingWords();
    if (words == null) return;
    try {
      await native.setBias(words);
    } catch (_) {}
  }

  Future<void> _stopVoice() async {
    // Only touch the microphone if Voice mode actually opened it.
    final sub = _voiceSub;
    if (sub == null) return;
    _voiceSub = null;
    _nativeVoice = false;
    await sub.cancel(); // stops the recogniser, which owns its microphone
  }

  /// Every recogniser result goes to the tracker, as the reference does (`ud.q`); blank ones carry nothing.
  void _onHypothesis(SpeechHypothesis h) {
    final tracker = _tracker;
    if (tracker == null) return;
    if (h.text.trim().isNotEmpty) {
      tracker.syncTo(state.progress.confirmedWordIndex);
      final moved = tracker.update(h.text, _trackerClock.elapsedMilliseconds);
      if (moved == null) {
        // Speech that keeps not matching means the reader is out of step.
        if (!state.lost) _lostTimer ??= Timer(_lostAfter, () => state = state.copyWith(lost: true));
      } else {
        _clearLost();
        final confirmed = tracker.lastMatched;
        state = state.copyWith(
          progress: PromptReadingProgress.synchronized(
            confirmed: confirmed,
            predicted: confirmed + 1 < _wordCount ? confirmed + 1 : null,
          ),
          lost: false,
          finished: moved >= _wordCount,
        );
      }
    }
    if (h.isFinal) {
      tracker.endUtterance();
      final native = ref.read(nativeSpeechProvider);
      if (native != null && _nativeVoice) unawaited(_sendBias(native));
    }
  }

  void _clearLost() {
    _lostTimer?.cancel();
    _lostTimer = null;
  }

  // --- Narration ---------------------------------------------------------------

  /// Loads the recording and lines its cached transcript up with the script. The transcript was made when the
  /// recording was chosen (see `NarrationPrep`), so nothing is recognised here and the microphone is never used.
  Future<void> _prepareAudio() async {
    final path = _audioPath;
    if (path == null) {
      state = state.copyWith(status: 'Choose an audio file');
      return;
    }
    state = state.copyWith(preparing: true, status: 'Loading audio…');
    try {
      final clock = ref.read(referenceClockFactoryProvider)(audible: true);
      final seconds = await clock.load(path);
      final language = await _narrationLanguage();
      final transcript = await const NarrationStore().cachedTranscript(path, language);
      if (transcript == null) {
        await clock.dispose();
        state = state.copyWith(preparing: false, status: 'Choose the recording again to transcribe it');
        return;
      }
      _audioSeconds = seconds;
      _alignment = alignScript(scriptWords(_script), transcript, duration: seconds);
      _clock = clock;
      _completedSub = clock.completed.listen((_) async {
        if (_clock != clock) return;
        await pause();
        state = state.copyWith(finished: true, status: 'Finished');
      });
      state = state.copyWith(preparing: false, status: 'Ready — press Play');
    } catch (_) {
      state = state.copyWith(preparing: false, status: 'Could not load this audio file');
    }
  }

  Future<String> _narrationLanguage() async {
    final native = ref.read(nativeSpeechProvider);
    final setting = ref.read(settingsProvider).speechLanguage;
    final auto = setting == autoSpeechLanguage;
    return resolveSpeechLanguage(
      setting: setting,
      script: _script,
      deviceTag: PlatformDispatcher.instance.locale.toLanguageTag(),
      detected: auto && native != null ? await native.detectLanguage(_script) : null,
      supported: auto && native != null ? await native.supportedLanguages() : const [],
    );
  }

  /// The audio position that shows the script word spoken at [seconds], allowing for the sync offset.
  Duration _clockPositionFor(double seconds) {
    final offset = ref.read(settingsProvider).narrationOffsetMs;
    final ms = (seconds * 1000).round() - offset;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  void _startNarrationTicker() {
    _narrationTicker?.cancel();
    _narrationTicker = Timer.periodic(const Duration(milliseconds: 40), (_) => _followPlayback());
  }

  /// Moves the highlight to the word being spoken at the playback position.
  void _followPlayback() {
    final map = _alignment, clock = _clock;
    if (map == null || clock == null || map.wordCount == 0) return;
    final offset = ref.read(settingsProvider).narrationOffsetMs;
    final seconds = (clock.position.inMilliseconds + offset) / 1000.0;
    final word = map.wordIndexAt(seconds).clamp(0, map.wordCount - 1);
    if (word == state.progress.confirmedWordIndex) return;
    state = state.copyWith(
      progress: PromptReadingProgress.synchronized(confirmed: word, predicted: word + 1 < _wordCount ? word + 1 : null),
    );
  }

  /// Narration: moves the audio by [delta] (negative goes back), and the script with it.
  Future<void> skip(Duration delta) async {
    final clock = _clock;
    if (_mode != PromptControlMode.recordedAudio || clock == null) return;
    final target = clock.position + delta;
    await clock.seek(target < Duration.zero ? Duration.zero : target);
    _followPlayback();
  }

  Future<void> _teardown() async {
    _clearLost();
    _narrationTicker?.cancel();
    _narrationTicker = null;
    await _completedSub?.cancel();
    _completedSub = null;
    await _stopVoice();
    await _clock?.dispose();
    _clock = null;
    _alignment = null;
  }
}

final prompterProvider = NotifierProvider<PrompterController, PrompterState>(PrompterController.new);
