# Architekturentscheidungen und offene Prüfung

## Maßgebliche Referenz

Die aktuelle HTML-Datei und die Quellen vom 31.10.2026 sind fachlich maßgeblich.
Die ältere `architecture/Native_Umsetzung.txt` und das SQL-Zielschema wurden gelesen,
aber nicht unverändert als bereits implementierte Gesamtarchitektur ausgegeben.
Alle Originaldateien bleiben bytegleich erhalten.

Das ältere Zielschema bindet Erinnerungen ausschließlich an Aufgaben und kennt
keine eigenständigen Orga-Notizen. Die neuere Referenz erlaubt ausdrücklich Notizen
mit Erinnerung, ohne daraus eine offene Aufgabe zu machen. Die Flutter-Teilimplementierung
verwendet deshalb ein Orga-Aggregat mit unabhängigen Feldern `isTask`, `dueDate`,
`reminderAtUtc`, `reminderState` und eigenen Checklistenpunkt-IDs.

Das neue `assets/schema.sql` ist Version 1 dieser **separaten Flutter-Datenbank**,
nicht eine Migration oder Ersetzung des alten SQL-Dokuments. Die Tabellen für die
noch ausstehenden Beobachtungen, Situationen, Ziele und Hausübungen werden erst
mit deren Fachabläufen integriert. Das ältere Zielmodell hat etwa eine verpflichtende
Situation für Beobachtungen, während der Text Situationen optional erlaubt; auch
dies muss beim nächsten Ausbau ausdrücklich aufgelöst werden.

## Datenregeln

- Schüler oder Klasse: `pupil_id IS NULL` bedeutet Klassen-Orga; keine künstliche Person.
- Notizen haben weder Erledigtstatus noch Aufgabentermin, dürfen aber Checklisten
  und Erinnerungen besitzen. Offen/Erledigt-Filter zählen ausschließlich Aufgaben.
- Aufgabenabschluss beendet nur eine aktive Erinnerung. Quittierung lässt eine
  Aufgabe offen. Wiederöffnen reaktiviert keine Erinnerung. Der Editor erlaubt
  die ausdrückliche erneute Planung. Listenpunkte sind davon unabhängig.
- Fachliche Termine sind `YYYY-MM-DD`, keine UTC-Mitternachtsinstants.
  Erinnerungen sind einmalige UTC-Instants mit gespeicherter Geräte-Zonenbezeichnung
  und Offset. Noch keine IANA-Zonenauswahl, Wiederholungen oder native Zustellung.
- Archivieren löscht keine offenen Verpflichtungen. Der erste Schritt bietet
  bewusst noch kein Löschen fachlicher Einträge; ein späterer Papierkorb braucht
  Tombstones und eine eigene geprüfte Wiederherstellung.

## Speicherung, Revisionen, Synchronisation

Drift öffnet native SQLite-Dateien bzw. SQLite-WASM im Browser. Die DDL und SQL-Abfragen
sind explizit, ohne Build-Runner-Codegenerierung. Keine direkten SQL-Aufrufe aus Widgets.
Nach Commit lädt der Controller den Stand neu; es gibt keine irrtümlich reaktiven
Streams über nicht registrierte Drift-Tabellen.

Eine Transaktion umfasst Aggregate, Checklisten, Revision mit Vorher/Nachher,
Operation und Outbox. Entwurfsentfernung beim Veröffentlichen gehört zur gleichen
Transaktion. Fortlaufende Sequenzen pro Gerät und Basisrevisionen dienen als
logische Ordnung. Zeitstempel sind Anzeigeinformationen, keine Konfliktentscheidung.
Ein veralteter Editor wird abgewiesen; beide Fassungen bleiben in aktuellem Eintrag
und Entwurf erhalten. Eine automatische punktweise Zusammenführung ist noch nicht
implementiert. Checklisten-IDs und vollständige Vorherfassungen bereiten sie vor.

Die Geräte-ID ist eine lokale UUID, kein kryptografischer Schlüssel. Es werden keine
Dummy-Public-Keys erzeugt. Operation/Outbox ist nur eine lokale Anschlussstelle;
Kopplung, authentifizierte Übertragung, Quittungen, Konfliktauflösung zwischen Geräten
und Protokollkompatibilität sind spätere Aufgaben. Das Änderungsjournal ist nicht
manipulationsgeschützt.

## Entwürfe

400-ms-Autosave und Schreiben bei Schließen/Lebenszykluswechsel. Ein fehlgeschlagener
Schreibvorgang darf den Orga-Editor nicht schließen. Ein abruptes Prozessende vor
einem abgeschlossenen Autosave kann die letzten Eingaben verlieren; Betriebssystem-
Unterbrechungstests stehen noch aus. Auch ein nicht per Plus bestätigter letzter
Checklistenpunkt wird in der Entwurfsfassung aufgenommen. Die Basisrevision bleibt
für die gesamte Bearbeitung konstant. Mehrere Editoren behalten eigene Entwurfs-IDs.
Schüler-Stammdaten haben bislang einen Speichern/Abbrechen-Dialog ohne dauerhaften Entwurf.

## Sicherungen und Migration

Die eigene versionierte Vollsicherung enthält alle Datentabellen einschließlich
Revisionen, Operationen, Outbox, Entwürfen und unveränderten HTML-Backups. Sie wird
transaktional erstellt; eine Wiederherstellung erfolgt nur in einen leeren Bestand
mit Feld-/Fremdschlüssel-/Domänenprüfung und Rollback bei Fehlern. Das neue Gerät
behält seine eigene lokale Geräte-ID. Noch kein Zusammenführen zweier Flutter-Backups.

HTML-V3/Schema-5-Sicherungen werden nur auf ihren erkennbaren Aufbau geprüft und
als vollständiger Originaltext vorgemerkt. Das ist keine vollständige Validierung
oder Migration. Unbekannte Felder, frühere Fassungen, alte IDs, Entwürfe und andere
Fachbereiche bleiben dadurch erhalten. Wiederholtes Vormerken identischer Bytes
ist idempotent. Verschlüsselte FLEX-Encrypted-V1-Sicherungen werden erkannt, aber
noch nicht entschlüsselt. Keine automatische Aktivierung von Teilbeständen.

Vor echter Datenübernahme fehlen: vollständiger Migrationsadapter aller Fachbereiche,
sichtbare Importbefunde, Probeexport/Wiederimport und Vergleich aller Beziehungen,
Revisionen und Entwürfe sowie durchgeführte Repository- und Gerätetests.
