import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/script/sections.dart';
import '../../services/platform.dart';
import '../prompter/cue_widgets.dart';

/// The "Insert Action Cue" button: purple, so cues read as a different kind of thing from sections.
class ActionCueButton extends StatelessWidget {
  const ActionCueButton({super.key, required this.onPressed, this.height = 40, this.dense = false});

  final VoidCallback onPressed;
  final double height;

  /// The desktop toolbar's small button.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.ads_click, size: dense ? 16 : 18),
      label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Insert Action Cue', maxLines: 1, softWrap: false)),
      style: OutlinedButton.styleFrom(
        backgroundColor: cueIconFill,
        foregroundColor: Colors.white,
        side: const BorderSide(color: cuePurple),
        minimumSize: Size(0, height),
        padding: dense ? null : const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: dense ? VisualDensity.compact : null,
        shape: dense ? null : const StadiumBorder(),
      ),
    );
  }
}

/// "Insert Action Cue": asks for the cue's text and whether it holds the prompter, then puts it in the script on a
/// line of its own at the caret. With the caret on an existing cue line, the same button edits that cue, or deletes it.
/// A bottom sheet on phones and tablets, a panel on desktop. Returns true if the script changed.
Future<bool> insertActionCue(BuildContext context, TextEditingController controller, {String? continueShortcut}) async {
  final text = controller.text;
  final sel = controller.selection;
  final at = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
  final lineStart = at == 0 ? 0 : text.lastIndexOf('\n', at - 1) + 1;
  final newline = text.indexOf('\n', at);
  final lineEnd = newline < 0 ? text.length : newline;
  final onCue = isActionCueLine(text.substring(lineStart, lineEnd));
  ActionCue? existing;
  if (onCue) {
    for (final c in actionCues(text)) {
      if (c.start >= lineStart && c.start < lineEnd) existing = c;
    }
  }
  Widget form(BuildContext _) => _ActionCueForm(
        initialText: existing?.text ?? '',
        initialHold: existing?.hold ?? false,
        editing: existing != null,
        sheet: isMobile,
        continueShortcut: continueShortcut,
      );
  final result = isMobile
      ? await showModalBottomSheet<_CueResult>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          builder: form,
        )
      : await showDialog<_CueResult>(
          context: context,
          builder: (c) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 340), child: form(c)),
          ),
        );
  if (result == null) return false;
  if (existing != null) {
    // Replace the line, or remove it (and its line break) when deleting.
    final from = existing.start, to = existing.end;
    if (result.delete) {
      final end = to < text.length ? to + 1 : to;
      controller.value = TextEditingValue(text: text.replaceRange(from, end, ''), selection: TextSelection.collapsed(offset: from.clamp(0, text.length - (end - from))));
    } else {
      final line = actionCueLine(result.text, hold: result.hold);
      controller.value = TextEditingValue(text: text.replaceRange(from, to, line), selection: TextSelection.collapsed(offset: from + line.length));
    }
    return true;
  }
  final lead = at > 0 && text[at - 1] != '\n' ? '\n' : '';
  final inserted = '$lead${actionCueLine(result.text, hold: result.hold)}\n';
  controller.value = TextEditingValue(
    text: text.replaceRange(at, sel.isValid ? sel.end.clamp(0, text.length) : at, inserted),
    selection: TextSelection.collapsed(offset: at + inserted.length),
  );
  return true;
}

class _CueResult {
  const _CueResult(this.text, this.hold, {this.delete = false});
  final String text;
  final bool hold;
  final bool delete;
}

class _ActionCueForm extends StatefulWidget {
  const _ActionCueForm({required this.initialText, required this.initialHold, required this.editing, required this.sheet, this.continueShortcut});

  final String initialText;
  final bool initialHold;
  final bool editing;

  /// A phone or tablet bottom sheet (larger type and buttons) rather than the desktop panel.
  final bool sheet;
  final String? continueShortcut;

  @override
  State<_ActionCueForm> createState() => _ActionCueFormState();
}

class _ActionCueFormState extends State<_ActionCueForm> {
  late final _text = TextEditingController(text: widget.initialText);
  late bool _hold = widget.initialHold;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _value => _text.text.replaceAll(RegExp(r'[{}\r\n]+'), ' ').trim();

