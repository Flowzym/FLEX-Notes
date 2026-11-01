# Aktueller Dialogaudit: 0.16.0-rebuild.5+25

Der Nutzer hat das Quellenpaket `FLEX-Notes-Quellen-9e5e4b6b8e8c.zip`
nachgereicht. Sein vollständiger Stand 0.16.0-rebuild.4+24 wurde übernommen;
der folgende Schritt korrigiert Dialoge anhand der aktuellen HTML-Referenz (37)
und der späteren ausdrücklichen Nutzervorgaben.

Maßgeblich sind jetzt das [vollständige Dialogverzeichnis](../../audit/DIALOGVERZEICHNIS.md),
der [dialogweise Abgleich](../../audit/FLUTTER_ABGLEICH.md) und der
[aktuelle Prüfnachweis](../../audit/PRUEFNACHWEIS.md). Dort stehen auch die
wesentlichen offenen Abweichungen bei Import, Konflikten, Übersicht und
historischen Formaten. **Nicht als „originalgetreu“ freigegeben.**

In dieser Runde: lokale Flutter-Tests und direkte Flutter-Renderings, keine
Browsertests, kein neuer Web-/Windows-/Android-Releasebuild und keine
Veröffentlichung. Ausgeliefert wird der bearbeitbare Quellstand mit Nachweisen.
Die folgenden Abschnitte gehören unverändert zum gefundenen Archiv und sind
historische Berichte; ihre Testzahlen und damaligen offenen Punkte werden nicht
als aktuelles Ergebnis ausgegeben.

---

# Aktueller Stand: 0.16.0-rebuild.4+24

Sozial- und Arbeitsverhalten sowie der Kalender wurden an die jetzt gelieferten
Screenshots angeglichen. Umfang, Speicherung, Prüfungen und Grenzen stehen im
[Dialog-Abgleich](DIALOG-ABGLEICH.md). Neu sind insbesondere einzelne Zusatz-
bereiche, persistente Favoriten/Auswahllisten, „Speichern & weiter“ und die
integrierte optionale Uhrzeit. 60 Tests und Analyse ohne Befunde; neue direkte
Flutter-Ansichten unter `renderings/reference-*`, Nachweise unter `evidence/dialog-*`.

Die folgenden Abschnitte sind historische Prüfstände; deren Aussagen zu fehlenden
Dialog-Screenshots, offenen Beobachtungskatalogen und „Speichern & weiter“ für
Beobachtungen werden durch den aktuellen Dialog-Abgleich ersetzt. Andere
fachliche Grenzen gelten weiterhin.

---

# Vorheriger Hintergrundstand: 0.16.0-rebuild.3+23

## Originalhintergrund vom 01.11.2026

Das nachgereichte `Background Mobile 01 Dark small.png` ist bytegleich als
App-Asset eingebaut (1061 × 1500 Pixel). Im dunklen Modus erscheint es als
Standard auf Mobilgeräten und Desktop; eigene Bilder behalten Vorrang.
Flächenfüllende, zentrierte Darstellung ohne Verzerrung ist voreingestellt.
Andere Bildmodi bleiben verfügbar. Der helle Modus behält seinen Verlauf.
Herkunft und SHA-256: [Asset-Dokumentation](../../flutter_app/assets/backgrounds/README.md).
Die zuvor fehlenden grünen Tafeltexturen und historischen Original-Screenshots
sind damit nicht wiederhergestellt; dieses Bild ist die jetzt gelieferte Vorlage.

Für diesen Stand neu ausgeführt:

- Flutter-Analyse: keine Befunde.
- Gesamtsuite: 56 Tests bestanden.
- Zusätzlicher Renderlauf des bestehenden UI-Tests: bestanden; echte Flutter-
  Ansichten für Desktop, Mobil, HÜ und Kommentar unter `renderings/background-*`.
  Desktop und Mobil wurden visuell geprüft; ausschließlich synthetische Schüler.
- Webbuild erfolgreich, einschließlich Wasm-Vorprüfung.
- Lokale HTTP-Prüfung von Einstieg, Version, App-JavaScript und Hintergrund:
  Status 200, bytegleich, COOP/COEP vorhanden; Bild stimmt mit Original-SHA überein.
- Drei Vorschau-Serverprüfungen bestanden.

