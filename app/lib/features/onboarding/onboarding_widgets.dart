import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/script/text.dart';
import '../../core/settings/prompt_settings.dart';
import '../prompter/prompt_surface.dart' show promptBackground, promptText;
import '../prompter/prompter_controller.dart';

/// Id of the prompter session the tour's voice test runs under; the Read and Record screens start their own, so
/// nothing from the test carries over.
const onboardingSessionId = -7;

/// What the voice test asks the reader to say.
const voiceTestSentence = 'Today I am testing how these words follow my voice.';

const _dim = Color(0xFF8E8E93);

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
                style: TextStyle(color: i < confirmed ? promptText : i == confirmed ? Colors.orange : _dim),
              ),
          ],
        ),
        style: TextStyle(fontSize: fontSize, height: 1.45, fontWeight: FontWeight.w600),
      ),
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

/// The voice test: listens through the real recogniser and lights [voiceTestSentence] as it is read. Shows what went
/// wrong when it cannot listen. [onReady] reports whether listening started.
class VoiceTest extends ConsumerStatefulWidget {
  const VoiceTest({super.key, this.fontSize = 22, this.onResult});
  final double fontSize;

  /// Called once the test has started (true) or found it cannot (false).
  final ValueChanged<bool>? onResult;

  @override
  ConsumerState<VoiceTest> createState() => _VoiceTestState();
}

class _VoiceTestState extends ConsumerState<VoiceTest> {
  late final PrompterController _ctrl = ref.read(prompterProvider.notifier);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _ctrl.begin(sessionId: onboardingSessionId, script: voiceTestSentence, mode: PromptControlMode.voice);
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(prompterProvider);
    final heard = s.progress.confirmedWordIndex >= 0;
    final failed = !s.playing && !s.preparing && (s.voiceUnsupported || s.status.isNotEmpty && s.status != 'Listening');
    final Color tint = failed ? scheme.errorContainer : heard ? scheme.tertiary.withValues(alpha: 0.16) : scheme.surfaceContainerHighest;
    final Color fg = failed ? scheme.onErrorContainer : heard ? scheme.tertiary : scheme.onSurfaceVariant;
    final message = failed
        ? (s.voiceUnsupported ? 'Voice is not available on this device.' : s.status)
        : heard
        ? 'Your voice is coming through'
        : 'Listening… say the sentence above';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PromptCard(text: voiceTestSentence, confirmed: s.progress.confirmedWordIndex, fontSize: widget.fontSize),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(failed ? Icons.error_outline : heard ? Icons.check_circle_outline : Icons.graphic_eq, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: TextStyle(color: fg, fontSize: 13))),
            ],
          ),
        ),
      ],
    );
  }
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
  const CheckLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.check, size: 16, color: scheme.tertiary)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}

/// The "what happens with your voice" lines, shared by the phone and desktop voice steps. [device] names where
/// speech is processed ("this Mac", "this device"). On Android the system recogniser may use the network.
List<Widget> voiceFacts({required bool onDevice, required String device}) => [
  const CheckLine("Only listens while you're reading"),
  const SizedBox(height: 10),
  const CheckLine("Voice mode doesn't save your audio"),
  const SizedBox(height: 10),
  CheckLine(
    onDevice
        ? 'Speech is processed on $device when it supports it'
        : "Your phone's speech service does the listening and may process audio online",
  ),
];
