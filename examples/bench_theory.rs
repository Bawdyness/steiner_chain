// Compile + render the Steiner theory document and print page stats.
use std::time::Instant;
use typst::layout::PagedDocument;
use typst_as_lib::TypstEngine;

static MATH_FONT: &[u8] = include_bytes!("../assets/fonts/latinmodern-math.otf");
static TEXT_FONT: &[u8] = include_bytes!("../assets/fonts/lmroman10-regular.otf");

static PREAMBLE: &str = r##"#set page(width: 16cm, height: auto, margin: (x: 1.2cm, y: 1cm), fill: rgb("#1e1e1e"))
#set text(font: "Latin Modern Roman", fill: rgb("#f0f0f0"), size: 12pt)
#show math.equation: set text(font: "Latin Modern Math")
#show heading: set text(fill: rgb("#ffd479"))

"##;

fn main() {
    let body = std::fs::read_to_string("docs/build/steiner.typ")
        .expect("docs/build/steiner.typ not found — run `make -C docs steiner`");
    let source = format!("{PREAMBLE}{body}");

    let t = Instant::now();
    let engine = TypstEngine::builder()
        .main_file(source)
        .fonts([MATH_FONT, TEXT_FONT])
        .build();
    println!("engine build: {:>5} ms", t.elapsed().as_millis());

    let t = Instant::now();
    let doc: PagedDocument = engine.compile().output.expect("compile failed");
    println!("compile:      {:>5} ms  ({} pages)", t.elapsed().as_millis(), doc.pages.len());

    for (i, page) in doc.pages.iter().enumerate() {
        let t = Instant::now();
        let pixmap = typst_render::render(page, 2.0);
        println!(
            "page {}: {}x{} px  ({} ms)",
            i,
            pixmap.width(),
            pixmap.height(),
            t.elapsed().as_millis()
        );
    }
}
