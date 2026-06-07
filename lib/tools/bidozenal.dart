// Bidozenal-Rechner — an exact base-24 (tetravigesimal) scientific calculator.
//
// Sibling in spirit to the dozenal calculator, rebuilt to this repo's tool-hub
// architecture. Two evaluation rails (see bidozenal/evaluator.dart): pure
// arithmetic stays exact (BigInt Rational, periodic expansion shown with an
// overline); transcendental operations fall back to f64 and are shown with "≈".
//
// Layout: the glyph keypad fills the left column; the right column holds the
// two-line display on top and the paged function keys below. The controls panel
// shows the current value converted to decimal/dozenal/bidozenal + a KaTeX
// formula; the reference panel carries the theory and a glyph chart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../scaffold/tool_scaffold.dart';
import '../theory.dart';
import 'package:geometrie_spielzeug/calc/digits.dart';
import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/glyphs.dart';
import 'package:geometrie_spielzeug/calc/input.dart';
import 'package:geometrie_spielzeug/calc/keyboard.dart';
import 'package:geometrie_spielzeug/calc/rational.dart';
import 'bidozenal/display.dart';
import 'bidozenal/keypad.dart';
import 'bidozenal/result.dart';

class BidozenalPage extends StatefulWidget {
  const BidozenalPage({super.key});

  @override
  State<BidozenalPage> createState() => _BidozenalPageState();
}

class _BidozenalPageState extends State<BidozenalPage> {
  static const String _theoryAsset = 'assets/theory/bidozenal.md';

  List<Tok> _input = const [];
  int _cursor = 0;

  /// Exact value of the last `=` (null when the last result was an f64
  /// fallback — then [_lastFormatted] carries the rounded digits for
  /// "continue from result").
  Rational? _lastAns;
  BidozResult _lastFormatted = const BidozResult();

  Rational? _memory;

  /// True right after `=`: the next value key starts a fresh expression, an
  /// operator continues from the result.
  bool _resultActive = false;

  /// Committed error (only `=` sets it; editing clears it). Drives the
  /// three-part error guard.
  String? _errorMsg;

  /// Active number base: 10 (Dezimal), 12 (Dozenal) or 24 (Bidozenal). One
  /// calculator outwardly; behind it three bases. Changing it clears the
  /// expression (digit sequences are base-dependent).
  int _base = 24;

  /// Conventional digits in decimal, custom glyphs in dozenal/bidozenal —
  /// driven by the base (no manual toggle).
  bool get _glyphMode => _base != 10;

  AngleMode _angleMode = AngleMode.deg;

  /// Physical-keyboard focus for this tool (autofocus while it is the active
  /// tool). Numbers + arithmetic route through the same [_onKey] path as taps.
  final FocusNode _kbFocus = FocusNode(debugLabel: 'bidozenal-keyboard');

  @override
  void dispose() {
    _kbFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final e = eventForKey(event, base: _base);
    if (e == null) return KeyEventResult.ignored;
    _onKey(e);
    return KeyEventResult.handled;
  }

  // --------------------------------------------------------------------
  // Key dispatch — port of the dozenal handleClick error-guard.
  // --------------------------------------------------------------------

  void _onKey(KeypadEvent e) {
    setState(() {
      if (_errorMsg != null) {
        if (e is ClearKey) {
          _clearAll();
          return;
        }
        if (_blockedDuringError(e)) return; // user must AC first
        if (e is MoveLeft || e is MoveRight) {
          _moveCursor(e is MoveLeft ? -1 : 1); // navigate the failing input
          return;
        }
        _errorMsg = null; // clear error, keep input + cursor, fall through
      }
      _dispatch(e);
    });
  }

  bool _blockedDuringError(KeypadEvent e) =>
      e is AnsKey || e is StoKey || e is RclKey || e is McKey || e is AngleKey;

  void _dispatch(KeypadEvent e) {
    switch (e) {
      case InsertTok(:final tok):
        _handleInsert(tok);
      case EqualsKey():
        _equals();
      case ClearKey():
        _clearAll();
      case DeleteKey():
        _delete();
      case MoveLeft():
        _resultActive = false;
        _moveCursor(-1);
      case MoveRight():
        _resultActive = false;
        _moveCursor(1);
      case AnsKey():
        _startFreshIfNeeded();
        for (final t in _continuationSeed()) {
          _insertAt(t);
        }
      case StoKey():
        _memory = _lastAns; // transparent — keeps _resultActive
      case McKey():
        _memory = null;
      case RclKey():
        if (_memory != null) {
          _startFreshIfNeeded();
          _insertAt(RatLitTok(_memory!, label: 'M'));
        }
      case AngleKey():
        _angleMode = _angleMode.next; // transparent
    }
  }

  void _handleInsert(Tok tok) {
    if (_resultActive) {
      _input = const [];
      _cursor = 0;
      if (tok is OpTok) {
        // Continue from the last result.
        for (final t in _continuationSeed()) {
          _insertAt(t);
        }
      }
      _resultActive = false;
    }
    if (tok is FuncTok && _tryInverseToggle(tok.id)) return;
    if (tok is DotTok && _hasDecimalInCurrentLiteral()) return;
    _insertAt(tok);
  }

