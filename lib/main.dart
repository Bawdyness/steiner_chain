import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'tools/steiner.dart';
import 'tools/unit_circle.dart';
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
    return MaterialApp(
      title: 'Geometrie-Spielzeug',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD479),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const Hub(),
    );
  }
}

const List<ToolEntry> _tools = [
  ToolEntry(
    title: 'Steiner-Kette',
    icon: Icons.donut_large_outlined,
    builder: SteinerPage.new,
  ),
  ToolEntry(
    title: 'Einheitskreis',
    icon: Icons.pie_chart_outline,
    builder: UnitCirclePage.new,
  ),
];

class Hub extends StatefulWidget {
  const Hub({super.key});

  @override
  State<Hub> createState() => _HubState();
}

class _HubState extends State<Hub> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    return HubScope(
      entries: _tools,
      activeIndex: _activeIndex,
      onSelect: (i) => setState(() => _activeIndex = i),
      child: _tools[_activeIndex].builder(),
    );
  }
}
