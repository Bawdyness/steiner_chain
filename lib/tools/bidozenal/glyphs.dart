// The 24 bidozenal glyphs, drawn as pure vector paths (no font).
//
// Ported from the throwaway design preview (tool/preview_glyphs.dart). The
// "+12" relationship is visible in the shape:
//   - strokes 1/4/7/10 (open chevrons) → 13/16/19/22 (closed triangles);
//   - half-circle composites 2/3/5/6/8/9/11 → 14/15/17/18/20/21/23 (+ centre
//     dot);
//   - pure circles 0 and 12 (= O/O) are neutral bridges.
// See docs/bidozenal.md §2 for the full rationale.
//
// Canvas coords are y-down: angle 0°=right, 90°=down, 180°=left, 270°=up.

import 'dart:math';
import 'package:flutter/material.dart';

void _arc(Canvas c, Paint p, Offset center, double r, double a0, double a1) {
  final rect = Rect.fromCircle(center: center, radius: r);
  c.drawArc(rect, a0 * pi / 180, (a1 - a0) * pi / 180, false, p);
}

void _rightHalf(Canvas c, Paint p, Offset center, double r) =>
    _arc(c, p, center, r, -90, 90); //  )  bulge right
void _leftHalf(Canvas c, Paint p, Offset center, double r) =>
    _arc(c, p, center, r, 90, 270); //  (  bulge left

void _arrow(Canvas c, Paint p, Offset ctr, Offset tip, Offset w1, Offset w2) {
  final t = ctr + tip;
  c.drawLine(t, ctr + w1, p);
  c.drawLine(t, ctr + w2, p);
}

void _triangle(Canvas c, Paint p, Offset ctr, Offset a, Offset b, Offset d) {
  final pa = ctr + a, pb = ctr + b, pd = ctr + d;
  c.drawPath(
    Path()
      ..moveTo(pa.dx, pa.dy)
      ..lineTo(pb.dx, pb.dy)
      ..lineTo(pd.dx, pd.dy)
      ..close(),
    p,
  );
}

/// Paints the glyph for [value] (0..23), centred at [center], using
/// quarter-size [q] (the half-circle radius; strokes use the full ±2q height).
void paintBidozenalGlyph(
  Canvas c,
  int value,
  Offset center,
  double q,
  Paint p,
) {
  final top = center + Offset(0, -q);
  final bot = center + Offset(0, q);
  final qy = 2 * q; // strokes span the full vertical extent (±2q)
  final cq = q * 0.4; // small centre circle marking the +12 composites

  switch (value) {
    // ---- 0..11 ----
    case 0:
      c.drawCircle(center, q, p);
    case 1: // ↑
      _arrow(c, p, center, Offset(0, -qy), Offset(-q, qy), Offset(q, qy));
    case 2: // ) over (
      _rightHalf(c, p, top, q);
      _leftHalf(c, p, bot, q);
    case 3: // ) over )
      _rightHalf(c, p, top, q);
      _rightHalf(c, p, bot, q);
    case 4: // ←
      _arrow(c, p, center, Offset(-q, 0), Offset(q, -qy), Offset(q, qy));
    case 5: // ( over )
      _leftHalf(c, p, top, q);
      _rightHalf(c, p, bot, q);
    case 6: // ( over O
      _leftHalf(c, p, top, q);
      c.drawCircle(bot, q, p);
    case 7: // →
      _arrow(c, p, center, Offset(q, 0), Offset(-q, -qy), Offset(-q, qy));
    case 8: // O over (
      c.drawCircle(top, q, p);
      _leftHalf(c, p, bot, q);
    case 9: // O over )
      c.drawCircle(top, q, p);
      _rightHalf(c, p, bot, q);
    case 10: // ↓
      _arrow(c, p, center, Offset(0, qy), Offset(-q, -qy), Offset(q, -qy));
    case 11: // ) over O
      _rightHalf(c, p, top, q);
      c.drawCircle(bot, q, p);

    // ---- 12..23 (the "+12" extension) ----
    case 12: // bridge: O over O (pure circles)
      c.drawCircle(top, q, p);
      c.drawCircle(bot, q, p);
    case 13: // △ (= 1 closed)
      _triangle(c, p, center, Offset(0, -qy), Offset(-q, qy), Offset(q, qy));
    case 14: // copy of 2 + centre dot
      _rightHalf(c, p, top, q);
      _leftHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 15: // copy of 3 + centre dot
      _rightHalf(c, p, top, q);
      _rightHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 16: // ◁ (= 4 closed)
      _triangle(c, p, center, Offset(-q, 0), Offset(q, -qy), Offset(q, qy));
    case 17: // copy of 5 + centre dot
      _leftHalf(c, p, top, q);
      _rightHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 18: // copy of 6 + centre dot
      _leftHalf(c, p, top, q);
      c.drawCircle(bot, q, p);
      c.drawCircle(center, cq, p);
    case 19: // ▷ (= 7 closed)
      _triangle(c, p, center, Offset(q, 0), Offset(-q, -qy), Offset(-q, qy));
    case 20: // copy of 8 + centre dot
      c.drawCircle(top, q, p);
      _leftHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 21: // copy of 9 + centre dot
      c.drawCircle(top, q, p);
      _rightHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 22: // ▽ (= 10 closed)
      _triangle(c, p, center, Offset(0, qy), Offset(-q, -qy), Offset(q, -qy));
    case 23: // copy of 11 + centre dot
      _rightHalf(c, p, top, q);
      c.drawCircle(bot, q, p);
      c.drawCircle(center, cq, p);
  }
}

/// A single bidozenal glyph rendered in a square box of side [size].
class BidozenalGlyph extends StatelessWidget {
  const BidozenalGlyph({
    super.key,
    required this.value,
    required this.size,
    required this.color,
    this.strokeWidth,
  });

  final int value;
  final double size;
  final Color color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          value: value,
          color: color,
          strokeWidth: strokeWidth ?? (size * 0.06).clamp(1.5, 6.0),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
  });

  final int value;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final q = size.shortestSide * 0.2;
    paintBidozenalGlyph(
      canvas,
      value,
      Offset(size.width / 2, size.height / 2),
      q,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.value != value ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
