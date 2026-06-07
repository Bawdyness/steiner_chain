import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../scaffold/tool_scaffold.dart';
import 'package:geometrie_spielzeug/calc/digits.dart';
import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/keypad.dart';
import 'package:geometrie_spielzeug/calc/rational.dart';
import 'wachstum/painter.dart';
import 'wachstum/tile.dart';

/// Wachstum: aus einzelnen Rechen-Schritten baut sich eine Funktion auf.
///
/// Teilt sich den Rechner-Kern (`lib/calc/`): Operatoren sind `BinOp`, die
/// Kachelwerte exakte `Rational`s, und Eingabe/Anzeige laufen über ein
/// basis-wählbares (10/12/24) Keypad bzw. `renderInBase`. y₀ ist der Startwert;
/// jede Kachel wendet einen der vier Grundrechenarten auf den laufenden y-Wert
/// an. Marker-Bewegung + Hz-Tempo wie gehabt.
class WachstumPage extends StatefulWidget {
  const WachstumPage({super.key});

  @override
  State<WachstumPage> createState() => _WachstumPageState();
}

class _WachstumPageState extends State<WachstumPage>
    with SingleTickerProviderStateMixin {
  static const double _maxHz = 20.0;
  static const double _manualStepDuration = 0.8; // Sekunden pro Segment
  static const double _bottomInset = 96.0;
  static const double _tileBarHeight = 72.0;
  static const double _tileWidth = 78.0;

  int _base = 10; // Anzeige/Eingabe: 10 dezimal · 12 dozenal · 24 bidozenal

  Rational _y0 = Rational.zero;
  List<WachstumTile> _tiles = [
    WachstumTile(op: BinOp.add, value: Rational.fromInt(1)),
    WachstumTile(op: BinOp.add, value: Rational.fromInt(3)),
    WachstumTile(op: BinOp.add, value: Rational.fromInt(5)),
  ];

  // Permanent left-column calculator: which target the keypad edits
  // (-1 = y₀, else tile index) + the cursor-based exact expression buffer.
  int _editIndex = -1;
  List<Tok> _input = const [];
  int _cursor = 0;

  double _currentT = 0;
  double _targetT = 0;
  _PlayMode _mode = _PlayMode.idle;
  double _hz = 1.0;
  late final TextEditingController _hzController;
  late final Ticker _ticker;
  Duration? _lastTickAt;

  @override
  void initState() {
    super.initState();
    _hzController = TextEditingController(text: '1');
    _ticker = createTicker(_onTick)..start();
    _loadBuffer(); // start by editing y₀
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hzController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Animation
  // ---------------------------------------------------------------------
  void _onTick(Duration elapsed) {
    final last = _lastTickAt;
    _lastTickAt = elapsed;
    if (_mode == _PlayMode.idle || last == null) return;
    if (_currentT >= _targetT) {
      setState(() => _mode = _PlayMode.idle);
      return;
    }
    final dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) return;
    final rate = _mode == _PlayMode.hzAuto ? _hz : 1.0 / _manualStepDuration;
    setState(() {
      _currentT = math.min(_currentT + rate * dt, _targetT);
      if (_currentT >= _targetT) _mode = _PlayMode.idle;
    });
  }

  void _onPlayPressed() {
    if (_tiles.isEmpty) return;
    if (_hz > 0) {
      if (_mode == _PlayMode.hzAuto) {
        _stopPlayback();
      } else {
        _startHzAuto();
      }
    } else {
      if (_mode == _PlayMode.idle) _startManualStep();
    }
  }

  void _startHzAuto() {
    setState(() {
      if (_currentT >= _tiles.length) _currentT = 0;
      _mode = _PlayMode.hzAuto;
      _targetT = _tiles.length.toDouble();
    });
    _lastTickAt = null;
  }

  void _startManualStep() {
    if (_currentT >= _tiles.length) return;
    final target = math.min(_currentT.floor() + 1.0, _tiles.length.toDouble());
    setState(() {
      _mode = _PlayMode.manualStep;
      _targetT = target;
    });
    _lastTickAt = null;
  }

  void _stopPlayback() {
    setState(() {
      _mode = _PlayMode.idle;
      _targetT = _currentT;
    });
  }

  void _reset() {
    setState(() {
      _mode = _PlayMode.idle;
      _currentT = 0;
      _targetT = 0;
    });
  }

  void _setHzFromText(String s) {
    final cleaned = s.replaceAll(',', '.').trim();
    final value = double.tryParse(cleaned);
    final clamped = (value ?? 0).clamp(0, _maxHz).toDouble();
    setState(() {
      _hz = clamped;
      if (clamped == 0 && _mode == _PlayMode.hzAuto) {
        _mode = _PlayMode.idle;
        _targetT = _currentT;
      }
    });
  }

  void _setHzFromPreset(double hz) {
    _hzController.text = hz == hz.roundToDouble() ? '${hz.toInt()}' : '$hz';
    _setHzFromText(_hzController.text);
  }

  // ---------------------------------------------------------------------
  // Permanenter Mini-Rechner (linke Spalte) — bearbeitet das gewählte Ziel
  // (y₀ oder eine Kachel) live. Nur exakt-erhaltende Tasten ⇒ Wert bleibt
  // ein exakter Rational; Trig/Log/√/Konstanten gibt es hier bewusst nicht.
  // ---------------------------------------------------------------------

  /// Selects the keypad's edit target (-1 = y₀, else tile index) and loads its
  /// value into the buffer.
  void _select(int index) => setState(() {
        _editIndex = index;
        _loadBuffer();
      });

  void _loadBuffer() {
    final value = _editIndex < 0 ? _y0 : _tiles[_editIndex].value;
    _input = _tokensFromRational(value, _base);
    _cursor = _input.length;
  }

  /// Exact value of the current expression, or null (incomplete / not exact).
  Rational? get _editValue => evaluate(_input, AngleMode.rad, base: _base).exact;

  /// Writes the current exact value to the selected target. Incomplete or
  /// non-exact input leaves the target at its last value.
  void _applyToTarget() {
    final v = _editValue;
    if (v == null) return;
    if (_editIndex < 0) {
      _y0 = v;
    } else if (_editIndex < _tiles.length) {
      final tile = _tiles[_editIndex];
      if (tile.op == BinOp.div && v.isZero) return; // a ÷0 tile is forbidden
      _tiles = List.of(_tiles)..[_editIndex] = tile.copyWith(value: v);
    }
  }

  void _setOp(BinOp op) {
    if (_editIndex < 0) return;
    setState(() {
      final tile = _tiles[_editIndex];
      if (op == BinOp.div && tile.value.isZero) return; // can't ÷0
      _tiles = List.of(_tiles)..[_editIndex] = tile.copyWith(op: op);
    });
  }

  void _addTile() => setState(() {
        _tiles = List.of(_tiles)
          ..add(WachstumTile(op: BinOp.add, value: Rational.one));
        _editIndex = _tiles.length - 1;
        _loadBuffer();
      });

  void _deleteTile() {
    if (_editIndex < 0) return;
    setState(() {
      _tiles = List.of(_tiles)..removeAt(_editIndex);
      _currentT = math.min(_currentT, _tiles.length.toDouble());
      _targetT = math.min(_targetT, _tiles.length.toDouble());
      if (_editIndex >= _tiles.length) {
        _editIndex = _tiles.isEmpty ? -1 : _tiles.length - 1;
      }
      _loadBuffer();
    });
  }

  // ---- buffer editing (cursor-based, like Kurve; writes through live) ----
  void _insert(Tok t) {
    if (t is DotTok && _hasDotInCurrentLiteral()) return;
    setState(() {
      _input = [..._input.sublist(0, _cursor), t, ..._input.sublist(_cursor)];
      _cursor++;
      _applyToTarget();
    });
  }

  void _delete() => setState(() {
        if (_cursor > 0) {
          _input = [..._input]..removeAt(_cursor - 1);
          _cursor--;
          _applyToTarget();
        }
      });

  void _clearInput() => setState(() {
        _input = const [];
        _cursor = 0;
      });

  void _move(int delta) =>
      setState(() => _cursor = (_cursor + delta).clamp(0, _input.length));

  /// Bidirectional walk through the number literal at the cursor — true if it
  /// already holds a decimal point (blocks `1.2.3`).
  bool _hasDotInCurrentLiteral() {
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

  static List<Tok> _tokensFromRational(Rational v, int base) {
    final e = v.expand(base: base);
    final neg = v.isNegative && !v.isZero;
    if (e.period.isNotEmpty) return neg ? [const OpTok(BinOp.sub)] : const [];
    return [
      if (neg) const OpTok(BinOp.sub),
      for (final d in e.intDigits) DigitTok(d),
      if (e.preDigits.isNotEmpty) const DotTok(),
      for (final d in e.preDigits) DigitTok(d),
    ];
  }

  String _inputString() {
    final sb = StringBuffer();
    for (var i = 0; i <= _input.length; i++) {
      if (i == _cursor) sb.write('▏');
      if (i < _input.length) sb.write(_tokLabel(_input[i]));
    }
    return sb.toString();
  }

  String _tokLabel(Tok t) => switch (t) {
        DigitTok d => bidozenalChar(d.value),
        DotTok() => '.',
        OpTok o => ' ${o.op.symbol} ',
        LParenTok() => '(',
        RParenTok() => ')',
        FuncTok f => f.id == FuncId.fact
            ? '!'
            : (f.id.isPrefix ? '${f.id.label} ' : f.id.label),
        VarTok() => 'x',
        ConstTok c => c.id.label,
        RatLitTok r => r.label,
      };

  // ---- key builders (shared CalcKey chrome; digits via GlyphDigitPad) ----
  Widget _key(String label, VoidCallback onTap, ColorScheme scheme,
          {Color? color}) =>
      CalcKey(
        onTap: onTap,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: color ?? scheme.onSurfaceVariant,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  Widget _opKey(BinOp o, ColorScheme scheme) =>
      _key(o.symbol, () => _insert(OpTok(o)), scheme, color: scheme.primary);

  Widget _funcKey(FuncId id, String label, ColorScheme scheme) =>
      _key(label, () => _insert(FuncTok(id)), scheme);

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Wachstum',
      controls: _buildControls(),
      canvas: _buildCanvas(),
      narrowControlsHeight: 340,
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final ysD = checkpointValues(_y0, _tiles).map((r) => r.toDouble()).toList();
      final scale = WachstumScale.forValues(ysD);
      final tMin = -1.0;
      final tMax = math.max(_tiles.length + 1.0, 5.0);
      final layout = WachstumLayout.compute(
        size: size,
        scale: scale,
        tMin: tMin,
        tMax: tMax,
        bottomInset: _bottomInset,
      );
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: WachstumPainter(
                y0: _y0,
                tiles: _tiles,
                currentT: _currentT,
                layout: layout,
                base: _base,
                colorScheme: Theme.of(context).colorScheme,
                textStyle: Theme.of(context).textTheme.bodyMedium ??
                    const TextStyle(),
              ),
            ),
          ),
          ..._buildTileWidgets(layout),
        ],
      );
    });
  }

  List<Widget> _buildTileWidgets(WachstumLayout layout) {
    final widgets = <Widget>[];
    final top = layout.canvasSize.height - _bottomInset + 8;
    final passedIndex = _currentT.floor().clamp(0, _tiles.length);

    Widget positioned(double slotIndex, Widget child) {
      final centerX = layout.tToX(slotIndex + 0.5);
      final width = math.min(_tileWidth, layout.pxPerT - 6);
      return Positioned(
        left: centerX - width / 2,
        top: top,
        width: width,
        height: _tileBarHeight,
        child: child,
      );
    }

    widgets.add(positioned(
      -1,
      _Y0TileWidget(
        value: _y0,
        base: _base,
        selected: _editIndex == -1,
        onTap: () => _select(-1),
      ),
    ));
    for (var i = 0; i < _tiles.length; i++) {
      final isActive = i == passedIndex - 1 ||
          (i == passedIndex && _currentT > passedIndex);
      widgets.add(positioned(
        i.toDouble(),
        _OpTileWidget(
          tile: _tiles[i],
          base: _base,
          active: isActive,
          selected: _editIndex == i,
          onTap: () => _select(i),
        ),
      ));
    }
    widgets.add(positioned(
      _tiles.length.toDouble(),
      _AddTileWidget(onTap: _addTile),
    ));
    return widgets;
  }

  Widget _buildControls() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ys = checkpointValues(_y0, _tiles);
    final ysD = ys.map((r) => r.toDouble()).toList();
    final currentValue = _currentValue(ysD);
    final editingTile = _editIndex >= 0;

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
            onSelectionChanged: (s) => setState(() {
              _base = s.first;
              _loadBuffer(); // re-tokenize the current target in the new base
            }),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),

          // ---- permanent editor for the selected tile / y₀ ----
          Row(
            children: [
              Text('Bearbeiten: ', style: theme.textTheme.labelMedium),
              Text(
                editingTile ? 'Kachel ${_editIndex + 1}' : 'Startwert y₀',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (editingTile)
                IconButton(
                  tooltip: 'Kachel entfernen',
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  visualDensity: VisualDensity.compact,
                  onPressed: _deleteTile,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (editingTile) ...[
            SegmentedButton<BinOp>(
              segments: const [
                ButtonSegment(value: BinOp.add, label: Text('+')),
                ButtonSegment(value: BinOp.sub, label: Text('−')),
                ButtonSegment(value: BinOp.mul, label: Text('×')),
                ButtonSegment(value: BinOp.div, label: Text('÷')),
              ],
              selected: {_tiles[_editIndex].op},
              onSelectionChanged: (s) => _setOp(s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 8),
          ],
          _editDisplay(scheme),
          const SizedBox(height: 8),
          GlyphDigitPad(
            base: _base,
            onDigit: (d) => _insert(DigitTok(d)),
            rowHeight: 48,
          ),
          _KeyRow(children: [
            _key('(', () => _insert(const LParenTok()), scheme),
            _key(')', () => _insert(const RParenTok()), scheme),
            _opKey(BinOp.pow, scheme),
            _opKey(BinOp.mod, scheme),
          ]),
          _KeyRow(children: [
            _funcKey(FuncId.fact, 'n!', scheme),
            _funcKey(FuncId.abs, '|x|', scheme),
            _funcKey(FuncId.recip, '1/x', scheme),
            _key('.', () => _insert(const DotTok()), scheme),
          ]),
          _KeyRow(children: [
            _opKey(BinOp.add, scheme),
            _opKey(BinOp.sub, scheme),
            _opKey(BinOp.mul, scheme),
            _opKey(BinOp.div, scheme),
          ]),
          _KeyRow(children: [
            _key('◀', () => _move(-1), scheme),
            _key('▶', () => _move(1), scheme),
            _key('⌫', _delete, scheme),
            _key('AC', _clearInput, scheme, color: scheme.error),
          ]),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Text('Aktueller Wert', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            _fmtDoubleBase(currentValue, _base),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          Text('Rechen-Spur', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              _formulaTex(ys),
              textStyle: const TextStyle(fontSize: 18),
              onErrorFallback: (err) => Text(
                'LaTeX-Fehler: ${err.message}',
                style: TextStyle(color: scheme.error),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          _buildTempoControls(theme),
          const SizedBox(height: 24),
          Text(
            'Tippe eine Kachel (oder y₀) an, um sie zu wählen; ihr Wert wird '
            'live über das Keypad eingegeben — exakt gerechnet. „+" fügt eine '
            'Kachel an. Bei Hz=1 spielt eine Kachel pro Sekunde; Hz=0 schaltet '
            'auf Handbetrieb (Play schiebt eine Kachel weiter).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Two-line edit display: the live expression (with cursor) over its value.
  Widget _editDisplay(ColorScheme scheme) {
    final v = _editValue;
    final valueStr =
        _input.isEmpty ? '' : (v == null ? '—' : renderInBase(v, _base));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _inputString(),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valueStr.isEmpty ? ' ' : '= $valueStr',
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTempoControls(ThemeData theme) {
    final canPlay = _tiles.isNotEmpty;
    final running = _mode == _PlayMode.hzAuto;
    final playLabel = _hz > 0 ? (running ? 'Pause' : 'Spielen') : 'Schritt';
    final playIcon = _hz > 0
        ? (running ? Icons.pause : Icons.play_arrow)
        : Icons.skip_next;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tempo (Hz)', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hzController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0 (Handbetrieb)',
                  suffixText: 'Hz',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: _setHzFromText,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: canPlay ? _onPlayPressed : null,
              icon: Icon(playIcon),
              label: Text(playLabel),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Zurück zum Anfang',
              icon: const Icon(Icons.replay),
              onPressed: _currentT > 0 ? _reset : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final preset in const [0.5, 1.0, 2.0, 5.0])
              ActionChip(
                label: Text(preset == preset.roundToDouble()
                    ? '${preset.toInt()} Hz'
                    : '$preset Hz'),
                onPressed: () => _setHzFromPreset(preset),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Formel- und Wertanzeige (basis-bewusst)
  // ---------------------------------------------------------------------
  double _currentValue(List<double> ys) {
    if (_tiles.isEmpty || _currentT <= 0) return ys[0];
    final clamped = _currentT.clamp(0.0, _tiles.length.toDouble());
    if (clamped >= _tiles.length) return ys.last;
    final i = clamped.floor();
    final local = clamped - i;
    final eased = local * local * (3 - 2 * local);
    return ys[i] + (ys[i + 1] - ys[i]) * eased;
  }

  String _formulaTex(List<Rational> ys) {
    if (_tiles.isEmpty) return 'y_0 = ${_texNum(_y0)}';
    final buf = StringBuffer(_texNum(ys[0]));
    for (var i = 0; i < _tiles.length; i++) {
      buf
        ..write(r' \xrightarrow{')
        ..write(_tiles[i].op.tex)
        ..write(' ')
        ..write(_texNum(_tiles[i].value))
        ..write('} ')
        ..write(_texNum(ys[i + 1]));
    }
    return buf.toString();
  }

  /// Number in the active base, wrapped in \text so brackets/`−`/letters from
  /// `renderInBase` (e.g. `A`, `0.[3]`) render literally in KaTeX.
  String _texNum(Rational r) => '\\text{${renderInBase(r, _base)}}';

  String _fmtDoubleBase(double v, int base) {
    if (!v.isFinite) return v.isNaN ? 'NaN' : (v < 0 ? '−∞' : '∞');
    if (base == 10) {
      if (v == v.roundToDouble() && v.abs() < 1e9) {
        return v.toStringAsFixed(0).replaceAll('-', '−');
      }
      return v.toStringAsFixed(2).replaceAll('-', '−');
    }
    final parts = doubleToBaseDigits(v.abs(), base: base, fracDigits: 2);
    final sb = StringBuffer(v < 0 ? '−' : '');
    for (final d in parts.intDigits) {
      sb.write(bidozenalChar(d));
    }
    if (parts.fracDigits.isNotEmpty) {
      sb.write('.');
      for (final d in parts.fracDigits) {
        sb.write(bidozenalChar(d));
      }
    }
    return sb.toString();
  }
}

enum _PlayMode { idle, hzAuto, manualStep }

/// Exact-value label in a base (chars), e.g. "A" / "10" / "−1.6".
String _numberInBase(Rational v, int base) => renderInBase(v, base);

// =====================================================================
// Kachel-Widgets
// =====================================================================

class _Y0TileWidget extends StatelessWidget {
  const _Y0TileWidget({
    required this.value,
    required this.base,
    required this.selected,
    required this.onTap,
  });
  final Rational value;
  final int base;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _TileBox(
      onTap: onTap,
      borderColor: selected ? scheme.tertiary : scheme.outlineVariant,
      borderWidth: selected ? 2.0 : 1.0,
      backgroundColor: scheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('y₀ =',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              )),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _numberInBase(value, base),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpTileWidget extends StatelessWidget {
  const _OpTileWidget({
    required this.tile,
    required this.base,
    required this.active,
    required this.selected,
    required this.onTap,
  });
  final WachstumTile tile;
  final int base;

  /// Playback highlight (the marker has passed this tile).
  final bool active;

  /// Edit-target highlight (the keypad is editing this tile).
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _TileBox(
      onTap: onTap,
      borderColor: selected
          ? scheme.tertiary
          : (active ? scheme.primary : scheme.outlineVariant),
      borderWidth: selected ? 2.0 : (active ? 1.6 : 1.0),
      backgroundColor: active
          ? scheme.primary.withValues(alpha: 0.16)
          : scheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tile.op.symbol,
            style: TextStyle(
              fontSize: 16,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _numberInBase(tile.value, base),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: active ? scheme.onPrimaryContainer : scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTileWidget extends StatelessWidget {
  const _AddTileWidget({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: DottedBorderBox(
          color: scheme.outline.withValues(alpha: 0.6),
          radius: 8,
          child: Center(
            child: Icon(Icons.add, size: 30, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _TileBox extends StatelessWidget {
  const _TileBox({
    required this.child,
    required this.onTap,
    required this.borderColor,
    required this.backgroundColor,
    this.borderWidth = 1.0,
  });
  final Widget child;
  final VoidCallback onTap;
  final Color borderColor;
  final Color backgroundColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Gestrichelter Rahmen (Flutter hat dafür keinen Standard-Widget).
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.radius = 8,
    this.strokeWidth = 1.2,
    this.dashLength = 4,
    this.gapLength = 3,
  });
  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gapLength: gapLength,
      ),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  _DottedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double distance = 0;
      while (distance < m.length) {
        final next = math.min(distance + dashLength, m.length);
        final extract = m.extractPath(distance, next);
        canvas.drawPath(extract, paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}

// =====================================================================
// Keypad-Zeile (geteiltes CalcKey-Chrome)
// =====================================================================

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: Row(children: [for (final c in children) Expanded(child: c)]),
      );
}

