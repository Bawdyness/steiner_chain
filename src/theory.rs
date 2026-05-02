//! In-App-Theorie-Viewer.
//!
//! Lädt eine von Pandoc erzeugte `.typ`-Datei (Pipeline:
//! `docs/Makefile` → LyX → LaTeX → Typst), prependet eine Styling-Präambel
//! mit dynamischer Seitenbreite, kompiliert mit der gebündelten Typst-Engine
//! und stellt die gerenderten Seiten in einer `egui::ScrollArea` dar.
//!
//! Bei Größenänderungen des Panels wird das Dokument auf eine neue Breite
//! neu kompiliert. Die Breite wird auf 10-Punkt-Schritte quantisiert,
//! damit Resizes nicht jeden Frame eine Neuberechnung auslösen.

use eframe::egui;
use std::path::{Path, PathBuf};
use typst::layout::PagedDocument;
use typst_as_lib::TypstEngine;

static MATH_FONT: &[u8] = include_bytes!("../assets/fonts/latinmodern-math.otf");
static TEXT_FONT: &[u8] = include_bytes!("../assets/fonts/lmroman10-regular.otf");

const RENDER_DPI: f32 = 2.0;
const WIDTH_QUANTUM_PT: f32 = 10.0;
const MIN_WIDTH_PT: f32 = 200.0;

fn build_preamble(width_pt: f32) -> String {
    format!(
        r##"#set page(width: {width_pt}pt, height: auto, margin: (x: 18pt, y: 16pt), fill: rgb("#1e1e1e"))
#set text(font: "Latin Modern Roman", fill: rgb("#f0f0f0"), size: 14pt)
#set par(justify: true)
#show math.equation: set text(font: "Latin Modern Math")
#show heading: set text(fill: rgb("#ffd479"))

"##
    )
}

struct Page {
    texture: egui::TextureHandle,
    /// Logische (Punkt-)Größe — Pixmap-Größe / DPI-Faktor.
    logical_size: egui::Vec2,
}

pub struct Theory {
    body: Option<(PathBuf, String)>,
    cache_key: Option<(PathBuf, u32)>,
    pages: Vec<Page>,
    error: Option<String>,
}

impl Theory {
    pub fn new() -> Self {
        Self {
            body: None,
            cache_key: None,
            pages: Vec::new(),
            error: None,
        }
    }

    fn load_body(&mut self, path: &Path) {
        if matches!(&self.body, Some((p, _)) if p == path) {
            return;
        }
        match std::fs::read_to_string(path) {
            Ok(s) => {
                self.body = Some((path.to_path_buf(), s));
                self.error = None;
            }
            Err(e) => {
                self.body = None;
                self.error = Some(format!("Konnte {} nicht lesen: {e}", path.display()));
            }
        }
    }

    fn rerender(&mut self, ctx: &egui::Context, path: &Path, width_pt: f32) {
        let Some((_, body)) = &self.body else {
            return;
        };
        let source = format!("{}{}", build_preamble(width_pt), body);

        let engine = TypstEngine::builder()
            .main_file(source)
            .fonts([MATH_FONT, TEXT_FONT])
            .build();

        let doc: PagedDocument = match engine.compile().output {
            Ok(d) => d,
            Err(e) => {
                self.error = Some(format!("Typst-Fehler: {e:?}"));
                return;
            }
        };

        self.pages.clear();
        self.error = None;
        for (i, page) in doc.pages.iter().enumerate() {
            let pixmap = typst_render::render(page, RENDER_DPI);
            let logical_size = egui::vec2(
                pixmap.width() as f32 / RENDER_DPI,
                pixmap.height() as f32 / RENDER_DPI,
            );
            let size = [pixmap.width() as usize, pixmap.height() as usize];
            let image = egui::ColorImage::from_rgba_unmultiplied(size, pixmap.data());
            let name = format!("theory-page-{i}");
            self.pages.push(Page {
                texture: ctx.load_texture(&name, image, Default::default()),
                logical_size,
            });
        }
        self.cache_key = Some((path.to_path_buf(), (width_pt / WIDTH_QUANTUM_PT) as u32));
    }

    pub fn show(&mut self, ui: &mut egui::Ui, path: &Path) {
        let target_width = ui.available_width().max(MIN_WIDTH_PT);
        let quantized = (target_width / WIDTH_QUANTUM_PT).round() * WIDTH_QUANTUM_PT;
        let key = (path.to_path_buf(), (quantized / WIDTH_QUANTUM_PT) as u32);

        self.load_body(path);
        if self.cache_key.as_ref() != Some(&key) && self.body.is_some() {
            self.rerender(ui.ctx(), path, quantized);
        }

        if let Some(err) = &self.error {
            ui.colored_label(egui::Color32::LIGHT_RED, err);
            return;
        }

        egui::ScrollArea::vertical()
            .auto_shrink([false; 2])
            .show(ui, |ui| {
                for page in &self.pages {
                    ui.image((page.texture.id(), page.logical_size));
                    ui.add_space(8.0);
                }
            });
    }
}
