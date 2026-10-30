import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/prompter/prompter_controller.dart';
import '../services/providers.dart';
import '../services/speech/speech_languages.dart';

/// The Settings row that shows the language Voice and Audio mode listens for and opens the list to change it.
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
            : 'Voice and Audio mode listen for ${speechLanguageName(current)}.',
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

class _LanguageDialog extends ConsumerStatefulWidget {
  const _LanguageDialog({required this.current});
  final String current;

  @override
  ConsumerState<_LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends ConsumerState<_LanguageDialog> {
  String _query = '';
  List<SpeechLanguage> _available = speechLanguages;

  @override
  void initState() {
    super.initState();
    _loadSupported();
  }

  /// Narrows the list to the languages this device's recogniser reports (all of them when it reports none).
  Future<void> _loadSupported() async {
    final native = ref.read(nativeSpeechProvider);
    if (native == null) return;
    final supported = await native.supportedLanguages();
    if (!mounted) return;
    setState(() {
      _available = supportedSpeechLanguages(supported);
      // A language chosen earlier stays visible even if this device no longer lists it.
      final c = widget.current;
      if (c != autoSpeechLanguage && !_available.any((l) => l.tag == c)) {
        _available = [...speechLanguages.where((l) => l.tag == c), ..._available];
      }
    });
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
              for (final l in shown) _tile(l.tag, l.name, l.tag),
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
