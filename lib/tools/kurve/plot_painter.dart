// x-y plot for the curve tool: a pan/zoomable Cartesian viewport that samples
// a compiled f(x) per pixel column and draws the curve. Tick labels render in a
// chosen base (default 12 / dozenal) via the shared calc digits, so the grid is
// "dozenal". The Wachstum-style growth is a sweep: only the part of the curve
// with x ≤ [sweepX] is drawn, and the area under it is filled — the curve and
// its area visibly grow left→right, fast through steep stretches.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:geometrie_spielzeug/calc/rational.dart';

/// The visible data window. Immutable; pan/zoom produce new instances.
class PlotView {
  const PlotView(this.xMin, this.xMax, this.yMin, this.yMax);

  final double xMin, xMax, yMin, yMax;

  double get xRange => xMax - xMin;
  double get yRange => yMax - yMin;

  /// Default window: x,y ∈ [−10, 10] in dozenal (= −12..12 decimal).
  static const PlotView initial = PlotView(-12, 12, -12, 12);

  PlotView pan(double dxData, double dyData) =>
      PlotView(xMin + dxData, xMax + dxData, yMin + dyData, yMax + dyData);

  /// Zoom by [factor] (>1 zooms out) about the data point ([cx], [cy]).
  PlotView zoom(double factor, double cx, double cy) => PlotView(
        cx - (cx - xMin) * factor,
        cx + (xMax - cx) * factor,
        cy - (cy - yMin) * factor,
        cy + (yMax - cy) * factor,
      );
}

/// Geometry binding a [PlotView] to a pixel [Size]: projection both ways.
/// Shared by the painter and the page (the page converts gesture pixels to
/// data units for pan/zoom).
class PlotGeom {
  PlotGeom(this.size, this.view);
  final Size size;
  final PlotView view;

  static const double leftPad = 46, rightPad = 14, topPad = 14, bottomPad = 26;

  double get left => leftPad;
  double get right => size.width - rightPad;
  double get top => topPad;
  double get bottom => size.height - bottomPad;
  double get width => right - left;
  double get height => bottom - top;

  double xToPx(double x) => left + (x - view.xMin) / view.xRange * width;
  double yToPy(double y) => bottom - (y - view.yMin) / view.yRange * height;
  double pxToX(double px) => view.xMin + (px - left) / width * view.xRange;
  double pyToY(double py) => view.yMin + (bottom - py) / height * view.yRange;

  /// Data-units per pixel — for converting gesture deltas to pan amounts.
  double get xPerPx => view.xRange / width;
  double get yPerPx => view.yRange / height;
}

class PlotPainter extends CustomPainter {
  PlotPainter({
    required this.f,
    required this.view,
    required this.sweepX,
    required this.scheme,
    required this.textStyle,
    this.base = 12,
    this.hasFunction = true,
  });

  /// Compiled function; returns NaN where undefined (drawn as a gap).
  final double Function(double) f;
  final PlotView view;

  /// Curve is drawn for x ≤ sweepX (the growth front).
  final double sweepX;
  final ColorScheme scheme;
  final TextStyle textStyle;
  final int base;
  final bool hasFunction;

  static const Color _gridColor = Color(0xFF9CCC65); // same green as Wachstum

