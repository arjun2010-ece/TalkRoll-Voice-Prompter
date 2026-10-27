import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ui/adaptive.dart';

/// Shown when the microphone is refused: Voice and Audio follow what is said, so they need it. Offers the
/// app's system settings, or carrying on without it.
Future<void> showMicrophoneDenied(BuildContext context) => showAdaptiveDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog.adaptive(
    title: const Text('Microphone access is off'),
    content: Text(
      isApple
          ? 'Voice mode follows what you say, so it needs the microphone. Turn it on in Settings, or use Normal mode.'
          : 'Voice mode needs the microphone. Turn it on in the app settings, or use Normal mode.',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Not now')),
      TextButton(
        onPressed: () {
          Navigator.of(ctx).pop();
          openAppSettings();
        },
        child: const Text('Open Settings'),
      ),
    ],
  ),
);
