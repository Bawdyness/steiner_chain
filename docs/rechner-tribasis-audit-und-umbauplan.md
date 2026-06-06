# Rechner-Kern: Tri-Basis-Audit + Umbauplan

> Erstellt aus einem zwei-Wellen-Subagenten-Audit (read-only). Scope: nur dieses
> Repo (`geometrie_spielzeug`). Ziel-Zustand laut Owner: **ein** Rechner nach
> außen, **drei** im Hintergrund (Dezimal 10 / Dozenal 12 / Bidozenal 24); das
> Keypad zeigt immer alle 24 Glyphen, aktiv (weiß) sind nur die der gewählten
> Basis, der Rest grau und funktionslos.

---

## Teil 1 — Audit-Report

### Welle 1: Ist der Rechner-Kern sauber tri-basig?

**Verdikt: JA — die Engine ist echt tri-basig. Null Engine-Änderungen nötig.
Alle Blocker liegen in der UI-/Helfer-Schicht.**

Die Engine parst, wertet, erkennt Perioden und formatiert für Basis 10/12/24
gleichwertig — `BigInt.from(base)` durchgängig:
- `lib/calc/evaluator.dart:202` `evaluate(…, {x, base = kBase})`, `:226`
  `compileF64(…, base = kBase)`, `:468` `_Parser([base = kBase])`; Ziffern-Parsing
  `:584-606` nutzt `base` konsistent (`intVal = intVal * BigInt.from(base) + …`).
- `lib/calc/rational.dart:82` `expand({base})` (Schul-Algorithmus, `rem *= base`),
  `:142` `doubleToBaseDigits({base})`, `:177` `renderInBase(r, base)`.
- Spot-Checks (aus Code abgeleitet): `renderInBase(10, 10)` = `"10"`,
  `renderInBase(10, 12)` = `"A"`, `renderInBase(10, 24)` = `"A"` — alle korrekt.
- `lib/calc/digits.dart:15` `assert(value < kBase)` ist **sicher** (alle erzeugten
  Ziffernwerte sind < base ≤ 24), also reine Naming-Reibung, kein Blocker.

**Test-Realität (frühere Recon war hier falsch — direkt verifiziert):**
Basis 10/12 *sind* getestet — auf Render-Ebene:
- `test/kurve_test.dart:36-42` — `compileF64` mit `base: 12` **und** `base: 24`.
- `test/wachstum_test.dart:43-56` — `renderInBase` für 10/12/24.
- `test/bidozenal_test.dart:234-244` — `renderInBase` für 10/12/24.
Lücken: kein isolierter `evaluate(base: 10)`-Test; keine Tastatur-Reject-Tests;
keine Greying-Widget-Tests.

**Blocker für den Soll-Zustand (alle UI/Helfer, kein Engine-Code):**

| # | Stelle | Befund | Schwere |
|---|--------|--------|---------|
| 1 | `lib/tools/bidozenal/result.dart:51,67` | `expand(base: 24)` / `doubleToBaseDigits(base: 24)` hartkodiert | hoch |
| 2 | `lib/tools/bidozenal.dart:268,287` | `evaluate(_input, _angleMode)` ohne `base` → immer Default 24 | hoch |
| 3 | `lib/tools/bidozenal/keypad.dart:54` | `(… + 1) % 24`-Grid + `_DigitKey` ohne Aktiv-/Disabled-Zustand → kein Greying | hoch |
| 4 | `lib/calc/keyboard.dart:31` | `charEvent`/`eventForKey` ohne `base` → inaktive Ziffern (z. B. `a`=10 in Dezimal) werden nicht abgelehnt | hoch |
| 5 | `lib/tools/bidozenal.dart:393,412,526` | feste Basis-24-Umrechnung, Erklärtext „Basis 24 = 2³·3", Glyph-Chart-Schleife `v < kBase` | mittel/UI |
| 6 | `lib/calc/digits.dart:14,21`, `glyphs.dart` | `bidozenalChar`/`bidozenalValue`/`paintBidozenalGlyph`/`BidozenalGlyph` sind generisch, heißen aber „bidozenal" | niedrig (Naming) |

### Welle 2: Ist der Rechner sauber an die anderen Tools angebunden?

**Verdikt: Die Anbindung ist sauber.** Alle fünf Tool-Disziplinen halten;
keine Cross-Tool-Imports; `lib/calc/` ist eine reine geteilte Bibliothek.

- **Registry datengetrieben** (`lib/main.dart:46-77`): der Rechner ist ein
  `ToolEntry` wie jedes andere Tool; Sichtbarkeit über generischen
  `_disabledToolsKey` (`main.dart:79,101,111`).
