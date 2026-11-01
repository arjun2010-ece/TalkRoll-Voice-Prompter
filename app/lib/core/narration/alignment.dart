import 'dart:typed_data';

import '../script/text.dart';

/// One word of a transcript with the time it is spoken, in seconds from the start of the recording.
class TimedWord {
  const TimedWord(this.text, this.start, this.end);

  final String text;
  final double start;
  final double end;

  Map<String, Object> toJson() => {'w': text, 's': start, 'e': end};

  static TimedWord fromJson(Map<String, dynamic> j) =>
      TimedWord(j['w'] as String, (j['s'] as num).toDouble(), (j['e'] as num).toDouble());
}

/// For every script word, the time in the recording at which it is spoken. Narration mode scrolls by looking the
/// playback position up here.
class AlignmentMap {
  const AlignmentMap({required this.starts, required this.matchedWords, required this.duration});

  /// Start time in seconds of each script word. Never decreases.
  final List<double> starts;

  /// How many script words were found in the transcript (the rest have interpolated times).
  final int matchedWords;

  /// Length of the recording in seconds.
  final double duration;

  int get wordCount => starts.length;

  /// Share of the script's words that were heard in the recording, 0 to 1.
  double get matchedFraction => starts.isEmpty ? 0 : matchedWords / starts.length;

