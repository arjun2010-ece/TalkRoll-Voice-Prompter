import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../core/narration/alignment.dart';
import '../../core/script/text.dart';
import '../../services/narration/file_transcriber.dart';
import '../../services/narration/language_pack.dart';
import '../../services/narration/narration_store.dart';
import '../../services/providers.dart';
import '../../services/speech/speech_languages.dart';
import '../prompter/prompter_controller.dart';
import 'audio_check.dart';

export '../../services/narration/language_pack.dart' show fileTranscriberProvider, languagePackProvider;

final narrationStoreProvider = Provider<NarrationStore>((_) => const NarrationStore());

enum NarrationPhase { idle, transcribing, ready, failed }

class NarrationPrepState {
  const NarrationPrepState({
    this.phase = NarrationPhase.idle,
    this.path,
    this.progress = 0,
    this.transcript = const [],
    this.failure,
    this.message = '',
    this.lowMatchAccepted = false,
    this.language = '',
  });

  final NarrationPhase phase;

  /// The recording this state is about.
  final String? path;

  /// How much of the recording is transcribed, 0 to 1.
  final double progress;
  final List<TimedWord> transcript;
  final TranscribeFailure? failure;
  final String message;

  /// The reader chose "Continue anyway" for a recording that does not match the script.
  final bool lowMatchAccepted;

  /// The language the recording was read as (`pt-BR`, ...), so a mismatch can say so.
  final String language;

  NarrationPrepState copyWith({NarrationPhase? phase, double? progress, bool? lowMatchAccepted}) => NarrationPrepState(
    phase: phase ?? this.phase,
    path: path,
    progress: progress ?? this.progress,
    transcript: transcript,
    failure: failure,
    message: message,
    lowMatchAccepted: lowMatchAccepted ?? this.lowMatchAccepted,
    language: language,
  );
}

/// Imports a chosen recording and transcribes it once on this device (a cached transcript is reused).
class NarrationPrep extends Notifier<NarrationPrepState> {
  int _run = 0;

  @override
  NarrationPrepState build() => const NarrationPrepState();

  /// The language to transcribe in: the reading-language setting, or the script's own language.
  Future<String> language(String script) async {
    final native = ref.read(nativeSpeechProvider);
    final setting = ref.read(settingsProvider).speechLanguage;
    final auto = setting == autoSpeechLanguage;
    return resolveSpeechLanguage(
      setting: setting,
      script: script,
      deviceTag: PlatformDispatcher.instance.locale.toLanguageTag(),
      detected: auto && native != null ? await native.detectLanguage(script) : null,
      supported: auto && native != null ? await native.supportedLanguages() : const [],
    );
  }

  /// Chooses [source] for the current script: copies it into app storage, links it, and transcribes it.
  Future<void> choose(String source) async {
    final store = ref.read(narrationStoreProvider);
    final path = await store.import(source);
    final id = ref.read(studioProvider.notifier).currentId;
    if (id != null) await store.linkAudio(ref.read(prefsProvider), id, path);
    ref.read(audioPathProvider.notifier).set(path);
    await prepare(path);
  }

  /// Makes sure [path] has a transcript: from the cache, or by transcribing it. A language pack that is not on this
  /// device yet is downloaded first.
  Future<void> prepare(String path) async {
    final run = ++_run;
    final script = ref.read(studioProvider).script;
    state = NarrationPrepState(phase: NarrationPhase.transcribing, path: path);
    final store = ref.read(narrationStoreProvider);
    final transcriber = ref.read(fileTranscriberProvider);
    var language = '';
    TranscribeException? packError;
    try {
      language = await this.language(script);
      final cached = await store.cachedTranscript(path, language);
      if (run != _run) return;
      if (cached != null) {
        state = NarrationPrepState(phase: NarrationPhase.ready, path: path, progress: 1, transcript: cached, language: language);
        return;
      }
      state = NarrationPrepState(phase: NarrationPhase.transcribing, path: path, language: language);
      if (!await transcriber.isSupported()) {
        throw TranscribeException(TranscribeFailure.unavailable, _unsupportedMessage);
      }
      try {
        final pack = await ref.read(languagePackProvider.notifier).ensure(language);
        if (run != _run) return;
        if (pack == LanguagePackState.unsupported) {
          throw TranscribeException(
            TranscribeFailure.unavailable,
            "Narration isn't available for ${speechLanguageName(language)} on this device yet.",
          );
        }
      } on TranscribeException catch (e) {
        // No connection for the download: the older recogniser may still manage, so carry on and report this if not.
        if (e.failure != TranscribeFailure.download) rethrow;
        packError = e;
      }
      final words = await transcriber.transcribe(path, language, onProgress: (f) {
        if (run == _run) state = state.copyWith(progress: f);
      });
      if (run != _run) return;
      await store.saveTranscript(path, language, words);
      state = NarrationPrepState(phase: NarrationPhase.ready, path: path, progress: 1, transcript: words, language: language);
    } on TranscribeException catch (e) {
      if (run != _run || e.failure == TranscribeFailure.cancelled) return;
      final message = packError != null ? ref.read(languagePackProvider).note ?? e.message : e.message;
      state = NarrationPrepState(phase: NarrationPhase.failed, path: path, failure: e.failure, message: message, language: language);
    } catch (_) {
      if (run != _run) return;
      state = NarrationPrepState(
        phase: NarrationPhase.failed,
        path: path,
        failure: TranscribeFailure.failed,
        message: "Couldn't transcribe this recording. Choose another one.",
        language: language,
      );
    }
  }

