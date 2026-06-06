// Input model + two-rail evaluator for the bidozenal calculator.
//
// Two rails, exactly as in the dozenal calculator: an exact BigInt [Rational]
// rail and an f64 rail. Pure arithmetic (+ − × ÷, integer powers, n!, |x|, 1/x)
// stays on the exact rail; anything transcendental (trig, log, √, non-integer
// powers, the constants π/e/φ/√2) collapses to f64 and is shown with an "≈".
//
// The f64 numerics (`_applyFunc`, the arsinh/tanh/fact guards, the acot
// convention, the AngleMode handling) are ported verbatim from the dozenal
// calculator's lib/logic/expression.dart — battle-tested edge cases.
//
// Self-contained: imports only `digits.dart` (kBase) and `rational.dart`.

import 'dart:math' as math;

import 'digits.dart';
import 'rational.dart';

/// Angle interpretation for trig in/out. Mirrors the dozenal AngleMode.
enum AngleMode {
  deg,
  rad,
  grad;

  String get label => switch (this) {
        AngleMode.deg => 'DEG',
        AngleMode.rad => 'RAD',
        AngleMode.grad => 'GRD',
      };

  AngleMode get next => switch (this) {
        AngleMode.deg => AngleMode.rad,
        AngleMode.rad => AngleMode.grad,
        AngleMode.grad => AngleMode.deg,
      };

  double toRad(double x) => switch (this) {
        AngleMode.deg => x * math.pi / 180.0,
        AngleMode.rad => x,
        AngleMode.grad => x * math.pi / 200.0,
      };

  double radToUnit(double x) => switch (this) {
        AngleMode.deg => x * 180.0 / math.pi,
        AngleMode.rad => x,
        AngleMode.grad => x * 200.0 / math.pi,
      };
}

/// Binary operators, carrying the glyph shown on the key / in the display.
enum BinOp {
  add('+'),
  sub('−'),
  mul('×'),
  div('÷'),
  mod('mod'),
  pow('^');

  const BinOp(this.symbol);
  final String symbol;
}

/// Unary functions. Prefix ones (sin … √, ln, log) are entered before their
/// operand; postfix ones (n!, |x|, 1/x) after it.
enum FuncId {
  sin, cos, tan, cot,
  asin, acos, atan, acot,
  sinh, cosh, tanh, coth,
  arsinh, arcosh, artanh, arcoth,
  ln, log10, sqrt,
  fact, abs, recip;

  bool get isPostfix =>
      this == FuncId.fact || this == FuncId.abs || this == FuncId.recip;
  bool get isPrefix => !isPostfix;

  /// Label for the input/result line and (mostly) the key.
  String get label => switch (this) {
        FuncId.sin => 'sin',
        FuncId.cos => 'cos',
        FuncId.tan => 'tan',
        FuncId.cot => 'cot',
        FuncId.asin => 'sin⁻¹',
        FuncId.acos => 'cos⁻¹',
        FuncId.atan => 'tan⁻¹',
        FuncId.acot => 'cot⁻¹',
        FuncId.sinh => 'sinh',
        FuncId.cosh => 'cosh',
        FuncId.tanh => 'tanh',
        FuncId.coth => 'coth',
        FuncId.arsinh => 'sinh⁻¹',
        FuncId.arcosh => 'cosh⁻¹',
        FuncId.artanh => 'tanh⁻¹',
        FuncId.arcoth => 'coth⁻¹',
        FuncId.ln => 'ln',
        FuncId.log10 => 'log',
        FuncId.sqrt => '√',
        FuncId.fact => '!',
        FuncId.abs => '|x|',
        FuncId.recip => '1/x',
      };

  /// The inverse counterpart for the double-tap toggle, or null.
  FuncId? get inverse => switch (this) {
        FuncId.sin => FuncId.asin,
        FuncId.asin => FuncId.sin,
        FuncId.cos => FuncId.acos,
        FuncId.acos => FuncId.cos,
        FuncId.tan => FuncId.atan,
        FuncId.atan => FuncId.tan,
        FuncId.cot => FuncId.acot,
        FuncId.acot => FuncId.cot,
        FuncId.sinh => FuncId.arsinh,
        FuncId.arsinh => FuncId.sinh,
        FuncId.cosh => FuncId.arcosh,
        FuncId.arcosh => FuncId.cosh,
        FuncId.tanh => FuncId.artanh,
        FuncId.artanh => FuncId.tanh,
        FuncId.coth => FuncId.arcoth,
        FuncId.arcoth => FuncId.coth,
        _ => null,
      };
}

