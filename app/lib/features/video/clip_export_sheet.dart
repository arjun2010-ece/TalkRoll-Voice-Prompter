import 'package:flutter/material.dart';

import '../../core/script/run_sections.dart';
import 'recording_session.dart';

enum ClipExportChoice { video, separate, discard }

String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// What to do with the clips of a section-by-section run: the keeper of every section joined into one video, each
/// keeper as its own file, or throw them away. A finished video with sections missing asks first.
Future<ClipExportChoice?> showClipExport(BuildContext context, {required RecordingSession session, required List<RunSection> sections}) {
  return showModalBottomSheet<ClipExportChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final scheme = theme.colorScheme;
      final missing = session.missingSections(sections.length);
      final keepers = session.keepers;
      Future<void> finished() async {
        if (missing.isNotEmpty) {
          final go = await showAdaptiveDialog<bool>(
            context: sheet,
            builder: (ctx) => AlertDialog.adaptive(
              title: Text(missingSectionsMessage(missing)),
              content: const Text('The finished video can be made without them. The sections that have a take will still be in order.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Go back')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Export without them')),
              ],
            ),
          );
          if (go != true || !sheet.mounted) return;
        }
        if (sheet.mounted) Navigator.pop(sheet, ClipExportChoice.video);
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Your clips', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              keepers.isEmpty
                  ? 'Nothing has been recorded yet.'
                  : 'The last take of each section is kept. ${keepers.length} of ${sections.length} sections · ${_clock(session.keepersDuration)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final clip = session.keeperFor(i);
                  final attempts = session.attemptsFor(i);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 13))),
                    title: Text(sections[i].label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      clip == null ? 'No take' : '${_clock(clip.duration)} · ${attempts == 1 ? '1 take' : '$attempts takes'}',
                      style: TextStyle(color: clip == null ? scheme.error : scheme.onSurfaceVariant),
                    ),
                    trailing: Icon(clip == null ? Icons.remove_circle_outline : Icons.check_circle_outline, color: clip == null ? scheme.error : scheme.primary),
                  );
                },
              ),
            ),
            if (missing.isNotEmpty && keepers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(missingSectionsMessage(missing), style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error))),
              ]),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: keepers.isEmpty ? null : finished,
              child: const Text('Finished video'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: keepers.isEmpty ? null : () => Navigator.pop(sheet, ClipExportChoice.separate),
              child: const Text('Separate clips'),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: scheme.error),
              onPressed: () => Navigator.pop(sheet, ClipExportChoice.discard),
              child: const Text('Discard clips'),
            ),
          ]),
        ),
      );
    },
  );
}
