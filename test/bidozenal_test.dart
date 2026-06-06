import 'package:flutter_test/flutter_test.dart';
import 'package:geometrie_spielzeug/tools/bidozenal/digits.dart';
import 'package:geometrie_spielzeug/tools/bidozenal/evaluator.dart';
import 'package:geometrie_spielzeug/tools/bidozenal/rational.dart';

/// Builds a digit-only number token list from a bidozenal literal like "1A.6".
List<Tok> _num(String literal) {
  final toks = <Tok>[];
  for (final ch in literal.split('')) {
    if (ch == '.') {
      toks.add(const DotTok());
    } else {
      final v = bidozenalValue(ch);
      if (v == null) throw ArgumentError('bad digit: $ch');
      toks.add(DigitTok(v));
    }
  }
  return toks;
}

Rational? _exact(List<Tok> t) => evaluate(t, AngleMode.deg).exact;
String _exactStr(List<Tok> t) => renderInBase(_exact(t)!, 24);

void main() {
  group('digit chars', () {
    test('value → char covers 0-9 A-N', () {
      expect(bidozenalChar(0), '0');
      expect(bidozenalChar(10), 'A');
      expect(bidozenalChar(12), 'C');
      expect(bidozenalChar(23), 'N');
    });
    test('char → value round-trips, case-insensitive', () {
      for (var v = 0; v < kBase; v++) {
        expect(bidozenalValue(bidozenalChar(v)), v);
      }
      expect(bidozenalValue('n'), 23);
      expect(bidozenalValue('Z'), isNull);
    });
  });

  group('reciprocals — single-digit terminators (doc §3)', () {
    String recip(int d) =>
        renderInBase(Rational.tryNew(BigInt.one, BigInt.from(d))!, 24);
    test('1/2 = 0.C', () => expect(recip(2), '0.C'));
    test('1/3 = 0.8', () => expect(recip(3), '0.8'));
    test('1/8 = 0.3', () => expect(recip(8), '0.3'));
    test('1/24 = 0.1', () => expect(recip(24), '0.1'));
  });

  group('reciprocals — periodic', () {
    test('1/5 = 0.[4J] (period length 2)', () {
      final r = Rational.tryNew(BigInt.one, BigInt.from(5))!;
      expect(r.expand(base: 24).period, [4, 19]);
      expect(renderInBase(r, 24), '0.[4J]');
    });
  });

  group('positional values + arithmetic (exact rail)', () {
    test('"10" = 24, "100" = 576', () {
      expect(_exact(_num('10')), Rational.fromInt(24));
      expect(_exact(_num('100')), Rational.fromInt(576));
    });
    test('"1.6" = 5/4', () {
      expect(_exact(_num('1.6')), Rational.tryNew(BigInt.from(5), BigInt.from(4)));
    });
    test('10 + 10 = 20  (48 dec)', () {
      expect(_exactStr([..._num('10'), const OpTok(BinOp.add), ..._num('10')]), '20');
    });
    test('10 × 10 = 100  (576 dec)', () {
      expect(_exactStr([..._num('10'), const OpTok(BinOp.mul), ..._num('10')]), '100');
    });
    test('1 ÷ 5 is exact periodic', () {
      expect(_exactStr([..._num('1'), const OpTok(BinOp.div), ..._num('5')]), '0.[4J]');
    });
    test('precedence: 2 + 3 × 4 = 14 dec', () {
      expect(_exact([..._num('2'), const OpTok(BinOp.add), ..._num('3'),
        const OpTok(BinOp.mul), ..._num('4')]), Rational.fromInt(14));
    });
    test('parentheses: (2 + 3) × 4 = 20 dec', () {
      expect(_exact([const LParenTok(), ..._num('2'), const OpTok(BinOp.add),
        ..._num('3'), const RParenTok(), const OpTok(BinOp.mul), ..._num('4')]),
        Rational.fromInt(20));
    });
    test('implicit multiplication: 2(3) = 6', () {
      expect(_exact([..._num('2'), const LParenTok(), ..._num('3'), const RParenTok()]),
        Rational.fromInt(6));
    });
    test('unary minus: −3 × 2 = −6', () {
      expect(_exact([const OpTok(BinOp.sub), ..._num('3'),
        const OpTok(BinOp.mul), ..._num('2')]), Rational.fromInt(-6));
    });
  });

  group('exact-preserving functions/operators', () {
    test('integer power 2^3 = 8 exact', () {
      expect(_exact([..._num('2'), const OpTok(BinOp.pow), ..._num('3')]),
        Rational.fromInt(8));
    });
    test('5! = 78 bidoz (120 dec) exact', () {
      // 120 dec = 5·24 = "50"
      expect(_exactStr([..._num('5'), const FuncTok(FuncId.fact)]), '50');
    });
    test('1/x of 5 = 0.[4J] exact', () {
      expect(_exactStr([..._num('5'), const FuncTok(FuncId.recip)]), '0.[4J]');
    });
    test('|x| of 5 = 5 exact', () {
      expect(_exact([..._num('5'), const FuncTok(FuncId.abs)]), Rational.fromInt(5));
    });
    test('7 mod 3 = 1 exact', () {
      expect(_exact([..._num('7'), const OpTok(BinOp.mod), ..._num('3')]),
        Rational.fromInt(1));
    });
  });

  group('f64 fallback (rail B)', () {
    test('√4 ≈ 2, no exact', () {
      final r = evaluate([const FuncTok(FuncId.sqrt), ..._num('4')], AngleMode.deg);
      expect(r.exact, isNull);
      expect(r.approx, closeTo(2.0, 1e-9));
    });
    test('sin(30°) ≈ 0.5  (operand "16" = 30 dec)', () {
      final r = evaluate([const FuncTok(FuncId.sin), ..._num('16')], AngleMode.deg);
      expect(r.exact, isNull);
      expect(r.approx, closeTo(0.5, 1e-9));
    });
    test('sin(30°) f64 noise snaps to 0.C, not 0.BNN…', () {
      // f64 sin(30°) = 0.49999999999999994 — must render as a single C (12/24).
      expect(doubleToBaseDigits(0.49999999999999994, base: 24).fracDigits, [12]);
    });
    test('π collapses to f64', () {
      final r = evaluate(const [ConstTok(ConstId.pi)], AngleMode.deg);
      expect(r.exact, isNull);
      expect(r.approx, closeTo(3.141592653589793, 1e-12));
    });
    test('non-integer exponent 2^(1.6) collapses', () {
      final r = evaluate([..._num('2'), const OpTok(BinOp.pow), ..._num('1.6')],
        AngleMode.deg);
      expect(r.exact, isNull);
      expect(r.approx, closeTo(2.378414, 1e-5)); // 2^1.25
    });
    test('angle mode matters: sin(30 rad) ≠ 0.5', () {
      final r = evaluate([const FuncTok(FuncId.sin), ..._num('16')], AngleMode.rad);
      expect(r.approx, isNot(closeTo(0.5, 1e-3)));
    });
  });

  group('errors', () {
    test('division by zero', () {
      expect(evaluate([..._num('1'), const OpTok(BinOp.div), ..._num('0')],
        AngleMode.deg).error, 'Division durch 0');
    });
    test('domain error √(0−1)', () {
      final t = [const FuncTok(FuncId.sqrt), const LParenTok(),
        ..._num('0'), const OpTok(BinOp.sub), ..._num('1'), const RParenTok()];
      expect(evaluate(t, AngleMode.deg).error, 'Bereichsfehler');
    });
    test('trailing operator is a syntax error', () {
      expect(evaluate([..._num('1'), const OpTok(BinOp.add)], AngleMode.deg).error,
        'Syntaxfehler');
    });
    test('empty input is neutral', () {
      expect(evaluate(const [], AngleMode.deg),
        (exact: null, approx: null, error: null));
    });
  });

  group('RatLit (Ans / continuation)', () {
    test('exact periodic value survives a RatLit round-trip', () {
      final oneFifth = Rational.tryNew(BigInt.one, BigInt.from(5))!;
      // RatLit(1/5) × 5 = 1 exactly — no precision loss.
      final t = [RatLitTok(oneFifth), const OpTok(BinOp.mul), ..._num('5')];
      expect(_exact(t), Rational.one);
    });
  });

  group('inverse-swap pairs', () {
    test('trig/hyp functions are mutually inverse', () {
      expect(FuncId.sin.inverse, FuncId.asin);
      expect(FuncId.asin.inverse, FuncId.sin);
      expect(FuncId.tanh.inverse, FuncId.artanh);
      expect(FuncId.ln.inverse, isNull);
      expect(FuncId.fact.isPostfix, isTrue);
      expect(FuncId.sqrt.isPrefix, isTrue);
    });
  });

  group('base conversions (doc §5)', () {
    test('"100" bidoz = 576 dec = "400" dozenal', () {
      final r = _exact(_num('100'))!;
      expect(renderInBase(r, 10), '576');
      expect(renderInBase(r, 12), '400');
    });
    test('1/5 dozenal repeats with period 2497', () {
      expect(renderInBase(Rational.tryNew(BigInt.one, BigInt.from(5))!, 12),
        '0.[2497]');
    });
  });
}
