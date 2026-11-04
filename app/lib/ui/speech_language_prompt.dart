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
/// "Different Language Detected"). Apple reads the script with its own language recogniser; Android has its own check
/// below. Other platforms are never asked.
/// "Use" makes the detected language (the device's own region of it) the setting; closing the dialog keeps it.
Future<void> confirmSpeechLanguage(BuildContext context, WidgetRef ref, String script) async {
  // Android has its own check (its own language detector); the Apple path below is unchanged.
  if (Platform.isAndroid) return _confirmOnAndroid(context, ref, script);
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

/// Android: the same question, with the script read by Android's text classifier (or common words when it can't
/// tell). Without it, a language fixed for one script (say Spanish) was silently used for every later script, and an
/// English script then never followed the voice. Kept apart from the Apple path so neither can change the other.
Future<void> _confirmOnAndroid(BuildContext context, WidgetRef ref, String script) async {
  final settings = ref.read(settingsProvider);
  if (settings.mode == PromptControlMode.normal || settings.speechLanguage == autoSpeechLanguage) return;
  // A few words are too little to tell a language from.
  if (spokenWords(script).length < 4) return;
  final key = '${settings.speechLanguage}|${script.hashCode}';
  if (_kept.contains(key)) return;
  final native = ref.read(nativeSpeechProvider);
  if (native == null) return;
  final found = androidScriptLanguage(script, await native.detectLanguage(script));
  if (found == null || sameSpeechLanguage(found, settings.speechLanguage)) return;
  // The variant Automatic would use for this script on this phone (its region, its recogniser's list).
  final use = await speechLanguageForScript(native: native, setting: autoSpeechLanguage, script: script);
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
