import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import '../../core/settings/prompt_settings.dart';
import '../../services/platform.dart';
import '../../services/providers.dart';
import '../../ui/position_picker.dart';
import '../../ui/voice_permission_list.dart';
import '../pro/paywall_dialog.dart';
import '../pro/pro_state.dart';
import '../prompter/voice_permissions.dart';
import 'onboarding_content.dart';
import 'onboarding_state.dart';
import 'onboarding_widgets.dart';

enum _Step { welcome, goal, pains, solution, position, voice, result }

/// First run on macOS and Windows, in the Studio window. Two quick questions (what the reader is getting ready for,
/// what gets in the way) shape a "here's how TalkRoll helps" screen and the practice line; then where the prompter sits,
/// Voice (a checklist of the microphone, speech recognition and Dictation, each asked for on its own click), a read of
/// that line, the result with the three modes explained, and the plans. The tour never saves a script, so it never uses
/// one of the free scripts. Voice is optional; the tour ends in Normal mode either way. There is no live voice test
/// here, unlike on phones.
class DesktopOnboarding extends ConsumerStatefulWidget {
  const DesktopOnboarding({super.key});

  @override
  ConsumerState<DesktopOnboarding> createState() => _DesktopOnboardingState();
}

class _DesktopOnboardingState extends ConsumerState<DesktopOnboarding> {
  _Step _step = _Step.welcome;

  /// Steps visited before this one, for Back.
  final _history = <_Step>[];

  OnboardingGoal? _goal;
  final _pains = <String>{};

  /// The plans are open, so a second click on the result's button does nothing.
  bool _completing = false;

  OnboardingGoal get _g => _goal ?? desktopGoals.last;

  static const _path = _Step.values;

  void _go(_Step s) => setState(() {
    _history.add(_step);
    _step = s;
  });

  void _back() {
    if (_history.isEmpty) return;
    setState(() {
      _step = _history.removeLast();
    });
  }

  /// Voice declined: carry on with Auto-scroll, which needs no permission.
  void _useAutoScroll() => _go(_Step.result);

  /// One click answers and moves on; the short pause lets the highlight show first.
  void _pickGoal(OnboardingGoal g) {
    setState(() => _goal = g);
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _step == _Step.goal) _go(_Step.pains);
    });
  }

  /// The mode the reader starts in. The Mac tour has no live voice test (the speech engine may still need its language
  /// models), so it starts in Auto-scroll, which always works; Voice is one choice away in the Studio.
  PromptControlMode get _finalMode => PromptControlMode.normal;

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
      if (mounted) _finish();
    } finally {
      _completing = false;
    }
  }

  /// Ends the tour (Skip, or after the plans).
  void _finish() {
    final mode = _finalMode;
    saveOnboardingAnswers(ref, {
      'goal': _goal?.id ?? '',
      'pains': _pains.join(','),
      'mode': mode.name,
      'completed': _step == _Step.result,
    });
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(mode: mode));
    ref.read(onboardingDoneProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final title = onboardingTitle(context);
    Widget heading(String t, String sub) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t, textAlign: TextAlign.center, style: title),
        const SizedBox(height: 10),
        Text(sub, textAlign: TextAlign.center, style: muted),
        const SizedBox(height: 20),
      ],
    );
    final pane = switch (_step) {
      _Step.welcome => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AutoReadingPrompt(text: "Hi, thanks for joining. Let's get started.", fontSize: 20),
          const SizedBox(height: 28),
          Text('Read your script right under the camera', textAlign: TextAlign.center, style: onboardingHero(context)),
          const SizedBox(height: 10),
          Text(
            'A floating prompter sits at the top of your screen, so you keep eye contact on calls and recordings.',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ],
      ),
      _Step.goal => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          heading('What will you use the teleprompter for?', "We'll try TalkRoll with a line you might really say."),
          GoalGrid(goals: desktopGoals, selected: _goal?.id, onPick: _pickGoal),
        ],
      ),
      _Step.pains => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          heading('What gets in the way ${_g.when}?', 'Pick all that apply.'),
          for (final p in desktopPains) ...[
            ChoiceTile(
              icon: p.icon,
              glyph: p.glyph,
              tone: p.tone,
              label: p.label,
              multi: true,
              selected: _pains.contains(p.id),
              onTap: () => setState(() => _pains.contains(p.id) ? _pains.remove(p.id) : _pains.add(p.id)),
            ),
            if (p != desktopPains.last) const SizedBox(height: 10),
          ],
        ],
      ),
      _Step.solution => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          heading(
            'Keep your eyes near the lens',
            'Your script floats right under your camera, so you keep eye contact.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Example preview', style: muted),
          ),
          const SizedBox(height: 10),
          const LensPreview(),
        ],
      ),
      _Step.position => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Where should the prompter sit?', textAlign: TextAlign.center, style: title),
          const SizedBox(height: 20),
          const PositionPicker(),
          const SizedBox(height: 14),
          Text(
            'Placing the prompter right under the camera helps you keep eye contact. It is hidden from most screen sharing apps, though not guaranteed in all of them.',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ],
      ),
      _Step.voice => _voice(context, muted),
      _Step.result => _result(context, title, muted),
    };
    return Theme(
      data: onboardingTheme(Theme.of(context)),
      child: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: OnboardingProgress(value: (_path.indexOf(_step) + 1) / _path.length),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: KeyedSubtree(key: ValueKey(_step), child: pane),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    const Spacer(),
                    for (final (i, b) in _buttons().indexed) ...[if (i > 0) const SizedBox(width: 8), b],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The bottom bar's buttons for this step, primary last.
  List<Widget> _buttons() {
    final back = TextButton(onPressed: _back, child: const Text('Back'));
    final skip = TextButton(onPressed: _finish, child: const Text('Skip'));
    Widget primary(String label, VoidCallback? onPressed) => FilledButton(onPressed: onPressed, child: Text(label));
    return switch (_step) {
      _Step.welcome => [skip, primary('Get started', () => _go(_Step.goal))],
      _Step.goal => [back, skip],
      _Step.pains => [back, skip, primary('Continue', () => _go(_Step.solution))],
      _Step.solution => [back, skip, primary('Set up my prompter', () => _go(_Step.position))],
      _Step.position => [back, primary('Continue', () => _go(_Step.voice))],
      // Continue appears once everything on the checklist is allowed; "Not now" always carries on without it.
      _Step.voice when voicePermissionsReady(ref.watch(voicePermissionsProvider).value) => [
        back,
        primary('Continue', () => _go(_Step.result)),
      ],
      _Step.voice => [back, TextButton(onPressed: _useAutoScroll, child: const Text('Not now'))],
      _Step.result => [back, primary('Open the Studio', _complete)],
    };
  }

  Widget _voice(BuildContext context, TextStyle? muted) {
    final device = isMacOS ? 'this Mac' : 'this PC';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your script follows your voice', style: onboardingHero(context)),
        const SizedBox(height: 10),
        Text(
          'Turn these on so Voice Mode can keep your place as you read aloud. You can change them later in Settings.',
          style: muted,
        ),
        const SizedBox(height: 24),
        const VoicePermissionList(card: true),
        const SizedBox(height: 28),
        PrivacyBlock(lines: voiceFacts(onDevice: true, device: device)),
      ],
    );
  }

  Widget _result(BuildContext context, TextStyle? title, TextStyle? muted) => const ReadyBody();
}
