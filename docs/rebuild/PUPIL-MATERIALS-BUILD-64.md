# Schüler-Materialien und kompakte Köpfe · 0.21.0+64

## Bedienung

In der Schülerübersicht öffnet **Materialien** die persönlichen Unterlagen.
**Material zuordnen** wählt Dateien oder Paketinhalte aus der bestehenden Ablage
und anschließend das Unterrichtsdatum. Abbrechen vor der Datumsbestätigung
verändert keine Zuordnungen. Dateien bleiben gemeinsam genutzt und werden nicht
kopiert.

Jede Datei zeigt eine Vorschau und die geplanten Unterrichtsdaten. Antippen eines
Datums verschiebt oder entfernt diesen Termin; das Plus ergänzt einen weiteren.
Die Daten anderer Schüler bleiben unabhängig. Entfernen der Schülerzuordnung
entfernt nur dessen Termine, nicht die Datei. Scannen, Anhänge und Planungen
bleiben direkt erreichbar. Die Unterlagen des Kalendertags zeigen die für
Schüler geplanten Dateien mit direktem Zugang zum jeweiligen Schüler.

Die Eintragungsköpfe verwenden eine breite Namenszeile und eine Titelzeile mit
sichtbaren Aktionen. Die zusätzliche Kopfkapsel und die doppelte
Zurück-/Schließen-Aktion entfallen; Zurück sichert weiterhin den Entwurf.
Bei großer Schrift stehen die Aktionen bei Bedarf in einer eigenen Zeile.

Navigationspillen haben gleich breite Segmente, einschließlich des aktiven
Segments. Bei Platzmangel werden gleichmäßige Reihen gebildet. Beschriftungen
werden nicht mitten im Wort getrennt. Die übrigen Optionsleisten verwenden
weiterhin ihre vorhandenen gleich breiten Segmente.

## Datenverträglichkeit

Materialien speichern optional `pupilDates` mit Schüler-ID und Datum. Validierung
verhindert ungültige Daten, doppelte Paare und Termine ohne Schülerzuordnung.
Beim Entfernen einer Zuordnung werden die betroffenen Termine ebenfalls
entfernt, auch in der Materialbearbeitung und beim Import einzelner Materialien.
Die vorhandene Sicherungszusammenführung übernimmt die Schüler-ID-Zuordnung
auch für diese Termine. Keine SQL-Schemaänderung ist erforderlich.

Ältere Sicherungen bleiben lesbar. Sicherungen mit den neuen Unterrichtsdaten
benötigen Build 64 oder neuer. Die Android-Kennung und das dauerhafte Zertifikat
bleiben gleich; Build 64 aktualisiert die neue FLEX aus Build 62/63 mit demselben
App-Speicher. Für FLEX Test gilt weiterhin die [Umzugsanleitung](ANDROID-UMZUG-62.md).

## Prüfung

- Gesamte Flutter-Suite: **519 Tests bestanden**.
- **11 SQLite-Tests und 3 Vorschau-Servertests bestanden**; Analyse ohne Befunde.
- 19 zusätzliche Material- und Navigationstests nach dem Entfernen des doppelten
  Scannerzugangs bestanden.
- Release im Chromium-Smartphonefenster (390 × 844): Material beim Schüler
  zuordnen, Unterrichtsdatum ändern, nach Neuladen wieder öffnen, gleich breite
  Navigation, kompakter Eintragungskopf und einmaliger Scannerzugang geprüft.
  Keine JavaScript-Seitenfehler.
- Release-Webbuild enthält die lokalen Rendering-Ressourcen und benötigt dafür
  keinen externen CDN. Signierter Android-Release erfolgreich gebaut; Signatur,
  Paketmetadaten, ZIP-Integrität und 16-KB-Ausrichtung geprüft.


Regressionsprüfungen decken individuelle und wiederholte Termine, Entfernen,
Datumsänderung, Abbrechen, Vorschauen, Sicherungswiederherstellung und
Schülerzuordnung beim Zusammenführen ab. Die bestehenden UI-Prüfungen erfassen
Smartphone, Tablet, große Schrift, helle und dunkle Darstellung sowie
Entwurfssicherung beim Verlassen des Editors.

[APK und Prüfnachweise](../../releases/android/build-64/README.md) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).

Eine Installation auf echter Android-Hardware und der persönliche Datenbestand
werden hier nicht geprüft. Die UI- und Browserprüfungen verwenden Testdaten.
