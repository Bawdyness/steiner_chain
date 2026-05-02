# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app for interactive geometry exploration. Mobile-first; primary deployment targets are Play Store and App Store, with Linux desktop available for development.

The repo previously hosted a Rust + `eframe`/`egui` prototype that validated the math approach (visible in `git log`). The Möbius/Steiner ideas are unchanged; only the runtime stack moved to Dart for mobile UX and store-friendly packaging.

Current tools:

- **Steiner-Kette** (`lib/tools/steiner.dart`) — `n` circles between two non-intersecting bounding circles. The eccentric variant uses a Möbius transform of the unit-disk symmetric case.
- **Einheitskreis** (`lib/tools/unit_circle.dart` + `lib/tools/unit_circle/`) — a draggable pointer on the unit circle plus a live sine/cosine wave that adapts to layout.

## Commands

- `make -C docs` — convert all `docs/*.lyx` theory documents to `assets/theory/*.md` via LyX → LaTeX → Pandoc-gfm. Required before the in-app theory viewer has anything to show.
- `flutter run -d linux` — launch the desktop build for development.
- `flutter run -d <android-device>` — once Android tooling is set up.
- `flutter analyze` / `flutter test` — static check and widget test.
- `flutter build linux --release` / `flutter build apk` — release builds.

## Architecture

### Tool hub (`lib/main.dart`, `lib/widgets/app_drawer.dart`)

`Hub` owns the active tool index and exposes it via `HubScope` (`InheritedWidget`). Each tool widget is a full `Scaffold` with its own AppBar and a `drawer:` slot pointing at the shared `AppDrawer`, which reads from `HubScope` to render the tool list. To add a tool, build a `StatefulWidget` returning a `Scaffold(drawer: const AppDrawer(), ...)` and append a `ToolEntry` to `_tools` in `main.dart`.

### Live formulas (`flutter_math_fork`)

`flutter_math_fork` renders KaTeX-style math. Used in two places:

- The Steiner controls panel renders `r_in = …` with the current `n` substituted on every slider tick.
- The Einheitskreis side panel renders the current angle as a fraction of π (or τ for full revolutions) plus the cosine/sine pair as exact radicals at standard angles. The fraction is generated dynamically by `_texForRadians` in `unit_circle.dart`, which tries denominators {1, 2, 3, 4, 6, 8} before falling back to a decimal multiplier of π — this also handles winding (e.g., `3π` at 540°, `2τ` at 720°).

### Theory viewer (`lib/theory.dart` + `docs/`)

Theory documents are authored in **LyX** (the user's preferred environment — see memory). The build pipeline:

```
docs/<tool>.lyx  --(lyx)-->  build/<tool>.tex  --(pandoc)-->  assets/theory/<tool>.md
```

`docs/Makefile` runs both steps plus a `sed`-based cleanup for Pandoc artifacts:

- ASCII `,,` → Unicode `„`
- Missing space before opening inline-math `$` (only when the math content is space-free, otherwise the regex chews across two adjacent inline-math islands)

`TheoryView` parses each block (header / paragraph / list / display-math) into a small AST and renders with Material widgets + `flutter_math_fork`. Headers use the same inline-math-splitting as paragraphs (so `$\pi$` in a section title renders correctly). Math goes through the same KaTeX renderer as the live formulas.

The hub UI shows a book icon in each tool's AppBar. On wide layouts it toggles a third resizable panel on the right; on narrow layouts it pushes a full-screen route.

### Steiner specifics (`lib/tools/steiner.dart`)

The eccentric chain isn't computed directly. Closed-form radii are computed for the symmetric concentric case (`r_in = (1 - sin(π/n)) / (1 + sin(π/n))`, etc.), then **every point fed to the painter is pushed through the disk-automorphism `f(z) = (z + a) / (1 + a·z)`**. This Möbius transform preserves circles and tangencies, so circles in disk coordinates have to be drawn as 64-point polygons via `_drawMappedCircle` — never `canvas.drawCircle` directly.

### Einheitskreis specifics (`lib/tools/unit_circle/`)

Three files:

- `checkpoints.dart` — universal list of standard angles (π/6 family, π/4 family, π/8 family, plus boundaries). `nearestCheckpoint` does modular wrap on input so winding-up (angle > 360°) still finds the right snap target.
- `scene_painter.dart` — single `CustomPainter` that draws the entire scene (circle + wave + connections). Layout-aware via `SceneLayout`.
- The page widget itself owns angle state, animation, and gesture wiring.

Key load-bearing decisions:

- **One painter, not three.** Connection lines span from the circle to the wave, so the painter needs to know both layouts simultaneously. `SceneLayout` enforces `circleRadius == waveAmplitude` and aligns the wave's value-axis with the corresponding circle axis (vertical y in wide, horizontal x in narrow). This is what makes the connection lines geometrically meaningful (truly horizontal in wide, truly vertical in narrow) without per-frame fudging.
- **Wide vs narrow swaps the wave function.** In wide layout, the wave plots `sin(θ)` horizontally to the right of the circle; the connection at angle θ lands at the same y-coordinate (= `sin(θ) · radius`) on both sides. In narrow layout, the wave plots `cos(θ)` vertically below the circle; connections share x-coordinates instead. This is geometrically forced by the requirement that the connection lines stay axis-aligned.
- **Color coding.** `colorScheme.tertiary` is the sine accent (gold); `colorScheme.secondary` is the cosine accent. The wave drawing, marker, ticks, axis-labels of the wave area, and connection lines all take the wave's mode color. The circle's inner labels (0°/90°/180°/270°) are colored by their projection meaning — 0°/180° on the x-axis use cosine color, 90°/270° on the y-axis use sine color — regardless of layout.
- **Wave display range > 2π.** The visible wave covers `_waveDisplayRange = 2.5π` so the curve runs visibly past τ. The marker, however, still wraps modular at 2π (so winding doesn't push it off-screen — it jumps back to the origin at 360°).
- **Snap with hysteresis + winding.** Enter radius 2°, release radius 5°. `_snappedAbsDegrees` tracks the absolute snap target (e.g., 540° for π in the second revolution), so the hysteresis check uses the real winding-aware distance.
- **Spring-back to 0.** A `Tween` from current to absolute 0, capped at 2 s, eased with `easeOutCubic`. From a large wound angle, the wave visibly rewinds through every checkpoint.

### Reference angle lists

The pizza slices and connection-line anchors use different angle sets per layout — a fundamental of the user's design:

- Wide (`_referenceAnglesWide`): upper hemisphere has the π/6 family + π/4 anchors; lower hemisphere has the π/8 family.
- Narrow (`_referenceAnglesNarrow`): right hemisphere = π/6 + π/4; left hemisphere = π/8.

The pizza-slice cuts on the circle adapt with the same right/left vs upper/lower split.

## Memory and feedback

The user authors documentation in LyX and rejects PDF as a delivery format (see `~/.claude/projects/-home-eric-steiner-chain/memory/feedback_open_formats.md`). The pipeline accordingly outputs Markdown for in-app rendering, never PDF.
