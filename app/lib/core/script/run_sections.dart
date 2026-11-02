import 'sections.dart';
import 'text.dart';

/// One part of a script for "Section by section": the words from [startWord] up to, not including, [endWord].
class RunSection {
  const RunSection({required this.index, required this.name, required this.startWord, required this.endWord});

  /// Position in the script's section list, from 0.
  final int index;

  /// The marker's name, or empty for text before the first marker (and for a script with no markers).
  final String name;
  final int startWord;
  final int endWord;

  int get wordCount => endWord - startWord;

  /// The name, or "Section 3" when it has none.
  String get label => name.isEmpty ? 'Section ${index + 1}' : name;
}

/// The sections a section-by-section run steps through, in order. A script with no markers is one section, and text
/// before the first marker is a section of its own. A marker with no words after it is skipped. Empty when the
/// script has no words.
List<RunSection> runSections(String script) {
  final total = scriptWords(script).length;
  if (total == 0) return const [];
  final markers = sectionMarkers(script);
  final starts = <(String, int)>[
    if (markers.isEmpty || markers.first.wordIndex > 0) ('', 0),
    for (final m in markers) (m.name, m.wordIndex),
  ];
  final out = <RunSection>[];
  for (var i = 0; i < starts.length; i++) {
    final start = starts[i].$2;
    final end = i + 1 < starts.length ? starts[i + 1].$2 : total;
    if (end <= start) continue;
    out.add(RunSection(index: out.length, name: starts[i].$1, startWord: start, endWord: end));
  }
  return out;
}

/// Index in [sections] of the one holding [word], clamped to the first and last.
int runSectionIndexForWord(List<RunSection> sections, int word) {
  var found = 0;
  for (final s in sections) {
    if (s.startWord <= word) found = s.index;
  }
  return found;
}
