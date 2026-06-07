// Drives the real app to the Kurve tool and checks the "Formen" figures: a
// chip shows the figure's parametric formula in the banner, exposes size
// sliders, and a live coordinate readout — and editing a size updates both the
// title (circle → ellipse) and the formula. Uses a tall surface so the controls
// ListView builds fully; pump() (not pumpAndSettle) because Kurve runs a
// permanent ticker.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geometrie_spielzeug/main.dart';

void main() {
  setUp(() {
    // Skip the intro overlay so it doesn't cover the tool.
    SharedPreferences.setMockInitialValues({'intro_seen_v2': true});
  });

  Future<void> openKurve(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GeometrieSpielzeugApp());
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Kurve').first);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('figure chip shows formula, sliders and a live point', (
    tester,
  ) async {
    await openKurve(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Kreis'));
    await tester.pump();

    // Banner: figure name + its parametric formula.
    expect(find.text('Form: Kreis'), findsOneWidget);
    expect(find.textContaining('cos t'), findsWidgets);
    // Editable magnitudes (Breite + Höhe) and the live coordinate rows.
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.textContaining('x ='), findsWidgets);
    expect(find.textContaining('y ='), findsWidgets);
  });

  testWidgets('shrinking one axis turns the circle into an ellipse', (
    tester,
  ) async {
    await openKurve(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Kreis'));
    await tester.pump();
    expect(find.text('Form: Kreis'), findsOneWidget);

    // Drag the second (Höhe) slider toward its minimum.
    await tester.drag(find.byType(Slider).at(1), const Offset(-400, 0));
    await tester.pump();

    // Title flips to Ellipse and the formula's y-coefficient is no longer 8.
    expect(find.text('Form: Ellipse'), findsOneWidget);
    expect(find.text('Form: Kreis'), findsNothing);
  });

  testWidgets('a polygon figure renders its polar formula', (tester) async {
    await openKurve(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Sechseck'));
    await tester.pump();

    expect(find.text('Form: Sechseck'), findsOneWidget);
    expect(find.textContaining('r(θ)'), findsWidgets);
    expect(find.byType(Slider), findsOneWidget); // size only
  });
}
