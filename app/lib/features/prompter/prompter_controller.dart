import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/matching/script_tracker.dart';
import '../../core/narration/alignment.dart';
import '../../core/progress/reading_progress.dart';
import '../../core/script/run_sections.dart';
import '../../core/script/sections.dart' show ActionCue, actionCues;
import '../../core/script/text.dart';
import '../../core/settings/prompt_settings.dart';
import '../../services/audio/audio_input.dart';
import '../../services/audio/reference_clock.dart';
import '../../services/narration/file_transcriber.dart' show LanguagePackState;
import '../../services/narration/language_pack.dart';
import '../../services/narration/narration_store.dart';
import '../../services/providers.dart';
import '../../services/speech/native_speech_recognizer.dart';
import '../../services/speech/speech_languages.dart';
import '../video/camera_state.dart';

/// Voice and Audio mode's recogniser: the platform's own (Android, iOS, macOS, Windows); null elsewhere.
/// A device without one is told so.
final nativeSpeechProvider = Provider<NativeSpeechRecognizer?>(
  (_) => Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows ? NativeSpeechRecognizer() : null,
);
final audioInputProvider = Provider<AudioInput>((_) => RecordAudioInput());

/// Builds the clock for a take; overridden in tests.
final referenceClockFactoryProvider =
    Provider<ReferenceClock Function({required bool audible, bool cameraOn})>((ref) {
      return ({required bool audible, bool cameraOn = false}) =>
          audible ? AudiblePlayback(handleSession: !(cameraOn && Platform.isIOS)) : SilentClock(durationOf: (path) async {
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
    this.voiceNeedsPack = false,
    this.resetToken = 0,
    this.sectionIndex = 0,
    this.sectionDone = false,
    this.sectionSeconds = 0,
    this.jumpWord = -1,
    this.jumpToken = 0,
    this.cueNow = -1,
    this.cueNext = -1,
    this.cueSeconds = 0,
    this.cueHolding = -1,
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

  /// Voice mode needs a language pack that is not on this device. The reader and camera screens then ask the reader
  /// whether to download it, and start Voice again once it is here.
  final bool voiceNeedsPack;

  /// Bumped by [PrompterController.begin] and restart; the text surface resets
  /// its scroll position when it changes.
  final int resetToken;

  /// Section by section: the section being run, whether it has just ended (the prompter then waits for Retake, Next
  /// or a jump), and how long it took.
  final int sectionIndex;
  final bool sectionDone;
  final double sectionSeconds;

  /// A request to put this word on the reading line (a Retake, Next or jump); the text surface acts when
  /// [jumpToken] changes. -1 until there has been one.
  final int jumpWord;
  final int jumpToken;

  /// Action cues, as indexes into the script's cue list (-1 for none): the one just reached, the one coming up
  /// (with [cueSeconds] to go, for the "Next up" heads-up), and the one that is holding the prompter until Continue.
  final int cueNow;
  final int cueNext;
  final int cueSeconds;
  final int cueHolding;

  PrompterState copyWith({
    PromptReadingProgress? progress,
    bool? playing,
    bool? preparing,
    String? status,
    bool? finished,
    bool? lost,
    bool? voiceUnsupported,
    bool? voiceNeedsPack,
    int? resetToken,
    int? sectionIndex,
    bool? sectionDone,
    double? sectionSeconds,
    int? jumpWord,
    int? jumpToken,
    int? cueNow,
    int? cueNext,
    int? cueSeconds,
    int? cueHolding,
  }) => PrompterState(
    progress: progress ?? this.progress,
    playing: playing ?? this.playing,
    preparing: preparing ?? this.preparing,
    status: status ?? this.status,
    finished: finished ?? this.finished,
    lost: lost ?? this.lost,
    voiceUnsupported: voiceUnsupported ?? this.voiceUnsupported,
    voiceNeedsPack: voiceNeedsPack ?? this.voiceNeedsPack,
    resetToken: resetToken ?? this.resetToken,
    sectionIndex: sectionIndex ?? this.sectionIndex,
    sectionDone: sectionDone ?? this.sectionDone,
    sectionSeconds: sectionSeconds ?? this.sectionSeconds,
    jumpWord: jumpWord ?? this.jumpWord,
    jumpToken: jumpToken ?? this.jumpToken,
    cueNow: cueNow ?? this.cueNow,
    cueNext: cueNext ?? this.cueNext,
    cueSeconds: cueSeconds ?? this.cueSeconds,
    cueHolding: cueHolding ?? this.cueHolding,
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
  List<RunSection> _sections = const [];
  final _sectionClock = Stopwatch();

  // Action cues. A cue is "done" once it has been shown (or, for a hold cue, continued past); a Retake, a jump back or
  // a restart makes the cues after that point fire again.
  List<ActionCue> _cues = const [];
  List<double> _cueTimes = const [];
  final _cuesDone = <int>{};
  Timer? _cueNowTimer;
  Future<void>? _holdSettled;
  final _pace = <(int, int)>[];
  static const _cueNowFor = Duration(milliseconds: 2500);
  static const _fallbackWordsPerSecond = 2.5;
  static const _voiceLineWords = 8;

  @override
  PrompterState build() {
    _input = ref.read(audioInputProvider);
    ref.onDispose(_teardown);
    return const PrompterState();
  }

  int get wordCount => _wordCount;

  /// The script's sections, for Section by section.
  List<RunSection> get sections => _sections;

  /// Whether the script is being run one section at a time (Run: Section by section, and the script has words).
  bool get sectionRun => ref.read(settingsProvider).runStyle == RunStyle.sections && _sections.isNotEmpty;

  /// The script's action cues, in order.
  List<ActionCue> get cues => _cues;

  /// Whether cue [i] belongs to the part of the script being run (all of it, or the current section).
  bool cueInRun(int i) {
    final c = _cues[i], s = currentSection;
    if (s == null) return true;
    return c.wordIndex >= s.startWord && (c.wordIndex < s.endWord || (s.endWord >= _wordCount && c.wordIndex >= _wordCount));
  }

  /// The section being run, or null when running the whole script.
  RunSection? get currentSection => sectionRun ? _sections[state.sectionIndex.clamp(0, _sections.length - 1)] : null;

  /// Audio mode: the recording's length and how far playback has got, for the time left.
  double? get audioSeconds => _audioSeconds;
  Duration get audioPosition => _clock?.position ?? Duration.zero;
  bool get audioPlaying => _clock?.isPlaying ?? false;

  Future<void> begin({
    required int sessionId,
    required String script,
    required PromptControlMode mode,
    String? audioPath,
    Stream<Float32List>? externalSamples,
    int startSection = 0,
  }) async {
    if (sessionId == _session && mode == _mode) return;
    await _teardown();
    _session = sessionId;
    _playWhenReady = false;
    _mode = mode;
    _script = script;
    _wordCount = scriptWords(script).length;
    _tracker = ScriptTracker(scriptWords(script));
    _sections = runSections(script);
    _sectionClock.reset();
    _resetCues(script);
    state = PrompterState(resetToken: state.resetToken + 1, jumpToken: state.jumpToken);
    _externalSamples = externalSamples;
    _audioPath = audioPath;
    if (mode == PromptControlMode.recordedAudio) await _prepareAudio();
    if (startSection > 0 && sectionRun) await goToSection(startSection);
  }

  Stream<Float32List>? _externalSamples;
  String? _audioPath;

  /// Narration: Play was pressed while the recording was loading.
  bool _playWhenReady = false;

  /// Voice: a recogniser's text is the whole running transcript of its current utterance, not only what was said since
  /// the last result, and it goes on growing until the recogniser ends the utterance (a final result). Words heard
  /// while a hold cue held are therefore still at the start of the transcript after Continue, and the tracker would
  /// take them for new speech and highlight them. [_heldWords] counts the words the transcript held during the hold,
  /// and after Continue [_ignoredWords] drops that many from its start, until the utterance ends.
  int _heldWords = 0;
  int _ignoredWords = 0;

  Future<void> togglePlay() => state.playing ? pause() : play();

  Future<void> play() async {
    // Play on a held cue is Continue.
    if (state.cueHolding >= 0) _releaseHold();
    await _holdSettled;
    // Pressing play on a finished section carries on: the next section, or a retake after the last one.
    if (sectionRun && state.sectionDone) {
      return state.sectionIndex < _sections.length - 1 ? nextSection() : retakeSection();
    }
    if (sectionRun) _sectionClock.start();
    switch (_mode) {
      case PromptControlMode.normal:
        state = state.copyWith(playing: true, finished: false);
      case PromptControlMode.voice:
        await _startVoice();
        _voiceCues();
      case PromptControlMode.recordedAudio:
        // Narration scrolls by the playback position alone: no microphone, no recogniser.
        final clock = _clock;
        // Play pressed while the recording is still loading starts it as soon as it is ready.
        if (state.preparing) {
          _playWhenReady = true;
          return;
        }
        if (clock == null || _alignment == null) return;
        state = state.copyWith(playing: true, finished: false, status: 'Playing');
        // just_audio's play() future only completes on pause/end, so don't await it.
        unawaited(clock.play());
        _startNarrationTicker();
    }
  }

  Future<void> pause() async {
    _sectionClock.stop();
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
      cueNext: -1,
      status: _mode == PromptControlMode.recordedAudio && !state.finished ? 'Paused' : state.status,
    );
  }

  Future<void> restart() async {
    final wasMode = _mode;
    await pause();
    _sectionClock.reset();
    // The same script and recording: the cues start over, but where they fall in the narration has not changed.
    _resetCues(_script, keepTimes: true);
    state = PrompterState(preparing: state.preparing, status: state.status, resetToken: state.resetToken + 1, jumpToken: state.jumpToken);
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
    // Narration only: moving the audio back from the end reopens the script. Other modes keep their state as before.
    final reopen = _mode == PromptControlMode.recordedAudio && state.finished;
    // Section by section: a tap in another section makes it the current one, and a tap in a finished section reopens it.
    final run = sectionRun && _mode != PromptControlMode.normal;
    _cuesDone
      ..clear()
      ..addAll([for (var i = 0; i < _cues.length; i++) if (_cues[i].wordIndex <= index) i]);
    _cueNowTimer?.cancel();
    state = state.copyWith(
      cueNow: -1,
      cueNext: -1,
      cueHolding: -1,
      lost: false,
      finished: reopen || (run && state.sectionDone) ? false : null,
      status: reopen || (run && state.sectionDone) ? 'Paused' : null,
      sectionIndex: run ? runSectionIndexForWord(_sections, index) : null,
      sectionDone: run ? false : null,
      progress: PromptReadingProgress.synchronized(
        confirmed: index,
        predicted: _predictedAfter(index),
      ),
    );
  }

  /// Normal mode reached the end of the script.
  void markFinished() => state = state.copyWith(playing: false, finished: true);

  // --- Section by section ----------------------------------------------------

  /// The section ended: stop listening or playing and wait for Retake, Next or a jump. The last section's end is also
  /// the end of the script.
  Future<void> endSection() async {
    final section = currentSection;
    if (section == null || state.sectionDone) return;
    final last = section.index >= _sections.length - 1;
    final map = _alignment;
    final seconds = _mode == PromptControlMode.recordedAudio && map != null
        ? _sectionEndSeconds(section, map) - _sectionStartSeconds(section, map)
        : _sectionClock.elapsedMilliseconds / 1000.0;
    // Mark it first, so a result that arrives while the recogniser shuts down cannot end the section twice.
    state = state.copyWith(sectionDone: true, sectionSeconds: seconds, cueNow: -1, cueNext: -1, cueHolding: -1);
    await pause();
    state = state.copyWith(playing: false, finished: last, status: last ? 'Finished' : 'Section done');
  }

  /// Puts the prompter at the first word of section [index] and waits there, or starts it when [play] is true.
  Future<void> goToSection(int index, {bool play = false}) async {
    if (_sections.isEmpty) return;
    final i = index.clamp(0, _sections.length - 1);
    final section = _sections[i];
    await pause();
    _sectionClock.reset();
    _clearLost();
    final word = section.startWord;
    final map = _alignment;
    if (_mode == PromptControlMode.recordedAudio && map != null) {
      await _clock?.seek(_clockPositionFor(_sectionStartSeconds(section, map)));
    }
    _tracker?.syncTo(word - 1);
    _cuesDone
      ..clear()
      ..addAll([for (var k = 0; k < _cues.length; k++) if (_cues[k].wordIndex < word) k]);
    _cueNowTimer?.cancel();
    state = state.copyWith(
      cueNow: -1,
      cueNext: -1,
      cueHolding: -1,
      sectionIndex: i,
      sectionDone: false,
      finished: false,
      lost: false,
      status: _mode == PromptControlMode.recordedAudio ? 'Paused' : '',
      sectionSeconds: 0,
      // Narration puts its first word on the reading line; Voice and Auto-scroll wait for the first word, with
      // nothing highlighted or dimmed (Voice's matcher is started at the section by `_onHypothesis`).
      progress: _mode == PromptControlMode.recordedAudio && word > 0
          ? PromptReadingProgress.synchronized(confirmed: word, predicted: _predictedAfter(word))
          : PromptReadingProgress.inactive,
      jumpWord: word,
      jumpToken: state.jumpToken + 1,
    );
    if (play) await this.play();
  }

  /// Runs the current section again from its first word.
  Future<void> retakeSection() => goToSection(state.sectionIndex, play: true);

  /// Carries on with the next section. Does nothing after the last.
  Future<void> nextSection() async {
    if (state.sectionIndex >= _sections.length - 1) return;
    await goToSection(state.sectionIndex + 1, play: true);
  }

  /// Run style or sections changed while the prompter is open: the section holding the reading position becomes the
  /// current one, or the run goes back to the whole script.
  void refreshRunStyle() {
    final word = _mode == PromptControlMode.normal ? ref.read(readingWordProvider) : state.progress.confirmedWordIndex;
    state = state.copyWith(
      sectionIndex: sectionRun ? runSectionIndexForWord(_sections, math.max(word, 0)) : 0,
      sectionDone: false,
    );
  }

  /// Where section [s] starts in the recording: the start of the file for the first section, else its first word.
  double _sectionStartSeconds(RunSection s, AlignmentMap map) => s.index == 0 ? 0 : map.timeOfWord(s.startWord);

  /// Where section [s] ends in the recording: where the next section's first word starts, or the end of the file.
  double _sectionEndSeconds(RunSection s, AlignmentMap map) =>
      s.endWord < map.wordCount ? map.timeOfWord(s.endWord) : map.duration;

  // --- Action cues -------------------------------------------------------------

  void _resetCues(String script, {bool keepTimes = false}) {
    _cues = actionCues(script);
    // Narration cue times come from the recording's alignment, which is only computed when the recording loads, so
    // a restart of the same script must keep them (a new session or mode has to start without them).
    if (!keepTimes) _cueTimes = const [];
    _cuesDone.clear();
    _pace.clear();
    _cueNowTimer?.cancel();
  }

  /// Every mode reports where the text is: the first [reached] cues are at or behind the reading line, and cue
  /// [next] (the first of the rest in this run), if any, is [secondsToNext] seconds away and so due a heads-up.
  /// A reached cue shows as "now", or holds the prompter if it is a hold cue.
  void cuePosition({required int reached, int? next, double secondsToNext = 0}) {
    if (_cues.isEmpty) return;
    for (var i = 0; i < reached && i < _cues.length; i++) {
      if (_cuesDone.contains(i) || state.cueHolding == i || !cueInRun(i)) continue;
      if (_cues[i].hold) {
        _beginHold(i);
        return;
      }
      _cuesDone.add(i);
      _showCueNow(i);
    }
    final coming = next != null && state.cueHolding < 0 && secondsToNext <= ref.read(settingsProvider).cueLeadSeconds ? next : -1;
    final seconds = coming < 0 ? 0 : math.max(1, secondsToNext.ceil());
    if (coming != state.cueNext || (coming >= 0 && seconds != state.cueSeconds)) {
      state = state.copyWith(cueNext: coming, cueSeconds: seconds);
    }
  }

  /// The word to show as coming next after [confirmed]: the following word, or none at the end. When an action cue
  /// sits right before that word, none either: the next line is not due until the cue is done, so the highlight stays
  /// on this side of it. A script without cues always gets the following word.
  int? _predictedAfter(int confirmed) {
    final next = confirmed + 1;
    if (next >= _wordCount) return null;
    for (final c in _cues) {
      if (c.wordIndex == next) return null;
    }
    return next;
  }

  void _showCueNow(int i) {
    _cueNowTimer?.cancel();
    state = state.copyWith(cueNow: i, cueNext: -1);
    _cueNowTimer = Timer(_cueNowFor, () {
      if (state.cueNow == i && state.cueHolding != i) state = state.copyWith(cueNow: -1);
    });
  }

  /// A hold cue was reached: the text stops (Auto-scroll), speech is ignored (Voice) or the audio pauses (Narration)
  /// until [continueFromHold].
  void _beginHold(int i) {
    _cueNowTimer?.cancel();
    state = state.copyWith(cueNow: i, cueNext: -1, cueHolding: i, status: 'On hold');
    switch (_mode) {
      case PromptControlMode.normal:
        state = state.copyWith(playing: false);
      case PromptControlMode.voice:
        // The recogniser can deliver several words at once and run past the cue: the reader resumes after
        // Continue from the cue, not from wherever that burst ended.
        final at = _cues[i].wordIndex - 1;
        if (state.progress.confirmedWordIndex > at) {
          _tracker?.syncTo(at);
          state = state.copyWith(
            progress: at < 0
                ? PromptReadingProgress.inactive
                : PromptReadingProgress.synchronized(confirmed: at, predicted: _predictedAfter(at)),
          );
        }
      case PromptControlMode.recordedAudio:
        _narrationTicker?.cancel();
        state = state.copyWith(playing: false);
        _holdSettled = _holdAudioAt(i);
    }
  }

  /// Narration: stops the audio exactly at cue [i], so Continue resumes from the same point.
  Future<void> _holdAudioAt(int i) async {
    final clock = _clock;
    if (clock == null) return;
    await clock.pause();
    if (state.cueHolding == i) await clock.seek(_clockPositionFor(_cueTimes[i]));
  }

  /// Ends the hold. The held cue has been on screen the whole time, so it doesn't turn "now" again; that would hide
  /// the next cue's heads-up for a few seconds.
  void _releaseHold() {
    // What was said during the hold is not read: only words after it count.
    _ignoredWords = _heldWords;
    _heldWords = 0;
    _cuesDone.add(state.cueHolding);
    _cueNowTimer?.cancel();
    state = state.copyWith(cueHolding: -1, cueNow: -1);
  }

  /// Continue after a hold cue (button, tap or hotkey).
  Future<void> continueFromHold() async {
    if (state.cueHolding < 0) return;
    // Voice is still listening, so only the hold has to end; the others play from where they stopped.
    if (state.playing) {
      _releaseHold();
      state = state.copyWith(status: 'Listening');
      // The next cue's heads-up shows now, not only after the next words are heard.
      _voiceCues();
    } else {
      await play();
    }
  }

  void _notePace(int confirmed) {
    final now = _trackerClock.elapsedMilliseconds;
    _pace.add((now, confirmed));
    _pace.removeWhere((p) => now - p.$1 > 30000);
  }

  /// Words per second over the last ~30 s, or a typical 150 words per minute until there is enough to measure.
  double get _wordsPerSecond {
    if (_pace.length < 3) return _fallbackWordsPerSecond;
    final spanMs = _pace.last.$1 - _pace.first.$1, words = _pace.last.$2 - _pace.first.$2;
    if (spanMs < 3000 || words < 4) return _fallbackWordsPerSecond;
    return (words * 1000 / spanMs).clamp(0.8, 6.0);
  }

  /// Voice: where the reader is, in words, against each cue's position. The heads-up comes by the reader's pace, but
  /// never less than about a line ahead.
  void _voiceCues() {
    if (_cues.isEmpty) return;
    final pos = math.max(state.progress.confirmedWordIndex, (currentSection?.startWord ?? 0) - 1);
    var reached = 0;
    while (reached < _cues.length && _cues[reached].wordIndex - 1 <= pos) {
      reached++;
    }
    int? next;
    var seconds = 0.0;
    for (var i = reached; i < _cues.length; i++) {
      if (!cueInRun(i)) continue;
      final away = _cues[i].wordIndex - 1 - pos;
      final pace = _wordsPerSecond;
      final byPace = away / pace;
      // A cue within a line is announced even if the pace says it is further off than the setting.
      seconds = away <= _voiceLineWords ? math.min(byPace, ref.read(settingsProvider).cueLeadSeconds.toDouble()) : byPace;
      next = i;
      break;
    }
    cuePosition(reached: reached, next: next, secondsToNext: seconds);
  }

  /// Narration: cue times come from the alignment, so the heads-up is exactly the set number of seconds ahead.
  /// Returns true when a hold cue has just stopped the audio.
  bool _narrationCues(double seconds) {
    if (_cueTimes.length != _cues.length) return false;
    var reached = 0;
    while (reached < _cueTimes.length && _cueTimes[reached] <= seconds) {
      reached++;
    }
    int? next;
    for (var i = reached; i < _cues.length; i++) {
      if (cueInRun(i)) {
        next = i;
        break;
      }
    }
    cuePosition(reached: reached, next: next, secondsToNext: next == null ? 0 : _cueTimes[next] - seconds);
    return state.cueHolding >= 0;
  }

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
    // The Record screen records the microphone, so the recogniser may not open it itself (reference: Video mode).
    final language = await speechLanguageForScript(
      native: native,
      setting: ref.read(settingsProvider).speechLanguage,
      script: _script,
    );
    state = state.copyWith(playing: true, status: 'Listening', voiceUnsupported: false, voiceNeedsPack: false);
    // Apple's speech pack for the language must be on this device (English ships with the system, the other platforms
    // have nothing to fetch, and a language the older recogniser does on the device needs none). The reader is asked
    // before one is downloaded, when Start is pressed; changing to Voice inside the reader never downloads on its own,
    // it says what to do. Progress shows as the status while an approved download runs.
    if (!language.toLowerCase().startsWith('en')) {
      final watch = ref.listen(languagePackProvider, (_, s) {
        final note = s.note;
        if (s.phase == LanguagePackPhase.downloading && note != null && _nativeVoice) state = state.copyWith(status: note);
      });
      var pack = LanguagePackState.ready;
      Object? failure;
      try {
        pack = await ref.read(languagePackProvider.notifier).ensure(language, voice: true);
      } catch (e) {
        failure = e;
      } finally {
        watch.close();
      }
      if (!_nativeVoice) return; // paused or closed while the pack downloaded
      if (failure != null || pack == LanguagePackState.needsDownload) {
        _nativeVoice = false;
        // The screen asks the reader whether to download it (a failed download is asked about again, with its error).
        state = state.copyWith(playing: false, status: 'Language pack needed', voiceNeedsPack: true);
        return;
      }
      state = state.copyWith(status: 'Listening');
    }
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
    // The next listening session starts with an empty transcript.
    _heldWords = 0;
    _ignoredWords = 0;
    await sub.cancel(); // stops the recogniser, which owns its microphone
  }

  /// Every recogniser result goes to the tracker, as the reference does (`ud.q`); blank ones carry nothing.
  void _onHypothesis(SpeechHypothesis h) {
    final tracker = _tracker;
    // A finished section ignores speech until Retake, Next or a jump.
    // A finished section, and a hold cue, ignore speech until Retake, Next, a jump or Continue.
    if (tracker == null || state.sectionDone || state.cueHolding >= 0) {
      if (state.cueHolding >= 0) {
        // Count what the transcript holds through the hold (none once the utterance has ended), so that after
        // Continue only words spoken later are read.
        _heldWords = h.isFinal ? 0 : trackerWords(h.text).length;
        if (h.isFinal) tracker?.endUtterance();
      }
      return;
    }
    // After Continue, the first words of the same utterance's transcript were heard during the hold.
    var text = h.text;
    if (_ignoredWords > 0) {
      final words = trackerWords(text);
      text = words.length > _ignoredWords ? words.skip(_ignoredWords).join(' ') : '';
    }
    if (text.trim().isNotEmpty) {
      // A section that has not heard its first word yet starts the matcher at the section, not at the script's start.
      final start = currentSection?.startWord ?? 0;
      tracker.syncTo(math.max(state.progress.confirmedWordIndex, start - 1));
      final moved = tracker.update(text, _trackerClock.elapsedMilliseconds);
      if (moved == null) {
        // Speech that keeps not matching means the reader is out of step.
        if (!state.lost) _lostTimer ??= Timer(_lostAfter, () => state = state.copyWith(lost: true));
      } else {
        _clearLost();
        final confirmed = tracker.lastMatched;
        state = state.copyWith(
          progress: PromptReadingProgress.synchronized(
            confirmed: confirmed,
            predicted: _predictedAfter(confirmed),
          ),
          lost: false,
          finished: moved >= _wordCount,
        );
        _notePace(confirmed);
        _voiceCues();
        // This result reached a hold cue: everything its transcript holds so far was heard before or during the hold.
        if (state.cueHolding >= 0) _heldWords = trackerWords(h.text).length;
        final section = currentSection;
        if (section != null && confirmed >= section.endWord - 1 && state.cueHolding < 0) unawaited(endSection());
      }
    }
    if (h.isFinal) {
      // The utterance has ended: the next transcript starts empty.
      _ignoredWords = 0;
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
      final clock = ref.read(referenceClockFactoryProvider)(audible: true, cameraOn: ref.read(cameraOnProvider));
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
      _cueTimes = [
        for (final c in _cues)
          c.wordIndex >= _alignment!.wordCount ? _alignment!.duration : math.max(0.0, _alignment!.timeOfWord(c.wordIndex) - 0.1),
      ];
      _clock = clock;
      _completedSub = clock.completed.listen((_) async {
        if (_clock != clock) return;
        if (sectionRun) return endSection();
        await pause();
        state = state.copyWith(finished: true, status: 'Finished');
      });
      state = state.copyWith(preparing: false, status: 'Ready — press Play');
      if (_playWhenReady) {
        _playWhenReady = false;
        await play();
      }
    } catch (_) {
      state = state.copyWith(preparing: false, status: 'Could not load this audio file');
    }
  }

  Future<String> _narrationLanguage() => speechLanguageForScript(
    native: ref.read(nativeSpeechProvider),
    setting: ref.read(settingsProvider).speechLanguage,
    script: _script,
  );

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
    if (_cues.isNotEmpty && _narrationCues(seconds)) return;
    final section = currentSection;
    if (section != null && !state.sectionDone && seconds >= _sectionEndSeconds(section, map)) {
      // Play only this section's part of the recording, then wait.
      unawaited(endSection());
      return;
    }
    var word = map.wordIndexAt(seconds).clamp(0, map.wordCount - 1);
    if (section != null) word = word.clamp(section.startWord, section.endWord - 1);
    if (word == state.progress.confirmedWordIndex) return;
    state = state.copyWith(
      progress: PromptReadingProgress.synchronized(confirmed: word, predicted: _predictedAfter(word)),
    );
  }

  /// Narration: moves the audio by [delta] (negative goes back), and the script with it.
  Future<void> skip(Duration delta) async {
    final clock = _clock;
    if (_mode != PromptControlMode.recordedAudio || clock == null) return;
    var target = clock.position + delta;
    final section = currentSection, map = _alignment;
    if (section != null && map != null) {
      // Inside the section: the audio does not run on into the next one or back into the last.
      final from = _clockPositionFor(_sectionStartSeconds(section, map));
      final to = _clockPositionFor(_sectionEndSeconds(section, map)) - const Duration(milliseconds: 100);
      if (target < from) target = from;
      if (target > to) target = to < from ? from : to;
    }
    await clock.seek(target < Duration.zero ? Duration.zero : target);
    // Cues after the new position fire again when the audio gets to them.
    final at = (target.inMilliseconds + ref.read(settingsProvider).narrationOffsetMs) / 1000.0;
    _cuesDone.removeWhere((i) => i < _cueTimes.length && _cueTimes[i] > at);
    if (state.finished || state.sectionDone) {
      state = state.copyWith(finished: false, sectionDone: false, status: state.playing ? 'Playing' : 'Paused');
    }
    _followPlayback();
  }

  Future<void> _teardown() async {
    _clearLost();
    _cueNowTimer?.cancel();
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
