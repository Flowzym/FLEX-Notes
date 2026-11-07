# UI-Prüfung und Überarbeitung · Build 49

Prüfung vom 7. November 2026. Version `0.16.0-rebuild.29+49`.

## Bewertung aus Nutzersicht

Die fünf Hauptbereiche geben eine brauchbare Orientierung. Die Schülerkarten
und der schnelle Einstieg in eine Beobachtung sind bereits kompakt. Am meisten
Unruhe entstand durch wiederholte Werkzeugleisten, doppelte Inhalte und zu viele
gleich stark gestaltete Verwaltungsaktionen. Diese Stellen wurden überarbeitet,
ohne Funktionen in zusätzliche Menüs zu verlagern.

| Bereich | Befund und Ergebnis |
| --- | --- |
| Live / Aktuell | Volle Listen mit Aufgaben, HÜ, Zielen und Terminen geprüft. Kompakte Zusammenfassungen und Anlegeaktionen bleiben erhalten. |
| Schüler / Notizen | Zwölf synthetische Schüler, lange Namen, mehrere Eintragsarten und offene Aufgaben geprüft. Im Schülerdialog stehen Dokumente, Suche und Anlegen zusammen; Alle / Noch offen / Abgeschlossen sind unmittelbar sichtbar. |
| Orga und allgemeine Aufgaben/Notizen | Identische Überschrift und Notiz werden nicht doppelt angezeigt. Anhänge, Scan, Wiederholung, Erinnerung, Verlauf und Papierkorb teilen eine kompakte Symbolleiste. Aufgaben lassen sich direkt am Statussymbol abhaken und wieder öffnen. Suche und Anlegen stehen beim Titel. |
| Kalender / Stundenplan | Tages-, Wochen- und Monatsansicht, Wechsel zum Stundenplan, Terminbearbeitung, Zeitmarkierung und große Schrift durch vorhandene Tests und Renderings geprüft. Die Wochenansicht darf bei sehr großer Schrift horizontal scrollen. |
| Rückläufe | Überschrift, Suche und Anlegen bilden eine gemeinsame Zeile; das Suchfeld öffnet bei Bedarf. Statusfilter bleiben sichtbar. |
| Materialien / Bereitgelegt / Pakete / Planungen | Jede Unterseite hat einen passenden Titel und ihre eigene Anlegeaktion. Dateiimport, Scan und Linkanlage stehen im Dateienbereich. OneDrive, Suche, Mehrfachauswahl und Sicherungen bleiben erreichbar. Die Paketseite wiederholt nicht mehr die komplette Datei-Werkzeugleiste. |
| Scanner und Anhänge | Raster/Liste, Vorschauen, Filter, Reihenfolge, Ersetzung, Schwärzung und Zuordnung sind durch die Scanner-Suite abgedeckt. Die Überschrift der Verwaltung bleibt auch bei großer Schrift lesbar; Einzahl „1 Datei“ korrigiert. |
| Mehr / Archiv / Papierkorb / Daten / Einstellungen | Navigation und Dialoge in kleinen und großen Ansichten geprüft. Export und Import zeigen jeweils die passenden Einstellungen. Ein Import in eine frische App mit vorinstalliertem Stundenplan nutzt das Zusammenführen; der vorhandene Stundenplan bleibt erhalten. |

## Anpassung an Bildschirm und Schrift

Die neue Prüfung nutzt 390 × 844, 320 × 740 bei 180 % Schriftgröße,
768 × 1024 sowie 1280 × 900 Pixel. Alle 19 Unterseiten werden mit gefüllten
Beispieldaten geöffnet. Dazu kommen die vier schulischen Eintragseditoren,
Notiz/Aufgabe/Termin und eine simulierte Bildschirmtastatur. Bestehende Tests
prüfen zusätzlich 200 % Schriftgröße und erhöhte App-Skalierung.

Überschriften und Aktionen erhalten bei Platzmangel getrennte Zeilen.
Auswahlpillen messen ihre Beschriftungen; „Aufgabe“ und andere Wörter werden
nicht mehr innerhalb eines Wortes umgebrochen. Alle Auswahlmöglichkeiten bleiben
sichtbar. Es wurden weder Nutzerdaten migriert noch Darstellungseinstellungen
des Nutzers zurückgesetzt.

## Nachweise

- 446 Flutter-Tests einschließlich acht neuer Prüfungen: [Protokoll](ui-pruefung-build49/tests.log).
- Strikte statische Analyse ohne Befund: [Protokoll](ui-pruefung-build49/analyze.log).
- Elf Datenbankschema- und drei Webserver-Tests: [Schema](ui-pruefung-build49/schema.log), [Webserver](ui-pruefung-build49/http.log).
- Nach der Bündelung der Import-Schreibvorgänge: 72 gezielte Daten-, Import- und UI-Tests erneut bestanden, einschließlich Rücknahme bei fehlerhaften Daten und Erhalt vorhandener Stundenpläne: [Protokoll](ui-pruefung-build49/import-regression.log).
- [Handyvergleich der überarbeiteten Bereiche](ui-pruefung-build49/phone-contact.png).
- [Große Schrift](ui-pruefung-build49/large-contact.png).
- [Desktop](ui-pruefung-build49/desktop-contact.png).
- [Schülerdialog mit Einträgen](ui-pruefung-build49/pupil-workspace-390-1-100.png).

Die reproduzierbaren Beispieldaten stehen in
`flutter_app/test/support/ui_audit_data.dart`. Mit
`FLEX_AUDIT_FIXTURE=/absoluter/pfad/fixture.json flutter test tool/ui_audit_fixture_test.dart`
lässt sich eine Sicherung für einen separaten Testarbeitsbereich erzeugen.
Es wurden ausschließlich synthetische Daten verwendet.

## Grenzen und verbleibende Punkte

Die Prüfung deckt die erreichbaren Hauptbereiche, wichtige tägliche Abläufe,
Fehler- und Wiederaufnahmefälle ab; sie beweist nicht jede mögliche Kombination
aller Einstellungen. „Ablauf“ bleibt der ausdrücklich vorgesehene Platzhalter.
Die umfangreichen Gestaltungseinstellungen und Scannerwerkzeuge benötigen
weiterhin Scrollen, insbesondere bei großer Schrift.

Eine echte Android-Kamera, native Dateiauswahl, Hersteller-Tastaturen,
Benachrichtigungen bei gesperrtem Gerät und Fingerabdruck wurden in dieser
Umgebung nicht am physischen Gerät geprüft. Ebenso fehlt weiterhin die eigene
Microsoft-Client-ID für eine echte OneDrive-Anmeldung. Automatisierte Tests und
Browserbedienung ersetzen diese Geräteprüfung nicht.

Release- und Browsernachweise werden nach Fertigstellung separat ergänzt.
