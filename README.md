# Geometrie-Spielzeug

Eine Flutter-App zum Erkunden geometrischer Konstruktionen — Schieberegler ändern, eine Live-Formel oder eine mitlaufende Kurve aktualisieren sich, und der zugehörige theoretische Hintergrund lässt sich direkt im selben Fenster aufschlagen.

Aktuell enthalten:

- **Steiner-Kette** — `n` Kreise zwischen zwei sich nicht schneidenden Begrenzungskreisen. Verschiebung des inneren Kreises erzeugt eine exzentrische Kette über eine Möbius-Transformation; Rotation demonstriert Steiner's Porism.
- **Einheitskreis** — beweglicher Zeiger auf dem Einheitskreis, mit weicher Einrastung an Standardwinkeln und Spring-Back beim Loslassen. Daneben/darunter eine Sinus- bzw. Kosinus-Welle, die mit dem Zeiger mitläuft, mit Verbindungslinien zu den Drittel- und Viertel-Anker-Punkten.

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

**Gemeinsam in beiden Tools:**

- Drawer-Symbol oben links wechselt zwischen den Werkzeugen.
- Buch-Icon in der AppBar: Wide-Layout öffnet ein Theorie-Panel rechts; auf Mobile wird eine Vollbild-Route gepusht.
- Drag-Handles zwischen den Panels: Spaltenbreiten live verstellbar.

**Steiner-Kette:**

- Schieberegler für Anzahl Kreise, Verschiebung des Innenkreises, Rotation an/aus.
- Live-Formel unter den Slidern (KaTeX über `flutter_math_fork`): symbolische Form plus aktueller numerischer Wert für `n`.

**Einheitskreis:**

- Zeiger auf dem Kreisrand mit der Maus oder Finger ziehen — rastet weich an Standardwinkeln ein. Beim Loslassen rutscht er im Uhrzeigersinn zurück. Über 360° hinaus wird gewickelt; die Welle läuft entsprechend weiter.
- Wave-Mode-Toggle oben im Panel: „Punkt wandert" (Welle steht, Marker wandert) oder „Welle wandert" (Marker bleibt am Wellen-Anfang, Welle scrollt durch).
- Im Wide-Layout liegt die Welle rechts vom Kreis und zeigt Sinus (horizontal); im schmalen Layout rutscht sie unter den Kreis und zeigt Kosinus (vertikal). Verbindungslinien führen vom Kreis-Anker zur Welle, jeweils horizontal bzw. senkrecht.
- Sinus-Werte sind in der Akzentfarbe „Gold", Kosinus-Werte in der zweiten Akzentfarbe — die Achsenbeschriftungen am Kreis (0°/180° vs. 90°/270°) zeigen die Zugehörigkeit.

## Lizenz

Quellcode, Theorie-Texte und Icon dieses Projekts stehen unter
**Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International
(CC BY-NC-SA 4.0)**. Den vollen Lizenztext findest du in der Datei
[`LICENSE`](LICENSE) im Projekt-Root.

Kurzfassung:

- **Frei zum Nutzen, Teilen und Bearbeiten** für jeden.
- **Namensnennung** des Urhebers (Eric Naville).
- **Keine kommerzielle Nutzung** ohne separate Vereinbarung.
- **Bearbeitungen** unter derselben Lizenz weitergeben.

In der App selbst ist der Lizenztext zusätzlich über den „Über"-Eintrag
im Drawer einsehbar, zusammen mit den Lizenzen der eingebundenen
Open-Source-Pakete (`flutter_math_fork`, `markdown`, etc.).