  void _done() {
    if (_value.isNotEmpty) Navigator.pop(context, _CueResult(_value, _hold));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sheet = widget.sheet;
    final muted = TextStyle(fontSize: sheet ? 13 : 11, height: sheet ? 1.4 : 1.35, color: scheme.onSurfaceVariant);
    final gap = sheet ? 18.0 : 12.0;
    final holdNote = sheet
        ? 'The prompter waits here. Use it for installs, page loads and builds.'
        : widget.continueShortcut != null
            ? 'Waits for ${widget.continueShortcut} or the Continue button.'
            : 'Waits for the Continue button.';

    final content = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(widget.editing ? 'Edit Action Cue' : 'Insert Action Cue', style: TextStyle(fontSize: sheet ? 22 : 15, fontWeight: FontWeight.w600))),
        if (sheet) IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      ]),
      SizedBox(height: sheet ? 4 : 8),
      Text('Something you do, not say. It is never read aloud or matched to your voice.', style: muted.copyWith(fontSize: sheet ? 14 : 12)),
      SizedBox(height: gap),
      Text('What should you do?', style: TextStyle(fontSize: sheet ? 13 : 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 6),
      TextField(
        controller: _text,
        autofocus: true,
        maxLength: maxActionCueLength,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[{}]'))],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _done(),
        style: TextStyle(fontSize: sheet ? 17 : 13),
        decoration: InputDecoration(
          isDense: !sheet,
          counterText: '',
          hintText: 'Type npm install',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(sheet ? 14 : 6)),
        ),
      ),
      SizedBox(height: gap),
      DecoratedBox(
        decoration: BoxDecoration(
          color: sheet ? scheme.surfaceContainerHighest : null,
          borderRadius: BorderRadius.circular(12),
          border: sheet ? Border.all(color: scheme.outlineVariant) : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: sheet ? 14 : 0, vertical: sheet ? 4 : 0),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hold until I continue', style: TextStyle(fontSize: sheet ? 16 : 13)),
                const SizedBox(height: 2),
                Text(holdNote, style: muted),
              ]),
            ),
            const SizedBox(width: 10),
            Switch(value: _hold, onChanged: (v) => setState(() => _hold = v)),
          ]),
        ),
      ),
      SizedBox(height: gap),
      Text('PREVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      ListenableBuilder(
        listenable: _text,
        builder: (context, _) => SizedBox(
          height: CueChip.height * (sheet ? 1 : 0.8),
          child: CueChip(text: _value.isEmpty ? 'Type npm install' : _value, hold: _hold, scale: sheet ? 1 : 0.8),
        ),
      ),
      SizedBox(height: sheet ? 22 : 16),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (widget.editing)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => Navigator.pop(context, const _CueResult('', false, delete: true)),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: const Text('Delete'),
            ),
          ),
        if (sheet) ...[
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), shape: const StadiumBorder()), child: const Text('Cancel'))),
          const SizedBox(width: 10),
          Expanded(child: _InsertButton(text: _text, sheet: true, editing: widget.editing, onPressed: _done)),
        ] else ...[
          OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 28)), child: const Text('Cancel')),
          const SizedBox(width: 8),
          _InsertButton(text: _text, sheet: false, editing: widget.editing, onPressed: _done),
        ],
      ]),
    ]);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(sheet ? 20 : 16, sheet ? 0 : 16, sheet ? 20 : 16, (sheet ? 20 : 16) + MediaQuery.viewInsetsOf(context).bottom),
      child: content,
    );
  }
}

class _InsertButton extends StatelessWidget {
  const _InsertButton({required this.text, required this.sheet, required this.editing, required this.onPressed});

  final TextEditingController text;
  final bool sheet;
  final bool editing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: text,
      builder: (context, _) {
        final ready = text.text.replaceAll(RegExp(r'[{}\s]+'), '').isNotEmpty;
        final label = editing ? 'Save' : 'Insert';
        return FilledButton(
          onPressed: ready ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: Size(0, sheet ? 52 : 28),
            shape: sheet ? const StadiumBorder() : null,
          ),
          // Return in the field inserts too. (⌘↩ belongs to Prompter ▸ Start, so the dialog can't use it.)
          child: sheet ? Text(label) : ShortcutHint('$label  ↩'),
        );
      },
    );
  }
}
