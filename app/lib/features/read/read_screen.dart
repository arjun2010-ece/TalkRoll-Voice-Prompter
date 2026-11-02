import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:permission_handler/permission_handler.dart';

import '../../core/settings/prompt_settings.dart';
import '../../services/permissions/permissions.dart';
import '../../ui/permission_dialogs.dart';
import '../studio/start_options.dart';
import '../video/mode_chip.dart';
import '../video/camera_state.dart';
import '../prompter/progress_line.dart';
import '../prompter/section_end.dart';
import '../../services/providers.dart';
import '../prompter/prompt_surface.dart';
import '../prompter/prompter_controller.dart';
import '../prompter/tracking_status.dart';
import 'reading_settings.dart';
import '../../ui/language_pack_prompt.dart';
import '../../ui/voice_unsupported_dialog.dart';
import 'script_editor_sheet.dart';

/// Window width from which the reader uses its roomy tablet layout.
const _wideMinWidth = 720.0;

/// Longest line length that stays comfortable to read on a big window.
const _maxTextWidth = 980.0;

/// Mobile "Read" mode: the script, full bleed on black, with controls that
/// step aside while you read. Playback sits in a floating dock at the bottom;
/// whether the prompter is following you is always visible at the top, even
/// when the rest of the chrome has faded. Tap the text to bring controls back.
/// Portrait or landscape; rotate/mirror live in the settings.
class ReadScreen extends ConsumerStatefulWidget {
  const ReadScreen({super.key});
  @override
  ConsumerState<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends ConsumerState<ReadScreen> {
  static const _hideAfter = Duration(seconds: 4);

  bool _chrome = true;
  Timer? _hideTimer;
  // Handed over to the Record screen, which keeps the system bars hidden and restores them itself.
  bool _toRecord = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final studio = ref.read(studioProvider);
    ref.read(prompterProvider.notifier).begin(
      sessionId: studio.sessionId,
      script: studio.script,
      mode: ref.read(settingsProvider).mode,
      audioPath: ref.read(audioPathProvider),
      startSection: ref.read(startSectionProvider),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // Runs after the exit animation, when the Record screen may already be showing.
    if (!_toRecord) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Controls stay up while paused and fade a few seconds after playback starts.
  void _syncChrome(bool playing) {
    _hideTimer?.cancel();
    if (!playing) {
      setState(() => _chrome = true);
      return;
    }
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) setState(() => _chrome = false);
    });
  }

  /// A tap while the controls are hidden only brings them back.
  bool _onTextTap() {
    final playing = ref.read(prompterProvider).playing;
    if (_chrome) {
      _syncChrome(playing);
      return false;
    }
    setState(() => _chrome = true);
    _syncChrome(playing);
    return true;
  }

  void _close() {
    ref.read(prompterProvider.notifier).pause();
    Navigator.of(context).pop();
  }

  Future<void> _edit() async {
    if (!await showScriptEditor(context, ref)) return;
    final studio = ref.read(studioProvider);
    await ref.read(prompterProvider.notifier).begin(
      sessionId: studio.sessionId,
      script: studio.script,
      mode: ref.read(settingsProvider).mode,
      audioPath: ref.read(audioPathProvider),
    );
  }

  void _record() {
    ref.read(cameraOnProvider.notifier).set(true);
    _toRecord = true;
    ref.read(prompterProvider.notifier).pause();
    Navigator.of(context).pop(true);
  }

  /// Opens "How to read". The reader pauses while it is open and keeps its mode until the sheet's button is pressed.
  /// Choosing the camera there moves to the camera screen; another mode restarts the prompter at the same word.
  Future<void> _changeMode() async {
    _hideTimer?.cancel();
    final prompter = ref.read(prompterProvider.notifier);
    await prompter.pause();
    if (!mounted) return;
    final before = ref.read(settingsProvider).mode;
    final beforeRun = ref.read(settingsProvider).runStyle;
    final word = before == PromptControlMode.normal
        ? ref.read(readingWordProvider)
        : math.max(ref.read(prompterProvider).progress.confirmedWordIndex, 0);
    var applied = false;
    await showStartOptions(context, apply: StartApply.use, onStart: () async => applied = true);
    if (!mounted || !applied) return;
    // Run style changed: the section holding the reading position becomes the current one (or the whole script runs).
    if (ref.read(settingsProvider).runStyle != beforeRun) prompter.refreshRunStyle();
    final mode = ref.read(settingsProvider).mode;
    if (ref.read(cameraOnProvider) && mode != PromptControlMode.normal) {
      _record();
    } else if (mode != before && mode != PromptControlMode.normal) {
      prompter.seekTo(word);
    }
  }

  /// Voice listens through the microphone, so its first Play asks for it. Auto-scroll and Narration never use it.
  Future<void> _togglePlay() async {
    HapticFeedback.selectionClick();
    final prompter = ref.read(prompterProvider.notifier);
    if (ref.read(settingsProvider).mode == PromptControlMode.voice && !ref.read(prompterProvider).playing) {
      final granted = await requestPermission(Permission.microphone, 'mic', ref.read(analyticsProvider));
      if (!granted) {
        if (mounted) showMicrophoneDenied(context);
        return;
      }
    }
    await prompter.togglePlay();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.mode), (_, mode) {
      final studio = ref.read(studioProvider);
      ref.read(prompterProvider.notifier).begin(
        sessionId: studio.sessionId,
        script: studio.script,
        mode: mode,
        audioPath: ref.read(audioPathProvider),
      );
    });
    ref.listen(prompterProvider.select((p) => p.playing), (_, playing) => _syncChrome(playing));
    ref.listen(prompterProvider.select((p) => p.voiceNeedsPack), (_, needs) async {
      if (!needs) return;
      final studio = ref.read(studioProvider);
      if (await confirmLanguagePack(context, ref, studio.script) && context.mounted) {
        await ref.read(prompterProvider.notifier).play();
      }
    });
    ref.listen(prompterProvider.select((p) => p.voiceUnsupported), (_, unsupported) {
      if (unsupported) {
        showVoiceUnsupportedDialog(
          context,
          onUseNormal: () => ref.read(settingsProvider.notifier).update((c) => c.copyWith(mode: PromptControlMode.normal)),
        );
      }
    });

    return Scaffold(
      backgroundColor: promptBackground,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
          const SingleActivator(LogicalKeyboardKey.escape): _close,
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= _wideMinWidth;
            final pad = MediaQuery.viewPaddingOf(context);
            return Stack(children: [
              Positioned.fill(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxTextWidth),
                    child: PromptSurface(onWordTap: true, onTapIntercept: _onTextTap),
                  ),
                ),
              ),
              Positioned(left: 0, right: 0, bottom: 0, child: _ProgressLine()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Dock(visible: _chrome, wide: wide, bottomInset: pad.bottom, onTogglePlay: _togglePlay, onEdit: _edit),
              ),
              // Over the dock too, which the scrim dims, so the card's buttons are never hidden behind it.
              const Positioned.fill(child: _SectionEnd()),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(visible: _chrome, wide: wide, topInset: pad.top, onClose: _close, onMode: _changeMode, onSettings: () => showReadingSettings(context)),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

