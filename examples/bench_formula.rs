// Benchmark: how long does Typst take to compile + render our formula?
use std::time::Instant;
use typst::foundations::{Dict, IntoValue};
use typst::layout::PagedDocument;
use typst_as_lib::TypstEngine;

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

fn main() {
    let t0 = Instant::now();
    let engine = TypstEngine::builder()
        .main_file(TEMPLATE)
        .fonts([MATH_FONT, TEXT_FONT])
        .build();
    println!("engine build:       {:>7} µs", t0.elapsed().as_micros());

    for n in [3usize, 6, 12, 24] {
        let mut inputs = Dict::new();
        inputs.insert("n".into(), (n as i64).into_value());

        let t = Instant::now();
        let doc: PagedDocument = engine
            .compile_with_input(inputs)
            .output
            .expect("compile failed");
        let compile_us = t.elapsed().as_micros();

        let t = Instant::now();
        let pixmap = typst_render::render(&doc.pages[0], 2.0);
        let render_us = t.elapsed().as_micros();

        println!(
            "n={:>2}  compile {:>5} µs  render {:>4} µs  px {}x{}",
            n,
            compile_us,
            render_us,
            pixmap.width(),
            pixmap.height()
        );
    }
}
