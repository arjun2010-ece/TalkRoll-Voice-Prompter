import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/narration/alignment.dart';

/// Why a recording could not be transcribed.
enum TranscribeFailure {
  /// Speech recognition access was refused.
  denied,

  /// This device has no on-device recogniser for the language (or at all), so nothing is sent anywhere.
  unavailable,

  /// The reader cancelled.
  cancelled,

  /// The language pack for the recording's language could not be downloaded (no connection, for one).
  download,

  /// The file could not be read or recognised.
  failed,
}

/// Whether the language's speech pack is on this device (Apple's newer engines manage packs of their own).
enum LanguagePackState {
  /// Installed, or the platform has no separate pack to manage.
  ready,

  /// Not installed yet; one download (from Apple, to this device) makes the language work offline from then on.
  needsDownload,

  /// Neither of Apple's engines has this language.
  unsupported,
}

class TranscribeException implements Exception {
  TranscribeException(this.failure, this.message);
  final TranscribeFailure failure;
  final String message;
  @override
  String toString() => message;
}

/// Turns a recording into words with times, on this device: Apple's speech recogniser on macOS, iOS and iPadOS.
/// Nothing leaves the device; where the device cannot do that, [transcribe] throws [TranscribeFailure.unavailable].
class FileTranscriber {
  FileTranscriber() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') _progress?.call((call.arguments as num).toDouble().clamp(0.0, 1.0));
      if (call.method == 'packProgress') {
        final m = call.arguments as Map<Object?, Object?>;
        onPackProgress?.call(m['language']! as String, (m['fraction']! as num).toDouble().clamp(0.0, 1.0));
      }
    });
  }

  /// Told how much of a language pack has downloaded, 0 to 1.
  void Function(String language, double fraction)? onPackProgress;

  static const _channel = MethodChannel('com.echoprompter/transcribe');
  void Function(double fraction)? _progress;

  /// Whether this platform has a transcriber at all.
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The words of [path] in [language] (`en-US`, ...), each with its start and end in seconds. [onProgress] reports
  /// how much of the recording is done, 0 to 1.
  Future<List<TimedWord>> transcribe(String path, String language, {void Function(double fraction)? onProgress}) async {
    _progress = onProgress;
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('transcribe', {'path': path, 'language': language});
      return [
        for (final m in raw ?? const <Map<Object?, Object?>>[])
          TimedWord(m['w']! as String, (m['s']! as num).toDouble(), (m['e']! as num).toDouble()),
      ];
    } on PlatformException catch (e) {
      throw TranscribeException(switch (e.code) {
        'denied' => TranscribeFailure.denied,
        'unavailable' => TranscribeFailure.unavailable,
        'cancelled' => TranscribeFailure.cancelled,
        _ => TranscribeFailure.failed,
      }, e.message ?? e.code);
    } on MissingPluginException {
      throw TranscribeException(TranscribeFailure.unavailable, 'This device cannot transcribe a recording yet.');
    } finally {
      _progress = null;
    }
  }

  /// Whether the pack for [language] is here. With [download] a missing pack is downloaded first ([onPackProgress]
  /// reports it) and this throws [TranscribeFailure.download] if that fails. Platforms without packs say [ready].
  Future<LanguagePackState> languagePack(String language, {bool download = false}) async {
    try {
      return switch (await _channel.invokeMethod<String>('languagePack', {'language': language, 'download': download})) {
        'needsDownload' => LanguagePackState.needsDownload,
        'unsupported' => LanguagePackState.unsupported,
        _ => LanguagePackState.ready,
      };
    } on PlatformException catch (e) {
      throw TranscribeException(TranscribeFailure.download, e.message ?? e.code);
    } on MissingPluginException {
      return LanguagePackState.ready;
    }
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // Nothing is running.
    }
  }
}