Protokolle: `evidence/background-*`. Flutter 3.47.9 / Dart 3.13.7.
Keine Browsertests oder Windows-/Android-Gerätetests; die nachstehenden
fachlichen Grenzen gelten weiterhin. Das Windows-Vorschaupaket wird aus diesem
Webbuild erstellt; vollständige Quellen werden separat als ZIP ausgeliefert.
Die früheren Aussagen zu ausgelieferten Paketen und Prüfzahlen im folgenden
Abschnitt dokumentieren den vorherigen Stand.

---

# Vorheriger Wiederaufbau – 0.16.0-rebuild.2+22

**0.16.0-rebuild.2+22** ist ein bearbeitbares Flutter-Projekt aus erhaltenen
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

Die nachgereichte [App-Referenz aus dem alten Chat](APP-DETAILS-AUS-ALTEM-CHAT.md)
präzisiert die jüngsten Vorgaben. Ihre historischen Testzahlen gelten nicht als
Prüfnachweis dieser Rekonstruktion. Der vorherige Wiederaufbau hatte erhebliche
UI-Abweichungen; der folgende Schritt korrigiert diese konkret, ohne einen
visuellen Originalabgleich vorzutäuschen.

| Bereich | Tatsächlicher Stand |
| --- | --- |
| Navigation und Schülerkarten | Zentrierte Pillen Übersicht / Schüler / …; Seiten- und untere Navigation entfernt. Karten mit farbigem Rand, Serifennamen, Pfeil und fünf gefüllten Symbolen in 3+2-Anordnung, einschließlich offener/fälliger Zähler. |
| Schülersuche | Anfangs verborgen; Lupe bei Neuer Schüler und Download öffnet mit Textfokus. Leeren erhält die offene Suche; Schließen leert den Filter. |
| Schüler / Orga | Überlieferte Anlage, Bearbeitung, Archiv, Aufgaben, Checklisten, unabhängige Erinnerung, Historie und Entwürfe; fachliches Datum und optionale Uhrzeit ergänzt; Editoren in gemeinsamer Dialoghülle. |
| Sozial-/Arbeitsverhalten | Eigene persistente Einträge, positive/negative Tags und Freitext, Auftrag, Situation, Quelle, Unterstützung, Beteiligte ohne fremde Einzelbewertung, Zielbezug mit damaligem Zieltext. |
| Ziele | Ziel, Kriterium, Unterstützung, Schülerperspektive, Zieltermin und separater Prüftermin; Überprüfungen mit Fortführen/Erreicht/Beendet/Wieder öffnen und verknüpften Beobachtungen. |
| Hausübung | Aufgaben und Teilaufgaben mit stabilen IDs, Fach/Termin, unabhängige Aufgabenstände, Abgabe und Kommentar, chronologischer Rückmeldungsverlauf mit Korrektur/Löschung. |
| **Direkte HÜ-Standbuttons** | **Offen / Vollständig / Teilweise / Nicht erledigt** direkt pro Aufgabe; keine HÜ-Checkboxen als Standbedienung. Gleicher Stand und Doppelklick erzeugen keine zusätzliche Historie; Speicherfehler erhält den gespeicherten Stand, Wiederholung ist möglich. Vollständig-Zähler ergänzt. |
| **Sprechblasen-Kommentar** | Gefüllte Sprechblase pro Aufgabe, vorhandene Kommentare hervorgehoben; Kommentar öffnet mit Textfokus und Standinformation. Kommentar und Abgabe verändern den Aufgabenstand nicht. |
| **Schüler-Tags** | Empfänger bei HÜ sowie Schüler-/Beteiligtenauswahl als Chips/Tags. Mehrere HÜ-Empfänger werden atomar gespeichert; Aufgaben-IDs und Zustände bleiben je Kind getrennt. |
| **Einheitliche Modals** | Auch die Schülerbereichslisten öffnen als Modals. Außenabstand mobil 10 / Desktop 16, Radius 24, Standard-Maximalbreite 640; Kommentar/Kalender 430. Alle fünf Bereichslisten und Editoren auf Desktop und bei 320 px mit Tastatur geprüft. |
| Eintragsdarstellung | Kompakter Entwurfsstatus, exakte Zeitpunkt-Tags, Abschnitt Kontext / Quelle, Reaktion / Unterstützung. Optionale Uhrzeit direkt im Kalender ohne eigenen Schalter. Schrift/Farbe ausgewählter Chips im tatsächlich gerenderten Widget geprüft. |
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
- `flutter test`: **56 Tests bestanden**. Einschließlich echter SQLite-
  Migration, atomarem Rollback, Revisionen, Rückmeldungsreihenfolge, Gruppen,
  Entwürfen, Backup-Rundlauf, Passwort-/Manipulationsprüfung und Widgettests
  zu den gewünschten Änderungen. Zusätzlich geprüft: Orga-Papierkorb,
  Darstellungs-/Bilddaten im Sicherungsrundlauf, gleichzeitiges Lesen/Schreiben
  und konkurrierende Entwurfsänderungen. Fünf zusätzliche Fälle prüfen die
  nachgereichten UI-Vorgaben, Suchfokus, Kartengeometrie, Standänderungen bei
  Doppelklick/Fehler, Chip-Schrift/-Farbe und direkte Flutter-Renderings.