  /// Tokens that re-introduce the last result so `=` then an operator (or Ans)
  /// continues from it. Exact when possible; otherwise the rounded digits.
  List<Tok> _continuationSeed() {
    if (_lastAns != null) return [RatLitTok(_lastAns!)];
    final r = _lastFormatted;
    final out = <Tok>[];
    if (r.negative) out.add(const OpTok(BinOp.sub));
    for (final d in r.intDigits) {
      out.add(DigitTok(d));
    }
    if (r.preDigits.isNotEmpty) {
      out.add(const DotTok());
      for (final d in r.preDigits) {
        out.add(DigitTok(d));
      }
    }
    return out;
  }

  void _startFreshIfNeeded() {
    if (_resultActive) {
      _input = const [];
      _cursor = 0;
      _resultActive = false;
    }
  }

  void _insertAt(Tok tok) {
    _input = [..._input.sublist(0, _cursor), tok, ..._input.sublist(_cursor)];
    _cursor++;
    _resultActive = false;
  }

  void _delete() {
    if (_resultActive) {
      _clearExpression();
      return;
    }
    if (_cursor > 0) {
      _input = [..._input]..removeAt(_cursor - 1);
      _cursor--;
    }
  }

  void _moveCursor(int delta) {
    _cursor = (_cursor + delta).clamp(0, _input.length);
  }

  void _clearExpression() {
    _input = const [];
    _cursor = 0;
    _resultActive = false;
    _errorMsg = null;
  }

  void _clearAll() {
    _clearExpression();
    _lastFormatted = const BidozResult();
  }

  /// Double-tap toggle for trig/hyperbolic functions (sin → sin⁻¹ → sin).
  /// Shares the buffer logic with the curve plotter (see lib/calc/input.dart).
  bool _tryInverseToggle(FuncId id) {
    final swapped = toggledInverse(_input, _cursor, id);
    if (swapped == null) return false;
    _input = swapped;
    return true;
  }

  bool _isArmed(FuncId id) => isInverseArmed(_input, _cursor, id);

  /// Bidirectional walk through the current number literal; true if it already
  /// holds a decimal point (prevents `1.2.3`).
  bool _hasDecimalInCurrentLiteral() {
    for (var i = _cursor - 1; i >= 0; i--) {
      final t = _input[i];
      if (t is DotTok) return true;
      if (t is! DigitTok) break;
    }
    for (var i = _cursor; i < _input.length; i++) {
      final t = _input[i];
      if (t is DotTok) return true;
      if (t is! DigitTok) break;
    }
    return false;
  }

  void _equals() {
    if (_input.isEmpty) {
      _lastAns = Rational.zero;
      _lastFormatted = const BidozResult();
      _errorMsg = null;
      _resultActive = true;
      return;
    }
    final res = evaluate(_input, _angleMode, base: _base);
    if (res.error != null) {
      _errorMsg = res.error; // keep input + cursor for in-place repair
      _lastAns = null;
      _resultActive = false;
      return;
    }
    _errorMsg = null;
    _lastAns = res.exact; // null on f64 fallback
    _lastFormatted = formatResult(res, base: _base);
    _resultActive = true;
  }

