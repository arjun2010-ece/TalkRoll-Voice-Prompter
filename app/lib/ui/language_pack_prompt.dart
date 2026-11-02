import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/prompt_settings.dart';
import '../features/studio/narration_prep.dart';
import '../services/narration/file_transcriber.dart';
import '../services/providers.dart';
import '../services/speech/speech_languages.dart';

/// Before Voice mode starts on Apple: when the language it will listen to needs an Apple speech pack that is not on this
/// device yet, asks before downloading it. The pack comes from Apple once, and the language then works without a
/// connection. Returns false when the reader says "Not now" or the download fails, so Start does not go on; true when
/// there is nothing to download or the pack is now here. Narration asks on its own card instead.
Future<bool> confirmLanguagePack(BuildContext context, WidgetRef ref, String script) async {
  if (!Platform.isMacOS && !Platform.isIOS) return true;
  if (ref.read(settingsProvider).mode != PromptControlMode.voice) return true;
  final language = await ref.read(narrationPrepProvider.notifier).language(script);
  // English ships with the system.
  if (language.toLowerCase().startsWith('en')) return true;
  final LanguagePackState pack;
  try {
    pack = await ref.read(languagePackProvider.notifier).check(language, voice: true);
  } catch (_) {
    return true;
  }
  if (pack != LanguagePackState.needsDownload || !context.mounted) return pack != LanguagePackState.needsDownload;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LanguagePackDialog(language: language),
      ) ??
      false;
}

enum _Stage { ask, downloading, failed }

class _LanguagePackDialog extends ConsumerStatefulWidget {
  const _LanguagePackDialog({required this.language});
  final String language;

  @override
  ConsumerState<_LanguagePackDialog> createState() => _LanguagePackDialogState();
}

class _LanguagePackDialogState extends ConsumerState<_LanguagePackDialog> {
  _Stage _stage = _Stage.ask;

  String get _name => speechLanguageName(widget.language);

  Future<void> _download() async {
    setState(() => _stage = _Stage.downloading);
    final packs = ref.read(languagePackProvider.notifier);
    packs.approve(widget.language);
    try {
      final pack = await packs.ensure(widget.language, voice: true);
      if (!mounted) return;
      if (pack == LanguagePackState.needsDownload) {
        setState(() => _stage = _Stage.failed);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.ask:
        return AlertDialog(
          icon: const Icon(Icons.download_rounded, size: 32),
          title: Text('Download the $_name language pack?'),
          content: Text(
            "Voice mode needs Apple's $_name speech pack on this device. It downloads once from Apple, so it needs an "
            "internet connection now, and then works without one.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
            FilledButton(onPressed: _download, child: const Text('Download')),
          ],
        );
      case _Stage.downloading:
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text('Downloading the $_name language pack…'),
            content: const Row(children: [
              SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3)),
              SizedBox(width: 16),
              Expanded(child: Text('One time only. Voice mode starts when it is done.')),
            ]),
          ),
        );
      case _Stage.failed:
        return AlertDialog(
          icon: const Icon(Icons.cloud_off_rounded, size: 32),
          title: const Text("Couldn't download it"),
          content: Text(
            "The $_name language pack didn't download. Connect to the internet once and try again, or use Auto-scroll mode, "
            "which needs nothing.",
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('OK'))],
        );
    }
  }
}
