import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geometrie_spielzeug/calc/digits.dart';
import 'package:geometrie_spielzeug/calc/rational.dart';
import 'tile.dart';

/// Auto-Zoom-Skala: hält den Datenbereich symmetrisch um Null und rastet
/// auf hübsche Halbreiten ein (5, 10, 20, 50, 100, …). Major-Schritt ist
/// immer ein Fünftel der Halbreite, Minor-Schritt ein Fünftel des Majors —
/// so wirkt das Gerüst optisch gleich, egal wie groß die Skala wird.
class WachstumScale {
  const WachstumScale({
    required this.yHalfRange,
    required this.yMajorStep,
    required this.yMinorStep,
  });

  final double yHalfRange;
  final double yMajorStep;
  final double yMinorStep;

  static const List<double> _niceHalfRanges = [
    5, 10, 20, 50, 100, 200, 500, 1000,
    2000, 5000, 10000, 20000, 50000, 100000, 1000000,
  ];

  factory WachstumScale.forValues(List<double> values) {
    final maxAbs = values.fold<double>(
      0,
      (m, v) => v.isFinite ? math.max(m, v.abs()) : m,
    );
    final padded = math.max(maxAbs * 1.15, 1);
    for (final r in _niceHalfRanges) {
      if (r >= padded) {
        return WachstumScale(
          yHalfRange: r,
          yMajorStep: r / 5,
          yMinorStep: r / 25,
        );
      }
    }
    final r = _niceHalfRanges.last;
    return WachstumScale(
      yHalfRange: r,
      yMajorStep: r / 5,
      yMinorStep: r / 25,
    );
  }
}

/// Geometrie des Wachstum-Plots. Wird sowohl vom Painter (Achsen, Gitter,
/// Kurve) als auch von der Page (Kachel-Bar, die unten überlagert wird)
/// benutzt — `tToX` muss in beiden Welten dieselben Pixel liefern, sonst
/// stehen die Kacheln nicht über ihren Zeit-Intervallen.
class WachstumLayout {
  const WachstumLayout({
    required this.canvasSize,
    required this.scale,
    required this.tMin,
    required this.tMax,
    required this.leftPad,
    required this.rightPad,
    required this.topPad,
    required this.bottomPad,
  });

  final Size canvasSize;
  final WachstumScale scale;
  final double tMin;
  final double tMax;
  final double leftPad;
  final double rightPad;
  final double topPad;
  final double bottomPad;

  double get plotLeft => leftPad;
  double get plotRight => canvasSize.width - rightPad;
  double get plotTop => topPad;
  double get plotBottom => canvasSize.height - bottomPad;
  double get plotWidth => plotRight - plotLeft;
  double get plotHeight => plotBottom - plotTop;

  double get zeroY => (plotTop + plotBottom) / 2;
  double get pxPerYUnit => plotHeight / 2 / scale.yHalfRange;
  double get pxPerT => plotWidth / (tMax - tMin);

  double tToX(double t) => plotLeft + (t - tMin) * pxPerT;
  double yToY(double y) => zeroY - y * pxPerYUnit;
  Offset project(double t, double y) => Offset(tToX(t), yToY(y));

  Rect get plotRect => Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom);

  static WachstumLayout compute({
    required Size size,
    required WachstumScale scale,
    required double tMin,
    required double tMax,
    required double bottomInset,
  }) {
    return WachstumLayout(
      canvasSize: size,
      scale: scale,
      tMin: tMin,
      tMax: tMax,
      leftPad: 48,
      rightPad: 88,
      topPad: 24,
      bottomPad: bottomInset,
    );
  }
}

class WachstumPainter extends CustomPainter {
  WachstumPainter({
    required this.y0,
    required this.tiles,
    required this.currentT,
    required this.layout,
    required this.colorScheme,
    required this.textStyle,
    this.base = 10,
  });

  final Rational y0;
  final List<WachstumTile> tiles;
  final double currentT;
  final WachstumLayout layout;
  final ColorScheme colorScheme;
  final TextStyle textStyle;
  final int base;

  /// Checkpoint values as doubles for plotting (exact Rationals → pixels).
  List<double> _ysDouble() =>
      checkpointValues(y0, tiles).map((r) => r.toDouble()).toList();

