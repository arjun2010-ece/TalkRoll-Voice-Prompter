import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/script/sections.dart';
import '../../core/settings/prompt_settings.dart';
import '../../services/providers.dart';
import 'cue_widgets.dart';
import 'prompt_surface.dart' show promptText;
import 'prompter_controller.dart';

/// Whole-number percent read, from the word the presenter has reached.
int readingPercent(WidgetRef ref) {
  final mode = ref.watch(settingsProvider.select((s) => s.mode));
  final finished = ref.watch(prompterProvider.select((p) => p.finished));
  final tracked = ref.watch(prompterProvider.select((p) => p.progress.confirmedWordIndex));
  final scrolled = ref.watch(readingWordProvider);
  final words = ref.read(prompterProvider.notifier).wordCount;
  if (finished) return 100;
  if (words <= 1) return 0;
  final index = mode == PromptControlMode.normal ? scrolled : math.max(tracked, 0);
  return (100 * index / (words - 1)).floor().clamp(0, 100);
}

String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// `Demo · 3 of 4  ·  42%  ·  1:10 elapsed  ·  ~1:35 left`. It is a widget of its own so a clock tick
/// rebuilds this line and never the script text. Elapsed counts only while the prompter is playing,
/// and starts over with Restart and with each new session.
class ProgressLine extends ConsumerStatefulWidget {
  const ProgressLine({super.key, this.style, this.showElapsed = true, this.headsUp = false, this.hideProgress = false, this.split = false});
  final TextStyle? style;

  /// While an action cue is coming up, this line says so ("Next  Click Submit · Hold") in place of the progress, so the
  /// host needs no strip over the script.
  final bool headsUp;

  /// With [headsUp]: the "Show progress" setting is off, so the line stays empty except for the heads-up.
  final bool hideProgress;

  /// Two sides instead of one centred line: the section on the left, the progress and time left on the right (the
  /// camera screen's footer on iPhone, iPad and Android). The heads-up then starts at the left edge.
  final bool split;

  /// False where the host screen already shows the time elapsed (the camera screen's recording timer).
  final bool showElapsed;