  // --------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final live = evaluate(_input, _angleMode, base: _base);
    return ToolScaffold(
      title: 'Bidozenal-Rechner',
      controls: _buildControls(live),
      canvas: _buildCanvas(live),
      reference: ToolReference(tabs: [
        const ReferenceTab(
          label: 'Theorie',
          content: TheoryView(assetPath: _theoryAsset),
        ),
        ReferenceTab(label: 'Symbole', content: const _SymbolSheet()),
      ]),
    );
  }

  /// What the result line shows: a committed error, the live preview, or blank
  /// when the expression is incomplete.
  BidozResult? _displayResult(EvalResult live) {
    if (_errorMsg != null) return BidozResult(error: _errorMsg);
    if (_input.isEmpty) return const BidozResult(); // 0
    if (live.error == null && (live.exact != null || live.approx != null)) {
      return formatResult(live, base: _base);
    }
    return null; // incomplete → blank
  }

  Widget _buildCanvas(EvalResult live) {
    // Focus + autofocus so the laptop keyboard drives the calculator; the
    // Listener re-grabs focus if a tap moved it elsewhere (e.g. the controls).
    return Focus(
      focusNode: _kbFocus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Listener(
        onPointerDown: (_) {
          if (!_kbFocus.hasFocus) _kbFocus.requestFocus();
        },
        child: _buildCalculator(live),
      ),
    );
  }

  Widget _buildCalculator(EvalResult live) {
    return LayoutBuilder(
      builder: (context, c) {
        final glyphW = (c.maxHeight * 3 / 8).clamp(120.0, c.maxWidth * 0.5);
        final displayH = (c.maxHeight * 0.30).clamp(88.0, 240.0);
        return Row(
          children: [
            SizedBox(
              width: glyphW,
              child: BidozenalGlyphPad(
                onKey: _onKey,
                base: _base,
                glyphMode: _glyphMode,
              ),
            ),
            const VerticalDivider(width: 1, color: Color(0xFF333333)),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: displayH,
                    child: BidozenalDisplay(
                      input: _input,
                      cursorPos: _cursor,
                      result: _displayResult(live),
                      glyphMode: _glyphMode,
                      memoryActive: _memory != null,
                      angleModeLabel: _angleMode.label,
                    ),
                  ),
                  Expanded(
                    child: BidozenalFunctionPad(
                      onKey: _onKey,
                      isArmed: _isArmed,
                      angleLabel: _angleMode.label,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(EvalResult live) {
    final theme = Theme.of(context);
    final exact = _input.isEmpty ? Rational.zero : live.exact;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('Zahlensystem', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 10, label: Text('Dez 10')),
              ButtonSegment(value: 12, label: Text('Doz 12')),
              ButtonSegment(value: 24, label: Text('Bidoz 24')),
            ],
            selected: {_base},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _base = s.first;
              _clearAll(); // digit sequences are base-dependent → start fresh
            }),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Text('Wert', style: theme.textTheme.labelMedium),
          const SizedBox(height: 12),
          if (exact != null) ...[
            _buildFormula(exact),
            const SizedBox(height: 16),
            _conversion('Bidozenal (24)', renderInBase(exact, 24), theme),
            _conversion('Dozenal (12)', renderInBase(exact, 12), theme),
            _conversion('Dezimal (10)', renderInBase(exact, 10), theme),
            if (!exact.isInteger)
              _conversion('Bruch', '${exact.num} / ${exact.den}', theme),
          ] else if (live.approx != null) ...[
            Math.tex(
              r'\approx ' '${_fmtDouble(live.approx!)}',
              textStyle: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Transzendentes Ergebnis — f64-Näherung (Schiene B).',
              style: theme.textTheme.bodySmall,
            ),
          ] else
            Text('Ausdruck unvollständig …', style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          Text(_baseNote(), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _conversion(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormula(Rational v) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        _valueTex(v),
        textStyle: const TextStyle(fontSize: 22),
        onErrorFallback: (err) => Text(
          v.toString(),
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  String _valueTex(Rational v) {
    final approx = _fmtDouble(v.toDouble());
    if (v.isInteger) return v.num.toString();
    final n = v.num.abs().toString();
    final d = v.den.toString();
    final frac = (n.length + d.length) <= 16
        ? '${v.isNegative ? '-' : ''}\\frac{$n}{$d}'
        : null;
    return frac == null ? r'\approx ' '$approx' : '$frac \\approx $approx';
  }

  String _fmtDouble(double d) {
    if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
    var s = d.toStringAsPrecision(8);
    if (s.contains('.') && !s.contains('e')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Base-specific footnote under the value panel.
  String _baseNote() {
    switch (_base) {
      case 10:
        return 'Dezimal (Basis 10). Aktiv sind nur die Ziffern 0–9; die '
            'übrigen Glyphen sind ausgegraut. Trig/Log/√ rechnen f64 (≈).';
      case 12:
        return 'Dozenal (Basis 12 = 2²·3). Aktiv sind 0–B; jeder Bruch mit '
            'Nenner aus 2en und 3en terminiert. Trig/Log/√ rechnen f64 (≈).';
      default:
        return 'Bidozenal (Basis 24 = 2³·3 = 4!). Alle 24 Ziffern aktiv; '
            'Periode (überstrichen) nur bei einer 5 im Nenner. Trig/Log/√ '
            'rechnen f64 (≈).';
    }
  }
}

/// Reference chart of all 24 glyphs, coloured by the +12 family (mirrors
/// store/glyph_preview.png): bridges (0,12) violet, new closed-triangle
/// strokes amber, +12 composites green, the base set white.
class _SymbolSheet extends StatelessWidget {
  const _SymbolSheet();

  static const _strokeNew = {13, 16, 19, 22};
  static const _bridge = {0, 12};

  Color _colorFor(int v, ColorScheme scheme) {
    if (_bridge.contains(v)) return const Color(0xFFB388FF); // violet
    if (v <= 11) return scheme.onSurface;
    if (_strokeNew.contains(v)) return const Color(0xFFE0A23A); // amber
    return const Color(0xFF55D17A); // green composites
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Die 24 Ziffern',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Untere Hälfte 0-B vertraut aus Dozenal; obere Hälfte C-N = '
          'dieselbe Form +12 (Strich → geschlossenes Dreieck, Halbkreis-'
          'Zeichen → Mittelkreis). 0 und C sind reine Kreis-Brücken.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var v = 0; v < kBase; v++)
              _SymbolCell(value: v, color: _colorFor(v, scheme)),
          ],
        ),
      ],
    );
  }
}

class _SymbolCell extends StatelessWidget {
  const _SymbolCell({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            child: BidozenalGlyph(value: value, size: 48, color: color),
          ),
          Text(
            '${bidozenalChar(value)}  =  $value',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