  /// Fetches the language pack for the current script's language ahead of time, so choosing a recording is quick.
  Future<void> prefetchLanguage() async {
    try {
      final language = await this.language(ref.read(studioProvider).script);
      await ref.read(languagePackProvider.notifier).ensure(language);
    } catch (_) {
      // The pack's own status says what went wrong; choosing a recording tries again.
    }
  }

  /// Stops a transcription in progress and forgets the recording.
  Future<void> cancel() async {
    _run++;
    await ref.read(fileTranscriberProvider).cancel();
    ref.read(audioPathProvider.notifier).set(null);
    final id = ref.read(studioProvider.notifier).currentId;
    if (id != null) await ref.read(narrationStoreProvider).linkAudio(ref.read(prefsProvider), id, null);
    state = const NarrationPrepState();
  }

  void acceptLowMatch() => state = state.copyWith(lowMatchAccepted: true);

  /// Opens a script: restores the recording linked to it and prepares it.
  Future<void> restoreFor(String? scriptId) async {
    final store = ref.read(narrationStoreProvider);
    // An unsaved script has no link yet, so it keeps the recording chosen in this session.
    final linked = scriptId == null ? ref.read(audioPathProvider) : store.linkedAudio(ref.read(prefsProvider), scriptId);
    ref.read(audioPathProvider.notifier).set(linked);
    if (linked == null) {
      _run++;
      state = const NarrationPrepState();
    } else if (state.path != linked) {
      await prepare(linked);
    }
  }
}

const _unsupportedMessage = "This device can't transcribe a recording without the internet, so Narration isn't available here.";

final narrationPrepProvider = NotifierProvider<NarrationPrep, NarrationPrepState>(NarrationPrep.new);

/// The recording lined up with the current script; null until a transcript exists.
final narrationAlignmentProvider = Provider<AlignmentMap?>((ref) {
  final prep = ref.watch(narrationPrepProvider);
  final seconds = ref.watch(audioCheckProvider).asData?.value.seconds;
  if (prep.phase != NarrationPhase.ready || seconds == null) return null;
  final script = ref.watch(studioProvider.select((s) => s.script));
  return alignScript(scriptWords(script), prep.transcript, duration: seconds);
});

typedef Reader = R Function<R>(ProviderListenable<R> provider);

/// True when the recording does not seem to belong to the script and the reader has not chosen to go on.
bool narrationNeedsDecision(Reader read) {
  final map = read(narrationAlignmentProvider);
  final prep = read(narrationPrepProvider);
  return map != null && map.matchedFraction < narrationLowMatchBelow && !prep.lowMatchAccepted;
}

/// Why Start is unavailable in Narration mode, or null when it is available. Pass `ref.watch` while building and
/// `ref.read` anywhere else.
String? narrationStartBlocker(Reader read) {
  final check = read(audioCheckProvider);
  final prep = read(narrationPrepProvider);
  final path = read(audioPathProvider);
  if (path == null) return 'Choose a recording to start.';
  if (check.isLoading) return 'Start is available once the recording is checked.';
  if (check.hasError || check.requireValue.readiness != AudioReadiness.ready) return 'Choose another recording to start.';
  return switch (prep.phase) {
    NarrationPhase.idle || NarrationPhase.transcribing => 'Start is available once the recording is transcribed.',
    NarrationPhase.failed => 'Choose another recording to start.',
    NarrationPhase.ready => narrationNeedsDecision(read) ? 'Continue anyway or choose another recording to start.' : null,
  };
}
