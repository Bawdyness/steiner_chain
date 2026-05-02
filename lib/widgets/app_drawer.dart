import 'package:flutter/material.dart';

/// Eintrag in der Tool-Liste — Anzeigename, Icon, und Builder für das
/// eigentliche Tool-Widget. Tools sind eigenständige `Scaffold`s mit
/// eigener AppBar und ihrem eigenen `drawer:`-Slot, der diesen
/// `AppDrawer` instanziiert.
class ToolEntry {
  const ToolEntry({
    required this.title,
    required this.icon,
    required this.builder,
  });
  final String title;
  final IconData icon;
  final Widget Function() builder;
}

/// Stellt die Tool-Liste und die aktive Auswahl unten an die Widget-Tree —
/// jedes Tool kann via `HubScope.of(context)` die Auswahl ändern.
class HubScope extends InheritedWidget {
  const HubScope({
    super.key,
    required this.entries,
    required this.activeIndex,
    required this.onSelect,
    required super.child,
  });

  final List<ToolEntry> entries;
  final int activeIndex;
  final void Function(int) onSelect;

  static HubScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HubScope>();
    assert(scope != null, 'HubScope nicht im Widget-Tree gefunden.');
    return scope!;
  }

  @override
  bool updateShouldNotify(HubScope old) =>
      activeIndex != old.activeIndex || entries != old.entries;
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
