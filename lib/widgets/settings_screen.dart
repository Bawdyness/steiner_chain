import 'package:flutter/material.dart';
import 'app_drawer.dart';

/// Einstellungs-Screen: Liste aller Tools mit `Switch` zum Aktivieren/
/// Deaktivieren. Mindestens ein Tool muss aktiv bleiben — der letzte
/// aktive Switch wird disabled gerendert.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HubScope.of(context);
    final theme = Theme.of(context);
    final visibleCount =
        scope.allEntries.where((t) => !scope.disabledIds.contains(t.id)).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Text(
              'Sichtbare Werkzeuge',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Deaktivierte Werkzeuge erscheinen nicht im Menü. Du kannst sie '
              'jederzeit wieder anschalten — sie sind weiterhin in der App '
              'enthalten.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final entry in scope.allEntries)
            _toolTile(context, scope, entry, visibleCount),
        ],
      ),
    );
  }

  Widget _toolTile(
    BuildContext context,
    HubScope scope,
    ToolEntry entry,
    int visibleCount,
  ) {
    final enabled = !scope.disabledIds.contains(entry.id);
    // Letzter aktiver Switch ist disabled — sonst würde der Drawer leer.
    final canToggle = !enabled || visibleCount > 1;
    return SwitchListTile(
      secondary: Icon(entry.icon),
      title: Text(entry.title),
      subtitle: Text(
        entry.id,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
      value: enabled,
      onChanged: canToggle
          ? (v) => scope.onToggleTool(entry.id, v)
          : null,
    );
  }
}
