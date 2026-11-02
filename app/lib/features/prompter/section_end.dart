import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/script/run_sections.dart';
import '../studio/audio_check.dart' show formatSeconds;
import 'prompt_surface.dart';
import 'prompter_controller.dart';

const _ok = Color(0xFF3DD68C);
const _okTint = Color(0xFF1F3B2E);
const _action = Color(0xFF0B63CE);
const _muted = Color(0xFFB4B0A8);

/// "Section 2 done", or just "Done" when the script is a single section.
String sectionDoneTitle(List<RunSection> sections, int index) => sections.length <= 1 ? 'Done' : 'Section ${index + 1} done';

/// What the end-of-section state says under its title: the section's name and how long it took.
String sectionDoneDetail(RunSection section, double seconds) =>
    [if (section.name.isNotEmpty) section.name, if (seconds >= 1) formatSeconds(seconds)].join(' · ');

/// "Up next: Deploy", or that this was the last section.
String sectionUpNext(List<RunSection> sections, int index) =>
    index + 1 < sections.length ? 'Up next: ${sections[index + 1].label}' : 'That was the last section.';

/// The state a section ends in: the prompter has stopped and waits. Retake runs the section again, Next goes on,
/// Sections… opens the list. Shown by the Read screen, the camera screen and the macOS prompter.
///
/// [compact] is for the small macOS layouts (notch and corner). [hints] puts a keyboard shortcut on each button.
class SectionEndCard extends ConsumerWidget {
  const SectionEndCard({super.key, required this.onSections, this.compact = false, this.hints = const {}});

  final VoidCallback onSections;
  final bool compact;

  /// Shortcut text by button: `retake`, `next`, `sections`.
  final Map<String, String> hints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(prompterProvider.notifier);
    final pr = ref.watch(prompterProvider);
    final sections = controller.sections;
    if (sections.isEmpty) return const SizedBox.shrink();
    final i = pr.sectionIndex.clamp(0, sections.length - 1);
    final last = i >= sections.length - 1;
    final detail = sectionDoneDetail(sections[i], pr.sectionSeconds);

    Widget button(String id, String text, IconData icon, VoidCallback? onTap, {bool primary = false, bool quiet = false}) {
      // The small layouts have no room for a shortcut beside the name; the tray menu and Settings list them.
      final hint = compact ? null : hints[id];
      final label = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Text(hint, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
        ],
      ]);
      final size = Size.fromHeight(compact ? 40 : 48);
      if (primary) {
        return FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(backgroundColor: _action, foregroundColor: Colors.white, minimumSize: size),
          child: label,
        );
      }
      if (quiet) {
        return TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: size),
          child: label,
        );
      }
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          // The card is dark in both themes, so the button must not take the light theme's fill.
          backgroundColor: Colors.transparent,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
          minimumSize: size,
        ),
        child: label,
      );
    }

    final retake = button('retake', 'Retake', Icons.replay, controller.retakeSection);
    final next = last ? null : button('next', 'Next', Icons.skip_next_rounded, controller.nextSection, primary: true);
    final list = button('sections', 'Sections…', Icons.format_list_bulleted, onSections, quiet: !compact);

    final title = Text(
      sectionDoneTitle(sections, i),
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white, fontSize: compact ? 17 : 20, fontWeight: FontWeight.w600),
    );
    final sub = Text(
      detail.isEmpty ? sectionUpNext(sections, i) : (compact ? '$detail · ${sectionUpNext(sections, i)}' : detail),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: _muted, fontSize: 13),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${sectionDoneTitle(sections, i)}. Retake, ${last ? '' : 'Next, '}or open the sections.',
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 520 : 420),
        padding: EdgeInsets.fromLTRB(compact ? 14 : 18, compact ? 10 : 22, compact ? 14 : 18, compact ? 10 : 18),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(compact ? 14 : 22),
          border: Border.all(color: const Color(0xFF48484A)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!compact)
            const Align(
              child: CircleAvatar(radius: 22, backgroundColor: _okTint, child: Icon(Icons.check, color: _ok, size: 24)),
            ),
          if (!compact) const SizedBox(height: 10),
          title,
          const SizedBox(height: 4),
          sub,
          SizedBox(height: compact ? 10 : 14),
          if (compact)
            Row(children: [
              Expanded(child: retake),
              const SizedBox(width: 8),
              if (next != null) ...[Expanded(child: next), const SizedBox(width: 8)],
              Expanded(child: list),
            ])
          else ...[
            Row(children: [
              Expanded(child: retake),
              if (next != null) ...[const SizedBox(width: 10), Expanded(child: next)],
            ]),
            const SizedBox(height: 6),
            list,
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(sectionUpNext(sections, i), textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 13)),
            ],
          ],
        ]),
      ),
    );
  }
}

