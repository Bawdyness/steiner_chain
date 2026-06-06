// The bidozenal keypad, split into two pads:
//   - [BidozenalGlyphPad]    — the 24 digit glyphs (left, full height), always
//     rendered as glyphs (brand identity). 3 cols × 8 rows, bottom-up, exactly
//     like store/glyph_preview.png: 1 bottom-left … 22·23·0 across the top row.
//   - [BidozenalFunctionPad] — paged (Basis | f(x)) operators, functions,
//     constants, memory and controls (right, under the display).
//
// Both are Columns of equal-height rows of equal-width keys, filling whatever
// area they are given. Function keys with an inverse show a small "armed" dot
// when a second tap would toggle them (e.g. sin → sin⁻¹).

import 'package:flutter/material.dart';

import 'package:geometrie_spielzeug/calc/digits.dart';
import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/glyphs.dart';
import 'package:geometrie_spielzeug/calc/input.dart';
import 'package:geometrie_spielzeug/calc/keypad.dart';

// ===========================================================================
// Glyph pad (digits)
// ===========================================================================

class BidozenalGlyphPad extends StatelessWidget {
  const BidozenalGlyphPad({super.key, required this.onKey, required this.base});

  final void Function(KeypadEvent) onKey;

  /// Active number base (10/12/24). All 24 glyphs are always rendered; digits
  /// with value >= [base] are greyed out and non-tappable.
  final int base;

  static const int _rows = 8;
  static const int _cols = 3;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          for (var rowTop = 0; rowTop < _rows; rowTop++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < _cols; col++)
                    Expanded(child: _cell(rowTop, col)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(int rowTop, int col) {
    final rBottom = _rows - 1 - rowTop;
    final v = (rBottom * _cols + col + 1) % 24;
    final active = v < base;
    return _DigitKey(
      value: v,
      active: active,
      onTap: active ? () => onKey(InsertTok(DigitTok(v))) : null,
    );
  }
}

// ===========================================================================
// Function pad (paged)
// ===========================================================================

class BidozenalFunctionPad extends StatefulWidget {
  const BidozenalFunctionPad({
    super.key,
    required this.onKey,
    required this.isArmed,
    required this.angleLabel,
  });

  final void Function(KeypadEvent) onKey;

  /// True when tapping the given function token would toggle it to its inverse.
  final bool Function(FuncId) isArmed;

  /// Current angle-mode label for the DRG key.
  final String angleLabel;

  @override
  State<BidozenalFunctionPad> createState() => _BidozenalFunctionPadState();
}

class _BidozenalFunctionPadState extends State<BidozenalFunctionPad> {
  int _page = 0; // 0 = Basis, 1 = f(x)

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          SizedBox(height: 38, child: _pageTabs(scheme)),
          const SizedBox(height: 4),
          Expanded(child: _page == 0 ? _basis(scheme) : _fx(scheme)),
        ],
      ),
    );
  }

  Widget _pageTabs(ColorScheme scheme) {
    Widget tab(String label, int index) => Expanded(
          child: CalcKey(
            onTap: () => setState(() => _page = index),
            fill: _page == index
                ? scheme.primary.withValues(alpha: 0.30)
                : null,
            child: Text(
              label,
              style: TextStyle(
                color: _page == index ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        );
    return Row(children: [tab('Basis', 0), tab('f(x)', 1)]);
  }

  // ---- Basis page --------------------------------------------------------

  Widget _basis(ColorScheme scheme) {
    return Column(
      children: [
        Expanded(
          child: Row(children: [
            _text('(', () => widget.onKey(const InsertTok(LParenTok())), scheme),
            _text(')', () => widget.onKey(const InsertTok(RParenTok())), scheme),
            _text('⌫', () => widget.onKey(const DeleteKey()), scheme),
            _text('AC', () => widget.onKey(const ClearKey()), scheme,
                color: scheme.error),
          ]),
        ),
        Expanded(
          child: Row(children: [
            _text('◀', () => widget.onKey(const MoveLeft()), scheme),
            _text('▶', () => widget.onKey(const MoveRight()), scheme),
            _text('.', () => widget.onKey(const InsertTok(DotTok())), scheme),
            _text('Ans', () => widget.onKey(const AnsKey()), scheme,
                color: scheme.tertiary),
          ]),
        ),
        Expanded(
          child: Row(children: [
            for (final op in const [BinOp.add, BinOp.sub, BinOp.mul, BinOp.div])
              _text(op.symbol, () => widget.onKey(InsertTok(OpTok(op))), scheme,
                  color: scheme.primary, big: true),
          ]),
        ),
        Expanded(
          child: Row(children: [
            _text('=', () => widget.onKey(const EqualsKey()), scheme,
                color: scheme.onTertiary, fill: scheme.tertiary, big: true),
          ]),
        ),
      ],
    );
  }

  // ---- f(x) page ---------------------------------------------------------
  //
  // The scientific functions/constants come from the shared [ScientificKeypad]
  // (also used by the curve plotter); only the calculator-specific memory/angle
  // row stays local.

  Widget _fx(ColorScheme scheme) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: ScientificKeypad(
            onKey: widget.onKey,
            isArmed: widget.isArmed,
          ),
        ),
        Expanded(
          child: Row(children: [
            _text('Sto', () => widget.onKey(const StoKey()), scheme),
            _text('Rcl', () => widget.onKey(const RclKey()), scheme),
            _text('Mc', () => widget.onKey(const McKey()), scheme),
            _text(widget.angleLabel, () => widget.onKey(const AngleKey()), scheme,
                color: scheme.tertiary),
          ]),
        ),
      ],
    );
  }

  Widget _text(
    String text,
    VoidCallback onTap,
    ColorScheme scheme, {
    Color? color,
    Color? fill,
    bool big = false,
  }) {
    return Expanded(
      child: CalcKey(
        onTap: onTap,
        fill: fill,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              color: color ?? scheme.onSurfaceVariant,
              fontSize: big ? 24 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Key widgets
// ===========================================================================

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.value,
    required this.active,
    required this.onTap,
  });

  final int value;

  /// False when [value] >= the active base: greyed out, [onTap] null.
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glyphColor = active
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.26);
    final cornerColor =
        scheme.onSurfaceVariant.withValues(alpha: active ? 0.55 : 0.22);
    return CalcKey(
      onTap: onTap,
      fill: active
          ? null
          : scheme.surfaceContainerHighest.withValues(alpha: 0.12),
      child: LayoutBuilder(
        builder: (context, c) {
          final glyphSize = c.biggest.shortestSide * 0.66;
          return Stack(
            children: [
              Positioned(
                left: 5,
                top: 3,
                child: Text(
                  bidozenalChar(value),
                  style: TextStyle(
                    color: cornerColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Center(
                child: BidozenalGlyph(
                  value: value,
                  size: glyphSize,
                  color: glyphColor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
