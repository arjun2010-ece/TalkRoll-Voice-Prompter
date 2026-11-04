import 'text.dart' show scriptWordPattern;

/// Section markers: a line holding only a name in square brackets, like `[Intro]`. A section runs
/// until the next marker. Markers are shown on the prompter as dividers but are never read, counted
/// or highlighted, so every word index stays the same as in the script without them.
///
/// On every platform. Kept as one switch so section handling can be turned off in a single place.
const bool sectionMarkersOn = true;

/// Longest section name.
const maxSectionNameLength = 40;

final _markerLine = RegExp(r'^[ \t]*\[([^\[\]\r\n]{1,40})\][ \t\r]*$', multiLine: true);
final _word = scriptWordPattern;

/// True if [line] (one line, no line break) is a section marker.
bool isSectionMarkerLine(String line) {
  if (!sectionMarkersOn) return false;
  final m = _markerLine.firstMatch(line);
  return m != null && m[1]!.trim().isNotEmpty;
}

class SectionMarker {
  const SectionMarker({required this.name, required this.start, required this.end, required this.wordIndex});

  /// Name without the brackets.
  final String name;

  /// Characters of the marker line in the script, brackets included.
  final int start;
  final int end;

  /// Index of the first spoken word in this section.
  final int wordIndex;
}

/// Every marker in [script], in order. Empty when markers are off or there are none.
List<SectionMarker> sectionMarkers(String script) {
  if (!sectionMarkersOn || !script.contains('[')) return const [];
  final raw = [
    for (final m in _markerLine.allMatches(script))
      if (m[1]!.trim().isNotEmpty) m,
  ];
  if (raw.isEmpty) return const [];
  final words = _wordIndexes(script, [for (final m in raw) m.start]);
  return [
    for (var i = 0; i < raw.length; i++)
      SectionMarker(name: raw[i][1]!.trim(), start: raw[i].start, end: raw[i].end, wordIndex: words[i]),
  ];
}

/// Action cues: a line holding only `{{ text }}`, or `{{! text }}` for a cue that holds the prompter until the
/// presenter presses Continue. A cue is something to do, not to say: like a section marker it is shown on the
/// prompter but never read, matched, counted or highlighted, so every word index stays the same without it.
const maxActionCueLength = 80;

final _cueLine = RegExp(r'^[ \t]*\{\{(!?)[ \t]*([^{}\r\n]{1,80}?)[ \t]*\}\}[ \t\r]*$', multiLine: true);

/// True if [line] (one line, no line break) is an action cue.
bool isActionCueLine(String line) {
  final m = _cueLine.firstMatch(line);
  return m != null && m[2]!.trim().isNotEmpty;
}

/// The script line for a cue.
String actionCueLine(String text, {bool hold = false}) => '{{${hold ? '!' : ''} ${text.trim()} }}';

class ActionCue {
  const ActionCue({required this.text, required this.hold, required this.start, required this.end, required this.wordIndex});

  final String text;
  final bool hold;

  /// Characters of the cue line in the script, braces included.
  final int start;
  final int end;

  /// Index of the first spoken word after the cue; the cue sits between word `wordIndex - 1` and `wordIndex`.
  /// The script's word count when nothing is spoken after it.
  final int wordIndex;
}

/// Every action cue in [script], in order.
List<ActionCue> actionCues(String script) {
  if (!script.contains('{{')) return const [];
  final raw = [
    for (final m in _cueLine.allMatches(script))
      if (m[2]!.trim().isNotEmpty) m,
  ];
  if (raw.isEmpty) return const [];
  final words = _wordIndexes(script, [for (final m in raw) m.start]);
  return [
    for (var i = 0; i < raw.length; i++)
      ActionCue(text: raw[i][2]!.trim(), hold: raw[i][1] == '!', start: raw[i].start, end: raw[i].end, wordIndex: words[i]),
  ];
}

/// Whether [script] has any section marker or action cue line, so word handling has to skip them.
bool hasNonSpokenLines(String script) => script.contains('[') || script.contains('{{');

/// Character ranges of every section marker and action cue line, in order.
List<(int, int)> _nonSpokenRanges(String script) {
  final out = <(int, int)>[
    if (sectionMarkersOn && script.contains('['))
      for (final m in _markerLine.allMatches(script))
        if (m[1]!.trim().isNotEmpty) (m.start, m.end),
    if (script.contains('{{'))
      for (final m in _cueLine.allMatches(script))
        if (m[2]!.trim().isNotEmpty) (m.start, m.end),
  ];
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

/// For each ascending character offset in [offsets], how many spoken words start before it.
List<int> _wordIndexes(String script, List<int> offsets) {
  final ranges = _nonSpokenRanges(script);
  final out = <int>[];
  var words = 0;
  final matches = _word.allMatches(script).iterator;
  var hasWord = matches.moveNext();
  for (final offset in offsets) {
    while (hasWord && matches.current.start < offset) {
      if (!_insideRange(matches.current.start, ranges)) words++;
      hasWord = matches.moveNext();
    }
    out.add(words);
  }
  return out;
}

bool _insideRange(int offset, List<(int, int)> ranges) {
  for (final r in ranges) {
    if (offset >= r.$1 && offset < r.$2) return true;
    if (r.$1 > offset) return false;
  }
  return false;
}

/// The spoken words of [script] with their character positions: `\S+` runs outside marker and cue lines.
Iterable<RegExpMatch> spokenWordMatches(String script) {
  if (!hasNonSpokenLines(script)) return _word.allMatches(script);
  final ranges = _nonSpokenRanges(script);
  if (ranges.isEmpty) return _word.allMatches(script);
  return _word.allMatches(script).where((w) => !_insideRange(w.start, ranges));
}

/// Index of the section a word belongs to, or -1 before the first marker.
int sectionIndexForWord(List<SectionMarker> markers, int word) {
  var found = -1;
  for (var i = 0; i < markers.length; i++) {
    if (markers[i].wordIndex <= word) {
      found = i;
    } else {
      break;
    }
  }
  return found;
}
