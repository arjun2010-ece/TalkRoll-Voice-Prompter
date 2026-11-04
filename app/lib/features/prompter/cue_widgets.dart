import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Action cue colours from the design: purple for "something to do", amber for a cue that holds.
const cuePurple = Color(0xFFBF5AF2);
const cueFill = Color(0xFF2E2140);
const cueIconFill = Color(0xFF4A3470);
const cueLabelColor = Color(0xFFE0C2F7);
const cueHoldAmber = Color(0xFFFFB340);

enum CueChipState { upcoming, active, past }

/// An action cue as drawn in the script and the prompter: a pill with an icon, "ACTION · NOT READ ALOUD" over the text,
/// and a HOLD badge for a hold cue. Dashed until it is reached, solid with a glow while it is active.
class CueChip extends StatelessWidget {
  const CueChip({super.key, required this.text, required this.hold, this.state = CueChipState.upcoming, this.scale = 1});

  final String text;
  final bool hold;
  final CueChipState state;
  final double scale;

  /// Height of the pill at [scale] 1.
  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final active = state == CueChipState.active;
    final pill = Container(
      height: height * s,
      padding: EdgeInsets.fromLTRB(10 * s, 0, 12 * s, 0),
      decoration: BoxDecoration(
        color: cueFill,
        borderRadius: BorderRadius.circular(28 * s),
        border: state == CueChipState.upcoming ? null : Border.all(color: cuePurple, width: 1.5),
        boxShadow: active ? [BoxShadow(color: cuePurple.withValues(alpha: 0.35), blurRadius: 26 * s), BoxShadow(color: cuePurple.withValues(alpha: 0.28), spreadRadius: 3)] : null,
      ),
      child: _CueRow(label: 'ACTION · NOT READ ALOUD', text: text, hold: hold, scale: s),
    );
    final shown = state == CueChipState.upcoming ? CustomPaint(foregroundPainter: _DashedBorder(28 * s), child: pill) : pill;
    return Opacity(opacity: state == CueChipState.past ? 0.5 : 1, child: shown);
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({required this.label, required this.text, required this.hold, required this.scale});

  final String label;
  final String text;
  final bool hold;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Row(children: [
      Container(
        width: 34 * s,
        height: 34 * s,
        decoration: const BoxDecoration(color: cueIconFill, shape: BoxShape.circle),
        child: Icon(hold ? Icons.pause_circle_outline : Icons.ads_click, size: 18 * s, color: cueLabelColor),
      ),
      SizedBox(width: 12 * s),
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: cueLabelColor, height: 1.2, decoration: TextDecoration.none)),
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17 * s, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2, decoration: TextDecoration.none)),
        ]),
      ),
      if (hold) ...[
        SizedBox(width: 8 * s),
        Container(
          height: 22 * s,
          padding: EdgeInsets.symmetric(horizontal: 9 * s),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cueHoldAmber, borderRadius: BorderRadius.circular(11 * s)),
          child: Text('HOLD', style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: const Color(0xFF1A1A1A), decoration: TextDecoration.none)),
        ),
      ],
    ]);
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = cuePurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.radius != radius;
}

// --- Prompter: quiet inline cues ------------------------------------------------------------------------------------

/// Prompter cue colours: grey like the section label, amber only for a cue that holds.
const cueQuietGrey = Color(0xFFA6A9B0);
const cueQuietNext = Color(0xFFEDEDEB);
const cueQuietDone = Color(0xFF55585E);
const cueQuietAmber = Color(0xFFD9A95B);
const cueQuietAmberNext = Color(0xFFF0C27A);
const promptFooterFill = Color(0xF2111214);
const promptFooterLine = Color(0xFF1F2023);

enum CueLineState { upcoming, next, now, done }

/// An action cue on the prompter: one italic line, smaller than the script, like a stage direction. ↳ for a cue,
/// pause bars and "Hold" (amber) for one that holds. It brightens as it comes up and dims once done.
class CueLine extends StatelessWidget {
  const CueLine({super.key, required this.text, required this.hold, required this.state, required this.fontSize});

  final String text;
  final bool hold;
  final CueLineState state;
  final double fontSize;

