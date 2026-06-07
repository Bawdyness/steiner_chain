// Kurve — a function plotter that grows. Enter f(x) in dozenal via the keypad;
// the curve is sampled through the shared calc f64 rail and drawn on a
// pan/zoomable plane. Unlike a static plot, the curve (and the area under it)
// *grows* left→right on a Hz-timed sweep — Wachstum's idea applied to f(x):
// steep stretches shoot up fast, flat ones crawl.
//
// Reuses lib/calc/ (evaluator, glyphs, keyboard, input); no cross-tool import.

import 'dart:math' as math;

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
  int _base = 12; // number base for input + axis labels (10/12/24)
  static const double _maxHz = 20.0;
  static const AngleMode _angleMode = AngleMode.rad; // math plotting

  /// One-tap example functions for non-mathematicians: pick one, then "Wachsen"
  /// or "Endlosschlaufe". Grouped by behaviour. Small digit literals only, so
  /// they read the same in every base.
  static final List<_Preset> _presets = [
    // Einfach — static shapes (the loop would just scroll them off-screen).
    _Preset('Parabel', _Kind.simple, [
      [VarTok(), OpTok(BinOp.mul), VarTok()],
    ]),
    _Preset('Glocke', _Kind.simple, [
      [
        DigitTok(1), OpTok(BinOp.div), LParenTok(),
        VarTok(), OpTok(BinOp.mul), VarTok(), OpTok(BinOp.add), DigitTok(1),
        RParenTok(),
      ],
    ]),
    _Preset('Achterbahn', _Kind.simple, [
      [
        VarTok(), OpTok(BinOp.mul), VarTok(), OpTok(BinOp.mul), VarTok(),
        OpTok(BinOp.sub), DigitTok(4), OpTok(BinOp.mul), VarTok(),
      ],
    ]),
    // Einfach — extra value-labelled chips (no names, just the formula).
    _Preset('x²', _Kind.simple, [
      [VarTok(), OpTok(BinOp.pow), DigitTok(2)],
    ]),
    _Preset('x³', _Kind.simple, [
      [VarTok(), OpTok(BinOp.pow), DigitTok(3)],
    ]),
    _Preset('2x³', _Kind.simple, [
      [DigitTok(2), OpTok(BinOp.mul), VarTok(), OpTok(BinOp.pow), DigitTok(3)],
    ]),
    _Preset('x³−4x', _Kind.simple, [
      [
        VarTok(), OpTok(BinOp.pow), DigitTok(3),
        OpTok(BinOp.sub), DigitTok(4), OpTok(BinOp.mul), VarTok(),
      ],
    ]),
    _Preset('x⁴−5x²', _Kind.simple, [
      [
        VarTok(), OpTok(BinOp.pow), DigitTok(4),
        OpTok(BinOp.sub),
        DigitTok(5), OpTok(BinOp.mul), VarTok(), OpTok(BinOp.pow), DigitTok(2),
      ],
    ]),
    _Preset('√x', _Kind.simple, [
      [FuncTok(FuncId.sqrt), LParenTok(), VarTok(), RParenTok()],
    ]),
    _Preset('1/x', _Kind.simple, [
      [DigitTok(1), OpTok(BinOp.div), VarTok()],
    ]),
    _Preset('2ˣ', _Kind.simple, [
      [DigitTok(2), OpTok(BinOp.pow), VarTok()],
    ]),
    // Wiederholend — waves that travel nicely in the endless loop.
    _Preset('Welle', _Kind.repeating, [
      [FuncTok(FuncId.sin), LParenTok(), VarTok(), RParenTok()],
    ]),
    _Preset('Große Welle', _Kind.repeating, [
      [
        VarTok(), OpTok(BinOp.mul),
        FuncTok(FuncId.sin), LParenTok(), VarTok(), RParenTok(),
      ],
    ]),
    _Preset('Zappelwelle', _Kind.repeating, [
      [
        FuncTok(FuncId.sin), LParenTok(),
        VarTok(), OpTok(BinOp.mul), VarTok(), RParenTok(),
      ],
    ]),
    _Preset('Schnelle Welle', _Kind.repeating, [
      [
        FuncTok(FuncId.sin), LParenTok(),
        DigitTok(4), OpTok(BinOp.mul), VarTok(), RParenTok(),
      ],
    ]),
    _Preset('Tangens', _Kind.repeating, [
      [FuncTok(FuncId.tan), LParenTok(), VarTok(), RParenTok()],
    ]),
    // Wiederholend — extra value-labelled chips.
    _Preset('cos(x)', _Kind.repeating, [
      [FuncTok(FuncId.cos), LParenTok(), VarTok(), RParenTok()],
    ]),
    _Preset('sin(2x)', _Kind.repeating, [
      [
        FuncTok(FuncId.sin), LParenTok(),
        DigitTok(2), OpTok(BinOp.mul), VarTok(), RParenTok(),
      ],
    ]),
    _Preset('sin(3x)', _Kind.repeating, [
      [
        FuncTok(FuncId.sin), LParenTok(),
        DigitTok(3), OpTok(BinOp.mul), VarTok(), RParenTok(),
      ],
    ]),
    _Preset('sin(x)+cos(2x)', _Kind.repeating, [
      [
        FuncTok(FuncId.sin), LParenTok(), VarTok(), RParenTok(),
        OpTok(BinOp.add),
        FuncTok(FuncId.cos), LParenTok(),
        DigitTok(2), OpTok(BinOp.mul), VarTok(), RParenTok(),
      ],
    ]),
    _Preset('x·cos(x)', _Kind.repeating, [
      [
        VarTok(), OpTok(BinOp.mul),
        FuncTok(FuncId.cos), LParenTok(), VarTok(), RParenTok(),
      ],
    ]),
    // Mehrfarbig — several curves in different colours at once.
    _Preset('Harmonische', _Kind.multi, [
      [FuncTok(FuncId.sin), LParenTok(), VarTok(), RParenTok()],
      [
        FuncTok(FuncId.sin), LParenTok(),
        DigitTok(2), OpTok(BinOp.mul), VarTok(), RParenTok(),
      ],
      [
        FuncTok(FuncId.sin), LParenTok(),
        DigitTok(3), OpTok(BinOp.mul), VarTok(), RParenTok(),
      ],
    ]),
    _Preset('Sin & Cos', _Kind.multi, [
      [FuncTok(FuncId.sin), LParenTok(), VarTok(), RParenTok()],
      [FuncTok(FuncId.cos), LParenTok(), VarTok(), RParenTok()],
    ]),
    // Mehrfarbig — extra value-labelled chips (one list per colour).
    _Preset('x · x² · x³', _Kind.multi, [
      [VarTok()],
      [VarTok(), OpTok(BinOp.pow), DigitTok(2)],
      [VarTok(), OpTok(BinOp.pow), DigitTok(3)],
    ]),
    _Preset('cos x · cos 2x · cos 3x', _Kind.multi, [
      [FuncTok(FuncId.cos), LParenTok(), VarTok(), RParenTok()],
      [
        FuncTok(FuncId.cos), LParenTok(),
        DigitTok(2), OpTok(BinOp.mul), VarTok(), RParenTok(),
      ],
      [
        FuncTok(FuncId.cos), LParenTok(),
        DigitTok(3), OpTok(BinOp.mul), VarTok(), RParenTok(),
      ],
    ]),
  ];

  /// Bounded parametric figures (closed loops) — they make a shape *inside* the
  /// frame instead of running off it. Drawn parametrically (not as f(x)), so
  /// they live outside the [_curves] token model: see [_shape]. Each is a dense,
  /// arc-length-even list of (x, y) points already centred and scaled to fit.
  static final List<_Shape> _shapes = [
    _Shape(
      label: 'Kreis',
      params: const [
        _ShapeParam('a', 'Breite', 2, 11),
        _ShapeParam('b', 'Höhe', 2, 11),
      ],
      defaults: const {'a': 8, 'b': 8},
      build: (p) => _ellipse(p['a']!, p['b']!, 240),
      formula: (p) =>
          'x = ${_fmtMag(p['a']!)} cos t\ny = ${_fmtMag(p['b']!)} sin t',
      titleOf: (p) => (p['a']! - p['b']!).abs() < 0.05 ? 'Kreis' : 'Ellipse',
    ),
    _Shape(
      label: 'Herz',
      params: const [_ShapeParam('a', 'Größe', 2, 11)],
      defaults: const {'a': 8},
      build: (p) => _scaled(_heartUnit, p['a']!),
      formula: (p) {
        final a = p['a']!;
        return 'x = ${_fmtMag(a)} sin³t\n'
            'y = ${_fmtMag(a * 13 / 16)} cos t − ${_fmtMag(a * 5 / 16)} cos 2t '
            '− ${_fmtMag(a * 2 / 16)} cos 3t − ${_fmtMag(a / 16)} cos 4t';
      },
    ),
    _polyShape('Quadrat', 4, math.pi / 4),
    _polyShape('Raute', 4, 0),
    _polyShape('Dreieck', 3, math.pi / 2),
    _polyShape('Fünfeck', 5, math.pi / 2),
    _polyShape('Sechseck', 6, 0),
    _Shape(
      label: 'Stern',
      params: const [
        _ShapeParam('a', 'Größe', 2, 11),
        _ShapeParam('n', 'Spitzen', 4, 9, integer: true),
        _ShapeParam('k', 'Tiefe', 0.2, 0.8),
      ],
      defaults: const {'a': 8, 'n': 5, 'k': 0.42},
      build: (p) => _polyOutline(
          _starVerts(p['n']!.round(), p['a']!, p['a']! * p['k']!, math.pi / 2),
          240),
      formula: (p) =>
          'r wechselt ${_fmtMag(p['a']!)} ↔ ${_fmtMag(p['a']! * p['k']!)} '
          '(${p['n']!.round()} Spitzen)',
    ),
    _Shape(
      label: 'Astroid',
      params: const [
        _ShapeParam('a', 'Breite', 2, 11),
        _ShapeParam('b', 'Höhe', 2, 11),
      ],
      defaults: const {'a': 8, 'b': 8},
      build: (p) => _astroidAB(p['a']!, p['b']!, 240),
      formula: (p) =>
          'x = ${_fmtMag(p['a']!)} cos³t\ny = ${_fmtMag(p['b']!)} sin³t',
    ),
  ];

  /// Colour used for a [_shape] (and its banner).
  static const Color _shapeColor = Color(0xFFF28B82); // coral

  /// Colours for the extra curves of the multi-colour presets (the main curve
  /// keeps the primary colour).
  static const List<Color> _multiColors = [
    Color(0xFF8AB4F8), // blue
    Color(0xFF81C995), // green
    Color(0xFFF28B82), // coral
  ];

  // The plotted curves (≥1). Curve 0 is the primary colour, extras use the
  // palette. [_active] is the one the keypad edits. f(x) = x by default.
  List<List<Tok>> _curves = [
    [const VarTok()],
  ];
  int _active = 0;
  int _cursor = 1;
  List<double Function(double)> _compiled = const [];

  PlotView _view = PlotView.initial;

  /// When non-null, a closed parametric figure is shown instead of the f(x)
  /// curves (the "Formen" presets). Editing the keypad or picking an f(x)
  /// preset clears it.
  _Shape? _shape;

  /// Current magnitudes of [_shape] (size, corner count, …) and the point loop
  /// built from them. The sliders edit [_shapeParams]; that rebuilds
  /// [_shapePoints], which is what the painter and the live readout consume.
  Map<String, double> _shapeParams = const {};
  List<Offset> _shapePoints = const [];

  _Move _move = _Move.schlaufe; // which animation Play runs
  bool _running = false; // play/pause; paused shows the full static curve
  double _sweepX = 0; // growth front for Schlange
  double _phase = 0; // horizontal shift for Schlaufe: curve drawn as f(x − phase)
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

  void _recompile() => _compiled = [
        for (final c in _curves) compileF64(c, _angleMode, base: _base),
      ];

  bool _isArmed(FuncId id) => isInverseArmed(_curves[_active], _cursor, id);

  /// One-tap preset: replace the curve list, reframe the view, rewind.
  void _applyPreset(_Preset p) {
    setState(() {
      _shape = null; // leave shape mode if it was active
      _curves = [for (final c in p.curves) List.of(c)];
      _active = 0;
      _cursor = _curves[0].length;
      _recompile();
      _view = PlotView.initial;
      _sweepX = _view.xMin;
      _phase = 0; // restart any running animation on the new curve(s)
    });
  }

  /// One-tap figure: draw a closed parametric shape instead of f(x).
  void _applyShape(_Shape s) {
    setState(() {
      _shape = s;
      _shapeParams = Map.of(s.defaults);
      _shapePoints = s.build(_shapeParams);
      _view = PlotView.initial;
      _phase = 0;
      _sweepX = _view.xMin;
      _lastTick = null;
    });
  }

  /// Change one magnitude of the active figure and rebuild its outline.
  void _setShapeParam(_ShapeParam p, double v) {
    setState(() {
      _shapeParams = {
        ..._shapeParams,
        p.key: p.integer ? v.roundToDouble() : v,
      };
      _shapePoints = _shape!.build(_shapeParams);
    });
  }

  /// Leave shape mode, back to the (unchanged) f(x) curves.
  void _clearShape() => setState(() {
        _shape = null;
        _shapePoints = const [];
        _phase = 0;
        _sweepX = _view.xMin;
      });

  /// The figure's current animation state: Schlange traces the outline (trace <
  /// 1), Schlaufe pulses it (pulse ≠ 1). Used by the canvas and the live row.
  ({double trace, double pulse}) _figureAnim() {
    if (_shape == null || !_running) return (trace: 1.0, pulse: 1.0);
    if (_move == _Move.schlange) return (trace: _phase % 1.0, pulse: 1.0);
    return (trace: 1.0, pulse: 1 + 0.12 * math.sin(2 * math.pi * _phase));
  }

  /// The point currently at the head of the outline (moves while tracing,
  /// breathes while pulsing, sits at the start when paused).
  Offset _leadPoint(double trace, double pulse) {
    if (_shapePoints.isEmpty) return Offset.zero;
    final idx =
        ((_shapePoints.length - 1) * trace).clamp(0, _shapePoints.length - 1);
    final p = _shapePoints[idx.round()];
    return Offset(p.dx * pulse, p.dy * pulse);
  }

  // -- curve management: add / remove / select (each curve is editable) -----
  Color _colorFor(int i, ColorScheme scheme) =>
      i == 0 ? scheme.primary : _multiColors[(i - 1) % _multiColors.length];

  void _selectCurve(int i) => setState(() {
        _shape = null;
        _active = i;
        _cursor = _curves[i].length;
      });

  void _addCurve() => setState(() {
        _shape = null;
        _curves = [
          ..._curves,
          [const VarTok()],
        ];
        _active = _curves.length - 1;
        _cursor = _curves[_active].length;
        _recompile();
      });

  void _removeCurve(int i) {
    if (_curves.length <= 1) return;
    setState(() {
      _curves = [..._curves]..removeAt(i);
      if (_active >= _curves.length) {
        _active = _curves.length - 1;
      } else if (_active > i) {
        _active--;
      }
      _cursor = _curves[_active].length;
      _recompile();
    });
  }

  // --------------------------------------------------------------------
  // Input
  // --------------------------------------------------------------------

  void _onKey(KeypadEvent e) {
    setState(() {
      _shape = null; // any keypad edit means "I want a function", not a figure
      final toks = _curves[_active];
      switch (e) {
        case InsertTok(:final tok):
          // Double-tap a trig/hyperbolic key to toggle its inverse (shared
          // buffer logic with the calculator — see lib/calc/input.dart).
          final swapped =
              tok is FuncTok ? toggledInverse(toks, _cursor, tok.id) : null;
          if (swapped != null) {
            _curves[_active] = swapped;
          } else {
            _curves[_active] = [
              ...toks.sublist(0, _cursor),
              tok,
              ...toks.sublist(_cursor),
            ];
            _cursor++;
          }
        case DeleteKey():
          if (_cursor > 0) {
            _curves[_active] = [...toks]..removeAt(_cursor - 1);
            _cursor--;
          }
        case ClearKey():
          _curves[_active] = const [];
          _cursor = 0;
        case MoveLeft():
          if (_cursor > 0) _cursor--;
        case MoveRight():
          if (_cursor < toks.length) _cursor++;
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
    final e = eventForKey(event, base: _base);
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
  // Animation (play / pause)
  // --------------------------------------------------------------------

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null || !_running) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) return;
    final rate = _hz * _view.xRange; // x-units per second (≈ one width @ 1 Hz)
    setState(() {
      if (_shape != null) {
        // Figure: phase counts cycles/sec — drives the trace (Schlange) or the
        // pulse (Schlaufe). Wrap so it never grows unbounded.
        _phase += _hz * dt;
        if (_phase > 1e6) _phase %= 1.0;
      } else if (_move == _Move.schlaufe) {
        _phase += rate * dt; // travelling wave (shape slides sideways)
      } else {
        _sweepX += rate * dt; // looping grow: redraw from the left at the edge
        if (_sweepX >= _view.xMax) _sweepX = _view.xMin;
      }
    });
  }

  void _togglePlay() {
    setState(() {
      _running = !_running;
      if (_running) {
        // Start a clean run; paused shows the full static curve.
        _phase = 0;
        _sweepX = _view.xMin;
        _lastTick = null;
      }
    });
  }

  void _setMove(_Move m) {
    setState(() {
      _move = m;
      if (_running) {
        _phase = 0;
        _sweepX = _view.xMin;
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
            final scheme = theme.colorScheme;
            final shape = _shape;
            final phase = _phase; // capture for the Schlaufe closures
            final shifted = shape == null && _running && _move == _Move.schlaufe;
            final curves = <({double Function(double) fn, Color color})>[];
            if (shape == null) {
              for (var i = 0; i < _compiled.length; i++) {
                final fn = _compiled[i];
                curves.add((
                  fn: shifted ? (x) => fn(x - phase) : fn,
                  color: _colorFor(i, scheme),
                ));
              }
            }
            // Figure animation: Schlange traces the outline, Schlaufe pulses it.
            final anim = _figureAnim();
            return GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: (d) => _onScaleUpdate(geom, d),
              child: CustomPaint(
                size: size,
                painter: PlotPainter(
                  curves: curves,
                  view: _view,
                  sweepX: (shape == null && _running && _move == _Move.schlange)
                      ? _sweepX
                      : double.infinity,
                  scheme: scheme,
                  textStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
                  base: _base,
                  hasFunction: shape == null && _curves.any((c) => c.isNotEmpty),
                  shape: shape == null ? null : _shapePoints,
                  shapeColor: _shapeColor,
                  shapeTrace: anim.trace,
                  shapePulse: anim.pulse,
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
    final scheme = theme.colorScheme;
    final dx = (_running && _move == _Move.schlaufe) ? -_phase : 0.0;
    final anim = _figureAnim();
    final lead = _shape == null ? Offset.zero : _leadPoint(anim.trace, anim.pulse);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          if (_shape != null) ...[
            // A closed figure is showing; the f(x) editor is paused. Banner +
            // formula, size sliders, then the live point on the outline.
            _shapeBanner(theme, scheme),
            const SizedBox(height: 8),
            ..._shapeParamSliders(theme),
            const SizedBox(height: 6),
            Text(
              'Wo die Form gerade ist',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            _axisRow('x', lead.dx),
            _axisRow('y', lead.dy),
          ] else ...[
            // f(x) = … one selectable/removable row per curve, colour-coded.
            for (var i = 0; i < _curves.length; i++) _curveRow(i, theme, scheme),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addCurve,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Funktion'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Wo jede Farbe gerade ist (Höhe bei x=0)',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < _curves.length; i++)
              _valueRow(_colorFor(i, scheme), _compiled[i](dx)),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
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
              _recompile(); // re-parse f(x) in the new base; axis relabels too
            }),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          KurveKeypad(onKey: _onKey, isArmed: _isArmed, base: _base),
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
            'Zahlensystem 10/12/24 (Ziffern + Achsen); Variable x + voller '
            'Funktionssatz (Doppeltipp = Inverse). Mit „+ Funktion" mehrere '
            'farbige Kurven gleichzeitig. Bewegung: „Schlaufe" schiebt die Welle '
            'seitwärts, „Schlange" zeichnet die Kurve endlos neu — „Abspielen" '
            'startet, „Pause" zeigt die ganze Kurve. Bei „Formen" lassen sich '
            'die Größen mit den Reglern ändern; „Schlange" zeichnet die Figur '
            'nach, „Schlaufe" lässt sie pulsieren. '
            'Ziehen verschiebt, Zwei-Finger zoomt. Winkel in Radiant.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text('Coole Funktionen', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            'Antippen, dann „Abspielen". „Schlaufe" passt zu den wiederholenden, '
            '„Schlange" zeichnet jede Kurve. „Formen" bleiben im Bild.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _presetGroup('Einfach', _Kind.simple, theme),
          _presetGroup('Wiederholend', _Kind.repeating, theme),
          _presetGroup('Mehrfarbig', _Kind.multi, theme),
          _shapeGroup('Formen', theme),
        ],
      ),
    );
  }

  Widget _swatch(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _curveRow(int i, ThemeData theme, ColorScheme scheme) {
    final color = _colorFor(i, scheme);
    final active = i == _active;
    final expr = active ? _inputString() : _exprString(_curves[i]);
    return Material(
      color: active ? color.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => _selectCurve(i),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            children: [
              _swatch(color),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Text(
                    'f(x) = $expr',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      color: color,
                    ),
                  ),
                ),
              ),
              if (_curves.length > 1)
                InkWell(
                  onTap: () => _removeCurve(i),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close,
                        size: 16, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueRow(Color color, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            _swatch(color),
            const SizedBox(width: 8),
            Text(
              'y = ${_fmtValue(value)}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      );

  String _exprString(List<Tok> toks) {
    final sb = StringBuffer();
    for (final t in toks) {
      sb.write(_tokLabel(t));
    }
    return sb.toString();
  }

  String _fmtValue(double v) {
    if (!v.isFinite) return v.isNaN ? '—' : (v < 0 ? '−∞' : '∞');
    return v.toStringAsFixed(2).replaceAll('-', '−');
  }

  Widget _presetGroup(String title, _Kind kind, ThemeData theme) {
    final items = _presets.where((p) => p.kind == kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in items)
                ActionChip(
                  label: Text(p.label),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _applyPreset(p),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Replaces the f(x) rows while a figure is showing: colour + name + a close
  /// button to return to the function editor.
  Widget _shapeBanner(ThemeData theme, ColorScheme scheme) {
    return Material(
      color: _shapeColor.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: _swatch(_shapeColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Form: ${_shape!.title(_shapeParams)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _shapeColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shape!.formula(_shapeParams),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.3,
                      color: _shapeColor,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: _clearShape,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 18, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One labelled slider per editable magnitude of the active figure.
  List<Widget> _shapeParamSliders(ThemeData theme) {
    final s = _shape!;
    return [
      for (final p in s.params)
        Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(p.label, style: theme.textTheme.bodySmall),
            ),
            Expanded(
              child: Slider(
                value: (_shapeParams[p.key] ?? p.min).clamp(p.min, p.max),
                min: p.min,
                max: p.max,
                divisions: p.integer ? (p.max - p.min).round() : null,
                onChanged: (v) => _setShapeParam(p, v),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                p.integer
                    ? '${(_shapeParams[p.key] ?? 0).round()}'
                    : _fmtMag(_shapeParams[p.key] ?? 0),
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
    ];
  }

  /// A live coordinate row for the figure's lead point (coral, like [_valueRow]).
  Widget _axisRow(String name, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            _swatch(_shapeColor),
            const SizedBox(width: 8),
            Text(
              '$name = ${_fmtValue(v)}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                color: _shapeColor,
              ),
            ),
          ],
        ),
      );

  Widget _shapeGroup(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in _shapes)
                ActionChip(
                  label: Text(s.label),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _applyShape(s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTempo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bewegung', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        SegmentedButton<_Move>(
          segments: const [
            ButtonSegment(value: _Move.schlaufe, label: Text('Schlaufe')),
            ButtonSegment(value: _Move.schlange, label: Text('Schlange')),
          ],
          selected: {_move},
          onSelectionChanged: (s) => _setMove(s.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 12),
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
                  suffixText: 'Hz',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: _setHz,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _togglePlay,
              icon: Icon(_running ? Icons.pause : Icons.play_arrow),
              label: Text(_running ? 'Pause' : 'Abspielen'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final p in const [0.1, 0.5, 1.0, 2.0, 5.0])
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
    final toks = _curves[_active];
    if (toks.isEmpty) return _cursor == 0 ? '▏' : '';
    final sb = StringBuffer();
    for (var i = 0; i <= toks.length; i++) {
      if (i == _cursor) sb.write('▏');
      if (i < toks.length) sb.write(_tokLabel(toks[i]));
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

/// Which animation Play runs: a sideways-sliding wave, or a looping redraw.
enum _Move { schlaufe, schlange }

/// How a preset behaves, used to group the chips in the controls.
enum _Kind { simple, repeating, multi }

/// A one-tap example. [curves] holds one token list for simple/repeating
/// presets, or several (drawn in different colours) for [_Kind.multi].
class _Preset {
  _Preset(this.label, this.kind, this.curves);
  final String label;
  final _Kind kind;
  final List<List<Tok>> curves;
}

/// One editable magnitude of a figure (size, corner count, …). Drives a slider.
class _ShapeParam {
  const _ShapeParam(this.key, this.label, this.min, this.max,
      {this.integer = false});
  final String key; // lookup in the params map ('a', 'b', 'n', 'k')
  final String label; // slider caption ('Breite', 'Ecken', …)
  final double min, max;
  final bool integer;
}

/// A closed parametric figure (the "Formen" presets), defined by adjustable
/// magnitudes. [build] turns the current parameter values into a dense, evenly
/// spaced loop in data coordinates (centred on the origin); [formula] renders
/// the defining function with those values; [titleOf] is the banner heading
/// (defaults to [label], but e.g. a circle becomes an ellipse).
class _Shape {
  const _Shape({
    required this.label,
    required this.params,
    required this.defaults,
    required this.build,
    required this.formula,
    this.titleOf,
  });
  final String label;
  final List<_ShapeParam> params;
  final Map<String, double> defaults;
  final List<Offset> Function(Map<String, double> p) build;
  final String Function(Map<String, double> p) formula;
  final String Function(Map<String, double> p)? titleOf;

  String title(Map<String, double> p) => titleOf?.call(p) ?? label;
}

/// A regular-polygon figure: one size knob, polar formula, fixed corner count.
_Shape _polyShape(String label, int n, double rot) => _Shape(
      label: label,
      params: const [_ShapeParam('a', 'Größe', 2, 11)],
      defaults: const {'a': 8},
      build: (p) => _scaled(_polyOutline(_polyVerts(n, rot), 240), p['a']!),
      formula: (p) {
        final modArg = n.isEven ? 'π/${n ~/ 2}' : '2π/$n';
        return 'r(θ) = ${_fmtMag(p['a']!)} · cos(π/$n) '
            '/ cos((θ mod $modArg) − π/$n)';
      },
    );

// ---------------------------------------------------------------------------
// Shape generators. Each returns raw (x, y) points; [_fitShape] then centres
// and uniformly scales them so the larger dimension just fills the box. The
// circle/heart/astroid are sampled directly; polygons and stars are given as a
// few vertices and resampled to an even outline so tracing is smooth.
// ---------------------------------------------------------------------------

List<Offset> _fitShape(List<Offset> raw, double half) {
  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  for (final p in raw) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  final span = math.max(maxX - minX, maxY - minY);
  final s = span == 0 ? 1.0 : (2 * half) / span;
  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  return [for (final p in raw) Offset((p.dx - cx) * s, (p.dy - cy) * s)];
}

/// Format an editable magnitude: integers plain, else one decimal.
String _fmtMag(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble()
      ? r.toStringAsFixed(0)
      : r.toStringAsFixed(1);
}

/// Scale a point loop about the origin (size knob for the precomputed shapes).
List<Offset> _scaled(List<Offset> pts, double s) =>
    [for (final p in pts) p * s];

/// Ellipse / circle: x = a·cos t, y = b·sin t.
List<Offset> _ellipse(double a, double b, int n) => [
      for (var i = 0; i <= n; i++)
        Offset(a * math.cos(2 * math.pi * i / n),
            b * math.sin(2 * math.pi * i / n)),
    ];

/// Astroid x = a·cos³t, y = b·sin³t — a four-cusp "pinched" diamond.
List<Offset> _astroidAB(double a, double b, int n) => [
      for (var i = 0; i <= n; i++)
        Offset(a * math.pow(math.cos(2 * math.pi * i / n), 3).toDouble(),
            b * math.pow(math.sin(2 * math.pi * i / n), 3).toDouble()),
    ];

/// The standard heart, centred and normalised to a unit box once; the size
/// knob scales this via [_scaled].
final List<Offset> _heartUnit = _fitShape(_heartPoints(240), 1);

/// Classic parametric heart (later centred/scaled by [_fitShape]).
List<Offset> _heartPoints(int n) {
  final out = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final t = 2 * math.pi * i / n;
    final x = 16 * math.pow(math.sin(t), 3).toDouble();
    final y = 13 * math.cos(t) -
        5 * math.cos(2 * t) -
        2 * math.cos(3 * t) -
        math.cos(4 * t);
    out.add(Offset(x, y));
  }
  return out;
}

/// Vertices of a regular [sides]-gon on the unit circle, rotated by [rot].
List<Offset> _polyVerts(int sides, double rot) => [
      for (var i = 0; i < sides; i++)
        Offset(math.cos(2 * math.pi * i / sides + rot),
            math.sin(2 * math.pi * i / sides + rot)),
    ];

/// Vertices of a [points]-pointed star alternating outer/inner radii.
List<Offset> _starVerts(int points, double rOut, double rIn, double rot) {
  final v = <Offset>[];
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? rOut : rIn;
    final a = math.pi * i / points + rot;
    v.add(Offset(r * math.cos(a), r * math.sin(a)));
  }
  return v;
}

/// Resample a closed vertex loop to [n]+1 points spaced evenly along its
/// perimeter, so a polygon traces as smoothly as a curve.
List<Offset> _polyOutline(List<Offset> verts, int n) {
  final closed = [...verts, verts.first];
  final seg = <double>[];
  var total = 0.0;
  for (var i = 0; i < closed.length - 1; i++) {
    final d = (closed[i + 1] - closed[i]).distance;
    seg.add(d);
    total += d;
  }
  if (total == 0) return closed;
  final out = <Offset>[];
  for (var k = 0; k <= n; k++) {
    var target = total * k / n;
    var i = 0;
    while (i < seg.length - 1 && target > seg[i]) {
      target -= seg[i];
      i++;
    }
    final f = seg[i] == 0 ? 0.0 : (target / seg[i]).clamp(0.0, 1.0);
    out.add(Offset.lerp(closed[i], closed[i + 1], f)!);
  }
  return out;
}