// --- Section end -------------------------------------------------------------------

/// Section by section: when a section ends the prompter stops under a dimmed script, with Retake, Next and Sections….
class _SectionEnd extends ConsumerWidget {
  const _SectionEnd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(prompterProvider.select((p) => p.sectionDone));
    if (!done || !ref.read(prompterProvider.notifier).sectionRun) return const SizedBox.shrink();
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.5),
      child: SafeArea(
        child: Align(
          alignment: const Alignment(0, -0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            // A short window (a phone in landscape) gets the compact card, laid out in one row.
            child: SectionEndCard(compact: MediaQuery.sizeOf(context).height < 500, onSections: () => showSectionsSheet(context)),
          ),
        ),
      ),
    );
  }
}

// --- Top bar -----------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.visible, required this.wide, required this.topInset, required this.onClose, required this.onMode, required this.onSettings});

  final bool visible;
  final bool wide;
  final double topInset;
  final VoidCallback onClose;
  final VoidCallback onMode;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    final pr = ref.watch(prompterProvider);
    final audio = ref.watch(audioPathProvider);
    final status = trackingStatusFor(mode, pr, audio);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, math.max(topInset, 8) + 4, 12, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FadeIn(
          visible: visible,
          duration: duration,
          child: _RoundButton(icon: Icons.close, tooltip: 'Close', onPressed: onClose),
        ),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TrackingPill(mode: mode, status: status, showMode: false),
            ),
            if (status.detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    status.detail!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: promptText.withValues(alpha: 0.8), fontSize: 13),
                  ),
                ),
              ),
          ]),
        ),
        _FadeIn(
          visible: visible,
          duration: duration,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ModeChip(mode: mode, camera: false, onPressed: onMode),
            const SizedBox(width: 8),
            _RoundButton(icon: Icons.tune, tooltip: 'Reading settings', onPressed: onSettings),
          ]),
        ),
      ]),
    );
  }
}

// --- Dock ----------------------------------------------------------------------------

class _Dock extends ConsumerWidget {
  const _Dock({
    required this.visible,
    required this.wide,
    required this.bottomInset,
    required this.onTogglePlay,
    required this.onEdit,
  });

