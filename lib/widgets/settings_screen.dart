import 'package:flutter/material.dart';
import 'tool_nav.dart';

/// Einstellungs-Screen: Liste aller Tools mit `Switch` zum Aktivieren/
/// Deaktivieren. Mindestens ein Tool muss aktiv bleiben — der letzte aktive
/// Switch wird disabled gerendert.
///
/// Wird als Route ÜBER dem [HubScope] gepusht und bekommt die Hub-Daten daher
/// explizit übergeben (statt via `HubScope.of`). Die Sichtbarkeit liegt in
/// lokalem State, damit die Switches sofort reagieren; [onToggleTool] meldet
/// die Änderung zurück an den Hub (persistiert + aktualisiert die Tool-Leiste).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.allEntries,
    required this.disabledIds,
    required this.onToggleTool,
  });

  final List<ToolEntry> allEntries;
  final Set<String> disabledIds;
  final void Function(String id, bool enabled) onToggleTool;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Set<String> _disabled = {...widget.disabledIds};

  void _toggle(String id, bool enabled) {
    setState(() {
      if (enabled) {
        _disabled.remove(id);
      } else {
        _disabled.add(id);
      }
    });
    widget.onToggleTool(id, enabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleCount =
        widget.allEntries.where((t) => !_disabled.contains(t.id)).length;
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
              'Deaktivierte Werkzeuge erscheinen nicht in der Tool-Leiste. Du '
              'kannst sie jederzeit wieder anschalten — sie sind weiterhin in '
              'der App enthalten.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final entry in widget.allEntries)
            _toolTile(theme, entry, visibleCount),
        ],
      ),
    );
  }

  Widget _toolTile(ThemeData theme, ToolEntry entry, int visibleCount) {
    final enabled = !_disabled.contains(entry.id);
    // Letzter aktiver Switch ist disabled — sonst bliebe die Leiste leer.
    final canToggle = !enabled || visibleCount > 1;
    return SwitchListTile(
      secondary: Icon(entry.icon),
      title: Text(entry.title),
      subtitle: Text(
        entry.id,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      value: enabled,
      onChanged: canToggle ? (v) => _toggle(entry.id, v) : null,
    );
  }
}
