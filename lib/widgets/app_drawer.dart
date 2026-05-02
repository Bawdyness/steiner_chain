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
          ],
        ),
      ),
    );
  }
}
