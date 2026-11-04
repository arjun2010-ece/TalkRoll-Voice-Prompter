
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show PlaceholderAlignment, PlaceholderDimensions, SizedBox, Widget, WidgetSpan;

import '../../core/script/sections.dart';
import '../../core/script/text.dart';

/// Character ranges of each whitespace-separated word, and their vertical
/// positions once laid out. Highlighting only changes colour/decoration, so
/// one cached layout serves every progress update.
///
/// Section markers (`[Intro]`) are drawn as a small numbered label ("01   Intro") and are not words: [ranges] skips them, so
/// word indices match the script without markers. [script] is the text as shown (dividers in place
/// of the markers), and every offset here refers to it.
class WordLayout {
  WordLayout(String raw, TextStyle base, double width, {TextAlign align = TextAlign.left, bool showSections = true, TextDirection textDirection = TextDirection.ltr, Size cueSize = const Size(0, 0), double Function(int cue)? cueHeight}) {
    this.cueSize = cueSize;
    markers = sectionMarkers(raw);
    _sectionGap = (base.fontSize ?? 24) * 0.47;
    // A section starts with a small grey label, "01   Demo", above its text.
    dividerStyle = base.copyWith(
      fontSize: ((base.fontSize ?? 24) * 0.55).clamp(14.0, 20.0).toDouble(),
      fontWeight: FontWeight.w400,
      letterSpacing: 0.3,
      color: const Color(0xFF8E9196),
    );
    cues = actionCues(raw);
    // Section markers and action cue lines, in script order. Each is drawn in place of its line.
    final lines = <(int, int, SectionMarker?, int)>[
      for (final m in markers) (m.start, m.end, m, -1),
      for (var i = 0; i < cues.length; i++) (cues[i].start, cues[i].end, null, i),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final shown = StringBuffer();
    var cursor = 0;
    var section = 0;
    for (final l in lines) {
      shown.write(raw.substring(cursor, l.$1));
      final m = l.$3;
      if (m != null) {
        section++;
        if (showSections) {
          final start = shown.length;
          // The label, then a thin spacer line (a zero-width space) so the section's text starts a little below it.
          shown.write('${section.toString().padLeft(2, '0')}   ${m.name}\n\u200B');
          dividerRanges.add(TextRange(start: start, end: shown.length));
        }
      } else {
        final cue = cues[l.$4];
        final start = shown.length;
        // A cue is one placeholder character: the pill is a widget of [cueSize], drawn in its place.
        shown.write('\uFFFC');
        assert(cue.text.isNotEmpty);
        cueRanges.add(TextRange(start: start, end: shown.length));
      }
      cursor = l.$2;
    }
    shown.write(raw.substring(cursor));
    script = shown.toString();
    for (final m in scriptWordPattern.allMatches(script)) {
      if (!_inDivider(m.start) && !_inCue(m.start)) ranges.add(TextRange(start: m.start, end: m.end));
    }
    // Before the spans below are built: each cue's slot is as tall as its text needs.
    cueHeights = [for (var i = 0; i < cueRanges.length; i++) cueHeight?.call(i) ?? cueSize.height];
    painter = TextPainter(
      text: TextSpan(style: base, children: gapSpans(0, script.length)),
      textDirection: textDirection,
      textAlign: align,
    );
    if (cueRanges.isNotEmpty) {
      painter.setPlaceholderDimensions([
        for (var i = 0; i < cueRanges.length; i++)
          PlaceholderDimensions(size: Size(cueSize.width, cueHeights[i]), alignment: PlaceholderAlignment.middle),
      ]);
    }
    painter.layout(maxWidth: width);
  }

  /// The text as shown.
  late final String script;
  final List<TextRange> ranges = [];

  /// Section markers of the script, whether or not dividers are shown.
  late final List<SectionMarker> markers;
  final List<TextRange> dividerRanges = [];
  late final TextStyle dividerStyle;

  /// Action cues of the script, and where each is drawn in [script] (same order).
  late final List<ActionCue> cues;
  final List<TextRange> cueRanges = [];

  /// The size each cue pill takes in the text.
  late final Size cueSize;

  /// Each cue's height: one line, or two when its text is long for the width.
  late final List<double> cueHeights;
  late final TextPainter painter;

  /// The space between a section label and its text: the design's 14 px at a 30 px script.
  late final double _sectionGap;

  bool _inDivider(int offset) {
    for (final d in dividerRanges) {
      if (offset >= d.start && offset < d.end) return true;
    }
    return false;
  }

  bool _inCue(int offset) {
    for (final d in cueRanges) {
      if (offset >= d.start && offset < d.end) return true;
    }
    return false;
  }

  /// Vertical centre of action cue [i]; 0 when it has no line.
  double cueMidY(int i) {
    final boxes = painter.getBoxesForSelection(TextSelection(baseOffset: cueRanges[i].start, extentOffset: cueRanges[i].end));
    return boxes.isEmpty ? 0 : (boxes.first.top + boxes.last.bottom) / 2;
  }

  /// The text between words from [from] to [to], with any divider or action cue in it drawn in its own style.
  /// [cueBuilder] draws cue `i`'s pill; without it (measuring) an empty box of [cueSize] stands in.
  List<InlineSpan> gapSpans(int from, int to, {Widget Function(int cue)? cueBuilder}) {
    final out = <InlineSpan>[];
    var at = from;
    final marks = <(TextRange, int)>[
      for (final d in dividerRanges) (d, -1),
      for (var i = 0; i < cueRanges.length; i++) (cueRanges[i], i),
    ]..sort((a, b) => a.$1.start.compareTo(b.$1.start));
    for (final (d, cue) in marks) {
      if (d.end <= at || d.start >= to) continue;
      if (d.start > at) out.add(TextSpan(text: script.substring(at, d.start)));
      if (cue < 0) {
        final label = script.substring(d.start, d.end);
        final br = label.indexOf('\n');
        out.add(TextSpan(text: br < 0 ? label : label.substring(0, br), style: dividerStyle));
        if (br >= 0) out.add(TextSpan(text: label.substring(br), style: dividerStyle.copyWith(fontSize: _sectionGap, height: 1)));
      } else {
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(width: cueSize.width, height: cueHeights[cue], child: cueBuilder?.call(cue)),
        ));
      }
      at = d.end;
    }
    if (at < to) out.add(TextSpan(text: script.substring(at, to)));
    return out;
  }

  double get height => painter.height;

  static final _paragraphGap = RegExp(r'\n\s*\n');

  /// First word of the next paragraph if a blank line follows one of the
  /// [within] words starting at [from], else null.
  int? paragraphStartWithin(int from, int within) {
    final end = (from + within).clamp(0, ranges.length - 1);
    for (var k = from; k < end; k++) {
      if (_paragraphGap.hasMatch(script.substring(ranges[k].end, ranges[k + 1].start))) return k + 1;
    }
    return null;
  }

  /// Vertical centre of word [i].
  double midY(int i) {
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: ranges[i].start, extentOffset: ranges[i].end),
    );
    if (boxes.isEmpty) return 0;
    return (boxes.first.top + boxes.first.bottom) / 2;
  }

  /// Index of the word at or just after a local text position; clamps to the
  /// last word. Returns 0 for an empty script.
  int nearestWord(Offset p) {
    if (ranges.isEmpty) return 0;
    final off = painter.getPositionForOffset(p).offset;
    var lo = 0, hi = ranges.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (ranges[mid].end < off) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Word index at a local text position, or null between words.
  int? wordAt(Offset p) {
    final off = painter.getPositionForOffset(p).offset;
    var lo = 0, hi = ranges.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final r = ranges[mid];
      if (off < r.start) {
        hi = mid - 1;
      } else if (off > r.end) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return null;
  }
}
