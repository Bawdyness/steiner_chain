import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../scaffold/tool_scaffold.dart';
import 'package:geometrie_spielzeug/calc/digits.dart';
import 'package:geometrie_spielzeug/calc/evaluator.dart';
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
  // Kachel-Bearbeitung (Mini-Rechner statt TextField)
  // ---------------------------------------------------------------------
  Future<void> _editY0() async {
    final result = await showModalBottomSheet<_CalcEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CalcEditSheet(
        title: 'Startwert y₀',
        base: _base,
        initialValue: _y0,
      ),
    );
    if (result != null) setState(() => _y0 = result.value);
  }

  Future<void> _editTile(int index) async {
    final tile = _tiles[index];
    final result = await showModalBottomSheet<_CalcEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CalcEditSheet(
        title: 'Kachel ${index + 1}',
        base: _base,
        showOp: true,
        initialOp: tile.op,
        initialValue: tile.value,
        canDelete: true,
      ),
    );
    if (result == null) return;
    setState(() {
      if (result.delete) {
        _tiles = List.of(_tiles)..removeAt(index);
        _currentT = math.min(_currentT, _tiles.length.toDouble());
        _targetT = math.min(_targetT, _tiles.length.toDouble());
      } else {
        _tiles = List.of(_tiles)
          ..[index] = WachstumTile(op: result.op!, value: result.value);
      }
    });
  }

  void _addTile() {
    setState(() {
      _tiles = List.of(_tiles)
        ..add(WachstumTile(op: BinOp.add, value: Rational.one));
    });
  }

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
        -1, _Y0TileWidget(value: _y0, base: _base, onTap: _editY0)));
    for (var i = 0; i < _tiles.length; i++) {
      final isActive = i == passedIndex - 1 ||
          (i == passedIndex && _currentT > passedIndex);
      widgets.add(positioned(
        i.toDouble(),
        _OpTileWidget(
          tile: _tiles[i],
          base: _base,
          active: isActive,
          onTap: () => _editTile(i),
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
    final ys = checkpointValues(_y0, _tiles);
    final ysD = ys.map((r) => r.toDouble()).toList();
    final currentValue = _currentValue(ysD);

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
            onSelectionChanged: (s) => setState(() => _base = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          Text('Aktueller Wert', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            _fmtDoubleBase(currentValue, _base),
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.primary,
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
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildTempoControls(theme),
          const SizedBox(height: 24),
          Text(
            'Tippe auf eine Kachel, um Operator und Zahl im gewählten '
            'Zahlensystem (über das Rechner-Keypad) zu setzen — exakt gerechnet. '
            'Bei Hz=1 spielt eine Kachel pro Sekunde; Hz=0 schaltet auf '
            'Handbetrieb (Play schiebt eine Kachel weiter).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
  const _Y0TileWidget({required this.value, required this.base, required this.onTap});
  final Rational value;
  final int base;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _TileBox(
      onTap: onTap,
      borderColor: scheme.outlineVariant,
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
    required this.onTap,
  });
  final WachstumTile tile;
  final int base;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _TileBox(
      onTap: onTap,
      borderColor: active ? scheme.primary : scheme.outlineVariant,
      borderWidth: active ? 1.6 : 1.0,
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
// Mini-Rechner zum Bearbeiten (basis-bewusst, exakt → Rational)
// =====================================================================

class _CalcEditResult {
  _CalcEditResult({this.op, required this.value, this.delete = false});
  final BinOp? op;
  final Rational value;
  final bool delete;
}

class _CalcEditSheet extends StatefulWidget {
  const _CalcEditSheet({
    required this.title,
    required this.base,
    required this.initialValue,
    this.showOp = false,
    this.initialOp = BinOp.add,
    this.canDelete = false,
  });
  final String title;
  final int base;
  final Rational initialValue;
  final bool showOp;
  final BinOp initialOp;
  final bool canDelete;

  @override
  State<_CalcEditSheet> createState() => _CalcEditSheetState();
}

class _CalcEditSheetState extends State<_CalcEditSheet> {
  late BinOp _op;
  late bool _neg;
  late List<Tok> _digits; // DigitTok / DotTok only

  @override
  void initState() {
    super.initState();
    _op = widget.initialOp;
    _neg = widget.initialValue.isNegative && !widget.initialValue.isZero;
    _digits = _digitsFromRational(widget.initialValue, widget.base);
  }

  static List<Tok> _digitsFromRational(Rational v, int base) {
    final e = v.expand(base: base);
    if (e.period.isNotEmpty) return []; // non-terminating → start fresh
    final out = <Tok>[for (final d in e.intDigits) DigitTok(d)];
    if (e.preDigits.isNotEmpty) {
      out.add(const DotTok());
      out.addAll([for (final d in e.preDigits) DigitTok(d)]);
    }
    return out;
  }

  Rational? get _value {
    final toks = <Tok>[if (_neg) const OpTok(BinOp.sub), ..._digits];
    return evaluate(toks, AngleMode.rad, base: widget.base).exact;
  }

  bool get _hasDot => _digits.any((t) => t is DotTok);

  String get _preview {
    final v = _value;
    if (_digits.isEmpty) return '—';
    return v == null ? '—' : renderInBase(v, widget.base);
  }

  bool get _valid {
    final v = _value;
    if (v == null) return false;
    if (widget.showOp && _op == BinOp.div && v.isZero) return false;
    return true;
  }

  void _insertDigit(int d) => setState(() => _digits = [..._digits, DigitTok(d)]);
  void _insertDot() {
    if (_hasDot) return;
    setState(() => _digits = [..._digits, const DotTok()]);
  }

  void _backspace() => setState(() {
        if (_digits.isNotEmpty) _digits = _digits.sublist(0, _digits.length - 1);
      });
  void _clear() => setState(() {
        _digits = [];
        _neg = false;
      });

  void _confirm() {
    final v = _value;
    if (v == null) {
      _snack('Bitte eine Zahl eingeben.');
      return;
    }
    if (widget.showOp && _op == BinOp.div && v.isZero) {
      _snack('Teilen durch 0 ist nicht erlaubt.');
      return;
    }
    Navigator.of(context).pop(_CalcEditResult(op: _op, value: v));
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final digitCount = widget.base;
    final rows = <List<int>>[];
    for (var i = 0; i < digitCount; i += 6) {
      rows.add([for (var d = i; d < math.min(i + 6, digitCount); d++) d]);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (widget.showOp) ...[
            SegmentedButton<BinOp>(
              segments: const [
                ButtonSegment(value: BinOp.add, label: Text('+')),
                ButtonSegment(value: BinOp.sub, label: Text('−')),
                ButtonSegment(value: BinOp.mul, label: Text('×')),
                ButtonSegment(value: BinOp.div, label: Text('÷')),
              ],
              selected: {_op},
              onSelectionChanged: (s) => setState(() => _op = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF101010),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Text(
              '${_neg && _digits.isEmpty ? '−' : ''}$_preview',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 26,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            _KeyRow(children: [
              for (final d in row)
                _CalcKey(label: bidozenalChar(d), onTap: () => _insertDigit(d)),
            ]),
          _KeyRow(children: [
            _CalcKey(label: '.', onTap: _insertDot),
            _CalcKey(label: '±', onTap: () => setState(() => _neg = !_neg)),
            _CalcKey(label: '⌫', onTap: _backspace),
            _CalcKey(label: 'AC', onTap: _clear, color: scheme.error),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.canDelete)
                TextButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pop(_CalcEditResult(op: _op, value: Rational.zero, delete: true)),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Entfernen'),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _valid ? _confirm : null,
                child: const Text('Fertig'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: Row(children: [for (final c in children) Expanded(child: c)]),
      );
}

class _CalcKey extends StatelessWidget {
  const _CalcKey({required this.label, required this.onTap, this.color});
  final String label;
  final VoidCallback onTap;
  final Color? color;

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
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color ?? scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
