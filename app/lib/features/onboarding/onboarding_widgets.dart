import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/script/text.dart';
import '../../core/settings/labels.dart';
import '../../core/settings/prompt_settings.dart';
import '../prompter/prompt_surface.dart' show promptBackground, promptText;
import '../prompter/prompter_controller.dart';
import 'onboarding_content.dart' show BadgeTone, GoalGlyph, OnboardingGoal;

/// Id of the prompter session the tour's voice test runs under; the Read and Record screens start their own, so
/// nothing from the test carries over.
const onboardingSessionId = -7;

/// What the voice test asks the reader to say.
const voiceTestSentence = 'Today I am testing how these words follow my voice.';

const _dim = Color(0xFF8E8E93);

/// The tour's colours in dark mode, taken from the design: a deep navy page, navy cards, a sky-blue accent with dark text
/// on the buttons, and a bluish-grey for secondary text. Light mode keeps the app's own theme. Only the tour is wrapped
/// in this; the rest of the app is untouched.
ThemeData onboardingTheme(ThemeData base) {
  if (base.brightness != Brightness.dark) return base;
  const accent = Color(0xFF5ACCFC);
  const page = Color(0xFF0C101B);
  const ink = Color(0xFF0A0E14);
  final scheme = base.colorScheme.copyWith(
    primary: accent,
    onPrimary: ink,
    primaryContainer: const Color(0xFF173D62),
    onPrimaryContainer: Colors.white,
    surface: page,
    onSurface: Colors.white,
    onSurfaceVariant: const Color(0xFFA9B4CC),
    surfaceContainerLow: const Color(0xFF111724),
    surfaceContainerHigh: const Color(0xFF141B28),
    surfaceContainerHighest: const Color(0xFF2B3447),
    outline: const Color(0xFF8A97AD),
    outlineVariant: const Color(0xFF2E394D),
    tertiary: const Color(0xFF6EE0B4),
  );
  ButtonStyle on(Color bg, Color fg) => ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? scheme.surfaceContainerHighest : bg,
    ),
    foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? scheme.outline : fg),
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    canvasColor: page,
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.merge(on(accent, ink)) ?? on(accent, ink),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.merge(ButtonStyle(foregroundColor: WidgetStatePropertyAll(accent))),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent, linearTrackColor: Color(0xFF2B3447)),
  );
}

/// The title of every tour step, one size everywhere so questions of any length sit the same way. The Welcome
/// headline uses [onboardingHero].
TextStyle? onboardingTitle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2);

TextStyle? onboardingHero(BuildContext context) =>
    Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.15);

/// A black prompter card with the words lit by [progress]; the real prompter's colours.
class PromptCard extends StatelessWidget {
  const PromptCard({super.key, required this.text, required this.confirmed, this.fontSize = 22});
  final String text;

