import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../theory.dart';
import '../widgets/app_drawer.dart';
import '../widgets/drag_handle.dart';
import 'unit_circle/checkpoints.dart';
import 'unit_circle/circle_painter.dart';

/// Einheitskreis mit beweglichem Zeiger. Rastet weich an Standardwinkeln
/// ein und federt im Uhrzeigersinn zurück zum Ruhewinkel 0°.
class UnitCirclePage extends StatefulWidget {
  const UnitCirclePage({super.key});

  @override
  State<UnitCirclePage> createState() => _UnitCirclePageState();
}

class _UnitCirclePageState extends State<UnitCirclePage>
    with SingleTickerProviderStateMixin {
  static const String _theoryAsset = 'assets/theory/einheitskreis.md';
  static const double _snapEnterDeg = 2.0;
  static const double _snapReleaseDeg = 5.0;

  /// Aktueller Zeigerwinkel in Grad, mathematisches System (0..360).
  /// Beim Snap zeigt dieser Wert auf den Checkpoint-Winkel.
  double _angle = 0.0;

  /// Der „un-gesnappte" Winkel, der die kumulierte Cursor-Bewegung
  /// reflektiert — nötig für Hysterese: erst wenn `_freeAngle` weit
  /// genug vom Checkpoint weg ist, lassen wir den Snap los.
  double _freeAngle = 0.0;

  Checkpoint? _snapped;

  /// Winkel des Cursors zum Mittelpunkt im letzten Drag-Frame
  /// (für Wickel-Erkennung).
  double? _lastCursorDegrees;

  late final AnimationController _spring;
  Animation<double>? _springAnim;

  double _controlsWidth = 360;
  double _theoryWidth = 460;
  bool _theoryVisible = false;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(vsync: this);
    _spring.addListener(() {
      if (_springAnim == null) return;
      setState(() {
        _angle = _springAnim!.value;
        _freeAngle = _angle;
        _snapped = nearestCheckpoint(_angle, toleranceDeg: _snapEnterDeg);
      });
    });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _onPanStart(Offset localPosition, Size size) {
    _spring.stop();
    _lastCursorDegrees = _cursorDegrees(localPosition, size);
    _updateAngleFromCursor(localPosition, size, isStart: true);
  }

  void _onPanUpdate(Offset localPosition, Size size) {
    _updateAngleFromCursor(localPosition, size, isStart: false);
  }

  void _onPanEnd() {
    _lastCursorDegrees = null;
    _startSpringBack();
  }

  /// Liefert den Winkel des Cursors zum Mittelpunkt in Grad,
  /// normalisiert auf [0, 360).
  double _cursorDegrees(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = local.dx - center.dx;
    final dy = center.dy - local.dy; // Y nach oben positiv
    final rad = math.atan2(dy, dx);
    var deg = rad * 180 / math.pi;
    if (deg < 0) deg += 360;
    return deg;
  }

  /// Wendet die Cursor-Bewegung als Delta auf den Zeigerwinkel an —
  /// vermeidet damit den Sprung beim Überschreiten von 0°/360°. Klemmt
  /// auf [0, 360] (single-revolution). Snap-Hysterese: Eintritt bei
  /// `_snapEnterDeg`, Austritt erst jenseits `_snapReleaseDeg` — sonst
  /// klebt der Zeiger bei langsamer Bewegung am Checkpoint fest.
  void _updateAngleFromCursor(Offset local, Size size, {required bool isStart}) {
    final cursor = _cursorDegrees(local, size);

    if (isStart) {
      _freeAngle = cursor.clamp(0.0, 360.0);
      _snapped = null;
    } else if (_lastCursorDegrees != null) {
      var delta = cursor - _lastCursorDegrees!;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      _freeAngle = (_freeAngle + delta).clamp(0.0, 360.0);
    }
    _lastCursorDegrees = cursor;

    // Hysterese: gesnappt bleiben, bis _freeAngle den Release-Radius verlässt.
    Checkpoint? snap = _snapped;
    if (snap != null && (_freeAngle - snap.degrees).abs() > _snapReleaseDeg) {
      snap = null;
    }
    snap ??= nearestCheckpoint(_freeAngle, toleranceDeg: _snapEnterDeg);

    setState(() {
      _snapped = snap;
      _angle = snap?.degrees ?? _freeAngle;
    });
  }

  void _startSpringBack() {
    if (_angle <= 0.001) {
      _angle = 0;
      _freeAngle = 0;
      _snapped = nearestCheckpoint(0);
      setState(() {});
      return;
    }
    final from = _angle;
    final duration =
        Duration(milliseconds: (300 + from * 1.5).clamp(300, 1300).toInt());
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
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Einheitskreis'),
        actions: [
          LayoutBuilder(builder: (context, _) {
            final isWide = MediaQuery.of(context).size.width > 700;
            return IconButton(
              tooltip: 'Theorie',
              icon: Icon(
                _theoryVisible && isWide
                    ? Icons.menu_book
                    : Icons.menu_book_outlined,
              ),
              onPressed: () {
                if (isWide) {
                  setState(() => _theoryVisible = !_theoryVisible);
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const _TheoryRoute(asset: _theoryAsset),
                  ));
                }
              },
            );
          }),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          if (isWide) return _buildWideLayout(constraints);
          return Column(
            children: [
              Expanded(child: _buildCanvas()),
              const Divider(height: 1),
              SizedBox(height: 280, child: _buildDisplay()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    final theoryW = _theoryVisible
        ? _theoryWidth.clamp(320.0, constraints.maxWidth * 0.6)
        : 0.0;
    final maxControls = constraints.maxWidth - 240 - theoryW;
    final controlsW = _controlsWidth.clamp(
      260.0,
      maxControls.clamp(260.0, double.infinity),
    );
    return Row(
      children: [
        SizedBox(width: controlsW, child: _buildDisplay()),
        DragHandle(
          onDrag: (dx) => setState(() {
            _controlsWidth = (_controlsWidth + dx).clamp(260.0, maxControls);
          }),
        ),
        Expanded(child: _buildCanvas()),
        if (_theoryVisible) ...[
          DragHandle(
            onDrag: (dx) => setState(() {
              _theoryWidth = (_theoryWidth - dx)
                  .clamp(320.0, constraints.maxWidth * 0.6);
            }),
          ),
          SizedBox(
            width: theoryW,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Theorie',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Schließen',
                        onPressed: () => setState(() => _theoryVisible = false),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: TheoryView(assetPath: _theoryAsset)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _onPanStart(d.localPosition, size),
        onPanUpdate: (d) => _onPanUpdate(d.localPosition, size),
        onPanEnd: (_) => _onPanEnd(),
        onPanCancel: _onPanEnd,
        onTapDown: (d) {
          _spring.stop();
          _onPanStart(d.localPosition, size);
        },
        onTapUp: (_) => _onPanEnd(),
        child: CustomPaint(
          painter: UnitCirclePainter(
            angleDegrees: _angle,
            snapped: _snapped,
            colorScheme: Theme.of(context).colorScheme,
            textStyle: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }

  Widget _buildDisplay() {
    final theme = Theme.of(context);
    final radians = _angle * math.pi / 180;
    final cosV = math.cos(radians);
    final sinV = math.sin(radians);

    final hauptTex = _snapped != null
        ? _snapped!.texFraction
        : '${(radians / math.pi).toStringAsFixed(3)}\\,\\pi';
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
            'Ziehe den Zeiger auf dem Kreis. Beim Loslassen läuft er im '
            'Uhrzeigersinn zurück zum Ruhewinkel. An Standardwinkeln rastet '
            'er weich ein.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TheoryRoute extends StatelessWidget {
  const _TheoryRoute({required this.asset});
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theorie')),
      body: TheoryView(assetPath: asset),
    );
  }
}

