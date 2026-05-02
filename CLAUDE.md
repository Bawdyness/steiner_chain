# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Rust desktop app (`eframe`/`egui`) hosting interactive geometry tools. Each tool is a self-contained module under `src/tools/` implementing the [`Tool`] trait. UI labels and prose are German.

## Commands

- `cargo run --release` — launch the app. The release profile is noticeably smoother than debug because the per-frame Möbius math + Typst formula compilation are CPU-bound.
- `cargo check` — fast type-check.
- `cargo run --release --example bench_formula` — measure Typst compile + render latency for the live-formula path.
- `cargo run --release --example bench_theory` — compile + render the Steiner theory document.
- `make -C docs` — convert all `docs/*.lyx` theory documents to `docs/build/*.typ` via LyX → LaTeX → Pandoc. Required before the in-app theory viewer can show a tool's theory. Needs `lyx` and `pandoc` in `PATH`.

There are no tests.

## Architecture

Three load-bearing pieces, none of which are obvious from a single file:

### 1. The `Tool` trait (`src/tool.rs`)

The hub (`App` in `src/main.rs`) is intentionally thin. It owns `Vec<Box<dyn Tool>>`, a tool selector, and dispatches `controls_ui` / `animate` / `draw` to the active tool. Each tool owns its own state and rendering — no shared model. To add a new tool, drop a module under `src/tools/`, implement `Tool`, and append it in `App::new()`.

### 2. Live formulas via Typst (`src/formula.rs`)

`Formula<K>` wraps a `TypstEngine` with a single `main_file` template that takes inputs through `sys.inputs`. The tool calls `formula.show(ui, key, inputs)` per frame; re-rendering only happens when `key` changes. The cache key `K` is whatever set of values the tool considers "the formula's identity" (e.g. `usize` for `n` in Steiner). Two OTF fonts (Latin Modern Math + Roman) are bundled via `include_bytes!` from `assets/fonts/`.

Non-obvious: Typst color literals (`"#abcdef"`) collide with Rust's `r#"..."#` raw string delimiter. All Typst templates use `r##"..."##`. Without explicit `#set text(font: "Latin Modern Roman")` and `#show math.equation: set text(font: "Latin Modern Math")` the engine errors with "no font could be found" — Typst defaults to Linux Libertine, which we don't bundle.

### 3. In-app theory viewer (`src/theory.rs` + `docs/`)

Theory documents are authored in **LyX** (the user's preferred environment). The build pipeline is:

```
docs/<tool>.lyx  --(lyx)-->  build/<tool>.tex  --(pandoc)-->  build/<tool>.typ
```

At runtime, `Theory::ensure_loaded` reads the `.typ` file, prepends a styling preamble (page width, dark background, font setup), compiles with the bundled Typst engine, and renders each page to an `egui::TextureHandle`. Pages are stacked in a `ScrollArea` inside a right-side panel toggled from the controls. `tool.theory_source()` returns the `.typ` path; the hub auto-shows a "Theorie anzeigen"-toggle when it's `Some`.

Conversion fidelity caveat: pandoc's LaTeX→Typst writer handles standard math, sections, lists, and images. Custom `\usepackage{}` magic or raw TeX won't translate cleanly — keep LyX docs to standard mechanisms (amsmath, basic structure, equations, figures).

### Steiner tool specifics (`src/tools/steiner.rs`)

The interesting numerical trick: the eccentric chain isn't computed directly. Closed-form radii for the symmetric concentric case (`r_in = (1 - sin(π/n)) / (1 + sin(π/n))`, etc.) are computed once, then **every point fed to the painter is pushed through the disk-automorphism `f(z) = (z + a) / (1 + a·z)`**. This Möbius transform preserves circles and tangencies, so the symmetric solution becomes a valid eccentric chain "for free" — that's Steiner's porism. Anything that wants to draw a circle in disk coordinates must go through `draw_mapped_circle`, never `painter.circle_*` directly, or it won't sit in the transformed space.

## Memory and feedback

The user works in LyX and prefers open document formats (no PDF — see `~/.claude/projects/-home-eric-steiner-chain/memory/feedback_open_formats.md`). The theory pipeline outputs `.typ` consumed by the in-app viewer, deliberately avoiding any closed delivery format.
