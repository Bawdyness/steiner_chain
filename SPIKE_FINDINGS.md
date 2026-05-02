# Spike: Live-Formel-Rendering via Typst

Branch: `spike/typst-formula`
Datum: 2026-05-02

## Aufbau

- `typst-as-lib` 0.15 als Wrapper (übernimmt das `World`-Boilerplate)
- `typst-render` 0.14 für Rasterisierung in `tiny_skia::Pixmap`
- Zwei OTF-Fonts gebündelt in `assets/fonts/` via `include_bytes!`
  - `latinmodern-math.otf` (717 KB) — Mathematik
  - `lmroman10-regular.otf` (109 KB) — Fließtext
- Modul `src/formula.rs`: hält eine einzige `TypstEngine`-Instanz, cached `egui::TextureHandle` per `n`-Wert

## Messwerte (Release-Build, ein Frame)

| Phase                 | Latenz   |
| --------------------- | -------- |
| Engine-Build (1×)     | 2.6 ms   |
| Compile (Folgeläufe)  | ~3.3 ms  |
| Render zu Pixmap      | ~1.1 ms  |
| **Pro Slider-Change** | ~4–5 ms  |

Bei 60 fps stehen 16.7 ms Frame-Budget zur Verfügung — mit Cache (ein Re-Render nur wenn sich `n` geändert hat) ist das mehr als komfortabel; selbst ohne Cache wäre Live-Update auf jedem Frame machbar.

## Binär-Größe

| Build                  | Größe   |
| ---------------------- | ------- |
| Debug                  | 532 MB  |
| Release                | 55 MB   |
| Release, gestripped    | 44 MB   |

Kompiliert wird ~3 Min für den ersten Release-Build (Cold-Cache). Inkrementelle Builds: ~2 s.

## Stolperfallen

1. **Edition 2024 + Raw Strings.** Typst-Syntax enthält `"#aabbcc"` für Farbwerte — kollidiert mit `r#"..."#`. Lösung: `r##"..."##` als Raw-String-Delimiter.
2. **Default-Font fehlt.** Typst sucht ohne explizite Angabe nach „Linux Libertine"; das Bündel hat das nicht. Im Template explizit setzen:
   ```typst
   #set text(font: "Latin Modern Roman", ...)
   #show math.equation: set text(font: "Latin Modern Math")
   ```
3. **Inputs-Routing.** `compile_with_input(Dict)` injiziert die Werte als `sys.inputs` — im Typst-Source via `#import sys: inputs` und `inputs.<key>` zugänglich.

## Architektonische Konsequenzen

- **Engine als Singleton pro Tool** ist günstig (2.6 ms Setup ist vernachlässigbar bei App-Start, aber pro Frame würde es spürbar werden).
- **Cache-Schlüssel** = Tupel der für die jeweilige Formel relevanten Slider-Werte. Bei Floats auf sinnvolle Präzision quantisieren (z.B. 3 Nachkommastellen), sonst rendern wir jeden Frame neu.
- **Fonts als App-globale Ressource** statt pro Tool. Im `Tool`-Trait-Refactoring sollten Fonts in einem App-weiten `FormulaContext` liegen, den der Trait optional konsumiert.
- **Theme-Integration.** Page- und Text-Farben müssen mit dem egui-Theme synchronisiert werden — bei dunklem/hellem Wechsel Cache invalidieren.

## Empfehlung

Grünes Licht für Typst als Live-Formel-Engine. Im Trait-Refactoring vorsehen:

```rust
trait Tool {
    fn name(&self) -> &str;
    fn controls_ui(&mut self, ui: &mut egui::Ui, fc: &mut FormulaContext);
    fn draw(&mut self, painter: &egui::Painter, rect: egui::Rect);
    fn theory_pdf(&self) -> Option<&Path> { None }
}
```

`FormulaContext` kapselt die geteilte `TypstEngine` + den Texture-Cache.

## Aufräumen

Vor dem Merge nach `master`:
- `examples/bench_formula.rs` entweder löschen oder als reproduzierbarer Benchmark behalten
- Fonts: prüfen, ob die Lizenzen (GUST Font License für Latin Modern) eine `LICENSE-fonts`-Datei verlangen