  /// Index of the word being spoken at [seconds]: the last word that has started, or -1 before the first.
  int wordIndexAt(double seconds) {
    var lo = 0, hi = starts.length - 1, found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (starts[mid] <= seconds) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  /// When [index] is spoken, in seconds.
  double timeOfWord(int index) => starts[index.clamp(0, starts.length - 1)];
}

/// Below this share of matched script words the recording is treated as not belonging to the script.
const narrationLowMatchBelow = 0.70;

// ---------------------------------------------------------------------------------------------------------------
// Normalising

const _ones = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve',
  'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
const _tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

List<String> _below100(int n) => n < 20 ? [_ones[n]] : [_tens[n ~/ 10], if (n % 10 != 0) _ones[n % 10]];

List<String> _below1000(int n) {
  if (n < 100) return _below100(n);
  return [_ones[n ~/ 100], 'hundred', if (n % 100 != 0) ..._below100(n % 100)];
}

/// English words for a whole number, or null when it is too long to read out (kept as digits).
List<String>? _spellOut(String digits) {
  if (digits.length > 9 || (digits.length > 1 && digits.startsWith('0'))) return null;
  final n = int.parse(digits);
  // Years are read in two halves: 1984 is "nineteen eighty four"; 2005 is "two thousand five".
  if (digits.length == 4 && n >= 1100 && n <= 2099 && !(n >= 2000 && n <= 2009) && n % 100 != 0) {
    return [..._below100(n ~/ 100), ..._below100(n % 100)];
  }
  if (n < 1000) return _below1000(n);
  final out = <String>[];
  var rest = n;
  for (final (unit, name) in [(1000000, 'million'), (1000, 'thousand')]) {
    if (rest >= unit) {
      out
        ..addAll(_below1000(rest ~/ unit))
        ..add(name);
      rest %= unit;
    }
  }
  if (rest > 0) out.addAll(_below1000(rest));
  return out;
}

/// Splits one script or transcript word into the plain tokens alignment compares: lowercase, no punctuation, numbers
/// spelled out ("2024" and "twenty twenty four" meet), and joined words like "well-known" cut in two.
List<String> alignmentTokens(String word) {
  final out = <String>[];
  for (final part in word.split(RegExp(r'[\s\-‐-―/_]+'))) {
    final t = normalizeWord(part);
    if (t.isEmpty) continue;
    if (RegExp(r'^[0-9]+$').hasMatch(t)) {
      out.addAll(_spellOut(t) ?? [t]);
    } else {
      out.add(t);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------------
// Aligning

const _match = 3;
const _near = 1;
const _mismatch = -2;
const _gap = -1;

bool _closeEnough(String a, String b) {
  if (a.length < 5 || b.length < 5 || (a.length - b.length).abs() > 1) return false;
  // One edit apart: the recogniser heard most of the word.
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  if (a.length == b.length) return a.substring(i + 1) == b.substring(i + 1);
  return a.length > b.length ? a.substring(i + 1) == b.substring(i) : a.substring(i) == b.substring(i + 1);
}

class _Token {
  const _Token(this.text, this.owner, [this.time = 0]);
  final String text;

  /// Index of the script word this token belongs to (script side only).
  final int owner;

  /// Start time in seconds (transcript side only).
  final double time;
}

/// Lines up what was said ([transcript]) with what is written ([script], as [scriptWords] gives it, so section titles
/// and anything else that is never spoken is not in it), and returns a time for every script word. Words found in
/// the transcript take its time; the others take a time interpolated between their neighbours, so a skipped or
/// extra word never throws the rest out of step.
AlignmentMap alignScript(List<String> script, List<TimedWord> transcript, {required double duration}) {
  final a = <_Token>[
    for (var i = 0; i < script.length; i++)
      for (final t in alignmentTokens(script[i])) _Token(t, i),
  ];
  final b = <_Token>[];
  for (final w in transcript) {
    final tokens = alignmentTokens(w.text);
    for (var k = 0; k < tokens.length; k++) {
      final span = (w.end - w.start).clamp(0.0, double.infinity);
      b.add(_Token(tokens[k], -1, w.start + span * k / tokens.length));
    }
  }
  final starts = List<double>.filled(script.length, 0);
  if (script.isEmpty) return AlignmentMap(starts: starts, matchedWords: 0, duration: duration);

  final n = a.length, m = b.length;
  // Needleman-Wunsch with a rolling score row and a full direction table (0 diagonal, 1 skip script, 2 skip heard).
  final dir = Uint8List((n + 1) * (m + 1));
  var prev = Int32List(m + 1), cur = Int32List(m + 1);
  for (var j = 1; j <= m; j++) {
    prev[j] = j * _gap;
    dir[j] = 2;
  }
  for (var i = 1; i <= n; i++) {
    cur[0] = i * _gap;
    dir[i * (m + 1)] = 1;
    for (var j = 1; j <= m; j++) {
      final x = a[i - 1].text, y = b[j - 1].text;
      final diag = prev[j - 1] + (x == y ? _match : (_closeEnough(x, y) ? _near : _mismatch));
      final up = prev[j] + _gap;
      final left = cur[j - 1] + _gap;
      if (diag >= up && diag >= left) {
        cur[j] = diag;
        dir[i * (m + 1) + j] = 0;
      } else if (up >= left) {
        cur[j] = up;
        dir[i * (m + 1) + j] = 1;
      } else {
        cur[j] = left;
        dir[i * (m + 1) + j] = 2;
      }
    }
    final t = prev;
    prev = cur;
    cur = t;
  }

  // Walk back, noting which heard token each script token took.
  final heard = List<int>.filled(n, -1);
  var i = n, j = m;
  while (i > 0 || j > 0) {
    final d = i == 0 ? 2 : (j == 0 ? 1 : dir[i * (m + 1) + j]);
    if (d == 0) {
      final x = a[i - 1].text, y = b[j - 1].text;
      if (x == y || _closeEnough(x, y)) heard[i - 1] = j - 1;
      i--;
      j--;
    } else if (d == 1) {
      i--;
    } else {
      j--;
    }
  }

  // Anchor times at matched tokens, then interpolate the gaps by position.
  final tokenTime = List<double?>.filled(n, null);
  for (var k = 0; k < n; k++) {
    if (heard[k] >= 0) tokenTime[k] = b[heard[k]].time;
  }
  var lastAnchor = -1;
  var lastTime = 0.0;
  for (var k = 0; k <= n; k++) {
    final isEnd = k == n;
    final t = isEnd ? duration : tokenTime[k];
    if (t == null) continue;
    final end = isEnd ? n : k;
    final to = isEnd ? (duration < lastTime ? lastTime : duration) : t;
    for (var g = lastAnchor + 1; g < end; g++) {
      final f = (g - lastAnchor) / (end - lastAnchor);
      tokenTime[g] = lastTime + (to - lastTime) * f;
    }
    if (!isEnd) {
      lastAnchor = k;
      lastTime = t;
    }
  }

  // A script word is heard when at least half of its tokens were; its time is its first token's.
  final tokensOf = List<int>.filled(script.length, 0);
  final heardOf = List<int>.filled(script.length, 0);
  final firstTime = List<double?>.filled(script.length, null);
  for (var k = 0; k < n; k++) {
    final w = a[k].owner;
    tokensOf[w]++;
    if (heard[k] >= 0) heardOf[w]++;
    firstTime[w] ??= tokenTime[k];
  }
  var matched = 0;
  final known = List<double?>.filled(script.length, null);
  for (var w = 0; w < script.length; w++) {
    if (tokensOf[w] > 0 && heardOf[w] * 2 >= tokensOf[w]) matched++;
    known[w] = firstTime[w];
  }
  // Words with no tokens at all (a lone symbol) sit with the word before them.
  var carry = 0.0;
  for (var w = 0; w < script.length; w++) {
    final t = known[w] ?? carry;
    starts[w] = t < carry ? carry : t;
    carry = starts[w];
  }
  return AlignmentMap(starts: starts, matchedWords: matched, duration: duration);
}
