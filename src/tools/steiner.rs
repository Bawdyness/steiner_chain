//! Steiner-Kette: `n` Kreise, die zwei konzentrische Kreise tangieren.
//!
//! Die Kette wird zunächst symmetrisch gerechnet (innerer Kreis im Ursprung)
//! und dann durch eine Möbius-Transformation des Einheitskreises
//! `f(z) = (z + a) / (1 + a·z)` exzentrisch verzerrt. Da Möbius-Abbildungen
//! Kreise und Tangentialitäten erhalten, bleibt die Kette geschlossen —
//! das ist Steiner's Porism.

use crate::formula::Formula;
use crate::tool::Tool;
use eframe::egui;
use std::f32::consts::{PI, TAU};
use std::path::{Path, PathBuf};
use typst::foundations::{Dict, IntoValue};

static FORMULA_TEMPLATE: &str = r##"#import sys: inputs
#set page(width: auto, height: auto, margin: 6pt, fill: rgb("#1e1e1e"))
#set text(font: "Latin Modern Roman", fill: rgb("#f0f0f0"), size: 16pt)
#show math.equation: set text(font: "Latin Modern Math")
#let n = int(inputs.n)
#let s = calc.sin(calc.pi / n)
#let r_in = (1 - s) / (1 + s)
$ r_"in" = (1 - sin(pi/n)) / (1 + sin(pi/n)) = (1 - sin(pi/#n)) / (1 + sin(pi/#n)) approx #calc.round(r_in, digits: 4) $
"##;

pub struct Steiner {
    n: usize,
    offset: f32,
    rotation: f32,
    animate: bool,
    formula: Formula<usize>,
}

impl Steiner {
    pub fn new() -> Self {
        Self {
            n: 12,
            offset: 0.0,
            rotation: 0.0,
            animate: true,
            formula: Formula::new(FORMULA_TEMPLATE, "steiner-formula"),
        }
    }
}

impl Tool for Steiner {
    fn name(&self) -> &str {
        "Steiner-Kette"
    }

    fn controls_ui(&mut self, ui: &mut egui::Ui) {
        ui.add(egui::Slider::new(&mut self.n, 3..=24).text("Anzahl Kreise (n)"));
        ui.add(egui::Slider::new(&mut self.offset, -0.95..=0.95).text("Verschiebung"));
        ui.checkbox(&mut self.animate, "Rotation (Steiner's Porism)");

        ui.add_space(20.0);
        ui.label(
            "Die Möbius-Transformation verzerrt den Raum so, dass die Kreise sich \
             immer perfekt berühren.",
        );

        ui.add_space(16.0);
        ui.separator();
        ui.label("Live-Formel:");
        let mut inputs = Dict::new();
        inputs.insert("n".into(), (self.n as i64).into_value());
        self.formula.show(ui, self.n, inputs);
    }

    fn animate(&mut self, ctx: &egui::Context) {
        if self.animate {
            self.rotation += 0.005;
            ctx.request_repaint();
        }
    }

    fn draw(&mut self, painter: &egui::Painter, rect: egui::Rect) {
        let center = rect.center();
        let radius = rect.width().min(rect.height()) * 0.45;

        // Möbius-Automorphismus des Einheitskreises: f(z) = (z + a) / (1 + a·z).
        let moebius = |x: f32, y: f32| -> egui::Pos2 {
            let a = self.offset;
            let den_real = 1.0 + a * x;
            let den_imag = a * y;
            let den_sq = den_real * den_real + den_imag * den_imag;
            let res_x = ((x + a) * den_real + y * den_imag) / den_sq;
            let res_y = (y * den_real - (x + a) * den_imag) / den_sq;
            egui::pos2(center.x + res_x * radius, center.y - res_y * radius)
        };

        // Kreise werden als Polygone aus 64 möbiustransformierten Punkten gezeichnet.
        let draw_mapped_circle =
            |cx: f32, cy: f32, r: f32, stroke: egui::Stroke, fill: egui::Color32| {
                let points = 64;
                let mut shape = Vec::with_capacity(points);
                for i in 0..points {
                    let angle = (i as f32) / (points as f32) * TAU;
                    let px = cx + r * angle.cos();
                    let py = cy + r * angle.sin();
                    shape.push(moebius(px, py));
                }
                shape.push(shape[0]);
                painter.add(egui::Shape::convex_polygon(shape, fill, stroke));
            };

        let sin_pi_n = (PI / self.n as f32).sin();
        let r_in = (1.0 - sin_pi_n) / (1.0 + sin_pi_n);
        let r_chain = (1.0 - r_in) / 2.0;
        let r_mid = (1.0 + r_in) / 2.0;

        let stroke_bg = egui::Stroke::new(2.0, egui::Color32::from_gray(100));
        draw_mapped_circle(0.0, 0.0, 1.0, stroke_bg, egui::Color32::TRANSPARENT);
        draw_mapped_circle(0.0, 0.0, r_in, stroke_bg, egui::Color32::from_gray(40));

        let stroke_chain = egui::Stroke::new(1.5, egui::Color32::GOLD);
        for i in 0..self.n {
            let theta = self.rotation + (i as f32) / (self.n as f32) * TAU;
            let cx = r_mid * theta.cos();
            let cy = r_mid * theta.sin();
            draw_mapped_circle(cx, cy, r_chain, stroke_chain, egui::Color32::from_black_alpha(50));
        }
    }

    fn theory_source(&self) -> Option<PathBuf> {
        let p = Path::new("docs/build/steiner.typ");
        if p.exists() { Some(p.to_path_buf()) } else { None }
    }
}
