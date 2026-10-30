import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/script/text.dart';
import '../core/settings/prompt_settings.dart';
import '../features/prompter/prompter_controller.dart';
import '../services/providers.dart';
import '../services/speech/speech_languages.dart';

/// Scripts the reader chose to keep their language for, so Start doesn't ask again for the same text.
final _kept = <String>{};

/// When the reader fixed a voice language and the script is in another, asks which to use (the macOS reference's
/// "Different Language Detected"). Apple only: it needs Apple's language recogniser, so nothing else is ever asked.
/// "Use" makes the detected language (the device's own region of it) the setting; closing the dialog keeps it.
Future<void> confirmSpeechLanguage(BuildContext context, WidgetRef ref, String script) async {
  if (!Platform.isMacOS && !Platform.isIOS) return;
  final settings = ref.read(settingsProvider);
  if (settings.mode == PromptControlMode.normal || settings.speechLanguage == autoSpeechLanguage) return;
  // A few words are too little to tell a language from.
  if (spokenWords(script).length < 4) return;
  final key = '${settings.speechLanguage}|${script.hashCode}';
  if (_kept.contains(key)) return;
  final native = ref.read(nativeSpeechProvider);
  if (native == null) return;
  final code = await native.detectLanguage(script);
  final found = code == null ? null : languageFromNaturalLanguage(code);
  if (found == null || sameSpeechLanguage(found, settings.speechLanguage)) return;
  final use = resolveSpeechLanguage(
    setting: autoSpeechLanguage,
    script: script,
    deviceTag: '',
    detected: code,
    supported: await native.supportedLanguages(),
  );
  if (!context.mounted) return;
  final useName = speechLanguageName(use);
  final keepName = speechLanguageName(settings.speechLanguage);
  final useIt = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.translate_rounded, size: 32),
      title: const Text('Different Language Detected'),
      content: Text(
        'This script looks like $useName. Your voice language is set to $keepName. '
        'Which language would you like to use? Your choice will be kept for future scripts.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Keep $keepName')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Use $useName')),
      ],
    ),
  );
  if (useIt == true) {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(speechLanguage: use));
  } else {
    _kept.add(key);
  }
}
