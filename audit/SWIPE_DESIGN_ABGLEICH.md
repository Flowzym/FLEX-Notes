# Wischen, Größenregler und Symbolbedienung · rebuild.9

Stand: **0.16.0-rebuild.9+29**, 02.11.2026. Weiterentwicklung der erhaltenen
Rekonstruktion auf `fix/dialog-reference-audit`. Die aktuellen Nutzeränderungen ersetzen
an den betroffenen Stellen die vorherige Bedienung und die älteren Referenzberichte.

## Änderungen

| Wunsch / Befund | Verhalten dieses Stands |
| --- | --- |
| Seitenwechsel durch Wischen | Ein horizontaler Flutter-PageView verbindet Übersicht und Schüler. Die Navigationsauswahl folgt dem Wischen; Antippen der Navigation wechselt ebenfalls die Seite. Suche und Scrollpositionen bleiben beim Wechsel erhalten. Vertikales Scrollen, Settings-Regler und offene Dialoge sind davon getrennt. |
| Skalierung und Schriftgröße in Settings | Der Bereich „Größe & Schrift“ steht direkt unter der Live-Vorschau. App-Skalierung 80–120 % in 5-%-Schritten; Schriftgröße 80–160 % in 5-%-Schritten. Separate Werte, direkte Anwendung, automatische Speicherung und gemeinsames Zurücksetzen. |
| Ganze App kleiner/größer | App-Skalierung verändert Layout, Darstellung und Trefferkoordinaten einschließlich Dialogen. Verfügbarer Platz, sichere Ränder und Tastatur-Inset werden passend umgerechnet. Offene Eingaben und Dialogzustände bleiben beim Ändern erhalten. |
| Schriftgröße unabhängig ändern | Der Schriftfaktor verändert den Text zusätzlich zur Systemschrift. Eine nichtlineare Systemskalierung wird weitergereicht. Der bisherige Basisfaktor 0,95 bleibt bestehen; 100 % bewahrt daher die bisherige Basisschrift. |
| Weitere Designoptionen | Feld- und Buttonrundung unter „Buttons & Eingabefelder“, Dialogrundung unter „Dialoge“, jeweils 0–32 px. Standardwerte 14/28/24 px. Vorhandene Kartenrundung, kompakte Abstände, Farben, Transparenz, Hintergrundbilder und Überschriftenschrift bleiben verfügbar. |
| Neue Rundungen tatsächlich anwenden | Standard-Textbuttons, Formularfelder, gemeinsame Tag-/Orga-/HÜ-Eingaberahmen, Modalrahmen und Dialogvorschau verwenden die Werte. Navigationspillen, ausgewählte Tags und kompakte Symbolaktionen behalten ihre jeweilige Form. |
| Orga-Listenwerkzeuge als Symbole | Checkliste, Aufzählung und Nummerierung sind drei Iconbuttons mit Tooltip und zugänglichem Namen. Enter-Fortsetzung, Markierung, Fokus und Checklisten-Häkchen behalten die geprüfte Funktion. Erledigen/Wiederöffnen einer Orga-Aufgabe ist ebenfalls eine Symbolaktion. |
| HÜ abhaken ohne Tagbuttons | Vier Symbole stehen für Offen (Kreis), Vollständig (Häkchen), Teilweise (halbgefüllter Kreis) und Nicht erledigt (Kreuz). Der aktuelle Zustand ist umrandet und als Text „Stand: …“ sichtbar. Tooltip und Screenreader benennen jede Aktion; die Auswahl ist semantisch als zusammengehörige Einzelauswahl markiert. |
| Settings-Rücksetzen passte nicht zu den aktuellen Standardflächen | Einzelne Flächen-Resets verwenden nun die neutralen Standarddeckkräfte von rebuild.8. Das Zurücksetzen der Darstellung erhält die individuell angeordnete Reihenfolge der Karten-Shortcuts, wie im Dialog zugesagt. |

App-Skalierung und Schriftgröße multiplizieren sich für die sichtbare Textgröße. Größere
Werte zeigen weniger Inhalt gleichzeitig. Größenregler bleiben auf der scrollbaren
Einstellungsseite erreichbar. Horizontaler Seitenwechsel gilt für die beiden Hauptseiten;
die drei Settings-Reiter bleiben gezielt bedienbare Reiter, damit Reglergesten nicht
versehentlich die Einstellungsseite verlassen.

