import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/prompter/prompter_controller.dart';
import '../services/providers.dart';
import '../services/speech/speech_languages.dart';

/// The Settings row that shows the language Voice and Narration mode listens for and opens the list to change it.
class SpeechLanguageRow extends ConsumerWidget {
  const SpeechLanguageRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(settingsProvider.select((s) => s.speechLanguage));
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return ListTile(
      title: const Text('Voice language'),
      subtitle: Text(
        current == autoSpeechLanguage
            ? 'Automatic: taken from your script (English if it can\'t tell).'
            : 'Voice and Narration mode listen for ${speechLanguageName(current)}.',
        style: muted,
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(speechLanguageName(current)),
        const Icon(Icons.chevron_right),
      ]),
      onTap: () async {
        final picked = await showDialog<String>(context: context, builder: (_) => _LanguageDialog(current: current));
        if (picked != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(speechLanguage: picked));
      },
    );
  }
}

/// "How to read" (and the desktop inspector): the language Voice and Narration mode will listen for with [script],
/// and Change to pick another. A wrong automatic guess (a very short script, two close languages) is seen and fixed
/// before Start rather than discovered mid-take. It is the same setting as Settings > Voice language.
class SpeechLanguageLine extends ConsumerStatefulWidget {
  const SpeechLanguageLine({super.key, required this.script, this.dense = false});

  final String script;

  /// The desktop inspector's smaller type.
  final bool dense;

  @override
  ConsumerState<SpeechLanguageLine> createState() => _SpeechLanguageLineState();
}

class _SpeechLanguageLineState extends ConsumerState<SpeechLanguageLine> {
  Future<String>? _language;
  (String, String)? _for;

  @override
  Widget build(BuildContext context) {
    final setting = ref.watch(settingsProvider.select((s) => s.speechLanguage));
    // Worked out again only when the setting or the script changes, not on every rebuild.
    if (_for != (setting, widget.script)) {
      _for = (setting, widget.script);
      _language = speechLanguageForScript(native: ref.read(nativeSpeechProvider), setting: setting, script: widget.script);
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = widget.dense ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge;
    final muted = (widget.dense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)?.copyWith(color: scheme.onSurfaceVariant);
    return Row(children: [
      Icon(Icons.translate_rounded, size: widget.dense ? 18 : 20, color: scheme.onSurfaceVariant),
      SizedBox(width: widget.dense ? 8 : 12),
      Expanded(
        child: FutureBuilder<String>(
          future: _language,
          builder: (context, snap) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(snap.hasData ? 'Listening for ${speechLanguageName(snap.data!)}' : 'Checking the language…', style: title),
            Text(setting == autoSpeechLanguage ? 'Automatic, from your script' : 'Chosen by you', style: muted),
          ]),
        ),
      ),
      TextButton(
        onPressed: () async {
          final picked = await showDialog<String>(context: context, builder: (_) => _LanguageDialog(current: setting));
          if (picked != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(speechLanguage: picked));
        },
        child: const Text('Change'),
      ),
    ]);
  }
}

class _LanguageDialog extends ConsumerStatefulWidget {
  const _LanguageDialog({required this.current});
  final String current;

  @override
  ConsumerState<_LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends ConsumerState<_LanguageDialog> {
  String _query = '';
  final List<SpeechLanguage> _available = speechLanguages;
  List<String> _supported = const [];

  @override
  void initState() {
    super.initState();
    _loadSupported();
  }

  /// Every language is offered. The ones this device's recogniser doesn't report (Android reports only those it can
  /// recognise offline) are marked, since they may need the internet or a download.
  Future<void> _loadSupported() async {
    final native = ref.read(nativeSpeechProvider);
    if (native == null) return;
    final supported = await native.supportedLanguages();
    if (!mounted) return;
    setState(() => _supported = supported);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = [for (final l in _available) if (q.isEmpty || l.name.toLowerCase().contains(q) || l.tag.toLowerCase().contains(q)) l];
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search languages', isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (q.isEmpty) _tile(autoSpeechLanguage, 'Automatic', 'From the script'),
              for (final l in shown)
                _tile(l.tag, l.name, speechLanguageListed(l.tag, _supported) ? l.tag : '${l.tag} · may need the internet or a download'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Some languages may use your device\'s speech service over the internet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tile(String tag, String name, String sub) => ListTile(
    dense: true,
    title: Text(name),
    subtitle: Text(sub),
    trailing: tag == widget.current ? const Icon(Icons.check) : null,
    onTap: () => Navigator.of(context).pop(tag),
  );
}
