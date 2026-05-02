import 'package:flutter/material.dart';

/// Schmaler vertikaler Trenner, der per horizontalem Drag eine Spaltenbreite
/// ändert. Wird zwischen den Panels der Tool-Layouts verwendet.
class DragHandle extends StatelessWidget {
  const DragHandle({super.key, required this.onDrag});

  final void Function(double dx) onDrag;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: Container(
          width: 6,
          alignment: Alignment.center,
          child: Container(width: 1, color: color),
        ),
      ),
    );
  }
}
