# Papierkorb und Wiederherstellung – Version 0.9.0+9

Historischer Umsetzungsschritt. Endgültiges Leeren ist seit Version 0.10.0+10
zusätzlich umgesetzt: `PAPIERKORB_ENDGUELTIG_LEEREN.md`.

Referenz: `deleteRecord`, `drawUndo`, `undoDelete`, `drawTrash`,
`restoreTrashRecord` und die Daten-Einstellungen der aktuellen HTML-Datei.
Alle Originaldateien bleiben unverändert. Die native Umsetzung verwendet die
vorhandenen Löschmarkierungen und Änderungsrevisionen; das Schema bleibt Version 6.

## Bedienung

1. Einen gespeicherten Eintrag aufklappen und **In den Papierkorb** wählen.
   Dies funktioniert jetzt auch für Schüler-Orga und Klassen-Orga.
2. Der Eintrag verschwindet aus aktiven Listen, Übersicht und Gesprächsauswahl.
   Eine aktive Orga-Erinnerung wird beendet. Aufgabenabschluss, Aufgabentermin,
   Checklistenpunkte und ihre IDs bleiben unverändert.
3. **Rückgängig** stellt die zuletzt gelöschte Fassung direkt wieder her.
   Der Hinweis ist wie im HTML im geöffneten Dialog sichtbar. Sein Schließen
   blendet nur den Hinweis aus; der Eintrag bleibt im Papierkorb.
4. Für spätere Wiederherstellung: **… → Einstellungen → Daten → Papierkorb öffnen**.
   Die gemeinsame Liste zeigt Schüler beziehungsweise Klasse, Bereich, Inhalt,
   Löschzeit, Aufgaben-/Erinnerungszustand und vorhandene Bearbeitungsentwürfe.
5. **Wiederherstellen** holt den Eintrag zurück. Bei einer durch die Löschung
   beendeten Erinnerung ist **Erinnerung wieder aktivieren** vorausgewählt.
   Der angezeigte ursprüngliche Zeitpunkt gilt auch dann, wenn er bereits
   vergangen ist. Ohne Haken bleibt die Erinnerung beendet.

Bereits quittierte oder schon vor dem Löschen beendete Erinnerungen werden nicht
reaktiviert. Das direkte Rückgängig stellt den ursprünglichen Zustand wieder her,
wenn der passende Löschbeleg vorhanden ist. Bei älteren gelöschten Daten ohne
passenden Verlauf wird eine aktive Erinnerung nicht aus einem beendeten Zustand
abgeleitet. Die zusätzliche sichtbare Erinnerungsoption ist eine bewusste
Ergänzung zum unmittelbaren Wiederherstellen im HTML.

## Entwürfe und Konflikte

Begonnene Bearbeitungen bleiben erhalten, auch wenn der zugehörige Eintrag
zwischenzeitlich gelöscht wird. Speichern und „Entwurf übernehmen“ dürfen eine
Löschung nicht unbemerkt aufheben. Die Konfliktansicht zeigt deshalb zuerst
**Papierkorb öffnen** und **Entwurf öffnen**. Nach der bewussten Wiederherstellung
kann der Entwurf wie bisher als neue Fassung übernommen werden.

Jeder Lösch-/Wiederherstellungsbefehl ist an die angezeigte Versionsnummer gebunden.
Zwischenzeitliche Änderungen werden abgewiesen. Nach einem Fehler bleiben Karte,
Entwurf und gewählte Erinnerungsoption erhalten; **Daten erneut laden** aktualisiert
eine veraltete Liste. Der Änderungsverlauf zeigt auch die gelöschte Fassung.

Gemeinsame Kontexte und Bezüge zu Zielen bleiben erhalten. Eine individuelle
Wiederherstellung aus einer zurückgenommenen Gruppe betrifft nur diesen Eintrag;
andere Gruppeneinträge und der Wiederaufnahmeentwurf bleiben bestehen. Schüler
selbst werden weiterhin über das Archiv verwaltet.

## Umfang und Nachweise

Dieser Schritt umfasst reversible Löschung, direktes Rückgängig und dauerhafte
Wiederherstellung für Orga, Ziele, Sozialverhalten, Arbeitsverhalten und Hausübung.
**Endgültiges Leeren und Speicherkompaktierung bleiben offen.** Dafür müssen
zusätzlich frühere Fassungen, Operationen, Outbox und abhängige Verknüpfungen
bereinigt werden. Es gibt keinen Knopf, der diese noch fehlende Funktion vorspiegelt.

Geprüft werden ausschließlich synthetische Daten: Inhalte und stabile IDs,
Aufgaben-/Erinnerungstrennung, quittierte und beendete Zustände, Konflikte,
Transaktionsfehler, erhaltene Entwürfe, gemeinsame Kontexte, Gruppenrücknahmen,
SQLite-Dateineustart und Vollsicherungen. Ein beschädigter Löschverlauf wird beim
Import abgewiesen, ohne einen Teilbestand zu aktivieren. Widgettests prüfen beide Löschwege,
Rückgängig im Dialog, Daten-Einstellungen, Erinnerungswahl, Fehlerversuche,
Entwurfskonflikte und mobile Darstellung. Konkrete Ergebnisse und Startnachweise:
`FLUTTER_STATUS.md`.