/// Every section, to jump to one. It starts from the section's first word and waits for play.
class SectionsList extends ConsumerWidget {
  const SectionsList({super.key, required this.onPicked, this.scroll, this.compact = false});

  /// Called after the prompter has moved to the chosen section.
  final VoidCallback onPicked;
  final ScrollController? scroll;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(prompterProvider.notifier);
    final current = ref.watch(prompterProvider.select((p) => p.sectionIndex));
    final sections = controller.sections;
    return ListView.separated(
      controller: scroll,
      shrinkWrap: scroll == null,
      padding: EdgeInsets.zero,
      itemCount: sections.length,
      separatorBuilder: (_, _) => SizedBox(height: compact ? 4 : 8),
      itemBuilder: (_, i) {
        final s = sections[i];
        final isCurrent = i == current;
        final done = i < current;
        return Semantics(
          button: true,
          selected: isCurrent,
          label: '${i + 1}, ${s.label}, ${s.wordCount} words${isCurrent ? ', current' : ''}',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(compact ? 8 : 14),
            onTap: () async {
              await controller.goToSection(i);
              onPicked();
            },
            child: Container(
              height: compact ? 40 : 64,
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF24406A) : (compact ? Colors.transparent : const Color(0xFF2C2C2E)),
                borderRadius: BorderRadius.circular(compact ? 8 : 14),
                border: compact ? null : Border.all(color: isCurrent ? const Color(0xFF3B82F6) : const Color(0xFF48484A), width: isCurrent ? 1.5 : 1),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: compact ? 10 : 16,
                  backgroundColor: const Color(0xFF3A3A3C),
                  child: Text('${i + 1}', style: TextStyle(color: Colors.white, fontSize: compact ? 11 : 14, fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: compact ? 13 : 17, fontWeight: FontWeight.w600)),
                    if (!compact) Text('${s.wordCount} words', style: const TextStyle(color: _muted, fontSize: 13)),
                  ]),
                ),
                if (done)
                  const Icon(Icons.check, size: 18, color: _ok)
                else if (isCurrent)
                  const Text('Current', style: TextStyle(color: Color(0xFF7DB5FF), fontSize: 12, fontWeight: FontWeight.w600))
                else if (!compact)
                  const Icon(Icons.chevron_right, size: 20, color: _muted),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// Mobile: the sections as a bottom sheet over the prompter.
Future<void> showSectionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      // A phone in landscape is short: open the list tall enough to show several sections.
      initialChildSize: MediaQuery.sizeOf(context).height < 500 ? 0.92 : 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('Sections', style: TextStyle(color: promptText, fontSize: 22, fontWeight: FontWeight.w600))),
            IconButton(tooltip: 'Close', icon: const Icon(Icons.close, color: promptText), onPressed: () => Navigator.of(sheet).pop()),
          ]),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Jump to any section. It starts from its first word.', style: TextStyle(color: _muted, fontSize: 14)),
          ),
          Expanded(child: SectionsList(scroll: scroll, onPicked: () => Navigator.of(sheet).pop())),
        ]),
      ),
    ),
  );
}
