# Das Bidozenale Zahlensystem (Basis 24)

Konzept- und Design-Fundament für eine mögliche eigenständige App. Gewachsen aus
dem Dozenal-Rechner (Basis 12), aber als eigenes System gedacht. Dieses Dokument
ist bewusst portabel — es hängt an keinem Code dieses Repos außer dem Glyphen-
Vorschau-Skript `tool/preview_glyphs.dart` (rendert das Zeichen-Sheet als PNG).

Arbeitsname: **Bidozenal** (= „zwei Dutzend", Dozenal + ein High-Bit).
Fachbegriff: *tetravigesimal*.

---

## 1. Idee in einem Satz

Basis 24 = `2 × 12`. Eine Bidozenal-Ziffer ist ein **Dutzend-Bit + eine
Dozenal-Ziffer**: die untere Hälfte (0–11) sind die vertrauten Dozenal-Zeichen,
die obere Hälfte (12–23) dieselben Zeichen mit einem „+12"-Marker. Das System
erbt die ganze Teilbarkeit von Dozenal und legt die **8** (und 24) obendrauf.

---

## 2. Ziffern und Notation

Werte 0–23. Über 9 werden Buchstaben verwendet:

| Wert | 0–9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Buchstabe | 0–9 | A | B | C | D | E | F | G | H | I | J | K | L | M | N |

Mehrstellige Bidozenal-Zahlen sind positionell zur Basis 24:
`"10" = 24`, `"100" = 576 = 24²`, `"20" = 48`. Stellenwerte: …, 24³=13824,
24²=576, 24, 1.

### Glyphen-System

Schriftlos gezeichnet (reines Vektor-Rendering), drei Bauteil-Familien. Die
„+12"-Beziehung ist **sichtbar** in der Form:

- **Striche (Pfeile/Dreiecke), Werte ≡ 1 mod 3:**
  - 1/4/7/10 = offene Chevrons ↑ ← → ↓.
  - 13/16/19/22 = **dieselben Richtungen als geschlossene Dreiecke** (= +12).
    Regel: *offener Chevron → Dreieck schließen*.
- **Komposita aus stehenden Halbkreisen `(` `)` und Vollkreis `O`:**
  - 2=`)/(`, 3=`)/)`, 5=`(/)`, 6=`(/O`, 8=`O/(`, 9=`O/)`, 11=`)/O`.
  - 14/15/17/18/20/21/23 = **exakte Kopie + kleiner Kreis in der Mitte** (= +12).
    Regel: *Kompositum → Mittelkreis hinzufügen*. (14←2, 15←3, 17←5, 18←6,
    20←8, 21←9, 23←11.)
- **Reine Kreise (neutral zu beiden Welten):**
  - 0 = ein Kreis `O`. 12 = zwei Kreise `O/O` (die „klassische 8", als
    Brücke an die Naht 11→12 verschoben).

Hinweis zur Verschiebung: Damit `O/O` als Brücke bei Wert **12** sitzt (reine
Kreise = neutral, siehe Abschnitt 7), wurde Wert **8** auf `O/(` umgesetzt — ein
im stehenden Raster zuvor ungenutzter Slot. Das Set 0–11 bleibt so „rein
stehend"; `O/O` markiert die Systemgrenze.

Zwei einfache „+12"-Regeln also: **Strich → schließen**, **Halbkreis-Zeichen →
Mittelkreis**.

### Tastatur-/Keypad-Layout

3 Spalten, von unten nach oben gezählt (wie ein Tasten-Block):

```
22  23   0      ← oben; 0 = ganz oben rechts
19  20  21
16  17  18
13  14  15
10  11  12
 7   8   9
 4   5   6
 1   2   3      ← unten links = 1
```

Wert an (Zeile von unten r, Spalte c) = `(r·3 + c + 1) mod 24`. **Spalte 1 ist
durchgehend die Strich-Spalte** (1·4·7·10·13·16·19·22).

---

## 3. Warum 24 — Teilbarkeit

`24 = 2³ · 3`. **Teiler: 1, 2, 3, 4, 6, 8, C(12), N+1(24)** — acht Stück.

| Basis | Faktoren | #Teiler |
|---|---|---|
| 10 | 2·5 | 4 |
| 12 | 2²·3 | 6 |
| **24** | **2³·3** | **8** |
| 60 | 2²·3·5 | 12 |

24 erbt **alle** Dozenal-Teiler und gewinnt **8** und **24**. Die Kehrwerte
aller Teiler terminieren einstellig, elegant als Ziffer `24/d`:

| Bruch | 1/2 | 1/3 | 1/4 | 1/6 | 1/8 | 1/C(12) | 1/24 |
|---|---|---|---|---|---|---|---|
| bidoz | 0.C | 0.8 | 0.6 | 0.4 | 0.3 | 0.2 | 0.1 |

**Wichtig:** 24 hat dieselben Primfaktoren `{2, 3}` wie 12. Es terminieren also
*exakt dieselben* Brüche (Nenner aus 2ern und 3ern), nur **nie länger und oft
kürzer**. `1/8` braucht in Basis 12 zwei Stellen, in Basis 24 nur eine.

**Geteilte Schwäche mit Dozenal:** keine **5**. `1/5, 1/A, 1/F, 1/K` sind
periodisch. Beispiel `1/5 = 0.[4J]` (Periode 2 — kürzer als Dozenals Periode 4).

### 24 ist ein Sonderling der Zahlentheorie

- **24 = 4!** und ist **hochzusammengesetzt** (mehr Teiler als jede kleinere Zahl).
- **Alle teilerfremden Ziffern sind prim:** 5, 7, B, D, H, J, N (= 5,7,11,13,17,
  19,23) sind ausnahmslos Primzahlen — und **24 ist die größte Zahl mit dieser
  Eigenschaft**.
- **Quadrate enden auf 1:** für jede zu 24 teilerfremde Zahl gilt `n² ≡ 1 (mod 24)`.
  Bidozenal: das Quadrat jeder Zahl ohne gemeinsamen Faktor mit der Basis endet
  auf die Ziffer **1**. Auch hier ist 24 die größte Basis mit dieser
  Universal-Eigenschaft.
- **Kanonenkugel:** `1² + 2² + … + 24² = 4900 = 70²` — und 24 ist die einzige
  Zahl > 1, für die die Summe der ersten n Quadrate selbst ein Quadrat ist.

---

## 4. Rechnen

**Kosten:** Das Einmaleins ist 24×24 statt 12×12 — flächenmäßig ~4× so groß.
Das ist der reale kognitive Preis; deshalb gilt Dozenal vielen als „Sweet Spot".

**Teilbarkeitsregeln (Gewinn):**
- **Letzte Ziffer** entscheidet über Teilbarkeit durch jeden Teiler von 24
  (2, 3, 4, 6, 8, C, 24), weil `24 ≡ 0`. Insbesondere **Teilbarkeit durch 8
  liest man direkt an der letzten Stelle ab** (Endziffer ∈ {0, 8, G}).
- **Quersumme mod 23** testet 23 (weil `24−1 = 23`, prim) — „Aus-23-Werfen".
- **Alternierende Quersumme mod 25** testet 5 und 25 (weil `24+1 = 25 = 5²`,
  da `24 ≡ −1 mod 25`). Sauberer 5er-Test — der Ausgleich dafür, dass 5 kein
  Faktor ist. (Dozenal kann das nicht: `12+1 = 13` ist prim.)
- Für 7 und 11 gibt es keine einfache Regel (wie 7 in Basis 10).

---

## 5. Verhältnis zum Dozenal-System

- `24 = 2 · 12`; die Basis selbst ist im Dozenal „**20**".
- **Glyphen-Einbettung:** Eine Bidozenal-Ziffer = (Hoch-Dutzend-Bit) +
  (Dozenal-Ziffer). Der +12-Marker *ist* das High-Bit. Bidozenal ist damit auf
  Symbolebene ein **binär erweitertes Dozenal**.
- **Umrechnung 12 ↔ 24 ist kein reines Umgruppieren** (anders als Binär↔Hex),
  weil weder 12 noch 24 eine Potenz der anderen ist — es braucht echtes Rechnen.
- **Gros-Resonanz:** `144 = 12² = ein Gros` = bidoz „60" = Viertelkreis (s.u.).
  Der Vollkreis `576 = 4 Gros = "100"`.

---

## 6. Der Einheitskreis

Miss in **Umdrehungen** (1 = voller Kreis) und entwickle bidozenal:
`1/24 Umdrehung = 15° = bidoz 0.1`. Damit werden alle Standardwinkel zu
einstelligen Bidozenal-Brüchen einer Umdrehung; die 24 Striche laufen rund:

```
00 10 20 30 40 50 60 70 80 90 A0 B0 C0 D0 E0 F0 G0 H0 I0 J0 K0 L0 M0 N0 → 100
```

Mit dem +12-Marker heißt „erste Ziffer ∈ C…N" automatisch **untere
Kreishälfte** (180°–345°) — die Glyphe sagt, in welcher Hälfte du bist.

### Welches Kreismaß (statt dez 360 / 400)?

Fundamentale Spannung: **runde Winkel-Numerale** bekommt man nur mit einer
**24-Potenz** (dort wird jedes 1/24 zu „X0"); die **5** (Fünfeck) bekommt man
nur mit einem Faktor 5, der die Rundung bricht.

| Kreis = | dez | bidoz | Faktoren | #Teiler | pro Einheit | 5? | 15°-Tick rund? |
|---|---|---|---|---|---|---|---|
| Grad | 360 | F0 | 2³·3²·5 | 24 | 1° | ✓ | nur Vielfache von 24° |
| Neugrad | 400 | — | 2⁴·5² | 15 | 0.9° | ✓ (kein 3!) | — |
| **Rein bidozenal** | **576** | **100** | 2⁶·3² | 21 | 0.625° | ✗ | **ja** (n·15° = „n0") |
| Bidoz + Fünf | 2880 | 500 | 2⁶·3²·5 | 63 | ⅛° | ✓ | Vielfache von 24-Einheit |
| Hochteilbar | 720 | 160 | 2⁴·3²·5 | 30 | 0.5° | ✓ | nein (90° = „7C") |

**Empfehlungen je nach Priorität:**
- **Runde Winkel, native Lesbarkeit:** `576 = "100"`. Erste Ziffer = 15°-Sektor
  (0…N, die 24 Ticks), zweite Ziffer = Feinposition (0.625°-Schritte). Viertel-
  kreis = „60" = 1 Gros.
- **Runde Winkel + Fünfeck:** `2880 = "500"` (= 5·576). 72° = „100", 36° = „C0",
  Einheit ⅛°.
- **Maximale Teilbarkeit (HCN über 576):** `720 = "160"` (= 6!, 30 Teiler, ½°,
  `1° = 2 Einheiten`). Holt 5/A/F-Teilung, opfert aber runde Numerale.
- **Vertraut & überraschend bidozenal-tidy:** `360 = "F0"` (siehe Abschnitt 7).

---

## 7. Die Versöhnung mit 5 und A(10) — 360 als Botschafter

In reinem Bidozenal sind 5 und A **Gäste, nie Bewohner**: `1/5`, `1/A` laufen
als unendliche Perioden, keine feste Adresse. Auf dem **360-Kreis** bekommen sie
eine: `1/5 Umdrehung = 72°`, `1/A = 36°` — ganzzahlig. Was als *Zahl* heimatlos
ist, wird als *Winkel* sesshaft.

Die Versöhnung steckt in einem Symbol:

> **360 = „10" × „F"** (bidoz) = 24 × 15, und **F = 15 = 3·5**.

Die beiden Faktoren des Kreises — Zahl der Ticks (`24 = "10"`) und Grad pro Tick
(`15 = "F"`) — sind beide saubere Einzelsymbole. „F0" liest sich als „F pro 10",
also 15 pro 24: genau die Uhr-/Tierkreis-Geometrie, mit der Basis 24 verschwistert
ist. Und `F = 3·5` liefert exakt das, was der reinen 24-Potenz fehlt: ein
zusätzliches 3 *und* die 5.

Historische Linie: `60 = 2²·3·5 = bidoz "2C"` war der babylonische Friedensschluss
zwischen den Zahlwelten; `360 = 6·60` ist sein Kreis-Kind. Geometrisch lädt
*gerade der Kreis* die 5 ein, weil im Kreis das **Fünfeck** wohnt (goldener
Schnitt, Ikosaeder, Dodekaeder) — ohne 5 wäre Bidozenal für diese Formen blind.

Fazit: 360 ist kein Fremdkörper, sondern der diplomatischste Schnittpunkt von
„vertraut", „hochteilbar" und „bidozenal-darstellbar" — der Grad-Kreis war die
ganze Zeit halb bidozenal.

---

## 8. Mögliche App-Bausteine

Was sich besonders mit Basis 24 verschwistert: alles **Kreisförmige und
Geteilte**.

1. **Bidozenal-Rechner** — Geschwister des Dozenal-Rechners: gleiche Zwei-
   Schienen-Auswertung (exakter Rational + f64), aber Basis 24, mit dem
   Glyphen-/Marker-System und dem 24-Tasten-Keypad.
2. **Winkel- / Geometrie-Werkzeug** — Einheitskreis mit wählbarer Konstante
   („100"/„500"/„F0"), Live-Umrechnung Grad ↔ Bidozenal-Umdrehung, Vielecke,
   Marker = untere Hälfte.
3. **Tageszeit** — der Tag hat 24 Stunden; die **Stunde ist eine Ziffer**, der
   Tag = „10", Mittag = 0.C Tag, 6 Uhr = 0.6 Tag. (Ehrlich: Minuten bei 60
   brechen das Muster.)
4. **Mikrotonale Musik** — 24-EDO = Vierteltöne; jeder Schritt = eine Ziffer,
   Oktave = „10", Marker trennt die obere mikrotonale Hälfte.
5. **Maße & Brüche** (Werkstatt/Küche) — drei Halbierungen (24→12→6→3) *und*
   saubere Drittel; 24 Portionen gehen auf 2,3,4,6,8,C Personen auf.
6. **Zahlentheorie-Explorer / Lern-App** — die Muster live zeigen: „Quadrate
   enden auf 1", „Teilerfremde sind prim", Teilbarkeitsregeln, Periodenlängen.

### Design-Entscheidungen für die App

- **Kreis-Konstante:** Default `576 = "100"`; optional `2880`/`360`. (Abschnitt 6.)
- **Anzeige:** Glyphen vs. konventionell (Buchstaben A–N). Wie der Dozenal-
  Rechner: Display umschaltbar, Keypad bleibt Glyphen (Markenidentität).
- **Eingabe >9 auf Hardware-Tastatur:** Buchstaben a–n auf Werte 10–23 mappen.
- **Umrechnung 12↔24 / 10↔24:** braucht echte Basis-Arithmetik (kein
  Digit-Regrouping). Konverter parametrisieren (`base`), wie im Dozenal-Repo
  bereits angelegt.
- **Keypad:** 24 Zifferntasten — entweder 3×8 (Layout oben) oder 6×4.

---

## 9. Schnellreferenz

- Basis `24 = 2³·3 = 4!`, hochzusammengesetzt, 8 Teiler.
- Ziffern `0–9, A–N` (A=10 … N=23). `"10" = 24`, `"100" = 576`.
- +12-Glyphenregel: Strich → Dreieck schließen; Halbkreis-Zeichen → Mittelkreis;
  reine Kreise 0 & 12.
- Einstellige Kehrwerte: `1/2=0.C, 1/3=0.8, 1/4=0.6, 1/6=0.4, 1/8=0.3, 1/C=0.2,
  1/24=0.1`. Keine 5 (`1/5 = 0.[4J]`).
- Teilbarkeit: letzte Ziffer (Teiler von 24), Quersumme mod 23, alternierende
  Quersumme mod 25 (→ 5).
- Einheitskreis: `15° = 0.1` Umdrehung; Vollkreis nativ `576 = "100"`,
  fünf-tauglich `2880 = "500"`, vertraut `360 = "F0" = "10"·"F"`.

---

## 10. Zeichen-Sheet erzeugen

```bash
flutter test tool/preview_glyphs.dart   # → store/glyph_preview.png
```

Selbst-enthaltenes Wegwerf-Skript (kopiert die Mal-Primitive lokal, importiert
nichts aus `lib/`). Es ist die Iterations-Schleife für das Glyphen-Design und der
Ausgangspunkt für den Painter einer künftigen Bidozenal-App.
