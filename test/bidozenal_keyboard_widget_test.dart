import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geometrie_spielzeug/tools/bidozenal.dart';
import 'package:geometrie_spielzeug/widgets/tool_nav.dart';

/// Mounts BidozenalPage inside a minimal HubScope (the page returns a
/// ToolScaffold whose AppBar tool-bar + overflow menu read HubScope; with
/// empty entries the bar is simply empty).
Widget _host() => MaterialApp(
      home: HubScope(
        entries: const [],
        allEntries: const [],
        activeIndex: 0,
        onSelect: (_) {},
        disabledIds: const {},
        onToggleTool: (_, _) {},
        child: const BidozenalPage(),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('autofocus + bound keys are consumed, unbound keys pass through',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(); // let autofocus claim the keyboard
    await tester.pump();

    // Bound keys are handled by the calculator's Focus.onKeyEvent.
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.digit2), isTrue);
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.digit3), isTrue);
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd), isTrue);
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.backspace), isTrue);
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft), isTrue);

    // An unbound key is ignored (not consumed) so app shortcuts still work.
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.f5), isFalse);

    // No exception thrown while driving the calculator from the keyboard.
    expect(tester.takeException(), isNull);
  });
}
