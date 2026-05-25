import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../scaffold/tool_scaffold.dart';
import 'wachstum/painter.dart';
import 'wachstum/tile.dart';

/// Wachstum: aus einzelnen Rechen-Schritten baut sich eine Funktion auf.
///
/// y₀ ist der Startwert. Jede Kachel wendet einen der vier Grundrechenarten
/// auf den laufenden y-Wert an. Auf der Zeitachse rückt der Marker pro
/// Kachel um eine Einheit nach rechts; in y bewegt er sich per
/// `easeInOutCubic` (horizontal → vertikal → horizontal) — die geforderte
/// Schwung-Bewegung. Bei Hz > 0 läuft die Sequenz automatisch in der
/// angegebenen Frequenz; bei Hz = 0 schiebt der Play-Knopf jeweils eine
/// Kachel weiter (feste Schritt-Dauer 800 ms).
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

  double _y0 = 0;
  List<WachstumTile> _tiles = const [
    WachstumTile(op: WachstumOp.plus, value: 1),
    WachstumTile(op: WachstumOp.plus, value: 3),
    WachstumTile(op: WachstumOp.plus, value: 5),
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
  // Animation: einzige Wahrheitsquelle ist `_currentT`. Bewegt sich linear
  // in Echtzeit auf `_targetT` zu. Die smoothstep-Easung in y macht der
  // Painter selbst — wenn wir hier nochmal easen würden, wäre der Schwung
  // doppelt geknickt.
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
      if (_currentT >= _targetT) {
        _mode = _PlayMode.idle;
      }
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
    final target =
        math.min(_currentT.floor() + 1.0, _tiles.length.toDouble());
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
  // Kachel-Bearbeitung
  // ---------------------------------------------------------------------
  Future<void> _editY0() async {
    final result = await _showValueSheet(
      title: 'Startwert y₀',
      initialValue: _y0,
    );
    if (result != null) {
      setState(() => _y0 = result);
    }
  }

  Future<void> _editTile(int index) async {
    final tile = _tiles[index];
    final result = await _showTileSheet(
      title: 'Kachel ${index + 1}',
      initialOp: tile.op,
      initialValue: tile.value,
      canDelete: true,
    );
    if (result == null) return;
    setState(() {
      if (result.delete) {
        _tiles = List.of(_tiles)..removeAt(index);
        _currentT = math.min(_currentT, _tiles.length.toDouble());
        _targetT = math.min(_targetT, _tiles.length.toDouble());
      } else {
        _tiles = List.of(_tiles)
          ..[index] = WachstumTile(op: result.op, value: result.value);
      }
    });
  }

  void _addTile() {
    setState(() {
      _tiles = List.of(_tiles)
        ..add(const WachstumTile(op: WachstumOp.plus, value: 1));
    });
  }

  Future<_TileEditResult?> _showTileSheet({
    required String title,
    required WachstumOp initialOp,
    required double initialValue,
    required bool canDelete,
  }) {
    return showModalBottomSheet<_TileEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TileEditSheet(
        title: title,
        initialOp: initialOp,
        initialValue: initialValue,
        canDelete: canDelete,
      ),
    );
  }

  Future<double?> _showValueSheet({
    required String title,
    required double initialValue,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ValueEditSheet(
        title: title,
        initialValue: initialValue,
      ),
    );
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
      narrowControlsHeight: 320,
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final ys = checkpointValues(_y0, _tiles);
      final scale = WachstumScale.forValues(ys);
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

    widgets.add(positioned(-1, _Y0TileWidget(value: _y0, onTap: _editY0)));
    for (var i = 0; i < _tiles.length; i++) {
      final isActive = i == passedIndex - 1 ||
          (i == passedIndex && _currentT > passedIndex);
      widgets.add(positioned(
        i.toDouble(),
        _OpTileWidget(
          tile: _tiles[i],
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
    final currentValue = _currentValue(ys);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('Aktueller Wert', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            _fmtValue(currentValue),
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
            'Beim Hz=1 spielt eine Kachel pro Sekunde. Hz=0 schaltet auf '
            'Handbetrieb: Play schiebt dann jeweils eine Kachel weiter. '
            'Tippe auf eine Kachel, um Operator und Zahl zu ändern.',
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
    final playLabel = _hz > 0
        ? (running ? 'Pause' : 'Spielen')
        : 'Schritt';
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
  // Hilfsfunktionen für Formel und Wertanzeige
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

  String _formulaTex(List<double> ys) {
    if (_tiles.isEmpty) return 'y_0 = ${_texNumber(_y0)}';
    final buf = StringBuffer(_texNumber(ys[0]));
    for (var i = 0; i < _tiles.length; i++) {
      buf
        ..write(r' \xrightarrow{')
        ..write(_tiles[i].op.tex)
        ..write(' ')
        ..write(_texNumber(_tiles[i].value))
        ..write('} ')
        ..write(_texNumber(ys[i + 1]));
    }
    return buf.toString();
  }

  String _texNumber(double v) {
    if (!v.isFinite) return v.isNaN ? r'\mathrm{NaN}' : (v < 0 ? r'-\infty' : r'\infty');
    if (v == v.roundToDouble() && v.abs() < 1e9) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  String _fmtValue(double v) {
    if (!v.isFinite) return v.isNaN ? 'NaN' : (v < 0 ? '−∞' : '∞');
    if (v == v.roundToDouble() && v.abs() < 1e9) {
      return v.toStringAsFixed(0).replaceAll('-', '−');
    }
    return v.toStringAsFixed(2).replaceAll('-', '−');
  }
}

enum _PlayMode { idle, hzAuto, manualStep }

// =====================================================================
// Kachel-Widgets
// =====================================================================

class _Y0TileWidget extends StatelessWidget {
  const _Y0TileWidget({required this.value, required this.onTap});
  final double value;
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
          Text(
            _formatNumber(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
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
    required this.active,
    required this.onTap,
  });
  final WachstumTile tile;
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
          Text(
            _formatNumber(tile.value),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: active ? scheme.onPrimaryContainer : scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
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

String _formatNumber(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e6) {
    return v.toStringAsFixed(0).replaceAll('-', '−');
  }
  return v.toStringAsFixed(2).replaceAll('-', '−');
}

// =====================================================================
// Bottom-Sheets zum Bearbeiten
// =====================================================================

class _TileEditResult {
  _TileEditResult({required this.op, required this.value, this.delete = false});
  final WachstumOp op;
  final double value;
  final bool delete;
}

class _TileEditSheet extends StatefulWidget {
  const _TileEditSheet({
    required this.title,
    required this.initialOp,
    required this.initialValue,
    required this.canDelete,
  });
  final String title;
  final WachstumOp initialOp;
  final double initialValue;
  final bool canDelete;

  @override
  State<_TileEditSheet> createState() => _TileEditSheetState();
}

class _TileEditSheetState extends State<_TileEditSheet> {
  late WachstumOp _op;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _op = widget.initialOp;
    _controller = TextEditingController(text: _formatNumber(widget.initialValue));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final raw = _controller.text.replaceAll(',', '.').replaceAll('−', '-').trim();
    final value = double.tryParse(raw);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte eine Zahl eingeben.')),
      );
      return;
    }
    if (_op == WachstumOp.dividedBy && value == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teilen durch 0 ist nicht erlaubt.')),
      );
      return;
    }
    Navigator.of(context).pop(_TileEditResult(op: _op, value: value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          SegmentedButton<WachstumOp>(
            segments: const [
              ButtonSegment(value: WachstumOp.plus, label: Text('+')),
              ButtonSegment(value: WachstumOp.minus, label: Text('−')),
              ButtonSegment(value: WachstumOp.times, label: Text('×')),
              ButtonSegment(value: WachstumOp.dividedBy, label: Text('÷')),
            ],
            selected: {_op},
            onSelectionChanged: (s) => setState(() => _op = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-−0-9.,]')),
            ],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Zahl',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.canDelete)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    _TileEditResult(op: _op, value: 0, delete: true),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Entfernen'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _confirm,
                child: const Text('Fertig'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueEditSheet extends StatefulWidget {
  const _ValueEditSheet({required this.title, required this.initialValue});
  final String title;
  final double initialValue;

  @override
  State<_ValueEditSheet> createState() => _ValueEditSheetState();
}

class _ValueEditSheetState extends State<_ValueEditSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatNumber(widget.initialValue));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final raw = _controller.text.replaceAll(',', '.').replaceAll('−', '-').trim();
    final value = double.tryParse(raw);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte eine Zahl eingeben.')),
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-−0-9.,]')),
            ],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Wert',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _confirm, child: const Text('Fertig')),
            ],
          ),
        ],
      ),
    );
  }
}
