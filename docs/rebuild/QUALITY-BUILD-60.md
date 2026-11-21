# FLEX 0.18.0+60 · Anhänge, Scanner, Tags und UI-Review

## Ergebnis

Scans, Fotos und Dateien lassen sich bereits an einem noch unveröffentlichten
Eintrag ergänzen. Die zuvor irreführenden Aktionen „Speichern & scannen“ und
„Speichern & Dokumente“ sind durch normale Anhangaktionen ersetzt; der doppelte
Dokumentenzugang im Editorkopf entfällt. Das gilt auch für HÜ-Unteraufgaben und
Gruppeneinträge. Bestehende Anhänge bleiben sichtbar.

„Live“ steht mittig in der unteren Navigation. Schülerzeilen haben unten acht
weitere logische Pixel Abstand. Titel sind etwas kleiner, der Abstand zwischen
oberer Kapsel und Seiteninhalt ist geringer. Seitenwechsel dauern 120 ms und
rasten ohne elastisches Überschwingen ein. Die Uhrzeit lässt sich als HH:mm oder
vier Ziffern eingeben; alternativ öffnet das Uhrsymbol die 24-Stunden-Uhr.

## Tags, Ausgabe und Stapelbearbeitung

- Gemeinsame Tag-Auswahl für Scanner und Materialeditor: Chips, Vorschläge,
  Suche während der Eingabe und eigene Tags. Noch nicht mit Enter bestätigter
  gültiger Text ist bereits im Entwurf enthalten. Groß-/Kleinschreibung,
  führende Rauten und mehrfache Leerzeichen erzeugen keine Dubletten.
- Tag-Verwaltung mit Verwendungszahlen, globalem Umbenennen/Zusammenführen und
  Entfernen. Dateien, Papierkorb und gespeicherte Bearbeitungsentwürfe werden
  gemeinsam in einer Datenbanktransaktion aktualisiert. Dateien bleiben bestehen.
- Mehrfachauswahl: Tags ergänzen, bestimmte Tags entfernen oder die Auswahl
  vollständig neu taggen. Mehrere Tagfilter werden als UND-Verknüpfung angewandt;
  Scannerentwürfe berücksichtigen dieselben Filter.
- Echtes Teilen einzelner oder mehrerer gespeicherter Dateien sowie der gerade
  bearbeiteten Scan-/Fotoseiten. Ein Scan wird als PDF, eine Fotoreihe als einzelne
  JPEG-Dateien ausgegeben. Exportieren bleibt eine getrennte Aktion. Der Browser
  lädt Dateien herunter, falls er kein Teilen unterstützt; eine frische
  Benutzeraktion nach der Aufbereitung erhält die Web-Share-Berechtigung.
- Stapelfilter mit auswählbaren Seiten, wechselbarer Seitenvorschau und einer
  separat berechneten Vorschau bis 720 px. Das Ausgabeformat behält seine
  bisherige Auflösung. Der letzte Stapelfilter lässt sich während der Sitzung
  verlustfrei zurücknehmen. Nicht ausgewählte Seiten bleiben unverändert.

## Datenfluss und behobene Widersprüche

1. **Scannen veröffentlichte bisher einen neuen Eintrag.** Anhänge referenzieren
   jetzt einen expliziten Orga-, Schul- oder Gruppenentwurf. Erst das Speichern
   des Eintrags überträgt diese Verweise atomar auf die tatsächlichen Datensätze
   und HÜ-Aufgaben-IDs. Die endgültige Schülerauswahl entscheidet über die
   automatische Zuordnung.
2. **Aufgaben-/Entwurfswechsel konnten Dateiverweise zurücklassen.** Beim Entfernen
   einer Aufgabe wechseln deren Anhänge zum Eintrag; beim Verwerfen eines Entwurfs
   werden die Entwurfsverweise entfernt, die Dateien bleiben in der Verwaltung.
   Auch fortsetzbare Scanentwürfe und veränderte Quelldatei-Revisionen werden
   berücksichtigt. Rückgängig gemachte Gruppenspeicherungen geben dem
   wiederhergestellten Entwurf Zugriff auf seine Anhänge.
3. **Import und Entwurfskollisionen brauchen dieselbe Referenzlogik.** Divergierende
   Entwürfe erhalten beim Zusammenführen eigene IDs. Material- und Scanverweise
   werden mitgeführt; identische Wiederholungsimporte erzeugen keine zusätzlichen
   Kopien. Ungültige neue Entwurfsverweise werden beim Prüfen zurückgewiesen.
