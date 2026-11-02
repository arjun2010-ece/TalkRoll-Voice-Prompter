import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../speech/speech_languages.dart';
import 'file_transcriber.dart';

final fileTranscriberProvider = Provider<FileTranscriber>((_) => FileTranscriber());

enum LanguagePackPhase { idle, downloading, unsupported, failed }

class LanguagePackStatus {
  const LanguagePackStatus({this.language = '', this.phase = LanguagePackPhase.idle, this.progress = 0, this.message = ''});
  final String language;
  final LanguagePackPhase phase;

  /// How much of the download is done, 0 to 1.
  final double progress;
  final String message;

  /// What to tell the reader about the pack, or null when there is nothing to say.
  String? get note {
    final name = speechLanguageName(language);
    return switch (phase) {
      // Apple does not always report how far a pack has come, so a percentage is shown only when there is one.
      LanguagePackPhase.downloading => 'Downloading the $name language pack (one time)…${progress > 0 ? ' ${(progress * 100).round()}%' : ''}',
      LanguagePackPhase.unsupported => "Narration isn't available for $name on this device yet.",
      LanguagePackPhase.failed => message,
      LanguagePackPhase.idle => null,
    };
  }
}

/// Finds out whether the speech pack for a language is on this device and, once the reader has agreed, downloads it
/// (from Apple, once; after that the language works offline). Narration and Voice mode share the packs: a language
/// downloaded in one is ready in the other. Nothing here downloads on its own: [ensure] does so only for a language
/// the reader approved with [approve] (the Download button on the Narration card, the download question when Voice
/// starts).
class LanguagePackNotifier extends Notifier<LanguagePackStatus> {
  final Map<String, Future<LanguagePackState>> _running = {};
  final Set<String> _approved = {};

  @override
  LanguagePackStatus build() => const LanguagePackStatus();

  /// The reader agreed to download the pack for [language].
  void approve(String language) => _approved.add(language);

  /// Where the pack for [language] is, without downloading anything.
  Future<LanguagePackState> check(String language, {bool voice = false}) =>
      ref.read(fileTranscriberProvider).languagePack(language, voice: voice);

  /// The state of the pack for [language]: [LanguagePackState.ready] once it is here (downloaded first if the reader
  /// approved it), [LanguagePackState.needsDownload] when it is missing and was not approved (nothing is downloaded),
  /// or [LanguagePackState.unsupported]. Throws a [TranscribeException] with [TranscribeFailure.download] when an
  /// approved download fails.
  Future<LanguagePackState> ensure(String language, {bool voice = false}) =>
      _running['$voice$language'] ??= _ensure(language, voice).whenComplete(() {
        _running.remove('$voice$language'); // a block, so the removed future is not returned and waited on by itself
      });

  Future<LanguagePackState> _ensure(String language, bool voice) async {
    final transcriber = ref.read(fileTranscriberProvider);
    var pack = await transcriber.languagePack(language, voice: voice);
    if (pack == LanguagePackState.unsupported) {
      state = LanguagePackStatus(language: language, phase: LanguagePackPhase.unsupported);
      return pack;
    }
    if (pack == LanguagePackState.ready) {
      if (state.language == language) state = const LanguagePackStatus();
      return pack;
    }
    if (!_approved.contains(language)) return pack;
    state = LanguagePackStatus(language: language, phase: LanguagePackPhase.downloading);
    transcriber.onPackProgress = (l, f) {
      if (l == language) state = LanguagePackStatus(language: language, phase: LanguagePackPhase.downloading, progress: f);
    };
    try {
      pack = await transcriber.languagePack(language, download: true, voice: voice);
      state = const LanguagePackStatus();
      return pack;
    } on TranscribeException {
      state = LanguagePackStatus(
        language: language,
        phase: LanguagePackPhase.failed,
        message: "Couldn't download the ${speechLanguageName(language)} language pack. Connect to the internet once, then try again.",
      );
      rethrow;
    } finally {
      transcriber.onPackProgress = null;
    }
  }
}

final languagePackProvider = NotifierProvider<LanguagePackNotifier, LanguagePackStatus>(LanguagePackNotifier.new);