  /// Index of the word being read, or -1 before any.
  final int confirmed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final words = scriptWords(text);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: promptBackground, borderRadius: BorderRadius.circular(16)),
      child: Text.rich(
        TextSpan(
          children: [
            for (var i = 0; i < words.length; i++)
              TextSpan(
                text: '${words[i]}${i == words.length - 1 ? '' : ' '}',
                style: TextStyle(
                  color: i < confirmed
                      ? promptText
                      : i == confirmed
                      ? Colors.orange
                      : _dim,
                ),
              ),
          ],
        ),
        style: TextStyle(fontSize: fontSize, height: 1.45, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The demo's script card: big bold words on a navy card. Words already read are dimmed, the next few ([lit]) sit in a
/// blue highlight, and the rest are white. [at] is the word being read, or -1 before the first.
class TourReadCard extends StatelessWidget {
  const TourReadCard({super.key, required this.text, required this.at, this.fontSize = 30, this.lit = 3});
  final String text;
  final int at;
  final double fontSize;
  final int lit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final words = scriptWords(text);
    final from = at < 0 ? 0 : at;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            for (var i = 0; i < words.length; i++)
              TextSpan(
                text: '${words[i]}${i == words.length - 1 ? '' : ' '}',
                style: i < at
                    ? TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.8))
                    : i >= from && i < from + lit
                    ? TextStyle(color: scheme.primary, backgroundColor: scheme.primary.withValues(alpha: 0.2))
                    : TextStyle(color: scheme.onSurface),
              ),
          ],
        ),
        style: TextStyle(fontSize: fontSize, height: 1.45, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// The line above the demo card: a microphone with live-looking bars and what is happening, or a warning.
class ListeningRow extends StatelessWidget {
  const ListeningRow({super.key, required this.message, this.icon = Icons.mic_none, this.warn = false, this.trailing});
  final String message;
  final IconData icon;
  final bool warn;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warn ? scheme.error : scheme.primary;
    return Row(
      children: [
        Icon(icon, size: 28, color: warn ? scheme.error : scheme.onSurface),
        if (!warn) ...[
          const SizedBox(width: 10),
          for (final h in const [8.0, 14.0, 10.0, 18.0, 12.0]) ...[
            Container(
              width: 3,
              height: h,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 3),
          ],
        ],
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: warn ? scheme.error : scheme.onSurface, fontWeight: FontWeight.w500),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A [PromptCard] that reads itself aloud on a loop, for the Welcome screens. It stands still when the system asks for
/// less motion.
class AutoReadingPrompt extends StatefulWidget {
  const AutoReadingPrompt({super.key, required this.text, this.fontSize = 22});
  final String text;
  final double fontSize;

  @override
  State<AutoReadingPrompt> createState() => _AutoReadingPromptState();
}

class _AutoReadingPromptState extends State<AutoReadingPrompt> {
  late final int _count = scriptWords(widget.text).length;
  late int _at = (_count * 0.45).floor();
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) return;
    _timer = Timer.periodic(const Duration(milliseconds: 520), (_) => setState(() => _at = (_at + 1) % (_count + 2)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PromptCard(text: widget.text, confirmed: _at, fontSize: widget.fontSize);
}

/// The voice test: listens through the real recogniser and lights [sentence] as it is read. Shows what went wrong when
/// it cannot listen. [onResult] reports whether listening started.
class VoiceTest extends ConsumerStatefulWidget {
  const VoiceTest({super.key, this.sentence = voiceTestSentence, this.fontSize = 22, this.onResult, this.onFinished});
  final String sentence;
  final double fontSize;

  /// Called once the test has started (true) or found it cannot (false).
  final ValueChanged<bool>? onResult;

  /// Called once the last word is read, with the reader's pace in words a minute (rounded to 5), or null when the
  /// timing was too short or too odd to trust.
  final ValueChanged<double?>? onFinished;

  @override
  ConsumerState<VoiceTest> createState() => _VoiceTestState();
}

class _VoiceTestState extends ConsumerState<VoiceTest> {
  late final PrompterController _ctrl = ref.read(prompterProvider.notifier);
  late final int _count = scriptWords(widget.sentence).length;
  DateTime? _firstHeard;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _ctrl.begin(sessionId: onboardingSessionId, script: widget.sentence, mode: PromptControlMode.voice);
    await _ctrl.play();
    if (!mounted) return;
    final s = ref.read(prompterProvider);
    widget.onResult?.call(s.playing && !s.voiceUnsupported);
  }

  @override
  void dispose() {
    // Stops the microphone; the Read screen starts its own session.
    unawaited(_ctrl.pause());
    super.dispose();
  }

  /// Times the read from the first word heard to the last.
  void _onWord(int at) {
    if (at < 0 || _finished) return;
    _firstHeard ??= DateTime.now();
    if (at < _count - 1) return;
    final ms = DateTime.now().difference(_firstHeard!).inMilliseconds;
    final wpm = ms < 500 ? null : (_count - 1) * 60000 / ms;
    setState(() => _finished = true);
    widget.onFinished?.call(wpm != null && wpm >= 80 && wpm <= 240 ? (wpm / 5).round() * 5.0 : null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(prompterProvider.select((s) => s.progress.confirmedWordIndex), (_, at) => _onWord(at));
    final s = ref.watch(prompterProvider);
    final failed = !s.playing && !s.preparing && (s.voiceUnsupported || s.status.isNotEmpty && s.status != 'Listening');
    final message = failed
        ? (s.voiceUnsupported ? 'Voice is not available on this device.' : s.status)
        : _finished
        ? 'Nice! It followed you to the last word.'
        : 'Listening…';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListeningRow(
          message: message,
          warn: failed,
          icon: failed
              ? Icons.error_outline
              : _finished
              ? Icons.check_circle_outline
              : Icons.mic_none,
        ),
        const SizedBox(height: 16),
        TourReadCard(text: widget.sentence, at: s.progress.confirmedWordIndex, fontSize: widget.fontSize),
      ],
    );
  }
}

/// The Auto-scroll demo: lights [sentence] at a steady 150 words a minute while the reader reads along, then offers a
/// replay. It finishes at once when the system asks for less motion.
class SteadyReadDemo extends StatefulWidget {
  const SteadyReadDemo({super.key, required this.sentence, this.fontSize = 22, this.onFinished});
  final String sentence;
  final double fontSize;
  final VoidCallback? onFinished;

  @override
  State<SteadyReadDemo> createState() => _SteadyReadDemoState();
}

class _SteadyReadDemoState extends State<SteadyReadDemo> {
  late final int _count = scriptWords(widget.sentence).length;
  int _at = -1;
  Timer? _timer;
  bool _started = false;

  bool get _done => _at >= _count;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) _start();
  }

  void _start() {
    _started = true;
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _at = _count;
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? widget.onFinished?.call() : null);
      return;
    }
    _at = -1;
    _timer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      setState(() => _at++);
      if (_done) {
        t.cancel();
        widget.onFinished?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListeningRow(
          icon: _done ? Icons.check_circle_outline : Icons.south,
          message: _done ? 'Done! Change the speed any time while you read.' : 'Reading along…',
          trailing: _done
              ? TextButton(
                  onPressed: () => setState(_start),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Replay'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        TourReadCard(text: widget.sentence, at: _at, fontSize: widget.fontSize),
      ],
    );
  }
}

