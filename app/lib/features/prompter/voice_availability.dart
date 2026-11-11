import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prompter_controller.dart';

/// Whether this device has a speech recogniser Voice and Audio mode can use. It asks the same question Play does,
/// so the mode choice can say so up front instead of failing after Play. Treated as available until the answer
/// arrives.
///
/// iOS reads the speech permission without asking (asking is what its `isAvailable` does): the question is left to the
/// Voice step's checklist or the first Voice Play, not the moment a screen opens. Not asked yet counts as available.
final voiceAvailableProvider = FutureProvider<bool>((ref) async {
  final native = ref.read(nativeSpeechProvider);
  if (native == null) return false;
  try {
    if (Platform.isIOS) {
      final speech = (await native.readiness())['speech'];
      return speech != 'denied' && speech != 'restricted';
    }
    return await native.isAvailable();
  } catch (_) {
    return false;
  }
});
