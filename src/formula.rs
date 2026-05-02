use eframe::egui;
use typst::foundations::{Dict, IntoValue};
use typst::layout::PagedDocument;
use typst_as_lib::{TypstEngine, TypstTemplateMainFile};

static MATH_FONT: &[u8] = include_bytes!("../assets/fonts/latinmodern-math.otf");
static TEXT_FONT: &[u8] = include_bytes!("../assets/fonts/lmroman10-regular.otf");

static TEMPLATE: &str = r##"#import sys: inputs
#set page(width: auto, height: auto, margin: 6pt, fill: rgb("#1e1e1e"))
#set text(font: "Latin Modern Roman", fill: rgb("#f0f0f0"), size: 14pt)
#show math.equation: set text(font: "Latin Modern Math")
#let n = int(inputs.n)
#let s = calc.sin(calc.pi / n)
#let r_in = (1 - s) / (1 + s)
$ r_"in" = (1 - sin(pi/n)) / (1 + sin(pi/n)) = (1 - sin(pi/#n)) / (1 + sin(pi/#n)) approx #calc.round(r_in, digits: 4) $
"##;

pub struct Formula {
    engine: TypstEngine<TypstTemplateMainFile>,
    cache_key: Option<usize>,
    texture: Option<egui::TextureHandle>,
    last_compile_us: u128,
}

impl Formula {
    pub fn new() -> Self {
        let engine = TypstEngine::builder()
            .main_file(TEMPLATE)
            .fonts([MATH_FONT, TEXT_FONT])
            .build();
        Self {
            engine,
            cache_key: None,
            texture: None,
            last_compile_us: 0,
        }
    }

    pub fn show(&mut self, ui: &mut egui::Ui, n: usize) {
        if self.cache_key != Some(n) {
            self.recompile(ui.ctx(), n);
            self.cache_key = Some(n);
        }
        if let Some(tex) = &self.texture {
            ui.image((tex.id(), tex.size_vec2()));
        }
        ui.label(format!("Typst-Compile: {} µs", self.last_compile_us));
    }

    fn recompile(&mut self, ctx: &egui::Context, n: usize) {
        let mut inputs = Dict::new();
        inputs.insert("n".into(), (n as i64).into_value());

        let t0 = std::time::Instant::now();
        let result = self.engine.compile_with_input::<_, PagedDocument>(inputs);
        let doc = match result.output {
            Ok(d) => d,
            Err(e) => {
                eprintln!("typst compile error: {e:?}");
                return;
            }
        };
        let pixmap = typst_render::render(&doc.pages[0], 2.0);
        self.last_compile_us = t0.elapsed().as_micros();

        let size = [pixmap.width() as usize, pixmap.height() as usize];
        let image = egui::ColorImage::from_rgba_unmultiplied(size, pixmap.data());
        self.texture = Some(ctx.load_texture("formula", image, Default::default()));
    }
}