/// A thin bar at the top of the tour showing how far along it is.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 250),
      builder: (_, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 6,
          color: scheme.primary,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

/// One answer on a question screen: an icon, the answer, and a radio (single choice) or check box ([multi]).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.icon,
    this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
    this.multi = false,
    this.tone,
  });
  final IconData icon;

  /// A drawn line icon, used instead of [icon] when given.
  final GoalGlyph? glyph;
  final String label;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  /// The badge colours; neutral when null.
  final BadgeTone? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = selected
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.14), scheme.surfaceContainerHigh)
        : scheme.surfaceContainerHigh;
    final Widget mark = multi
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: selected ? scheme.primary : scheme.outline, width: 2),
            ),
            child: selected ? Icon(Icons.check, size: 18, color: scheme.onPrimary) : null,
          )
        : Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? scheme.primary : scheme.outline,
          );
    return Semantics(
      selected: selected,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                IconBadge(icon: glyph == null ? icon : null, glyph: glyph, size: 46, tone: tone, selected: selected),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 12),
                mark,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tour's last screen: a script-with-tick graphic, "You're ready to read", and the three ways to read in one card.
class ReadyBody extends StatelessWidget {
  const ReadyBody({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const modes = [
      (GoalGlyph.micLine, BadgeTone.modeVoice, voiceModeName, 'Follows your words and waits when you pause.'),
      (GoalGlyph.autoScroll, BadgeTone.modeAuto, autoScrollModeName, 'Scrolls at the speed you set. No mic needed.'),
      (GoalGlyph.narration, BadgeTone.modeNarration, narrationModeName, "Syncs your script to a recording you've made."),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: ReadyDocIcon()),
        const SizedBox(height: 22),
        Text("You're ready to read", textAlign: TextAlign.center, style: onboardingHero(context)),
        const SizedBox(height: 32),
        Text('Three ways to read', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant, width: 1.5),
          ),
          child: Column(
            children: [
              for (final (i, m) in modes.indexed) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(glyph: m.$1, size: 62, tone: m.$2),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.$3, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(m.$4, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.3, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('You can switch modes anytime.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

/// A script page with a tick badge: the "ready" graphic. Blue-grey outline and lines with one lit line on dark; the
/// theme's own colours on light.
class ReadyDocIcon extends StatelessWidget {
  const ReadyDocIcon({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(124, 134),
    painter: _ReadyDocPainter(
      dark: Theme.of(context).brightness == Brightness.dark,
      scheme: Theme.of(context).colorScheme,
    ),
  );
}

class _ReadyDocPainter extends CustomPainter {
  _ReadyDocPainter({required this.dark, required this.scheme});
  final bool dark;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final border = dark ? const Color(0xFF6784B3) : scheme.outline;
    final fill = dark ? const Color(0xFF10192D) : scheme.surfaceContainerHigh;
    final line = dark ? const Color(0xFF667894) : scheme.outlineVariant;
    final lit = scheme.primary;
    final doc = RRect.fromRectAndRadius(const Rect.fromLTWH(2, 2, 116, 120), const Radius.circular(28));
    canvas.drawRRect(doc, Paint()..color = fill);
    canvas.drawRRect(doc, Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = 3.5);
    Paint stroke(Color c, double w) => Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round;
    for (final (y, x1, c, w) in [(24.0, 92.0, line, 6.0), (42.0, 68.0, line, 6.0), (60.0, 96.0, lit, 7.0), (78.0, 82.0, line, 6.0), (96.0, 66.0, line, 6.0)]) {
      canvas.drawLine(Offset(26, y), Offset(x1, y), stroke(c, w));
    }
    // The tick badge, overlapping the page's corner.
    const centre = Offset(98, 108);
    canvas.drawCircle(centre, 24, Paint()..color = scheme.surface);
    canvas.drawCircle(centre, 21, Paint()..color = lit);
    canvas.drawPath(
      Path()..moveTo(88, 108)..lineTo(95, 115)..lineTo(109, 100),
      stroke(scheme.onPrimary, 5),
    );
  }

  @override
  bool shouldRepaint(_ReadyDocPainter old) => old.dark != dark || old.scheme != scheme;
}

/// A short "getting it ready" pause: a pulsing icon and [lines] ticking in one by one, then [onDone]. It only paces the
/// tour; nothing is loading.
class ProcessingView extends StatefulWidget {
  const ProcessingView({
    super.key,
    required this.title,
    required this.lines,
    required this.onDone,
    this.icon = Icons.auto_awesome_outlined,
  });
  final String title;
  final List<String> lines;
  final VoidCallback onDone;
  final IconData icon;

  @override
  State<ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<ProcessingView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Timer? _timer;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 550), (t) {
      if (_shown < widget.lines.length) {
        setState(() => _shown++);
        return;
      }
      t.cancel();
      widget.onDone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(_pulse), child: HeroIcon(widget.icon)),
        const SizedBox(height: 20),
        Text(widget.title, textAlign: TextAlign.center, style: onboardingTitle(context)),
        const SizedBox(height: 24),
        Center(
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.lines.length; i++)
                  AnimatedOpacity(
                    opacity: i < _shown ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CheckLine(widget.lines[i], large: true),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The goal question's answers as a grid of cards: a coloured icon badge, a short label and a hint, with a check on the
/// one picked, in two columns.
class GoalGrid extends StatelessWidget {
  const GoalGrid({super.key, required this.goals, required this.selected, required this.onPick});
  final List<OnboardingGoal> goals;
  final String? selected;
  final ValueChanged<OnboardingGoal> onPick;

  @override
  Widget build(BuildContext context) {
    const columns = 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < goals.length; r += columns) ...[
          if (r > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = r; i < r + columns; i++) ...[
                  if (i > r) const SizedBox(width: 12),
                  Expanded(
                    child: i < goals.length
                        ? _GoalCard(goal: goals[i], selected: goals[i].id == selected, onTap: () => onPick(goals[i]))
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.selected, required this.onTap});
  final OnboardingGoal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${goal.label}, ${goal.hint}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(glyph: goal.glyph, size: 56, tone: goal.tone),
                      const SizedBox(height: 14),
                      Text(
                        goal.label,
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(goal.hint, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.check_circle, size: 22, color: scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded-square badge holding a goal's line icon ([glyph], in its [tone]: the design's colours) or an ordinary
/// [icon]. Without a tone it is neutral grey and turns to the accent when [selected].
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, this.icon, this.glyph, this.size = 40, this.tone, this.selected = false})
    : assert(icon != null || glyph != null);
  final IconData? icon;
  final GoalGlyph? glyph;
  final double size;
  final BadgeTone? tone;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final t = tone;
    final fg = t?.icon(brightness) ?? (selected ? scheme.primary : scheme.onSurfaceVariant);
    final bg =
        t?.badge(brightness) ?? (selected ? scheme.primary.withValues(alpha: 0.18) : scheme.surfaceContainerHighest);
    final g = glyph;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.22)),
      child: g != null ? CustomPaint(painter: GoalGlyphPainter(g, fg)) : Icon(icon, size: size * 0.5, color: fg),
    );
  }
}

/// Draws a [GoalGlyph] as a line icon traced from the design: round-capped strokes laid out on the design's 110-unit
/// badge, scaled to the badge it fills and centred in it.
class GoalGlyphPainter extends CustomPainter {
  GoalGlyphPainter(this.glyph, this.color);
  final GoalGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The goal icons are laid out on a 110-unit badge, the question-list icons on a 90-unit one.
    final list = glyph.index >= GoalGlyph.eye.index;
    final box = list ? 90.0 : 110.0;
    final (path, bounds) = _shape(glyph);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = glyph.index >= GoalGlyph.autoScroll.index ? 4 : list ? 5.5 : 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.width / box, size.height / box);
    canvas.translate(box / 2 - bounds.center.dx, box / 2 - bounds.center.dy);
    canvas.drawPath(path, stroke);
    canvas.restore();
  }

  static (Path, Rect) _shape(GoalGlyph g) => switch (g) {
    // A film camera: two reels on top, the body, and the lens on the right.
    GoalGlyph.movieCamera => (
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(27, 33), radius: 9))
        ..addOval(Rect.fromCircle(center: const Offset(53, 33), radius: 9))
        ..addRRect(RRect.fromLTRBR(18, 46, 60, 76, const Radius.circular(6)))
        ..moveTo(60, 54)
        ..lineTo(78, 47)
        ..lineTo(78, 75)
        ..lineTo(60, 68),
      const Rect.fromLTRB(18, 24, 78, 76),
    ),
    // A mortarboard: the diamond top, the cap below it, and the tassel on the right.
    GoalGlyph.mortarboard => (
      Path()
        ..moveTo(48, 21)
        ..lineTo(80, 38)
        ..lineTo(48, 55)
        ..lineTo(16, 38)
        ..close()
        ..moveTo(28, 44.5)
        ..lineTo(28, 62)
        ..arcToPoint(const Offset(68, 62), radius: const Radius.elliptical(20, 13), clockwise: false)
        ..lineTo(68, 44.5)
        ..moveTo(80, 38)
        ..lineTo(80, 60),
      const Rect.fromLTRB(16, 21, 80, 75),
    ),
    // A presentation board on a stand, with a rising bar chart.
    GoalGlyph.easel => (
      Path()
        ..moveTo(15, 21)
        ..lineTo(79, 21)
        ..moveTo(21, 21)
        ..lineTo(21, 60)
        ..quadraticBezierTo(21, 65, 26, 65)
        ..lineTo(68, 65)
        ..quadraticBezierTo(73, 65, 73, 60)
        ..lineTo(73, 21)
        ..moveTo(37, 54)
        ..lineTo(37, 49)
        ..moveTo(47, 54)
        ..lineTo(47, 41)
        ..moveTo(57, 54)
        ..lineTo(57, 33)
        ..moveTo(47, 65)
        ..lineTo(47, 78)
        ..moveTo(47, 68)
        ..lineTo(34, 81)
        ..moveTo(47, 68)
        ..lineTo(60, 81),
      const Rect.fromLTRB(15, 21, 79, 81),
    ),
    // A handheld microphone held at an angle: the round head and the handle, with its band against the head.
    GoalGlyph.handheldMic => (
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(61, 34), radius: 14))
        ..moveTo(47.7, 38.5)
        ..lineTo(25.1, 66.4)
        ..arcToPoint(const Offset(36.8, 75.9), radius: const Radius.circular(7.5), clockwise: false)
        ..lineTo(59.4, 47.9)
        ..close(),
      const Rect.fromLTRB(18, 20, 75, 79),
    ),
    // A studio microphone: the capsule with its grille marks, the holder, the stem and the base.
    GoalGlyph.studioMic => (
      Path()
        ..addRRect(
          RRect.fromLTRBAndCorners(
            34,
            17,
            62,
            64,
            topLeft: const Radius.circular(9),
            topRight: const Radius.circular(9),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          ),
        )
        ..moveTo(34, 29)
        ..lineTo(42, 29)
        ..moveTo(54, 29)
        ..lineTo(62, 29)
        ..moveTo(34, 39)
        ..lineTo(42, 39)
        ..moveTo(54, 39)
        ..lineTo(62, 39)
        ..moveTo(34, 49)
        ..lineTo(42, 49)
        ..moveTo(54, 49)
        ..lineTo(62, 49)
        ..moveTo(24, 45)
        ..lineTo(24, 50)
        ..cubicTo(24, 63, 34.5, 72, 48, 72)
        ..cubicTo(61.5, 72, 72, 63, 72, 50)
        ..lineTo(72, 45)
        ..moveTo(48, 72)
        ..lineTo(48, 81)
        ..moveTo(36, 81)
        ..lineTo(60, 81),
      const Rect.fromLTRB(24, 17, 72, 81),
    ),
    // Three four-pointed sparkles: a large one, a medium one to the right, a small one below.
    GoalGlyph.sparkles => (
      Path()
        ..addPath(_sparkle(const Offset(35, 32), 16, 16), Offset.zero)
        ..addPath(_sparkle(const Offset(67, 48), 14, 15), Offset.zero)
        ..addPath(_sparkle(const Offset(44, 68), 11, 11), Offset.zero),
      const Rect.fromLTRB(19, 16, 81, 79),
    ),
    // Two people, for calls and meetings.
    GoalGlyph.people => (
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(40, 36), radius: 10))
        ..moveTo(20, 76)
        ..lineTo(20, 72)
        ..cubicTo(20, 61, 29, 54, 40, 54)
        ..cubicTo(51, 54, 60, 61, 60, 72)
        ..lineTo(60, 76)
        ..addOval(Rect.fromCircle(center: const Offset(67, 37), radius: 8))
        ..moveTo(65, 54)
        ..cubicTo(74, 55, 80, 62, 80, 71)
        ..lineTo(80, 76),
      const Rect.fromLTRB(20, 26, 80, 76),
    ),
    // An eye: the almond outline with the iris ring.
    GoalGlyph.eye => _fit(
      Path()
        ..moveTo(20, 44)
        ..cubicTo(30, 24, 60, 24, 70, 44)
        ..cubicTo(60, 64, 30, 64, 20, 44)
        ..addOval(Rect.fromCircle(center: const Offset(45, 44), radius: 8)),
    ),
    // Three lines of text, the last two shorter, with a tick on the right.
    GoalGlyph.listCheck => _fit(
      Path()
        ..moveTo(22, 24.5)
        ..lineTo(68, 24.5)
        ..moveTo(22, 41)
        ..lineTo(48, 41)
        ..moveTo(22, 57.5)
        ..lineTo(40, 57.5)
        ..moveTo(50, 50)
        ..lineTo(57, 57)
        ..lineTo(69, 43),
    ),
    // A circular arrow, round the bottom and up the left to an arrowhead.
    GoalGlyph.retake => _fit(_arcArrow(const Offset(45, 47), 18, -0.7, 4.7)),
    // A speedometer: an open ring over the top, with the needle and its hub.
    GoalGlyph.gauge => _fit(
      Path()
        ..addArc(Rect.fromCircle(center: const Offset(45, 50), radius: 24), 2.62, 4.19)
        ..moveTo(45, 52)
        ..lineTo(58, 40),
    ),
    // An open book: two pages meeting at the spine.
    GoalGlyph.book => _fit(
      Path()
        ..moveTo(45, 37)
        ..cubicTo(40, 31, 31, 30, 21, 33)
        ..lineTo(21, 60)
        ..cubicTo(31, 57, 40, 58, 45, 63)
        ..cubicTo(50, 58, 59, 57, 69, 60)
        ..lineTo(69, 33)
        ..cubicTo(59, 30, 50, 31, 45, 37)
        ..moveTo(45, 37)
        ..lineTo(45, 63),
    ),
    // An arrow down onto two lines: scrolling at a steady pace.
    GoalGlyph.autoScroll => _fit(
      Path()
        ..moveTo(45, 22)
        ..lineTo(45, 50)
        ..moveTo(34, 40)
        ..lineTo(45, 51)
        ..lineTo(56, 40)
        ..moveTo(29, 60)
        ..lineTo(61, 60)
        ..moveTo(29, 68)
        ..lineTo(61, 68),
    ),
    // Sound bars beside a play triangle: following a recording.
    GoalGlyph.narration => _fit(
      Path()
        ..moveTo(18, 40)
        ..lineTo(18, 52)
        ..moveTo(27, 30)
        ..lineTo(27, 62)
        ..moveTo(36, 22)
        ..lineTo(36, 70)
        ..moveTo(45, 32)
        ..lineTo(45, 60)
        ..moveTo(55, 33)
        ..lineTo(70, 46)
        ..lineTo(55, 59)
        ..close(),
    ),
    // A microphone: the capsule, its holder and the stem.
    GoalGlyph.micLine => _fit(
      Path()
        ..addRRect(RRect.fromLTRBR(35, 16, 55, 48, const Radius.circular(10)))
        ..moveTo(28, 40)
        ..cubicTo(28, 56, 36, 63, 45, 63)
        ..cubicTo(54, 63, 62, 56, 62, 40)
        ..moveTo(45, 63)
        ..lineTo(45, 74),
    ),
    // Five sound bars, tallest in the middle.
    GoalGlyph.waveform => _fit(
      Path()
        ..moveTo(23, 44)
        ..lineTo(23, 50)
        ..moveTo(34, 38)
        ..lineTo(34, 59)
        ..moveTo(45, 29)
        ..lineTo(45, 65)
        ..moveTo(56, 38)
        ..lineTo(56, 59)
        ..moveTo(67, 44)
        ..lineTo(67, 50),
    ),
  };

  /// [p] with its own bounds, for the icons drawn by shape rather than a measured box.
  static (Path, Rect) _fit(Path p) => (p, p.getBounds());

  /// An arc with an arrowhead at its end, for the retake icon: the circle's centre [c], radius [r], from angle [from]
  /// sweeping [sweep] radians clockwise.
  static Path _arcArrow(Offset c, double r, double from, double sweep) {
    final path = Path()..addArc(Rect.fromCircle(center: c, radius: r), from, sweep);
    final end = from + sweep;
    final tip = c + Offset(math.cos(end), math.sin(end)) * r;
    // Straight back along the way the arc came, then out to each side.
    final back = math.atan2(-math.cos(end), math.sin(end)) + 0;
    for (final side in const [-1, 1]) {
      final a = back + side * 0.75;
      path
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + math.cos(a) * 11, tip.dy + math.sin(a) * 11);
    }
    return path;
  }

  /// A four-pointed sparkle with curved, pinched sides.
  static Path _sparkle(Offset c, double w, double h) {
    const k = 0.16;
    return Path()
      ..moveTo(c.dx, c.dy - h)
      ..quadraticBezierTo(c.dx + w * k, c.dy - h * k, c.dx + w, c.dy)
      ..quadraticBezierTo(c.dx + w * k, c.dy + h * k, c.dx, c.dy + h)
      ..quadraticBezierTo(c.dx - w * k, c.dy + h * k, c.dx - w, c.dy)
      ..quadraticBezierTo(c.dx - w * k, c.dy - h * k, c.dx, c.dy - h)
      ..close();
  }

  @override
  bool shouldRepaint(GoalGlyphPainter old) => old.glyph != glyph || old.color != color;
}

