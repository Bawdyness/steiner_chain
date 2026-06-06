import 'package:flutter_test/flutter_test.dart';
import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/rational.dart';
import 'package:geometrie_spielzeug/tools/wachstum/tile.dart';

WachstumTile _t(BinOp op, int v) =>
    WachstumTile(op: op, value: Rational.fromInt(v));

void main() {
  group('checkpointValues — exact growth chain (shared calc core)', () {
    test('y₀=1, [+1,+3,+5] → [1,2,5,10]', () {
      final ys = checkpointValues(
        Rational.fromInt(1),
        [_t(BinOp.add, 1), _t(BinOp.add, 3), _t(BinOp.add, 5)],
      );
      expect(ys.map((r) => r.toString()).toList(), ['1', '2', '5', '10']);
    });

    test('length is tiles.length + 1', () {
      expect(checkpointValues(Rational.zero, [_t(BinOp.add, 1)]).length, 2);
      expect(checkpointValues(Rational.zero, const []).length, 1);
    });

    test('division chain stays exact: y₀=10, [÷3, ÷2] → [10, 10/3, 5/3]', () {
      final ys = checkpointValues(
        Rational.fromInt(10),
        [_t(BinOp.div, 3), _t(BinOp.div, 2)],
      );
      expect(ys[1], Rational.tryNew(BigInt.from(10), BigInt.from(3)));
      expect(ys[2], Rational.tryNew(BigInt.from(5), BigInt.from(3)));
    });

    test('mixed ×/− chain: y₀=2, [×3, −1] → [2, 6, 5]', () {
      final ys = checkpointValues(
        Rational.fromInt(2),
        [_t(BinOp.mul, 3), _t(BinOp.sub, 1)],
      );
      expect(ys.map((r) => r.toString()).toList(), ['2', '6', '5']);
    });
  });

  group('base-aware display of checkpoints', () {
    test('value 10 (dec) renders per base', () {
      final ten = Rational.fromInt(10);
      expect(renderInBase(ten, 10), '10');
      expect(renderInBase(ten, 12), 'A');
      expect(renderInBase(ten, 24), 'A');
    });

    test('1/3 terminates in 12 and 24 but repeats in 10', () {
      final third = Rational.tryNew(BigInt.one, BigInt.from(3))!;
      expect(renderInBase(third, 10), '0.[3]');
      expect(renderInBase(third, 12), '0.4'); // 4/12
      expect(renderInBase(third, 24), '0.8'); // 8/24
    });
  });

  group('operator helpers', () {
    test('Wachstum offers exactly + − × ÷', () {
      expect(kWachstumOps, [BinOp.add, BinOp.sub, BinOp.mul, BinOp.div]);
    });
    test('applyTo: division by zero returns null (safety net)', () {
      expect(BinOp.div.applyTo(Rational.one, Rational.zero), isNull);
      expect(BinOp.mul.applyTo(Rational.fromInt(3), Rational.fromInt(4)),
          Rational.fromInt(12));
    });
    test('tex symbols for the live formula', () {
      expect(BinOp.mul.tex, r'\times');
      expect(BinOp.div.tex, r'\div');
    });
  });
}
