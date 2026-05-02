# Geometrie-Spielzeug

Eine Desktop-App zum Erkunden geometrischer Konstruktionen — Schieberegler ändern, Formeln aktualisieren sich live, und der zugehörige theoretische Hintergrund lässt sich direkt im selben Fenster aufschlagen.

Aktuell enthalten:

- **Steiner-Kette** — `n` Kreise zwischen zwei sich nicht schneidenden Begrenzungskreisen. Verschiebung des inneren Kreises erzeugt eine exzentrische Kette über eine Möbius-Transformation; Rotation demonstriert Steiner's Porism.

Weitere Tools sind geplant — die App ist als Hub aufgebaut, in dem jedes Werkzeug ein eigenes Modul ist.

## Bauen und starten

Voraussetzung: Rust (stabil, mit `edition = "2024"`-Unterstützung).

```sh
cargo run --release
```

Der erste Release-Build dauert ein paar Minuten (Typst-Compiler wird mitgebaut), spätere Builds sind in Sekunden.

## Theorie-Dokumente erzeugen

Die App zeigt die Theorie zu jedem Tool im rechten Panel an, sobald „Theorie anzeigen" aktiviert ist. Quelle der Theorie sind LyX-Dateien in `docs/`, die über eine kleine Pipeline zu Typst konvertiert werden:

```sh
make -C docs
```

Voraussetzungen: `lyx` und `pandoc` im `PATH`. Die Pipeline läuft `lyx --export-to latex` gefolgt von `pandoc -t typst` und legt die Ergebnisse unter `docs/build/` ab.

Ohne diesen Schritt bleibt das Theorie-Panel leer (oder der Toggle erscheint gar nicht erst).

## Bedienung

Linke Seitenleiste:

- Schieberegler und Optionen für das aktive Tool (in der Steiner-Kette: Anzahl Kreise, Verschiebung, Rotation)
- Eine Live-Formel, die sich beim Ziehen am Slider aktualisiert
- „Theorie anzeigen"-Schalter, falls ein Theoriedokument gebaut wurde

Rechte Seitenleiste (optional):

- Das gerenderte Theoriedokument, scrollbar, Spaltenbreite per Drag verstellbar (das Dokument wird neu gesetzt, damit der Text in die Spalte passt)

Hauptbereich: die Zeichnung des aktiven Tools.

## Beispiel-Benchmarks

```sh
cargo run --release --example bench_formula   # Live-Formel-Latenz
cargo run --release --example bench_theory    # Theoriedokument-Latenz
```

## Lizenzen

Quellcode dieses Projekts: noch nicht festgelegt.

Mitgebündelte Schriften (Latin Modern Math, Latin Modern Roman) stehen unter der GUST Font License — siehe `assets/fonts/LICENSE` und `assets/fonts/NOTICE`.