/// Irrational constants.
enum ConstId {
  pi('π', math.pi),
  e('e', math.e),
  phi('φ', 1.618033988749895),
  sqrt2('√2', math.sqrt2);

  const ConstId(this.label, this.value);
  final String label;
  final double value;
}

/// A single editable input token.
sealed class Tok {
  const Tok();
}

class DigitTok extends Tok {
  const DigitTok(this.value);
  final int value; // 0..23
}

class DotTok extends Tok {
  const DotTok();
}

class OpTok extends Tok {
  const OpTok(this.op);
  final BinOp op;
}

class LParenTok extends Tok {
  const LParenTok();
}

class RParenTok extends Tok {
  const RParenTok();
}

class FuncTok extends Tok {
  const FuncTok(this.id);
  final FuncId id;
}

class ConstTok extends Tok {
  const ConstTok(this.id);
  final ConstId id;
}

/// Exact rational literal injected by Ans / RCL / "continue from result".
/// Carries the value so periodicity survives without precision loss.
class RatLitTok extends Tok {
  const RatLitTok(this.value, {this.label = 'Ans'});
  final Rational value;
  final String label;
}

/// Result of evaluating a token stream:
///   - [error] != null            → SYNTAX / DOMAIN / DIV BY ZERO,
///   - [exact] != null            → exact rational (rail A; [approx] also set),
///   - [exact] == null, [approx]  → f64 fallback (rail B, shown with "≈"),
///   - all null                   → empty / still-incomplete input.
typedef EvalResult = ({Rational? exact, double? approx, String? error});

const int _maxExactExponent = 4096; // guard runaway BigInt powers
const int _maxFactorial = 4096;

EvalResult evaluate(List<Tok> input, AngleMode angleMode) {
  if (input.isEmpty) return (exact: null, approx: null, error: null);
  _Node ast;
  try {
    ast = _Parser(input).parseTop();
  } on _EvalException catch (e) {
    return (exact: null, approx: null, error: e.message);
  }
  final double f;
  try {
    f = _f64(ast, angleMode);
  } on _EvalException catch (e) {
    return (exact: null, approx: null, error: e.message);
  }
  if (f.isNaN) return (exact: null, approx: null, error: 'Bereichsfehler');
  if (f.isInfinite) return (exact: null, approx: null, error: 'Division durch 0');
  final exact = _exact(ast);
  return (exact: exact, approx: f, error: null);
}

// ---------------------------------------------------------------------------
// AST
// ---------------------------------------------------------------------------

sealed class _Node {}

class _Num extends _Node {
  _Num(this.value);
  final Rational value;
}

class _Const extends _Node {
  _Const(this.value);
  final double value;
}

class _Bin extends _Node {
  _Bin(this.op, this.l, this.r);
  final BinOp op;
  final _Node l, r;
}

class _Neg extends _Node {
  _Neg(this.child);
  final _Node child;
}

class _Pow extends _Node {
  _Pow(this.base, this.exp);
  final _Node base, exp;
}

class _Func extends _Node {
  _Func(this.id, this.arg);
  final FuncId id;
  final _Node arg;
}

// ---------------------------------------------------------------------------
// Exact rail — returns null as soon as a value goes transcendental.
// ---------------------------------------------------------------------------

