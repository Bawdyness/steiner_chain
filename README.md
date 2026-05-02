# Geometrie-Spielzeug

Eine Flutter-App zum Erkunden geometrischer Konstruktionen — Schieberegler ändern, eine Live-Formel aktualisiert sich mit den Werten, und der zugehörige theoretische Hintergrund lässt sich direkt im selben Fenster aufschlagen.

Aktuell enthalten:

- **Steiner-Kette** — `n` Kreise zwischen zwei sich nicht schneidenden Begrenzungskreisen. Verschiebung des inneren Kreises erzeugt eine exzentrische Kette über eine Möbius-Transformation; Rotation demonstriert Steiner's Porism.

Weitere Werkzeuge folgen.

## Bauen und starten

Voraussetzung: Flutter (stabil, ≥ 3.41).

```sh
make -C docs            # Theoriedokumente konvertieren (s. unten)
flutter run -d linux    # oder -d android, -d ios, etc.
```

Plattformen: Android und Linux-Desktop sind im Scaffold konfiguriert. iOS ist machbar (`flutter create --platforms ios .`), HarmonyOS ist ein eigenes Kapitel.

## Theorie-Pipeline

Theoriedokumente werden in **LyX** (`docs/*.lyx`) verfasst und über `make -C docs` in Markdown konvertiert (`assets/theory/*.md`), das die App als Asset bündelt. Die Pipeline läuft `lyx --export-to latex` gefolgt von `pandoc -t gfm` mit einem `sed`-Putzschritt für Pandoc-Eigenheiten.

Voraussetzungen für die Pipeline: `lyx` und `pandoc` im `PATH`. Ohne `make`-Lauf vor `flutter build` fehlt der Theorie-Inhalt — das Buch-Icon wäre dann sichtbar, das Panel aber leer.

## Bedienung

- Schieberegler: Anzahl Kreise, Verschiebung des Innenkreises, Rotation an/aus.
- Live-Formel unter den Slidern (KaTeX über `flutter_math_fork`): symbolische Form plus aktueller numerischer Wert für `n`.
- Buch-Icon in der AppBar: Wide-Layout öffnet ein drittes Panel rechts; Mobile öffnet eine Vollbild-Route.
- Drag-Handles zwischen den Panels: Spaltenbreite live verstellbar (im Wide-Layout).

## Lizenzen

Quellcode dieses Projekts: noch nicht festgelegt.
