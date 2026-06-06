// Shared keypad-event model for calculator-style tools (the bidozenal
// calculator and the curve plotter). What a key press asks the page to do.
// Lives in lib/calc/ so tools and the keyboard mapper share one definition.
// (Named `KeypadEvent` to avoid the clash with Flutter's hardware `KeyEvent`.)

import 'evaluator.dart';

sealed class KeypadEvent {
  const KeypadEvent();
}

class InsertTok extends KeypadEvent {
  const InsertTok(this.tok);
  final Tok tok;
}

class EqualsKey extends KeypadEvent {
  const EqualsKey();
}

class ClearKey extends KeypadEvent {
  const ClearKey();
}

class DeleteKey extends KeypadEvent {
  const DeleteKey();
}

class MoveLeft extends KeypadEvent {
  const MoveLeft();
}

class MoveRight extends KeypadEvent {
  const MoveRight();
}

class AnsKey extends KeypadEvent {
  const AnsKey();
}

class StoKey extends KeypadEvent {
  const StoKey();
}

class RclKey extends KeypadEvent {
  const RclKey();
}

class McKey extends KeypadEvent {
  const McKey();
}

class AngleKey extends KeypadEvent {
  const AngleKey();
}
