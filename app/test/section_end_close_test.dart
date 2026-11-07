import 'package:echoprompter/core/settings/prompt_settings.dart';
import 'package:echoprompter/features/prompter/prompter_controller.dart';
import 'package:echoprompter/features/prompter/section_end.dart';
import 'package:echoprompter/services/audio/audio_input.dart';
import 'package:echoprompter/services/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Input implements AudioInput {
  @override
  Future<bool> hasPermission() async => true;
}

void main() {
  for (final compact in [false, true]) {
    testWidgets('section end card close button (compact: $compact)', (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs), audioInputProvider.overrideWithValue(_Input())]);
      addTearDown(c.dispose);
      c.read(settingsProvider.notifier).update((s) => s.copyWith(runStyle: RunStyle.sections));
      await c.read(prompterProvider.notifier).begin(sessionId: 1, script: '[A]\none two\n[B]\nthree four', mode: PromptControlMode.normal);
      var closed = 0;
      Widget card({VoidCallback? onClose}) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: compact ? 480 : 420, child: SectionEndCard(compact: compact, onSections: () {}, onClose: onClose))))),
      );
      await t.pumpWidget(card(onClose: () => closed++));
      expect(t.takeException(), isNull);
      await t.tap(find.byIcon(Icons.close));
      expect(closed, 1);
      await t.pumpWidget(card());
      expect(find.byIcon(Icons.close), findsNothing); // other screens' cards are unchanged
    });
  }
}
