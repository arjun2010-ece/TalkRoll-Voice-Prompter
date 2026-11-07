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

/// macOS take list as plain text, one line per section with its number of attempts [takes] (by section index). The
/// last attempt of a section is the keeper, so a section with several says so.
String takeListText(List<RunSection> sections, Map<int, int> takes) {
  final names = [
    for (final s in sections) 'Section ${s.index + 1}${s.name.isEmpty ? '' : ' · ${s.name}'}',
  ];
  final width = names.fold<int>(0, (m, n) => n.length > m ? n.length : m);
  final lines = <String>[];
  for (var i = 0; i < sections.length; i++) {
    final n = takes[sections[i].index] ?? 0;
    final count = n == 0 ? 'no take' : '$n ${n == 1 ? 'attempt' : 'attempts'}${n > 1 ? ' (keep the last)' : ''}';
    lines.add('${names[i]} ${'.' * (width - names[i].length + 4)} $count');
  }
  return lines.join('\n');
}
