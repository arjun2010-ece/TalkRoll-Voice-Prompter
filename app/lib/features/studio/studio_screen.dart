import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/script/clean_script.dart';
import '../../core/script/saved_script.dart';
import '../../core/script/reading_time.dart';
import '../../core/script/sections.dart';
import '../../core/settings/prompt_settings.dart';
import '../../services/platform.dart';
import '../../core/entitlements/entitlements.dart';
import '../../services/providers.dart';
import '../pro/paywall_dialog.dart';
import '../pro/pro_state.dart';
import '../pro/upgrade_card.dart';
import '../../services/storage/script_io.dart';
import '../../ui/adaptive.dart';
import '../../ui/fade_route.dart';
import '../../ui/language_pack_prompt.dart';
import '../../ui/speech_language_prompt.dart';
import '../../ui/discard_changes_dialog.dart';
import '../read/read_screen.dart';
import '../settings/mobile_settings.dart';
import '../video/camera_state.dart';
import '../video/record_screen.dart';
import 'script_list.dart';
import 'action_cue_dialog.dart';
import 'script_text_controller.dart';
import 'start_options.dart';

/// Window width from which scripts and the editor sit side by side.
const _splitMinWidth = 720.0;
const _listPaneWidth = 360.0;
const _inspectorWidth = 400.0;
const _editorMaxWidth = 760.0;

/// Mobile Studio. In a narrow window it is a script library that opens an
/// editor, so each screen has one job and the text gets the whole screen. In a
/// wide window (iPad, landscape, resized windows) the library and the editor
/// share the screen. The layout follows the window, never the device type.
class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= _splitMinWidth ? const _SplitStudio() : const _LibraryPage(),
    );
  }
}

// --- Actions shared by both layouts -----------------------------------------

/// Imports a script into the editor; true if one was loaded.
Future<bool> _importScript(WidgetRef ref) async {
  // Checked before the file picker, so a user with no free scripts left is not asked to choose a file first.
  if (!ref.read(studioProvider.notifier).mayCreate()) return false;
  final text = await ScriptIO.importText(ref.read(prefsProvider), ref.read(libraryProvider).directory);
  if (text == null) return false;
  if (!await ref.read(studioProvider.notifier).importScript(text)) return false;
  _resetFollow(ref);
  return true;
}

void _exportScript(WidgetRef ref) {
  final body = ref.read(studioProvider).script;
  ScriptIO.exportText(
    body.split('\n').first,
    body,
    prefs: ref.read(prefsProvider),
    scriptsDir: ref.read(libraryProvider).directory,
  );
}

Future<void> presentScript(BuildContext context, WidgetRef ref, {required bool record}) async {
  final studio = ref.read(studioProvider.notifier);
  // A new script on the free plan, once the free ones are used, opens the plans straight away.
  if (!ref.read(proProvider).canPresent(studio.currentId)) {
    await showPaywall(context, reason: 'You\'ve used your $freeScriptLimit free scripts.');
    return;
  }
  await confirmSpeechLanguage(context, ref, ref.read(studioProvider).script);
  if (!context.mounted) return;
  if (!await confirmLanguagePack(context, ref, ref.read(studioProvider).script)) return;
  if (!context.mounted) return;
  await studio.start();
  // The built-in demo is never saved, so it never counts toward the free scripts.
  final id = studio.currentId;
  if (id != null) ref.read(proProvider.notifier).recordStart(id);
  if (!context.mounted) return;
  // The reader hands over to the camera with its Camera button, and the camera screen hands back to reading
  // with the voice alone. Each hand-over starts a fresh session.
  var camera = record;
  while (context.mounted) {
    if (!camera) {
      camera = await Navigator.of(context).push<bool>(FadeCoverRoute<bool>(builder: (_) => const ReadScreen())) ??
          false;
      if (!camera) break;
      await studio.start();
      if (!context.mounted) break;
    } else {
      final voiceOnly = await Navigator.of(context).push<bool>(FadeCoverRoute<bool>(builder: (_) => const RecordScreen())) ??
          false;
      if (!voiceOnly) break;
      camera = false;
      await studio.start();
      if (!context.mounted) break;
    }
  }
  studio.stopPresenting();
}

