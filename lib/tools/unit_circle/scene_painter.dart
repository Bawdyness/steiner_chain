import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'checkpoints.dart';

/// Wie sich Welle und Marker zueinander verhalten.
enum WaveMode {
  /// Welle steht, Marker bewegt sich entlang ihrer Parameter-Achse.
  markerOnWave,
  /// Marker bleibt fest am Anfang der Welle, Welle scrollt durch.
  waveOnMarker,
}

/// Geteilte Geometrie für Kreis und Welle. Im Wide-Layout liegt die Welle
/// rechts und plottet `sin(θ)` horizontal; im Narrow-Layout liegt sie
/// unten und plottet `cos(θ)` vertikal — dadurch sind die Verbindungs-
/// Linien je nach Layout horizontal bzw. vertikal.
class SceneLayout {
  SceneLayout({
    required this.canvasSize,
    required this.wide,
    required this.circleCenter,
    required this.circleRadius,
    required this.waveOrigin,
    required this.waveLength,
  });

  final Size canvasSize;
  final bool wide;

  final Offset circleCenter;
  final double circleRadius;

  /// Position der (θ=0, Wert=0)-Referenz auf der Welle.
  /// Wide: linker Rand des Plots, vertikal mittig.
  /// Narrow: horizontal zentriert mit dem Kreis, oberer Rand.
  final Offset waveOrigin;

  /// Pixel-Länge der θ-Achse (Wide: horizontal, Narrow: vertikal).
  final double waveLength;

  /// Amplitude in Pixeln — entspricht per Konstruktion `circleRadius`,
  /// damit Wert-1 auf der Welle exakt auf der Kreis-Außenseite liegt.
  double get waveAmplitude => circleRadius;

  Offset circleAt(double angleRad) => Offset(
        circleCenter.dx + circleRadius * math.cos(angleRad),
        circleCenter.dy - circleRadius * math.sin(angleRad),
      );

  /// Konvertiert eine Cursor-Position in einen Winkel relativ zum
  /// Kreis-Mittelpunkt.
  double cursorAngleDegrees(Offset local) {
    final dx = local.dx - circleCenter.dx;
    final dy = circleCenter.dy - local.dy;
    var deg = math.atan2(dy, dx) * 180 / math.pi;
    if (deg < 0) deg += 360;
    return deg;
  }

  bool isInsideCircleArea(Offset local) {
    if (!wide) {
      return local.dy < canvasSize.height * 5 / 8;
    }
    return local.dx < canvasSize.width * 5 / 9;
  }

  static SceneLayout compute(Size size) {
    final wide = size.width >= size.height;
    const innerPad = 16.0;
    const labelPad = 28.0;
    const wavePadOuter = 30.0;
    const wavePadInner = 24.0;

    if (wide) {
      final circleAreaW = size.width * 5 / 9;
      final circleAreaSize = math.min(
        circleAreaW - 2 * innerPad,
        size.height - 2 * innerPad,
      );
      final circleCenter = Offset(
        innerPad + circleAreaSize / 2,
        size.height / 2,
      );
      final circleRadius = circleAreaSize / 2 - labelPad;
      final waveAreaLeft = circleAreaW;
      final waveOriginX = waveAreaLeft + wavePadInner;
      final waveOriginY = circleCenter.dy;
      final waveLength = size.width - waveAreaLeft - wavePadInner - wavePadOuter;
      return SceneLayout(
        canvasSize: size,
        wide: true,
        circleCenter: circleCenter,
        circleRadius: circleRadius,
        waveOrigin: Offset(waveOriginX, waveOriginY),
        waveLength: waveLength,
      );
    }

    // Narrow: Kreis oben (so kompakt wie möglich), Welle direkt darunter.
    // Damit die senkrechten Verbindungs-Linien geometrisch sauber sind,
    // muss die Wellenamplitude gleich dem Kreisradius sein. Der Kreis
    // wird so groß wie möglich — beschränkt entweder durch die Breite
    // oder durch maximal ~55 % der Höhe (damit der Welle genug Platz
    // bleibt). Die Welle wird *immer* direkt unterhalb des Kreises
    // angedockt, egal wie schmal die Box wird.
    final maxRadiusByWidth = (size.width - 2 * innerPad) / 2 - labelPad;
    final maxRadiusByHeight = (size.height * 0.55 - 2 * innerPad) / 2 - labelPad;
    final circleRadius = math.min(maxRadiusByWidth, maxRadiusByHeight);
    final circleCenter = Offset(
      size.width / 2,
      innerPad + circleRadius + labelPad,
    );
    final circleBottom = circleCenter.dy + circleRadius + labelPad;

    final waveOriginY = circleBottom + wavePadInner;
    final waveLength = size.height - waveOriginY - wavePadOuter;
    return SceneLayout(
      canvasSize: size,
      wide: false,
      circleCenter: circleCenter,
      circleRadius: circleRadius,
      waveOrigin: Offset(size.width / 2, waveOriginY),
      waveLength: waveLength,
    );
  }
}