Neue Darstellungswerte sind optionale Felder im bisherigen Einstellungs-JSON. Alte
Sicherungen erhalten passende Standardwerte; vorhandene Schriftgrößen bleiben erhalten.
Kein SQL-Schemawechsel und keine Umwandlung der Eintrags-/Entwurfsdaten.

## Ausgeführte Prüfungen

- **157 Flutter-Tests bestanden**, davon **12 neue Tests** in `swipe_design_test.dart`.
  [Gesamtlauf](evidence/swipe-flutter-tests.log).
- [Statische Analyse](evidence/swipe-analyze.log) ohne Befunde.
- [Release-Webbuild](evidence/swipe-web-build.log) mit lokalen Web-Ressourcen erfolgreich.
- **186 direkte Flutter-PNGs** einschließlich der vorhandenen Dialog-/Settings-Matrix und
  18 neuer Ansichten für Designregler, HÜ-Symbole und Orga mit Tastatur-Inset.
  [Renderings](swipe-renderings/), [Dateiindex mit Prüfsummen](swipe-renderings/render-index.json).

Neue Funktionsnachweise: Wischen in beide Richtungen, Navigation durch Antippen, Rückkehr aus
Settings, Suchtext-Erhalt, vertikale Gesten ohne Seitenwechsel, echte Slider-Berührung,
unabhängige Größenwerte, Speichern/Reset, fehlgeschlagene Speicherung mit Rückkehr zum letzten
Wert, alle vier HÜ-Zustände und Erhalt der Nachbaraufgabe/des Kommentars, tatsächliche skalierte
Symbolbreite und Trefferpositionen, umgerechneter Tastatur-Inset sowie Erhalt des offenen Editors.
Der bestehende Datei-Neustart-/Backup-Test wurde um abweichende Werte aller neuen Einstellungen
erweitert. Bestehende Enter-, Fokus-, Schreibkonflikt- und Fehlerprüfungen laufen weiter.

Neue Ansichten: 320/390/1200 px, App-Skalierung 80/100/120 %, Systemschriftfaktor 1/2,
Orga mit 240 px simuliertem Tastatur-Inset. Ein zusätzlicher Extremfall kombiniert bei
320 px **120 % App**, **160 % Text** und **200 % Systemschrift**. Das Formular lässt sich
weiter scrollen und speichern; Wortumbrüche und abgeschnittene einzeilige Feldvorschauen
machen diese Kombination deutlich weniger übersichtlich. Sie wird nicht als optisch
uneingeschränkt geeignet bezeichnet. Die vorhandene Matrix prüft außerdem leere, befüllte
und fehlerhafte Dialogzustände sowie große Schrift mit 280 px Inset.

Die neuen Ansichten wurden direkt gesichtet; verkleinerte Kontaktübersichten dokumentieren
die erneut gerenderte Dialogmatrix. Historische Szenario-Bezeichnungen in Testmanifesten
bezeichnen gegebenenfalls die Einführung des Szenarios, nicht den Quellstand dieser PNGs.
Zwischenläufe und korrigierte Testannahmen stehen unter `evidence/swipe-diagnostics/`.
Maßgeblich ist der abschließende grüne Gesamtlauf.

## Grenzen

Keine Browsertests und kein nativer Windows-/Android-Abnahmelauf. Tastatur und Gesten werden
über Flutter-Tests simuliert; reale Bildschirmtastatur, Browserpersistenz und Windows-Ausführung
der Vorschau sind hier nicht geprüft. Die bekannte Darstellungsgrenze langer Wörter bei sehr
großer Schrift bleibt sichtbar. Die bisherigen Lücken bei Import-Zusammenführung, feldweiser
Konfliktauflösung und geführtem Notfall-Reimport bleiben dokumentiert.

Dies ist eine geprüfte Weiterentwicklung der Rekonstruktion, **keine Freigabe als „originalgetreu“**.
Vorheriger Prüfbericht: [Übersicht, Listen und Modalzugänge](UEBERSICHT_ORGA_ABGLEICH.md).
