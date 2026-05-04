# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app for interactive geometry exploration. Mobile-first; primary deployment targets are Play Store and App Store, with Linux desktop available for development.

The repo previously hosted a Rust + `eframe`/`egui` prototype that validated the math approach (visible in `git log`). The Möbius/Steiner ideas are unchanged; only the runtime stack moved to Dart for mobile UX and store-friendly packaging.

Current tools:

- **Steiner-Kette** (`lib/tools/steiner.dart`) — `n` circles between two non-intersecting bounding circles. The eccentric variant uses a Möbius transform of the unit-disk symmetric case.
- **Einheitskreis** (`lib/tools/unit_circle.dart` + `lib/tools/unit_circle/`) — a draggable pointer on the unit circle plus a live sine/cosine wave that adapts to layout.

## Long-term architecture intent

Today this repo is a single Flutter app. The intended endpoint is several apps — geometry, woodworking, physics, and so on — sharing one tool catalog. Target shape:

```
weltanschauung_workspace/
├── packages/
│   └── geometrie_kit/        # Shared: scaffold, theory, all tools
└── apps/
    ├── geometrie_spielzeug/  # Thin wrapper: bundle-id, theme, tool list
    ├── holzbau_helfer/
    └── physik_spielzeug/
```

In the target shape each tool is authored once in `geometrie_kit`. Each app is a thin wrapper with its own bundle-id, icon, Play Store listing and release cycle, and a `main.dart` of ~30 lines that lists which tools it includes. Migrating a tool from one app to another is a one-line change in two `main.dart` files — no code copy, no asset duplication.

The Play Store treats these as separate apps: separate listings, separate ratings, separate release cycles. There is no cross-app magic — tool migration is just two normal app updates landing on different days.

We are not in the monorepo yet — this section documents what we're working toward so the next refactor doesn't accidentally close that door. The actual extraction happens when (not before) the second app starts. Until then: stay disciplined as if the kit already existed.

## Tool authoring disciplines

Five rules that apply now, even while we're still single-app, because they are what makes the future kit-extraction trivial:

1. **No app-level strings in tools.** A tool widget does not reference `'Geometrie-Spielzeug'`, the bundle-id, the seed color, or any other app-identity. Those live in `main.dart` and platform configs. A tool gets a title, an icon, an id, a builder — that is it.

2. **No cross-tool imports.** A tool may import shared infrastructure (`lib/widgets/`, `lib/theory.dart`, `lib/scaffold/`), `dart:math`, and `package:flutter/...`. It must NOT import another tool. If two tools share something (e.g., a `Vec3`), that something belongs in shared infrastructure.

3. **Tools are self-contained.** `lib/tools/<id>.dart` plus optional `lib/tools/<id>/` directory for sub-files. A tool does not spread across siblings or reach into another tool's directory.

4. **Stable, persistence-safe IDs.** Each tool gets a `String id` (e.g., `'steiner'`, `'unit_circle'`) used as a SharedPreferences key, asset folder name, and registration anchor. The id is final after the tool ships — never rename.

5. **Tool registration is data, not code.** `_tools` in `main.dart` is a `const` list of `ToolEntry` records. Adding a tool = creating its file + appending to the list. Removing a tool = removing the entry. Both are one-line changes in `main.dart`.

These rules should not be relaxed even temporarily.

## Commands

- `make -C docs` — convert all `docs/*.lyx` theory documents to `assets/theory/*.md` via LyX → LaTeX → Pandoc-gfm. Required before the in-app theory viewer has anything to show.
- `flutter run -d linux` — launch the desktop build for development.
- `flutter run -d <android-device>` — once Android tooling is set up.
- `flutter analyze` / `flutter test` — static check and widget test.
- `flutter build linux --release` / `flutter build apk` — release builds.

## Architecture

### Tool hub (`lib/main.dart`, `lib/widgets/app_drawer.dart`)

`Hub` owns the active tool index and exposes it via `HubScope` (`InheritedWidget`). Each tool widget returns a `ToolScaffold(...)` (`lib/scaffold/tool_scaffold.dart`) which handles the AppBar, drawer slot, Wide/Narrow layout (`> 700` breakpoint), drag-handles for panel widths, and the optional reference panel (Theorie / Glossar / Symbole / Beispiele tabs). The tool itself only provides `controls` and `canvas` widgets, plus optional `reference: ToolReference(...)`. See "Adding a new tool" below for the recipe.

`Hub` filters the tool list by the user's visibility set (managed via "Einstellungen" in the drawer, persisted in `shared_preferences`) before exposing it to `AppDrawer`.

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
- **Hertz auto-animation.** A continuous `Ticker` (separate from the spring-back `AnimationController`) advances the angle by `_frequencyHz · 360°/s · Δt` each frame, accumulating without bound (winding works). Activated via the side-panel `TextField` (accepts comma or dot, clamped 0–60 Hz) or preset chips (0.5/1/5/50 Hz). While animating, snap-pinning is suppressed so the pointer flows through anchors. Drag interrupts cleanly — release at non-zero Hz resumes auto-animation from the new position (no spring-back).

