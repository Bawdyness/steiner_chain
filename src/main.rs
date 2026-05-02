mod formula;

use eframe::egui;
use formula::Formula;
use std::f32::consts::{PI, TAU};

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_title("Steiner Chain Explorer")
            .with_inner_size([900.0, 650.0]),
        ..Default::default()
    };
    eframe::run_native(
        "Steiner Chain",
        options,
        Box::new(|_cc| Box::new(SteinerApp::new())),
    )
}

struct SteinerApp {
    n: usize,
    offset: f32,
    rotation: f32,
    animate: bool,
    formula: Formula,
}

impl SteinerApp {
    fn new() -> Self {
        Self {
            n: 12,
            offset: 0.0,
            rotation: 0.0,
            animate: true,
            formula: Formula::new(),
        }
    }
}

impl eframe::App for SteinerApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        if self.animate {
            self.rotation += 0.005;
            ctx.request_repaint();
        }

        egui::SidePanel::left("controls").show(ctx, |ui| {
            ui.add_space(10.0);
            ui.heading("Steiner Chain");
            ui.add_space(20.0);

            ui.add(egui::Slider::new(&mut self.n, 3..=24).text("Anzahl Kreise (n)"));
            ui.add(egui::Slider::new(&mut self.offset, -0.95..=0.95).text("Verschiebung"));
            ui.checkbox(&mut self.animate, "Rotation (Steiner's Porism)");

            ui.add_space(20.0);
            ui.label(
                "Die Möbius-Transformation verzerrt den Raum so, dass die Kreise sich \
                 immer perfekt berühren.",
            );

            ui.add_space(20.0);
            ui.separator();
            ui.label("Live-Formel:");
            self.formula.show(ui, self.n);
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            let (rect, _response) =
                ui.allocate_exact_size(ui.available_size(), egui::Sense::hover());
            let center = rect.center();
            let radius = rect.width().min(rect.height()) * 0.45;
            let painter = ui.painter();

            let moebius = |x: f32, y: f32| -> egui::Pos2 {
                let a = self.offset;
                let den_real = 1.0 + a * x;
                let den_imag = a * y;
                let den_sq = den_real * den_real + den_imag * den_imag;
                let res_x = ((x + a) * den_real + y * den_imag) / den_sq;
                let res_y = (y * den_real - (x + a) * den_imag) / den_sq;
                egui::pos2(center.x + res_x * radius, center.y - res_y * radius)
            };

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
                draw_mapped_circle(
                    cx,
                    cy,
                    r_chain,
                    stroke_chain,
                    egui::Color32::from_black_alpha(50),
                );
            }
        });
    }
}