Rational? _exact(_Node n) {
  switch (n) {
    case _Num():
      return n.value;
    case _Const():
      return null; // irrational
    case _Neg():
      final c = _exact(n.child);
      return c?.negated;
    case _Bin():
      final l = _exact(n.l);
      final r = _exact(n.r);
      if (l == null || r == null) return null;
      switch (n.op) {
        case BinOp.add:
          return l.add(r);
        case BinOp.sub:
          return l.sub(r);
        case BinOp.mul:
          return l.mul(r);
        case BinOp.div:
          return l.div(r); // null on ÷0 → f64 reports DIV BY ZERO
        case BinOp.mod:
          if (!l.isInteger || !r.isInteger || r.isZero) return null;
          return Rational.fromBig(l.num % r.num);
        case BinOp.pow:
          return null; // handled by _Pow
      }
    case _Pow():
      final base = _exact(n.base);
      final e = _exact(n.exp);
      if (base == null || e == null || !e.isInteger) return null;
      if (e.num.abs() > BigInt.from(_maxExactExponent)) return null;
      return base.pow(e.num.toInt());
    case _Func():
      final c = _exact(n.arg);
      if (c == null) return null;
      switch (n.id) {
        case FuncId.abs:
          return c.isNegative ? c.negated : c;
        case FuncId.recip:
          return c.isZero ? null : Rational.one.div(c);
        case FuncId.fact:
          if (!c.isInteger || c.isNegative) return null;
          if (c.num > BigInt.from(_maxFactorial)) return null;
          var r = BigInt.one;
          for (var i = BigInt.two; i <= c.num; i += BigInt.one) {
            r *= i;
          }
          return Rational.fromBig(r);
        default:
          return null; // transcendental
      }
  }
}

// ---------------------------------------------------------------------------
// f64 rail
// ---------------------------------------------------------------------------

double _f64(_Node n, AngleMode mode) {
  switch (n) {
    case _Num():
      return n.value.toDouble();
    case _Const():
      return n.value;
    case _Neg():
      return -_f64(n.child, mode);
    case _Bin():
      final l = _f64(n.l, mode);
      final r = _f64(n.r, mode);
      return switch (n.op) {
        BinOp.add => l + r,
        BinOp.sub => l - r,
        BinOp.mul => l * r,
        BinOp.div => l / r,
        BinOp.mod => l % r,
        BinOp.pow => math.pow(l, r).toDouble(),
      };
    case _Pow():
      return math.pow(_f64(n.base, mode), _f64(n.exp, mode)).toDouble();
    case _Func():
      return _applyFunc(n.id, _f64(n.arg, mode), mode);
  }
}

double _applyFunc(FuncId id, double x, AngleMode mode) {
  switch (id) {
    case FuncId.sin:
      return math.sin(mode.toRad(x));
    case FuncId.cos:
      return math.cos(mode.toRad(x));
    case FuncId.tan:
      return math.tan(mode.toRad(x));
    case FuncId.cot:
      return 1.0 / math.tan(mode.toRad(x));
    case FuncId.asin:
      return mode.radToUnit(math.asin(x));
    case FuncId.acos:
      return mode.radToUnit(math.acos(x));
    case FuncId.atan:
      return mode.radToUnit(math.atan(x));
    case FuncId.acot:
      // Convention A: range (0, π), formula π/2 − atan(x).
      return mode.radToUnit(math.pi / 2.0 - math.atan(x));
    case FuncId.sinh:
      return _sinh(x);
    case FuncId.cosh:
      return _cosh(x);
    case FuncId.tanh:
      return _tanh(x);
    case FuncId.coth:
      return _cosh(x) / _sinh(x);
    case FuncId.arsinh:
      // Symmetric form: the naive log(x+√(x²+1)) cancels catastrophically
      // for negative x.
      return x < 0
          ? -math.log(-x + math.sqrt(x * x + 1.0))
          : math.log(x + math.sqrt(x * x + 1.0));
    case FuncId.arcosh:
      return math.log(x + math.sqrt(x * x - 1.0));
    case FuncId.artanh:
      return 0.5 * math.log((1.0 + x) / (1.0 - x));
    case FuncId.arcoth:
      return 0.5 * math.log((x + 1.0) / (x - 1.0));
    case FuncId.ln:
      return math.log(x);
    case FuncId.log10:
      return math.log(x) / math.ln10;
    case FuncId.sqrt:
      return math.sqrt(x);
    case FuncId.fact:
      return _factF64(x);
    case FuncId.abs:
      return x.abs();
    case FuncId.recip:
      return 1.0 / x;
  }
}

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2.0;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2.0;
double _tanh(double x) {
  if (x > 20.0) return 1.0;
  if (x < -20.0) return -1.0;
  final ex = math.exp(x);
  final emx = math.exp(-x);
  return (ex - emx) / (ex + emx);
}

double _factF64(double x) {
  if (x.isNaN || x.isInfinite) return double.nan;
  final n = x.round();
  if (n < 0) return double.nan;
  var r = BigInt.one;
  for (var i = 1; i <= n; i++) {
    r *= BigInt.from(i);
  }
  return r.toDouble();
}