/// An illustrated camera preview (drawn in code, so it is original artwork): a person smiling at the lens in a warm
/// room, with the prompter bar sitting just under the lens and a line of script in it. [line] is the script text.
class LensPreview extends StatelessWidget {
  const LensPreview({super.key, this.line = "Today, we'll keep it simple."});
  final String line;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Example camera preview with the script just below the lens',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _RoomPainter())),
                  // The lens.
                  Positioned(
                    top: w * 0.026,
                    left: w * 0.5 - w * 0.02,
                    child: Container(
                      width: w * 0.04,
                      height: w * 0.04,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.6),
                      ),
                    ),
                  ),
                  // The prompter bar, as it sits in the camera view.
                  Positioned(
                    top: w * 0.092,
                    left: w * 0.15,
                    width: w * 0.7,
                    height: w * 0.15,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(w * 0.04),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              line,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: w * 0.05,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                          ),
                          SizedBox(height: w * 0.014),
                          Container(
                            width: w * 0.28,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5BC3FC),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The room and the person behind [LensPreview]: flat shapes in warm light, with a window, a plant, a shelf and lamp.
class _RoomPainter extends CustomPainter {
  const _RoomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Paint fill(Color c) => Paint()..color = c;
    Offset o(double x, double y) => Offset(x * w, y * h);

