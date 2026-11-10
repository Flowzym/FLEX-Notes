# FLEX 0.17.1+58 · Gestaltung und Konsolidierung

Die freigegebene Creme-/Salbei-Gestaltung ist weiter ausgearbeitet: Inter mit
eindeutiger Schriftgewichtung, warme Hintergrundverläufe, feine Schatten,
gemeinsame Navigationskapseln und ruhige runde Such-/Anlegeaktionen. Die offenen
Schülerzeilen behalten alle fünf direkten Eintragungsaktionen. Bei 390 × 844 px
sind sechs vollständige Schülerzeilen sichtbar. Kalender, Stundenplan und Aufgaben
passen wieder gemeinsam in eine obere Navigationszeile.

## Konsolidierung

- Gemeinsame Flächen, Schatten und Kapseln ersetzen wiederholte Dekorationen.
  Überflüssige Farb-Aliase und verschachtelte Text-/Icon-Themes sind entfernt.
- `prototype_navigation.dart` heißt jetzt `app_navigation.dart`; die bestehenden
  Seiten, Zugänge und Navigationsschlüssel bleiben erhalten.
- Unbenutzte Textur, alte Schriftfamilien und veraltete Bild-Testdaten sind entfernt.
  App, PDF-Ausgabe und UI-Tests verwenden dieselben lokal eingebundenen Schriften.
- 16 duplizierte Schriftladeblöcke verwenden einen Testhelfer. Vier identische
  Mehr-Navigationstests entfallen. Die Prüfungen verwenden echte Schriftgrößen
  statt inzwischen wirkungsloser alter Oberflächenskalierung.
- Darstellung bleibt auf Hell/Dunkel/System und Schriftgröße beschränkt;
  funktionale Einstellungen bleiben erhalten.

## Gefundene und behobene Fehler

1. **Verspätetes Nachladen nach dem Schließen:** Eine laufende Datenbankabfrage
   konnte einen bereits freigegebenen Controller aktualisieren und dessen
   Listener aufrufen. Lebensdauer und Abfragegeneration werden nach dem Warten
   erneut geprüft. Ein weiterer Test schützt vor einem älteren Snapshot, der
   neuere Daten überschreibt.
2. **Gleichzeitige Erinnerungseinstellungen:** Schnell aufeinanderfolgende
   Schalteränderungen konnten sich überschreiben. Eine spät beantwortete
   Android-Berechtigungsabfrage konnte eine nachfolgende Deaktivierung wieder
   rückgängig machen. Änderungen werden nun in Eingabereihenfolge gespeichert
   und jeweils mit dem aktuellen Stand zusammengeführt. Ein gescheiterter
   Schreibvorgang blockiert folgende Änderungen nicht.
3. **Scanner meldet Fehler nach erfolgreichem Bildersatz:** Schlägt nur das
   anschließende Entfernen einer alten Datei fehl, erschien bisher trotzdem ein
   Speicherfehler. Die neue Seite bleibt korrekt gespeichert; das Aufräumen wird
   beim Schließen erneut versucht. Andere Seiten und zum Rückgängigmachen
   benötigte Dateien bleiben erhalten.

Die Regressionen wurden vor der jeweiligen Korrektur reproduziert. Fünf neue
Lebensdauer-/Nebenläufigkeitstests und ein Scanner-Regressionstest sichern die
Korrekturen und angrenzende Fehlerpfade ab.

## Prüfumfang und Ergebnis

Der Durchgang umfasst die Flutter-Schichten für Datenbank, Fachlogik, Controller,
Dienste und Oberfläche sowie native Schnittstellen und die Testpipeline. Im Fokus
standen Entwürfe, Revisionen/Konflikte, Referenzintegrität, Sicherung/Import,
Erinnerungen, Kalender/Stundenplan, Anhänge und Scanner. Die bestehende
Transaktions-, Verschlüsselungs- und Pixel-Schwärzungslogik bleibt bestehen.

| Prüfung | Ergebnis |
| --- | --- |
| Gesamte Flutter-Suite, 43 Testdateien | **486 Tests bestanden** |
| Statische Analyse | **Keine Befunde** |
| Dart-Formatierung | **Keine Änderungen nötig** |
| SQLite-Schema | **11 Tests bestanden** |
| Vorschau-Server | **3 Tests bestanden** |
| Release-Webbuild, lokale Schrift-/CanvasKit-Ressourcen | **Erfolgreich** |
| Gemessene Dart-Zeilenabdeckung | **79,52 %** (14.525 / 18.265, 102 erfasste Dateien) |

Die UI-Prüfungen laufen mit den echten App-Schriften, unter anderem bei 390 px
hell/dunkel, 320 px mit 1,8-facher Systemschrift sowie Tablet und Desktop.
Zusätzliche Tests prüfen App- und Systemschrift gemeinsam, Tastaturhöhenwechsel,
Fokus, lange Beschriftungen, sämtliche Eintragungsarten und Scannerbearbeitung.
415 Renderings wurden erzeugt; eine Auswahl liegt in der Evidenz. Renderings sind
ergänzende Sichtprüfung, keine Behauptung einer vollständigen Pixelabnahme.

Der Chromium-Durchgang verwendet den gespeicherten synthetischen Datenbestand
aus Build 57 unter derselben Adresse. Geprüft werden vorhandene Schüler und
Einträge, Schließen/Fortsetzen eines neuen Entwurfs, Speichern, Neuladen
und JSON-Export mit den neuen und alten Einträgen. Die endgültigen Resultate
stehen in [verification.json](quality-58/verification.json).

## Grenzen und Datenverträglichkeit

Keine SQL-Schemaänderung, kein Zurücksetzen lokaler Daten, keine neuen Datensatz-
oder Anhangs-IDs. Die Vorschau bleibt unter ihrer bestehenden Adresse. Die
Prüfung zeigt keine offenen Fehler in den durchgespielten Abläufen; sie ist keine
Garantie für Fehlerfreiheit. Größere Editor- und Repository-Dateien bleiben
vorhanden; eine vollständige Neuarchitektur wurde nicht behauptet oder erzwungen.

Android-Übersetzung wird zusätzlich durch [FLEX CI](https://github.com/Flowzym/FLEX-Notes/actions/workflows/flutter-ci.yml)
geprüft. Physische Kamera, Biometrie und Betriebssystem-Erinnerungen wurden hier
nicht auf einem Handy abgenommen. Eine echte OneDrive-Anmeldung benötigt die
Microsoft-Appregistrierung und ist nicht Teil dieses Gerätetests. Der ursprüngliche
Android-Testsignierschlüssel fehlt weiterhin; eine CI-APK ist kein kompatibles
Installationsupdate.