  /// Height for [text] at [fontSize] in [width]: one line, or two when it is too long for one (never cut off), with
  /// [gap] above and below it so the cue stands apart from the script around it.
  static double heightFor(String text, bool hold, double fontSize, double width, {double gap = 0}) {
    final reserved = fontSize * (1.05 + 0.55 + (hold ? 0.5 + 2.2 : 0));
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: (width - reserved).clamp(1.0, double.infinity));
    return math.max(fontSize * 1.2, painter.height) + gap * 2;
  }

  @override
  Widget build(BuildContext context) {
    final f = fontSize;
    final color = switch (state) {
      CueLineState.upcoming => hold ? cueQuietAmber : cueQuietGrey,
      CueLineState.next => hold ? cueQuietAmberNext : cueQuietNext,
      CueLineState.now => hold ? cueQuietAmberNext : Colors.white,
      CueLineState.done => hold ? cueQuietAmber.withValues(alpha: 0.45) : cueQuietDone,
    };
    final now = state == CueLineState.now;
    final suffix = hold ? 'Hold' : now ? 'now' : null;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(hold ? Icons.pause_rounded : Icons.subdirectory_arrow_right_rounded, size: f * 1.05, color: color),
        SizedBox(width: f * 0.55),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: f,
              fontStyle: FontStyle.italic,
              fontWeight: now ? FontWeight.w600 : FontWeight.w400,
              color: color,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        if (suffix != null) ...[
          SizedBox(width: f * 0.5),
          Text(
            suffix,
            style: TextStyle(
              fontSize: f * 0.68,
              fontWeight: FontWeight.w500,
              color: hold ? color : cueQuietGrey,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ]),
    );
  }
}

/// The prompter's footer strip for cues: "Holding at cue" with Continue while a hold cue holds, or "Next" with the
/// cue when it is still below the window. Edge to edge, above the controls, so it never covers the reading line.
class CueFooter extends StatelessWidget {
  const CueFooter.holding({super.key, required this.onContinue, this.shortcut, this.compact = false, this.large = false, this.bottomInset = 0})
      : cueText = null,
        hold = true;

  const CueFooter.next({super.key, required String text, required this.hold, this.compact = false, this.large = false, this.bottomInset = 0})
      : cueText = text,
        onContinue = null,
        shortcut = null;

  final String? cueText;
  final bool hold;
  final VoidCallback? onContinue;
  final String? shortcut;

  /// Notch and corner: a shorter strip.
  final bool compact;

  /// Phone reader: in place of the dock, with a finger-sized Continue.
  final bool large;

  /// Space below the strip for the home indicator when it sits at the very bottom.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final c = compact;
    final l = large;
    final label = TextStyle(fontSize: c ? 12 : 15, color: cueQuietGrey, decoration: TextDecoration.none);
    final List<Widget> row;
    if (cueText == null) {
      row = [
        Expanded(child: Text('Holding at cue', style: label)),
        if (shortcut != null) ...[
          ShortcutHint(shortcut!, style: label.copyWith(fontSize: c ? 11 : 12, color: const Color(0xFF6E7177))),
          SizedBox(width: c ? 8 : 12),
        ],
        SizedBox(
          height: c ? 28 : (l ? 48 : 40),
          child: TextButton(
            onPressed: onContinue,
            style: TextButton.styleFrom(
              backgroundColor: cueQuietNext,
              foregroundColor: const Color(0xFF111214),
              padding: EdgeInsets.symmetric(horizontal: c ? 12 : (l ? 20 : 18)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(c ? 8 : (l ? 12 : 10))),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Continue', style: TextStyle(fontSize: c ? 13 : (l ? 16 : 15), fontWeight: FontWeight.w500)),
              SizedBox(width: c ? 6 : 10),
              Icon(Icons.play_arrow_outlined, size: c ? 16 : 20),
            ]),
          ),
        ),
      ];
    } else {
      final color = hold ? cueQuietAmber : cueQuietNext;
      row = [
        Text('Next', style: label),
        SizedBox(width: c ? 8 : 12),
        Icon(hold ? Icons.pause_rounded : Icons.subdirectory_arrow_right_rounded, size: c ? 14 : 17, color: color),
        SizedBox(width: c ? 6 : 8),
        Flexible(
          child: Text(
            cueText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: label.copyWith(fontStyle: FontStyle.italic, color: color),
          ),
        ),
        if (hold) ...[
          SizedBox(width: c ? 6 : 8),
          Text('Hold', style: label.copyWith(fontSize: c ? 10 : 12, color: color)),
        ],
      ];
    }
    return Container(
      height: (c ? 40 : (l ? 74 : 64)) + bottomInset,
      padding: EdgeInsets.fromLTRB(c ? 16 : 24, 0, c ? 10 : 16, bottomInset),
      decoration: const BoxDecoration(color: promptFooterFill, border: Border(top: BorderSide(color: promptFooterLine))),
      child: Row(children: row),
    );
  }
}

/// A shortcut such as "⌃⌥↩" as small grey text. The return key is drawn as an icon: the system's ↩ glyph comes out
/// as a coloured emoji.
class ShortcutHint extends StatelessWidget {
  const ShortcutHint(this.label, {super.key, this.style});

  final String label;

  /// Defaults to the surrounding text style (inside a button, the button's).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(this.style);
    final parts = label.split('↩');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < parts.length; i++) ...[
        if (parts[i].isNotEmpty) Text(parts[i], style: style),
        if (i < parts.length - 1) Icon(Icons.keyboard_return_rounded, size: (style.fontSize ?? 12) * 1.15, color: style.color),
      ],
    ]);
  }
}
