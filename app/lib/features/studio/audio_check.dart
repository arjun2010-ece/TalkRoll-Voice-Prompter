import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers.dart';
import '../prompter/prompter_controller.dart';

/// Whether the chosen recording can be used: the file has to exist and load.
enum AudioReadiness { none, ready, unreadable }

class AudioCheck {
  const AudioCheck(this.readiness, [this.seconds]);
  final AudioReadiness readiness;

  /// Length of the recording, when it could be read.
  final double? seconds;
}

/// Re-runs whenever another recording is chosen. Loading is shown as `isLoading`, and Start stays
/// off until it finishes, so the prompter never opens in Narration mode without a ready recording.
final audioCheckProvider = FutureProvider.autoDispose<AudioCheck>((ref) async {
  final path = ref.watch(audioPathProvider);
  if (path == null) return const AudioCheck(AudioReadiness.none);
  if (!File(path).existsSync()) return const AudioCheck(AudioReadiness.unreadable);
  final clock = ref.read(referenceClockFactoryProvider)(audible: false);
  try {
    final seconds = await clock.load(path);
    return seconds > 0 ? AudioCheck(AudioReadiness.ready, seconds) : const AudioCheck(AudioReadiness.unreadable);
  } catch (_) {
    return const AudioCheck(AudioReadiness.unreadable);
  } finally {
    await clock.dispose();
  }
});

String formatSeconds(double s) {
  final t = s.round();
  return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}