- Der Kryptografie-Kompatibilitätstest nutzt einen synthetischen Container,
  den die ursprünglichen HTML-Kryptofunktionen unter **Node/Web Crypto** erzeugt
  haben. Dies ist kein Browserlauf.
- Widgettests prüfen unter anderem 320 Pixel Breite mit 1,35-facher Schrift und simulierter Tastatur,
  Fokus nach Sprechblasen-Klick, Tag-Empfänger, Ziele und Mitternacht/fehlende Zeit.
- Direkte Flutter-Bildausgabe mit geladenen Originalschriften unter `renderings/`.
  Die neuen Desktop-/Mobilansichten wurden visuell angesehen. Kein pixelgenauer Abgleich mit der
  kompilierten Referenz-Web-App und keine Browseraufnahme.
- `flutter build web --no-web-resources-cdn`: erfolgreich; Wasm-Vorprüfung bestanden.
- Lokaler Server auf **0.0.0.0:8081** gestartet. 13 Ressourcen einschließlich
  App-JavaScript, SQLite-Wasm, Drift-Worker, CanvasKit, Schema und Schriften per
  HTTP geprüft: Status 200, bytegleiche Inhalte und erforderliche COOP-/COEP-
  Header. `version.json` meldet `0.16.0-rebuild.2+22`. Dies bestätigt die
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

Als lokale Alternative kann `tool/package_preview.py` ein Windows-ZIP mit
dem geprüften Web-Build, Server-EXEs für x64/ARM64 und `Webvorschau-starten.cmd` erzeugen.
Das vollständige ZIP wird auf dem Windows-PC entpackt; der Starter öffnet dessen
Standardbrowser und bindet nur die dortige Loopback-Adresse. Flutter, Python und
Go sind beim Empfänger nicht nötig. Go-Serverquellen sind im Paket und Repository
enthalten. Der Hilfsserver wurde unter Linux per HTTP geprüft; Windows-Ausführung
und Browserpersistenz bleiben ungetestet. Keine Cloud-Veröffentlichung oder
Konfigurationspublikation, kein öffentlicher Tunnel.

Das zuvor gelieferte Windows-Paket gehört zu **0.16.0-rebuild.1+21** und enthält
die aktuellen UI-Korrekturen noch nicht. In dieser Runde wurde kein neues ZIP
erstellt. Die folgenden Starterprüfungen beziehen sich auf jenes frühere Paket.

Der Vorschau-Starter bestand drei lokale Tests: Auslieferung aus seinem eigenen
Paketordner unabhängig vom Arbeitsverzeichnis (auch mit Leerzeichen im Pfad),
Erkennung fehlender Webdateien und Konflikte mit einem belegten Port. Die
Windows-Binaries wurden mit Go 1.27.3 erzeugt und ihre PE-Zielarchitekturen geprüft.
Alle Dateien jenes ZIP wurden anhand der enthaltenen SHA-256-Liste geprüft; sein
Flutter-Web-Build entspricht bytegleich dem Stand `4e79901`.
Nachweise: `evidence/local-preview.json` und `evidence/local-preview-tests.txt`.

## Noch offen gegenüber der 0.15.3-Referenz

- Vollständige Funktions- und Pixelgleichheit. Die neuen Darstellungsoptionen
  sind rekonstruiert; exakte Geometrie, gekoppelte Transparenzen und sämtliche
  ursprünglichen Reglerstufen sind nicht vollständig abgeglichen.
- Vollständige Katalog-/Favoritenpflege für Auswahltexte und Auftragsvorschläge.
- Noch nicht vollständig angeglichen: Aufklappverhalten der HÜ-Karten,
  „Speichern & weiter“, sämtliche Übersichtsgruppen und Wischbedienung zwischen
  Hauptseiten. Die beschriebenen Original-Screenshots und Tafeltexturen fehlen.
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
