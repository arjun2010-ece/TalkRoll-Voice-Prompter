import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/settings/labels.dart';
import '../../core/settings/prompt_settings.dart';
import '../../services/permissions/permissions.dart';
import '../../services/providers.dart';
import '../../ui/adaptive.dart';
import '../prompter/voice_availability.dart';
import 'onboarding_state.dart';
import 'onboarding_widgets.dart';

enum _Step { welcome, mode, voice, test, camera }

/// First run on iPhone, iPad and Android. Welcome, then how the reader wants to read; Voice and Audio go on to the
/// microphone and a live test and then the optional camera, Normal goes straight to the Studio. Every permission ask
/// has a way past it, and nothing here is needed to use Auto-scroll mode.
class MobileOnboarding extends ConsumerStatefulWidget {
  const MobileOnboarding({super.key});

  @override
  ConsumerState<MobileOnboarding> createState() => _MobileOnboardingState();
}

class _MobileOnboardingState extends ConsumerState<MobileOnboarding> with WidgetsBindingObserver {
  _Step _step = _Step.welcome;
  PromptControlMode _mode = PromptControlMode.voice;

  /// The microphone was refused (or cannot be asked again): the voice step shows how to carry on.
  bool _micOff = false;

  static const _steps = _Step.values;

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

  /// Coming back from Settings after turning the microphone on carries on to the test.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _step != _Step.voice || !_micOff) return;
    Permission.microphone.status.then((s) {
      if (mounted && s.isGranted && _micOff) {
        setState(() => _micOff = false);
        _go(_Step.test);
      }
    });
  }

  void _go(_Step s) => setState(() => _step = s);

  /// Ends the tour. [mode] becomes this session's mode; Normal when the reader skipped the voice setup.
  void _finish(PromptControlMode mode) {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(mode: mode));
    ref.read(onboardingDoneProvider.notifier).complete();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Tap "Try the sample script" to see it read. You can leave any time with the back button.'),
        duration: Duration(seconds: 6),
      ));
    });
  }

  Future<void> _askMicrophone() async {
    final status = await Permission.microphone.status;
    final granted = status.isGranted ||
        (!status.isPermanentlyDenied && !status.isRestricted &&
            await requestPermission(Permission.microphone, 'mic', ref.read(analyticsProvider)));
    if (!mounted) return;
    if (granted) {
      setState(() => _micOff = false);
      _go(_Step.test);
    } else {
      setState(() => _micOff = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_step) {
      _Step.welcome => _welcome(context),
      _Step.mode => _modePage(context),
      _Step.voice => _micOff ? _micOffPage(context) : _voicePage(context),
      _Step.test => _testPage(context),
      _Step.camera => _cameraPage(context),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(key: ValueKey('$_step$_micOff'), child: page),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Dots(count: _steps.length, at: _step.index),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Pages -----------------------------------------------------------------

  Widget _welcome(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Page(
      top: TextButton(onPressed: () => _finish(PromptControlMode.normal), child: const Text('Skip')),
      body: [
        const Spacer(),
        Text('Read to camera without looking away', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          'Your script scrolls as you speak, right where your eyes already are.',
          style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        const AutoReadingPrompt(text: 'Hi, thanks for watching. Today I want to show you how the words follow your voice.'),
        const Spacer(),
      ],
      actions: [FilledButton(onPressed: () => _go(_Step.mode), child: const Text('Get started'))],
    );
  }

  Widget _modePage(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final voiceOk = ref.watch(voiceAvailableProvider).value ?? true;
    return _Page(
      top: TextButton(onPressed: () => _finish(PromptControlMode.normal), child: const Text('Skip')),
      body: [
        Text('How do you want to read?', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('You can change this any time.', style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        _ModeCard(
          icon: Icons.mic_none,
          title: 'Voice',
          subtitle: voiceOk ? 'Follows you as you speak' : 'Not available on this device',
          selected: _mode == PromptControlMode.voice,
          enabled: voiceOk,
          onTap: () => setState(() => _mode = PromptControlMode.voice),
        ),
        const SizedBox(height: 10),
        _ModeCard(
          icon: Icons.south,
          title: autoScrollModeName,
          subtitle: 'Scrolls at a steady speed',
          selected: _mode == PromptControlMode.normal,
          onTap: () => setState(() => _mode = PromptControlMode.normal),
        ),
        const SizedBox(height: 10),
        _ModeCard(
          icon: Icons.graphic_eq,
          title: narrationModeName,
          subtitle: voiceOk ? 'Follows a recording you choose' : 'Not available on this device',
          selected: _mode == PromptControlMode.recordedAudio,
          enabled: voiceOk,
          onTap: () => setState(() => _mode = PromptControlMode.recordedAudio),
        ),
        const Spacer(),
      ],
      actions: [
        FilledButton(
          onPressed: () {
            if (_mode == PromptControlMode.normal) {
              _finish(PromptControlMode.normal);
            } else {
              _go(_Step.voice);
            }
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _voicePage(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final audio = _mode == PromptControlMode.recordedAudio;
    return _Page(
      body: [
        const Spacer(),
        const HeroIcon(Icons.mic_none),
        const SizedBox(height: 20),
        Text('Let it hear you read', textAlign: TextAlign.center, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          audio
              ? 'Narration mode listens to your recording as it plays so it can keep your place in the script.'
              : 'Voice mode listens while you read so it can keep your place in the script.',
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        ...voiceFacts(onDevice: isApple, device: 'this device'),
        const Spacer(),
      ],
      actions: [
        FilledButton(onPressed: _askMicrophone, child: const Text('Turn on microphone')),
        TextButton(onPressed: () => _finish(PromptControlMode.normal), child: const Text('Not now')),
      ],
    );
  }

  Widget _micOffPage(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Page(
      body: [
        const Spacer(),
        const HeroIcon(Icons.mic_off_outlined, warn: true),
        const SizedBox(height: 20),
        Text('Microphone is off', textAlign: TextAlign.center, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          isApple
              ? 'Voice mode follows what you say, so it needs the microphone. Turn it on in Settings, or use Auto-scroll mode, which needs nothing.'
              : 'Voice mode needs the microphone. Turn it on in the app settings, or use Auto-scroll mode, which needs nothing.',
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const Spacer(),
      ],
      actions: [
        FilledButton(onPressed: openAppSettings, child: const Text('Open Settings')),
        OutlinedButton(onPressed: () => _finish(PromptControlMode.normal), child: const Text('Use Auto-scroll mode')),
      ],
    );
  }

  Widget _testPage(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Page(
      top: TextButton(onPressed: () => _go(_Step.camera), child: const Text('Skip test')),
      body: [
        Text('Say this out loud', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('The words light up as you read them.', style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const Spacer(),
        // Audio mode needs a recording, chosen later in the Studio; the test is the same either way.
        const VoiceTest(fontSize: 24),
        const Spacer(),
      ],
      actions: [FilledButton(onPressed: () => _go(_Step.camera), child: const Text('Continue'))],
    );
  }

  Widget _cameraPage(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Page(
      body: [
        const Spacer(),
        const HeroIcon(Icons.videocam_outlined),
        const SizedBox(height: 20),
        Text('Record yourself while you read', textAlign: TextAlign.center, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          'The camera sits behind your script, so you look at the lens while you read.',
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const Spacer(),
      ],
      actions: [
        FilledButton(
          onPressed: () async {
            await requestPermission(Permission.camera, 'camera', ref.read(analyticsProvider));
            if (mounted) _finish(_mode);
          },
          child: const Text('Set up camera'),
        ),
        TextButton(onPressed: () => _finish(_mode), child: const Text('Skip for now')),
      ],
    );
  }
}

/// One tour page: an optional action at the top right, the content, and the buttons at the bottom.
class _Page extends StatelessWidget {
  const _Page({this.top, required this.body, required this.actions});
  final Widget? top;
  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(height: 48, child: Align(alignment: Alignment.centerRight, child: top)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body)),
      for (final a in actions) ...[const SizedBox(height: 8), a],
    ],
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: selected ? Colors.white : scheme.onSurface),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? scheme.primary : scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.at});
  final int count;
  final int at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == at ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == at ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
