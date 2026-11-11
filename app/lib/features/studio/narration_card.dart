import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/narration/alignment.dart';
import '../../core/settings/prompt_settings.dart';
import '../../services/providers.dart';
import '../../services/speech/speech_languages.dart';
import '../../services/storage/script_io.dart';
import 'audio_check.dart';
import 'narration_prep.dart';

/// Narration mode's setup, on every platform: choose a recording, watch it being transcribed on this device, see
/// whether it matches the script, and set the sync offset.
class NarrationCard extends ConsumerStatefulWidget {
  const NarrationCard({super.key});

  @override
  ConsumerState<NarrationCard> createState() => _NarrationCardState();
}

class _NarrationCardState extends ConsumerState<NarrationCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restore();
    });
  }

  void _restore() => ref.read(narrationPrepProvider.notifier).restoreFor(ref.read(studioProvider.notifier).currentId);

  Future<void> _choose() async {
    final picked = await ScriptIO.chooseAudio();
    if (picked != null && mounted) await ref.read(narrationPrepProvider.notifier).choose(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Another script was opened: show the recording linked to it.
    ref.listen(studioProvider.select((s) => s.scriptRevision), (_, _) => _restore());
    ref.listen(settingsProvider.select((s) => s.speechLanguage), (_, _) => _restore());
    final path = ref.watch(audioPathProvider);
    // The demo script only ever uses the bundled sample recording: no choosing another file.
    final demo = ref.watch(studioProvider.select((s) => s.script == StudioNotifier.welcome)) &&
        ref.read(studioProvider.notifier).currentId == null;
    final packNote = ref.watch(languagePackProvider).note;
    if (path == null) {
      // The built-in demo comes with its own recording, so Narration can be tried without one of your own.
      if (demo) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => ref.read(narrationPrepProvider.notifier).chooseSample(),
            icon: const Icon(Icons.graphic_eq),
            label: const Text('Use the sample recording'),
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _choose,
          icon: const Icon(Icons.audio_file_outlined),
          label: const Text('Choose a recording…'),
        ),
      );
    }
    final check = ref.watch(audioCheckProvider);
    final prep = ref.watch(narrationPrepProvider);
    final map = ref.watch(narrationAlignmentProvider);
    final checking = check.isLoading;
    final unreadable = check.hasValue && check.requireValue.readiness == AudioReadiness.unreadable;
    final seconds = check.hasValue ? check.requireValue.seconds : null;
    final transcribing = !checking && !unreadable && prep.phase == NarrationPhase.transcribing;
    final needsPack = !checking && !unreadable && prep.phase == NarrationPhase.needsPack;
    final failed = prep.phase == NarrationPhase.failed;
    final lowMatch = map != null && map.matchedFraction < narrationLowMatchBelow;
    final problem = unreadable || failed || (lowMatch && !prep.lowMatchAccepted);

    final String detail;
    if (checking) {
      detail = 'Checking the recording…';
    } else if (unreadable) {
      detail = "Can't be read, or was moved";
    } else if (needsPack) {
      detail = 'Needs the ${speechLanguageName(prep.language)} language pack: a one-time download from Apple, then it works offline.';
    } else if (transcribing) {
      detail = packNote ?? 'Preparing on this device… ${(prep.progress * 100).round()}%';
    } else if (failed) {
      detail = prep.message;
    } else if (lowMatch) {
      detail = prep.language.isEmpty
          ? "This recording doesn't seem to match this script."
          : "This recording doesn't seem to match this script. It was read as ${speechLanguageName(prep.language)}; if it is in another language, change the reading language.";
    } else if (map != null) {
      final length = seconds == null ? '' : '${formatSeconds(seconds)} · ';
      detail = map.byPauses ? "${length}Timed by the recording's pauses" : '$length${(map.matchedFraction * 100).round()}% matches your script';
    } else {
      detail = 'Getting ready…';
    }
    final name = demo ? 'Sample recording' : path.split(RegExp(r'[\\/]')).last;
    final colour = problem ? scheme.secondary : scheme.onSurfaceVariant;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: problem ? scheme.secondary : scheme.outlineVariant),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox.square(
              dimension: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: checking || transcribing
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, value: transcribing && prep.progress > 0 ? prep.progress : null),
                        )
                      : Icon(problem ? Icons.warning_amber_rounded : Icons.audio_file_outlined, color: colour),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(detail, style: TextStyle(fontSize: 13, color: colour)),
              ]),
            ),
            if (transcribing)
              TextButton(onPressed: () => ref.read(narrationPrepProvider.notifier).cancel(), child: const Text('Cancel'))
            else if (demo)
              (unreadable || failed
                  ? TextButton(onPressed: () => ref.read(narrationPrepProvider.notifier).chooseSample(), child: const Text('Try again'))
                  : const SizedBox.shrink())
            else if (!needsPack && (!lowMatch || prep.lowMatchAccepted))
              TextButton(onPressed: _choose, child: Text(unreadable || failed ? 'Choose another' : 'Change…')),
          ]),
          if (needsPack)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => ref.read(narrationPrepProvider.notifier).cancel(), child: const Text('Not now')),
                FilledButton.tonal(
                  onPressed: () => ref.read(narrationPrepProvider.notifier).downloadPackAndContinue(),
                  child: const Text('Download'),
                ),
              ]),
            ),
          if (lowMatch && !prep.lowMatchAccepted)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: demo ? () => ref.read(narrationPrepProvider.notifier).chooseSample() : _choose,
                  child: Text(demo ? 'Try again' : 'Choose another file'),
                ),
                FilledButton.tonal(
                  onPressed: () => ref.read(narrationPrepProvider.notifier).acceptLowMatch(),
                  child: const Text('Continue anyway'),
                ),
              ]),
            ),
        ]),
      ),
      if (map != null && (!lowMatch || prep.lowMatchAccepted)) const _SyncOffset(),
    ]);
  }
}

/// A small shift (up to half a second either way) for the delay of Bluetooth headphones.
class _SyncOffset extends ConsumerWidget {
  const _SyncOffset();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ms = ref.watch(settingsProvider.select((s) => s.narrationOffsetMs));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Sync offset')),
          Text(ms == 0 ? '0 ms' : '${ms > 0 ? '+' : ''}$ms ms', style: TextStyle(color: scheme.primary)),
        ]),
        Slider(
          value: ms.toDouble(),
          min: -maxNarrationOffsetMs.toDouble(),
          max: maxNarrationOffsetMs.toDouble(),
          divisions: maxNarrationOffsetMs ~/ 25,
          onChanged: (v) => ref.read(settingsProvider.notifier).update((c) => c.copyWith(narrationOffsetMs: v.round())),
        ),
        Text(
          'If the words run ahead of or behind the audio (Bluetooth headphones can delay sound), shift them here.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}
