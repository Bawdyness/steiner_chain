// Top tool bar (ToolSelectorBar) + AppBar overflow (Einstellungen/Über) that
// replaced the hamburger drawer. Verifies tab switching and that the settings
// route — pushed above the HubScope — still opens (it receives the hub data by
// parameter). See CLAUDE.md → "Tool hub".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geometrie_spielzeug/scaffold/tool_scaffold.dart';
import 'package:geometrie_spielzeug/widgets/tool_nav.dart';

List<ToolEntry> _entries() => [
      ToolEntry(
        id: 'a',
        title: 'Alpha',
        icon: Icons.looks_one_outlined,
        builder: () => const SizedBox.shrink(),
      ),
      ToolEntry(
        id: 'b',
        title: 'Beta',
        icon: Icons.looks_two_outlined,
        builder: () => const SizedBox.shrink(),
      ),
    ];

Widget _host({
  required int active,
  required void Function(int) onSelect,
  void Function(String, bool)? onToggle,
}) {
  final entries = _entries();
  return MaterialApp(
    home: HubScope(
      entries: entries,
      allEntries: entries,
      activeIndex: active,
      onSelect: onSelect,
      disabledIds: const {},
      onToggleTool: onToggle ?? (_, _) {},
      child: const ToolScaffold(
        title: 'Alpha',
        controls: SizedBox.shrink(),
        canvas: SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  testWidgets('bar shows every tool and tapping one selects it', (tester) async {
    int? selected;
    await tester.pumpWidget(_host(active: 0, onSelect: (i) => selected = i));

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(selected, 1);
  });

  testWidgets('overflow menu opens the settings route', (tester) async {
    await tester.pumpWidget(_host(active: 0, onSelect: (_) {}));

    await tester.tap(find.byTooltip('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();

    // SettingsScreen rendered (it gets hub data by parameter, not HubScope).
    expect(find.text('Sichtbare Werkzeuge'), findsOneWidget);
    expect(find.text('Beta'), findsWidgets);
  });
}
