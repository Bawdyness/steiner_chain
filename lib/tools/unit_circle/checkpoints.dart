/// Standardwinkel auf dem Einheitskreis. Wenn der Zeiger einen Checkpoint
/// trifft (innerhalb der Snap-Toleranz), zeigt das Anzeige-Panel den
/// schönen Bruch und die Koordinaten als exakte Wurzelausdrücke.
class Checkpoint {
  const Checkpoint({
    required this.degrees,
    required this.texFraction,
    required this.texCoords,
  });

  /// Winkel in Grad, 0..360.
  final double degrees;

  /// Bogenmaß als hübscher LaTeX-Bruch — `\dfrac{\pi}{4}`, `\pi`, `\tau`,
  /// `0` etc.
  final String texFraction;

  /// Koordinatenpaar `(\cos, \sin)` als LaTeX. Bei den Standard-Winkeln
  /// als Wurzel-Bruch, sonst nicht relevant (kein Checkpoint).
  final String texCoords;
}

const List<Checkpoint> kCheckpoints = [
  Checkpoint(
    degrees: 0,
    texFraction: r'0',
    texCoords: r'\left(1,\,0\right)',
  ),
  Checkpoint(
    degrees: 30,
    texFraction: r'\dfrac{\pi}{6}',
    texCoords: r'\left(\dfrac{\sqrt{3}}{2},\,\dfrac{1}{2}\right)',
  ),
  Checkpoint(
    degrees: 45,
    texFraction: r'\dfrac{\pi}{4}',
    texCoords: r'\left(\dfrac{\sqrt{2}}{2},\,\dfrac{\sqrt{2}}{2}\right)',
  ),
  Checkpoint(
    degrees: 60,
    texFraction: r'\dfrac{\pi}{3}',
    texCoords: r'\left(\dfrac{1}{2},\,\dfrac{\sqrt{3}}{2}\right)',
  ),
  Checkpoint(
    degrees: 90,
    texFraction: r'\dfrac{\pi}{2}',
    texCoords: r'\left(0,\,1\right)',
  ),
  Checkpoint(
    degrees: 120,
    texFraction: r'\dfrac{2\pi}{3}',
    texCoords: r'\left(-\dfrac{1}{2},\,\dfrac{\sqrt{3}}{2}\right)',
  ),
  Checkpoint(
    degrees: 135,
    texFraction: r'\dfrac{3\pi}{4}',
    texCoords: r'\left(-\dfrac{\sqrt{2}}{2},\,\dfrac{\sqrt{2}}{2}\right)',
  ),
  Checkpoint(
    degrees: 150,
    texFraction: r'\dfrac{5\pi}{6}',
    texCoords: r'\left(-\dfrac{\sqrt{3}}{2},\,\dfrac{1}{2}\right)',
  ),
  Checkpoint(
    degrees: 180,
    texFraction: r'\pi',
    texCoords: r'\left(-1,\,0\right)',
  ),
  // Untere Hälfte: π/8-Familie (Viertelung statt Drittelung).
  Checkpoint(
    degrees: 202.5,
    texFraction: r'\dfrac{9\pi}{8}',
    texCoords:
        r'\left(-\dfrac{\sqrt{2+\sqrt{2}}}{2},\,-\dfrac{\sqrt{2-\sqrt{2}}}{2}\right)',
  ),
  Checkpoint(
    degrees: 225,
    texFraction: r'\dfrac{5\pi}{4}',
    texCoords: r'\left(-\dfrac{\sqrt{2}}{2},\,-\dfrac{\sqrt{2}}{2}\right)',
  ),
  Checkpoint(
    degrees: 247.5,
    texFraction: r'\dfrac{11\pi}{8}',
    texCoords:
        r'\left(-\dfrac{\sqrt{2-\sqrt{2}}}{2},\,-\dfrac{\sqrt{2+\sqrt{2}}}{2}\right)',
  ),
  Checkpoint(
    degrees: 270,
    texFraction: r'\dfrac{3\pi}{2}',
    texCoords: r'\left(0,\,-1\right)',
  ),
  Checkpoint(
    degrees: 292.5,
    texFraction: r'\dfrac{13\pi}{8}',
    texCoords:
        r'\left(\dfrac{\sqrt{2-\sqrt{2}}}{2},\,-\dfrac{\sqrt{2+\sqrt{2}}}{2}\right)',
  ),
  Checkpoint(
    degrees: 315,
    texFraction: r'\dfrac{7\pi}{4}',
    texCoords: r'\left(\dfrac{\sqrt{2}}{2},\,-\dfrac{\sqrt{2}}{2}\right)',
  ),
  Checkpoint(
    degrees: 337.5,
    texFraction: r'\dfrac{15\pi}{8}',
    texCoords:
        r'\left(\dfrac{\sqrt{2+\sqrt{2}}}{2},\,-\dfrac{\sqrt{2-\sqrt{2}}}{2}\right)',
  ),
  Checkpoint(
    degrees: 360,
    texFraction: r'\tau',
    texCoords: r'\left(1,\,0\right)',
  ),
];

/// Liefert den nahsten Checkpoint, falls innerhalb der Toleranz, sonst null.
Checkpoint? nearestCheckpoint(double degrees, {double toleranceDeg = 2.0}) {
  Checkpoint? best;
  double bestDiff = toleranceDeg;
  for (final cp in kCheckpoints) {
    final diff = (cp.degrees - degrees).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = cp;
    }
  }
  return best;
}
