# UI-/UX-Abgleich – Version 0.13.0+13, 01.11.2026

Referenz ist die unveränderte `work/FLEX-Notizbuch/FLEX-Notizbuch.html`, identisch
mit dem Upload „FLEX-Notizbuch (37).html“. Verglichen wurden die endgültigen
CSS-Regeln und die aktiven JavaScript-Erweiterungen. Die älteren Regeln innerhalb
von `@layer components` sind nicht die abschließende Gestaltung. Maßgeblich sind
insbesondere `design-system.css`, `review-interface.*`, `pupil-overview.*`,
`settings.*` und `background-image.js` im Original-Unterordner `scratch/`.

Dies ist ein Quellcodeabgleich mit lokalen Flutter-Renderings und Verhaltenstests.
Gemäß Auftrag wurde kein Browser geöffnet. Eine pixelidentische Browser-/Windows-/
Android-Abnahme ist damit nicht belegt. Alle Testdatensätze sind synthetisch.

## Korrigierte Unterschiede

| Punkt | Vorher | Jetzt |
| --- | --- | --- |
| Dialoginhalt | Je Formular 20, 22 oder 24 px auf allen Geräten | Einheitlich 24 px horizontal / 22 px vertikal; bis 700 px Breite 16 px |
| Kopf und Fuß | Weitgehend gleiche Maße auf allen Geräten | Kopf 20/14 px, mobil 12/9 px; Footer 24/12 px, mobil 16/11 px; niedrigere Maße bei wenig Platz |
| Schülerbereich-Kopf | Bereich und Name auch mobil untereinander in einer Zeile mit Aktionen | Mobil Name neben Aktionen, Bereich darunter; Bereich 21 px statt Desktop 24 px; Schülerübersicht mit eigenem 23-px-Namen |
| Dialogtypografie | Serifentitel allein durch vorhandenen Untertitel bestimmt | Expliziter Schülerbereich-/Übersichtsmodus; allgemeine Titel bleiben 18 px Sans |
| Detailfenster | Fast die gesamte verfügbare Höhe | 90 % der Viewporthöhe, innerhalb der verfügbaren Höhe; bis 600 px mobile Vollhöhe |
| Kleine Formulare | Schüler 500, Sicherungen 480/520, Aufgabenkommentar 560 px | Jeweils 430 px; Inhalt scrollt bei schmaler Ansicht/Tastatur |
| Allgemeine Fenster | Klassen-Orga und Importprüfung 640, Papierkorb 680 px | 760 px; Eintrags-/Gruppenformulare bleiben 640 px |
| Gemeinsame Situation | Normaler 640-px-Dialog | Detaildialog mit 1000-px-Grenze und mobiler Vollhöhe |
| Zielüberprüfung | 1000 px | 600 px entsprechend der spezifischen `#goalReviewDialog`-Regel; Detailhöhe bleibt erhalten |
| Bestätigungen | Vier abweichende Material-AlertDialog-Fenster | Gemeinsamer 430-px-Rahmen, gleiche Abstände/Farben, Schließen/Escape entspricht Abbruch |
| Footerstatus | Stets oberhalb der Schaltflächen | Bei ausreichender Breite links neben den Aktionen; auf kleinen Flächen umbrochen |
| Eingabeschrift | Material-Standard konnte 16 px und zusätzliche Laufweite verwenden | 14 px, Zeilenhöhe 1,5 und Laufweite 0; Felder mit 10/12 px Innenabstand |
| Schriftdateien | Roboto und Liberation Serif | Selawik und Gelasio mit passenden Gewichten; OFL-Lizenzen offline im Build |
| Einstellungsgruppen | Abweichende Titel, Material-Aufklapppfeile und fehlende Zusammenfassung | Originaltitel, Erläuterungen und Wertzusammenfassungen; Plus/Minus; Aufklappzustand bleibt erhalten |
| Einstellungen | Pillenreiter und Rückkehr immer zu Darstellung | Drei gleich breite, abgerundete Reiter; Links/Rechts zyklisch, Home/End; aktiver Reiter bleibt beim Seitenwechsel erhalten |
| Karten-Shortcuts | Nur Ziehen | Pfeile nach oben/unten, deaktivierte Endpositionen und Standardreihenfolge; direkt gespeichert |
| Einstellungsfarben | HEX nur in einem Zusatzdialog | HEX direkt neben dem Farbfeld; ungültige Zwischenstände werden angezeigt und nicht gespeichert; gültige Werte aktualisieren Vorschau und Speicherung |
| Schülerfarbe | 32-px-Farbflächen mit 8-px-Abstand; aufgeklappte RGB-Regler | 40-px-Trefferflächen, 26-px-Farbflächen, 4-px-Abstand; zehn Originalfarben plus separater Picker; Abbruch übernimmt nichts |
| Farbwähler | Unterschiedliche Schüler-/Einstellungslösungen | Gemeinsames Farbfeld mit Maus-/Touchauswahl, Regler für Farbton/Sättigung/Helligkeit und HEX; Regler auch per Tastatur bedienbar |
| Hintergrundbild | Maximal 5 MB, auf 1920 px Breite skalierte PNG-Ausgabe | HTML-Grenzen: 12 MiB, 48 MP, lange Kante höchstens 1600 px, keine Vergrößerung, JPEG-Qualität 82 und gegebenenfalls 60 |
| Bildspeichergrenze | 5 MB | Maximal 1.200.000 Zeichen einschließlich JPEG-Data-URL-Präfix; intern weiterhin nur Base64 gespeichert |
| Transparente Bilder | Transparenz blieb erhalten | Wie der Canvas des HTML mit `#203a2d` hinterlegt; EXIF-Drehung berücksichtigt, Metadaten entfernt |

