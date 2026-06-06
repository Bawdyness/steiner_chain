// THROWAWAY DESIGN PREVIEW — renders the existing dozenal glyphs alongside the
// PROPOSED extended set (values 12..23) plus two reworked slots, into a single
// PNG so the designs can be judged visually before any decision to integrate.
//
// Self-contained: carries its OWN local copy of the drawing primitives and
// glyph definitions. Imports nothing from lib/, changes nothing in the app.
// Edit only this file to iterate on the designs.
//
// Layout: 3 columns, bottom-up (like the keypad grid). Bottom row 1·2·3,
// then 4·5·6 above it, … top row 22·23·0 (zero top-right). Column 1 (the
// values ≡ 1 mod 3) is the all-strokes / arrow column.
//
// Design notes (this iteration):
//   - NEW STROKES 13/16/19/22 = the cardinal arrows 1/4/7/10 closed into
//     triangles (same direction, value +12). Open chevron = small value,
//     closed triangle = +12. Full height (±2q), 2q wide like the half-circles.
//   - +12 COMPOSITES = an exact copy of the standing glyph 2/3/5/6/8/9/11 with
//     a small circle added in the centre as the "+12" marker. So 14←2, 15←3,
//     17←5, 18←6, 20←8, 21←9, 23←11.
//   - PURE CIRCLES 0 (single) and 12 (O/O) are neutral to both half-circle
//     systems; 12 = O/O sits at the seam as the bridge.
//   - REWORKED OLD SLOT: value 8 = O over ( (a previously-unused standing slot;
//     O/O moved up to 12).
//
// Run from the project root:
//
//   flutter test tool/preview_glyphs.dart
//
// Output: store/glyph_preview.png

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _fontFamily = 'PreviewLiberation';

