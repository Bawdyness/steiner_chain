import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'tools/bidozenal.dart';
import 'tools/kurve.dart';
import 'tools/steiner.dart';
import 'tools/unit_circle.dart';
import 'tools/wachstum.dart';
import 'widgets/app_drawer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Eigene Lizenz (CC BY-NC-SA 4.0) zur LicenseRegistry hinzufügen, damit
  // sie zusammen mit den Drittanbieter-Lizenzen im About-Dialog erscheint.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(['Geometrie-Spielzeug'], text);
  });
  runApp(const GeometrieSpielzeugApp());
}

class GeometrieSpielzeugApp extends StatelessWidget {
  const GeometrieSpielzeugApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFD479),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Geometrie-Spielzeug',
      // Immer dunkel, unabhängig von Geräte-Nachtmodus.
      themeMode: ThemeMode.dark,
      theme: dark,
      darkTheme: dark,
      home: const Hub(),
    );
  }
}

const List<ToolEntry> _tools = [
  ToolEntry(
    id: 'steiner',
    title: 'Steiner-Kette',
    icon: Icons.donut_large_outlined,
    builder: SteinerPage.new,
  ),
  ToolEntry(
    id: 'unit_circle',
    title: 'Einheitskreis',
    icon: Icons.pie_chart_outline,
    builder: UnitCirclePage.new,
  ),
  ToolEntry(
    id: 'wachstum',
    title: 'Wachstum',
    icon: Icons.trending_up,
    builder: WachstumPage.new,
  ),
  ToolEntry(
    id: 'bidozenal',
    title: 'Bidozenal-Rechner',
    icon: Icons.calculate_outlined,
    builder: BidozenalPage.new,
  ),
  ToolEntry(
    id: 'kurve',
    title: 'Kurve',
    icon: Icons.show_chart,
    builder: KurvePage.new,
  ),
];

const String _disabledToolsKey = 'disabled_tools';

class Hub extends StatefulWidget {
  const Hub({super.key});

  @override
  State<Hub> createState() => _HubState();
}

class _HubState extends State<Hub> {
  int _activeIndex = 0;
  Set<String> _disabledIds = const {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadDisabled();
  }

  Future<void> _loadDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_disabledToolsKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _disabledIds = list.toSet();
      _loaded = true;
    });
  }

  Future<void> _persist(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_disabledToolsKey, ids.toList());
  }

  void _toggleTool(String id, bool enabled) {
    final updated = Set<String>.from(_disabledIds);
    if (enabled) {
      updated.remove(id);
    } else {
      // Schutz: das letzte sichtbare Tool darf nicht deaktiviert werden.
      // Die UI verhindert das auch, hier zur Sicherheit nochmal prüfen.
      final wouldRemain = _tools
          .where((t) => !updated.contains(t.id) && t.id != id)
          .isNotEmpty;
      if (!wouldRemain) return;
      updated.add(id);
    }
    setState(() {
      _disabledIds = updated;
      // Aktiven Index neu zuordnen, damit er auf einem sichtbaren Tool landet.
      final visible = _tools.where((t) => !updated.contains(t.id)).toList();
      if (_activeIndex >= visible.length) {
        _activeIndex = visible.length - 1;
      }
    });
    _persist(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final visible =
        _tools.where((t) => !_disabledIds.contains(t.id)).toList();
    final safeIndex = _activeIndex.clamp(0, visible.length - 1);
    return HubScope(
      entries: visible,
      allEntries: _tools,
      activeIndex: safeIndex,
      onSelect: (i) => setState(() => _activeIndex = i),
      disabledIds: _disabledIds,
      onToggleTool: _toggleTool,
      child: visible[safeIndex].builder(),
    );
  }
}
