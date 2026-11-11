import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers.dart';
import '../../services/storage/script_library.dart';

const onboardingKey = 'TalkRoll.onboarding.v1';

/// The tour's answers (ids only, never script text), kept for later personalisation.
const onboardingAnswersKey = 'TalkRoll.onboarding.answers.v1';

/// Stores the tour's answers and logs them as one event. A replay overwrites the earlier answers.
void saveOnboardingAnswers(WidgetRef ref, Map<String, Object> answers) {
  ref.read(prefsProvider).setString(onboardingAnswersKey, jsonEncode(answers));
  ref.read(analyticsProvider).log('onboarding_answers', answers);
}

/// Whether the first-run tour has been finished (or skipped). Someone who already has saved settings or scripts
/// is an existing user and never sees it. The answer is written on first read, so quitting halfway through (after
/// the tour has changed a setting) still brings the tour back next launch.
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(prefsProvider);
    final stored = prefs.getBool(onboardingKey);
    if (stored != null) return stored;
    final existing = prefs.containsKey(settingsKey) || prefs.containsKey(ScriptLibrary.historyKey);
    prefs.setBool(onboardingKey, existing);
    return existing;
  }

  void complete() {
    state = true;
    ref.read(prefsProvider).setBool(onboardingKey, true);
  }

  /// Settings → Help → "Show the tour again".
  void replay() {
    state = false;
    ref.read(prefsProvider).setBool(onboardingKey, false);
  }
}

final onboardingDoneProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

/// Closes Settings (a page or a dialog) and starts the tour again from the first screen.
void replayOnboarding(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  container.read(onboardingDoneProvider.notifier).replay();
}
