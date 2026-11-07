# Scannerzugänge und Anhänge je HÜ-Aufgabe – Build 46

Version **0.16.0-rebuild.26+46**, Branch `fix/dialog-reference-audit`.

## Bedienung

Unten in Zielen, Sozial- und Arbeitsbeobachtungen sowie Orga-Einträgen stehen
**Scannen / Foto** und **Dokumente**. Gespeicherte Dateien erscheinen direkt dort;
ein Tippen öffnet sie. Der Dokumentenzugang erlaubt auch bestehende Dateien
zuzuordnen und Scanentwürfe fortzusetzen. Dieselben direkten Zugänge gibt es bei
Schülerunterlagen, Kalendereinträgen, Rückläufen und weiteren Dokumentbereichen.

Jede HÜ-Aufgabe und Teilaufgabe hat eigene Scanner-/Anhangsymbole und eine eigene Dateiliste,
sowohl im Editor als auch beim Abhaken. Im Editor stehen die Symbole in der vorhandenen
Werkzeugzeile, damit leere Aufgabenzeilen kompakt bleiben. Allgemeine HÜ-Dateien stehen unten beim
Eintrag. Der Dokumentenknopf im Eintragskopf sammelt auch Dateien der Teilaufgaben.
Auch bei Erfassung für mehrere Schüler werden die neuen Aufgaben-IDs korrekt
zugeordnet; die Datei wird gemeinsam verknüpft und nicht je Schüler kopiert.

Bei neuen Einträgen oder noch ungespeicherten Aufgaben heißen die Aktionen
**Speichern & scannen** bzw. **Speichern & Dokumente**. Sie speichern den Eintrag
und öffnen anschließend den Scanner bzw. die Dokumentliste. Leere oder ungültige
Einträge werden dabei nicht gespeichert. Bei vorhandenen Einträgen bleiben
ungespeicherte Bearbeitungen als Entwurf erhalten.

## Daten und Nachweise

Dokumentverweise besitzen optional eine stabile `taskId`. Alte Verweise bleiben
kompatibel. Umbenennen, Umsortieren und gleich lautende Aufgaben verändern die
Zuordnung nicht. Beim Entfernen einer Aufgabe bleiben Dateien und Scanentwürfe
am HÜ-Eintrag erhalten. Das geschieht in derselben Datenbanktransaktion und erhöht
die Revisionen; alte offene Bearbeitungen dürfen diese Zuordnung nicht überschreiben.
Sicherungen erhalten die Verweise, ungültige Aufgabenbezüge werden abgewiesen.

Keine SQL-Schemaänderung. App-ID und Testsignatur bleiben unverändert.
Die echte Kamera und Installation als Update müssen weiterhin am Android-Gerät
abgenommen werden. Die Webvorschau unterstützt Bild-/PDF-Import.

## Prüfung des veröffentlichten Quellstands

Quellcommit: `8192066de424fd62cc01c918d0b39c48c18c476f`.
410 Flutter-Tests mit Coverage erfolgreich, darunter 13 neue Tests für stabile
Aufgabenbezüge, Sicherung/Wiederherstellung, Löschung, Gruppenerfassung, Editorzugänge
und schmale Layouts. Strenge Analyse und Formatprüfung ohne Befunde; 11 SQLite-
und drei HTTP-Tests erfolgreich. Der vorhandene Test für kompakte HÜ-Zeilen bleibt
unverändert erfolgreich. Orga entfernt nach korrigierten Eingaben den alten Fehler,
damit das Speichern auch über der geöffneten Tastatur erreichbar bleibt.

Android- und Web-Release gebaut. APK-Kennung, Version, Manifest, bisherige Signatur,
ZIP-Ausrichtung und native Bibliotheken geprüft. OneDrive-Größe und QuickXorHash
stimmen mit dem lokalen APK überein. GitHub liefert die APK mit HTTP 200 und
korrekter Dateigröße/ZIP-Signatur.

Browserprüfung mit ausschließlich synthetischen Schüler- und Dokumentdaten bei
390 × 844: Haupt- und Teilaufgabe erfassen, direkt aus der Teilaufgabe den Scanner
öffnen, automatische Schüler-/Aufgabenzuordnung prüfen, Bild importieren, PDF
speichern/exportieren und direkt an der Teilaufgabe wieder öffnen.

[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42402531104):
Alle vier Jobs erfolgreich. Nach dem geprüften Quellcommit wurden nur Nachweise und
Veröffentlichungsdateien ergänzt; Flutter- und CI-Quellen blieben identisch.
Automatisierte Prüfungen und Artefaktnachweise: `scanner-zugaenge-build46/`.
