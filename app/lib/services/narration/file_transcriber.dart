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

  /// The file could not be read or recognised.
  failed,
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
    });
  }

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

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // Nothing is running.
    }
  }
}
