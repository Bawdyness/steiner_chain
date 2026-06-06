import 'package:flutter/material.dart';

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
/// den Widget-Tree. `entries` enthält nur die *sichtbaren* Tools (die die
/// Tool-Leiste rendert); `allEntries` enthält alle (für die Einstellungs-Liste).
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

/// Horizontale Tool-Leiste für die AppBar: alle sichtbaren Tools als Icon +
/// Name nebeneinander, das aktive farbig hervorgehoben. Passt nicht alles in
/// die Breite, ist sie horizontal scrollbar. Tippen wechselt das Tool über den
/// [HubScope] — ersetzt den früheren Hamburger-Drawer.
class ToolSelectorBar extends StatelessWidget {
  const ToolSelectorBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HubScope.of(context);
    return SizedBox(
      height: kToolbarHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: scope.entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) => _ToolTab(
          entry: scope.entries[i],
          active: i == scope.activeIndex,
          onTap: () => scope.onSelect(i),
        ),
      ),
    );
  }
}

class _ToolTab extends StatelessWidget {
  const _ToolTab({
    required this.entry,
    required this.active,
    required this.onTap,
  });

  final ToolEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = active ? scheme.primary : scheme.onSurfaceVariant;
    return Center(
      child: Material(
        color: active
            ? scheme.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(entry.icon, size: 20, color: fg),
                const SizedBox(width: 6),
                Text(
                  entry.title,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
