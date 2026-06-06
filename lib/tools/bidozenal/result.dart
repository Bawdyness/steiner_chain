// Turns an [EvalResult] into a flat, display-ready decomposition — the
// bidozenal analogue of the dozenal calculator's formatRationalResult /
// formatF64Result + PeriodMeta. The display painter consumes [BidozResult]
// without re-touching the rational engine.

import 'evaluator.dart';
import 'rational.dart';

/// Longest period rendered with an overline. Longer periods are truncated and
/// flagged with [periodCapped] → the display shows the State-C raised dots.
const int maxPeriodDisplay = 12;

/// How many fractional digits the f64 fallback emits (State B).
const int f64FracDigits = 6;

class BidozResult {
  const BidozResult({
    this.error,
    this.negative = false,
    this.intDigits = const [0],
    this.preDigits = const [],
    this.period = const [],
    this.periodCapped = false,
    this.approx = false,
  });

  /// Non-null → render this message in red instead of digits.
  final String? error;
  final bool negative;
  final List<int> intDigits;
  final List<int> preDigits;

  /// Shown period (already capped at [maxPeriodDisplay]).
  final List<int> period;

  /// True period exceeds [maxPeriodDisplay] → State C.
  final bool periodCapped;

  /// f64 fallback → State B ("≈").
  final bool approx;

  bool get isError => error != null;
}

/// Builds the display decomposition. Empty input renders as `0`.
BidozResult formatResult(EvalResult res) {
  if (res.error != null) return BidozResult(error: res.error);

  final exact = res.exact;
  if (exact != null) {
    final e = exact.expand(base: 24);
    final capped = e.period.length > maxPeriodDisplay;
    final shown =
        capped ? e.period.sublist(0, maxPeriodDisplay) : e.period;
    return BidozResult(
      negative: exact.isNegative && !exact.isZero,
      intDigits: e.intDigits,
      preDigits: e.preDigits,
      period: shown,
      periodCapped: capped,
      approx: false,
    );
  }

  final approx = res.approx;
  if (approx != null) {
    final parts = doubleToBaseDigits(approx, base: 24, fracDigits: f64FracDigits);
    return BidozResult(
      negative: approx < 0 && approx.abs() > 1e-12,
      intDigits: parts.intDigits,
      preDigits: parts.fracDigits,
      period: const [],
      periodCapped: false,
      approx: true,
    );
  }

  return const BidozResult(); // empty → 0
}
