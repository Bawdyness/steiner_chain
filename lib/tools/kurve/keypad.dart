// Compact input keypad for the curve plotter: enter f(x) in dozenal. Reuses the
// shared calc glyphs, the shared key chrome ([CalcKey]) and the shared
// [ScientificKeypad] (so the plotter and the calculator offer the same function
// set), and emits shared KeypadEvent/Tok incl. the variable `x`. Fixed-height
// rows so it sits inside the scrollable controls panel.

import 'package:flutter/material.dart';

import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/glyphs.dart';
import 'package:geometrie_spielzeug/calc/input.dart';
import 'package:geometrie_spielzeug/calc/keypad.dart';

class KurveKeypad extends StatelessWidget {
  const KurveKeypad({super.key, required this.onKey, required this.isArmed});

  final void Function(KeypadEvent) onKey;

  /// True when tapping the given function would toggle it to its inverse
  /// (sin → sin⁻¹). Drives the armed dot in the shared [ScientificKeypad].
  final bool Function(FuncId) isArmed;

  static const double _rowHeight = 46;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget digit(int v) => CalcKey(
          onTap: () => onKey(InsertTok(DigitTok(v))),
          child: BidozenalGlyph(value: v, size: 26, color: scheme.onSurface),
        );
    Widget txt(String label, KeypadEvent e, {Color? color, bool italic = false}) =>
        CalcKey(
          onTap: () => onKey(e),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: color ?? scheme.onSurfaceVariant,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        );
    Widget op(BinOp o) =>
        txt(o.symbol, InsertTok(OpTok(o)), color: scheme.primary);

    Widget row(List<Widget> keys) => SizedBox(
          height: _rowHeight,
          child: Row(children: [for (final k in keys) Expanded(child: k)]),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([
          txt('x', const InsertTok(VarTok()), color: scheme.tertiary, italic: true),
          txt('(', const InsertTok(LParenTok())),
          txt(')', const InsertTok(RParenTok())),
          txt('⌫', const DeleteKey()),
          txt('AC', const ClearKey(), color: scheme.error),
        ]),
        row([digit(0), digit(1), digit(2), digit(3)]),
        row([digit(4), digit(5), digit(6), digit(7)]),
        row([digit(8), digit(9), digit(10), digit(11)]),
        row([op(BinOp.add), op(BinOp.sub), op(BinOp.mul), op(BinOp.div)]),
        row([
          txt('.', const InsertTok(DotTok())),
          txt('◀', const MoveLeft()),
          txt('▶', const MoveRight()),
        ]),
        // Shared with the calculator's f(x) page — one definition, no drift.
        ScientificKeypad(onKey: onKey, isArmed: isArmed, rowHeight: _rowHeight),
      ],
    );
  }
}
