import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../theory.dart';
import '../widgets/app_drawer.dart';
import '../widgets/drag_handle.dart';

/// Steiner-Kette: `n` Kreise tangieren zwei nicht-schneidende Begrenzungskreise.
///
/// Die exzentrische Variante entsteht durch Möbius-Transformation des
/// Einheitskreises auf den symmetrischen Fall — dieselbe Idee wie im
/// Rust-Prototyp.
class SteinerPage extends StatefulWidget {
  const SteinerPage({super.key});

  @override
  State<SteinerPage> createState() => _SteinerPageState();
}

class _SteinerPageState extends State<SteinerPage>
    with SingleTickerProviderStateMixin {
  static const String _theoryAsset = 'assets/theory/steiner.md';

  int _n = 12;
  double _offset = 0.0;
  double _rotation = 0.0;
  bool _animate = true;
  double _controlsWidth = 360;
  double _theoryWidth = 460;
  bool _theoryVisible = false;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!_animate) {
      _lastTick = elapsed;
      return;
    }
    final dtMs = (elapsed - _lastTick).inMilliseconds;
    _lastTick = elapsed;
    setState(() {
      _rotation += dtMs * 0.0005;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Steiner-Kette'),
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
          if (isWide) {
            return _buildWideLayout(constraints);
          }
          return Column(
            children: [
              Expanded(child: _buildCanvas()),
              const Divider(height: 1),
              SizedBox(height: 280, child: _buildControls()),
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
    final controlsW = _controlsWidth.clamp(260.0, maxControls.clamp(260.0, double.infinity));

    return Row(
      children: [
        SizedBox(width: controlsW, child: _buildControls()),
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

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('Anzahl Kreise (n): $_n'),
          Slider(
            value: _n.toDouble(),
            min: 3,
            max: 24,
            divisions: 21,
            label: '$_n',
            onChanged: (v) => setState(() => _n = v.round()),
          ),
          Text('Verschiebung: ${_offset.toStringAsFixed(2)}'),
          Slider(
            value: _offset,
            min: -0.95,
            max: 0.95,
            onChanged: (v) => setState(() => _offset = v),
          ),
          SwitchListTile(
            title: const Text("Rotation (Steiner's Porism)"),
            value: _animate,
            onChanged: (v) => setState(() => _animate = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Text(
            'Die Möbius-Transformation verzerrt den Raum so, dass die Kreise '
            'sich immer perfekt berühren.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Text('Live-Formel:', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          _buildFormula(),
        ],
      ),
    );
  }

  Widget _buildFormula() {
    final sinPiN = math.sin(math.pi / _n);
    final rIn = (1 - sinPiN) / (1 + sinPiN);
    final tex =
        r'\begin{aligned}'
        r'r_{\mathrm{in}} &= \dfrac{1 - \sin(\pi/n)}{1 + \sin(\pi/n)} \\[4pt]'
        r'&= \dfrac{1 - \sin(\pi/' '$_n' r')}{1 + \sin(\pi/' '$_n' r')} '
        r'\approx ' '${rIn.toStringAsFixed(4)}'
        r'\end{aligned}';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        tex,
        textStyle: const TextStyle(fontSize: 20),
        onErrorFallback: (err) => Text(
          'LaTeX-Fehler: ${err.message}',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return CustomPaint(
      painter: _SteinerPainter(n: _n, offset: _offset, rotation: _rotation),
      child: const SizedBox.expand(),
    );
  }
}

class _SteinerPainter extends CustomPainter {
  _SteinerPainter({
    required this.n,
    required this.offset,
    required this.rotation,
  });

  final int n;
  final double offset;
  final double rotation;

  /// f(z) = (z + a) / (1 + a·z) — Möbius-Automorphismus des Einheitskreises.
  Offset _moebius(double x, double y, Offset center, double radius) {
    final a = offset;
    final denRe = 1.0 + a * x;
    final denIm = a * y;
    final denSq = denRe * denRe + denIm * denIm;
    final resX = ((x + a) * denRe + y * denIm) / denSq;
    final resY = (y * denRe - (x + a) * denIm) / denSq;
    return Offset(center.dx + resX * radius, center.dy - resY * radius);
  }

  /// Zeichnet einen Kreis im Einheitskreis-Koordinatensystem als Polygon
  /// aus 64 möbiustransformierten Punkten.
  void _drawMappedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    double cx,
    double cy,
    double r,
    Paint stroke, {
    Paint? fill,
  }) {
    const steps = 64;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final px = cx + r * math.cos(angle);
      final py = cy + r * math.sin(angle);
      final p = _moebius(px, py, center, radius);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    if (fill != null) canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.45;

    final sinPiN = math.sin(math.pi / n);
    final rIn = (1 - sinPiN) / (1 + sinPiN);
    final rChain = (1 - rIn) / 2;
    final rMid = (1 + rIn) / 2;

    final bgStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF888888);
    final innerFill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF202020);
    _drawMappedCircle(canvas, center, radius, 0, 0, 1, bgStroke);
    _drawMappedCircle(canvas, center, radius, 0, 0, rIn, bgStroke,
        fill: innerFill);

    final chainStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFD479);
    final chainFill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x33000000);
    for (var i = 0; i < n; i++) {
      final theta = rotation + (i / n) * 2 * math.pi;
      final cx = rMid * math.cos(theta);
      final cy = rMid * math.sin(theta);
      _drawMappedCircle(canvas, center, radius, cx, cy, rChain, chainStroke,
          fill: chainFill);
    }
  }

  @override
  bool shouldRepaint(covariant _SteinerPainter old) {
    return old.n != n || old.offset != offset || old.rotation != rotation;
  }
}

/// Vollbildroute für die Theorie auf schmalen Layouts (Mobile).
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
