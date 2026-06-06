// Compact input keypad for the curve plotter: enter f(x) in dozenal. Reuses the
// shared calc glyphs + emits shared KeypadEvent/Tok (incl. the variable `x`).
// Fixed-height rows so it sits inside the scrollable controls panel.

import 'package:flutter/material.dart';

import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/glyphs.dart';
import 'package:geometrie_spielzeug/calc/input.dart';

class KurveKeypad extends StatelessWidget {
  const KurveKeypad({super.key, required this.onKey});

  final void Function(KeypadEvent) onKey;

  static const double _rowHeight = 46;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget digit(int v) => _Key(
          onTap: () => onKey(InsertTok(DigitTok(v))),
          child: BidozenalGlyph(value: v, size: 26, color: scheme.onSurface),
        );
    Widget txt(String label, KeypadEvent e, {Color? color, bool italic = false}) =>
        _Key(
          onTap: () => onKey(e),
          child: Text(
            label,
            style: TextStyle(
              color: color ?? scheme.onSurfaceVariant,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        );
    Widget op(BinOp o) =>
        txt(o.symbol, InsertTok(OpTok(o)), color: scheme.primary);
    Widget fn(FuncId id) => txt(id.label, InsertTok(FuncTok(id)));

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
          op(BinOp.pow),
          txt('.', const InsertTok(DotTok())),
          txt('◀', const MoveLeft()),
          txt('▶', const MoveRight()),
        ]),
        row([fn(FuncId.sin), fn(FuncId.cos), fn(FuncId.tan), fn(FuncId.sqrt)]),
        row([
          fn(FuncId.ln),
          fn(FuncId.log10),
          txt(ConstId.pi.label, const InsertTok(ConstTok(ConstId.pi))),
          txt(ConstId.e.label, const InsertTok(ConstTok(ConstId.e))),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          canRequestFocus: false, // keep the keyboard focus on the plot
          child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: child)),
        ),
      ),
    );
  }
}
