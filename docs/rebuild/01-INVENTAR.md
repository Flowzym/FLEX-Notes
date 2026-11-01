# Wiederaufbau: geprüfte Ausgangsbasis

Branch: `rebuild/flutter`, Basis `recovery/webpreview` bei Commit
`8a97a94d2854b43427c1016748b2adab431879f5`.

Der tatsächliche Repository-Inhalt bestand anfangs aus acht Sicherungsdateien.
Aus dem Quellenarchiv 0.1.0+1 wurden 173 Dateien bytegleich wiederhergestellt:
das Flutter-Grundprojekt mit 14 Dart-Dateien, der HTML-Prototyp und seine
Architektur-/Entwicklungsunterlagen. Die 145 Dateien außerhalb des Flutter-
Grundprojekts sind historische Referenzen, keine Anweisungen für diesen Auftrag.
Die App wird als Flutter-UI rekonstruiert; HTML wird nicht eingebettet.

Die 18 Markdown-Dokumente und das SQL-Schema 7 aus dem Webpreview liegen als
unveränderte Referenz unter `reference/webpreview-0.15.3+19/`. Die gebaute Web-App
und alle Originalarchive unter `recovery/` bleiben unverändert. Die Bildvorlage
des Nutzers zeigt fünf gefüllte Hauptsymbole: Zielscheibe mit Pfeil, Personen,
Dokument, Haus und Kalender. Diese werden als skalierbare Flutter-Grafiken
umgesetzt; die Bilddatei selbst lag hier nicht als lokal zugängliche Datei vor.

## Nachgewiesener Ausgangsstand

- Schülerverwaltung, Orga, Entwürfe, lokale SQLite-Revisionen und JSON-Sicherung
  sind in den 0.1.0-Quellen enthalten.
- Ziele, Sozial-/Arbeitsbeobachtungen und Hausübungen sind dort noch Platzhalter.
- Für 0.15.3+19 liegen nur Build, Schema und Dokumentation vor, keine Dart-Quellen.
- Für 0.16.0+20 liegen weder Quellen noch Build vor. Neuer Code ist ausdrücklich
  eine Rekonstruktion, keine Wiedergewinnung dieser fehlenden Originalquellen.

## Prüfung dieser Ausgangsbasis

- Alle 173 extrahierten Dateien byteweise mit dem Quellenarchiv verglichen.
- Alle sechs gesicherten Dateien gegen `recovery/SHA256SUMS` geprüft.
- Die elf SQLite-Schema-Tests des ursprünglichen Flutter-Projekts bestanden.
- Der SQLite-Test des ursprünglichen Architektur-Zielschemas bestand.
- Kein Browser geöffnet; keine HTML-/Browser-Testskripte ausgeführt.

Flutter-Analyse, Widgettests und Web-Build sind eigene folgende Prüfschritte.
Historische Testzahlen in den unveränderten Referenzdokumenten sind keine neuen
Prüfnachweise. Neue Arbeitsbereiche starten ohne Beispieldaten; nur Tests verwenden
synthetische Schüler und Inhalte. Keine Veröffentlichung der Cloud-Umgebung.