/// A new script starts in Normal mode, voice only, with no recording chosen, whatever the last script used.
void _resetFollow(WidgetRef ref) {
  ref.read(settingsProvider.notifier).update((c) => c.copyWith(mode: PromptControlMode.normal));
  ref.read(cameraOnProvider.notifier).set(false);
  ref.read(audioPathProvider.notifier).set(null);
}

String _stats(String body) {
  final words = wordCount(body);
  if (words == 0) return 'Empty script';
  final time = readingTimeLabel(words);
  final sections = sectionMarkers(body).length;
  return '$words ${words == 1 ? 'word' : 'words'} · $time${sections == 0 ? '' : ' · $sections ${sections == 1 ? 'section' : 'sections'}'}';
}

// --- Narrow layout: library, then editor ---------------------------------------------

class _LibraryPage extends ConsumerWidget {
  const _LibraryPage();

  void _openEditor(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _EditorPage()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(studioProvider.select((s) => s.history));
    final notifier = ref.read(studioProvider.notifier);
    final selecting = ref.watch(scriptSelectionProvider) != null;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar.large(
          leadingWidth: 196,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'EchoPrompter',
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          title: const Text('Scripts'),
          actions: [
            IconButton(
              tooltip: 'Import script',
              icon: const Icon(Icons.file_open_outlined),
              onPressed: () async {
                if (await _importScript(ref) && context.mounted) _openEditor(context);
              },
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.tune),
              onPressed: () => openMobileSettings(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        if (history.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyLibrary(
              onNew: () {
                if (!notifier.newScript()) return;
                _resetFollow(ref);
                _openEditor(context);
              },
              onImport: () async {
                if (await _importScript(ref) && context.mounted) _openEditor(context);
              },
              onSample: () => _openEditor(context),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 96 + MediaQuery.viewPaddingOf(context).bottom),
            sliver: SliverToBoxAdapter(
              child: ScriptListBody(
                history: history,
                highlightCurrent: false,
                showPreview: true,
                onOpen: (s) {
                  notifier.load(s);
                  _openEditor(context);
                },
                onOpenDemo: () {
                  notifier.loadDemo();
                  _openEditor(context);
                },
                menuItems: () => [
                  const PopupMenuItem(value: 'edit', child: _MenuLabel(Icons.edit_outlined, 'Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: _MenuLabel(Icons.delete_outline, 'Delete', color: Theme.of(context).colorScheme.error),
                  ),
                ],
                onMenu: (s, action) {
                  switch (action) {
                    case 'edit':
                      notifier.load(s);
                      _openEditor(context);
                    case 'delete':
                      confirmDeleteScripts(context, ref, [s]);
                  }
                },
              ),
            ),
          ),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!selecting) const SafeArea(top: false, child: UpgradeCard()),
        ScriptSelectionBar(history: history),
      ]),
      floatingActionButton: history.isEmpty || selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                if (!notifier.newScript()) return;
                _resetFollow(ref);
                _openEditor(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('New script'),
            ),
    );
  }
}

/// An icon and a label, so the row menu's entries read at a glance.
class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.icon, this.label, {this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 20, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 12),
      Text(label, style: color == null ? null : TextStyle(color: color)),
    ]);
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.onNew,
    required this.onImport,
    required this.onSample,
    this.title = 'Your scripts live here',
    this.message = 'Write or paste a script, then press Read to see it scroll.',
    this.showSample = true,
  });

  final String title;
  final String message;
  final bool showSample;

  final VoidCallback onNew;
  final VoidCallback onImport;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.subject_rounded, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onNew, icon: const Icon(Icons.add), label: const Text('New script'))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onImport, icon: const Icon(Icons.file_open_outlined), label: const Text('Import a file'))),
            const SizedBox(height: 4),
            if (showSample) TextButton(onPressed: onSample, child: const Text('Try the sample script')),
          ]),
        ),
      ),
    );
  }
}

