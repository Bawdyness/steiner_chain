// Exact rational arithmetic + positional expansion with period detection,
// generalised to any base. Adapted from the dozenal calculator's
// lib/logic/rational.dart (BigInt-based, always reduced) — there the base was
// fixed at 12; here `expand` takes the base so the same school-algorithm drives
// the base-24 display and the base-10/base-12 conversion read-outs.
//
// Self-contained: imports only `digits.dart` (for kBase + char rendering).

import 'digits.dart';

/// Decomposition of |value| into a positional expansion in some base:
/// integer digits, the pre-period fractional digits, and the repeating
/// period (empty iff the expansion is finite in that base).
typedef PeriodicExpansion = ({
  List<int> intDigits,
  List<int> preDigits,
  List<int> period,
});

/// Exact rational number. Invariants: `den > 0`, fraction always reduced.
class Rational {
  final BigInt num;
  final BigInt den;

  const Rational._(this.num, this.den);

  /// Reduced constructor. Returns null on `den == 0`.
  static Rational? tryNew(BigInt num, BigInt den) {
    if (den == BigInt.zero) return null;
    final g = num.gcd(den);
    final gg = g == BigInt.zero ? BigInt.one : g;
    final sign = den.isNegative ? -BigInt.one : BigInt.one;
    return Rational._(sign * (num ~/ gg), sign * (den ~/ gg));
  }

  factory Rational.fromInt(int n) => Rational._(BigInt.from(n), BigInt.one);
  factory Rational.fromBig(BigInt n) => Rational._(n, BigInt.one);

  static final Rational zero = Rational._(BigInt.zero, BigInt.one);
  static final Rational one = Rational._(BigInt.one, BigInt.one);

  bool get isInteger => den == BigInt.one;
  bool get isZero => num == BigInt.zero;
  bool get isNegative => num.isNegative;

  // --- Arithmetic. BigInt removes any overflow failure mode; the only
  //     remaining failure is division by zero (handled by the caller). ---

  Rational add(Rational o) => tryNew(num * o.den + o.num * den, den * o.den)!;
  Rational sub(Rational o) => tryNew(num * o.den - o.num * den, den * o.den)!;
  Rational mul(Rational o) => tryNew(num * o.num, den * o.den)!;

  /// Returns null on division by zero.
  Rational? div(Rational o) =>
      o.num == BigInt.zero ? null : tryNew(num * o.den, den * o.num);

  /// Integer power (negative exponent allowed). Returns null on `0^negative`.
  Rational? pow(int exp) {
    if (exp == 0) return one;
    if (exp < 0) {
      if (num == BigInt.zero) return null;
      return tryNew(den, num)!.pow(-exp);
    }
    var result = one, base = this, e = exp;
    while (e > 0) {
      if (e & 1 == 1) result = result.mul(base);
      base = base.mul(base);
      e >>= 1;
    }
    return result;
  }

  Rational get negated => Rational._(-num, den);
  double toDouble() => num.toDouble() / den.toDouble();

  // --- Period detection — classical school algorithm over remainders. ---

  /// Positional expansion of |value| in [base]. `period` is empty iff the
  /// expansion is finite. The period is capped at [maxDigits]; beyond that the
  /// result is treated as non-periodic (a safety bound for pathological dens).
  /// Sign is dropped — the magnitude is what's returned.
  PeriodicExpansion expand({int base = kBase, int maxDigits = 1024}) {
    final absNum = num.abs();
    final d = den; // positive by invariant
    final intDigits = digitsForBigInt(absNum ~/ d, base: base);
    var rem = absNum % d;

    final frac = <int>[];
    final seen = <BigInt, int>{};
    final b = BigInt.from(base);

    while (true) {
      if (rem == BigInt.zero) {
        return (intDigits: intDigits, preDigits: frac, period: const <int>[]);
      }
      final firstPos = seen[rem];
      if (firstPos != null) {
        return (
          intDigits: intDigits,
          preDigits: frac.sublist(0, firstPos),
          period: frac.sublist(firstPos),
        );
      }
      if (frac.length >= maxDigits) {
        return (intDigits: intDigits, preDigits: frac, period: const <int>[]);
      }
      seen[rem] = frac.length;
      rem *= b;
      frac.add((rem ~/ d).toInt());
      rem %= d;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Rational && other.num == num && other.den == den;
  @override
  int get hashCode => Object.hash(num, den);
  @override
  String toString() => den == BigInt.one ? '$num' : '$num/$den';
}

/// Non-negative magnitude of [value] → digit list (most-significant first) in
/// [base]. Zero renders as `[0]`.
List<int> digitsForBigInt(BigInt value, {int base = kBase}) {
  if (value.isNegative) value = -value;
  if (value == BigInt.zero) return <int>[0];
  final b = BigInt.from(base);
  final out = <int>[];
  while (value > BigInt.zero) {
    out.add((value % b).toInt());
    value = value ~/ b;
  }
  return out.reversed.toList();
}

/// Approximate decomposition of an f64 [v] into integer + fractional digits in
/// [base], for the f64-fallback display (State B). The fractional part stops at
/// [fracDigits] or once the residual drops below a small epsilon. Sign dropped.
({List<int> intDigits, List<int> fracDigits}) doubleToBaseDigits(
  double v, {
  int base = kBase,
  int fracDigits = 6,
}) {
  const eps = 1e-6;
  v = v.abs();
  // Snap off f64 noise: sin(30°) = 0.499999999999999994 must read as 0.C, not
  // 0.BNNNN…. 12 significant figures is plenty for an "≈" display.
  v = double.parse(v.toStringAsPrecision(12));
  final ints = <int>[];
  var ip = v.floorToDouble();
  if (ip < 1.0) {
    ints.add(0);
  } else {
    while (ip >= 1.0) {
      ints.add((ip % base).floor());
      ip = (ip / base).floorToDouble();
    }
    ints.setAll(0, ints.reversed.toList());
  }
  final frac = <int>[];
  var f = v - v.floorToDouble();
  for (var i = 0; i < fracDigits && f.abs() > eps; i++) {
    f *= base;
    var d = (f + eps).floor(); // nudge so 11.9999998 reads as 12, not 11
    if (d >= base) d = base - 1;
    if (d < 0) d = 0;
    frac.add(d);
    f -= d;
  }
  return (intDigits: ints, fracDigits: frac);
}

/// Renders [r] in [base] as a flat string, marking any period with brackets,
/// e.g. `0.[4J]` for 1/5 in base 24. Long periods are truncated with `…`.
/// Uses the minus sign U+2212 to match the operator glyphs.
String renderInBase(Rational r, int base, {int maxPeriod = 48}) {
  final e = r.expand(base: base);
  final sb = StringBuffer();
  if (r.isNegative && !r.isZero) sb.write('−');
  for (final d in e.intDigits) {
    sb.write(bidozenalChar(d));
  }
  if (e.preDigits.isNotEmpty || e.period.isNotEmpty) {
    sb.write('.');
    for (final d in e.preDigits) {
      sb.write(bidozenalChar(d));
    }
    if (e.period.isNotEmpty) {
      sb.write('[');
      final shown =
          e.period.length > maxPeriod ? e.period.sublist(0, maxPeriod) : e.period;
      for (final d in shown) {
        sb.write(bidozenalChar(d));
      }
      if (e.period.length > maxPeriod) sb.write('…');
      sb.write(']');
    }
  }
  return sb.toString();
}
