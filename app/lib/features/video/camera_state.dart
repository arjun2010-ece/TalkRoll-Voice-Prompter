import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the next Start in Voice or Audio mode records video ("Voice + camera") or only reads ("Voice only").
/// Kept for this run only: the app opens voice-only every time.
class CameraOnNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool on) => state = on;
}

final cameraOnProvider = NotifierProvider<CameraOnNotifier, bool>(CameraOnNotifier.new);
