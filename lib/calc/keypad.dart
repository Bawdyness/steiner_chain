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
import 'glyphs.dart';
import 'input.dart';

/// The number block shared by Wachstum and the curve plotter: digits
/// `0..base-1` as glyphs in 3 columns, bottom row `1·2·3` rising to the highest
/// digit then `0` at the end (the dozenal_calc_flutter layout). Trailing empty
/// cells (e.g. base 10) keep the grid aligned. Lives in a scroll view, so each
/// row is a fixed [rowHeight].
class GlyphDigitPad extends StatelessWidget {
  const GlyphDigitPad({
    super.key,
    required this.base,
    required this.onDigit,
    required this.rowHeight,
  });

  final int base;
  final void Function(int value) onDigit;
  final double rowHeight;

  static const int _cols = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = [for (var d = 1; d < base; d++) d, 0]; // 1..base-1, then 0
    final rowCount = (order.length + _cols - 1) ~/ _cols;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rowCount; r++)
          SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                for (var c = 0; c < _cols; c++)
                  Expanded(
                    child: _cell((rowCount - 1 - r) * _cols + c, order, scheme),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(int idx, List<int> order, ColorScheme scheme) {
    if (idx >= order.length) return const SizedBox();
    final value = order[idx];
    return CalcKey(
      onTap: () => onDigit(value),
      child: BidozenalGlyph(value: value, size: 24, color: scheme.onSurface),
    );
  }
}

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
class ScientificKeypad extends StatefulWidget {
  const ScientificKeypad({
    super.key,
    required this.onKey,
    required this.isArmed,
    this.rowHeight,
    this.collapsible = false,
    this.trailingOp = BinOp.pow,
  });

  final void Function(KeypadEvent) onKey;
  final bool Function(FuncId) isArmed;
  final double? rowHeight;

  /// The 4th key in the ln/log/√ row: `^` (calculator) or `⊕` (plotter).
  final BinOp trailingOp;

  /// When true, only the trig row stays visible; the hyperbolic, log/√/^,
  /// n!/|x|/1/x/mod and constant rows fold behind a "Mehr Funktionen" toggle
  /// (default collapsed) to save vertical space. Requires a fixed [rowHeight].
  final bool collapsible;

  @override
  State<ScientificKeypad> createState() => _ScientificKeypadState();
}

class _ScientificKeypadState extends State<ScientificKeypad> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trig = [
      for (final f in const [FuncId.sin, FuncId.cos, FuncId.tan, FuncId.cot])
        _func(f, scheme),
    ];
    // Hyperbolic … constants (the part Kurve folds away).
    final advanced = <List<Widget>>[
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
        _op(widget.trailingOp, scheme),
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

    if (!widget.collapsible) {
      return Column(
        mainAxisSize:
            widget.rowHeight == null ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final r in [trig, ...advanced]) _row(r)],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(trig),
        _toggle(scheme),
        if (_expanded) for (final r in advanced) _row(r),
      ],
    );
  }

  Widget _toggle(ColorScheme scheme) => SizedBox(
        height: widget.rowHeight,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
          label: Text(_expanded ? 'Weniger' : 'Mehr Funktionen'),
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
        ),
      );

  Widget _row(List<Widget> keys) {
    final row = Row(children: [for (final k in keys) Expanded(child: k)]);
    return widget.rowHeight == null
        ? Expanded(child: row)
        : SizedBox(height: widget.rowHeight, child: row);
  }

  Widget _func(FuncId id, ColorScheme scheme) => _key(
        _keyLabel(id), InsertTok(FuncTok(id)), scheme,
        armed: widget.isArmed(id),
      );

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
      onTap: () => widget.onKey(event),
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
