import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/entitlements/entitlements.dart';
import '../../core/settings/prompt_settings.dart';
import '../../services/permissions/permissions.dart';
import '../../services/providers.dart';
import '../../ui/adaptive.dart';
import '../pro/paywall_dialog.dart';
import '../pro/pro_state.dart';
import '../prompter/voice_availability.dart';
import 'onboarding_content.dart';
import 'onboarding_state.dart';
import 'onboarding_widgets.dart';

enum _Step { welcome, goal, pains, solution, voice, preparing, demo, result }

/// Steps with a Skip at the top. The microphone step has its own "Not now", the pause has no buttons, and the result
/// has its own choice.
const _skippable = {_Step.welcome, _Step.goal, _Step.pains, _Step.solution, _Step.demo};

/// First run on iPhone, iPad and Android. Two quick questions (what the reader is getting ready for, what gets in the
/// way) shape a "here's how TalkRoll helps" screen and the practice line. Then the microphone, a live read of that line
/// in Voice mode (Auto-scroll without the microphone), the result with the three modes explained, and the plans. The
/// tour never saves a script, so it never uses one of the free scripts. The camera is asked for on the Record screen, when it is needed. Nothing here is needed to use
/// Auto-scroll mode.
class MobileOnboarding extends ConsumerStatefulWidget {
  const MobileOnboarding({super.key});

  @override
  ConsumerState<MobileOnboarding> createState() => _MobileOnboardingState();
}

class _MobileOnboardingState extends ConsumerState<MobileOnboarding> with WidgetsBindingObserver {
  _Step _step = _Step.welcome;

  /// Steps visited before this one, for Back.
  final _history = <_Step>[];

  OnboardingGoal? _goal;
  final _pains = <String>{};

  /// The microphone was refused (or cannot be asked again): the voice step shows how to carry on.
  bool _micOff = false;

  /// The microphone is allowed, so the demo listens and the reader ends in Voice mode.
  bool _micReady = false;

  /// Words a minute from the voice demo, when it measured one.
  double? _pace;

  /// The plans are open, so a second tap on the result's button does nothing.
  bool _completing = false;

  OnboardingGoal get _g => _goal ?? mobileGoals.last;

  bool get _voiceOk => ref.read(voiceAvailableProvider).value ?? true;

  /// The steps this run will show, for the progress bar. A device without speech recognition has no microphone step.
  List<_Step> get _path => [
    _Step.welcome,
    _Step.goal,
    _Step.pains,
    _Step.solution,
    if (_voiceOk) _Step.voice,
    _Step.preparing,
    _Step.demo,
    _Step.result,
  ];

  PromptControlMode get _finalMode => _micReady ? PromptControlMode.voice : PromptControlMode.normal;

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