// ---------------------------------------------------------------------------
// Parser. Grammar (precedence low → high):
//   expr    := addSub
//   addSub  := mulDiv (('+'|'−') mulDiv)*
//   mulDiv  := unary  (('×'|'÷'|mod) unary | implicit-mul-operand)*
//   unary   := ('−'|'+') unary | pow
//   pow     := postfix ('^' unary)?            (right-assoc)
//   postfix := primary (postfix-func)*         (n!, |x|, 1/x)
//   primary := '(' expr ')' | number | const | ratlit | prefix-func primary
// ---------------------------------------------------------------------------

class _EvalException implements Exception {
  const _EvalException(this.message);
  final String message;
}

class _Parser {
  _Parser(this.toks);
  final List<Tok> toks;
  int _i = 0;

  Tok? get _peek => _i < toks.length ? toks[_i] : null;
  void _advance() => _i++;

  _Node parseTop() {
    final v = _addSub();
    if (_i != toks.length) throw const _EvalException('Syntaxfehler');
    return v;
  }

  _Node _addSub() {
    var acc = _mulDiv();
    while (true) {
      final t = _peek;
      if (t is OpTok && (t.op == BinOp.add || t.op == BinOp.sub)) {
        _advance();
        acc = _Bin(t.op, acc, _mulDiv());
      } else {
        return acc;
      }
    }
  }

  _Node _mulDiv() {
    var acc = _unary();
    while (true) {
      final t = _peek;
      if (t is OpTok &&
          (t.op == BinOp.mul || t.op == BinOp.div || t.op == BinOp.mod)) {
        _advance();
        acc = _Bin(t.op, acc, _unary());
      } else if (_startsFactor(t)) {
        acc = _Bin(BinOp.mul, acc, _unary()); // implicit multiplication
      } else {
        return acc;
      }
    }
  }

  bool _startsFactor(Tok? t) =>
      t is DigitTok ||
      t is DotTok ||
      t is LParenTok ||
      t is ConstTok ||
      t is RatLitTok ||
      (t is FuncTok && t.id.isPrefix);

  _Node _unary() {
    final t = _peek;
    if (t is OpTok && t.op == BinOp.sub) {
      _advance();
      return _Neg(_unary());
    }
    if (t is OpTok && t.op == BinOp.add) {
      _advance();
      return _unary();
    }
    return _pow();
  }

  _Node _pow() {
    final base = _postfix();
    final t = _peek;
    if (t is OpTok && t.op == BinOp.pow) {
      _advance();
      return _Pow(base, _unary()); // right-assoc, exponent may be unary
    }
    return base;
  }

  _Node _postfix() {
    var node = _primary();
    while (true) {
      final t = _peek;
      if (t is FuncTok && t.id.isPostfix) {
        _advance();
        node = _Func(t.id, node);
      } else {
        return node;
      }
    }
  }

  _Node _primary() {
    final t = _peek;
    if (t is LParenTok) {
      _advance();
      final v = _addSub();
      if (_peek is RParenTok) _advance(); // lenient: missing ')' closes at end
      return v;
    }
    if (t is ConstTok) {
      _advance();
      return _Const(t.id.value);
    }
    if (t is RatLitTok) {
      _advance();
      return _Num(t.value);
    }
    if (t is FuncTok && t.id.isPrefix) {
      _advance();
      return _Func(t.id, _primary());
    }
    if (t is DigitTok || t is DotTok) return _number();
    throw const _EvalException('Syntaxfehler');
  }

  _Node _number() {
    final b = BigInt.from(kBase);
    var intVal = BigInt.zero;
    var sawDigit = false;
    while (_peek is DigitTok) {
      intVal = intVal * b + BigInt.from((_peek as DigitTok).value);
      sawDigit = true;
      _advance();
    }
    var fracNum = BigInt.zero;
    var fracDen = BigInt.one;
    if (_peek is DotTok) {
      _advance();
      while (_peek is DigitTok) {
        fracNum = fracNum * b + BigInt.from((_peek as DigitTok).value);
        fracDen *= b;
        sawDigit = true;
        _advance();
      }
    }
    if (!sawDigit) return _Num(Rational.zero); // a lone '.'
    return _Num(Rational.tryNew(intVal * fracDen + fracNum, fracDen)!);
  }
}
