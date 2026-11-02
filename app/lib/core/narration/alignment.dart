import 'dart:math' as math;
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
  const AlignmentMap({required this.starts, required this.matchedWords, required this.duration, this.byPauses = false});

  /// True when the times come from the pauses in the recording rather than from a transcript (Android).
  final bool byPauses;

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
    } else if (_unspaced.hasMatch(t)) {
      out.addAll(_letterUnits(t));
    } else {
      out.add(t);
    }
  }
  return out;
}

// Chinese, Japanese and Thai have no spaces, so a recogniser's "words" and the script's words are cut in different
// places. Both sides are compared letter by letter instead (a letter with its tone and vowel marks is one unit).
final _unspaced = RegExp(r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Thai}]', unicode: true);
final _mark = RegExp(r'\p{M}', unicode: true);

List<String> _letterUnits(String text) {
  final out = <String>[];
  for (final r in text.runes) {
    final c = String.fromCharCode(r);
    if (out.isNotEmpty && _mark.hasMatch(c)) {
      out[out.length - 1] += c;
    } else {
      out.add(c);
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
  if (isPauseTimed(transcript)) return _alignByPauses(script, transcript, duration: duration);
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

// ---------------------------------------------------------------------------------------------------------------
// Aligning by pauses (no transcript)

/// Whether [transcript] is not words but the stretches of speech found in the recording (each has empty text). Android
/// has no speech recogniser that works without microphone access, so it only finds where the speaker talks and pauses.
bool isPauseTimed(List<TimedWord> transcript) => transcript.isNotEmpty && transcript.every((w) => w.text.isEmpty);

final _strongEnd = RegExp(r'[.!?…。！？;；:：]["\x27”’)\]»]*$');
final _softEnd = RegExp(r'[,，、]["\x27”’)\]»]*$');
final _thaiLetter = RegExp(r'[\u0E00-\u0E7F]');

/// Times every script word from the stretches of speech: words are spread over the time someone is speaking (never
/// over a pause) in proportion to their length, and the ends of sentences and phrases are pinned to the pauses nearest
/// where they should fall, so the estimate cannot drift over a long script. Needs no knowledge of the language.
AlignmentMap _alignByPauses(List<String> script, List<TimedWord> stretches, {required double duration}) {
  final n = script.length;
  final spans = [...stretches]..sort((a, b) => a.start.compareTo(b.start));
  if (n == 0) return AlignmentMap(starts: const [], matchedWords: 0, duration: duration, byPauses: true);

  // Time on the speech clock (pauses removed) at the start of each stretch.
  final before = <double>[];
  var speech = 0.0;
  for (final w in spans) {
    before.add(speech);
    speech += (w.end - w.start).clamp(0.0, double.infinity);
  }
  if (speech <= 0) {
    final even = [for (var i = 0; i < n; i++) duration * i / n];
    return AlignmentMap(starts: even, matchedWords: 0, duration: duration, byPauses: true);
  }

  // How much of the speech each word takes: its letters, at least one.
  final weight = [for (final w in script) math.max(1, normalizeWord(w).runes.length).toDouble()];
  final upTo = List<double>.filled(n + 1, 0); // weight before word i
  for (var i = 0; i < n; i++) {
    upTo[i + 1] = upTo[i] + weight[i];
  }
  final total = upTo[n];

  // Where the script pauses: after sentences (strongly) and commas (weakly). Thai has no punctuation, so its spaces count.
  var thai = 0, letters = 0;
  for (final w in script) {
    for (final r in w.runes) {
      final c = String.fromCharCode(r);
      if (RegExp(r'\p{L}', unicode: true).hasMatch(c)) {
        letters++;
        if (_thaiLetter.hasMatch(c)) thai++;
      }
    }
  }
  final spacedThai = letters > 0 && thai * 2 > letters;
  final boundaryWord = <int>[], boundaryReward = <double>[];
  for (var i = 0; i < n - 1; i++) {
    if (_strongEnd.hasMatch(script[i])) {
      boundaryWord.add(i);
      boundaryReward.add(1.0);
    } else if (_softEnd.hasMatch(script[i]) || spacedThai) {
      boundaryWord.add(i);
      boundaryReward.add(0.5);
    }
  }

  // Where the recording pauses: the speech-clock time of each gap between stretches, and how long it lasts.
  final gapAt = <double>[], gapLength = <double>[];
  for (var j = 0; j + 1 < spans.length; j++) {
    gapAt.add(before[j + 1]);
    gapLength.add(spans[j + 1].start - spans[j].end);
  }

  // Pair script pauses with recording pauses in order, preferring long pauses close to where the script expects them.
  final window = math.max(4.0, speech * 0.2);
  final nb = boundaryWord.length, ng = gapAt.length;
  final anchorsScript = <double>[0], anchorsSpeech = <double>[0];
  if (nb > 0 && ng > 0) {
    double gain(int k, int j) {
      final expected = upTo[boundaryWord[k] + 1] / total * speech;
      final off = (expected - gapAt[j]).abs();
      if (off > window) return 0;
      return boundaryReward[k] * (1 + math.min(gapLength[j], 1.0)) - off / window;
    }

    final best = List.generate(nb + 1, (_) => Float64List(ng + 1));
    final from = Uint8List((nb + 1) * (ng + 1)); // 0 skip script pause, 1 skip recording pause, 2 pair them
    for (var k = 1; k <= nb; k++) {
      for (var j = 1; j <= ng; j++) {
        var v = best[k - 1][j], d = 0;
        if (best[k][j - 1] > v) {
          v = best[k][j - 1];
          d = 1;
        }
        final g = gain(k - 1, j - 1);
        if (g > 0 && best[k - 1][j - 1] + g > v) {
          v = best[k - 1][j - 1] + g;
          d = 2;
        }
        best[k][j] = v;
        from[k * (ng + 1) + j] = d;
      }
    }
    final pairs = <(int, int)>[];
    var k = nb, j = ng;
    while (k > 0 && j > 0) {
      final d = from[k * (ng + 1) + j];
      if (d == 2) {
        pairs.add((k - 1, j - 1));
        k--;
        j--;
      } else if (d == 0) {
        k--;
      } else {
        j--;
      }
    }
    for (final (bk, gj) in pairs.reversed) {
      anchorsScript.add(upTo[boundaryWord[bk] + 1]);
      anchorsSpeech.add(gapAt[gj]);
    }
  }
  anchorsScript.add(total);
  anchorsSpeech.add(speech);

  // A time on the speech clock back to a time in the recording.
  double inRecording(double u) {
    var j = spans.length - 1;
    while (j > 0 && before[j] > u) {
      j--;
    }
    return spans[j].start + (u - before[j]).clamp(0.0, double.infinity);
  }

  final starts = List<double>.filled(n, 0);
  var a = 0;
  for (var i = 0; i < n; i++) {
    while (a + 2 < anchorsScript.length && upTo[i] >= anchorsScript[a + 1]) {
      a++;
    }
    final w0 = anchorsScript[a], w1 = anchorsScript[a + 1];
    final u0 = anchorsSpeech[a], u1 = anchorsSpeech[a + 1];
    final f = w1 > w0 ? ((upTo[i] - w0) / (w1 - w0)).clamp(0.0, 1.0) : 0.0;
    final t = inRecording(u0 + (u1 - u0) * f);
    starts[i] = i > 0 && t < starts[i - 1] ? starts[i - 1] : t;
  }

  // The speech should run at a human pace; far off means this is not a reading of the script.
  final pace = total / speech; // letters per second
  return AlignmentMap(starts: starts, matchedWords: pace >= 1.5 && pace <= 45 ? n : 0, duration: duration, byPauses: true);
}
