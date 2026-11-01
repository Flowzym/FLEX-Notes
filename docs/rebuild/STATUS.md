# Wiederaufbau – aktueller Prüfstand

**0.16.0-rebuild.1+21** ist ein bearbeitbares Flutter-Projekt aus erhaltenen
Quellen und neu rekonstruierten Funktionen. Es ist kein wiedergefundenes Original
von 0.16.0+20 und noch kein vollständiger Funktions-/Pixelabgleich mit 0.15.3.

## Herkunft

- Basisbranch `recovery/webpreview`, Commit `8a97a94d2854b43427c1016748b2adab431879f5`.
- Geprüfte Extraktion von 173 Quelldateien und Referenzdateien aus 0.1.0+1,
  gesichert im Zwischencommit `9e80ba7` auf `rebuild/flutter`.
- HTML-Prototyp unter `work/` unverändert; keine dauerhafte HTML-Einbettung.
- Webpreview-Original 0.15.3+19 und Quellarchive 0.1.0+1 unverändert unter
  `recovery/`. Die ursprünglichen neueren Flutter-Quellen fehlen weiterhin.
- Das SQL-Schema 7 stammt bytegleich aus dem Webpreview. Schriften Selawik und
  Gelasio samt Lizenzen wurden aus demselben Paket übernommen.
- Die fünf Hauptsymbole sind neue Flutter-Vektorzeichnungen anhand der im Chat
  sichtbaren Bildvorlage. Die PNG-Originaldatei war nicht als lokale Datei verfügbar.

## Implementiert und lokal geprüft

| Bereich | Tatsächlicher Stand |
| --- | --- |
| Schüler / Orga | Überlieferte Anlage, Bearbeitung, Archiv, Aufgaben, Checklisten, unabhängige Erinnerung, Historie und Entwürfe; fachliches Datum und optionale Uhrzeit ergänzt; Editoren in gemeinsamer Dialoghülle. |
| Sozial-/Arbeitsverhalten | Eigene persistente Einträge, positive/negative Tags und Freitext, Auftrag, Situation, Quelle, Unterstützung, Beteiligte ohne fremde Einzelbewertung, Zielbezug mit damaligem Zieltext. |
| Ziele | Ziel, Kriterium, Unterstützung, Schülerperspektive, Zieltermin und separater Prüftermin; Überprüfungen mit Fortführen/Erreicht/Beendet/Wieder öffnen und verknüpften Beobachtungen. |
| Hausübung | Aufgaben und Teilaufgaben mit stabilen IDs, Fach/Termin, unabhängige Aufgabenstände, Abgabe und Kommentar, chronologischer Rückmeldungsverlauf mit Korrektur/Löschung. |
| **Direkte HÜ-Standbuttons** | **Offen / Vollständig / Teilweise / Nicht erledigt** direkt pro Aufgabe; keine HÜ-Checkboxen als Standbedienung. |
| **Sprechblasen-Kommentar** | Gefüllte Sprechblase pro Aufgabe; Kommentar öffnet mit Textfokus. Kommentar und Abgabe verändern den Aufgabenstand nicht. |
| **Schüler-Tags** | Empfänger bei HÜ sowie Schüler-/Beteiligtenauswahl als Chips/Tags. Mehrere HÜ-Empfänger werden atomar gespeichert; Aufgaben-IDs und Zustände bleiben je Kind getrennt. |
| **Einheitliche Modals** | Gemeinsame Flutter-Hülle für Orga, Beobachtungen, Ziele, HÜ, Kommentare, Überprüfungen, Kalender, Stammdaten, Bestätigungen und Sicherungen. |
| **Gefüllte Icons** | Zielscheibe/Pfeil, Personen, Dokument, Haus und Kalender in gemeinsamer skalierbarer Flutter-Zeichnung. |
| Entwürfe | Fachliche Editoren speichern nach Schreibpause, bei Escape/Schließen und Lebenszykluswechsel. Kommentar-/Überprüfungsentwürfe behalten ihren Dialogmodus. Revisionen schützen auch beim endgültigen Speichern vor dem Entfernen neuerer Entwürfe. |
| Gruppenrücknahme | HÜ-Gruppen idempotent gespeichert; Rücknahme nur bei unveränderten Einträgen ohne Bearbeitungsentwurf, Wiederherstellung der Eingaben als neuer Entwurf. |
| Papierkorb | Ziele, Beobachtungen, HÜ und Orga weich löschen und wiederherstellen, mit neuer Revision. Löschen von Orga beendet geplante Erinnerungen; Wiederherstellen reaktiviert sie nicht. |
| Darstellung | Freie Hex-Farben für Dialogleisten/Karten/Buttons, optional gekoppelte Farben, getrennte Deckkraft, Gelasio-Überschriften, separate Desktop-/Mobilbilder mit fünf Bildmodi. Bilder bleiben lokal und werden in Sicherungen aufgenommen. |
| Konsistentes Laden | Ein gemeinsamer SQLite-Snapshot verhindert gemischte Ansichten während gleichzeitiger Änderungen. |
| Gesprächsvorbereitung | Auswahl fachlicher Einträge, Text-/Bereichs-/Datumsfilter und bewusstes Kopieren einer Textunterlage. |
| Sicherungen | Alle rekonstruierten Tabellen inklusive Verlauf/Entwürfen; atomare Wiederherstellung in leeren Bestand, zusätzlicher Import des erhaltenen Flutter-0.1-Formats. Datei- oder Zwischenablage-Ausgabe, Passwortschutz vorausgewählt. |
| Verschlüsselung | PBKDF2-SHA256 (310000 Iterationen), AES-256-GCM, frische Salt/IV; kompatibler äußerer `FLEX-Encrypted`-Container mit authentifiziertem Inhalt. |
| Schema | Echte Dateimigration 1 → 7 getestet. Neue Fach-Payloads tragen `rebuildFormat: 1`; unbekannte Formate werden abgewiesen. |

