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

/// Makes sure the speech pack for a language is on this device, downloading it once when it is not. Narration and
/// Voice mode both ask before they listen, so a new language is fetched when it is first wanted and works offline
/// afterwards.
class LanguagePackNotifier extends Notifier<LanguagePackStatus> {
  final Map<String, Future<LanguagePackState>> _running = {};

  @override
  LanguagePackStatus build() => const LanguagePackStatus();

  /// The state of the pack for [language] once it is ready or known to be unavailable. Throws a
  /// [TranscribeException] with [TranscribeFailure.download] when the download fails.
  Future<LanguagePackState> ensure(String language) => _running[language] ??= _ensure(language).whenComplete(() {
    _running.remove(language); // a block, so the removed future is not returned and waited on by itself
  });

  Future<LanguagePackState> _ensure(String language) async {
    final transcriber = ref.read(fileTranscriberProvider);
    var pack = await transcriber.languagePack(language);
    if (pack == LanguagePackState.unsupported) {
      state = LanguagePackStatus(language: language, phase: LanguagePackPhase.unsupported);
      return pack;
    }
    if (pack == LanguagePackState.ready) {
      if (state.language == language) state = const LanguagePackStatus();
      return pack;
    }
    state = LanguagePackStatus(language: language, phase: LanguagePackPhase.downloading);
    transcriber.onPackProgress = (l, f) {
      if (l == language) state = LanguagePackStatus(language: language, phase: LanguagePackPhase.downloading, progress: f);
    };
    try {
      pack = await transcriber.languagePack(language, download: true);
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
