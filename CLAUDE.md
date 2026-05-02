# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app for interactive geometry exploration. Currently ships one tool (Steiner chain) with a live KaTeX formula in the controls panel and an integrated theory viewer fed by LyX-authored documents. Mobile-first — primary targets are Play Store and App Store; Linux desktop is available for development.

The repo previously hosted a Rust + `eframe`/`egui` prototype that validated the math and the Typst-based formula approach. That code lives only in `git log` now (commits before the Flutter port). The Möbius/Steiner approach is unchanged; only the runtime stack moved to Dart for mobile UX and store-friendly packaging.

## Commands

- `make -C docs` — convert all `docs/*.lyx` theory documents to `assets/theory/*.md` via LyX → LaTeX → Pandoc-gfm. Required before the in-app theory viewer has anything to show. Needs `lyx` and `pandoc` in `PATH`.
- `flutter run -d linux` — launch the desktop build for development.
- `flutter run -d <android-device>` — once Android tooling is set up (currently `flutter doctor` reports it missing).
- `flutter analyze` / `flutter test` — static check and widget test.
- `flutter build linux --release` / `flutter build apk` — release builds.

## Architecture

Three load-bearing pieces:

### 1. Tool page (`lib/tools/steiner.dart`)

A `StatefulWidget` that owns its sliders and animation state. The drawing happens in a `CustomPainter` (`_SteinerPainter`); the controls panel and live formula are sibling widgets. There is no `Tool` abstraction yet — the second tool will tell us what abstraction is actually needed (deferred until then). Animation is driven by `SingleTickerProviderStateMixin` with delta-time accumulation, so frame rate doesn't affect rotation speed.

The Möbius trick from the prototype is preserved verbatim: closed-form radii for the symmetric concentric chain, then **every point on every chain circle is pushed through `f(z) = (z + a) / (1 + a·z)`** (the disk automorphism). Circles in disk coordinates therefore have to be drawn as 64-point polygons via `_drawMappedCircle`, never with `canvas.drawCircle` directly, or they won't sit in the transformed space.

### 2. Live formula (`flutter_math_fork`)

The KaTeX-based renderer in the live-formula widget builds a LaTeX string with the current `n` substituted (`r_in = ...`) and re-renders on every slider change. The aligned environment splits the symbolic and numeric forms onto two lines so the formula fits in a narrow controls column.

### 3. Theory viewer (`lib/theory.dart` + `docs/`)

Theory documents are authored in **LyX** (the user's preferred environment — see memory). The build pipeline is:

```
docs/<tool>.lyx  --(lyx)-->  build/<tool>.tex  --(pandoc)-->  assets/theory/<tool>.md
```

`docs/Makefile` runs both steps, plus a `sed`-based cleanup for Pandoc artifacts (German low-9 quotes that come out as `,,`, missing space before opening inline-math `$`). The cleanup deliberately uses `[^[:space:]$]` rather than `[^[:space:]]` for the inline-math rule so it doesn't mangle display-math `$$...$$`.

`TheoryView` (`lib/theory.dart`) reads the bundled asset, parses it into a small AST (`HeaderBlock`, `ParagraphBlock`, `ListBlock`, `DisplayMathBlock`, with `TextSegment`/`MathSegment` for inline math), and renders each block as Material widgets. Math goes through the same `flutter_math_fork` engine as the live formula — single visual style throughout. Inline math is embedded in `Text.rich` via `WidgetSpan(alignment: PlaceholderAlignment.middle)`.

The hub UI shows a book icon in the AppBar. On wide layouts it toggles a third resizable panel on the right; on narrow layouts it pushes a full-screen route — this is the right Mobile pattern, not a side panel.

## Memory and feedback

The user authors documentation in LyX and rejects PDF as a delivery format (see `~/.claude/projects/-home-eric-steiner-chain/memory/feedback_open_formats.md`). The pipeline accordingly outputs Markdown for in-app rendering, never PDF.
