# FLEX-Notizbuch – Dialogverfeinerung, 01.11.2026

Version **0.15.3+19** setzt die Rückmeldungen zu Kalender, Dialogfarben, Buttonflächen,
Abständen und ergänzenden Eingabebereichen um. Alle vorherigen Review-Korrekturen,
Bildmodi und getrennten Desktop-/Mobilbilder bleiben erhalten.

## Ergebnis

- Datum und optionale Uhrzeit in einem Kalender; kein Uhrzeit-Schalter in der
  Datumsleiste und kein nachgeschalteter Zeitdialog. Erinnerungen verwenden
  denselben Kalender mit erforderlicher Uhrzeit. Fälligkeitstermine bleiben separat.
- Situationsauswahl: Vor Unterricht, Unterricht, Nach Unterricht, Pause.
- Eine eigene gemeinsame Farbe für Kopf-/Datums-/Fußleisten der Dialoge unter
  Einstellungen → Darstellung → Dialoge. Transparenzen bleiben getrennt einstellbar.
- Eine durchgehende Buttonfläche für Auswahltext und Favoritenstern; einheitliche
  Filterchips und kontrastgerechte aktive Beschriftung.
- Kompakte Entwurfshinweise und geringerer Abstand unter Positiv/Negativ.
- Einheitliche Schalter für ergänzende Bereiche, „Kontext / Quelle“ und
  „Reaktion / Unterstützung“; kein „Weitere Angaben“-Trenner. Eingeklappte
  Eingabefelder behalten ihren Inhalt.

Details: [DIALOG_VERFEINERUNG.md](DIALOG_VERFEINERUNG.md).

## Tatsächlich geprüft und gebaut

| Prüfung | Ergebnis |
| --- | --- |
| Flutter / Dart | 3.47.9 / 3.13.7 |
| Statische Analyse | `flutter analyze --no-pub`: keine Befunde, 1,5 s |
| Vollständige Flutter-Suite | **319 bestanden**, 0 fehlgeschlagen, **140 s** |
| Kalender | Gemeinsames Übernehmen, Abbruch ohne Änderungen, 00:00, Entfernen optionaler Uhrzeit, Entwurf/Speichern/Neuladen, 320-Pixel-Ansicht |
| Bereiche / Entwürfe | Verborgene Inhalte erhalten, alte Zeitbezeichnungen, kompaktes Fortsetzen des gewählten Entwurfs, stabiler Rückmeldungsverlauf |
| Darstellung | Tatsächliche Buttonpixel für Text-/Favoritenfläche, Einstellungen im UI, gemeinsame Farbe und getrennte Transparenzen, Datenbank-/Vollsicherungsrundlauf, ältere Präferenzen |
| Renderings | **74** direkte Flutter-Ansichten mit synthetischen Daten; neue Ansichten 71–74 visuell kontrolliert |
| Web-Build | Erfolgreich in **48,8 s**, ohne externe Flutter-Ressourcen; Wasm-Vorprüfung erfolgreich |
| Prozessstart / HTTP | Linux-Vorschau auf Loopback-Port **8080** neu gestartet; acht HTTP-/Hash-/Headerprüfungen, Version **0.15.3+19** und Fingerabdruck der 16 benötigten Dateien bestanden |

Prüfnachweise: `flutter_app/review/dialog-evidence/`.
Keine Browserprüfungen und keine nativen Windows-/Android-Gerätetests ausgeführt.
Alle Testdaten und Testbilder sind synthetisch.

## Start und Lieferung

Webvorschau-ZIP vollständig entpacken, alten Vorschauprozess mit Strg+C schließen,
`Webvorschau-starten.cmd` doppelklicken. Python/`py`, Flutter und Go werden dafür
nicht benötigt. Die Server-EXE ist keine native Flutter-Windows-App.

Vollständige Quellen, Änderungen gegenüber dem Bildmodi-/Settings-Paket 0.15.2,
gebaute Webvorschau und 74 Ansichten werden separat als ZIP mit SHA-256-Manifesten
geliefert. Die 145 Originaldateien werden bei der Paketierung bytegenau mit dem
ursprünglichen Upload verglichen. Die HTML-Referenz bleibt unverändert.

SQLite und inneres Vollsicherungsformat bleiben Version 7. Die Dialogleistenfarbe
ist ein optionales Darstellungsfeld. Bei paralleler Nutzung sollten alle Fenster
die neue Version verwenden. Die aktive Datenbank bleibt lokal unverschlüsselt.

## Weiterhin ausstehend

- Native Windows-App mit Visual Studio C++-Werkzeugen/Windows SDK bauen und prüfen.
- Android-SDK/Build-Tools, Gerät/Emulator und private Release-Signierung; keine APK gebaut.
- Native Dateidialoge, OS-Backup-Regeln, Fenster-/Prozessende, Screenreader und
  Browserpersistenz praktisch prüfen.
- Vollständige HTML-Altdatenmigration, Synchronisation, Scanner, native
  Benachrichtigungen und physische Datenbankkompaktierung.
- Die im Chat gezeigten grünen Tafelmotive liegen nicht als lokale Originaldateien
  vor und sind noch nicht fest eingebunden; eigene Bilddateien lassen sich über
  die App auswählen. Siehe `BILDHINTERGRUENDE.md`.

Der Vorschauprozess läuft innerhalb der Cloud, nicht auf dem Windows-Rechner des
Nutzers. Es wurde keine Umgebung oder öffentliche Vorschau veröffentlicht.
