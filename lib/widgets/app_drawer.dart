import 'package:flutter/material.dart';
import 'settings_screen.dart';

/// Eintrag in der Tool-Liste — stabiler `id`, Anzeigename, Icon, und Builder
/// für das eigentliche Tool-Widget. Tools sind eigenständige Widgets, die
/// sich an `ToolScaffold` hängen (siehe CLAUDE.md → "Adding a new tool").
///
/// Der `id` ist persistenz-relevant (SharedPreferences-Schlüssel für die
/// Sichtbarkeits-Toggle-Liste) und wird nach Auslieferung NIE umbenannt.
class ToolEntry {
  const ToolEntry({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
  });
  final String id;
  final String title;
  final IconData icon;
  final Widget Function() builder;
}

/// Stellt die Tool-Liste, die aktive Auswahl und die Sichtbarkeits-Logik an
/// die Widget-Tree. `entries` enthält nur die *sichtbaren* Tools (die der
/// Drawer rendert); `allEntries` enthält alle (für die Einstellungs-Liste).
class HubScope extends InheritedWidget {
  const HubScope({
    super.key,
    required this.entries,
    required this.allEntries,
    required this.activeIndex,
    required this.onSelect,
    required this.disabledIds,
    required this.onToggleTool,
    required super.child,
  });

  /// Sichtbare Tools (gefiltert nach `disabledIds`).
  final List<ToolEntry> entries;

  /// Alle registrierten Tools, unabhängig von Sichtbarkeit.
  final List<ToolEntry> allEntries;

  /// Index in `entries` des gerade aktiven Tools.
  final int activeIndex;

  final void Function(int) onSelect;

  /// IDs der vom User deaktivierten Tools.
  final Set<String> disabledIds;

  /// Setzt die Sichtbarkeit eines Tools. Das letzte sichtbare Tool kann
  /// nicht deaktiviert werden (UI verhindert das).
  final void Function(String id, bool enabled) onToggleTool;

  static HubScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HubScope>();
    assert(scope != null, 'HubScope nicht im Widget-Tree gefunden.');
    return scope!;
  }

  @override
  bool updateShouldNotify(HubScope old) =>
      activeIndex != old.activeIndex ||
      entries != old.entries ||
      disabledIds != old.disabledIds;
}

/// Drawer mit Tool-Liste, geteilt von allen Tools. Reagiert auf den
/// `HubScope` darüber.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HubScope.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Geometrie-Spielzeug',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            for (var i = 0; i < scope.entries.length; i++)
              ListTile(
                leading: Icon(scope.entries[i].icon),
                title: Text(scope.entries[i].title),
                selected: i == scope.activeIndex,
                onTap: () {
                  scope.onSelect(i);
                  Navigator.of(context).pop();
                },
              ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Einstellungen'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Über'),
              onTap: () {
                Navigator.of(context).pop();
                showAboutDialog(
                  context: context,
                  applicationName: 'Geometrie-Spielzeug',
                  applicationVersion: '0.1.0',
                  applicationLegalese:
                      '© Eric Naville, 2026.\n'
                      'Lizenz: CC BY-NC-SA 4.0\n'
                      '(Frei für nicht-kommerzielle Nutzung)',
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Quelltext und Inhalte stehen unter der Creative-'
                      'Commons-Lizenz BY-NC-SA 4.0. Du darfst sie weiter'
                      'geben und bearbeiten, solange du den Urheber nennst, '
                      'sie nicht kommerziell nutzt und Bearbeitungen unter '
                      'derselben Lizenz teilst.',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
