import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import '../../core/settings/labels.dart';
import '../../core/settings/prompt_settings.dart';
import '../../services/providers.dart';
import '../../services/storage/script_io.dart';
import '../../ui/adaptive.dart';
import '../../ui/prompt_text_controls.dart';
import '../pro/paywall_dialog.dart';
import '../pro/pro_state.dart';
import '../prompter/voice_availability.dart';
import '../video/camera_state.dart';
import 'audio_check.dart';
import 'prompt_preview.dart';

/// What the sheet's main button does: begin the session (from the editor), or switch an open session to the
/// choices made here (from the reader or the camera).
enum StartApply { start, use }

/// Opens "How to read": a bottom sheet on phones, a panel on the trailing edge on tablets. [onStart] runs after the
/// choices have been saved, so nothing behind the sheet changes until the main button is pressed. Starting leaves
/// the sheet up while the next screen fades in over it; applying closes the sheet first.
Future<void> showStartOptions(
  BuildContext context, {
  required Future<void> Function() onStart,
  bool dirty = false,
  String? scriptText,
  StartApply apply = StartApply.start,
}) {
  Future<void> start(BuildContext sheet) async {
    final route = ModalRoute.of(sheet)!;
    if (apply == StartApply.use) {
      Navigator.of(sheet).pop();
      // The next screen only starts once the sheet has finished leaving, or it shows through the fade.
      await route.completed;
      await onStart();
      return;
    }
    // Starting keeps the sheet frozen while the prompter fades in over it, so the script behind never shows on its
    // own; the sheet is dropped from underneath once it is fully covered (or at once if nothing was presented).
    final navigator = Navigator.of(sheet);
    void leave() {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    }

    route.secondaryAnimation?.addStatusListener((status) {
      if (status == AnimationStatus.completed) leave();
    });
    try {
      await onStart();
    } finally {
      leave();
    }
  }

  if (!isTabletWidth(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.94,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        builder: (_, scroll) => StartOptions(
          scroll: scroll,
          dirty: dirty,
          scriptText: scriptText,
          apply: apply,
          onStart: () => start(sheet),
          onClose: () => Navigator.of(sheet).pop(),
        ),
      ),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, a, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Theme.of(ctx).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(isApple ? 16 : 28),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 420,
              child: StartOptions(
                dirty: dirty,
                scriptText: scriptText,
                apply: apply,
                onStart: () => start(ctx),
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "How to read": the mode, what that mode needs (speed, or the recording), and whether video is recorded. It is the
/// only place these are chosen; the same sheet starts a session and switches one. The choices are a draft until the
/// main button is pressed. Shown in a sheet, or inline beside the editor on a tablet in landscape.
class StartOptions extends ConsumerStatefulWidget {
  const StartOptions({
    super.key,
    required this.onStart,
    this.onClose,
    this.scroll,
    this.dirty = false,
    this.scriptText,
    this.apply = StartApply.start,
  });

  final VoidCallback onStart;

  /// Shows a close button when set (the sheet and panel); the inline inspector has none.
  final VoidCallback? onClose;
  final ScrollController? scroll;

  /// The editor holds unsaved edits; Start saves them first.
  final bool dirty;

  /// The text in the editor, saved or not. The preview shows it and Start is available once it isn't empty.
  final String? scriptText;
  final StartApply apply;

  @override
  ConsumerState<StartOptions> createState() => _StartOptionsState();
}

class _StartOptionsState extends ConsumerState<StartOptions> {
  late PromptControlMode _mode = ref.read(settingsProvider).mode;
  late bool _camera = ref.read(cameraOnProvider);

  /// Saves the choices, then lets the caller carry on.
  void _apply() {
    ref.read(settingsProvider.notifier).update((c) => c.copyWith(mode: _mode));
    ref.read(cameraOnProvider.notifier).set(_camera && _mode != PromptControlMode.normal);
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = widget.apply == StartApply.start;
    final savedEmpty = ref.watch(studioProvider.select((x) => x.script.trim().isEmpty));
    final empty = widget.scriptText != null ? widget.scriptText!.trim().isEmpty : savedEmpty;
    final camera = _camera && _mode != PromptControlMode.normal;
    final blocker = _mode == PromptControlMode.recordedAudio ? audioStartBlocker(ref.watch(audioCheckProvider)) : null;
    // A new script once the free ones are used: Start opens the plans.
    final locked = start && !ref.watch(proProvider.select((p) => p.canPresent(ref.read(studioProvider.notifier).currentId)));
    final caption = start && empty
        ? 'Write or paste a script to start.'
        : blocker ?? (locked ? "Needs Pro. You've used your $freeScriptLimit free scripts." : start && widget.dirty ? 'Starting saves your changes.' : null);
    final canApply = !(start && empty) && blocker == null;
    final label = start ? (camera ? 'Start with camera' : 'Start') : 'Use ${_mode.label}${camera ? ' + camera' : ''}';

    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, widget.onClose == null ? 16 : 0, 8, 4),
        child: Row(children: [
          Expanded(child: Text('How to read', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
          if (widget.onClose != null) IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: widget.onClose),
        ]),
      ),
      Expanded(
        child: ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: SizedBox(height: 112, child: PromptPreview(wordIndex: 0, height: 112, script: widget.scriptText)),
              ),
            ),
            const SizedBox(height: 20),
            FollowOptions(
              mode: _mode,
              camera: _camera,
              onMode: (m) => setState(() => _mode = m),
              onCamera: (c) => setState(() => _camera = c),
            ),
          ],
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerTheme.color ?? Colors.transparent))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FilledButton.icon(
                onPressed: !canApply
                    ? null
                    : locked
                        ? () => showPaywall(context, reason: "You've used your $freeScriptLimit free scripts.")
                        : _apply,
                icon: Icon(locked ? Icons.lock_outline : camera ? Icons.videocam : start ? Icons.play_arrow_rounded : Icons.check),
                label: Text(label),
              ),
              if (caption != null) ...[
                const SizedBox(height: 8),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: locked ? scheme.secondary : scheme.onSurfaceVariant),
                ),
              ],
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// The mode, what it needs (scroll speed, or the recording), and the Voice only / Voice + camera choice. The caller
/// owns the values, so the screen behind a sheet can stay as it is until the choices are confirmed.
class FollowOptions extends ConsumerWidget {
  const FollowOptions({super.key, required this.mode, required this.camera, required this.onMode, required this.onCamera});

