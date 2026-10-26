import 'package:flutter/material.dart';

/// The mark of the reading line: a very faint band behind the line you are reading, with a solid
/// orange arrow at each edge pointing at it (the same orange as the current word). The text moves to
/// it, so it never moves. Symmetric, so mirroring and 180° rotation need no special case.
class ReadingGuideBand extends StatelessWidget {
  const ReadingGuideBand({super.key, required this.centerY, required this.lineHeight});
  final double centerY;
  final double lineHeight;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: centerY - lineHeight / 2,
    height: lineHeight,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _orange.withValues(alpha: 0.09),
          border: Border.symmetric(horizontal: BorderSide(color: _orange.withValues(alpha: 0.22))),
        ),
      ),
    ),
  );
}

class ReadingGuideArrows extends StatelessWidget {
  const ReadingGuideArrows({super.key, required this.centerY, required this.fontSize});
  final double centerY;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Sized to the text, with a floor so it stays findable in the small layouts.
    final h = (fontSize * 0.75).clamp(12.0, 22.0);
    final w = (h * 0.62).roundToDouble();
    Widget arrow(bool pointsRight) => IgnorePointer(
      child: CustomPaint(size: Size(w, h), painter: _ArrowPainter(pointsRight)),
    );
    return Stack(children: [
      Positioned(left: 6, top: centerY - h / 2, child: arrow(true)),
      Positioned(right: 6, top: centerY - h / 2, child: arrow(false)),
    ]);
  }
}

const _orange = Color(0xFFFF9F0A);

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.pointsRight);
  final bool pointsRight;

  @override
  void paint(Canvas canvas, Size size) {
    final x0 = pointsRight ? 0.0 : size.width;
    final x1 = pointsRight ? size.width : 0.0;
    final path = Path()
      ..moveTo(x0, 0)
      ..lineTo(x1, size.height / 2)
      ..lineTo(x0, size.height)
      ..close();
    // A soft glow keeps the arrow visible over lit-up words, then the solid shape on top.
    canvas.drawPath(path, Paint()..color = _orange.withValues(alpha: 0.55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(path, Paint()..color = _orange.withValues(alpha: 0.95));
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.pointsRight != pointsRight;
}
