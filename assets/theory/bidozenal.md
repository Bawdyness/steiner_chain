# Das bidozenale Zahlensystem

Hand-geschriebene Theorie für den Bidozenal-Rechner. Der vollständige
Entwurf mit allen Tabellen liegt in `docs/bidozenal.md` — diese Fassung
ist auf den In-App-Viewer zugeschnitten (keine Tabellen).

## Die Idee in einem Satz

Die Basis ist $24 = 2 \cdot 12$. Eine bidozenale Ziffer ist ein
Dutzend-Bit plus eine Dozenal-Ziffer: die untere Hälfte $0$ bis $B$ sind
die vertrauten Dozenal-Zeichen, die obere Hälfte $C$ bis $N$ dieselben
Zeichen mit einem $+12$-Marker. Das System erbt die ganze Teilbarkeit von
Dozenal und legt die $8$ und die $24$ obendrauf.

## Die Ziffern

Werte $0$ bis $23$. Über $9$ schreiben wir Buchstaben: $A = 10$, $B = 11$,
$C = 12$, $D = 13$, weiter bis $N = 23$. Mehrstellige Zahlen sind
positionell zur Basis $24$:

$$\text{``10''} = 24, \quad \text{``100''} = 24^2 = 576, \quad \text{``20''} = 48$$

Die Stellenwerte sind also $\dots, 24^3, 24^2, 24, 1$.

## Warum 24 — Teilbarkeit

Der ganze Reiz liegt in der Faktorzerlegung:

$$24 = 2^3 \cdot 3 = 4!$$

$24$ ist hochzusammengesetzt — sie hat mehr Teiler als jede kleinere
Zahl. Die acht Teiler sind $1, 2, 3, 4, 6, 8, 12, 24$. Zum Vergleich:
Basis $10$ hat vier Teiler, Basis $12$ hat sechs, Basis $24$ hat acht.

Entscheidend: $24$ hat dieselben Primfaktoren $\{2, 3\}$ wie $12$. Es
terminieren also *exakt dieselben* Brüche, nur nie länger und oft kürzer.
$1/8$ braucht in Basis $12$ zwei Stellen, in Basis $24$ nur eine.

## Einstellige Kehrwerte

Die Kehrwerte aller Teiler terminieren mit einer einzigen Ziffer — nämlich
der Ziffer $24/d$:

- $1/2 = 0.C$
- $1/3 = 0.8$
- $1/4 = 0.6$
- $1/6 = 0.4$
- $1/8 = 0.3$
- $1/12 = 0.2$
- $1/24 = 0.1$

Die geteilte Schwäche mit Dozenal ist die $5$: sie ist kein Faktor, also
läuft ihr Kehrwert periodisch. Im Rechner wird die Periode überstrichen
dargestellt: $1/5 = 0.\overline{4J}$ — Periodenlänge $2$, kürzer als die
Periodenlänge $4$ in Basis $12$.

## Schöne Eigenschaften

$24$ ist ein Sonderling der Zahlentheorie:

- Alle zu $24$ teilerfremden Ziffern sind prim: $5, 7, B, D, H, J, N$. Und
  $24$ ist die größte Zahl mit dieser Eigenschaft.
- Für jede zu $24$ teilerfremde Zahl gilt $n^2 \equiv 1 \pmod{24}$. In
  Basis $24$ heißt das: das Quadrat jeder solchen Zahl endet auf $1$.
- Kanonenkugel-Identität: $1^2 + 2^2 + \dots + 24^2 = 4900 = 70^2$, und
  $24$ ist die einzige Zahl über $1$, für die die Summe der ersten $n$
  Quadrate wieder ein Quadrat ist.

## Rechnen

Der Preis: das Einmaleins ist $24 \times 24$ statt $12 \times 12$ — rund
viermal so groß. Das ist der reale kognitive Aufwand; deshalb gilt
Dozenal vielen als Sweet Spot.

Der Gewinn liegt bei den Teilbarkeitsregeln:

- Die letzte Ziffer entscheidet über jeden Teiler von $24$. Teilbarkeit
  durch $8$ liest man direkt an der Endziffer ab (Endziffer $0$, $8$ oder
  $G$).
- Die Quersumme modulo $23$ testet die $23$, weil $24 - 1 = 23$ prim ist.
- Die alternierende Quersumme modulo $25$ testet die $5$, weil
  $24 \equiv -1 \pmod{25}$ und $25 = 5^2$. Das ist der saubere Fünfer-Test
  — der Ausgleich dafür, dass $5$ kein Faktor ist.

## Der Einheitskreis

Misst man Winkel in Umdrehungen, wird $1/24$ Umdrehung zu $15°$ und damit
zur bidozenalen $0.1$. Alle $24$ Standard-Striche laufen rund. Der
Vollkreis lässt sich nativ als $576 = \text{``100''}$ legen; dann ist jeder
$15°$-Sektor eine erste Ziffer. Wer das Fünfeck braucht, nimmt
$2880 = \text{``500''}$; wer Vertrautheit will, den Grad-Kreis
$360 = \text{``F0''}$ — denn $360 = 24 \cdot 15$ und $15 = 3 \cdot 5$
liefert genau die $5$, die der reinen Potenz fehlt.
