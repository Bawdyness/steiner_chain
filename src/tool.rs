//! Trait für interaktive Geometrie-Tools.
//!
//! Jedes Tool ist autark: es hält seinen eigenen Zustand, rendert seine
//! eigenen Steuerelemente in der Seitenleiste und seine Grafik in den
//! Hauptbereich. Der Hub (`App` in `main.rs`) wählt das aktive Tool aus
//! und delegiert UI- und Zeichen-Aufrufe an es.
//!
//! ## Ein neues Tool hinzufügen
//!
//! 1. Modul unter `src/tools/<name>.rs` anlegen.
//! 2. Eine Struktur definieren, die `Tool` implementiert.
//! 3. In `App::new()` (in `main.rs`) eine Instanz zur Tool-Liste hinzufügen.
//! 4. Optional eine `.lyx`-Datei in `docs/` für die ausführliche Theorie
//!    pflegen und über `theory_pdf()` referenzieren.

use eframe::egui;
use std::path::PathBuf;

pub trait Tool {
    /// Anzeigename in der Tool-Auswahl.
    fn name(&self) -> &str;

    /// Steuerelemente und Live-Formeln für die linke Seitenleiste.
    fn controls_ui(&mut self, ui: &mut egui::Ui);

    /// Zeichnung in den Hauptbereich. `rect` ist die zugewiesene Fläche.
    fn draw(&mut self, painter: &egui::Painter, rect: egui::Rect);

    /// Optional: pro Frame aufgerufen, bevor `draw` läuft. Tools mit
    /// Animationen aktualisieren hier ihren Zustand und rufen
    /// `ctx.request_repaint()` auf.
    fn animate(&mut self, _ctx: &egui::Context) {}

    /// Optional: Pfad zu einer Typst-Quelldatei (`.typ`), die der Hub im
    /// integrierten Theorie-Viewer anzeigt. Erzeugt wird sie in der Regel
    /// von `docs/Makefile` aus einer `.lyx`-Quelle. Wenn gesetzt, rendert
    /// der Hub einen "Theorie"-Toggle, der ein Panel mit dem gerenderten
    /// Dokument einblendet.
    fn theory_source(&self) -> Option<PathBuf> {
        None
    }
}
