import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../scaffold/tool_scaffold.dart';
import '../theory.dart';
import 'unit_circle/checkpoints.dart';
import 'unit_circle/scene_painter.dart';

/// Einheitskreis mit beweglichem Zeiger. Rastet weich an Standardwinkeln
/// ein und federt im Uhrzeigersinn zurück zum Ruhewinkel 0°.
class UnitCirclePage extends StatefulWidget {
  const UnitCirclePage({super.key});

  @override
  State<UnitCirclePage> createState() => _UnitCirclePageState();
}

class _UnitCirclePageState extends State<UnitCirclePage>
    with TickerProviderStateMixin {
  static const String _theoryAsset = 'assets/theory/einheitskreis.md';
  static const double _snapEnterDeg = 2.0;
  static const double _snapReleaseDeg = 5.0;
  static const double _maxHz = 60.0;

  /// Aktueller Zeigerwinkel in Grad, mathematisches System (0..360).
  /// Beim Snap zeigt dieser Wert auf den Checkpoint-Winkel.
  double _angle = 0.0;

  /// Der „un-gesnappte" Winkel, der die kumulierte Cursor-Bewegung
  /// reflektiert — nötig für Hysterese: erst wenn `_freeAngle` weit
  /// genug vom Checkpoint weg ist, lassen wir den Snap los.
  double _freeAngle = 0.0;

  Checkpoint? _snapped;
  /// Die absolute Position (in Grad, kann jenseits von 360 liegen) des
  /// aktuellen Snap-Ziels. Nötig für die Hysterese mit Winding.
  double? _snappedAbsDegrees;
  WaveMode _waveMode = WaveMode.markerOnWave;

  /// Winkel des Cursors zum Mittelpunkt im letzten Drag-Frame
  /// (für Wickel-Erkennung).
  double? _lastCursorDegrees;

  late final AnimationController _spring;
  Animation<double>? _springAnim;

  // Hertz-Animation: wenn _frequencyHz > 0 läuft der Zeiger automatisch
  // mit f · 360°/s. Der Ticker läuft permanent, agiert aber nur, wenn
  // weder gerade gezogen wird noch Spring-Back aktiv ist.
  double _frequencyHz = 0.0;
  late final Ticker _hzTicker;
  Duration? _hzLastTick;
  late final TextEditingController _hzController;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(vsync: this);
    _spring.addListener(() {
      if (_springAnim == null) return;
      setState(() {
        _angle = _springAnim!.value;
        _freeAngle = _angle;
        final result = _nearestCheckpointAbs(_angle, _snapEnterDeg);
        _snapped = result?.cp;
        _snappedAbsDegrees = result?.absDegrees;
      });
    });
    _hzController = TextEditingController(text: '');
    _hzTicker = createTicker(_onHzTick)..start();
  }

  @override
  void dispose() {
    _hzTicker.dispose();
    _hzController.dispose();
    _spring.dispose();
    super.dispose();
  }

  void _onHzTick(Duration elapsed) {
    if (_frequencyHz == 0 ||
        _lastCursorDegrees != null ||
        _spring.isAnimating) {
      _hzLastTick = elapsed;
      return;
    }
    final last = _hzLastTick;
    _hzLastTick = elapsed;
    if (last == null) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) return;
    setState(() {
      _angle = _angle + _frequencyHz * 360 * dt;
      _freeAngle = _angle;
      // Während Auto-Animation kein Snap-Pinning — _snapped bleibt null,
      // damit der Zeiger ungebremst durch die Anker fließt.
      _snapped = null;
      _snappedAbsDegrees = null;
    });
  }

  void _setHz(double hz) {
    final clamped = hz.clamp(-_maxHz, _maxHz);
    setState(() {
      _frequencyHz = clamped;
      _hzLastTick = null;
      if (clamped != 0) {
        _spring.stop();
        _snapped = null;
        _snappedAbsDegrees = null;
      }
    });
  }

  void _setHzFromText(String s) {
    final cleaned = s.replaceAll(',', '.').trim();
    final value = double.tryParse(cleaned);
    if (value == null) {
      _setHz(0);
      return;
    }
    _setHz(value);
  }

  void _setHzFromPreset(double hz) {
    _hzController.text = hz == hz.roundToDouble() ? '${hz.toInt()}' : '$hz';
    _setHz(hz);
  }

  void _onPanStart(Offset localPosition, SceneLayout layout) {
    if (!layout.isInsideCircleArea(localPosition)) return;
    _spring.stop();
    _lastCursorDegrees = layout.cursorAngleDegrees(localPosition);
    _updateAngleFromCursor(localPosition, layout, isStart: true);
  }

  void _onPanUpdate(Offset localPosition, SceneLayout layout) {
    _updateAngleFromCursor(localPosition, layout, isStart: false);
  }

  void _onPanEnd() {
    _lastCursorDegrees = null;
    if (_frequencyHz != 0) {
      _hzLastTick = null;
      _snapped = null;
      _snappedAbsDegrees = null;
      return;
    }
    _startSpringBack();
  }

  /// Wendet die Cursor-Bewegung als Delta auf den Zeigerwinkel an —
  /// vermeidet damit den Sprung beim Überschreiten von 0°/360°. Klemmt
  /// auf [0, 360] (single-revolution). Snap-Hysterese: Eintritt bei
  /// `_snapEnterDeg`, Austritt erst jenseits `_snapReleaseDeg` — sonst
  /// klebt der Zeiger bei langsamer Bewegung am Checkpoint fest.
  void _updateAngleFromCursor(
    Offset local,
    SceneLayout layout, {
    required bool isStart,
  }) {
    final cursor = layout.cursorAngleDegrees(local);

    if (isStart) {
      _freeAngle = cursor;
      _snapped = null;
      _snappedAbsDegrees = null;
    } else if (_lastCursorDegrees != null) {
      var delta = cursor - _lastCursorDegrees!;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      _freeAngle = _freeAngle + delta;
    }
    _lastCursorDegrees = cursor;

    if (_snappedAbsDegrees != null &&
        (_freeAngle - _snappedAbsDegrees!).abs() > _snapReleaseDeg) {
      _snapped = null;
      _snappedAbsDegrees = null;
    }
    if (_snapped == null) {
      final result = _nearestCheckpointAbs(_freeAngle, _snapEnterDeg);
      if (result != null) {
        _snapped = result.cp;
        _snappedAbsDegrees = result.absDegrees;
      }
    }

    setState(() {
      _angle = _snappedAbsDegrees ?? _freeAngle;
    });
  }

  /// Findet den naheliegendsten Checkpoint in absoluter Position — sucht
  /// in der aktuellen Umrundung sowie in den beiden Nachbarn, damit Snap
  /// auch nahe der 0°/360°-Grenze sauber funktioniert.
  ({Checkpoint cp, double absDegrees})? _nearestCheckpointAbs(
      double angle, double tolerance) {
    Checkpoint? bestCp;
    double bestAbs = 0;
    double bestDist = tolerance;
    final base = (angle / 360).floor();
    for (final r in [base - 1, base, base + 1]) {
      for (final cp in kCheckpoints) {
        final candAbs = r * 360 + cp.degrees;
        final dist = (angle - candAbs).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestCp = cp;
          bestAbs = candAbs;
        }
      }
    }
    if (bestCp == null) return null;
    return (cp: bestCp, absDegrees: bestAbs);
  }

  void _startSpringBack() {
    if (_angle.abs() <= 0.001) {
      _angle = 0;
      _freeAngle = 0;
      _snapped = nearestCheckpoint(0);
      _snappedAbsDegrees = 0;
      setState(() {});
      return;
    }
    final from = _angle;
    final duration = Duration(
      milliseconds: (300 + from.abs() * 1.5).clamp(300, 2000).toInt(),
    );
    _spring
      ..stop()
      ..duration = duration;
    _springAnim = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic),
    );
    _spring.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Einheitskreis',
      controls: _buildDisplay(),
      canvas: _buildCanvas(),
      reference: const ToolReference(tabs: [
        ReferenceTab(
          label: 'Theorie',
          content: TheoryView(assetPath: _theoryAsset),
        ),
      ]),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final layout = SceneLayout.compute(size);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _onPanStart(d.localPosition, layout),
        onPanUpdate: (d) => _onPanUpdate(d.localPosition, layout),
        onPanEnd: (_) => _onPanEnd(),
        onPanCancel: _onPanEnd,
        onTapDown: (d) {
          if (!layout.isInsideCircleArea(d.localPosition)) return;
          _spring.stop();
          _onPanStart(d.localPosition, layout);
        },
        onTapUp: (_) => _onPanEnd(),
        child: CustomPaint(
          painter: UnitCircleScenePainter(
            angleDegrees: _angle,
            snapped: _snapped,
            colorScheme: Theme.of(context).colorScheme,
            textStyle:
                Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
            waveMode: _waveMode,
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }

  Widget _buildHzControls(ThemeData theme) {
    final running = _frequencyHz != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequenz (Hz)',
          style: theme.textTheme.labelMedium,
        ),
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
                  hintText: '0 (steht still)',
                  suffixText: 'Hz',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: _setHzFromText,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: running ? 'Animation stoppen' : 'Animation läuft nicht',
              icon: Icon(running ? Icons.stop_circle : Icons.stop_circle_outlined),
              onPressed: running
                  ? () {
                      _hzController.text = '';
                      _setHz(0);
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final preset in const [0.5, 1.0, 5.0, 50.0])
              ActionChip(
                label: Text(preset == preset.roundToDouble()
                    ? '${preset.toInt()} Hz'
                    : '$preset Hz'),
                onPressed: () => _setHzFromPreset(preset),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        Text(
          'Bei 50 Hz (Wechselstrom) wird der Zeiger zum Schemen — '
          'das Auge kann der Bewegung nicht mehr folgen.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDisplay() {
    final theme = Theme.of(context);
    final radians = _angle * math.pi / 180;
    final cosV = math.cos(radians);
    final sinV = math.sin(radians);

    final hauptTex = _texForRadians(radians);
    final koordTex = _snapped != null
        ? _snapped!.texCoords
        : r'\left(' +
            cosV.toStringAsFixed(3) +
            r',\,' +
            sinV.toStringAsFixed(3) +
            r'\right)';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          SegmentedButton<WaveMode>(
            segments: const [
              ButtonSegment(
                value: WaveMode.markerOnWave,
                label: Text('Punkt wandert'),
              ),
              ButtonSegment(
                value: WaveMode.waveOnMarker,
                label: Text('Welle wandert'),
              ),
            ],
            selected: {_waveMode},
            onSelectionChanged: (s) => setState(() => _waveMode = s.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity(horizontal: -2, vertical: -2),
            ),
          ),
          const SizedBox(height: 16),
          _buildHzControls(theme),
          const SizedBox(height: 16),
          Text('Zeiger', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              hauptTex,
              textStyle: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${_angle.toStringAsFixed(1)}°',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${radians.toStringAsFixed(3)} rad',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Koordinaten (cos, sin)', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              koordTex,
              textStyle: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ziehe den Zeiger auf dem Kreis. Über 360° hinaus läuft die '
            'Welle weiter. Beim Loslassen rutscht der Zeiger zurück zum '
            'Ruhewinkel.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Druckt einen Bogenmaß-Wert als möglichst hübschen LaTeX-Ausdruck.
  /// Sonderfall: ganzzahlige Vielfache von τ → `\tau`, `2\tau`, …
  /// Sonst: Bruch über π mit Nenner aus {1, 2, 3, 4, 6, 8}, soweit der
  /// Wert genau passt; andernfalls Dezimalmultipikator.
  String _texForRadians(double rad) {
    if (rad.abs() < 1e-3) return r'0';

    final tauRatio = rad / (2 * math.pi);
    final tauRounded = tauRatio.roundToDouble();
    if ((tauRatio - tauRounded).abs() < 1e-3 && tauRounded != 0) {
      final n = tauRounded.toInt();
      if (n == 1) return r'\tau';
      if (n == -1) return r'-\tau';
      return '$n\\tau';
    }

    final piRatio = rad / math.pi;
    for (final den in [1, 2, 3, 4, 6, 8]) {
      final num = piRatio * den;
      if ((num - num.roundToDouble()).abs() < 1e-3) {
        var n = num.round();
        var d = den;
        final g = _gcd(n.abs(), d);
        n ~/= g;
        d ~/= g;
        if (d == 1) {
          if (n == 1) return r'\pi';
          if (n == -1) return r'-\pi';
          return '$n\\pi';
        }
        final sign = n < 0 ? '-' : '';
        return '$sign\\dfrac{${n.abs()}\\pi}{$d}';
      }
    }
    return '${piRatio.toStringAsFixed(3)}\\,\\pi';
  }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}
