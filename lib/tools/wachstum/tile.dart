// Wachstum's tiles now run on the shared calc core: the four operators are
// calc `BinOp` (add/sub/mul/div), and tile values are exact `Rational`s, so the
// whole growth chain is computed without floating-point drift and can be shown
// in any base (10/12/24).

import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/rational.dart';

/// The four operators Wachstum offers (a subset of calc `BinOp`).
const List<BinOp> kWachstumOps = [
  BinOp.add,
  BinOp.sub,
  BinOp.mul,
  BinOp.div,
];

extension WachstumBinOp on BinOp {
  /// LaTeX operator for the live `\xrightarrow{…}` formula.
  String get tex => switch (this) {
        BinOp.add => '+',
        BinOp.sub => '-',
        BinOp.mul => r'\times',
        BinOp.div => r'\div',
        BinOp.mod => r'\bmod',
        BinOp.pow => '^',
        BinOp.par => r'\oplus',
      };

  /// Applies the operator. Division by zero returns null (the editor forbids a
  /// zero divisor, so this is only a safety net).
  Rational? applyTo(Rational current, Rational value) => switch (this) {
        BinOp.add => current.add(value),
        BinOp.sub => current.sub(value),
        BinOp.mul => current.mul(value),
        BinOp.div => current.div(value),
        BinOp.mod => value.isZero ? null : current.sub(value.mul(_floorDiv(current, value))),
        BinOp.pow => null, // not offered by Wachstum
        BinOp.par => null, // not offered by Wachstum
      };
}

Rational _floorDiv(Rational a, Rational b) {
  final q = a.div(b)!;
  // floor of a rational
  var f = q.num ~/ q.den;
  if (q.isNegative && q.num % q.den != BigInt.zero) f -= BigInt.one;
  return Rational.fromBig(f);
}

class WachstumTile {
  const WachstumTile({required this.op, required this.value});
  final BinOp op;
  final Rational value;

  WachstumTile copyWith({BinOp? op, Rational? value}) =>
      WachstumTile(op: op ?? this.op, value: value ?? this.value);
}

/// The running sequence `[y0, y0∘t0, (y0∘t0)∘t1, …]` (length tiles.length + 1),
/// computed exactly. A division by zero (should be prevented upstream) freezes
/// the running value rather than producing ∞.
List<Rational> checkpointValues(Rational y0, List<WachstumTile> tiles) {
  final values = <Rational>[y0];
  var y = y0;
  for (final tile in tiles) {
    y = tile.op.applyTo(y, tile.value) ?? y;
    values.add(y);
  }
  return values;
}
