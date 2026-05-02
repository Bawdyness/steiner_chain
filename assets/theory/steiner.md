# Aufbau

Stell dir zwei Kreise vor, einer im anderen — ein größerer aussen und
ein kleinerer innen. Zwischen die beiden passt eine Kette aus $n$
weiteren Kreisen, und zwar so, dass jeder Kreis der Kette

- den Außenkreis von innen berührt,

- den Innenkreis von außen berührt,

- und seine beiden Nachbarn in der Kette berührt.

Im einfachsten Fall sitzt der innere Kreis genau im Mittelpunkt des
äußeren, und alle Kettenkreise sind gleich groß. Verschiebt man den
Innenkreis aus der Mitte, werden die Kettenkreise unterschiedlich groß —
aber alle Berührungen bleiben erhalten. Die App zeigt diese Verschiebung
über den Schieberegler „Verschiebung“.

# Der symmetrische Fall

Solange beide Kreise denselben Mittelpunkt haben, ist die Rechnung
überschaubar. Wir setzen den Außenkreis auf Radius $1$ (das ist nur eine
Wahl der Einheit). Die $n$ Kettenkreise liegen auf einem gemeinsamen
Mittelpunkts-Kreis und sind alle gleich groß.

Vom Zentrum aus gesehen liegt zwischen zwei benachbarten
Kettenkreis-Mittelpunkten der Winkel $2\pi/n$. Die Bedingung, dass sich
Nachbarn gerade berühren, übersetzt sich in eine einfache Gleichung mit
dem Sinus des halben Winkels. Daraus folgen direkt geschlossene Formeln
für die drei wichtigen Radien — den des inneren Kreises, den der
Kettenkreise und den Bahnradius, auf dem ihre Mittelpunkte sitzen:

$$r_{\text{in}}=\frac{1-\sin(\pi/n)}{1+\sin(\pi/n)},\qquad r_{\text{Kette}}=\frac{1-r_{\text{in}}}{2},\qquad r_{\text{mid}}=\frac{1+r_{\text{in}}}{2}.$$

Der innere Kreis bekommt dabei automatisch den richtigen Radius — die
Kettenkreise berühren ihn, ohne dass wir das gesondert verlangen.

# Steiner’s Porism

Hier kommt das Schöne. Sobald für ein bestimmtes Paar von Kreisen (außen
und innen) überhaupt eine geschlossene Kette aus $n$ Gliedern existiert,
kann man sie um beliebige Winkel „drehen“ — und sie bleibt immer
geschlossen. Es gibt keinen ausgezeichneten Startpunkt.

Andersherum: ändert man die beiden Begrenzungskreise, ist nicht
garantiert, dass eine Kette mit $n$ Gliedern überhaupt passt. Aber wenn
sie passt, dann passt sie für jede Drehung. Ob die Kette schließt, hängt
also nur von der relativen Geometrie der beiden Begrenzungskreise ab,
nicht vom Startwinkel. Genau das nennt man Steiner’s Porism.

Beim Schieberegler „Rotation“ in der App siehst du diese Eigenschaft
direkt: die Kette läuft endlos rund, ohne je „aufzubrechen“.

# Möbius-Transformation

Bei der exzentrischen Variante — Innenkreis nicht im Zentrum — wirken
die Rechnungen auf den ersten Blick deutlich unangenehmer. Es gibt aber
einen Trick, der sie auf den symmetrischen Fall zurückführt: eine
bestimmte Möbius-Transformation der komplexen Ebene. Konkret die
Abbildung

$$f(z)=\frac{z+a}{1+a\,z},\qquad a\in(-1,1)$$

mit einem reellen Parameter $a$. Diese Abbildung hat zwei Eigenschaften,
die alles andere möglich machen:

- Sie bildet die Einheitskreisscheibe auf sich selbst ab — der Außenrand
  bleibt also unverändert dort, wo er ist.

- Sie schickt jeden Kreis im Inneren wieder auf einen Kreis (nicht etwa
  auf eine Ellipse), und sie erhält Tangentialitäten — wenn sich zwei
  Kreise vorher berührt haben, tun sie das auch nachher.

Was heißt das praktisch? Wir können die Steiner-Kette zuerst im
symmetrischen Fall berechnen, danach jeden Punkt durch $f$ schicken, und
erhalten dadurch automatisch eine gültige exzentrische Kette. Der
Slider „Verschiebung“ steuert genau den Parameter $a$. Die Anzahl der
Kreise, alle Berührungen und die Geschlossenheit bleiben erhalten — wir
sehen also Steiner’s Porism in einer anderen Verkleidung.

Genau aus diesem Grund werden in der App nicht direkt Kreise gezeichnet,
sondern für jeden Kreis 64 Punkte auf seinem Rand berechnet, durch $f$
transformiert und als Polygon verbunden. Das Ergebnis sieht aus wie ein
Kreis — und ist es auch, denn die Möbius-Abbildung garantiert das.
