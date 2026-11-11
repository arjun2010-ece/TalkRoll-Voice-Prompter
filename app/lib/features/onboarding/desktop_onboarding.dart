import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/prompt_settings.dart';
import '../../services/platform.dart';
import '../../services/providers.dart';
import '../../ui/position_picker.dart';
import '../prompter/prompter_controller.dart' show audioInputProvider;
import 'onboarding_state.dart';
import 'onboarding_widgets.dart';

/// First run on macOS and Windows, in the Studio window: Welcome, where the prompter sits, then Voice. Voice is
/// optional; skipping it, or a refused microphone, leaves the app in Normal mode.
class DesktopOnboarding extends ConsumerStatefulWidget {
  const DesktopOnboarding({super.key});

  @override
  ConsumerState<DesktopOnboarding> createState() => _DesktopOnboardingState();
}

class _DesktopOnboardingState extends ConsumerState<DesktopOnboarding> with WidgetsBindingObserver {
  int _step = 0;

  /// Voice step: the microphone was allowed and the test is listening.
  bool _testing = false;
  bool _listening = false;
  bool _micOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from System Settings after turning the microphone on carries on to the test.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_micOff) return;
    ref.read(audioInputProvider).hasPermission().then((granted) {
      if (mounted && granted && _micOff) setState(() { _micOff = false; _testing = true; });
    });
  }

  void _finish() {
    final voice = _testing && _listening;
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(mode: voice ? PromptControlMode.voice : PromptControlMode.normal));
    ref.read(onboardingDoneProvider.notifier).complete();
  }

  Future<void> _askMicrophone() async {
    final granted = await ref.read(audioInputProvider).hasPermission();
    if (!mounted) return;
    setState(() {
      _micOff = !granted;
      _testing = granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final title = text.headlineMedium?.copyWith(fontWeight: FontWeight.w700);
    final pane = switch (_step) {
      0 => Column(mainAxisSize: MainAxisSize.min, children: [
        const AutoReadingPrompt(text: "Hi, thanks for joining. Let's get started.", fontSize: 20),
        const SizedBox(height: 28),
        Text('Read your script right under the camera', textAlign: TextAlign.center, style: title),
        const SizedBox(height: 10),
        Text(
          'A floating prompter sits at the top of your screen, so you keep eye contact on calls and recordings.',
          textAlign: TextAlign.center,
          style: muted,
        ),
      ]),
      1 => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Where should the prompter sit?', textAlign: TextAlign.center, style: title),
        const SizedBox(height: 20),
        const PositionPicker(),
        const SizedBox(height: 14),
        Text(
          'Placing the prompter right under the camera helps you keep eye contact. It is hidden from most screen sharing apps, though not guaranteed in all of them.',
          textAlign: TextAlign.center,
          style: muted,
        ),
      ]),
      _ => _voice(context, title, muted),
    };
    final last = _step == 2;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: pane),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Text('${_step + 1} of 3', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const Spacer(),
                if (_step == 0) TextButton(onPressed: _finish, child: const Text('Skip')),
                if (_step > 0 && !_testing) TextButton(onPressed: () => setState(() { _step--; _micOff = false; }), child: const Text('Back')),
                if (last && !_testing && !_micOff) TextButton(onPressed: _finish, child: const Text('Not now')),
                const SizedBox(width: 8),
                if (!last) FilledButton(onPressed: () => setState(() => _step++), child: const Text('Continue')),
                if (last && !_testing && !_micOff) FilledButton(onPressed: _askMicrophone, child: Text(isMacOS ? 'Continue' : 'Turn on microphone')),
                if (last && _micOff) FilledButton(onPressed: _finish, child: const Text('Continue in Auto-scroll mode')),
                if (last && _testing) FilledButton(onPressed: _finish, child: const Text('Finish')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _voice(BuildContext context, TextStyle? title, TextStyle? muted) {
    final device = isMacOS ? 'this Mac' : 'this PC';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeroIcon(_micOff ? Icons.mic_off_outlined : Icons.mic_none, warn: _micOff),
        const SizedBox(height: 20),
        Text(_micOff ? 'Microphone is off' : 'Let it hear you read', textAlign: TextAlign.center, style: title),
        const SizedBox(height: 10),
        if (_micOff)
          Text(
            isMacOS
                ? 'Voice mode follows what you say, so it needs the microphone. Turn it on in System Settings → Privacy & Security → Microphone, or carry on in Auto-scroll mode.'
                : 'Voice mode follows what you say, so it needs the microphone. Turn it on in Settings → Privacy → Microphone, or carry on in Auto-scroll mode.',
            textAlign: TextAlign.center,
            style: muted,
          )
        else if (!_testing) ...[
          Text(
            "Voice mode listens while you read so it can keep your place. It doesn't save your audio, and speech is processed on $device when it supports it.",
            textAlign: TextAlign.center,
            style: muted,
          ),
        ] else ...[
          Text('Say this out loud to see the words light up.', textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 20),
          VoiceTest(fontSize: 20, onResult: (ok) => setState(() => _listening = ok)),
        ],
      ],
    );
  }
}
