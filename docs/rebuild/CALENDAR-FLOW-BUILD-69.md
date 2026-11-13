# Kalender, individuelle Abläufe und schnelles Anlegen · 0.23.0+69

## Verhalten

- **Kalender:** kompakter Kopf ohne große runde Datumsbuttons oder doppelte
  Wochenüberschrift. Tag/Woche/Monat, Unterricht, Wochenende und Stundenplanbearbeitung
  bleiben direkt erreichbar. Wischen im Kalender wechselt den Zeitraum, Wischen auf
  der Hauptpille weiterhin Kalender/Aufgaben. Die Richtung bleibt konsistent.
- **Standardansicht:** Mehr → Einstellungen → Bedienung → Kalender · Standardansicht.
  Tag, Woche oder Monat werden gespeichert, mitgesichert und beim nächsten Start
  der Kalenderseite verwendet. Ein normaler Ansichtswechsel überschreibt den Standard nicht.
- **Schmale Woche:** fünf und sieben Tage passen bei normaler Schrift vollständig
  in 320 px. Bei großer Schrift stehen horizontales Scrollen, sichtbarer Scrollbalken
  sowie Sprünge zum Wochenanfang und Wochenende zur Verfügung. In diesem breiten
  Raster scrollt die horizontale Geste die Tages-Spalten; im Kalenderkopf wechselt
  sie weiterhin die Woche. Ereignisse lassen sich öffnen, überlappende Einträge bleiben erreichbar.
- **Navigation:** direkter, synchroner Zustand statt nachträglicher PageController-Sprünge.
  Zyklische Reiter behalten auch bei schnellen Wischfolgen ihre Reihenfolge. Der
  aktive Bereich unten ist durch kleinen Symbolhintergrund, Schrift und Strich deutlicher.
- **Plus-Menü:** schwebender Hinzufügen-Button auf den Hauptseiten und in der
  Schülerübersicht. Gruppierte direkte Aktionen für Sozial, Arbeit, Ziel, HÜ, Notiz,
  Aufgabe, Termin, Rücklauf, Scan/Bild, Datei, Link, Materialpaket, Planung,
  Unterricht, Ferien/Ausfall sowie Schüler und Gruppeneinträge. Bestehende Editoren,
  Entwürfe und Scanner werden wiederverwendet. Schülerkontext wird übernommen;
  ohne Kontext wählen Schülereinträge zunächst einen Schüler. Kalenderaktionen
  erhalten das aktuell ausgewählte Datum, auch nach Wischen.
- **Ablauf:** Gemeinsam/Individuell. Jeder Schüler erhält bei erster Änderung eine
  unabhängige Folge aus den für ihn passenden gemeinsamen Phasen, ohne deren Fortschritt.
  Eigene Dauer, Auftrag, Materialien, Reihenfolge, Start/Pause/Weiter und Fortschritt.
  Gemeinsam gestartete Phasen schalten individuelle Abläufe nicht weiter. Die
  Schülerliste bietet direkte Statusaktionen und Materialien. Offenes weiterführen
  bleibt beim selben Schüler; Vorlage und ursprünglicher Verlauf bleiben erhalten.
- **Materialzugriff:** sichtbarer Materialbutton ohne Bearbeitungsmodus, Suche,
  Zugeordnet/Alle Materialien, Vorschauen, direktes Öffnen und Zuordnung zur Phase
  oder zum Unterrichtstag. Gemeinsame Dateien werden nicht dupliziert. Individuelle
  HÜ-Kontrolle wird auf den jeweiligen Schüler eingegrenzt.
- **Unteraufgaben:** bei Aufgaben direkt im Editor anlegbar und in Aufgabenlisten
  einzeln abhakbar; zusätzliche Unteraufgabe auch direkt von der Karte aus. Alle
  erledigt schließt die Aufgabe ab; ein neuer/offener Punkt öffnet sie wieder.
  Gesamtes Erledigen hakt die Punkte mit ab. Bearbeiten, Entfernen und Entwurfs-
  speicherung bleiben verfügbar. Notiz-Checklisten ändern keinen Aufgabenstatus.
- **Aktuell:** eigener Bereich Überfälliges mit Anzahl, Aufgaben, HÜ,
  Zielüberprüfungen, fälligen Erinnerungen und offenen Rückläufen. Anstehend enthält
  die übrigen offenen Einträge. Erledigte Einträge verschwinden aus Überfälliges.

## Daten und Grenzen

Keine SQL-Migration, keine Löschung bestehender Einträge. Individuelle Abläufe
verwenden das optionale validierte `flow.pupilId`; Zuordnungen werden geprüft und
beim Zusammenführen auf lokale Schüler-IDs abgebildet. Fortschritte verschiedener
Schüler liegen in getrennten Dokumenten mit Revisionsschutz. Alte Abläufe ohne
`pupilId` bleiben gemeinsame Abläufe. Neue Sicherungen mit individuellen Abläufen
benötigen Build 69 oder neuer; ältere Sicherungen bleiben importierbar.
Unteraufgaben verwenden die vorhandenen CheckItem-IDs und Speicherung.

Der Scanner nutzt weiter die bestehende Kamera-/Importfunktion. Diese Änderung
ist eine Webvorschau; letzte Android-APK bleibt Build 67. Neue Kamera- oder
Benachrichtigungstests auf echter Android-Hardware wurden hier nicht durchgeführt.

## Nachweise

- 181 gezielte Regressionstests: Ablauf, HÜ, Kalender, Navigation, Orga,
  Übersicht, Materialzuordnung, Unterrichtsserien, Klassen-Daten und Backup-Merge.
- 19 ergänzende UI-Tests einschließlich der 9 neuen Integrations-/Layoutprüfungen
  und bestehender Klassen-UI: insgesamt 200 unterschiedliche Prüfungen.
- Nach der letzten Korrektur der Fünftagebreite 26 relevante UI-Prüfungen erneut
  bestanden (Kalender, neue Funktionen und Navigationslayout).
- Statische Analyse ohne Befunde; Formatierung und Git-Diff geprüft. Keine
  vollständige Testsuite in diesem Schritt.
- Release-Webbuild mit lokalen CanvasKit-Ressourcen. Touch-Browser mit synthetischen
  Testdaten: zyklische Hauptnavigation in allen fünf Bereichen, Kalenderwischen,
  Plus-Menü und schmale Wochenansicht. Individueller Ablauf gestartet/pausiert,
  anderer Schüler auf 25 Minuten angepasst; Fortschritt und Dauer nach Neuladen
  erhalten. Materialablage direkt aus dem Ablauf geöffnet. Keine JavaScript-Seitenfehler.

[Logs und Bildschirmansichten](evidence/build-69/) ·
[Private Vorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
