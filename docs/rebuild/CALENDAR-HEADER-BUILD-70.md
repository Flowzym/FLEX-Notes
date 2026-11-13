# Kalenderkopf · Webvorschau 0.23.1+70

Alle Kalenderaktionen sind in einer obersten Zeile direkt erreichbar:
Anlegen, Unterlagen, Verwalten, Unterricht, Stundenplan bearbeiten, in der Woche
Sa/So sowie Filter. Einheitliche Symbole mit Tooltips und zugänglichen Namen
ersetzen die verteilten Aktionszeilen. Aktive Ansichtsoptionen sind hinterlegt.

Darunter steht die gleichmäßig aufgeteilte Auswahl Tag/Woche/Monat. Erst danach
folgt der Zeitraum, mit Heute unmittelbar daneben und den Zeitraum-Pfeilen außen.
Der Zeitraum bleibt zum Auswählen eines Datums antippbar.

Die untere zusätzliche Kalenderleiste entfällt. Das globale Plus behält die
Übernahme des ausgewählten Datums und sitzt direkt über der Hauptnavigation.
Zusätzlicher Scrollabstand am Ende hält die letzten Inhalte erreichbar.

## Prüfung

- 29 unterschiedliche UI-/Integrationstests bestanden: `calendar_hub_test`,
  `build69_ui_test` und `calendar_redesign_ui_test`.
- Bestehende Layoutprüfungen kontrollieren zusätzlich die Reihenfolge der
  Kopfzeilen, alle Aktionen auf derselben Höhe, mindestens 40 × 44 Pixel große
  Trefferflächen sowie Heute unmittelbar neben dem Zeitraum. Tag, Woche und
  Monat werden bei 390/1100 Pixel Breite und 320 Pixel mit doppelter Schrift
  geprüft.
- Der erste kombinierte Lauf bestand 28 Prüfungen. Eine neue Größenprüfung
  scheiterte ausschließlich an Gleitkomma-Präzision (39,99999999999997 statt 40).
  Nach Ergänzung einer 0,01-Pixel-Toleranz bestanden alle 16 Kalenderprüfungen
  erneut. Die übrigen 13 Prüfungen waren bereits erfolgreich.
- Analyse ohne Befunde, Formatierung und `git diff --check` sauber.
- Release-Webbuild mit lokalen Rendering-Ressourcen. Chromium mit synthetischen
  Daten bei 390 × 844 und 320 × 844: Tag/Woche/Monat, Datum-Wischen,
  Heute-Rückkehr, siebentägige Woche und Öffnen der oberen Aktionsdialoge.

Die vollständige Testsuite und ein Android-Gerät wurden für diese Layoutänderung
nicht erneut geprüft. Die letzte APK bleibt Build 67. Datenmodell, gespeicherte
Einträge, Standardansicht und bestehende Webadresse sind unverändert.

[Prüfnachweise](evidence/build-70/) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
