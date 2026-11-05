import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/prompt_settings.dart';
import '../../services/providers.dart';
import 'prompt_surface.dart';
import 'progress_line.dart';
import 'prompter_controller.dart';
import 'tracking_status.dart';

export 'prompt_surface.dart' show PromptLayoutStyle;

/// Mobile prompter: the shared text surface plus a simple control row. Used
/// by the Read screen and as the overlay on the Record screen. (The desktop
/// overlay has its own layouts in `desktop_prompter_screen.dart`.)
class PromptView extends ConsumerWidget {
  const PromptView({
    super.key,
    this.style = PromptLayoutStyle.full,
    this.backgroundOpacity,
    this.showControls = true,
    this.showProgress = false,
    this.bottomInset = 0,
    this.quietCues = false,
    this.onClose,
    this.trailing = const [],
  });

  final PromptLayoutStyle style;
  final double? backgroundOpacity;

  /// Shows the percent / elapsed / time-left line under the text, when the "Show progress" setting is on.
  /// [bottomInset] keeps it clear of anything the host draws over the panel's bottom edge.
  final bool showProgress;
  final double bottomInset;

  /// No cue strips in the panel: the "Next" heads-up takes the status line's place for a moment, and the host draws
  /// Continue itself.
  final bool quietCues;

  /// False when the host screen shows [PromptControlBar] itself.
  final bool showControls;
  final VoidCallback? onClose;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final bg = promptBackground.withValues(alpha: backgroundOpacity ?? s.opacity);
    final compact = style != PromptLayoutStyle.full;

    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 12 : 0),
      child: ColoredBox(
        color: bg,
        child: Column(children: [
          Expanded(child: PromptSurface(style: style, onWordTap: true, quietCues: quietCues)),
          if (showProgress && (s.showProgress || quietCues))
            Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 8 + bottomInset),
              child: SizedBox(
                width: double.infinity,
                child: DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  // The camera screen's top bar already shows the recording time.
                  child: ProgressLine(
                    showElapsed: false,
                    headsUp: quietCues,
                    hideProgress: !s.showProgress,
                    style: TextStyle(color: promptText.withValues(alpha: 0.65), fontSize: 12),
                  ),
                ),
              ),
            ),
          if (showControls) PromptControlBar(compact: compact, onClose: onClose, trailing: trailing),
        ]),
      ),
    );
  }
}

/// Play/restart/speed/mode controls for the prompter.
class PromptControlBar extends ConsumerWidget {
  const PromptControlBar({super.key, this.compact = true, this.onClose, this.trailing = const [], this.color, this.onSettings});

  final bool compact;

  /// Replaces the mode menu with a settings button, for screens whose mode is fixed.
  final VoidCallback? onSettings;
  final VoidCallback? onClose;
  final List<Widget> trailing;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final pr = ref.watch(prompterProvider);
    final c = ref.read(prompterProvider.notifier);
    final set = ref.read(settingsProvider.notifier).update;
    const fg = promptText;
    return Material(
    color: color ?? Colors.black.withValues(alpha: 0.35),
    child: IconTheme(
      data: IconThemeData(color: fg, size: compact ? 18 : 22),
      child: Row(children: [
        IconButton(
          tooltip: pr.playing ? 'Pause' : 'Play',
          icon: Icon(pr.playing ? Icons.pause : Icons.play_arrow),
          onPressed: pr.preparing ? null : c.togglePlay,
        ),
        IconButton(tooltip: 'Restart', icon: const Icon(Icons.replay), onPressed: c.restart),
        if (s.mode == PromptControlMode.normal) ...[
          IconButton(icon: const Icon(Icons.remove), tooltip: 'Slower', onPressed: () => set((v) => v.copyWith(speed: math.max(6, v.speed - 3)))),
          Text('${(s.speed / 24).toStringAsFixed(2)}×', style: TextStyle(color: fg, fontSize: 12)),
          IconButton(icon: const Icon(Icons.add), tooltip: 'Faster', onPressed: () => set((v) => v.copyWith(speed: math.min(72, v.speed + 3)))),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TrackingPill(
              mode: s.mode,
              status: trackingStatusFor(s.mode, pr, ref.watch(audioPathProvider)),
              showMode: false,
              dense: true,
            ),
          ),
        ),
        if (onSettings != null)
          IconButton(tooltip: 'Settings', icon: const Icon(Icons.tune), onPressed: onSettings)
        else
        PopupMenuButton<PromptControlMode>(
          tooltip: 'Mode',
          icon: Icon(Icons.tune, color: fg),
          initialValue: s.mode,
          onSelected: (m) => set((v) => v.copyWith(mode: m)),
          itemBuilder: (_) => const [
            PopupMenuItem(value: PromptControlMode.normal, child: Text('Auto-scroll')),
            PopupMenuItem(value: PromptControlMode.voice, child: Text('Voice control')),
            PopupMenuItem(value: PromptControlMode.recordedAudio, child: Text('Narration')),
          ],
        ),
        ...trailing,
        if (onClose != null) IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
      ]),
    ),
  );
  }
}