## Prüfungen dieses Wiederaufbaus

- Flutter **3.47.9**, Dart **3.13.7**, aufgelöste Pakete in `pubspec.lock`.
- `flutter analyze --no-pub`: **keine Befunde**.
- `flutter test`: **51 Tests bestanden**. Einschließlich echter SQLite-
  Migration, atomarem Rollback, Revisionen, Rückmeldungsreihenfolge, Gruppen,
  Entwürfen, Backup-Rundlauf, Passwort-/Manipulationsprüfung und neun neuen
  Widgettests zu den gewünschten Änderungen. Zusätzlich geprüft: Orga-Papierkorb,
  Darstellungs-/Bilddaten im Sicherungsrundlauf, gleichzeitiges Lesen/Schreiben
  und konkurrierende Entwurfsänderungen.
- Der Kryptografie-Kompatibilitätstest nutzt einen synthetischen Container,
  den die ursprünglichen HTML-Kryptofunktionen unter **Node/Web Crypto** erzeugt
  haben. Dies ist kein Browserlauf.
- Widgettests prüfen unter anderem 320 Pixel Breite mit simulierter Tastatur,
  Fokus nach Sprechblasen-Klick, Tag-Empfänger, Ziele und Mitternacht/fehlende Zeit.
- Direkte Flutter-Bildausgabe mit geladenen Originalschriften unter `renderings/`.
  Die Desktopansicht wurde visuell angesehen. Kein pixelgenauer Abgleich mit der
  kompilierten Referenz-Web-App und keine Browseraufnahme.
- `flutter build web --no-web-resources-cdn`: erfolgreich; Wasm-Vorprüfung bestanden.
- Lokaler Server auf **0.0.0.0:8081** gestartet. 13 Ressourcen einschließlich
  App-JavaScript, SQLite-Wasm, Drift-Worker, CanvasKit, Schema und Schriften per
  HTTP geprüft: Status 200, bytegleiche Inhalte und erforderliche COOP-/COEP-
  Header. `version.json` meldet `0.16.0-rebuild.1+21`. Dies bestätigt die
  Auslieferung, nicht die Ausführung im Browser oder OPFS-Persistenz.
- Die elf ursprünglichen SQL-Tests und der Architektur-SQL-Test bestanden.
- Alle Originalarchive und der gesicherte Prüfbericht wurden bytegleich geprüft.

