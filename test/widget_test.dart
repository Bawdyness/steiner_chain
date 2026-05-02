import 'package:flutter_test/flutter_test.dart';

import 'package:geometrie_spielzeug/main.dart';

void main() {
  testWidgets('App startet und zeigt Steiner-Tool', (WidgetTester tester) async {
    await tester.pumpWidget(const GeometrieSpielzeugApp());
    expect(find.text('Steiner-Kette'), findsWidgets);
  });
}