  final PromptControlMode mode;
  final bool camera;
  final ValueChanged<PromptControlMode> onMode;
  final ValueChanged<bool> onCamera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final voiceOk = ref.watch(voiceAvailableProvider).value ?? true;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final withCamera = camera && mode != PromptControlMode.normal;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 0.8, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
    );
    Widget note(String text, {Color? color}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline, size: 18, color: color ?? scheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: muted?.copyWith(fontSize: 13))),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      heading('FOLLOW'),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<PromptControlMode>(
          showSelectedIcon: !isApple,
          segments: [for (final m in PromptControlMode.values) ButtonSegment(value: m, label: Text(m.label))],
          selected: {mode},
          onSelectionChanged: (v) => onMode(v.first),
        ),
      ),
      Padding(padding: const EdgeInsets.only(top: 10), child: Text(mode.explanation, style: muted)),
      if (!voiceOk && mode != PromptControlMode.normal)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: note(
            'This device reports no speech recognition for English, so Voice and Narration may not work here. You can still choose them. Auto-scroll always works.',
            color: scheme.secondary,
          ),
        ),
      if (mode == PromptControlMode.normal) ...[
        const SizedBox(height: 8),
        const ScrollSpeedControl(),
      ],
      if (mode == PromptControlMode.recordedAudio) ...[
        const SizedBox(height: 12),
        const _AudioCard(),
        const SizedBox(height: 10),
        note('Play the audio on your speakers, not a headset, so the microphone can hear it.'),
      ],
      const SizedBox(height: 20),
      if (mode != PromptControlMode.normal) ...[
        heading('CAMERA'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.mic_none, size: 18), label: Text('Voice only')),
              ButtonSegment(value: true, icon: Icon(Icons.videocam_outlined, size: 18), label: Text('Voice + camera')),
            ],
            selected: {withCamera},
            onSelectionChanged: (v) => onCamera(v.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            withCamera ? 'Records video to your gallery. The prompter sits on top of the camera.' : 'Read with your voice only. Turn the camera on to record yourself.',
            style: muted,
          ),
        ),
      ] else
        note('The camera works with Voice and Narration. Auto-scroll never uses the camera or microphone.'),
    ]);
  }
}

/// The chosen recording and whether it can be used, or a prompt to choose one.
class _AudioCard extends ConsumerWidget {
  const _AudioCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final path = ref.watch(audioPathProvider);
    final check = ref.watch(audioCheckProvider);
    final checking = path != null && check.isLoading;
    final unreadable = check.hasValue && check.requireValue.readiness == AudioReadiness.unreadable;
    final seconds = check.hasValue ? check.requireValue.seconds : null;
    Future<void> choose() async => ref.read(audioPathProvider.notifier).set(await ScriptIO.chooseAudio() ?? path);

    if (path == null) {
      return OutlinedButton.icon(
        onPressed: choose,
        icon: const Icon(Icons.audio_file_outlined),
        label: const Text('Choose a recording…'),
      );
    }
    final detail = checking
        ? 'Checking the recording…'
        : unreadable
            ? "Can't be read, or was moved"
            : '${seconds == null ? '' : '${formatSeconds(seconds)} · '}ready';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: unreadable ? scheme.secondary : scheme.outlineVariant),
      ),
      child: Row(children: [
        SizedBox.square(
          dimension: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: checking
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Icon(unreadable ? Icons.warning_amber_rounded : Icons.audio_file_outlined, color: unreadable ? scheme.secondary : scheme.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(path.split(RegExp(r'[\\/]')).last, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(detail, style: TextStyle(fontSize: 13, color: unreadable ? scheme.secondary : scheme.onSurfaceVariant)),
          ]),
        ),
        TextButton(onPressed: choose, child: Text(unreadable ? 'Choose another' : 'Change…')),
      ]),
    );
  }
}
