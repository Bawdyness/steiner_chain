//! Live-Formel-Rendering via Typst.
//!
//! Jedes Tool hält eine eigene `Formula<K>`-Instanz mit eigenem Template.
//! Der Cache-Schlüssel `K` ist eine vom Tool gewählte Repräsentation der
//! aktuellen Eingabewerte (z.B. `usize`, ein Tupel, oder ein quantisiertes
//! Float). Re-Rendering passiert nur, wenn `K` sich ändert.

use eframe::egui;
use typst::foundations::Dict;
use typst::layout::PagedDocument;
use typst_as_lib::{TypstEngine, TypstTemplateMainFile};

static MATH_FONT: &[u8] = include_bytes!("../assets/fonts/latinmodern-math.otf");
static TEXT_FONT: &[u8] = include_bytes!("../assets/fonts/lmroman10-regular.otf");

pub struct Formula<K: PartialEq + Clone> {
    engine: TypstEngine<TypstTemplateMainFile>,
    cache_key: Option<K>,
    texture: Option<egui::TextureHandle>,
    texture_name: &'static str,
}

impl<K: PartialEq + Clone> Formula<K> {
    pub fn new(template: &'static str, texture_name: &'static str) -> Self {
        let engine = TypstEngine::builder()
            .main_file(template)
            .fonts([MATH_FONT, TEXT_FONT])
            .build();
        Self {
            engine,
            cache_key: None,
            texture: None,
            texture_name,
        }
    }

    pub fn show(&mut self, ui: &mut egui::Ui, key: K, inputs: Dict) {
        if self.cache_key.as_ref() != Some(&key) {
            self.recompile(ui.ctx(), inputs);
            self.cache_key = Some(key);
        }
        if let Some(tex) = &self.texture {
            ui.image((tex.id(), tex.size_vec2()));
        }
    }

    fn recompile(&mut self, ctx: &egui::Context, inputs: Dict) {
        let result = self.engine.compile_with_input::<_, PagedDocument>(inputs);
        let doc = match result.output {
            Ok(d) => d,
            Err(e) => {
                eprintln!("typst compile error ({}): {e:?}", self.texture_name);
                return;
            }
        };
        let pixmap = typst_render::render(&doc.pages[0], 2.0);
        let size = [pixmap.width() as usize, pixmap.height() as usize];
        let image = egui::ColorImage::from_rgba_unmultiplied(size, pixmap.data());
        self.texture = Some(ctx.load_texture(self.texture_name, image, Default::default()));
    }
}