  /// Coming back from Settings after turning the microphone on carries on to the demo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _step != _Step.voice || !_micOff) return;
    Permission.microphone.status.then((s) {
      if (mounted && s.isGranted && _micOff && _step == _Step.voice) {
        setState(() {
          _micOff = false;
          _micReady = true;
        });
        _go(_Step.preparing);
      }
    });
  }

  void _go(_Step s) => setState(() {
    _history.add(_step);
    _step = s;
    if (s == _Step.demo) _pace = null;
  });

  void _back() {
    if (_history.isEmpty) return;
    setState(() {
      var s = _history.removeLast();
      // The pause only paces the tour; Back passes over it.
      while (s == _Step.preparing && _history.isNotEmpty) {
        s = _history.removeLast();
      }
      _step = s;
      _micOff = false;
      if (s == _Step.demo) _pace = null;
    });
  }

  /// Voice setup declined: carry on with Auto-scroll, which needs no permission.
  void _useAutoScroll() {
    setState(() {
      _micOff = false;
      _micReady = false;
    });
    _go(_Step.preparing);
  }

  /// Ends the tour without the plans (Skip).
  void _skip() => _finish(_finalMode);

  /// The last step: shows the plans, then ends the tour.
  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    try {
      final pro = ref.read(proProvider);
      await showPaywall(
        context,
        source: 'onboarding',
        title: 'Keep every ${_g.noun.isEmpty ? '' : '${_g.noun} '}script with TalkRoll Pro',
        reason: pro.canCreate ? null : proLimitReason(pro),
      );
      if (mounted) _finish(_finalMode);
    } finally {
      _completing = false;
    }
  }

  /// Ends the tour. [mode] becomes this session's mode; Normal unless the microphone was turned on.
  void _finish(PromptControlMode mode) {
    final messenger = ScaffoldMessenger.of(context);
    saveOnboardingAnswers(ref, {
      'goal': _goal?.id ?? '',
      'pains': _pains.join(','),
      'mode': mode.name,
      'completed': _step == _Step.result,
      'pace': _pace?.round() ?? 0,
    });
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(mode: mode));
    ref.read(onboardingDoneProvider.notifier).complete();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tap "New script" to write your own, or "Try the sample script" to see one read.'),
          duration: Duration(seconds: 6),
        ),
      );
    });
  }

  Future<void> _askMicrophone() async {
    final status = await Permission.microphone.status;
    final granted =
        status.isGranted ||
        (!status.isPermanentlyDenied &&
            !status.isRestricted &&
            await requestPermission(Permission.microphone, 'mic', ref.read(analyticsProvider)));
    if (!mounted) return;
    if (granted) {
      setState(() {
        _micOff = false;
        _micReady = true;
      });
      _go(_Step.preparing);
    } else {
      setState(() => _micOff = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read once here so the answer is ready by the solution step.
    ref.watch(voiceAvailableProvider);
    final page = switch (_step) {
      _Step.welcome => _welcome(context),
      _Step.goal => _goalPage(context),
      _Step.pains => _painsPage(context),
      _Step.solution => _solutionPage(context),
      _Step.voice => _micOff ? _micOffPage(context) : _voicePage(context),
      _Step.preparing => _preparingPage(),
      _Step.demo => _demoPage(context),
      _Step.result => _resultPage(context),
    };
    final path = _path;
    final busy = _step == _Step.preparing;
    final canBack = _history.isNotEmpty && !busy;
    return Theme(
      data: onboardingTheme(Theme.of(context)),
      child: PopScope(
        // Android's back button steps back through the tour; on the first screen it leaves the app as usual.
        canPop: _history.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !busy) _back();
        },
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: canBack
                                    ? IconButton(tooltip: 'Back', onPressed: _back, icon: const BackButtonIcon())
                                    : null,
                              ),
                            ),
                            Expanded(child: OnboardingProgress(value: (path.indexOf(_step) + 1) / path.length)),
                            SizedBox(
                              width: 64,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _skippable.contains(_step)
                                    ? TextButton(onPressed: _skip, child: const Text('Skip'))
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: KeyedSubtree(key: ValueKey('$_step$_micOff'), child: page),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Pages -----------------------------------------------------------------

  TextStyle? _title(BuildContext context) => onboardingTitle(context);

  TextStyle? _muted(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  Widget _welcome(BuildContext context) {
    return _Page(
      body: [
        const Spacer(),
        Text('Read to camera without looking away', style: onboardingHero(context)),
        const SizedBox(height: 10),
        Text('Your script scrolls as you speak, right where your eyes already are.', style: _muted(context)),
        const SizedBox(height: 24),
        const AutoReadingPrompt(
          text: 'Hi, thanks for watching. Today I want to show you how the words follow your voice.',
        ),
        const Spacer(),
      ],
      actions: [FilledButton(onPressed: () => _go(_Step.goal), child: const Text('Get started'))],
    );
  }

  /// One tap answers and moves on; the short pause lets the highlight show first.
  void _pickGoal(OnboardingGoal g) {
    setState(() => _goal = g);
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _step == _Step.goal) _go(_Step.pains);
    });
  }

  Widget _goalPage(BuildContext context) {
    return _Page(
      body: [
        Text('What will you use the teleprompter for?', style: _title(context)),
        const SizedBox(height: 8),
        Text("We'll try TalkRoll with a line you might really say.", style: _muted(context)),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: GoalGrid(goals: mobileGoals, selected: _goal?.id, onPick: _pickGoal),
          ),
        ),
      ],
    );
  }

  Widget _painsPage(BuildContext context) {
    return _Page(
      body: [
        Text('What gets in the way ${_g.when}?', style: _title(context)),
        const SizedBox(height: 8),
        Text('Pick all that apply.', style: _muted(context)),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: mobilePains.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = mobilePains[i];
              final on = _pains.contains(p.id);
              return ChoiceTile(
                icon: p.icon,
                glyph: p.glyph,
                tone: p.tone,
                label: p.label,
                multi: true,
                selected: on,
                onTap: () => setState(() => on ? _pains.remove(p.id) : _pains.add(p.id)),
              );
            },
          ),
        ),
      ],
      actions: [FilledButton(onPressed: () => _go(_Step.solution), child: const Text('Continue'))],
    );
  }

  Widget _solutionPage(BuildContext context) {
    final voiceOk = _voiceOk;
    return _Page(
      body: [
        Text('Keep your eyes near the lens', style: onboardingHero(context)),
        const SizedBox(height: 10),
        Text('Your script sits over the camera preview, right below the lens.', style: _muted(context)),
        const SizedBox(height: 24),
        Text(
          'Example preview',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        const Expanded(child: SingleChildScrollView(child: LensPreview())),
      ],
      actions: [
        FilledButton(
          onPressed: () => _go(voiceOk ? _Step.voice : _Step.preparing),
          child: Text(voiceOk ? 'Try it with my voice' : 'Try it now'),
        ),
      ],
    );
  }

  Widget _voicePage(BuildContext context) {
    return _Page(
      body: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Your script follows your voice', style: onboardingHero(context)),
                const SizedBox(height: 10),
                Text('Voice Mode uses your microphone to keep your place as you read aloud.', style: _muted(context)),
                const SizedBox(height: 24),
                const VoiceExampleCard(),
                const SizedBox(height: 28),
                PrivacyBlock(
                  lines: voiceFacts(onDevice: isApple, device: 'this device'),
                ),
              ],
            ),
          ),
        ),
      ],
      actions: [
        FilledButton(onPressed: _askMicrophone, child: Text(isApple ? 'Continue' : 'Turn on microphone')),
        TextButton(onPressed: _useAutoScroll, child: const Text('Not now')),
      ],
    );
  }

  Widget _micOffPage(BuildContext context) {
    return _Page(
      body: [
        const Spacer(),
        const HeroIcon(Icons.mic_off_outlined, warn: true),
        const SizedBox(height: 20),
        Text('Microphone is off', textAlign: TextAlign.center, style: _title(context)),
        const SizedBox(height: 10),
        Text(
          isApple
              ? 'Voice mode follows what you say, so it needs the microphone. Turn it on in Settings, or use Auto-scroll mode, which needs nothing.'
              : 'Voice mode needs the microphone. Turn it on in the app settings, or use Auto-scroll mode, which needs nothing.',
          textAlign: TextAlign.center,
          style: _muted(context),
        ),
        const Spacer(),
      ],
      actions: [
        FilledButton(onPressed: openAppSettings, child: const Text('Open Settings')),
        OutlinedButton(onPressed: _useAutoScroll, child: const Text('Use Auto-scroll mode')),
      ],
    );
  }

  Widget _preparingPage() {
    final noun = _g.noun.isEmpty ? '' : '${_g.noun} ';
    return _Page(
      body: [
        const Spacer(),
        ProcessingView(
          title: 'Getting your prompter ready…',
          lines: [
            'Picking a line from a ${noun.isEmpty ? 'script' : noun.trim()}',
            'Setting up the prompter',
            _micReady ? 'Getting Voice mode ready' : 'Getting Auto-scroll ready',
          ],
          onDone: () => _go(_Step.demo),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _demoPage(BuildContext context) {
    return _Page(
      body: [
        Text('Try reading aloud', style: onboardingHero(context)),
        const SizedBox(height: 10),
        Text(
          _micReady ? 'Watch the words highlight as you speak.' : 'Watch the words highlight as they scroll.',
          style: _muted(context),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: SingleChildScrollView(
            child: _micReady
                ? VoiceTest(sentence: _g.line, fontSize: 30, onFinished: (pace) => setState(() => _pace = pace))
                : SteadyReadDemo(sentence: _g.line, fontSize: 30),
          ),
        ),
      ],
      actions: [FilledButton(onPressed: () => _go(_Step.result), child: const Text('Continue'))],
    );
  }

  Widget _resultPage(BuildContext context) {
    return _Page(
      body: const [Expanded(child: SingleChildScrollView(child: ReadyBody()))],
      actions: [FilledButton(onPressed: _complete, child: const Text('Go to my scripts'))],
    );
  }
}

/// One tour page: the content, and the buttons at the bottom.
class _Page extends StatelessWidget {
  const _Page({required this.body, this.actions = const []});
  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
      ),
      for (final a in actions) ...[const SizedBox(height: 8), a],
    ],
  );
}
