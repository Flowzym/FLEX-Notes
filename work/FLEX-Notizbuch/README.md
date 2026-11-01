# FLEX-Notizbuch – Review umgesetzt im HTML-Prototyp

Die App bleibt eine eigenständige HTML-Datei mit lokaler Speicherung.
Der aktuelle Umfang und die noch offenen nativen Funktionen stehen vollständig
in [UMSETZUNGSSTAND.txt](UMSETZUNGSSTAND.txt).

## Bauen

Im Projektverzeichnis: `node scratch/upgrade-reliable.cjs`.
Immer die Quellen ändern; die HTML-Ausgabe wird daraus erzeugt.
Historische einmalige Patchskripte nicht erneut ausführen.

## Aktueller Aufbau

- `scratch/domain-model.js`: gemeinsame Situationen, individuelle Beobachtungen,
  strukturierte Listen, Revisionen, Konflikterkennung und Validierung.
- `scratch/reliable-app.js`: lokales Operationsjournal und bestehende Erfassung.
- `scratch/edit-protection.js`: gesicherte Bearbeitungsentwürfe und Wiederaufnahme.
- `scratch/import-recovery.js`: Import, Zusammenführung und Wiederherstellung.
- `scratch/backup-crypto.js`: optionale Verschlüsselung von Sicherungsdateien.
- `scratch/review-interface.js`: gemeinsame Situationen, individuelle Mehrfach-
  erfassung, Klassenaufgaben, Konfliktliste und Entwurfsübersicht.
- `architecture/schema-v1.sql`: geprüftes SQLite-Zielschema für die native App.
- `architecture/Native_Umsetzung.txt`: Fachmodell, Bedien- und Synchronisationsvertrag.

## Lokale Prüfung ohne Browser

`node scratch/run-local-review.cjs` führt die zwölf aktuellen Node-Suiten aus.
`python architecture/test_schema.py` prüft das native Zielschema isoliert.
Historische Browserprüfungen sind mitgeliefert, gehören aber nicht zur aktuellen
Freigabe. Keine persönlichen Daten oder Browserspeicher für Tests verwenden.

## Daten und Grenzen

Die vorhandenen Daten bleiben erhalten. Neue Arbeitsbereiche starten leer.
Sicherungen sind wahlweise verschlüsselt oder normales JSON. Gesprächsexporte
sind ausgewählte aktuelle Texte, keine vollständigen Sicherungen. Das Weglassen
strukturierter Beteiligtennamen anonymisiert keine Namen im freien Text.

Die aktuelle App enthält keinen WLAN-/Bluetooth-Abgleich und keine nativen
Benachrichtigungen. Es gibt noch keine APK/EXE und keinen getesteten Flutter-Build.
Die Darstellung und Bedienung der neuen Elemente wurden nicht im Browser geprüft.

## Einstellungen

Drei Bereiche: Darstellung, Bedienung und Daten. Unter Darstellung stehen
Stilvorlagen und die gemeinsame Flächeneinstellung direkt bereit. Aufklappbare
Gruppen bündeln Hintergrund, Hauptansicht, Buttons/Eingabefelder und Dialoge.
Die Live-Vorschau steht am Desktop daneben, auf kleinen Ansichten aufklappbar darüber.
Die Shortcut-Reihenfolge steht unter Bedienung. Sicherung/Import, Papierkorb und
Speicherpflege stehen unter Daten. Alle bisherigen Regler bleiben erhalten.
Bereich, geöffnete Gruppen und Vorschauzustand bleiben innerhalb der Sitzung erhalten.

## Gemeinsame Orga

Orga bündelt Notizen, Aufgaben, Checklisten und Erinnerungen. Der Schalter
„Als Aufgabe“ steuert den Erledigtstatus; Termin und Erinnerung sind getrennt.
Notizen zählen nicht als offene Aufgaben. Die Filter Alle/Offen/Erledigt zeigen
in Offen und Erledigt ausschließlich Aufgaben. Listenpunkte bleiben unabhängig
vom Aufgabenabschluss. Erledigen beendet eine ausstehende Erinnerung; Quittieren
einer Erinnerung erledigt die Aufgabe nicht. Wiederöffnen reaktiviert die Erinnerung
nicht automatisch; dies ist ausdrücklich im Editor möglich.

Alte eigenständige Erinnerungen werden beim Laden und Import deterministisch zu
Orga-Aufgaben, verknüpfte Orga-Notizen bleiben Notizen. Originalfassungen und IDs
bleiben erhalten. Alte Reminder-Entwürfe öffnen sich im gemeinsamen Orga-Editor.
Klassen-Orga verwendet denselben Ablauf ohne Schülerzuordnung. Die Übersicht
zeigt Aufgaben und Erinnerungen als getrennt beschriftete Ereignisse.

Quellen: `domain-model.js` (Migration), `entry-experience.js` (gemeinsame Felder),
`orga-unified.js`/`.css` (Listen und Bedienung), `work-overview.js` (Übersicht).
Die 14 neuen lokalen Integrationsgruppen prüfen Migration, Import, Journal,
Speicherfehler, Aufgaben-/Erinnerungszustände, Klassen-Orga und alte Entwürfe.

## Schülerübersicht

Die Einstiegsansicht „Aktuell“ zeigt Anstehendes, noch zu ergänzende Dokumentation
und zuletzt abgeschlossene/gespeicherte Einträge getrennt. Fällige Vorgänge stehen
vor späteren Terminen und undatierten Zielen/Aufgaben. Aufgabe und zugehörige
Erinnerung stehen in einer Zeile mit getrennten Zeitangaben. Offene Aufgaben
lassen sich direkt erledigen; aktive Ziele direkt überprüfen. Jede Gruppe zeigt
zunächst wenige Einträge und kann vollständig aufgeklappt werden.

Checklisten erscheinen als lesbare Vorschau mit Fortschritt; die Bearbeitung der
Listenpunkte bleibt in der vollständigen Eintragsansicht. Die fünf Bereiche sind
direkt erreichbar. Suche, Wochenfilter, offene Vorgänge und gesamter Verlauf
bleiben verfügbar. Der Kopf hebt den Schülernamen hervor.

Die Darstellung entsteht in `scratch/pupil-overview.js` und `.css`. Neun lokale
Prüfgruppen decken Reihenfolge, Mehrfachanzeige, Filter, Escaping, Datenisolation,
verwaiste Hausübungen, unveränderte Daten, lange Listen und Altbestände ab.
