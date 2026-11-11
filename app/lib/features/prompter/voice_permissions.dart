import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/permissions/permissions.dart';
import '../../services/providers.dart';
import 'prompter_controller.dart';
import 'voice_availability.dart';

/// What Voice mode needs on this device. The camera is not here: the Record screen asks for it when it opens.
enum VoicePermission { microphone, speech, dictation }

/// Where one [VoicePermission] stands.
enum AccessState {
  /// Not asked yet (on Android, also refused once and askable again): the row's button shows the system prompt.
  ask,
  granted,

  /// Refused, or (Dictation) a setting that is off: only Settings can change it now.
  settings,

  /// Blocked by Screen Time or device management; the reader can't change it here.
  restricted,
}

/// The rows this platform shows before their state is known: the microphone everywhere, speech recognition on Apple
/// (Android's recogniser needs only the microphone). Dictation is added on a Mac once it can be read.
List<VoicePermission> voicePermissionKinds() => [
  if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) VoicePermission.microphone,
  if (Platform.isIOS || Platform.isMacOS) VoicePermission.speech,
];

/// True once everything Voice mode needs here is on; false while the states are still being read.
bool voicePermissionsReady(Map<VoicePermission, AccessState>? states) =>
    states != null && states.values.every((s) => s == AccessState.granted);

/// The voice permissions checklist (onboarding's Voice step, Settings > Permissions). Reading never asks; [request]
/// asks for one permission only, so the reader decides what is shown and when.
class VoicePermissionsNotifier extends AsyncNotifier<Map<VoicePermission, AccessState>> {
  @override
  Future<Map<VoicePermission, AccessState>> build() => _read();

  /// Reads the states again (after a system prompt, or coming back from Settings).
  Future<void> refresh() async {
    final before = state.value?[VoicePermission.speech];
    final next = await _read();
    if (!ref.mounted) return;
    state = AsyncData(next);
    // iOS reads the speech answer for "is Voice available" once; a new answer must reach that too.
    if (before != null && before != next[VoicePermission.speech]) ref.invalidate(voiceAvailableProvider);
  }

  /// Shows the system prompt for [p] alone, then reads the states again.
  Future<void> request(VoicePermission p) async {
    final analytics = ref.read(analyticsProvider);
    try {
      switch (p) {
        case VoicePermission.microphone:
          if (Platform.isMacOS) {
            final granted = await ref.read(audioInputProvider).hasPermission();
            analytics.log('permission_result', {'permission': 'mic', 'granted': granted});
          } else {
            await requestPermission(Permission.microphone, 'mic', analytics);
          }
        case VoicePermission.speech:
          final native = ref.read(nativeSpeechProvider);
          if (native != null) {
            final granted = await native.isAvailable(); // asks the first time
            analytics.log('permission_result', {'permission': 'speech', 'granted': granted});
          }
        case VoicePermission.dictation:
          break; // a setting, not a permission: only Settings turns it on
      }
    } catch (_) {
      // The prompt couldn't be shown; the row keeps its state.
    }
    if (ref.mounted) await refresh();
  }

  /// The settings page where [p] is turned on: the matching System Settings pane on a Mac, this app's page elsewhere.
  Future<void> openSettings(VoicePermission p) async {
    if (!Platform.isMacOS) {
      await openAppSettings();
      return;
    }
    final url = switch (p) {
      VoicePermission.microphone => 'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
      VoicePermission.speech => 'x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition',
      VoicePermission.dictation => 'x-apple.systempreferences:com.apple.Keyboard-Settings.extension',
    };
    try {
      await Process.run('open', [url]);
    } catch (_) {}
  }

  Future<Map<VoicePermission, AccessState>> _read() async {
    final native = ref.read(nativeSpeechProvider);
    Map<String, String> readiness = const {};
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        readiness = await native?.readiness() ?? const {};
      } catch (_) {}
    }
    if (Platform.isMacOS) {
      final dictation = readiness['dictation'];
      return {
        VoicePermission.microphone: _apple(readiness['mic']),
        VoicePermission.speech: _apple(readiness['speech']),
        // "unknown": the setting can't be read here, so there is no row; Voice mode explains it if it is off.
        if (dictation == 'on' || dictation == 'off')
          VoicePermission.dictation: dictation == 'on' ? AccessState.granted : AccessState.settings,
      };
    }
    if (Platform.isIOS || Platform.isAndroid) {
      final mic = _handler(await Permission.microphone.status);
      return {
        VoicePermission.microphone: mic,
        if (Platform.isIOS) VoicePermission.speech: _apple(readiness['speech']),
      };
    }
    return const {};
  }

  static AccessState _apple(String? s) => switch (s) {
    'authorized' => AccessState.granted,
    'denied' => AccessState.settings,
    'restricted' => AccessState.restricted,
    _ => AccessState.ask,
  };

  static AccessState _handler(PermissionStatus s) {
    if (s.isGranted) return AccessState.granted;
    if (s.isRestricted) return AccessState.restricted;
    if (s.isPermanentlyDenied) return AccessState.settings;
    return AccessState.ask;
  }
}

final voicePermissionsProvider =
    AsyncNotifierProvider.autoDispose<VoicePermissionsNotifier, Map<VoicePermission, AccessState>>(
      VoicePermissionsNotifier.new,
    );
