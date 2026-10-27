import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prompter_controller.dart';

/// Whether this device has a speech recogniser Voice and Audio mode can use. It asks the same question Play does,
/// so the mode choice can say so up front instead of failing after Play. Treated as available until the answer
/// arrives.
final voiceAvailableProvider = FutureProvider<bool>((ref) async {
  final native = ref.read(nativeSpeechProvider);
  if (native == null) return false;
  try {
    return await native.isAvailable();
  } catch (_) {
    return false;
  }
});