  @override
  ConsumerState<ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends ConsumerState<ProgressLine> {
  Timer? _timer;
  Duration _banked = Duration.zero;
  DateTime? _since;

  /// Recent (elapsed seconds, word index) samples, for how fast Voice mode is moving.
  final _samples = <(double, int)>[];

  Duration get _elapsed => _banked + (_since == null ? Duration.zero : DateTime.now().difference(_since!));

  void _playing(bool playing) {
    if (playing && _since == null) {
      _since = DateTime.now();
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    } else if (!playing && _since != null) {
      _banked += DateTime.now().difference(_since!);
      _since = null;
      _timer?.cancel();
      _timer = null;
      setState(() {});
    }
  }

  void _restarted() {
    _banked = Duration.zero;
    _since = ref.read(prompterProvider).playing ? DateTime.now() : null;
    _samples.clear();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (ref.read(prompterProvider).playing) _playing(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Seconds left, or null when it can't be told yet.
  int _secondsLeft(PromptSettings s, PrompterState pr, int words, int index) {
    if (pr.finished) return 0;
    final left = math.max(0, words - 1 - index);
    switch (s.mode) {
      case PromptControlMode.normal:
        final px = ref.watch(scrollRemainingProvider);
        return (px / s.speed).ceil();
      case PromptControlMode.recordedAudio:
        final ctrl = ref.read(prompterProvider.notifier);
        final total = ctrl.audioSeconds;
        if (total != null) return math.max(0, (total - ctrl.audioPosition.inMilliseconds / 1000).ceil());
        return (left / 2.5).ceil();
      case PromptControlMode.voice:
        return (left / _pace()).ceil();
    }
  }

  /// Words per second the reader has really been going, else a typical speaking pace (150 a minute).
  double _pace() {
    const fallback = 150 / 60;
    if (_samples.length < 2) return fallback;
    final (t1, i1) = _samples.last;
    final (t0, i0) = _samples.first;
    if (t1 - t0 < 8 || i1 - i0 < 4) return fallback;
    return (i1 - i0) / (t1 - t0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(prompterProvider.select((p) => p.playing), (_, playing) => _playing(playing));
    ref.listen(prompterProvider.select((p) => p.resetToken), (_, _) => _restarted());
    final s = ref.watch(settingsProvider);
    final pr = ref.watch(prompterProvider);
    final script = ref.watch(studioProvider.select((st) => st.script));
    final ctrl = ref.read(prompterProvider.notifier);
    final words = ctrl.wordCount;
    final percent = readingPercent(ref);
    final index = s.mode == PromptControlMode.normal
        ? ref.watch(readingWordProvider)
        : math.max(pr.progress.confirmedWordIndex, 0);

    // Narration shows where the recording is, so Back and Forward 5 s are reflected.
    final elapsed = s.mode == PromptControlMode.recordedAudio ? ctrl.audioPosition : _elapsed;
    if (s.mode == PromptControlMode.voice && pr.progress.confirmedWordIndex >= 0) {
      final t = elapsed.inMilliseconds / 1000;
      if (_samples.isEmpty || _samples.last.$2 != index) _samples.add((t, index));
      _samples.removeWhere((e) => t - e.$1 > 30);
    }
    final left = _secondsLeft(s, pr, words, index);
    // Rounded to 5 seconds so the number doesn't flicker.
    final shownLeft = pr.finished ? 0 : (left / 5).round() * 5;

    // The section being read, as its name and where it is among the others (empty without sections).
    var sectionName = '';
    var sectionOf = '';
    final run = ctrl.currentSection;
    if (run != null && s.showSections) {
      // Section by section: the section being run, as the prompter itself counts them.
      final name = run.label;
      sectionName = name.length > 18 ? '${name.substring(0, 17)}…' : name;
      sectionOf = '${run.index + 1} of ${ctrl.sections.length}';
    } else if (s.showSections) {
      final markers = sectionMarkers(script);
      final at = sectionIndexForWord(markers, index);
      if (at >= 0) {
        final name = markers[at].name;
        sectionName = name.length > 18 ? '${name.substring(0, 17)}…' : name;
        sectionOf = '${at + 1} of ${markers.length}';
      }
    }
    final section = sectionName.isEmpty ? '' : '$sectionName · $sectionOf  ·  ';
    if (widget.headsUp) {
      final cues = ctrl.cues;
      final i = pr.cueNext;
      if (i >= 0 && i < cues.length && pr.cueHolding < 0 && pr.cueNow < 0) {
        final hold = cues[i].hold;
        final color = hold ? cueQuietAmberNext : cueQuietNext;
        final base = widget.style ?? const TextStyle();
        return Text.rich(
          TextSpan(style: base, children: [
            const TextSpan(text: 'Next  '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(hold ? Icons.pause_rounded : Icons.subdirectory_arrow_right_rounded, size: 13, color: color),
            ),
            TextSpan(text: ' ${cues[i].text}', style: TextStyle(fontStyle: FontStyle.italic, color: color)),
            if (hold) TextSpan(text: '  ·  Hold', style: TextStyle(color: color)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: widget.split ? TextAlign.start : null,
        );
      }
      if (widget.hideProgress) return Text(' ', maxLines: 1, style: widget.style);
    }
    if (widget.split) {
      final base = (widget.style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
      final strong = base.copyWith(color: promptText.withValues(alpha: 0.88));
      final rest = '${widget.showElapsed ? '${_clock(elapsed.inSeconds)} elapsed  ·  ' : ''}${pr.finished ? '' : '~'}${_clock(shownLeft)} left';
      return Row(children: [
        Expanded(
          child: sectionName.isEmpty
              ? const SizedBox.shrink()
              : Text.rich(
                  TextSpan(style: base, children: [TextSpan(text: sectionName, style: strong), TextSpan(text: ' · $sectionOf')]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
        ),
        const SizedBox(width: 12),
        // Flexible, so a very large system font shortens this side instead of overflowing the row.
        Flexible(
          child: Text.rich(
            TextSpan(style: base, children: [TextSpan(text: '$percent%', style: strong), TextSpan(text: '  ·  $rest')]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ]);
    }
    return Text(
      '$section$percent%  ·  ${widget.showElapsed ? '${_clock(elapsed.inSeconds)} elapsed  ·  ' : ''}${pr.finished ? '' : '~'}${_clock(shownLeft)} left',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (widget.style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}