- **`ToolScaffold` einheitlich** über alle Tools (`lib/scaffold/tool_scaffold.dart`).
- **`'bidozenal'`-id/Titel-Kopplungen** (relevant falls Umbenennung erwogen wird):
  `main.dart:66` (id), `main.dart:67` (Titel `'Bidozenal-Rechner'`),
  `bidozenal.dart:37` (`assets/theory/bidozenal.md`), `bidozenal.dart:63`
  (FocusNode-Debug-Label), `docs/bidozenal.md`. Disziplin 4: id nach Release final.
- **Vorhandenes Modus-Toggle-Muster zum Nachbauen:** Glyph-Modus =
  ephemeres `bool` + `SegmentedButton` in `_buildControls`
  (`bidozenal.dart:58, 377-384`); Winkel-Modus = ephemeres Enum, per Keypad-Taste
  gezykelt (`bidozenal.dart:59, 136-137`). **Keine per-Tool-Persistenz** existiert
  irgendwo — der Basis-Selektor wäre also per Default ebenfalls ephemer.

**Wichtigster Welle-2-Befund — Duplikation der drei Keypads:**

| Aspekt | Bidozenal | Kurve | Wachstum | Bewertung |
|--------|-----------|-------|----------|-----------|
| Tasten-Chrome | `_KeyButton` (`bidozenal/keypad.dart:326-352`) | `_Key` (`kurve/keypad.dart:80-102`) | `_CalcKey` (`wachstum.dart:918-949`) | **~95 % identisch** → teilen |
| Grid-Layout | 3×8 fix | Reihen à 4 | 6er-Chunks, basis-bewusst | **0 % geteilt** |
| Ziffern-Render | `BidozenalGlyph` | `BidozenalGlyph` | `bidozenalChar` (Text, **keine** Glyphen) | gemischt |
| Basis-Limit/Greying | keins | keins (12 fix) | keins | **fehlt überall** — das ist das neue Feature |

Wachstums `_CalcEditSheet` (`wachstum.dart:154-906`) ist bereits ein
basis-umschaltbarer Mini-Rechner (Selektor `:301-310`, Ziffern `:821-871`), nutzt
aber **Text statt Glyphen** und rollt sein eigenes Keypad. Heißt: sobald der
Rechner einen 10/12/24-Selektor + Greying bekommt, brauchen **zwei** Tools dasselbe
basis-bewusste Glyph-Keypad.

**Ausbau Richtung `geometrie_kit`:** Der Kern ist nahezu paket-fertig (reine
Dart-Abhängigkeiten innerhalb `lib/calc/` + Flutter). Empfehlung: ein geteiltes
basis-bewusstes Glyph-Keypad als `lib/calc/keypad.dart` extrahieren (nicht
`lib/widgets/`, weil domänenspezifisch). Kurve bleibt außen vor (Plotter:
Ziffern 0–B + Variable `x`, eigenes Grid), nutzt aber weiter den geteilten
Glyph-Renderer.

---

## Teil 2 — Umbauplan zum Soll-Zustand

**Reihenfolge-Gate (bewusst):** Zuerst die **Rechner-UI selbst** korrekt machen
(Phasen 1 + 2 — ein Rechner, drei Basen, Greying), visuell + per Tests abnehmen.
**Erst danach** und mit eigener Freigabe die **Anbindung/Teilung mit anderen Tools**
(Phase 3 — geteiltes Keypad, Wachstum). Begründung: der Rechner ist die
Referenz-Implementierung; das basis-bewusste Keypad erst zu extrahieren, wenn seine
UX feststeht, vermeidet, eine geteilte API zu refaktorieren, während die
Anforderungen noch wandern (= Churn in zwei Tools gleichzeitig). Deckt sich mit der
Repo-Disziplin „extract when (not before) the second consumer needs it"
(`CLAUDE.md` §Long-term architecture intent).

Sequenziert; nach jedem Phasenende `flutter analyze` + `flutter test` grün halten.
Bei Basis 24 ändert sich nichts am bestehenden Verhalten (reines Durchreichen).

### Phase 1 — Basis durchreichen (multi-base safe, kein Verhaltenswechsel bei 24)
- `lib/calc/keyboard.dart`: `int base` zu `eventForKey`/`charEvent` ergänzen; in
  `charEvent` nach `bidozenalValue(ch)` Guard `if (v == null || v >= base) return null;`.
  Aufrufstelle `bidozenal.dart:75` (`_handleKey`) reicht `base: _base` durch.