### Reference angle lists

The pizza slices and connection-line anchors use different angle sets per layout, strictly matching each hemisphere's family:

- Wide (`_referenceAnglesWide`): upper hemisphere is **purely π/6** (30°-grid); lower hemisphere is **purely π/8** (22.5°-grid). The π/4 angles 225°/315° are kept in the lower set because they coincide with the π/8-grid (45° = 22.5° · 2). 45° and 135° are NOT in the upper set — having them there would break the strict 30°-grid feel.
- Narrow (`_referenceAnglesNarrow`): same logic but rotated — right hemisphere (cos > 0) is π/6, left hemisphere (cos < 0) is π/8.

The pizza-slice cuts on the circle follow the same partition, so the reference dots and the slice lines always agree.

`kCheckpoints` (in `checkpoints.dart`) is the **universal** list used for snap and is independent of layout — π/6, π/4, and π/8 family members are all present, so dragging always finds the canonical anchor regardless of which hemisphere is showing 30°-cuts vs 22.5°-cuts.

### Boundary-modulo subtleties

Three places in `scene_painter.dart` need careful handling of the θ = 2π boundary because Dart's `2π % 2π` is 0:

1. `_curvePath` samples θ from 0 to `_waveDisplayRange` — must NOT wrap at 2π, otherwise the curve's last sample lands at the origin instead of the right edge.
2. `_referenceWaveEnd` positions the τ tick (at θ=2π exactly) — must NOT wrap, otherwise the τ label lands at the origin instead of the wave's negative-to-positive crossing at the end of one period.
3. `_activeWavePoint` (the marker) — DOES wrap at 2π so the marker jumps back to the origin when the angle completes a full revolution. This is intentional and user-requested.

The trick in (1) and (2): only modulo when strictly outside [0, 2π], not at the inclusive boundary.

### License + about dialog

`LICENSE` (CC BY-NC-SA 4.0) is bundled as an asset. `main.dart` registers it with `LicenseRegistry` so it appears alongside Flutter's auto-collected third-party licenses. The drawer's "Über"-Eintrag opens `showAboutDialog`, which exposes the standard "View Licenses" button.

### Adding a new tool

1. Choose a stable `id`: lowercase, snake_case, never changes after the tool ships.
2. Create `lib/tools/<id>.dart` with a `StatefulWidget` whose `build()` returns `ToolScaffold(...)`.
3. If the tool needs sub-files (helpers, painters, sub-widgets), put them under `lib/tools/<id>/`.
4. Author theory in `docs/<id>.lyx`. If the tool has its own glossary, add `docs/<id>_glossar.lyx`. Run `make -C docs` to produce the Markdown assets.
5. Append a `ToolEntry(id: '<id>', title: ..., icon: ..., builder: () => <Tool>Page())` to `_tools` in `main.dart`. The const list keeps natural authoring order; the drawer renders in that order.
6. Drawer entry, settings toggle, theory book-icon, and persistence wire up automatically from the registration. No further setup.

What you must not do (see "Tool authoring disciplines" above):
- Hard-code app-identity strings in the tool — title comes via `ToolEntry.title`.
- Import another tool — share via `lib/scaffold/`, `lib/widgets/`, or other shared infrastructure.
- Change the `id` after the tool has shipped — it is the SharedPreferences key.

## Tool visibility (user setting)

Users can hide tools they do not want via the drawer entry "Einstellungen". A `Set<String>` of deactivated tool ids is persisted via `shared_preferences`. `Hub` filters `_tools` by the visible set before exposing it to `AppDrawer`. UI enforces that at least one tool stays visible (the last one cannot be deactivated).

This is UX-only — the APK ships with all tools regardless of which are visible. Reducing actual bundle size via Android Play Feature Delivery (Flutter `deferred_components`) is a separate, future option, only worth pursuing if total bundle exceeds ~100 MB. Android-only — iOS and desktop ship the full bundle anyway. Out of scope today.

## Build identity (Android)

- Bundle ID: `app.weltanschauung.geometrie`
- Version: `0.1.0+1` (in `pubspec.yaml`)
- Signing config in `android/app/build.gradle.kts` reads from `android/key.properties` (gitignored — contains the keystore path and password)
- Upload keystore lives at `~/keys/geometriespielzeug-upload.jks` (RSA 2048, valid until 2053)
- Build commands: `flutter build apk --release` (for emulator/device testing) or `flutter build appbundle --release` (for Play Store upload)

## Memory and feedback

The user authors documentation in LyX and rejects PDF as a delivery format (see `~/.claude/projects/-home-eric-steiner-chain/memory/feedback_open_formats.md`). The pipeline accordingly outputs Markdown for in-app rendering, never PDF.
