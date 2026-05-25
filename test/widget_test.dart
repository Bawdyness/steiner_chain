import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geometrie_spielzeug/main.dart';

void main() {
  setUp(() {
    // Hub liest beim Start aus SharedPreferences. Ohne Mock-Init blockiert
    // der Plattform-Channel.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App startet und zeigt Steiner-Tool', (WidgetTester tester) async {
    await tester.pumpWidget(const GeometrieSpielzeugApp());
    // Ein Pump um die Microtask-Queue (SharedPreferences-Future) zu leeren.
    await tester.pump();
    // Ein weiterer Pump für den Frame nach setState. `pumpAndSettle` geht
    // hier nicht, weil Steiner einen permanent laufenden Ticker hat.
    await tester.pump();
    expect(find.text('Steiner-Kette'), findsWidgets);
  });
}
