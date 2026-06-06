// Kurve — a function plotter that grows. Enter f(x) in dozenal via the keypad;
// the curve is sampled through the shared calc f64 rail and drawn on a
// pan/zoomable plane. Unlike a static plot, the curve (and the area under it)
// *grows* left→right on a Hz-timed sweep — Wachstum's idea applied to f(x):
// steep stretches shoot up fast, flat ones crawl.
//
// Reuses lib/calc/ (evaluator, glyphs, keyboard, input); no cross-tool import.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../scaffold/tool_scaffold.dart';
import 'package:geometrie_spielzeug/calc/digits.dart';
import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/input.dart';
import 'package:geometrie_spielzeug/calc/keyboard.dart';
import 'kurve/keypad.dart';
import 'kurve/plot_painter.dart';

class KurvePage extends StatefulWidget {
  const KurvePage({super.key});

  @override
  State<KurvePage> createState() => _KurvePageState();
}

class _KurvePageState extends State<KurvePage>
    with SingleTickerProviderStateMixin {
  static const int _base = 12; // dozenal axis labels
  static const double _maxHz = 20.0;
  static const AngleMode _angleMode = AngleMode.rad; // math plotting

  // f(x) = x by default — a clean diagonal that fills the initial window.
  List<Tok> _input = const [VarTok()];
  int _cursor = 1;
  late double Function(double) _f;

  PlotView _view = PlotView.initial;

  bool _playing = false;
  double _sweepX = 0;
  double _hz = 1.0;
  late final TextEditingController _hzController;

  late final Ticker _ticker;
  Duration? _lastTick;
  double _lastScale = 1.0;

  final FocusNode _kbFocus = FocusNode(debugLabel: 'kurve-keyboard');

  @override
  void initState() {
    super.initState();
    _recompile();
    _hzController = TextEditingController(text: '1');
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hzController.dispose();
    _kbFocus.dispose();
    super.dispose();
  }

  void _recompile() => _f = compileF64(_input, _angleMode, base: _base);

  // --------------------------------------------------------------------
  // Input
  // --------------------------------------------------------------------

  void _onKey(KeypadEvent e) {
    setState(() {
      switch (e) {
        case InsertTok(:final tok):
          _input = [..._input.sublist(0, _cursor), tok, ..._input.sublist(_cursor)];
          _cursor++;
        case DeleteKey():
          if (_cursor > 0) {
            _input = [..._input]..removeAt(_cursor - 1);
            _cursor--;
          }
        case ClearKey():
          _input = const [];
          _cursor = 0;
        case MoveLeft():
          if (_cursor > 0) _cursor--;
        case MoveRight():
          if (_cursor < _input.length) _cursor++;
        default:
          return; // Equals/Ans/Sto/… aren't used by the plotter
      }
      _recompile();
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final ch = event.character;
    if (ch == 'x' || ch == 'X') {
      _onKey(const InsertTok(VarTok()));
      return KeyEventResult.handled;
    }
    final e = eventForKey(event);
    if (e is InsertTok ||
        e is DeleteKey ||
        e is ClearKey ||
        e is MoveLeft ||
        e is MoveRight) {
      _onKey(e!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // --------------------------------------------------------------------
  // Growth sweep
  // --------------------------------------------------------------------

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (!_playing || last == null) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) return;
    final rate = _hz * _view.xRange; // x-units per second (≈ one width @ 1 Hz)
    setState(() {
      _sweepX += rate * dt;
      if (_sweepX >= _view.xMax) {
        _sweepX = _view.xMax;
        _playing = false; // reached the right edge → full curve stays shown
      }
    });
  }

  void _onPlay() {
    setState(() {
      if (_playing) {
        _playing = false;
      } else {
        _sweepX = _view.xMin;
        _playing = true;
        _lastTick = null;
      }
    });
  }

  void _setHz(String s) {
    final v = double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;
    setState(() => _hz = v.clamp(0, _maxHz).toDouble());
  }

  void _resetView() => setState(() => _view = PlotView.initial);

  // --------------------------------------------------------------------
  // Gestures (pan + zoom)
  // --------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails d) => _lastScale = 1.0;

  void _onScaleUpdate(PlotGeom geom, ScaleUpdateDetails d) {
    setState(() {
      // Pan by the focal-point delta.
      var v = _view.pan(
        -d.focalPointDelta.dx * geom.xPerPx,
        d.focalPointDelta.dy * geom.yPerPx,
      );
      // Incremental zoom about the focal point.
      final factor = d.scale == 0 ? 1.0 : _lastScale / d.scale;
      _lastScale = d.scale;
      if (factor.isFinite && factor > 0 && (factor - 1).abs() > 1e-4) {
        final cx = geom.pxToX(d.localFocalPoint.dx);
        final cy = geom.pyToY(d.localFocalPoint.dy);
        v = v.zoom(factor, cx, cy);
      }
      // Clamp to sane ranges so the view can't collapse or explode.
      if (v.xRange.clamp(1e-4, 1e9) == v.xRange &&
          v.yRange.clamp(1e-4, 1e9) == v.yRange) {
        _view = v;
      }
    });
  }

  // --------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Kurve',
      narrowControlsHeight: 430,
      canvas: _buildCanvas(),
      controls: _buildControls(),
    );
  }

  Widget _buildCanvas() {
    final theme = Theme.of(context);
    return Focus(
      focusNode: _kbFocus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Listener(
        onPointerDown: (_) {
          if (!_kbFocus.hasFocus) _kbFocus.requestFocus();
        },
        child: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            final geom = PlotGeom(size, _view);
            return GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: (d) => _onScaleUpdate(geom, d),
              child: CustomPaint(
                size: size,
                painter: PlotPainter(
                  f: _f,
                  view: _view,
                  sweepX: _playing ? _sweepX : double.infinity,
                  scheme: theme.colorScheme,
                  textStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
                  base: _base,
                  hasFunction: _input.isNotEmpty,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('f(x) =', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              _inputString(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          KurveKeypad(onKey: _onKey),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _buildTempo(theme),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _resetView,
            icon: const Icon(Icons.center_focus_strong_outlined),
            label: const Text('Ansicht zurücksetzen'),
          ),
          const SizedBox(height: 16),
          Text(
            'Ziffern 0–B (dozenal) + Variable x. „Wachsen" lässt die Kurve und '
            'ihre Fläche von links nach rechts einlaufen — durch steile Stellen '
            'schnell, durch flache langsam. Ziehen verschiebt, Zwei-Finger-Geste '
            'zoomt. Winkel in Radiant.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTempo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wachstum (Hz)', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hzController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  suffixText: 'Hz',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: _setHz,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _hz > 0 ? _onPlay : null,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              label: Text(_playing ? 'Pause' : 'Wachsen'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final p in const [0.5, 1.0, 2.0, 5.0])
              ActionChip(
                label: Text(p == p.roundToDouble() ? '${p.toInt()} Hz' : '$p Hz'),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _hzController.text = p == p.roundToDouble() ? '${p.toInt()}' : '$p';
                  _setHz(_hzController.text);
                },
              ),
          ],
        ),
      ],
    );
  }

  String _inputString() {
    if (_input.isEmpty) return _cursor == 0 ? '▏' : '';
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
        VarTok() => 'x',
        FuncTok f => '${f.id.label}${f.id.isPrefix ? ' ' : ''}',
        ConstTok c => c.id.label,
        RatLitTok r => r.label,
      };
}
