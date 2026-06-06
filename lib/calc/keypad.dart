// Shared keypad widgets for calculator-style tools (the bidozenal calculator
// and the curve plotter). Lives in lib/calc/ so the tools draw from ONE
// definition instead of copying the key chrome and the scientific function set.
//
//   - [CalcKey]          — the shared rounded key chrome (Material + InkWell).
//   - [ScientificKeypad] — the canonical trig / hyperbolic / log / constant
//     grid, with sin↔sin⁻¹ double-tap arming. Used by the calculator's f(x)
//     page and by the plotter, so the two never drift apart.

import 'package:flutter/material.dart';

import 'evaluator.dart';
import 'input.dart';

/// Shared key chrome: rounded surface, ink response, optional [fill] colour.
/// A null [onTap] renders a disabled key (no ink, not tappable).
class CalcKey extends StatelessWidget {
  const CalcKey({super.key, required this.child, required this.onTap, this.fill});

  final Widget child;
  final VoidCallback? onTap;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: fill ?? scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Don't steal the page's keyboard-focus node on tap, so physical-
          // keyboard input keeps working after a screen tap.
          canRequestFocus: false,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// The canonical scientific function + constant keys: trig, hyperbolic, ln/log/
/// √, n!/|x|/1/x, ^/mod, and the constants. Forward trig/hyperbolic keys arm
/// their inverse on a second tap (sin → sin⁻¹), shown via [isArmed].
///
/// Rows fill the available height when [rowHeight] is null (each row is
/// [Expanded]); pass a fixed [rowHeight] to sit inside a scroll view.
class ScientificKeypad extends StatelessWidget {
  const ScientificKeypad({
    super.key,
    required this.onKey,
    required this.isArmed,
    this.rowHeight,
  });

  final void Function(KeypadEvent) onKey;
  final bool Function(FuncId) isArmed;
  final double? rowHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <List<Widget>>[
      [
        for (final f in const [FuncId.sin, FuncId.cos, FuncId.tan, FuncId.cot])
          _func(f, scheme),
      ],
      [
        for (final f in const [
          FuncId.sinh,
          FuncId.cosh,
          FuncId.tanh,
          FuncId.coth,
        ])
          _func(f, scheme),
      ],
      [
        _func(FuncId.ln, scheme),
        _func(FuncId.log10, scheme),
        _func(FuncId.sqrt, scheme),
        _op(BinOp.pow, scheme),
      ],
      [
        _func(FuncId.fact, scheme),
        _func(FuncId.abs, scheme),
        _func(FuncId.recip, scheme),
        _op(BinOp.mod, scheme),
      ],
      [
        for (final c in ConstId.values)
          _key(c.label, InsertTok(ConstTok(c)), scheme),
      ],
    ];
    return Column(
      mainAxisSize: rowHeight == null ? MainAxisSize.max : MainAxisSize.min,
      children: [for (final r in rows) _row(r)],
    );
  }

  Widget _row(List<Widget> keys) {
    final row = Row(children: [for (final k in keys) Expanded(child: k)]);
    return rowHeight == null
        ? Expanded(child: row)
        : SizedBox(height: rowHeight, child: row);
  }

  Widget _func(FuncId id, ColorScheme scheme) =>
      _key(_keyLabel(id), InsertTok(FuncTok(id)), scheme, armed: isArmed(id));

  Widget _op(BinOp o, ColorScheme scheme) =>
      _key(o.symbol, InsertTok(OpTok(o)), scheme, color: scheme.primary);

  Widget _key(
    String label,
    KeypadEvent event,
    ColorScheme scheme, {
    Color? color,
    bool armed = false,
  }) {
    return CalcKey(
      onTap: () => onKey(event),
      child: Stack(
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color ?? scheme.onSurfaceVariant,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (armed)
            Positioned(
              top: 4,
              right: 5,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The factorial key reads "n!"; everything else uses the token label.
  static String _keyLabel(FuncId id) => id == FuncId.fact ? 'n!' : id.label;
}
