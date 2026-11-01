# UI-Feinschliff – Version 0.14.0+14, 01.11.2026

Diese Runde verfeinert die bestehende Flutter-Oberfläche. Referenz bleiben die
Originalregeln aus `design-system.css`, `pill-navigation.css`, `cards.js` und
`settings.css` des unveränderten HTML-Prototyps. Die Datenbank und Fachlogik
bleiben auf dem bisherigen Stand; alle Beispiele sind synthetisch.

## Sichtbare Verbesserungen

- Die Schülerleiste trennt Anzahl und Auswahl auf der linken Seite von Hinzufügen
  und Sicherung rechts. Bei schmalen Ansichten kann die Auswahlbeschriftung
  umbrechen. Eine laufende Suche lässt sich mit dem Kreuz direkt zurücksetzen.
  Bis 360 px Breite beträgt der Seitenrand wie in der Referenz 12 px.
- Schülerkarten haben klar erkennbare Hover- und Tastaturzustände. Der Fokus folgt
  dem tatsächlich gewählten Schnellzugriff. Namen verwenden das vorgesehene
  Gewicht 500 und die engere Laufweite. Kartenreihen haben 20 px Abstand und die
  beiden Shortcut-Zeilen 4 px Zwischenraum.
- Fällige Hausübungen und Orga-Aufgaben haben gelbe Zähler wie im HTML. Ab 100
  offenen Einträgen steht sichtbar `99+`; Tooltip und Screenreader behalten die
  genaue Zahl. Erledigte Aufgaben werden nicht mehr als fällig dargestellt.
- Allgemeine Textschaltflächen haben 14-px-Rundungen. Navigation, Auswahlpillen und
  aktive Tags behalten ihre Pillenform. Hover, Tastaturfokus und Gedrücktzustand
  unterscheiden sich; deaktivierte Schaltflächen zeigen keinen aktiven Hoverzustand.
- Eingabefokus und Umrandungen orientieren sich an der jeweiligen Feld-/Buttonfarbe.
  Auch ein weißes Eingabefeld in einem dunklen Dialog erhält einen sichtbaren Rand.
- Die Einstellungen zeigen nur noch eine Überschrift. Gruppen und Einstellungs-
  panels sind deckend wie `--panel-bg` in der Referenz. Ein Hintergrundbild bleibt
  sichtbar, während Texte und Regler auf ruhigen Leseflächen stehen. Die separat
  eingestellten Karten-, Button-, Feld- und Dialogtransparenzen werden nicht verändert.
- Mobile Einstellungsgruppen verwenden kleinere Innenabstände und kürzere
  Werteblöcke. Aufgeklappte Gruppen bleiben beim Reiterwechsel geöffnet.
- In Schüler-/Orga-Eintragsformularen nutzen zwei Speicheraktionen auf dem Handy
  die verfügbare Breite gleichmäßig. Bei großer Schrift und geringer Breite stehen
  sie untereinander. Header-Symbole beanspruchen weniger Platz. Bei eingeblendeter
  Tastatur bleibt die Statuszeile einzeilig; ihr vollständiger Text steht weiterhin
  für Tooltip und Screenreader bereit. Eingabefläche, Datumsleiste und Aktionen
  bleiben ohne den zuvor reproduzierten Überlauf bedienbar.

## Lokal geprüft

Sieben neue Widgetfälle prüfen Suchrücksetzung ohne Datenänderung, Zähler/Fälligkeit,
Tastaturaktivierung mit erhaltenem Entwurf, Einstellungslesbarkeit und Reiterzustand,
320-/390-px-Ansichten mit großer Schrift/Tastatur sowie Feldkontrast beim Speichern.
Die bestehenden Tests prüfen weiterhin die Eintrags- und Sicherungsabläufe.
Abschließende Ergebnisse und Build-/Startnachweise: `FLUTTER_STATUS.md`.

Alle bisherigen Ansichten werden mit der Flutter-Engine neu gerendert. Hinzu kommen:

- `64-einstellungen-bild-grosse-schrift-mobil.png`
- `65-schuelerkarte-tastaturfokus-desktop.png`
- `66-dialog-grosse-schrift-tastatur-320.png`

Es gibt weiterhin keine Browser- oder native Windows-/Android-Geräteabnahme.
Der HTML-Prototyp wurde nicht im Browser gerendert; pixelgenaue Gleichheit ist
nicht bestätigt. Ersatzschriften und Plattformpicker bleiben die im vorigen
Abgleich beschriebenen Unterschiede.

Die Auslieferung enthält vollständige Quellen, neue/geänderte Quellen gegenüber
`FLEX-Notizbuch-Flutter-UI-Abgleich-Quellen.zip`, die gebaute Webvorschau mit
Windows-Startern sowie die direkten Flutter-Ansichten. Alle Pakete haben
SHA-256-Manifeste. Die 145 Originaldateien werden bytegleich geprüft.

## Suchbutton – Version 0.14.1+15

Auf Wunsch ist die Schülersuche jetzt zunächst verborgen. Die Lupe links neben
Hinzufügen und Datensicherung öffnet die Suchleiste und setzt direkt den
Eingabefokus. Erneutes Anklicken des nun als Schließen markierten Buttons
blendet die Leiste aus und leert den Filter. Das Kreuz im Suchfeld leert nur den
Suchtext und lässt die Eingabe geöffnet und fokussiert. Das gilt auch im Archiv.

Die vorhandenen Widgetprüfungen decken Öffnen, Fokus, Eingabeverbindung, Filtern,
Leeren, Schließen und erneutes Öffnen sowie schmale Ansichten mit großer Schrift
ab. Die Ansichten 02/06 zeigen die eingeklappte Suche; 67/68 die geöffnete Suche
auf Desktop und Handy. Keine Datenbank- oder Fachlogikänderungen.