  /// Hellgrünes Gerüst — analog zu den Pizzaschnitten beim Einheitskreis,
  /// aber mit eigener Farbe, weil das Wachstum-Tool kein Akzent-Farbschema
  /// vom Material-Theme erbt.
  static const Color _gridColor = Color(0xFF9CCC65);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(layout.plotRect);
    _drawGrid(canvas);
    _drawCurve(canvas);
    _drawCheckpointDots(canvas);
    canvas.restore();
    _drawAxes(canvas);
    _drawYLabels(canvas);
    _drawTLabels(canvas);
    _drawMarker(canvas);
  }

  void _drawGrid(Canvas canvas) {
    final minor = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = _gridColor.withValues(alpha: 0.14);
    final major = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _gridColor.withValues(alpha: 0.32);

    final hr = layout.scale.yHalfRange;
    final minorStep = layout.scale.yMinorStep;
    final majorStep = layout.scale.yMajorStep;
    final minorCount = (hr / minorStep).round();

    for (int i = -minorCount; i <= minorCount; i++) {
      if (i % 5 == 0) continue; // Major überzeichnet das ohnehin
      final y = i * minorStep;
      canvas.drawLine(
        Offset(layout.plotLeft, layout.yToY(y)),
        Offset(layout.plotRight, layout.yToY(y)),
        minor,
      );
    }
    final majorCount = (hr / majorStep).round();
    for (int i = -majorCount; i <= majorCount; i++) {
      final y = i * majorStep;
      canvas.drawLine(
        Offset(layout.plotLeft, layout.yToY(y)),
        Offset(layout.plotRight, layout.yToY(y)),
        major,
      );
    }
    for (int t = layout.tMin.ceil(); t <= layout.tMax.floor(); t++) {
      final x = layout.tToX(t.toDouble());
      canvas.drawLine(
        Offset(x, layout.plotTop),
        Offset(x, layout.plotBottom),
        major,
      );
    }
  }

  void _drawCurve(Canvas canvas) {
    final ys = _ysDouble();
    if (currentT <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = colorScheme.primary;

    final endT = currentT.clamp(0.0, tiles.length.toDouble());
    final fullSegments = endT.floor();
    final partial = endT - fullSegments;

    final path = Path()..moveTo(layout.tToX(0), layout.yToY(ys[0]));

    const samplesPerSegment = 20;
    for (var i = 0; i < fullSegments; i++) {
      _appendSegment(path, ys[i], ys[i + 1], i, 1.0, samplesPerSegment);
    }
    if (partial > 0 && fullSegments < tiles.length) {
      final samples = math.max(2, (samplesPerSegment * partial).ceil());
      _appendSegment(
        path,
        ys[fullSegments],
        ys[fullSegments + 1],
        fullSegments,
        partial,
        samples,
      );
    }
    canvas.drawPath(path, paint);
  }

  /// Fügt der Pfad-Spur ein Schwung-Segment hinzu: x wächst linear in der
  /// Zeit, y interpoliert per `smoothstep` (horizontale Tangenten an
  /// Anfang und Ende — exakt die geforderte „horizontal → vertikal →
  /// horizontal"-Bewegung).
  void _appendSegment(
    Path path,
    double yStart,
    double yEnd,
    int segmentIndex,
    double maxLocalT,
    int samples,
  ) {
    for (var s = 1; s <= samples; s++) {
      final localT = (s / samples) * maxLocalT;
      final eased = _smoothstep(localT);
      final t = segmentIndex + localT;
      final v = yStart + (yEnd - yStart) * eased;
      path.lineTo(layout.tToX(t), layout.yToY(v));
    }
  }

  void _drawAxes(Canvas canvas) {
    final axis = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = colorScheme.outline.withValues(alpha: 0.9);
    canvas.drawLine(
      Offset(layout.plotLeft - 4, layout.zeroY),
      Offset(layout.plotRight + 14, layout.zeroY),
      axis,
    );
    final xZero = layout.tToX(0);
    canvas.drawLine(
      Offset(xZero, layout.plotTop - 12),
      Offset(xZero, layout.plotBottom + 4),
      axis,
    );
    _drawArrow(canvas, Offset(layout.plotRight + 14, layout.zeroY),
        const Offset(1, 0));
    _drawArrow(canvas, Offset(xZero, layout.plotTop - 12),
        const Offset(0, -1));

    final letterStyle = textStyle.copyWith(
      color: colorScheme.onSurface,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
      fontSize: (textStyle.fontSize ?? 14) + 1,
    );
    _paintLabel(canvas, 't',
        Offset(layout.plotRight + 26, layout.zeroY + 2),
        Alignment.centerLeft, letterStyle);
    _paintLabel(canvas, 'y', Offset(xZero, layout.plotTop - 24),
        Alignment.center, letterStyle);
  }

  void _drawArrow(Canvas canvas, Offset tip, Offset dir) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.outline.withValues(alpha: 0.9);
    final perp = Offset(-dir.dy, dir.dx);
    final base = tip - dir * 9;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + perp.dx * 4, base.dy + perp.dy * 4)
      ..lineTo(base.dx - perp.dx * 4, base.dy - perp.dy * 4)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawYLabels(Canvas canvas) {
    final hr = layout.scale.yHalfRange;
    final majorStep = layout.scale.yMajorStep;
    final style = textStyle.copyWith(
      color: _gridColor.withValues(alpha: 0.85),
      fontSize: (textStyle.fontSize ?? 14) - 2,
    );
    final majorCount = (hr / majorStep).round();
    for (int i = -majorCount; i <= majorCount; i++) {
      if (i == 0) continue;
      final y = i * majorStep;
      _paintLabel(
        canvas,
        _fmtBase(y, base),
        Offset(layout.plotLeft - 6, layout.yToY(y)),
        Alignment.centerRight,
        style,
      );
    }
  }

  void _drawTLabels(Canvas canvas) {
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = colorScheme.outline.withValues(alpha: 0.9);
    final style = textStyle.copyWith(
      color: colorScheme.onSurface.withValues(alpha: 0.85),
      fontSize: (textStyle.fontSize ?? 14) - 2,
    );
    for (int t = math.max(layout.tMin.ceil(), 0);
        t <= layout.tMax.floor();
        t++) {
      final x = layout.tToX(t.toDouble());
      canvas.drawLine(
        Offset(x, layout.zeroY - 4),
        Offset(x, layout.zeroY + 4),
        tickPaint,
      );
      _paintLabel(canvas, renderInBase(Rational.fromInt(t), base),
          Offset(x, layout.zeroY + 16), Alignment.bottomCenter, style);
    }
  }

  void _drawCheckpointDots(Canvas canvas) {
    final ys = _ysDouble();
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.primary.withValues(alpha: 0.55);
    final passed = currentT.floor().clamp(0, tiles.length);
    // Startpunkt als heller Punkt, damit y₀ auch ohne Animation sichtbar ist
    final startPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.onSurface.withValues(alpha: 0.55);
    canvas.drawCircle(layout.project(0, ys[0]), 3.2, startPaint);
    for (var i = 1; i <= passed; i++) {
      canvas.drawCircle(layout.project(i.toDouble(), ys[i]), 2.8, paint);
    }
  }

  void _drawMarker(Canvas canvas) {
    final ys = _ysDouble();
    final (pos, value) = _markerState(ys);
    final inside = layout.plotRect.inflate(20).contains(pos);
    if (!inside) return;

    final halo = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.primary.withValues(alpha: 0.22);
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.primary;

    canvas.drawCircle(pos, 14, halo);
    canvas.drawCircle(pos, 6.5, dot);

    _paintLabel(
      canvas,
      'y = ${_fmtBase(value, base)}',
      Offset(pos.dx + 16, pos.dy - 2),
      Alignment.centerLeft,
      textStyle.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  (Offset, double) _markerState(List<double> ys) {
    if (tiles.isEmpty || currentT <= 0) {
      return (layout.project(0, ys[0]), ys[0]);
    }
    final clamped = currentT.clamp(0.0, tiles.length.toDouble());
    if (clamped >= tiles.length) {
      return (layout.project(tiles.length.toDouble(), ys.last), ys.last);
    }
    final i = clamped.floor();
    final local = clamped - i;
    final eased = _smoothstep(local);
    final v = ys[i] + (ys[i + 1] - ys[i]) * eased;
    return (layout.project(clamped, v), v);
  }

  @override
  bool shouldRepaint(covariant WachstumPainter old) => true;

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset anchor,
    Alignment align,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = anchor.dx - tp.width * (align.x + 1) / 2;
    final dy = anchor.dy - tp.height * (align.y + 1) / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  static double _smoothstep(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// Zahlen kompakt formatieren — ganzzahlig ohne Dezimalstellen, sonst
  /// auf 2 Nachkommastellen, sehr große oder sehr kleine Werte
  /// exponentiell. Minus-Zeichen wird je nach Kontext als ASCII `-` oder
  /// Unicode `−` ausgegeben.
  static String _fmt(double v, {bool signedMinus = false}) {
    if (!v.isFinite) return v.isNaN ? 'NaN' : (v < 0 ? '−∞' : '∞');
    final minus = signedMinus ? '−' : '-';
    if (v == 0) return '0';
    final abs = v.abs();
    String body;
    if (abs >= 1e5 || (abs < 1e-2 && abs > 0)) {
      body = abs.toStringAsExponential(1);
    } else if (abs == abs.roundToDouble()) {
      body = abs.toStringAsFixed(0);
    } else {
      body = abs.toStringAsFixed(2);
    }
    return v < 0 ? '$minus$body' : body;
  }

  /// Base-aware number label. Base 10 keeps the familiar decimal formatting
  /// (incl. exponential for extremes); base 12/24 render the digits via the
  /// shared calc converter (chars 0-9/A-N), two fractional places.
  static String _fmtBase(double v, int base) {
    if (base == 10) return _fmt(v, signedMinus: true);
    if (!v.isFinite) return v.isNaN ? 'NaN' : (v < 0 ? '−∞' : '∞');
    final parts = doubleToBaseDigits(v.abs(), base: base, fracDigits: 2);
    final sb = StringBuffer(v < 0 ? '−' : '');
    for (final d in parts.intDigits) {
      sb.write(bidozenalChar(d));
    }
    if (parts.fracDigits.isNotEmpty) {
      sb.write('.');
      for (final d in parts.fracDigits) {
        sb.write(bidozenalChar(d));
      }
    }
    return sb.toString();
  }
}
