# Review-Korrekturen – FLEX-Notizbuch 0.15.0+16

Die sieben bestätigten Fehler R1–R7 aus `REVIEW_2026-11-01.md` sind korrigiert.
Die ursprünglichen Reproduktionen gehören jetzt zur regulären Testsuite.
Die HTML-Referenz bleibt unverändert. Es werden keine früheren Änderungen neu
angewendet und keine Umgebung oder App veröffentlicht.

| Befund | Korrektur | Nachweis |
| --- | --- | --- |
| R1: Speichern & weiter bei nur einem Schüler | Jeder Wechsel startet eine neue Editor-Instanz mit neuer Eintragsidentität. | Zwei aufeinanderfolgende Speicherungen für Orga und Sozialverhalten |
| R2: Auswahl durch Suche eingeschränkt | Archivierung verwendet die vollständige angezeigte Auswahl; alle Schüler werden in einer SQL-Transaktion geändert. | Versteckter ausgewählter Schüler wird mitarchiviert; spätere veraltete Revision rollt den gesamten Vorgang zurück |
| R3: paralleler Entwurf überschrieben | Speichern, Verwerfen und Übernehmen prüfen die tatsächlich geladene Entwurfsfassung. Bei Autosave-Konflikten wird die lokale Eingabe als eigener Entwurf erhalten. | Schreib-, Lösch- und Übernahmekonflikte für Orga, Schul-, Kontext-, Gruppen- und Auswahlentwürfe; Fortsetzen im Widget |
| R4: große aufbewahrte HTML-Dateien blockieren Sicherung/Papierkorb | Große Vollsicherungen werden komprimiert. HTML-Originale lassen sich unter Einstellungen → Daten einzeln unverändert sichern und erst danach mit Bestätigung entfernen. Neue Vormerkungen werden atomar abgewiesen, wenn damit keine Vollsicherung mehr möglich wäre. | Zwei Originale mit jeweils 10,5 MB, verschlüsselter Export, Wiederherstellung und endgültiges Leeren; Abbruch/Bestätigung bei Originalverwaltung |
| R5: beschädigte Entwurfsfelder importiert | Separate Strukturprüfung für fachliche Felder, Aufgaben, Tags, Beteiligte, Gruppendaten und Auswahllisten; unvollständige Formulare bleiben erlaubt. | Falsche Typen werden atomar abgewiesen; anschließend gelingt ein gültiger Import |
| R6: gemischte/überholte Neuladung | Gemeinsame SQL-Lesetransaktion; vollständige Übernahme nur beim aktuellsten Ladevorgang; keine Benachrichtigung nach dispose. Neuere Darstellungsänderungen bleiben erhalten. | Gezieltes Anhalten älterer Snapshots, konkurrierende Speicherung, Darstellungsänderung und dispose |
| R7: Tastatur verursacht Dialogüberlauf | Bei kleiner Resthöhe kann der gesamte Dialog einschließlich Metadaten und Aktionen scrollen. Bei ausreichender Höhe bleiben Metadaten und Aktionen fest. | 320×640, Orga/Sozial, Schriftfaktoren 1/1,3, Tastaturhöhen 160/240/300; Fokus bleibt erhalten, Speichern erreichbar |

## Ergänzende Absicherung

- Orga-Checklisten und Kontextzuordnungen werden gesammelt geladen, nicht mit
  einer eigenen SQL-Abfrage pro Eintrag. Vollständige Controller-Neuladungen
  bleiben bestehen; ein Leistungstest mit mehrjährigen Beständen steht noch aus.
- Die sieben Entwurfseditoren beantworten Flutter-Plattformanfragen zum Beenden
  erst nach dem Schreiben ihrer Entwürfe. Bei Fehlern oder laufenden Aktionen
  wird die Beendigung abgelehnt. Der automatisierte Test prüft den Flutter-Vertrag;
  Windows-X/Alt+F4, Browser-Tab-Schließen, Prozessabbruch und Android-Prozessende
  sind damit noch nicht auf echten Geräten bestätigt. Browser und erzwungenes
  Prozessende können asynchrone Speicherung weiterhin abbrechen.
- Android: automatische OS-Sicherung und Geräteübertragung sind im Manifest und
  in Regeln für ältere/neuere Android-Versionen ausdrücklich ausgeschlossen.
  Das tatsächliche Verhalten des Zielgeräts ist noch zu prüfen.
- Android-Release verwendet keinen Debug-Schlüssel. Für Release-Builds wird eine
  private `android/key.properties` benötigt; Vorlage: `key.properties.example`.
  Keystore und Zugangsdaten sind nicht Bestandteil des Quellenpakets.

## Daten- und Formatkompatibilität

Die SQLite-Datenbank und der enthaltene Vollsicherungsinhalt bleiben Version 7.
Kleine Vollsicherungen behalten ihr bisheriges JSON-Format. Große Sicherungen
verwenden `FLEX-Flutter-Archive` Version 1 (`gzip+base64`) als äußeren Rahmen.
Nur die aktuelle App kann diesen neuen Rahmen lesen. Der AES-GCM-Schutzcontainer
`FLEX-Encrypted` Version 1 und die originale HTML-Kryptokompatibilität bleiben
unverändert. Komprimierung ersetzt keine Verschlüsselung.

Grenzen: 20 MB vor Verschlüsselung bzw. für den komprimierten Rahmen, 28 MB für die
Sicherungsdatei, maximal 200 MB nach Dekomprimierung. Die Dekomprimierung prüft
Größe und Integrität und begrenzt die Ausgabe während des Entpackens. Bei zu
großem Gesamtbestand können die aufbewahrten HTML-Originale einzeln gesichert und
entfernt werden. Der Export/Import ist weiterhin speicherbasiert, kein Streaming
beliebig großer Bestände. Vormerken ist weiterhin keine vollständige Migration.

Entwurfsprüfungen gelten für die neue Repository-Implementierung. Alle gleichzeitig
offenen App-Fenster sollten diese Version verwenden; ältere Programme kennen den
neuen Schutz nicht. Schülerentwürfe behalten ihre bereits vorhandenen Revisionen.
Die aktive lokale Datenbank bleibt unverschlüsselt; die Sicherungsverschlüsselung
ändert daran nichts.

## Prüfstand

Die abschließenden Zahlen, Build- und Prozessnachweise stehen in
`FLUTTER_STATUS.md`. Alle Tests verwenden synthetische Daten in getrennten
Arbeitsbereichen. Keine Browserprüfung und kein nativer Windows-/Android-Start.

Weiterhin ausstehend sind vollständige HTML-Altdatenmigration, Synchronisation,
Scanner, native Benachrichtigungen und physische Datenbankkompaktierung. Das sind
bestehende Ausbaupunkte, keine durch dieses Review neu eingeführten Funktionen.
