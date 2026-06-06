import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/keyboard.dart';
import 'package:geometrie_spielzeug/tools/kurve/plot_painter.dart';

void main() {
  group('plot variable x', () {
    test('f(x)=x² at x=3 → 9 on f64; exact rail collapses', () {
      final t = [const VarTok(), const OpTok(BinOp.pow), const DigitTok(2)];
      final r = evaluate(t, AngleMode.rad, x: 3);
      expect(r.exact, isNull); // a function of x has no single exact value
      expect(r.approx, closeTo(9, 1e-9));
    });

    test('compileF64 evaluates one parsed AST at many x', () {
      final f = compileF64(const [VarTok()], AngleMode.rad); // f(x)=x
      expect(f(7), 7);
      expect(f(-2.5), -2.5);
    });

    test('sin(x) is radian-based in the plotter', () {
      final f = compileF64(
          const [FuncTok(FuncId.sin), VarTok()], AngleMode.rad);
      expect(f(0), closeTo(0, 1e-12));
      expect(f(math.pi / 2), closeTo(1, 1e-12));
    });

    test('2x parses as implicit 2·x', () {
      final f = compileF64(const [DigitTok(2), VarTok()], AngleMode.rad);
      expect(f(5), 10);
    });

    test('dozenal literal: "10" means 12 with base 12', () {
      // tokens 1,0 → "10"; base 12 → 12, base 24 → 24.
      final f12 = compileF64(const [DigitTok(1), DigitTok(0)], AngleMode.rad, base: 12);
      final f24 = compileF64(const [DigitTok(1), DigitTok(0)], AngleMode.rad, base: 24);
      expect(f12(0), 12);
      expect(f24(0), 24);
    });

    test('invalid expression compiles to a NaN gap, no throw', () {
      final f = compileF64(const [OpTok(BinOp.add)], AngleMode.rad);
      expect(f(1).isNaN, isTrue);
    });
  });

  group('shared keyboard does not bind x', () {
    test("'x' stays unbound so the number calculator gets no variable", () {
      expect(charEvent('x'), isNull);
      expect(charEvent('X'), isNull);
    });
  });

  group('PlotView pan/zoom', () {
    test('pan shifts the window', () {
      final v = const PlotView(-10, 10, -10, 10).pan(5, -2);
      expect(v.xMin, -5);
      expect(v.xMax, 15);
      expect(v.yMin, -12);
      expect(v.yMax, 8);
    });

    test('zoom out about origin doubles the range', () {
      final v = const PlotView(-10, 10, -10, 10).zoom(2, 0, 0);
      expect(v.xMin, -20);
      expect(v.xMax, 20);
      expect(v.yRange, 40);
    });

    test('geometry round-trips px↔data', () {
      const view = PlotView(-12, 12, -12, 12);
      final g = PlotGeom(const Size(400, 300), view);
      expect(g.pxToX(g.xToPx(3.5)), closeTo(3.5, 1e-9));
      expect(g.pyToY(g.yToPy(-4.0)), closeTo(-4.0, 1e-9));
    });
  });
}
