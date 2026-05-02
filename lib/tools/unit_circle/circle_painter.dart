import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'checkpoints.dart';

/// Zeichnet den Einheitskreis mit Pizzaschnitten, Innenbeschriftung,
/// Checkpoint-Markierungen und dem beweglichen Zeiger.
class UnitCirclePainter extends CustomPainter {
  UnitCirclePainter({
    required this.angleDegrees,
    required this.snapped,
    required this.colorScheme,
    required this.textStyle,
  });

  /// Aktueller Zeigerwinkel in Grad, mathematisches System
  /// (0° rechts, gegen den Uhrzeigersinn).
  final double angleDegrees;

  /// Wenn nicht null: aktuell eingerasteter Checkpoint.
  final Checkpoint? snapped;

  final ColorScheme colorScheme;
  final TextStyle textStyle;

  static const double _outerStroke = 2.0;
  static const double _sliceStroke = 0.8;
  static const double _pointerStroke = 2.5;
  static const double _checkpointDotRadius = 3.0;
  static const double _knobRadius = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Platz für Innenbeschriftung lassen
    final radius = math.min(size.width, size.height) / 2 - 28;

    _drawSlices(canvas, center, radius);
    _drawOuterCircle(canvas, center, radius);
    _drawInnerLabels(canvas, center, radius);
    _drawCheckpointDots(canvas, center, radius);
    _drawPointer(canvas, center, radius);
  }

  /// Konvertiert Math-Winkel (Grad, gegen Uhrzeigersinn, 0° rechts) in
  /// Canvas-Winkel (Bogenmaß, im Uhrzeigersinn, 0° rechts) — bei Flutter
  /// wächst Y nach unten, deshalb negieren wir den Sinus.
  Offset _pointAt(Offset center, double radius, double mathDegrees) {
    final rad = mathDegrees * math.pi / 180;
    return Offset(
      center.dx + radius * math.cos(rad),
      center.dy - radius * math.sin(rad),
    );
  }

  void _drawSlices(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sliceStroke
      ..color = colorScheme.outline.withValues(alpha: 0.4);

    // Obere Halbkreis-Pizza: 6 Schnitte → 30°-Schritte zwischen 0° und 180°.
    for (var i = 1; i < 6; i++) {
      final deg = i * 30.0;
      canvas.drawLine(center, _pointAt(center, radius, deg), paint);
    }
    // Untere Halbkreis-Pizza: 8 Schnitte → 22.5°-Schritte zwischen 180° und 360°.
    for (var i = 1; i < 8; i++) {
      final deg = 180 + i * 22.5;
      canvas.drawLine(center, _pointAt(center, radius, deg), paint);
    }
    // Horizontaler Trenner (0° / 180°-Achse)
    canvas.drawLine(
      _pointAt(center, radius, 0),
      _pointAt(center, radius, 180),
      paint,
    );
  }

  void _drawOuterCircle(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _outerStroke
      ..color = colorScheme.outline;
    canvas.drawCircle(center, radius, paint);
  }

  void _drawInnerLabels(Canvas canvas, Offset center, double radius) {
    final labelOffset = radius - 22;
    final labels = <(double, String, Alignment)>[
      (0, '0°', Alignment.centerRight),
      (90, '90°', Alignment.topCenter),
      (180, '180°', Alignment.centerLeft),
      (270, '270°', Alignment.bottomCenter),
    ];
    for (final (deg, text, align) in labels) {
      final pos = _pointAt(center, labelOffset, deg);
      _paintText(canvas, text, pos, align);
    }
  }

  void _paintText(Canvas canvas, String text, Offset anchor, Alignment align) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final size = tp.size;
    // Anchor ist die Position am Kreis, Alignment beschreibt, welcher Rand
    // des Textes daran festgemacht wird.
    final dx = anchor.dx - size.width * (align.x + 1) / 2;
    final dy = anchor.dy - size.height * (align.y + 1) / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  void _drawCheckpointDots(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.outline.withValues(alpha: 0.6);
    for (final cp in kCheckpoints) {
      // 0° und 360° überlappen visuell — einen weglassen.
      if (cp.degrees == 360) continue;
      final p = _pointAt(center, radius, cp.degrees);
      canvas.drawCircle(p, _checkpointDotRadius, paint);
    }
  }

  void _drawPointer(Canvas canvas, Offset center, double radius) {
    final tip = _pointAt(center, radius, angleDegrees);
    final accent = colorScheme.tertiary;
    final shaft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _pointerStroke
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawLine(center, tip, shaft);

    _drawRadiusLabel(canvas, center, radius);

    // Knopf am Zeigerende — größer, mit Highlight bei Snap.
    if (snapped != null) {
      final halo = Paint()
        ..style = PaintingStyle.fill
        ..color = accent.withValues(alpha: 0.25);
      canvas.drawCircle(tip, _knobRadius + 6, halo);
    }
    final knob = Paint()
      ..style = PaintingStyle.fill
      ..color = accent;
    canvas.drawCircle(tip, _knobRadius, knob);

    // Mittelpunkt
    final centerDot = Paint()
      ..style = PaintingStyle.fill
      ..color = colorScheme.onSurface.withValues(alpha: 0.6);
    canvas.drawCircle(center, 3, centerDot);
  }

  /// Zeichnet die "r = 1"-Beschriftung auf der Höhe des Zeigers, leicht
  /// senkrecht zur Linie versetzt damit der Strich frei bleibt. Die
  /// Position bewegt sich mit dem Zeiger; die Beschriftung selbst bleibt
  /// horizontal lesbar.
  void _drawRadiusLabel(Canvas canvas, Offset center, double radius) {
    final rad = angleDegrees * math.pi / 180;
    // Mittelpunkt des Zeigerstrichs
    final midX = center.dx + (radius / 2) * math.cos(rad);
    final midY = center.dy - (radius / 2) * math.sin(rad);
    // Senkrechter Versatz (mathematisch „links" der Bewegungsrichtung,
    // damit der Text konsistent auf einer Seite des Strichs sitzt).
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

  @override
  bool shouldRepaint(covariant UnitCirclePainter old) =>
      old.angleDegrees != angleDegrees ||
      old.snapped != snapped ||
      old.colorScheme != colorScheme;
}