class _EditorPage extends ConsumerWidget {
  const _EditorPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(tooltip: 'Export script', icon: const Icon(Icons.ios_share), onPressed: () => _exportScript(ref)),
        IconButton(tooltip: 'Settings', icon: const Icon(Icons.tune), onPressed: () => openMobileSettings(context)),
        const SizedBox(width: 4),
      ]),
      body: const _Editor(popOnDiscard: true),
    );
  }
}

// --- Wide layout: library and editor together --------------------------------------

class _SplitStudio extends ConsumerStatefulWidget {
  const _SplitStudio();
  @override
  ConsumerState<_SplitStudio> createState() => _SplitStudioState();
}

class _SplitStudioState extends ConsumerState<_SplitStudio> {
  /// The editor opens only once a script is chosen or created, so the right
  /// pane never shows a blank text box next to a "New script" button.
  bool _editing = false;

  /// Android: whether the editor holds unsaved edits.
  final _draftDirty = ValueNotifier(false);

  @override
  void dispose() {
    _draftDirty.dispose();
    super.dispose();
  }

  void _edit() => setState(() => _editing = true);

  /// True when nothing unsaved would be lost, or the user agreed to lose it.
  Future<bool> _canReplaceDraft() async => !_draftDirty.value || await confirmDiscardChanges(context);

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(studioProvider.select((s) => s.history));
    // Rebuild when a script is loaded so the selection follows it.
    ref.watch(studioProvider.select((s) => s.scriptRevision));
    final notifier = ref.read(studioProvider.notifier);

    Future<void> newScript() async {
      if (!await _canReplaceDraft()) return;
      if (!notifier.newScript()) return;
      _resetFollow(ref);
      _edit();
    }

    Future<void> import() async {
      if (!await _canReplaceDraft()) return;
      if (await _importScript(ref)) _edit();
    }

    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          SizedBox(
            width: _listPaneWidth,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(children: [
                  Expanded(child: Text('Scripts', style: Theme.of(context).textTheme.headlineSmall)),
                  IconButton(tooltip: 'Import script', icon: const Icon(Icons.file_open_outlined), onPressed: import),
                  IconButton(tooltip: 'Settings', icon: const Icon(Icons.tune), onPressed: () => openMobileSettings(context)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(onPressed: newScript, icon: const Icon(Icons.add), label: const Text('New script')),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: ScriptListBody(
                    history: history,
                    highlightCurrent: _editing,
                    showPreview: true,
                    onOpen: (s) async {
                      if (!await _canReplaceDraft()) return;
                      notifier.load(s);
                      _edit();
                    },
                    onOpenDemo: () async {
                      if (!await _canReplaceDraft()) return;
                      notifier.loadDemo();
                      _edit();
                    },
                    menuItems: () => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
                    onMenu: (s, _) async {
                      final wasOpen = notifier.currentId == s.id;
                      if (await confirmDeleteScripts(context, ref, [s]) && wasOpen) setState(() => _editing = false);
                    },
                  ),
                ),
              ),
              if (ref.watch(scriptSelectionProvider) == null) const UpgradeCard(),
              ScriptSelectionBar(
                history: history,
                onDeleted: (currentRemoved) {
                  if (currentRemoved) setState(() => _editing = false);
                },
              ),
            ]),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _editing
                ? Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        IconButton(tooltip: 'Export script', icon: const Icon(Icons.ios_share), onPressed: () => _exportScript(ref)),
                      ]),
                    ),
                    Expanded(child: _Editor(dirty: _draftDirty, inspector: isTabletLandscape(context))),
                  ])
                : _EmptyLibrary(
                    onNew: newScript,
                    onImport: import,
                    onSample: _edit,
                    title: history.isEmpty ? 'Your scripts live here' : 'Choose a script',
                    message: history.isEmpty
                        ? 'Write or paste a script, then press Read to see it scroll.'
                        : 'Pick one from the list, or start a new one.',
                    showSample: history.isEmpty,
                  ),
          ),
        ]),
      ),
    );
  }
}

// --- Editor ---------------------------------------------------------------------------