4. **„Teilen / Exportieren“ war nur ein Download.** Die System-Teilen-Funktion und
   Dateiausgabe sind nun getrennt. Dateinamen werden bereinigt und bei einer
   Mehrfachausgabe eindeutig gemacht. Eine fehlende Datei bricht die Vorbereitung
   ab, statt unbemerkt nur einen Teil der Auswahl zu teilen.
5. **Aufräumfehler nach Bildbearbeitung wirkten wie Speicherfehler.** Erfolgreich
   gespeicherte Seiten bleiben erfolgreich; die Bereinigung wird erneut versucht.
   Ursprüngliche Pixel für das Rückgängigmachen eines Stapelfilters werden bis zum
   Schließen oder Speichern behalten.

SQL-Schema, App-ID und Webadresse bleiben erhalten. Es findet keine Rücksetzung
vorhandener Einträge statt. Neue Sicherungen mit Entwurfsanhängen benötigen eine
App-Version, die diese zusätzlichen Verweisarten versteht.

## Prüfung

| Prüfung | Ergebnis |
| --- | --- |
| Gesamte Flutter-Suite | 500 Tests bestanden |
| Nachprüfung der abschließenden Datenfluss-/Materialänderungen | 34 + 17 Tests bestanden |
| Statische Analyse und Dart-Formatierung | Ohne Befund |
| SQLite-Schema / Vorschau-Server | 11 / 3 Tests bestanden |
| Release-Webbuild ohne externe Schrift-/CanvasKit-CDNs | Erfolgreich |
| Gemessene Zeilenabdeckung | 79,43 % (15.031 / 18.923) |


Die Tests decken Datenbanktransaktionen, Revisionskonflikte, Entwurfslebenszyklus,
Sicherung/Import, Gruppen-/Aufgabenverweise, Tags, Freigabedaten, Uhrzeitvalidierung,
Scannerfilter/Pixelbearbeitung sowie die vorhandenen App-Flows ab. Kleine Displays,
vergrößerte Schrift, Tastaturfokus und Hell/Dunkel sind Teil der UI-Suite.

Der lokale Release-Webbuild wird zusätzlich in Chromium bei 390 × 844 px mit dem
vorhandenen synthetischen Browserprofil geprüft. Der Datenstand bleibt erhalten;
Scannen vor dem Eintragsspeichern und PDF-Ausgabe werden praktisch durchlaufen.
Android-Kamera und Android-Teilen sind damit noch nicht auf echter Hardware geprüft.
Die GitHub-Pipeline prüft zusätzlich den nativen Releasebuild des Commits.

## Kritische verbleibende Punkte

| Priorität | Befund | Empfehlung |
| --- | --- | --- |
| Hoch | Keine durchgehende OCR für fotografierte Seiten; gescannter Text ist damit nicht zuverlässig durchsuchbar. | Lokale Texterkennung mit überprüfbarem Ergebnis und Suchindex ergänzen. |
| Hoch | Kantenqualität, Schärfe, schwaches Licht, große Serien und Android-Teilen sind nicht auf einem physischen Gerät abgenommen. | Mit echten Arbeitsblättern, Buchseiten und Fotos auf dem Zielgerät testen; Laufzeit/Speicher und Exportziel prüfen. |
| Hoch | Notizbuchsicherung und binäre Materialdateien werden weiterhin getrennt gesichert. | Eine geführte vollständige Sicherung/Wiederherstellung ausarbeiten und beide Bestandteile gemeinsam prüfen. |
| Mittel | Große Editor-Dateien bleiben: Schul-Editor über 2.000, Materialseite über 1.800, Scanner-Editor über 1.400 Zeilen. | Weitere Bearbeitungsschritte in kleinere Widgets und Dienste zerlegen; keine pauschale Umstrukturierung ohne Regressionstests. |
| Mittel | Undo für einen Stapelfilter gilt für die offene Sitzung; Schließen beendet diese Bearbeitungshistorie. | Bei Bedarf eine dauerhaft gespeicherte Versionshistorie mit klarer Speicherbereinigung ergänzen. |
| Mittel | Automatische OneDrive-Anmeldung benötigt weiterhin eine Microsoft-Appregistrierung. | Die Einrichtung getrennt abschließen; vorhandene Datei-/Link-Zugänge bleiben nutzbar. |

CamScanner-Parität und vollständige Fehlerfreiheit werden nicht behauptet. Die
aktuelle Arbeit verbessert konkrete Erfassungs-, Zuordnungs- und Ausgabeabläufe;
OCR und die Abnahme mit echten Kamerabildern bleiben wesentliche nächste Schritte.