    // Wall, lit from the left.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD8C6AE), Color(0xFF8F7458)],
        ).createShader(Offset.zero & size),
    );
    // Window light on the wall.
    for (final r in [
      Rect.fromLTWH(0.03 * w, 0.28 * h, 0.1 * w, 0.3 * h),
      Rect.fromLTWH(0.15 * w, 0.3 * h, 0.1 * w, 0.28 * h),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), fill(Colors.white.withValues(alpha: 0.3)));
    }
    // Shelf and lamp on the right.
    canvas.drawRect(Rect.fromLTWH(0.74 * w, 0.58 * h, 0.26 * w, 0.02 * h), fill(const Color(0xFF7A5F44)));
    canvas.drawRect(Rect.fromLTWH(0.78 * w, 0.5 * h, 0.03 * w, 0.08 * h), fill(const Color(0xFFB98F63)));
    canvas.drawRect(Rect.fromLTWH(0.82 * w, 0.46 * h, 0.025 * w, 0.12 * h), fill(const Color(0xFF8C6A4A)));
    canvas.drawRect(Rect.fromLTWH(0.9 * w, 0.78 * h, 0.012 * w, 0.1 * h), fill(const Color(0xFF6B5339)));
    canvas.drawPath(
      Path()
        ..moveTo(0.86 * w, 0.78 * h)
        ..lineTo(0.95 * w, 0.78 * h)
        ..lineTo(0.93 * w, 0.7 * h)
        ..lineTo(0.88 * w, 0.7 * h)
        ..close(),
      fill(const Color(0xFFF3E2C2)),
    );
    // Plants.
    for (final (x, y, rx, ry, rot, c) in [
      (0.9, 0.3, 0.05, 0.1, 0.4, Color(0xFF3F6B3C)),
      (0.86, 0.2, 0.04, 0.09, -0.5, Color(0xFF2F5530)),
      (0.94, 0.42, 0.04, 0.09, 0.2, Color(0xFF355F36)),
      (0.04, 0.72, 0.05, 0.1, -0.5, Color(0xFF3F6B3C)),
      (0.09, 0.8, 0.04, 0.08, 0.5, Color(0xFF2F5530)),
    ]) {
      canvas.save();
      canvas.translate(x * w, y * h);
      canvas.rotate(rot);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2 * w, height: ry * 2 * h), fill(c));
      canvas.restore();
    }

    // Hair behind the head.
    const hair = Color(0xFF45291D);
    canvas.drawPath(
      Path()
        ..moveTo(0.2 * w, 0.95 * h)
        ..cubicTo(0.13 * w, 0.62 * h, 0.2 * w, 0.28 * h, 0.5 * w, 0.26 * h)
        ..cubicTo(0.8 * w, 0.28 * h, 0.87 * w, 0.62 * h, 0.8 * w, 0.95 * h)
        ..close(),
      fill(hair),
    );
    // Neck and sweater.
    const skin = Color(0xFFE8B896);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(0.44 * w, 0.64 * h, 0.56 * w, 0.8 * h), Radius.circular(0.03 * w)),
      fill(const Color(0xFFD29C7C)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0.04 * w, h)
        ..cubicTo(0.08 * w, 0.8 * h, 0.28 * w, 0.76 * h, 0.5 * w, 0.77 * h)
        ..cubicTo(0.72 * w, 0.76 * h, 0.92 * w, 0.8 * h, 0.96 * w, h)
        ..close(),
      fill(const Color(0xFF2A2A2D)),
    );
    canvas.drawArc(
      Rect.fromCenter(center: o(0.5, 0.775), width: 0.26 * w, height: 0.06 * h),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF3B3B40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.014 * w,
    );
    // Face.
    canvas.drawOval(Rect.fromCenter(center: o(0.5, 0.53), width: 0.3 * w, height: 0.38 * h), fill(skin));
    // Cheeks.
    for (final x in [0.4, 0.6]) {
      canvas.drawOval(
        Rect.fromCenter(center: o(x, 0.6), width: 0.06 * w, height: 0.035 * h),
        fill(const Color(0xFFE59C86).withValues(alpha: 0.45)),
      );
    }
    // Hair over the forehead, parted to one side.
    canvas.drawPath(
      Path()
        ..moveTo(0.34 * w, 0.54 * h)
        ..cubicTo(0.32 * w, 0.32 * h, 0.44 * w, 0.28 * h, 0.54 * w, 0.3 * h)
        ..cubicTo(0.63 * w, 0.32 * h, 0.69 * w, 0.38 * h, 0.66 * w, 0.54 * h)
        ..cubicTo(0.64 * w, 0.44 * h, 0.58 * w, 0.39 * h, 0.5 * w, 0.385 * h)
        ..cubicTo(0.42 * w, 0.39 * h, 0.36 * w, 0.44 * h, 0.34 * w, 0.54 * h)
        ..close(),
      fill(const Color(0xFF5A3826)),
    );
    // Eyes and brows.
    for (final x in [0.43, 0.57]) {
      canvas.drawOval(Rect.fromCenter(center: o(x, 0.5), width: 0.062 * w, height: 0.03 * h), fill(Colors.white));
      canvas.drawCircle(o(x, 0.5), 0.011 * w, fill(const Color(0xFF6A4630)));
      canvas.drawCircle(o(x, 0.5), 0.005 * w, fill(const Color(0xFF1E140E)));
      canvas.drawArc(
        Rect.fromCenter(center: o(x, 0.46), width: 0.075 * w, height: 0.04 * h),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        Paint()
          ..color = const Color(0xFF3A2418)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.008 * w
          ..strokeCap = StrokeCap.round,
      );
    }
    // Nose and smile.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.007 * w;
    canvas.drawPath(
      Path()
        ..moveTo(0.5 * w, 0.52 * h)
        ..quadraticBezierTo(0.485 * w, 0.57 * h, 0.5 * w, 0.585 * h),
      line..color = const Color(0xFFC48A6C),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0.44 * w, 0.64 * h)
        ..quadraticBezierTo(0.5 * w, 0.685 * h, 0.56 * w, 0.64 * h)
        ..quadraticBezierTo(0.5 * w, 0.655 * h, 0.44 * w, 0.64 * h),
      fill(const Color(0xFFC4605F)),
    );
    // Earrings.
    for (final x in [0.349, 0.651]) {
      canvas.drawCircle(o(x, 0.6), 0.007 * w, fill(const Color(0xFFD9A441)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// A round-cornered tile holding one big icon, at the top of the permission steps.
class HeroIcon extends StatelessWidget {
  const HeroIcon(this.icon, {super.key, this.warn = false});
  final IconData icon;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: warn ? scheme.tertiaryContainer : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, size: 40, color: warn ? scheme.onTertiaryContainer : scheme.primary),
      ),
    );
  }
}

/// A check-marked line in the "what happens with your voice" list.
class CheckLine extends StatelessWidget {
  const CheckLine(this.text, {super.key, this.large = false});
  final String text;

  /// Body-large text, for the processing checklist where the lines are the whole screen.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.check, size: large ? 18 : 16, color: scheme.tertiary),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            style: large ? Theme.of(context).textTheme.bodyLarge : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// The "what happens with your voice" lines, shared by the phone and desktop voice steps. [device] names where
/// speech is processed ("this Mac", "this device"). On Android the system recogniser may use the network.
List<String> voiceFacts({required bool onDevice, required String device}) => [
  'Active during Voice Mode sessions',
  "Voice Mode doesn't save your audio",
  onDevice
      ? 'Speech is processed on-device when supported.'
      : "Your phone's speech service does the listening and may process audio online.",
];

/// A shield, "Microphone privacy" and its plain lines, for the permission steps.
class PrivacyBlock extends StatelessWidget {
  const PrivacyBlock({super.key, required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 28, color: scheme.primary),
            const SizedBox(width: 12),
            Text(
              'Microphone privacy',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        for (final l in lines) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(l, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ],
    );
  }
}
