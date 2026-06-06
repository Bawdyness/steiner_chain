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

// ---------------------------------------------------------------------------
// Inverse-swap helpers for keypads with sin↔sin⁻¹ double-tap arming.
//
// Pure functions over a token buffer + cursor (no widget state) so the
// calculator and the curve plotter share one definition instead of each
// re-implementing the toggle.
// ---------------------------------------------------------------------------

/// True when the token before [cursor] is [id] or its inverse — i.e. a tap on
/// [id] would toggle it. Drives the "armed" dot on the key.
bool isInverseArmed(List<Tok> input, int cursor, FuncId id) {
  if (cursor == 0) return false;
  final prev = input[cursor - 1];
  if (prev is! FuncTok) return false;
  return (prev.id == id && id.inverse != null) || prev.id == id.inverse;
}

/// If the token before [cursor] is [id] or its inverse, returns a new buffer
/// with that token toggled to the other; otherwise null (caller inserts fresh).
List<Tok>? toggledInverse(List<Tok> input, int cursor, FuncId id) {
  if (cursor == 0) return null;
  final prev = input[cursor - 1];
  if (prev is! FuncTok) return null;
  final FuncId? swap =
      prev.id == id ? id.inverse : (prev.id == id.inverse ? id : null);
  if (swap == null) return null;
  final out = [...input];
  out[cursor - 1] = FuncTok(swap);
  return out;
}
