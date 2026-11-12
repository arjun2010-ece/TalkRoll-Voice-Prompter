import 'text.dart';

/// Most words compared on each side; a free script is far shorter, and a Pro script is never compared.
const _maxCompared = 3000;

/// The share (0 to 1) of a script's words that changed between [before] and [after]: a word-level diff over the spoken
/// words (action cues and section titles are not words, case and punctuation do not count). Words kept in order are
/// unchanged; reordered, replaced and removed words count as changed. Nothing to compare (no words before or after)
/// is 0, so a script with only cues, or an empty one, is never a rewrite.
double changedWordShare(String before, String after) {
  final a = _words(before), b = _words(after);
  if (a.isEmpty || b.isEmpty) return 0;
  final kept = _longestCommon(a, b);
  final total = a.length > b.length ? a.length : b.length;
  return 1 - kept / total;
}

List<String> _words(String script) {
  final words = [for (final w in scriptWords(script)) normalizeWord(w)].where((w) => w.isNotEmpty).toList();
  return words.length > _maxCompared ? words.sublist(0, _maxCompared) : words;
}

/// Length of the longest run of words the two lists share in the same order.
int _longestCommon(List<String> a, List<String> b) {
  var prev = List<int>.filled(b.length + 1, 0);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      cur[j] = a[i - 1] == b[j - 1] ? prev[j - 1] + 1 : (prev[j] > cur[j - 1] ? prev[j] : cur[j - 1]);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[b.length];
}
