import 'dart:io' show Platform;

import 'package:echoprompter/core/script/run_sections.dart';
import 'package:echoprompter/core/settings/prompt_settings.dart';
import 'package:echoprompter/features/prompter/prompter_controller.dart';
import 'package:echoprompter/services/audio/audio_input.dart';
import 'package:echoprompter/services/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Input implements AudioInput {
  @override
  Future<bool> hasPermission() async => true;
}

const _script = '[Intro]\none two three\n[Setup]\nfour five six\n[Deploy]\nseven eight nine';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('take list text lists sections, attempts and the keeper rule', () {
    final sections = runSections(_script);
    expect(
      takeListText(sections, {0: 1, 1: 3}),
      'Section 1 · Intro ..... 1 attempt\n'
      'Section 2 · Setup ..... 3 attempts (keep the last)\n'
      'Section 3 · Deploy .... no take',
    );
  });

  test('settings round-trip and old saved settings get the defaults', () {
    final s = const PromptSettings().copyWith(retakeClap: RetakeClap.flash, retakeFlashCorner: PromptCorner.bottomRight);
    final back = PromptSettings.fromJson(s.toJson().cast<String, Object?>());
    expect(back.retakeClap, RetakeClap.flash);
    expect(back.retakeFlashCorner, PromptCorner.bottomRight);
    final old = PromptSettings.fromJson({'fontSize': 30});
    expect(old.retakeClap, RetakeClap.both);
    expect(old.retakeFlashCorner, PromptCorner.topLeft);
  });

  group('controller (macOS only)', () {
    late List<Map> claps;
    late ProviderContainer c;

    setUp(() async {
      claps = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.echoprompter/window'),
        (call) async {
          if (call.method == 'retakeClap') claps.add(Map.of(call.arguments as Map));
          return null;
        },
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs), audioInputProvider.overrideWithValue(_Input())]);
      addTearDown(c.dispose);
    });

    Future<PrompterController> start({RunStyle run = RunStyle.sections, RetakeClap clap = RetakeClap.both}) async {
      c.read(settingsProvider.notifier).update((s) => s.copyWith(runStyle: run, retakeClap: clap, retakeFlashCorner: PromptCorner.topRight));
      final p = c.read(prompterProvider.notifier);
      await p.begin(sessionId: 1, script: _script, mode: PromptControlMode.normal);
      return p;
    }

    test('claps at each section start and every retake, not on resume; counts attempts', () async {
      final p = await start();
      await p.play();
      expect(claps, hasLength(1));
      expect(claps.single, {'sound': true, 'flash': true, 'corner': 'topRight'});
      await p.pause();
      await p.play(); // resume mid-section
      expect(claps, hasLength(1));
      await p.endSection();
      await p.retakeSection();
      await p.retakeSection(); // second retake of section 1
      expect(claps, hasLength(3));
      await p.endSection();
      await p.nextSection();
      expect(claps, hasLength(4));
      expect(p.takeCounts, {0: 3, 1: 1});
      // Jump to the last section and play: a take there too.
      await p.goToSection(2);
      expect(claps, hasLength(4));
      await p.play();
      expect(claps, hasLength(5));
      expect(p.takeCounts, {0: 3, 1: 1, 2: 1});
    });

    test('a new run starts the take list over', () async {
      final p = await start();
      await p.play();
      await p.begin(sessionId: 2, script: _script, mode: PromptControlMode.normal);
      expect(p.takeCounts, isEmpty);
      await p.play();
      expect(p.takeCounts, {0: 1});
    });

    test('whole-script run claps once at the start', () async {
      final p = await start(run: RunStyle.whole);
      await p.play();
      await p.pause();
      await p.play();
      expect(claps, hasLength(1));
      expect(p.takeCounts, isEmpty);
    });

    test('settings pick sound, flash or nothing', () async {
      var p = await start(clap: RetakeClap.sound);
      await p.play();
      expect(claps.single, containsPair('sound', true));
      expect(claps.single, containsPair('flash', false));
      claps.clear();
      c.read(settingsProvider.notifier).update((s) => s.copyWith(retakeClap: RetakeClap.flash));
      await p.retakeSection();
      expect(claps.single, containsPair('sound', false));
      expect(claps.single, containsPair('flash', true));
      claps.clear();
      c.read(settingsProvider.notifier).update((s) => s.copyWith(retakeClap: RetakeClap.off));
      await p.retakeSection();
      expect(claps, isEmpty);
      expect(p.takeCounts, {0: 3}); // the take list still counts when the clap is off
    });
  }, skip: !Platform.isMacOS ? 'macOS only' : false);
}