Prüfprotokolle stehen unter `evidence/`; die Bildausgabe unter `renderings/`.
Der Cloud-Server ist ein temporärer interner Prozess und muss nach einem Neustart
der Umgebung erneut gestartet werden. Der Nutzerbrowser meldete für
`http://127.0.0.1:8081/` **ERR_CONNECTION_REFUSED**, während der Server innerhalb
der Cloud weiterhin HTTP 200 lieferte. Eine Weiterleitung in den eingebetteten
Browser ist hier nicht verfügbar; eine Portauswahl in dessen Oberfläche ist
nicht belegt. Die frühere Anleitung, dort Port 8081 auszuwählen, war unzutreffend.

Als lokale Alternative erzeugt `tool/package_preview.py` ein Windows-ZIP mit
dem geprüften Web-Build, Server-EXEs für x64/ARM64 und `Webvorschau-starten.cmd`.
Das vollständige ZIP wird auf dem Windows-PC entpackt; der Starter öffnet dessen
Standardbrowser und bindet nur die dortige Loopback-Adresse. Flutter, Python und
Go sind beim Empfänger nicht nötig. Go-Serverquellen sind im Paket und Repository
enthalten. Der Hilfsserver wurde unter Linux per HTTP geprüft; Windows-Ausführung
und Browserpersistenz bleiben ungetestet. Keine Cloud-Veröffentlichung oder
Konfigurationspublikation, kein öffentlicher Tunnel.

Der Vorschau-Starter besteht drei lokale Tests: Auslieferung aus seinem eigenen
Paketordner unabhängig vom Arbeitsverzeichnis (auch mit Leerzeichen im Pfad),
Erkennung fehlender Webdateien und Konflikte mit einem belegten Port. Die
Windows-Binaries wurden mit Go 1.27.3 erzeugt und ihre PE-Zielarchitekturen geprüft.
Alle Dateien im ZIP wurden anhand der enthaltenen SHA-256-Liste geprüft; der
Flutter-Web-Build entspricht bytegleich dem zuvor geprüften Stand `4e79901`.
Nachweise: `evidence/local-preview.json` und `evidence/local-preview-tests.txt`.

## Noch offen gegenüber der 0.15.3-Referenz

- Vollständige Funktions- und Pixelgleichheit. Die neuen Darstellungsoptionen
  sind rekonstruiert; exakte Geometrie, gekoppelte Transparenzen und sämtliche
  ursprünglichen Reglerstufen sind nicht vollständig abgeglichen.
- Vollständige Katalog-/Favoritenpflege für Auswahltexte und Auftragsvorschläge.
- Eigener gemeinsamer Kontexteditor mit Konfliktauflösung; Gruppenerfassung
  individueller Verhaltensbeobachtungen und Orga-Gruppen entsprechend der Referenz.
- Dauerhafte Stammdatenentwürfe, Stammdaten-Papierkorb und endgültiges Leeren
  mit sämtlichen Referenzprüfungen. Die neue Fach-Papierkorbbedienung ersetzt dies
  nicht stillschweigend.
- Vollständiger bereichsübergreifender Verlauf einschließlich aller Orga-Felder
  und Gesprächsunterlagen mit sämtlichen Export-/Filteroptionen der Referenz.
- Geführtes Übertragen einer konflikthaften Bearbeitung auf die neueste Revision.
  Der aktuelle Konfliktschutz weist veraltete Änderungen ab und erhält Entwürfe.
- Import/Migration unbekannter Flutter-Formate 0.15.3/0.16.0. Schema 7 allein
  beweist keine Payload-Kompatibilität. Die Rekonstruktion nutzt daher eine
  getrennte Datenbank und einen eigenen inneren Sicherungsformatnamen.

## Nicht ausgeführt / keine entsprechende Zusage

Keine Browsertests, keine praktische Prüfung von OPFS/IndexedDB oder mehreren
Browserfenstern, keine Windows-/Android-Gerätetests, kein nativer Flutter-Release-Build
und keine Release-Signierung. Native Dateiwähler wurden nicht praktisch geprüft.
Die lokale Datenbank bleibt unverschlüsselt. HTML-Altdaten werden nur vorgemerkt;
die vollständige Migration, Synchronisation, Scanner und native Benachrichtigungen
bleiben offen, wie teilweise bereits im Referenzstand.

Neue Arbeitsbereiche enthalten keine Testschüler. Tests verwenden ausschließlich
synthetische Inhalte. Es wurde keine Cloud-Umgebung veröffentlicht.