Ungültige Farbtexte aus bereits vorhandenen Schülerentwürfen werden nicht
weggeworfen: Sie können weiterhin korrigiert und mit derselben Schüler-ID
fortgesetzt werden. Bei abgebrochener oder ungültiger Bildauswahl bleibt der alte
Hintergrund gespeichert. Die Bildauswahl kann über eine austauschbare Schnittstelle
lokal mit synthetischen Dateien getestet werden.

## Dialoginventar und Prüfung

| Dialogfamilie | Abgleich / Prüfweg |
| --- | --- |
| Schüler hinzufügen/verwalten, Archivstatus und Konflikte | Kleine Form, zehn Farben, neuer Picker, Entwurf/Schließen/Escape; Widgettests und Desktop-/Mobil-Renderings |
| Schülerübersicht | Eigene Titelmetrik, gemeinsamer Rahmen und Körperabstand; vorhandene Filter-/Such-/Öffnungsabläufe bleiben geprüft |
| Ziele, Sozial-/Arbeitsverhalten, Hausübung | Bereichstitel, aktive Tags im Feld, Favoriten, Bearbeitung und feste Datumsleiste; bestehende Modal-Paritätstests laufen weiter |
| Schüler-/Klassen-Orga | Unterschiedliche Breiten, gemeinsame Eingabe, Termin/Erinnerung weiterhin getrennt; Anlegen/Bearbeiten/Laden/Erledigen und Entwurfschutz geprüft |
| Gruppenerfassung und Empfängerwahl | Körperabstände und Titelrahmen; Bereichswechsel, individuelle Beobachtungen und Empfänger bleiben geprüft |
| Auswahllisten | 640-px-Editor mit gemeinsamen Abständen; Fortsetzen, Umordnen, Favoriten und Konfliktschutz |
| Verlauf und Fassungen | Detailrahmen beziehungsweise allgemeine Fassungsliste; Suche, Datumsfilter, Öffnen und Rücknahme bleiben geprüft |
| Gemeinsamer Kontext | Detailhöhe und mobile Vollansicht; Beteiligte, Kontextentwurf und Versionsschutz |
| Zielüberprüfung | Spezifische Breite plus Detailhöhe; Fortführen/Erreicht/Beendet, Prüftermin und Verlauf |
| Hausübungsnotiz/-verlauf, Aufgabenkommentar | Detail- und kleine Form getrennt; Abgabe, Teilaufgabenstand, Korrektur und Löschen |
| Gesprächsvorbereitung | Detailrahmen, Auswahl und Vorschau, geschützte Textbearbeitung und lokaler Export |
| Papierkorb und endgültiges Leeren | Allgemeine Breite, gemeinsamer Rahmen; Wiederherstellen, Pflichtsicherung und verbindliche Bestätigungen |
| Sicherung exportieren/öffnen, Import prüfen | Kleine Passwortform / allgemeine Importprüfung; Verschlüsselung, Abbruch, Fehler und Übernahmeschutz |
| Verwerfen/Löschen/Konfliktübernahme | Material-Ausnahmen beseitigt; gleiche sichere Entscheidung wie bisher |
| Kalender und Uhrzeit | Eigene kompakte Auswahl bleibt erhalten; Tages-/Zeitauswahl wird durch bestehende Modaltests abgedeckt |
| Farben | Gemeinsamer neuer Picker; getrennte Übernahme/Abbruch und direkte Einstellungswerte |

Die Übersicht beschreibt den geprüften Umfang. Sie behauptet keine vollständige
Pixelgleichheit aller denkbaren Zustände und Textlängen.

## Schriften und verbleibende Unterschiede

Selawik ist Microsofts freie Segoe-UI-Alternative. Gelasio ist auf Georgia-kompatible
Metriken ausgelegt. Proprietäre Segoe-UI-/Georgia-Dateien werden nicht kopiert.
`flutter_app/assets/fonts/SOURCES.json` enthält Quellen, Version/Commit und SHA-256.
Die Original-Schriftdateien dieser freien Projekte wurden nicht verändert.
Abweichende Glyphen, Kerning und Engine-Rasterisierung sind weiterhin möglich.

Der HTML-Farbwähler wird vom jeweiligen Browser/Betriebssystem gezeichnet. Flutter
verwendet einen gemeinsamen Picker; dessen Systemfenster kann daher nicht auf jedem
Gerät identisch aussehen. Gleiches gilt für die Dateiauswahl. Die Größen- und
Qualitätsregeln der Bildaufbereitung stimmen jetzt überein; Browser-Canvas und
Dart-JPEG-Encoder produzieren nicht zwingend identische Pixel oder Dateigrößen.

Weiterhin bestehen produktbezogene Ergänzungen des nativen Datenmodells, etwa
Entwurfs-/Konflikthinweise, Sicherungsprüfungen und separate Schrift-/Lesbarkeitsoptionen.
Die vollständige HTML-Datenmigration, Synchronisation, Scanner und native
Benachrichtigungen sind kein Bestandteil dieses UI-Schritts.

Die Dateiprüfung des eigenständigen Web-Starters wurde ebenfalls auf die neuen
Schriften/Lizenzen umgestellt. Beide Windows-Architekturen sind neu gebaut.

Die tatsächlichen abschließenden Testzahlen, Build- und Prozessprüfungen stehen
in `FLUTTER_STATUS.md`. Das Änderungspaket bezieht sich auf
`FLEX-Notizbuch-Flutter-Verschluesselung-Quellen.zip` (Version 0.12.0+12).
