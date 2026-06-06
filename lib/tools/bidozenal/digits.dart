// Bidozenal (base-24 / tetravigesimal) digit helpers.
//
// Values 0..23 print as 0-9 then A..N (A=10 … N=23). Self-contained — pure
// Dart, no Flutter imports — so the logic core stays testable in isolation.
// See docs/bidozenal.md for the full design rationale.

/// The base this tool computes in.
const int kBase = 24;

/// 0-9 then A..N (= 10..23). The index into this string IS the digit value.
const String _digitChars = '0123456789ABCDEFGHIJKLMN';

/// Value 0..23 → display char ('0'..'9', 'A'..'N').
String bidozenalChar(int value) {
  assert(value >= 0 && value < kBase, 'digit out of range: $value');
  return _digitChars[value];
}

/// Display char → value 0..23, or null if not a base-24 digit.
/// Accepts both upper- and lowercase letters (a..n map like A..N).
int? bidozenalValue(String ch) {
  if (ch.isEmpty) return null;
  final i = _digitChars.indexOf(ch.toUpperCase());
  return i < 0 ? null : i;
}