/// Sichtbarer θ-Bereich auf der Welle. Etwas mehr als ein voller Umlauf,
/// damit die Welle nach τ visuell weiterläuft. Marker und Anker-Endpunkte
/// bleiben aber bei θ = 2π modulo-gewrappt — der Marker springt dann
/// zurück zum Ursprung statt aus dem Plot zu wandern.
const double _waveDisplayRange = 2.5 * math.pi;

/// Anker-Winkel für die Verbindungs-Linien im Wide-Layout (Sinus-Welle).
/// Obere Hälfte: π/6-Familie (Drittelung) — auch 45°/135° als π/4-Brüder.
/// Untere Hälfte: π/8-Familie (Viertelung).
const List<double> _referenceAnglesWide = [
  30, 45, 60, 90, 120, 135, 150,
  202.5, 225, 247.5, 270, 292.5, 315, 337.5,
];

/// Anker-Winkel für das Narrow-Layout (Cosinus-Welle, vertikale
/// Verbindungs-Linien). Rechte Hälfte (cos > 0): π/6-Familie + π/4.
/// Linke Hälfte (cos < 0): π/8-Familie. 90° und 270° entfallen, weil
/// dort cos = 0 — die Linie hätte keine horizontale Auslenkung.
const List<double> _referenceAnglesNarrow = [
  0, 30, 45, 60, 300, 315, 330, 360,
  112.5, 135, 157.5, 180, 202.5, 225, 247.5,
];

class UnitCircleScenePainter extends CustomPainter {
  UnitCircleScenePainter({
    required this.angleDegrees,
    required this.snapped,
    required this.colorScheme,
    required this.textStyle,
    required this.waveMode,
  });

  final double angleDegrees;
  final Checkpoint? snapped;
  final ColorScheme colorScheme;
  final TextStyle textStyle;
  final WaveMode waveMode;

  /// Farbe für sin-bezogene Elemente (vertikale Achse des Kreises,
  /// Sinus-Welle im Wide-Layout).
  Color get _sineColor => colorScheme.tertiary;

  /// Farbe für cos-bezogene Elemente (horizontale Achse des Kreises,
  /// Cosinus-Welle im Narrow-Layout).
  Color get _cosineColor => colorScheme.secondary;

  /// Farbe der aktuell dargestellten Welle und ihrer Marker/Linien.
  Color _waveColor(SceneLayout l) => l.wide ? _sineColor : _cosineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = SceneLayout.compute(size);