- `lib/tools/bidozenal/result.dart`: `formatResult(EvalResult, {int base = kBase})`;
  `:51`/`:67` auf `base` umstellen; `BidozResult` erhält ein `base`-Feld; Call-Site
  `bidozenal.dart:277` reicht `base: _base`.

### Phase 2 — Basis-Modus + Greying im Rechner (der eigentliche Soll-Zustand)
- `bidozenal.dart`: `int _base = 24;` als Instanz-State; `SegmentedButton<int>`
  in `_buildControls` (Muster aus `wachstum.dart:301-310`), Labels
  „Dezimal/Dozenal/Bidozenal" (tool-lokale Strings, keine App-Identität).
- `base: _base` an alle Engine-Calls: `evaluate` (`:268`, `:287`), `formatResult`
  (`:277`), Display, Keypad, Keyboard-Handler (`:75`).
- Keypad-Greying: `BidozenalGlyphPad` + `_DigitKey` bekommen `base`; ein einziges
  Prädikat `isActive = value < base` als Single Source; inaktiv ⇒ gedämpfte Farbe
  (`outlineVariant`/Alpha) **und** nicht tappbar.
- Basis-bewusst machen: Umrechnungs-Panel (`bidozenal.dart:393`), Erklärtext
  (`:412`), Glyph-Chart (`:526`) — Default-Entscheidung im Decision-Block unten.

### Phase 3 — Geteiltes Keypad extrahieren (Ausbau; empfohlen, optional)
- Neu `lib/calc/keypad.dart`: `BaseAwareGlyphKeypad` (rendert alle 24, grau bei
  `value >= base`) + geteiltes Tasten-Chrome (heutiges `_KeyButton`/`_Key`/`_CalcKey`
  zusammenführen). Minimal-API: `{required int base, required void Function(KeypadEvent) onKey, bool useGlyphs = true}`.
- Konsumenten: Rechner + Wachstums `_CalcEditSheet`. Kurve bleibt eigenständig.

### Phase 4 — Tests
- Engine: `evaluate([Digit(1),Digit(0)], base: 10)` → 10, `base: 12` → 12; isolierter
  Dezimal-Pfad.
- Tastatur: `charEvent('A', base: 10)` → null, `base: 24` → `DigitTok(10)`.
- Widget: Greying pro Modus (aktiv vs. grau/disabled) in `test/`.

### Naming-Hygiene (optional, niedriges Risiko)
`bidozenalChar`→`digitChar`, `bidozenalValue`→`digitValue`, ggf. Glyph-Namen — nur
wenn gewünscht; rein mechanisch, entkoppelt die generische Infrastruktur vom Tool.

---

## Teil 3 — Offene Entscheidungen (Owner)

1. **Tool-id/Titel `'bidozenal'`** — beibehalten (24 = nativ, 10/12 = Gäste; null
   Asset-/Doc-Ripple; Disziplin 4) **[empfohlen]** vs. Titel ändern (id bleibt) vs.
   id+Titel ändern (nur falls noch nicht im Store; Version ist `0.1.0+1`).
2. **Persistenz des Selektors** — ephemer wie Glyph-/Winkel-Modus, Default
   Bidozenal/24 **[empfohlen, mirror]** vs. persistiert (neuer prefs-Key).
3. **Geteiltes Keypad** — `lib/calc/keypad.dart` extrahieren **[empfohlen]**;
   Wachstum auf Glyphen umstellen (Konsistenz) vs. Text behalten (leichtgewichtig).
4. **Inaktive Ziffern** — grau **sichtbar** + nicht tappbar **[empfohlen, = „grau und
   funktionslos"]** vs. komplett ausblenden.
5. **Eingabe-Semantik** — Ziffernfolge wird in der **gewählten** Basis interpretiert
   (`„10"` = zehn in Dezimal, zwölf in Dozenal). Das liefert das `base:`-Durchreichen
   automatisch — bestätigen.
6. **Umrechnungs-Panel** (`:393`) — alle drei Basen zeigen vs. nur die nicht-aktiven.
7. **Kurve** — außerhalb des Scopes (Plotter), behält fixe Basis 12. **[empfohlen]**

## Verifikation (nach Umsetzung)
- `flutter analyze` + `flutter test` grün; neue Tests aus Phase 4.
- Visuelle Kontrolle per Linux-Screenshot-Workflow (`CLAUDE.md` §Screenshot):
  alle drei Basis-Modi capturen und **nebeneinander** zeigen (Greying), nicht
  spot-checken.
