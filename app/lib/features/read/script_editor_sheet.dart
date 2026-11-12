import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/script/clean_script.dart';
import '../../services/platform.dart';
import '../../core/entitlements/entitlements.dart';
import '../../core/script/reading_time.dart';
import '../../services/providers.dart';
import '../pro/free_change_prompt.dart';
import '../pro/pro_state.dart';
import '../../ui/discard_changes_dialog.dart';

/// Edits the current script from a prompter screen. Returns true when the text
/// changed, so the caller can restart its prompter session on the new script.
/// On mobile the text is a draft until Save, which cleans and stores it; Cancel discards it.
Future<bool> showScriptEditor(BuildContext context, WidgetRef ref) async {
  final before = ref.read(studioProvider).script;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (_) => const _ScriptEditorSheet(),
  );
  if (!context.mounted) return false;
  if (ref.read(studioProvider).script == before) return false;
  await ref.read(studioProvider.notifier).start();
  return true;
}

class _ScriptEditorSheet extends ConsumerStatefulWidget {
  const _ScriptEditorSheet();
  @override
  ConsumerState<_ScriptEditorSheet> createState() => _ScriptEditorSheetState();
}

class _ScriptEditorSheetState extends ConsumerState<_ScriptEditorSheet> {
  late final _controller = TextEditingController(text: ref.read(studioProvider).script);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => isMobile && _controller.text != ref.read(studioProvider).script;

  void _edited(String text) {
    if (isMobile) return setState(() {});
    ref.read(studioProvider.notifier).setScript(text);
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final cleaned = cleanScript(_controller.text);
    // Free limits (word limit, big rewrite): a refused save keeps the sheet open with the draft.
    final gate = await checkSaveLimits(context, ref, cleaned);
    if (!gate.proceed || !mounted) return;
    await ref.read(studioProvider.notifier).commitScript(cleaned, rewriteConfirmed: gate.rewriteConfirmed);
    navigator.pop();
  }

  Future<void> _cancel(bool didPop) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    if (await confirmDiscardChanges(context)) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dirty = _dirty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) => _cancel(didPop),
      child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    // Free plan: the word limit shows before it is hit.
                    final limited = ref.watch(proProvider.select((p) => p.limitsApply));
                    final words = wordCount(_controller.text);
                    final over = limited && words > freeWordLimit;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Edit script', style: theme.textTheme.titleLarge),
                      if (limited)
                        Text(
                          '$words / $freeWordLimit words',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: over ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                            fontWeight: over ? FontWeight.w700 : null,
                          ),
                        ),
                    ]);
                  },
                ),
              ),
              if (isMobile) ...[
                TextButton(
                  onPressed: () => dirty ? _cancel(false) : Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: dirty && cleanScript(_controller.text).isNotEmpty ? _save : null,
                  child: const Text('Save'),
                ),
                const SizedBox(width: 8),
              ] else
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            ]),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 19, height: 1.5),
              onChanged: _edited,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Write or paste your script…',
                contentPadding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              ),
            ),
          ),
        ]),
      ),
      ),
    );
  }
}
