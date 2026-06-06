// Physical-keyboard input for the bidozenal calculator — the base-24 analogue
// of the dozenal calculator's _charKeyMap / _logicalKeyMap (lib/main.dart).
//
// Character keys carry the layout-aware symbols (Shift+1 = '!', etc.); logical
// keys cover the non-character keys (Enter, Backspace, arrows, numpad) and act
// as a fall-through where some Linux layouts leave `event.character` empty.
//
// One base-24 wrinkle: the digit letters are a-n (= 10..23), so the natural
// letters for sin/cos/… are taken by digits. Scientific functions therefore
// stay on the f(x) pad; the keyboard covers digits + arithmetic + the postfix
// "!" (factorial), which is the free, unambiguous one.

import 'package:flutter/services.dart';

import 'digits.dart';
import 'evaluator.dart';
import 'input.dart';

/// Maps a key event to a [KeypadEvent], or null if the key isn't bound.
///
/// [base] is the active number base (10/12/24): digit characters whose value is
/// >= base are inert, mirroring the greyed-out digits on the on-screen keypad.
KeypadEvent? eventForKey(KeyEvent event, {int base = kBase}) {
  final ch = event.character;
  if (ch != null && ch.isNotEmpty) {
    final e = charEvent(ch, base: base);
    if (e != null) return e;
  }
  return logicalEvent(event.logicalKey);
}

/// Character-based binding (digits 0-9 and a-n, operators, parens, '!', '=').
/// Digit characters with value >= [base] are rejected (return null).
KeypadEvent? charEvent(String ch, {int base = kBase}) {
  final v = bidozenalValue(ch); // '0'..'9','a'..'n','A'..'N' → 0..23
  if (v != null) return v < base ? InsertTok(DigitTok(v)) : null;
  switch (ch) {
    case '+':
      return const InsertTok(OpTok(BinOp.add));
    case '-':
      return const InsertTok(OpTok(BinOp.sub));
    case '*':
      return const InsertTok(OpTok(BinOp.mul));
    case '/':
      return const InsertTok(OpTok(BinOp.div));
    case '^':
      return const InsertTok(OpTok(BinOp.pow));
    case '%':
      return const InsertTok(OpTok(BinOp.mod));
    case '.':
    case ',': // German keyboards use ',' as the decimal separator.
      return const InsertTok(DotTok());
    case '(':
      return const InsertTok(LParenTok());
    case ')':
      return const InsertTok(RParenTok());
    case '!':
      return const InsertTok(FuncTok(FuncId.fact));
    case '=':
      return const EqualsKey();
  }
  return null;
}

/// Logical-key binding (Enter, Backspace, Esc, arrows, full numpad + digit
/// fall-throughs).
KeypadEvent? logicalEvent(LogicalKeyboardKey key) {
  final digit = _digitKeys[key];
  if (digit != null) return InsertTok(DigitTok(digit));
  switch (key) {
    case LogicalKeyboardKey.enter:
    case LogicalKeyboardKey.numpadEnter:
    case LogicalKeyboardKey.numpadEqual:
      return const EqualsKey();
    case LogicalKeyboardKey.backspace:
      return const DeleteKey();
    case LogicalKeyboardKey.escape:
      return const ClearKey();
    case LogicalKeyboardKey.arrowLeft:
      return const MoveLeft();
    case LogicalKeyboardKey.arrowRight:
      return const MoveRight();
    case LogicalKeyboardKey.numpadAdd:
      return const InsertTok(OpTok(BinOp.add));
    case LogicalKeyboardKey.numpadSubtract:
      return const InsertTok(OpTok(BinOp.sub));
    case LogicalKeyboardKey.numpadMultiply:
      return const InsertTok(OpTok(BinOp.mul));
    case LogicalKeyboardKey.numpadDivide:
      return const InsertTok(OpTok(BinOp.div));
    case LogicalKeyboardKey.numpadDecimal:
      return const InsertTok(DotTok());
  }
  return null;
}

/// Top-row + numpad digit keys → 0..9 (fall-through when `character` is empty).
final Map<LogicalKeyboardKey, int> _digitKeys = {
  LogicalKeyboardKey.digit0: 0, LogicalKeyboardKey.numpad0: 0,
  LogicalKeyboardKey.digit1: 1, LogicalKeyboardKey.numpad1: 1,
  LogicalKeyboardKey.digit2: 2, LogicalKeyboardKey.numpad2: 2,
  LogicalKeyboardKey.digit3: 3, LogicalKeyboardKey.numpad3: 3,
  LogicalKeyboardKey.digit4: 4, LogicalKeyboardKey.numpad4: 4,
  LogicalKeyboardKey.digit5: 5, LogicalKeyboardKey.numpad5: 5,
  LogicalKeyboardKey.digit6: 6, LogicalKeyboardKey.numpad6: 6,
  LogicalKeyboardKey.digit7: 7, LogicalKeyboardKey.numpad7: 7,
  LogicalKeyboardKey.digit8: 8, LogicalKeyboardKey.numpad8: 8,
  LogicalKeyboardKey.digit9: 9, LogicalKeyboardKey.numpad9: 9,
};
