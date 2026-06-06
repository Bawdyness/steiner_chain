// Shared keypad infrastructure (lib/calc/keypad.dart + the inverse-swap helpers
// in lib/calc/input.dart): the calculator and the curve plotter draw from one
// definition. See docs/rechner-tribasis-audit-und-umbauplan.md (Phase 3).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/input.dart';
import 'package:geometrie_spielzeug/calc/keypad.dart';
import 'package:geometrie_spielzeug/tools/kurve/keypad.dart';

FuncId? _funcOf(KeypadEvent e) =>
    (e is InsertTok && e.tok is FuncTok) ? (e.tok as FuncTok).id : null;
BinOp? _opOf(KeypadEvent e) =>
    (e is InsertTok && e.tok is OpTok) ? (e.tok as OpTok).op : null;

void main() {
  group('inverse-swap helpers (shared by calculator + plotter)', () {
    test('arms when the previous token is the function or its inverse', () {
      expect(isInverseArmed([FuncTok(FuncId.sin)], 1, FuncId.sin), isTrue);
      expect(isInverseArmed([FuncTok(FuncId.asin)], 1, FuncId.sin), isTrue);
      expect(isInverseArmed([DigitTok(3)], 1, FuncId.sin), isFalse);
      expect(isInverseArmed(const [], 0, FuncId.sin), isFalse);
      // fact has no inverse → never arms.
      expect(isInverseArmed([FuncTok(FuncId.fact)], 1, FuncId.fact), isFalse);
    });

    test('toggles to the inverse and back, else null', () {
      final fwd = toggledInverse([FuncTok(FuncId.sin)], 1, FuncId.sin);
      expect((fwd!.single as FuncTok).id, FuncId.asin);
      final back = toggledInverse([FuncTok(FuncId.asin)], 1, FuncId.sin);
      expect((back!.single as FuncTok).id, FuncId.sin);
      expect(toggledInverse([DigitTok(3)], 1, FuncId.sin), isNull);
      expect(toggledInverse(const [], 0, FuncId.sin), isNull);
    });
  });

  group('ScientificKeypad emits the tapped key', () {
    testWidgets('functions, operators and constants', (tester) async {
      final events = <KeypadEvent>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 320,
            child: ScientificKeypad(
              onKey: events.add,
              isArmed: (_) => false,
              rowHeight: 44,
            ),
          ),
        ),
      ));

      Future<void> tap(String t) async {
        await tester.tap(find.text(t));
        await tester.pump();
      }

      await tap('sin');
      await tap('√');
      await tap('mod');
      await tap('n!');
      await tap('π');

      expect(_funcOf(events[0]), FuncId.sin);
      expect(_funcOf(events[1]), FuncId.sqrt);
      expect(_opOf(events[2]), BinOp.mod);
      expect(_funcOf(events[3]), FuncId.fact);
      expect((events[4] as InsertTok).tok, isA<ConstTok>());
    });
  });

  group('Kurve keypad now offers the full shared function set', () {
    testWidgets('exposes the advanced keys and emits them', (tester) async {
      final events = <KeypadEvent>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 760,
            child: SingleChildScrollView(
              child: KurveKeypad(onKey: events.add, isArmed: (_) => false),
            ),
          ),
        ),
      ));

      // These were absent from the old hand-rolled Kurve keypad.
      for (final label in const ['sinh', 'coth', 'cot', 'mod', '√']) {
        expect(find.text(label), findsOneWidget, reason: 'missing "$label"');
      }

      await tester.tap(find.text('cos'));
      await tester.pump();
      expect(_funcOf(events.single), FuncId.cos);
    });
  });
}