/// The script text with its title, and Start. A phone or a portrait tablet opens Start options from a button;
/// a tablet in landscape shows them beside the text.
///
/// On mobile the text and title are a draft until Save: Save cleans the text, stores both and enables Start;
/// Cancel throws the edits away. Starting also saves them.
class _Editor extends ConsumerStatefulWidget {
  const _Editor({
    this.dirty,
    this.popOnDiscard = false,
    this.inspector = false,
  });

  /// Told whether the draft has unsaved edits.
  final ValueNotifier<bool>? dirty;

  /// Leaving with unsaved edits and agreeing to discard them also leaves the screen.
  final bool popOnDiscard;

  /// Start options sit beside the text instead of behind a button.
  final bool inspector;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final _controller = ScriptTextController(
    text: ref.read(studioProvider).script,
  );
  final _focus = FocusNode();
  late final _titleController = TextEditingController(
    text: ref.read(studioProvider).title,
  );

  @override
  void dispose() {
    widget.dirty?.value = false;
    _controller.dispose();
    _titleController.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isDirty {
    if (!isMobile) return false;
    final studio = ref.read(studioProvider);
    return _controller.text != studio.script ||
        _titleController.text.trim() != studio.title.trim();
  }

  void _publishDirty() => widget.dirty?.value = _isDirty;

  void _edited(String text) {
    if (!isMobile) return ref.read(studioProvider.notifier).setScript(text);
    setState(() {});
    _publishDirty();
  }

  void _titleEdited() {
    setState(() {});
    _publishDirty();
  }

  /// Puts the saved script and title back in the text boxes.
  void _revert() {
    final studio = ref.read(studioProvider);
    _controller.text = studio.script;
    _titleController.text = studio.title;
    FocusManager.instance.primaryFocus?.unfocus();
    _publishDirty();
    setState(() {});
  }

  Future<void> _save() async {
    final cleaned = cleanScript(_controller.text);
    if (cleaned.isEmpty) return;
    _controller.value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(
        offset: _controller.selection.baseOffset.clamp(0, cleaned.length),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = ref
        .read(studioProvider.notifier)
        .commitScript(cleaned, title: _titleController.text.trim());
    _publishDirty();
    setState(() {});
    await saved;
  }

  Future<void> _cancel() async {
    if (await confirmDiscardChanges(context)) _revert();
  }

  Future<void> _leave(bool didPop) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    if (!await confirmDiscardChanges(context)) return;
    _revert();
    if (widget.popOnDiscard) navigator.pop();
  }

  /// Empties the script (not the title). Cancel restores the saved one, and the snackbar's Undo the text just cleared.
  void _clear() {
    final previous = _controller.text;
    _controller.clear();
    _edited('');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Cleared'),
          // A snackbar with an action stays until it is tapped unless told otherwise; this one must go by itself so
          // it doesn't cover Start.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              _controller.text = previous;
              _edited(previous);
            },
          ),
        ),
      );
  }

  /// Puts a new `[Section N]` line at the caret, on a line of its own, with its name selected to type over.
  void _insertSection() {
    final text = _controller.text;
    final sel = _controller.selection;
    final at = sel.isValid ? sel.start : text.length;
    final name = 'Section ${sectionMarkers(text).length + 1}';
    final lead = at > 0 && text[at - 1] != '\n' ? '\n' : '';
    final inserted = '$lead[$name]\n';
    final nameStart = at + lead.length + 1;
    _controller.value = TextEditingValue(
      text: text.replaceRange(at, sel.isValid ? sel.end : at, inserted),
      selection: TextSelection(
        baseOffset: nameStart,
        extentOffset: nameStart + name.length,
      ),
    );
    _focus.requestFocus();
    _edited(_controller.text);
  }

  /// Asks for an action cue and puts it at the caret (or edits the cue the caret is on).
  Future<void> _insertActionCue() async {
    if (!await insertActionCue(context, _controller)) return;
    if (!mounted) return;
    _focus.requestFocus();
    _edited(_controller.text);
  }

  /// Starting saves the draft first, then presents in the mode and with or without the camera chosen in Start options.
  Future<void> _start() async {
    if (_isDirty) {
      if (cleanScript(_controller.text).isEmpty) return;
      await _save();
    }
    if (!mounted) return;
    final mode = ref.read(settingsProvider).mode;
    final camera =
        ref.read(cameraOnProvider) && mode != PromptControlMode.normal;
    await presentScript(context, ref, record: camera);
  }

  @override
  Widget build(BuildContext context) {
    // A script replaced from outside the editor (open, new, import) reloads the text and title.
    ref.listen(studioProvider.select((s) => s.scriptRevision), (_, _) {
      final studio = ref.read(studioProvider);
      _controller.text = studio.script;
      _titleController.text = studio.title;
      _publishDirty();
    });
    // A script edited from a prompter screen comes back without a revision bump.
    ref.listen(studioProvider.select((s) => s.script), (_, script) {
      if (_controller.text != script) _controller.text = script;
      _publishDirty();
    });
    final script = ref.watch(studioProvider.select((s) => s.script));
    final dirty = _isDirty;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = isMobile ? _controller.text : script;
    final empty = text.trim().isEmpty;
    final canSave = dirty && cleanScript(_controller.text).isNotEmpty;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            // Save state and the word count share this line, so the buttons below can have a row to themselves.
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: dirty ? 'Unsaved changes' : 'Saved',
                  style: TextStyle(color: dirty ? scheme.secondary : scheme.onSurfaceVariant),
                ),
                TextSpan(
                  text: ' · ${_stats(text)}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (isMobile) ...[
            TextButton(
              onPressed: dirty ? _cancel : null,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(minimumSize: const Size(72, 40)),
              child: const Text('Save'),
            ),
          ],
        ],
      ),
    );

    final titleField = Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _titleController,
              maxLength: SavedScript.maxTitleLength,
              maxLines: 1,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _titleEdited(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Title',
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          // The count only shows when the limit is close.
          ListenableBuilder(
            listenable: _titleController,
            builder: (_, _) => _titleController.text.length >= 20
                ? Text(
                    '${_titleController.text.length}/${SavedScript.maxTitleLength}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    // Insert Section and Insert Action Cue sit side by side, as in the design; Clear is the small button after them.
    final insertRow = Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _insertSection,
              icon: const Icon(Icons.horizontal_rule, size: 18),
              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Insert Section', maxLines: 1, softWrap: false)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 10)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: ActionCueButton(onPressed: _insertActionCue, height: 40)),
          if (!empty) ...[
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: _clear,
              tooltip: 'Clear',
              icon: const Icon(Icons.backspace_outlined, size: 18),
              style: IconButton.styleFrom(fixedSize: const Size(40, 40)),
            ),
          ],
        ],
      ),
    );

    final body = Expanded(
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        autofocus: script.isEmpty,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        style: theme.textTheme.bodyLarge?.copyWith(fontSize: 19, height: 1.5),
        onChanged: _edited,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Script',
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );

    final startBar = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerTheme.color ?? Colors.transparent,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _editorMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: empty
                        ? null
                        : () => showStartOptions(
                            context,
                            dirty: dirty,
                            scriptText: _controller.text,
                            onStart: _start,
                          ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start…'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    empty
                        ? 'Write or paste a script to start.'
                        : dirty
                        ? 'Starting saves your changes.'
                        : 'Choose how the prompter follows you.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final editorColumn = Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _editorMaxWidth),
              child: Column(
                children: [
                  header,
                  titleField,
                  const Divider(indent: 24, endIndent: 24),
                  const SizedBox(height: 4),
                  insertRow,
                  body,
                ],
              ),
            ),
          ),
        ),
        if (!widget.inspector) startBar,
      ],
    );

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) => _leave(didPop),
      child: widget.inspector
          ? Row(
              children: [
                Expanded(child: editorColumn),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: _inspectorWidth,
                  child: StartOptions(
                    dirty: dirty,
                    scriptText: _controller.text,
                    onStart: _start,
                  ),
                ),
              ],
            )
          : editorColumn,
    );
  }
}
