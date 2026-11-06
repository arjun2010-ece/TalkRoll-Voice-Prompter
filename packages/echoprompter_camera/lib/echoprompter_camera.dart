import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

enum CameraFacing { front, back }

/// Where Recorded-audio reference audio is heard while recording (§10.2).
enum ReferenceRoute { headphones, silent, speaker }

class CameraPreviewInfo {
  const CameraPreviewInfo({
    required this.textureId,
    required this.width,
    required this.height,
    required this.mirrored,
    this.quarterTurns = 0,
  });

  /// Flutter texture to show with a `Texture` widget.
  final int textureId;

  /// Upright (display-oriented) pixel size of the preview.
  final int width;
  final int height;

  /// True for the front camera: flip horizontally for a selfie-style preview.
  /// The recorded file is never mirrored.
  final bool mirrored;

  /// Clockwise quarter turns to apply for the display rotation (the texture is
  /// already sensor-upright); 0 in portrait and on iOS.
  final int quarterTurns;

  double get aspectRatio => width / height;
}

class RecordingResult {
  const RecordingResult(this.path, this.duration, this.reason, {this.narrationFailed = false});
  final String path;
  final Duration duration;

  /// iOS Narration mode: the narration could not be put into the video, so the file has no sound.
  final bool narrationFailed;

  /// user | interrupted | storage_full | error
  final String reason;
}

/// Camera preview + recording + a shared 16 kHz mono microphone stream.
///
/// One microphone capture feeds both the video file and the speech engine, so
/// Voice mode works while recording and audio/video stay in sync.
class EchoPrompterCamera {
  EchoPrompterCamera._();

  static const _channel = MethodChannel('com.echoprompter/camera');
  static const _audio = EventChannel('com.echoprompter/camera/audio');
  static const _events = EventChannel('com.echoprompter/camera/events');

  /// Microphone samples ([-1, 1], 16 kHz, mono). The mic is opened when the
  /// first listener subscribes and closed when the last one cancels (unless a
  /// recording is in progress).
  static Stream<Float32List> get audioSamples => _audio.receiveBroadcastStream().map((d) {
    // The codec doesn't align byte arrays, so copy to offset 0 before viewing as floats.
    final bytes = Uint8List.fromList(d as Uint8List);
    return bytes.buffer.asFloat32List(0, bytes.lengthInBytes ~/ 4);
  });

  /// `{type: interrupted|storage_full|orientation|error, ...}`
  static Stream<Map<Object?, Object?>> get events =>
      _events.receiveBroadcastStream().map((e) => (e as Map).cast<Object?, Object?>());

  static Future<CameraPreviewInfo> startPreview(CameraFacing facing) async {
    final m = (await _channel.invokeMapMethod<String, Object?>(
      'startPreview',
      {'facing': facing.name},
    ))!;
    return CameraPreviewInfo(
      textureId: m['textureId']! as int,
      width: m['width']! as int,
      height: m['height']! as int,
      mirrored: m['mirrored']! as bool,
      quarterTurns: (m['quarterTurns'] as int?) ?? 0,
    );
  }

  static Future<void> stopPreview() => _channel.invokeMethod('stopPreview');

  /// Switches front/back. Not allowed while recording.
  static Future<CameraPreviewInfo> switchCamera(CameraFacing facing) async {
    await stopPreview();
    return startPreview(facing);
  }

  /// Locks the output orientation for the file. Called when recording starts
  /// and released on stop; [landscape] is the current UI orientation.
  ///
  /// iOS Narration mode: [narrationPath] is the file that plays during the take. The take is filmed without the
  /// microphone, and [narrationTick] tells the camera which part of the file is playing so [stopRecording] can put
  /// that part of the file itself into the video.
  static Future<void> startRecording({
    required bool landscape,
    int height = 1080,
    bool hevc = false,
    String? narrationPath,
  }) => _channel.invokeMethod('startRecording', {
    'landscape': landscape,
    'height': height,
    'hevc': hevc,
    'narrationPath': ?narrationPath,
  });

  /// iOS Narration mode: where the narration file is now and whether it is playing. Call often during a take.
  static Future<void> narrationTick({required Duration position, required bool playing}) =>
      _channel.invokeMethod('narrationTick', {'positionMs': position.inMilliseconds, 'playing': playing});

  /// Pauses/resumes the take without ending the file.
  static Future<void> pauseRecording() => _channel.invokeMethod('pauseRecording');
  static Future<void> resumeRecording() => _channel.invokeMethod('resumeRecording');

  static Future<RecordingResult> stopRecording({String reason = 'user'}) async {
    final m = (await _channel.invokeMapMethod<String, Object?>(
      'stopRecording',
      {'reason': reason},
    ))!;
    return RecordingResult(
      m['path']! as String,
      Duration(milliseconds: m['durationMs']! as int),
      m['reason']! as String,
      narrationFailed: (m['narrationFailed'] as bool?) ?? false,
    );
  }

  /// Joins video files, in the order given, into one video and returns its path (Android: Media3 Transformer; iOS:
  /// AVMutableComposition and AVAssetExportSession). The files are left as they are.
  static Future<String> joinClips(List<String> paths) async =>
      (await _channel.invokeMethod<String>('joinClips', {'paths': paths}))!;

  /// Saves to Photos (iOS, add-only) or MediaStore DCIM/EchoPrompter (Android).
  static Future<void> saveToGallery(String path) =>
      _channel.invokeMethod('saveToGallery', {'path': path});

  static Future<bool> get headphonesConnected async =>
      (await _channel.invokeMethod<bool>('headphonesConnected')) ?? false;

  /// Android: whether the microphone may be a connected headset (USB, wired or Bluetooth SCO) instead of
  /// the built-in one. Voice mode wants the headset; Audio mode must hear the speaker, so it does not.
  static Future<void> setHeadsetInput(bool headset) =>
      _channel.invokeMethod('setInputPreference', {'headset': headset});

  /// Routes reference-audio playback for a take. Keeps the input on the
  /// built-in microphone so Bluetooth output keeps full quality.
  static Future<void> setReferenceRoute(ReferenceRoute route) =>
      _channel.invokeMethod('setReferenceRoute', {'route': route.name});
}
