# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Single-binary Rust app rendering an interactive Steiner chain (a ring of `n` circles tangent to two concentric circles) using `eframe`/`egui`, with a live mathematical formula rendered by an embedded Typst engine. UI labels and prose are German.

## Commands

- `cargo run --release` — launch the app. Release is noticeably smoother because per-frame Möbius math + Typst formula compilation are CPU-bound.
- `cargo check` — fast type-check.
- `cargo run --release --example bench_formula` — measure Typst engine build, compile, and render latency.

There are no tests.

## Architecture

Two load-bearing pieces:

### Steiner chain rendering (`src/main.rs`)

Closed-form radii for the symmetric concentric case (`r_in = (1 - sin(π/n)) / (1 + sin(π/n))`, etc.) are computed once. To handle the eccentric case (inner circle off-center), every point fed to the painter is pushed through the disk-automorphism `f(z) = (z + a) / (1 + a·z)`. This Möbius transform preserves circles and tangencies, so the symmetric solution becomes a valid eccentric chain "for free" — Steiner's porism. Anything that wants to draw a circle in disk coordinates must go through `draw_mapped_circle`, never `painter.circle_*` directly, or it won't sit in the transformed space.

### Live formula via Typst (`src/formula.rs`)

`Formula` wraps a `TypstEngine` whose `main_file` template takes inputs through `sys.inputs`. `formula.show(ui, n)` re-renders only when `n` changes (cached `egui::TextureHandle`). Two OTF fonts (Latin Modern Math + Roman) are bundled via `include_bytes!` from `assets/fonts/`.

Non-obvious traps:

- Typst color literals (`"#abcdef"`) collide with Rust's `r#"..."#` raw string delimiter. All Typst templates use `r##"..."##`.
- Without explicit `#set text(font: "Latin Modern Roman")` and `#show math.equation: set text(font: "Latin Modern Math")`, the engine errors with "no font could be found" — Typst defaults to Linux Libertine, which we don't bundle.
- Inputs are passed via `engine.compile_with_input(Dict)` and accessed in the template as `sys.inputs.<key>`.

Performance (release): engine build ~2.6 ms (one-time), per-formula compile ~3.3 ms, render ~1.1 ms. Easily fits a 16.7 ms frame budget.
