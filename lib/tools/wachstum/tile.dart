/// Operatoren der Rechen-Kacheln: vier Grundrechenarten, frei mischbar.
enum WachstumOp { plus, minus, times, dividedBy }

extension WachstumOpDisplay on WachstumOp {
  /// Symbol für die Kachel-Beschriftung. `−` ist der echte Minus-Strich,
  /// `×` das Mal-Zeichen, `÷` das Geteilt-Zeichen — alle drei sehen
  /// in unterschiedlichen Fonts deutlich besser aus als ASCII `-`, `*`, `/`.
  String get symbol => switch (this) {
        WachstumOp.plus => '+',
        WachstumOp.minus => '−',
        WachstumOp.times => '×',
        WachstumOp.dividedBy => '÷',
      };

  /// LaTeX-Operator für die Live-Formel (`\xrightarrow{…}`).
  String get tex => switch (this) {
        WachstumOp.plus => '+',
        WachstumOp.minus => '-',
        WachstumOp.times => r'\times',
        WachstumOp.dividedBy => r'\div',
      };

  double apply(double current, double value) => switch (this) {
        WachstumOp.plus => current + value,
        WachstumOp.minus => current - value,
        WachstumOp.times => current * value,
        WachstumOp.dividedBy => current / value,
      };
}

class WachstumTile {
  const WachstumTile({required this.op, required this.value});
  final WachstumOp op;
  final double value;

  WachstumTile copyWith({WachstumOp? op, double? value}) =>
      WachstumTile(op: op ?? this.op, value: value ?? this.value);
}

/// Berechnet die Folge der Zwischenwerte: `[y0, y0∘t0, (y0∘t0)∘t1, …]`.
/// Die Liste hat immer Länge `tiles.length + 1`.
List<double> checkpointValues(double y0, List<WachstumTile> tiles) {
  final values = <double>[y0];
  var y = y0;
  for (final tile in tiles) {
    y = tile.op.apply(y, tile.value);
    values.add(y);
  }
  return values;
}
