//! Geometrie-Spielzeug-Hub.
//!
//! Die Wurzel-App hält eine Liste von [`Tool`]-Implementierungen und
//! delegiert UI- und Zeichen-Aufrufe an das aktive Tool. Der Hub selbst
//! kennt nur die Trait-Schnittstelle — Tools liegen unter `tools/`.
//!
//! Optionale Theorie-Dokumente werden vom integrierten [`Theory`]-Viewer
//! als gerenderte Typst-Seiten in einem rechten Panel angezeigt.

mod formula;
mod theory;
mod tool;
mod tools;

use eframe::egui;
use theory::Theory;
use tool::Tool;

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_title("Geometrie-Spielzeug")
            .with_inner_size([1100.0, 700.0]),
        ..Default::default()
    };
    eframe::run_native(
        "Geometrie-Spielzeug",
        options,
        Box::new(|cc| {
            cc.egui_ctx.set_pixels_per_point(1.3);
            Box::new(App::new())
        }),
    )
}

struct App {
    tools: Vec<Box<dyn Tool>>,
    active: usize,
    theory: Theory,
    theory_visible: bool,
}

impl App {
    fn new() -> Self {
        Self {
            tools: vec![Box::new(tools::steiner::Steiner::new())],
            active: 0,
            theory: Theory::new(),
            theory_visible: false,
        }
    }
}

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::SidePanel::left("controls")
            .min_width(280.0)
            .show(ctx, |ui| {
                ui.add_space(10.0);
                ui.heading("Geometrie-Spielzeug");
                ui.add_space(8.0);

                if self.tools.len() > 1 {
                    egui::ComboBox::from_label("Tool")
                        .selected_text(self.tools[self.active].name().to_string())
                        .show_ui(ui, |ui| {
                            for (i, tool) in self.tools.iter().enumerate() {
                                ui.selectable_value(&mut self.active, i, tool.name());
                            }
                        });
                    ui.separator();
                } else {
                    ui.label(self.tools[self.active].name());
                    ui.separator();
                }

                let active = &mut self.tools[self.active];
                active.controls_ui(ui);

                if active.theory_source().is_some() {
                    ui.add_space(10.0);
                    ui.toggle_value(&mut self.theory_visible, "Theorie anzeigen");
                }
            });

        let theory_path = self.tools[self.active].theory_source();
        if self.theory_visible {
            if let Some(path) = theory_path.as_deref() {
                egui::SidePanel::right("theory")
                    .min_width(440.0)
                    .resizable(true)
                    .show(ctx, |ui| {
                        ui.add_space(6.0);
                        ui.horizontal(|ui| {
                            ui.heading("Theorie");
                            if ui.button("✕").clicked() {
                                self.theory_visible = false;
                            }
                        });
                        ui.separator();
                        self.theory.show(ui, path);
                    });
            }
        }

        egui::CentralPanel::default().show(ctx, |ui| {
            let active = &mut self.tools[self.active];
            active.animate(ctx);
            let (rect, _response) =
                ui.allocate_exact_size(ui.available_size(), egui::Sense::hover());
            active.draw(ui.painter(), rect);
        });
    }
}