Future<void> _loadFont() async {
  final file = File('tool/fonts/LiberationSans-Bold.ttf');
  final bytes = await file.readAsBytes();
  final loader = FontLoader(_fontFamily)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

// ---------------------------------------------------------------------------
// Drawing vocabulary (mirrors lib/glyph_painter.dart) plus the two NEW
// horizontal-chord ("lying") half-circles.
// Canvas coords y-down: angle 0°=right, 90°=down, 180°=left, 270°=up.
// ---------------------------------------------------------------------------

void _arc(Canvas c, Paint p, Offset center, double r, double a0, double a1) {
  final rect = Rect.fromCircle(center: center, radius: r);
  c.drawArc(rect, a0 * pi / 180, (a1 - a0) * pi / 180, false, p);
}

void _rightHalf(Canvas c, Paint p, Offset center, double r) =>
    _arc(c, p, center, r, -90, 90); //  )  standing, bulge right (existing)
void _leftHalf(Canvas c, Paint p, Offset center, double r) =>
    _arc(c, p, center, r, 90, 270); //  (  standing, bulge left  (existing)

void _arrow(Canvas c, Paint p, Offset ctr, Offset tip, Offset w1, Offset w2) {
  final t = ctr + tip;
  c.drawLine(t, ctr + w1, p);
  c.drawLine(t, ctr + w2, p);
}

// Closed triangle through three points (same geometry as _arrow but with the
// base closed). Used for the new strokes 13/16/19/22 = 1/4/7/10 closed.
void _triangle(Canvas c, Paint p, Offset ctr, Offset a, Offset b, Offset d) {
  final pa = ctr + a, pb = ctr + b, pd = ctr + d;
  final path = Path()
    ..moveTo(pa.dx, pa.dy)
    ..lineTo(pb.dx, pb.dy)
    ..lineTo(pd.dx, pd.dy)
    ..close();
  c.drawPath(path, p);
}

const _strokeNew = {13, 16, 19, 22}; // closed triangles (= 1/4/7/10 + 12)
const _bridge = {0, 12}; // pure-circle glyphs, neutral to both systems

/// Paints glyph for [value] (0..23) centred at [center] with quarter-size [q].
void _paintGlyph(Canvas c, int value, Offset center, double q, Paint p) {
  final top = center + Offset(0, -q);
  final bot = center + Offset(0, q);
  final qy = 2 * q; // strokes use full vertical extent (±2q), width stays ±q
  final cq = q * 0.4; // small centre circle marking the +12 composites

  switch (value) {
    // ---- EXISTING (0..11) — shapes unchanged; arrows now full height ----
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
    case 8: // REWORKED: O over ( (was O over O; O/O moves to value 12)
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

    // ---- EXTENSION (12..23) ----
    case 12: // BRIDGE: O over O (pure circles → compatible with both systems)
      c.drawCircle(top, q, p);
      c.drawCircle(bot, q, p);
    case 13: // △ closed triangle pointing up (= 1 closed)
      _triangle(c, p, center, Offset(0, -qy), Offset(-q, qy), Offset(q, qy));
    case 14: // copy of 2 = )/(  + centre circle
      _rightHalf(c, p, top, q);
      _leftHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 15: // copy of 3 = )/)  + centre circle
      _rightHalf(c, p, top, q);
      _rightHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 16: // ◁ closed triangle pointing left (= 4 closed)
      _triangle(c, p, center, Offset(-q, 0), Offset(q, -qy), Offset(q, qy));
    case 17: // copy of 5 = (/)  + centre circle
      _leftHalf(c, p, top, q);
      _rightHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 18: // copy of 6 = (/O  + centre circle
      _leftHalf(c, p, top, q);
      c.drawCircle(bot, q, p);
      c.drawCircle(center, cq, p);
    case 19: // ▷ closed triangle pointing right (= 7 closed)
      _triangle(c, p, center, Offset(q, 0), Offset(-q, -qy), Offset(-q, qy));
    case 20: // copy of 8 = O/(  + centre circle
      c.drawCircle(top, q, p);
      _leftHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 21: // copy of 9 = O/)  + centre circle
      c.drawCircle(top, q, p);
      _rightHalf(c, p, bot, q);
      c.drawCircle(center, cq, p);
    case 22: // ▽ closed triangle pointing down (= 10 closed)
      _triangle(c, p, center, Offset(0, qy), Offset(-q, -qy), Offset(q, -qy));
    case 23: // copy of 11 = )/O  + centre circle
      _rightHalf(c, p, top, q);
      c.drawCircle(bot, q, p);
      c.drawCircle(center, cq, p);
  }
}

// ---------------------------------------------------------------------------

void main() {
  test('generate glyph preview sheet', () async {
    await _loadFont();

    const int cols = 3;
    const int rows = 8; // 24 cells, bottom-up
    const double cell = 200.0;
    const double headerH = 156.0;
    const double width = 720.0;
    const double gridW = cols * cell; // 600
    const double gridLeft = (width - gridW) / 2; // 60
    const double height = headerH + rows * cell;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, width, height),
    );

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF1F1F1F),
    );

    void drawText(
      String s,
      Offset topLeft, {
      double size = 16,
      Color color = Colors.white,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, topLeft);
    }

    const white = Colors.white;
    const amber = Color(0xFFE0A23A); // new strokes (closed triangles)
    const green = Color(0xFF55D17A); // new lying half-circles
    const violet = Color(0xFFB388FF); // pure-circle glyphs (0, 12)

    drawText('Glyphen-Layout — unten links = 1, oben rechts = 0',
        const Offset(24, 20), size: 24);
    drawText('weiß = Bestand (8 = O über () · violett = reine Kreise 0 & 12',
        const Offset(24, 56),
        size: 15);
    drawText('bernstein = geschlossene Dreiecke 13·16·19·22 (= 1·4·7·10 + 12)',
        const Offset(24, 80),
        size: 15, color: amber);
    drawText('grün = Kopie von 2·3·5·6·8·9·11 + kleiner Mittelkreis',
        const Offset(24, 104),
        size: 15, color: green);
    drawText('            → 14·15·17·18·20·21·23', const Offset(24, 128),
        size: 15, color: green);

    final glyphPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final q = cell * 0.20;

    for (int rowTop = 0; rowTop < rows; rowTop++) {
      final rBottom = rows - 1 - rowTop; // 0 = bottom row
      for (int col = 0; col < cols; col++) {
        final value = (rBottom * 3 + col + 1) % 24; // bottom-left = 1 … 0 last
        final cellLeft = gridLeft + col * cell;
        final cellTop = headerH + rowTop * cell;
        final cx = cellLeft + cell / 2;
        final cy = cellTop + cell / 2;

        final Color color;
        if (_bridge.contains(value)) {
          color = violet;
        } else if (value <= 11) {
          color = white;
        } else if (_strokeNew.contains(value)) {
          color = amber;
        } else {
          color = green;
        }

        canvas.drawRect(
          Rect.fromLTWH(cellLeft, cellTop, cell, cell),
          Paint()
            ..color = const Color(0xFF333333)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

        drawText('$value', Offset(cellLeft + 10, cellTop + 8),
            size: 18,
            color: color == white ? const Color(0xFF888888) : color);

        glyphPaint.color = color;
        _paintGlyph(canvas, value, Offset(cx, cy), q, glyphPaint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final out = File('store/glyph_preview.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes);
    // ignore: avoid_print
    print('Wrote ${out.path} (${bytes.length} bytes)');
  });
}
