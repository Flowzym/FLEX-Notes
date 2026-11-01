# App-Details aus der nachgereichten Übergabe

Quelle: vom Nutzer als „Eingefügter Text.txt“ bereitgestellte Angaben aus dem
alten Chat. Der Auftrag im ersten Absatz, ein Übergabe-ZIP zu erzeugen, wurde
vom Nutzer ausdrücklich aufgehoben. Dieses Dokument hält die App-Details und
ihren Nachweisstatus fest; es enthält keine wiedergefundenen Originalquellen.

## Referenz und Vorrang

- Erhaltene Original-Web-App: **0.15.3+19**; Originalquellen: **0.1.0+1**.
- **0.16.0+20** war ein Arbeitsstand im alten Chat. Seine Quellen, sein finaler
  Web-Build und die dort genannten Downloadpakete sind hier nicht verfügbar.
- Für UI und UX gelten das endgültige HTML/CSS, die Dokumente von 0.15.3 und
  danach die ausdrücklich neueren Wünsche aus der Übergabe.
- Die spätere Modalregel ersetzt ältere mobile Vollbildregeln: Außenabstand
  mobil **10 px**, Desktop **16 px**, Radius **24 px**, Standard-Maximalbreite
  **640 px**. Auch Ziele und HÜ bleiben Modals. Hauptseiten bleiben Hauptseiten.
- Tests verwenden synthetische Daten. Flutter-Renderings, lokale Tests, Builds
  und Prozessstart sind erlaubt; Browsertests sind ausgeschlossen.

## Sichtbarer Aufbau

- Zentrierte Pillen **Übersicht / Schüler / …**. Keine Seitenleiste und keine
  zusätzliche untere Navigation; aktive Pille angehoben und deutlich erkennbar.
- Schülerkarten: farbiger Rand, Name in Serifenschrift, Pfeil, fünf gefüllte
  Symbole. Erste Reihe **Ziele / Sozial / Arbeit**, zweite **HÜ / Orga**.
- Suche zunächst verborgen; Lupe neben Neuer Schüler und Datensicherung.
  Öffnen setzt Textfokus. Leeren erhält die offene Suche; Schließen leert sie.
- Schülerübersicht gliedert sich in Anstehend, Noch ergänzen und Zuletzt.
- Einheitliche Eintragsdialoge, kompakter Entwurfsstatus, erreichbare Aktionen
  bei schmalem Bildschirm und eingeblendeter Tastatur.
- Eingabefelder und aktive Tags folgen dem HTML-Prototyp. Kalender enthält die
  optionale Uhrzeit direkt; kein eigener Uhrzeit-Schalter.
- Zeitpunkt-Tags exakt: **Vor Unterricht / Unterricht / Nach Unterricht / Pause**.
- Optionaler Abschnitt **Kontext / Quelle**, Feld **Reaktion / Unterstützung**.
  Keine Zwischenüberschrift „Weitere Angaben“. Schülerauswahl als Tags.
- Kopf und Fuß der Dialoge gemeinsam einfärbbar; Flächenfarben/Transparenz und
  ausgewählte Buttons müssen lesbar bleiben. Hintergrundbilder für Desktop und
  Mobil getrennt, mit verschiedenen Bildmodi.

## Hausübung und Entwürfe

- Vier direkte Standbuttons: **Offen / Vollständig / Teilweise / Nicht erledigt**.
  Die Auswahl speichert über den vorhandenen Revisionsweg. Derselbe Stand oder
  schnelle Doppelklicks dürfen keine zusätzliche Historie erzeugen.
- Speicherfehler erhalten den vorherigen Stand und zeigen einen verständlichen
  Fehler. Kommentare, andere Aufgaben und deren IDs/Zustände bleiben erhalten.
- Bereits vorhandene Kommentare sind erkennbar. Eine eigene Sprechblase öffnet
  **Kommentar**, setzt Textfokus und zeigt den aktuellen Stand nur als Information.
- Kommentarmodus und Schüler-Tags bleiben beim Fortsetzen eines Entwurfs erhalten.
  Ein Kommentar darf einen inzwischen geänderten Stand nach einer ausdrücklich
  bestätigten Konfliktübernahme nicht zurücksetzen.
- `notchecked` und `absent` sind historische Sonderwerte; sie dürfen bei einer
  späteren kompatiblen Übernahme nicht still zu „Offen“ werden.
- Im alten Code hieß das optionale boolesche Feld `commentOnly`; die heutige
  Rekonstruktion nutzt einen eigenen Entwurfsmodus und ein eigenes Payloadformat.
  Gleiches Verhalten beweist keine Austauschbarkeit dieser Datenformate.

## Fachliche Regeln

- Orga umfasst Notizen, Aufgaben, Checklisten und unabhängige Erinnerungen.
- Aufgabe erledigen beendet die zugehörige Erinnerung; Erinnerung quittieren
  erledigt die Aufgabe nicht. Klassen-Orga funktioniert ohne Schülerzuordnung.
- UI, Fachlogik und Speicherung bleiben getrennt. Synchronisation und Scanner
  sind spätere Ausbaustufen. Bestehende Datenformate werden nicht ungeprüft ersetzt.

## Fehlende Originaldateien und historische Prüfungen

Die beschriebenen Original-Screenshots A–E, beide grünen Tafeltexturen und die
Flutter-Renderings 75–80 sind nicht mit diesem Text übertragen worden. Es gibt
keinen bestätigten lokalen Fund dieser Bilder. Die Icon-Vorlage war separat im
Chat sichtbar; die neu gezeichneten Flutter-Symbole sind kein Original-Bildasset.
Der vorhandene HTML-Farbverlauf ist eine belegte Darstellung, keine Ersatztextur,
die als ursprüngliches Nutzerbild ausgegeben werden darf.

Die genannten 35 gezielten Tests, sieben neuen Tests und die erwartete Suite mit
326 Tests sind historische Protokollangaben. Sie zählen nicht als bestandene Tests
der Rekonstruktion. Maßgeblich sind ausschließlich neu ausgeführte Prüfungen.

## Erster korrigierter UI-Schritt

Die Pillennavigation, Schülerkarten in 3+2-Anordnung, Suchbedienung, Schülerbereiche
als Modals, neuen Rahmenmaße, direkte Uhrzeitfelder und kompaktere Fachlisten sind
im aktuellen Code umgesetzt. HÜ-Doppelklicks, gleiche Standwahl, Fehler/Wiederholung,
Kommentarerhalt sowie Schrift/Farbe ausgewählter Chips sind zusätzlich geprüft.

Noch kein vollständiger UI-/Funktionsabgleich: unter anderem Aufklappverhalten der
HÜ-Karten, „Speichern & weiter“, vollständige Auswahllisten/Favoriten, gemeinsame
Kontexte und Gruppenabläufe, vollständige Stammdatenentwürfe sowie explizite
Konfliktübernahme mit Kommentar-Rebase bleiben offen. Historische Sonderwerte und
das alte optionale `commentOnly`-Feld sind nicht als Originalformat importierbar;
unbekannte Payloads werden derzeit abgewiesen und nicht still umgewandelt.
Die großen Anfangsabweichungen sind damit konkret korrigiert, aber ein visueller
Abgleich mit tatsächlich übertragenen Original-Screenshots steht weiterhin aus.