  final bool visible;
  final bool wide;
  final double bottomInset;
  final VoidCallback onTogglePlay;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final pr = ref.watch(prompterProvider);
    final c = ref.read(prompterProvider.notifier);
    final set = ref.read(settingsProvider.notifier).update;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final playSize = wide ? 76.0 : 68.0;
    final leftActions = Row(mainAxisSize: MainAxisSize.min, children: [
      _RoundButton(icon: Icons.replay, tooltip: 'Restart', onPressed: c.restart),
      const SizedBox(width: 8),
      _RoundButton(icon: Icons.edit_outlined, tooltip: 'Edit script', onPressed: onEdit),
    ]);

    final stepper = s.mode == PromptControlMode.normal
        ? _Stepper(
            label: '${(s.speed / 24).toStringAsFixed(1)}×',
            caption: 'Speed',
            onMinus: () => set((v) => v.copyWith(speed: math.max(6, v.speed - 3))),
            onPlus: () => set((v) => v.copyWith(speed: math.min(72, v.speed + 3))),
            minusTip: 'Slower',
            plusTip: 'Faster',
          )
        : s.mode == PromptControlMode.recordedAudio
        ? _Stepper(
            label: '5 s',
            caption: 'Skip',
            onMinus: () => c.skip(const Duration(seconds: -5)),
            onPlus: () => c.skip(const Duration(seconds: 5)),
            minusTip: 'Back 5 seconds',
            plusTip: 'Forward 5 seconds',
            minusIcon: Icons.replay_5,
            plusIcon: Icons.forward_5,
          )
        : _Stepper(
            label: '${s.fontSize.round()}',
            caption: 'Text size',
            onMinus: () => set((v) => v.copyWith(fontSize: v.fontSize - 3)),
            onPlus: () => set((v) => v.copyWith(fontSize: v.fontSize + 3)),
            minusTip: 'Smaller text',
            plusTip: 'Larger text',
          );

    return _FadeIn(
      visible: visible,
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      slide: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, math.max(bottomInset, 8) + 8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 560 : 440),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (s.showProgress) ...[
                    SizedBox(
                      width: double.infinity,
                      child: DefaultTextStyle.merge(
                        textAlign: TextAlign.center,
                        child: ProgressLine(style: TextStyle(color: promptText.withValues(alpha: 0.65), fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Equal side slots keep the play button centred whatever the side widths.
                  Row(children: [
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: leftActions)),
                    _PlayButton(size: playSize, playing: pr.playing, busy: pr.preparing, onPressed: onTogglePlay),
                    Expanded(child: Align(alignment: Alignment.centerRight, child: stepper)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.size, required this.playing, required this.busy, required this.onPressed});

  final double size;
  final bool playing;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Play',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: busy ? Colors.white24 : const Color(0xFF0B63CE),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onPressed,
            child: Center(
              child: busy
                  ? const SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 3, color: promptText))
                  : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: size * 0.6, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.caption,
    required this.onMinus,
    required this.onPlus,
    required this.minusTip,
    required this.plusTip,
    this.minusIcon = Icons.remove,
    this.plusIcon = Icons.add,
  });

  final String label;
  final String caption;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final String minusTip;
  final String plusTip;
  final IconData minusIcon;
  final IconData plusIcon;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _RoundButton(icon: minusIcon, tooltip: minusTip, onPressed: onMinus, filled: false),
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(color: promptText, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(caption, style: TextStyle(color: promptText.withValues(alpha: 0.6), fontSize: 10)),
        ]),
      ),
      _RoundButton(icon: plusIcon, tooltip: plusTip, onPressed: onPlus, filled: false),
    ]);
  }
}

// --- Small pieces ----------------------------------------------------------------

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onPressed, this.filled = true});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: promptText),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: filled ? Colors.white.withValues(alpha: 0.12) : null,
      ),
    );
  }
}

/// Fades (and optionally slides down) its child away; hidden children stop
/// receiving touches.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.visible, required this.duration, required this.child, this.slide = false});

  final bool visible;
  final Duration duration;
  final Widget child;
  final bool slide;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedSlide(
          duration: duration,
          curve: Curves.easeOutCubic,
          offset: slide && !visible ? const Offset(0, 0.4) : Offset.zero,
          child: AnimatedOpacity(duration: duration, opacity: visible ? 1 : 0, child: child),
        ),
      ),
    );
  }
}

/// A hairline of reading progress along the bottom edge.
class _ProgressLine extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    final tracked = ref.watch(prompterProvider.select((p) => p.progress.confirmedWordIndex));
    final scrolled = ref.watch(readingWordProvider);
    final words = ref.read(prompterProvider.notifier).wordCount;
    final index = mode == PromptControlMode.normal ? scrolled : math.max(tracked, 0);
    final value = words <= 1 ? 0.0 : (index / (words - 1)).clamp(0.0, 1.0).toDouble();
    return ExcludeSemantics(
      child: LinearProgressIndicator(
        value: value,
        minHeight: 3,
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        color: const Color(0xFFFF9F0A).withValues(alpha: 0.8),
      ),
    );
  }
}