  @override
  void paint(Canvas canvas, Size size) {
    final g = PlotGeom(size, view);
    _drawGrid(canvas, g);
    _drawAxes(canvas, g);
    if (hasFunction) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(g.left, g.top, g.right, g.bottom));
      _drawCurve(canvas, g);
      canvas.restore();
    }
  }

  // ---- grid + axis labels (dozenal ticks) --------------------------------

  void _drawGrid(Canvas canvas, PlotGeom g) {
    final minor = Paint()
      ..color = _gridColor.withValues(alpha: 0.12)
      ..strokeWidth = 0.6;
    final major = Paint()
      ..color = _gridColor.withValues(alpha: 0.30)
      ..strokeWidth = 0.9;
    final labelStyle = textStyle.copyWith(
      color: _gridColor.withValues(alpha: 0.85),
      fontSize: (textStyle.fontSize ?? 14) - 3,
    );

    final xticks = _ticks(view.xMin, view.xMax, base: base);
    for (final t in xticks) {
      final px = g.xToPx(t.pos);
      canvas.drawLine(Offset(px, g.top), Offset(px, g.bottom), major);
      _label(canvas, renderInBase(t.value, base),
          Offset(px, g.bottom + 4), Alignment.topCenter, labelStyle);
      // minor subdivisions (fifths)
      _minorLines(canvas, g, t.pos, xticks.step, minor, vertical: true);
    }
    final yticks = _ticks(view.yMin, view.yMax, base: base);
    for (final t in yticks) {
      if (t.value.isZero) continue; // 0 sits on the axis label spot
      final py = g.yToPy(t.pos);
      canvas.drawLine(Offset(g.left, py), Offset(g.right, py), major);
      _label(canvas, renderInBase(t.value, base),
          Offset(g.left - 5, py), Alignment.centerRight, labelStyle);
      _minorLines(canvas, g, t.pos, yticks.step, minor, vertical: false);
    }
  }

  void _minorLines(Canvas canvas, PlotGeom g, double majorPos, double step,
      Paint paint, {required bool vertical}) {
    for (var k = 1; k < 5; k++) {
      final p = majorPos + step * k / 5;
      if (vertical) {
        if (p <= view.xMin || p >= view.xMax) continue;
        final px = g.xToPx(p);
        canvas.drawLine(Offset(px, g.top), Offset(px, g.bottom), paint);
      } else {
        if (p <= view.yMin || p >= view.yMax) continue;
        final py = g.yToPy(p);
        canvas.drawLine(Offset(g.left, py), Offset(g.right, py), paint);
      }
    }
  }

  void _drawAxes(Canvas canvas, PlotGeom g) {
    final axis = Paint()
      ..color = scheme.outline.withValues(alpha: 0.9)
      ..strokeWidth = 1.2;
    if (view.yMin <= 0 && view.yMax >= 0) {
      final y0 = g.yToPy(0);
      canvas.drawLine(Offset(g.left, y0), Offset(g.right, y0), axis);
    }
    if (view.xMin <= 0 && view.xMax >= 0) {
      final x0 = g.xToPx(0);
      canvas.drawLine(Offset(x0, g.top), Offset(x0, g.bottom), axis);
    }
  }

  // ---- curve + growth sweep ----------------------------------------------

  void _drawCurve(Canvas canvas, PlotGeom g) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = scheme.primary;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = scheme.primary.withValues(alpha: 0.16);

    final xEnd = math.min(view.xMax, sweepX);
    if (xEnd <= view.xMin) return;
    final y0Px = g.yToPy(0).clamp(g.top, g.bottom);
    final maxJump = g.height * 2; // break the path across poles

    // One sample per ~1.5 px for a smooth curve.
    final cols = (g.width / 1.5).clamp(2, 4000).toInt();
    var runStroke = <Offset>[];

    void flushRun() {
      if (runStroke.length < 2) {
        runStroke = [];
        return;
      }
      final fillPath = Path()..moveTo(runStroke.first.dx, y0Px);
      for (final p in runStroke) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath
        ..lineTo(runStroke.last.dx, y0Px)
        ..close();
      canvas.drawPath(fillPath, fill);
      final line = Path()..moveTo(runStroke.first.dx, runStroke.first.dy);
      for (final p in runStroke.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(line, stroke);
      runStroke = [];
    }

    double? prevPy;
    for (var i = 0; i <= cols; i++) {
      final x = view.xMin + (xEnd - view.xMin) * i / cols;
      final y = f(x);
      if (!y.isFinite) {
        flushRun();
        prevPy = null;
        continue;
      }
      final py = g.yToPy(y);
      if (prevPy != null && (py - prevPy).abs() > maxJump) {
        flushRun(); // likely a pole — start a fresh run
      }
      runStroke.add(Offset(g.xToPx(x), py));
      prevPy = py;
    }
    flushRun();

    // Growth-front marker at the sweep tip.
    if (sweepX < view.xMax) {
      final yTip = f(xEnd);
      if (yTip.isFinite) {
        final tip = Offset(g.xToPx(xEnd), g.yToPy(yTip));
        canvas.drawCircle(tip, 12, Paint()..color = scheme.primary.withValues(alpha: 0.22));
        canvas.drawCircle(tip, 5.5, Paint()..color = scheme.primary);
      }
    }
  }

  void _label(Canvas canvas, String text, Offset anchor, Alignment align,
      TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = anchor.dx - tp.width * (align.x + 1) / 2;
    final dy = anchor.dy - tp.height * (align.y + 1) / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant PlotPainter old) => true;
}

// ---------------------------------------------------------------------------
// Dozenal-friendly tick generation: step = mant × baseStep^exp with mant chosen
// from {1,2,3,4,6} so labels stay clean single-ish digits in base 12. Tick
// values are exact Rationals so renderInBase prints them precisely.
// ---------------------------------------------------------------------------

class _TickList extends Iterable<({double pos, Rational value})> {
  _TickList(this._ticks, this.step);
  final List<({double pos, Rational value})> _ticks;
  final double step;
  @override
  Iterator<({double pos, Rational value})> get iterator => _ticks.iterator;
}

_TickList _ticks(double lo, double hi, {int approx = 8, int base = 12}) {
  final range = hi - lo;
  if (range <= 0 || !range.isFinite) {
    return _TickList(const [], 1);
  }
  final raw = range / approx;
  const mants = [1, 2, 3, 4, 6];
  final b = base.toDouble();
  var exp = (math.log(raw) / math.log(b)).floor();
  var bestVal = double.infinity, bestMant = 1, bestExp = exp;
  for (var e = exp - 1; e <= exp + 1; e++) {
    for (final m in mants) {
      final v = m * math.pow(b, e).toDouble();
      if (v >= raw && v < bestVal) {
        bestVal = v;
        bestMant = m;
        bestExp = e;
      }
    }
  }
  final step = bestMant * math.pow(b, bestExp).toDouble();
  final bigBase = BigInt.from(base);
  Rational tickValue(int i) {
    final n = BigInt.from(i * bestMant);
    if (bestExp >= 0) {
      return Rational.fromBig(n * bigBase.pow(bestExp));
    }
    return Rational.tryNew(n, bigBase.pow(-bestExp))!;
  }

  final first = (lo / step).ceil();
  final last = (hi / step).floor();
  final out = <({double pos, Rational value})>[];
  for (var i = first; i <= last && out.length < 40; i++) {
    out.add((pos: i * step, value: tickValue(i)));
  }
  return _TickList(out, step);
}
