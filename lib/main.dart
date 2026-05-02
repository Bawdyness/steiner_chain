import 'package:flutter/material.dart';
import 'tools/steiner.dart';

void main() {
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
      home: const SteinerPage(),
    );
  }
}
