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

Automatisierte Prüfungen und Artefaktnachweise: `scanner-zugaenge-build46/`.
