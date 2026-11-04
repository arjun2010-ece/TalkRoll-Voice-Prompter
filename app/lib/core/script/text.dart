import 'dart:ui' show TextDirection;

import 'sections.dart';

// Combining marks belong to their letter (Hindi vowel signs, Thai tone marks, accents typed as two code points), so
// a word is not cut at one. Arabic and Hebrew vowel marks are the exception: scripts carry them and recognisers
// never do, so they are dropped on both sides.
final _letterOrDigit = RegExp(r'[\p{L}\p{N}\p{M}]', unicode: true);
final _vowelMarks = RegExp('[\u0591-\u05C7\u0610-\u061A\u064B-\u065F\u0670]');
const _ideograph = r'\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}';

/// A script word: a run of anything but spaces, except that Chinese and Japanese text, which has no spaces,
/// is cut after every character (with the punctuation that follows it).
final scriptWordPattern = RegExp('[$_ideograph][^\\p{L}\\p{N}\\p{M}\\s]*|[^\\s$_ideograph]+', unicode: true);

// A spoken word: a run of letters, digits and marks, or one ideograph.
final _spokenWord = RegExp('[$_ideograph]|(?:(?![$_ideograph])[\\p{L}\\p{N}\\p{M}])+', unicode: true);

/// The reading direction of [script]: right to left when most of its letters are Arabic or Hebrew.
TextDirection scriptTextDirection(String script) {
  var letters = 0, rtl = 0;
  final isLetter = RegExp(r'\p{L}', unicode: true);
  for (final r in (script.length > 2000 ? script.substring(0, 2000) : script).runes) {
    if (!isLetter.hasMatch(String.fromCharCode(r))) continue;
    letters++;
    if ((r >= 0x590 && r < 0x900) || (r >= 0xFB1D && r < 0xFE00) || (r >= 0xFE70 && r < 0xFF00)) rtl++;
  }
  return letters > 0 && rtl > letters ~/ 2 ? TextDirection.rtl : TextDirection.ltr;
}

/// Lowercases [word] and strips everything except letters and digits.
/// Single copy of the POC's duplicated `normalized(_:)`.
String normalizeWord(String word) => word
    .toLowerCase()
    .replaceAll(_vowelMarks, '')
    .runes
    .map(String.fromCharCode)
    .where(_letterOrDigit.hasMatch)
    .join();

final _blankLineRun = RegExp(r'[ \t]*(?:\r?\n[ \t]*){3,}');

/// [script] with any run of two or more blank lines cut to a single blank
/// line. Only for display: word positions are unchanged, and a single blank
/// line, or none, is left as written.
String tidyBlankLines(String script) => script.replaceAll(_blankLineRun, '\n\n');

/// Script words as displayed: split on whitespace, punctuation kept. Section marker and action cue lines are not words.
List<String> scriptWords(String script) => hasNonSpokenLines(script)
    ? [for (final m in spokenWordMatches(script)) m[0]!]
    : [for (final m in scriptWordPattern.allMatches(script)) m[0]!];

/// Words as recognised/spoken: lowercased, split on non letter/digit.
List<String> spokenWords(String text) =>
    [for (final m in _spokenWord.allMatches(text.toLowerCase().replaceAll(_vowelMarks, ''))) m[0]!];

/// Whether a script word matches a normalised spoken word. Words of four or
/// more characters may match as a substring (partial recognition).
bool wordsMatch(String scriptWord, String spokenWord) {
  final expected = normalizeWord(scriptWord);
  return expected == spokenWord ||
      (spokenWord.length >= 4 && expected.contains(spokenWord));
}
