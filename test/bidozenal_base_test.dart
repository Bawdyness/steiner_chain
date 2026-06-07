// Tri-base behaviour of the calculator: the engine parses digit sequences in
// the active base, the physical keyboard rejects digits outside it, and the
// glyph keypad greys out (and disables) digits >= base. See
// docs/rechner-tribasis-audit-und-umbauplan.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geometrie_spielzeug/calc/evaluator.dart';
import 'package:geometrie_spielzeug/calc/input.dart';
import 'package:geometrie_spielzeug/calc/keyboard.dart';
import 'package:geometrie_spielzeug/calc/rational.dart';
import 'package:geometrie_spielzeug/tools/bidozenal/keypad.dart';

void main() {
  group('engine parses "10" in the active base', () {
    final ten = <Tok>[DigitTok(1), DigitTok(0)];
    test('base 10 → ten', () {
      expect(evaluate(ten, AngleMode.deg, base: 10).exact, Rational.fromInt(10));
    });
    test('base 12 → twelve', () {
      expect(evaluate(ten, AngleMode.deg, base: 12).exact, Rational.fromInt(12));
    });
    test('base 24 → twentyfour', () {
      expect(evaluate(ten, AngleMode.deg, base: 24).exact, Rational.fromInt(24));
    });
  });

  group('keyboard rejects digit characters outside the active base', () {
    int? digitOf(KeypadEvent? e) =>
        (e is InsertTok && e.tok is DigitTok) ? (e.tok as DigitTok).value : null;

    test("'9' is active in every base", () {
      expect(digitOf(charEvent('9', base: 10)), 9);
      expect(digitOf(charEvent('9', base: 12)), 9);
      expect(digitOf(charEvent('9', base: 24)), 9);
    });
    test("'A' (=10): inert in base 10, active in 12 and 24", () {
      expect(charEvent('A', base: 10), isNull);
      expect(digitOf(charEvent('A', base: 12)), 10);
      expect(digitOf(charEvent('A', base: 24)), 10);
    });
    test("'C' (=12): inert below base 24", () {
      expect(charEvent('C', base: 10), isNull);
      expect(charEvent('C', base: 12), isNull);
      expect(digitOf(charEvent('C', base: 24)), 12);
    });
    test('operators stay active regardless of base', () {
      expect(charEvent('+', base: 10), isA<InsertTok>());
      expect(charEvent('=', base: 10), isA<EqualsKey>());
    });
  });

  group('glyph keypad greys digits >= base', () {
    testWidgets('inactive digit is non-tappable, active digit fires', (
      tester,
    ) async {
      final taps = <int>[];
      void onKey(KeypadEvent e) {
        if (e is InsertTok && e.tok is DigitTok) {
          taps.add((e.tok as DigitTok).value);
        }
      }

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 600,
            child: BidozenalGlyphPad(base: 10, glyphMode: true, onKey: onKey),
          ),
        ),
      ));

      // 'A' (=10) is greyed/disabled in base 10 → tapping does nothing.
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(taps, isEmpty);

      // '5' is active → tapping inserts it.
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(taps, [5]);
    });
  });
}