    _drawReferenceConnections(canvas, layout);
    _drawWaveAxes(canvas, layout);
    _drawWaveCurves(canvas, layout);
    _drawCirclePizzaSlices(canvas, layout);
    _drawCircleOuter(canvas, layout);
    _drawCircleInnerLabels(canvas, layout);
    _drawCircleCheckpointDots(canvas, layout);
    _drawActiveConnection(canvas, layout);
    _drawWaveMarker(canvas, layout);
    _drawPointer(canvas, layout);
  }

  // ---------------------------------------------------------------------
  // Geometrie-Helfer: liefern die Canvas-Position eines θ-Werts auf der
  // Welle, je nach Layout (sinus-horizontal vs. cosinus-vertikal).
  //
  // Die Funktionen sind absichtlich getrennt, weil sie unterschiedlich
  // wrappen müssen:
  // - `_curvePosition`: für die durchgezogene Welle. Kein Wrap, weil θ
  //   im sichtbaren Bereich [0, _waveDisplayRange] gesampelt wird.
  // - `_referenceWaveEnd`: für statische Anker-Endpunkte und Tick-Labels.
  //   Modulo 2π, damit periodische Äquivalente in der ersten Umrundung
  //   landen.
  // - `_activeWavePoint`: für den aktiven Marker. Modulo 2π, sodass er
  //   bei jeder vollen Umdrehung zum Ursprung zurückspringt statt aus
  //   dem Bild zu wandern.
  // ---------------------------------------------------------------------

  Offset _placeOnWave(SceneLayout l, double t, double angleForValue) {
    if (l.wide) {
      return Offset(
        l.waveOrigin.dx + t * l.waveLength,
        l.waveOrigin.dy - math.sin(angleForValue) * l.waveAmplitude,
      );
    }
    return Offset(
      l.waveOrigin.dx + math.cos(angleForValue) * l.waveAmplitude,
      l.waveOrigin.dy + t * l.waveLength,
    );
  }

  Offset _curvePosition(SceneLayout l, double angleRad) {
    final delta = waveMode == WaveMode.waveOnMarker
        ? angleRad - angleDegrees * math.pi / 180
        : angleRad;
    return _placeOnWave(l, delta / _waveDisplayRange, angleRad);
  }

  Offset _referenceWaveEnd(SceneLayout l, double angleRad) {
    double offset;
    if (waveMode == WaveMode.waveOnMarker) {
      offset = angleRad - angleDegrees * math.pi / 180;
      offset = offset % (2 * math.pi);
      if (offset < 0) offset += 2 * math.pi;
    } else {
      offset = angleRad % (2 * math.pi);
      if (offset < 0) offset += 2 * math.pi;
    }
    return _placeOnWave(l, offset / _waveDisplayRange, angleRad);
  }

  /// Position des aktiven Markers — im `waveOnMarker`-Modus am Anfang
  /// der Welle, sonst auf der θ-Achse modulo 2π. Wenn θ über 2π hinaus
  /// geht, springt der Marker zurück zum Ursprung statt sich aus dem
  /// Plot herauszuschieben.
  Offset _activeWavePoint(SceneLayout l) {
    final theta = angleDegrees * math.pi / 180;
    if (waveMode == WaveMode.waveOnMarker) {
      if (l.wide) {
        return Offset(
          l.waveOrigin.dx,
          l.waveOrigin.dy - math.sin(theta) * l.waveAmplitude,
        );
      }
      return Offset(
        l.waveOrigin.dx + math.cos(theta) * l.waveAmplitude,
        l.waveOrigin.dy,
      );
    }
    var wrapped = theta % (2 * math.pi);
    if (wrapped < 0) wrapped += 2 * math.pi;
    return _placeOnWave(l, wrapped / _waveDisplayRange, theta);
  }

  // ---------------------------------------------------------------------
  // Referenz-Verbindungen: pro Anker-Winkel eine Linie vom Kreis-Punkt
  // zur Welle-Position. Im Wide-Layout horizontal (gleiches y), im
  // Narrow-Layout vertikal (gleiches x).
  // ---------------------------------------------------------------------
  void _drawReferenceConnections(Canvas canvas, SceneLayout l) {
    final anchors = l.wide ? _referenceAnglesWide : _referenceAnglesNarrow;
    final color = _waveColor(l);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = color.withValues(alpha: 0.35);
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.5);

    for (final deg in anchors) {
      final rad = deg * math.pi / 180;
      final start = l.circleAt(rad);
      final end = _referenceWaveEnd(l, rad);
      canvas.drawLine(start, end, line);
      canvas.drawCircle(end, 2.5, dot);
    }
  }

  // ---------------------------------------------------------------------
  // Aktive Verbindung: vom Zeiger-Tip zum aktuellen Wellen-Marker.
  // ---------------------------------------------------------------------
  void _drawActiveConnection(Canvas canvas, SceneLayout l) {
    final theta = angleDegrees * math.pi / 180;
    final tip = l.circleAt(theta);
    final wavePoint = _activeWavePoint(l);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _waveColor(l).withValues(alpha: 0.6);
    canvas.drawLine(tip, wavePoint, paint);
  }

  // ---------------------------------------------------------------------
  // Welle: Achsen, Tick-Beschriftungen, Referenzkurve und aktive Kurve.
  // ---------------------------------------------------------------------
  void _drawWaveAxes(Canvas canvas, SceneLayout l) {
    final color = _waveColor(l);
    final axis = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color.withValues(alpha: 0.7);
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color.withValues(alpha: 0.6);
    final labelStyle = textStyle.copyWith(color: color);

    if (l.wide) {
      // X-Achse (θ-Achse, horizontal) — bis zum Plot-Ende, d.h. _waveDisplayRange
      canvas.drawLine(
        l.waveOrigin,
        Offset(l.waveOrigin.dx + l.waveLength, l.waveOrigin.dy),
        axis,
      );
      // Y-Achse (Wert-Achse, vertikal)
      canvas.drawLine(
        Offset(l.waveOrigin.dx, l.waveOrigin.dy - l.waveAmplitude),
        Offset(l.waveOrigin.dx, l.waveOrigin.dy + l.waveAmplitude),
        axis,
      );
      _waveTickLabels(canvas, l, tick, labelStyle);
      return;
    }

    // Narrow: θ-Achse vertikal, Wert-Achse horizontal.
    canvas.drawLine(
      l.waveOrigin,
      Offset(l.waveOrigin.dx, l.waveOrigin.dy + l.waveLength),
      axis,
    );
    canvas.drawLine(
      Offset(l.waveOrigin.dx - l.waveAmplitude, l.waveOrigin.dy),
      Offset(l.waveOrigin.dx + l.waveAmplitude, l.waveOrigin.dy),
      axis,
    );
    _waveTickLabels(canvas, l, tick, labelStyle);
  }

  void _waveTickLabels(
    Canvas canvas,
    SceneLayout l,
    Paint tick,
    TextStyle style,
  ) {
    final paramTicks = <(double, String)>[
      (math.pi / 2, 'π/2'),
      (math.pi, 'π'),
      (3 * math.pi / 2, '3π/2'),
      (2 * math.pi, 'τ'),
    ];

    if (l.wide) {
      for (final (theta, label) in paramTicks) {
        final pos = _referenceWaveEnd(l, theta);
        canvas.drawLine(
          Offset(pos.dx, l.waveOrigin.dy - 4),
          Offset(pos.dx, l.waveOrigin.dy + 4),
          tick,
        );
        _paintLabel(
          canvas,
          label,
          Offset(pos.dx, l.waveOrigin.dy + 16),
          Alignment.center,
          style,
        );
      }
      for (final (v, label) in <(double, String)>[(1, '1'), (-1, '−1')]) {
        final y = l.waveOrigin.dy - v * l.waveAmplitude;
        canvas.drawLine(
          Offset(l.waveOrigin.dx - 4, y),
          Offset(l.waveOrigin.dx + 4, y),
          tick,
        );
        _paintLabel(
          canvas,
          label,
          Offset(l.waveOrigin.dx - 8, y),
          Alignment.centerRight,
          style,
        );
      }
      return;
    }

    // Narrow: θ-Ticks an der vertikalen Achse, Wert-Ticks horizontal.
    for (final (theta, label) in paramTicks) {
      final pos = _referenceWaveEnd(l, theta);
      canvas.drawLine(
        Offset(l.waveOrigin.dx - 4, pos.dy),
        Offset(l.waveOrigin.dx + 4, pos.dy),
        tick,
      );
      _paintLabel(
        canvas,
        label,
        Offset(l.waveOrigin.dx + 10, pos.dy),
        Alignment.centerLeft,
        style,
      );
    }
    for (final (v, label) in <(double, String)>[(1, '1'), (-1, '−1')]) {
      final x = l.waveOrigin.dx + v * l.waveAmplitude;
      canvas.drawLine(
        Offset(x, l.waveOrigin.dy - 4),
        Offset(x, l.waveOrigin.dy + 4),
        tick,
      );
      _paintLabel(
        canvas,
        label,
        Offset(x, l.waveOrigin.dy - 8),
        Alignment.bottomCenter,
        style,
      );
    }
  }

  void _drawWaveCurves(Canvas canvas, SceneLayout l) {
    final color = _waveColor(l);

    if (waveMode == WaveMode.waveOnMarker) {
      final theta = angleDegrees * math.pi / 180;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.85);
      canvas.drawPath(_curvePath(l, theta, theta + _waveDisplayRange), paint);
      return;
    }

    // markerOnWave: blasse Referenzkurve plus wachsendes Akzent-Segment.
    final reference = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: 0.4);
    canvas.drawPath(_curvePath(l, 0, _waveDisplayRange), reference);

    final theta = angleDegrees * math.pi / 180;
    final upTo = theta >= 2 * math.pi
        ? 2 * math.pi
        : (theta < 0 ? 0.0 : theta);
    if (upTo > 0.001) {
      final active = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawPath(_curvePath(l, 0, upTo), active);
    }
  }

  Path _curvePath(SceneLayout l, double from, double to) {
    const samples = 320;
    final path = Path();
    for (var i = 0; i <= samples; i++) {
      final theta = from + (to - from) * (i / samples);
      final p = _curvePosition(l, theta);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  void _drawWaveMarker(Canvas canvas, SceneLayout l) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = _waveColor(l);
    canvas.drawCircle(_activeWavePoint(l), 5, fill);
  }

  // ---------------------------------------------------------------------
  // Kreis: Pizzaschnitte, Außenkreis, Innenbeschriftung, Checkpoint-Dots,
  // Zeiger.
  // ---------------------------------------------------------------------
  void _drawCirclePizzaSlices(Canvas canvas, SceneLayout l) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = colorScheme.outline.withValues(alpha: 0.4);

    if (l.wide) {
      // Obere Hälfte: 6 Schnitte (alle 30°), untere: 8 Schnitte (alle 22.5°).
      for (var i = 1; i < 6; i++) {
        canvas.drawLine(l.circleCenter, _atDeg(l, i * 30.0), paint);
      }
      for (var i = 1; i < 8; i++) {
        canvas.drawLine(l.circleCenter, _atDeg(l, 180 + i * 22.5), paint);
      }
      // Trenner Ober/Unter
      canvas.drawLine(_atDeg(l, 0), _atDeg(l, 180), paint);
      return;
    }

    // Narrow: rechte Hälfte 6 Schnitte (alle 30°), linke 8 (alle 22.5°).
    // Rechte Hälfte geht von 270° über 0°/360° bis 90°.
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(l.circleCenter, _atDeg(l, 270.0 + i * 30.0), paint);
    }
    for (var i = 1; i < 8; i++) {
      canvas.drawLine(l.circleCenter, _atDeg(l, 90 + i * 22.5), paint);
    }
    // Trenner Rechts/Links (vertikale Achse)
    canvas.drawLine(_atDeg(l, 90), _atDeg(l, 270), paint);
  }

  Offset _atDeg(SceneLayout l, double deg) =>
      l.circleAt(deg * math.pi / 180);

  void _drawCircleOuter(Canvas canvas, SceneLayout l) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = colorScheme.outline;
    canvas.drawCircle(l.circleCenter, l.circleRadius, paint);
  }

  /// Innen-Labels mit semantischer Färbung: 0°/180° (x-Achse) =
  /// Cosinus-Farbe, 90°/270° (y-Achse) = Sinus-Farbe. Damit sieht der
  /// Nutzer auf einen Blick, welche Achse welcher Funktion entspricht.
  void _drawCircleInnerLabels(Canvas canvas, SceneLayout l) {
    final labelOffset = l.circleRadius - 22;
    final labels = <(double, String, Alignment, Color)>[
      (0, '0°', Alignment.centerRight, _cosineColor),
      (90, '90°', Alignment.topCenter, _sineColor),
      (180, '180°', Alignment.centerLeft, _cosineColor),
      (270, '270°', Alignment.bottomCenter, _sineColor),
    ];
    for (final (deg, text, align, color) in labels) {
      final rad = deg * math.pi / 180;
      final pos = Offset(
        l.circleCenter.dx + labelOffset * math.cos(rad),
        l.circleCenter.dy - labelOffset * math.sin(rad),
      );
      _paintLabel(
        canvas,
        text,
        pos,
        align,
        textStyle.copyWith(color: color, fontWeight: FontWeight.w500),
      );
    }
  }

  void _drawCircleCheckpointDots(Canvas canvas, SceneLayout l) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.outline.withValues(alpha: 0.6);
    final anchors = l.wide ? _referenceAnglesWide : _referenceAnglesNarrow;
    final visible = <double>{...anchors, 0, 90, 180, 270};
    for (final deg in visible) {
      if (deg == 360) continue;
      canvas.drawCircle(_atDeg(l, deg), 3, paint);
    }
  }

  void _drawPointer(Canvas canvas, SceneLayout l) {
    final tip = _atDeg(l, angleDegrees);
    final accent = colorScheme.tertiary;
    final shaft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawLine(l.circleCenter, tip, shaft);

    _drawRadiusLabel(canvas, l);

    if (snapped != null) {
      final halo = Paint()
        ..style = PaintingStyle.fill
        ..color = accent.withValues(alpha: 0.25);
      canvas.drawCircle(tip, 14, halo);
    }
    final knob = Paint()
      ..style = PaintingStyle.fill
      ..color = accent;
    canvas.drawCircle(tip, 8, knob);

    final centerDot = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.onSurface.withValues(alpha: 0.6);
    canvas.drawCircle(l.circleCenter, 3, centerDot);
  }

  void _drawRadiusLabel(Canvas canvas, SceneLayout l) {
    final rad = angleDegrees * math.pi / 180;
    final midX = l.circleCenter.dx + (l.circleRadius / 2) * math.cos(rad);
    final midY = l.circleCenter.dy - (l.circleRadius / 2) * math.sin(rad);
    const offsetDist = 14.0;
    final lblX = midX - offsetDist * math.sin(rad);
    final lblY = midY - offsetDist * math.cos(rad);

    final tp = TextPainter(
      text: TextSpan(
        text: 'r = 1',
        style: textStyle.copyWith(
          color: colorScheme.tertiary,
          fontSize: (textStyle.fontSize ?? 14) - 1,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(lblX - tp.width / 2, lblY - tp.height / 2));
  }

  // ---------------------------------------------------------------------
  void _paintLabel(
    Canvas canvas,
    String text,
    Offset anchor,
    Alignment align,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = anchor.dx - tp.width * (align.x + 1) / 2;
    final dy = anchor.dy - tp.height * (align.y + 1) / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant UnitCircleScenePainter old) =>
      old.angleDegrees != angleDegrees ||
      old.snapped != snapped ||
      old.colorScheme != colorScheme ||
      old.waveMode != waveMode;
}
