# Architektur der Rekonstruktion

## Herkunft

Die überlieferte 0.1.0-Implementierung liefert SQLite/Drift, Schülerverwaltung,
Orga, Revisionen, Entwürfe und Controller. Der HTML-Prototyp und die Dokumente
des Webpreview beschreiben den Ausbau. Die erhaltene SQL-DDL 7 wird bytegleich
als `assets/schema.sql` verwendet. Neuere originale Dart-Quellen fehlen.
Das Webpreview wird nicht modifiziert und nicht in die Flutter-App eingebettet.

## Schichten

- `domain/models.dart`: Schüler-/Orga-Modelle und Darstellung.
- `domain/school.dart`: rekonstruierte Beobachtungen, Ziele, Aufgaben,
  Rückmeldungen, Überprüfungen und typisierte Entwürfe.
- `data/database.dart`: Drift, explizite DDL und Migration 1 → 7.
- `data/sqlite_notebook.dart`, `data/school_store.dart`: parametrisierte SQL-
  Zugriffe, Validierung, Transaktionen, Revisionen, Operationen und Outbox.
- `application/notebook_controller.dart`: Laden und Mutationen. Generations-
  nummern verhindern, dass ältere Nachladevorgänge neuere Ergebnisse ersetzen.
  Jeder Gesamtabzug wird in einer gemeinsamen SQLite-Lesetransaktion geladen.
- `ui/flex_modal.dart`: gemeinsame Dialoghülle und Kalender mit optionaler Zeit.
- `ui/prototype_navigation.dart`, `ui/pupil_card.dart`: zentrierte Pillennavigation
  und Schülerkarten nach den endgültigen HTML-Regeln. `notebook_screen.dart`
  öffnet Schülerbereichslisten in derselben gerahmten Dialogfamilie wie Editoren.
  Die jüngeren Vorgaben aus dem alten Chat bestimmen Außenabstand, Radius und
  Standardbreite; Hauptseiten bleiben außerhalb der Dialoge.
- `ui/school_editor.dart`: Editoren einschließlich Kommentar-Fokus,
  Empfänger-Tags, Entwürfen und Zielüberprüfung.
- `ui/school_workspace.dart`: HÜ-Standbuttons, Rückmeldungsverlauf, Papierkorb,
  Gruppenrücknahme und Gesprächsauswahl.
- `ui/flex_icons.dart`: fünf gefüllte, direkt durch Flutter gezeichnete Symbole.
- `ui/appearance_settings.dart`, `ui/surfaces.dart`: getrennte Desktop-/Mobil-
  Hintergrundbilder, Bildmodi, Farben, Deckkraft und kontrastabhängige Schrift.
- `security/backup_codec.dart`: Standard-Kryptografie über `cryptography`.
- `ui/backup_dialog.dart`: Sicherungsdialog, Datei-/Zwischenablage-Ausgabe und
  Wiederherstellung. Native Schlüsselableitung läuft über `compute` außerhalb
  des UI-Isolates; im Web nutzt die Bibliothek verfügbare Plattformverfahren.

## Datenvertrag

Speichern schreibt Fachdatensatz, Revision, Operation und Outbox atomar. Das
Entfernen des zugehörigen Entwurfs gehört zur selben Transaktion. Alte
Basisrevisionen werden abgewiesen. Auch beim Veröffentlichen eines Entwurfs wird
dessen aktuelle Revision innerhalb der Transaktion geprüft. Zusätzliche Personen in einem Kontext
erhalten dadurch keine Einzelbewertung.

HÜ-Aufgaben haben stabile IDs und unabhängige Zustände. Rückmeldungen enthalten
fachliches Datum, optionale Uhrzeit, Aufgaben-Snapshot und optional Stand,
Abgabe oder Kommentar. Der aktuelle Stand folgt den gültigen chronologisch
geordneten Rückmeldungen. Kommentar und Abgabenotiz verändern ihn nicht.
Entfernen einer Rückmeldung stellt den vorherigen Stand wieder her. Umbenennen
von Aufgaben verändert keine historischen Text-Snapshots; beim Entfernen einer
Hauptaufgabe werden deren Teilaufgaben zu Hauptaufgaben.

HÜ-Gruppen werden atomar gespeichert und erhalten getrennte Aufgaben-IDs pro
Kind. Rücknahme ist nur für unveränderte Einträge ohne Bearbeitungsentwürfe
zulässig und erzeugt wieder einen Entwurf. Mehrfache Rücknahme ist wirkungslos.
Das ist keine allgemeine Synchronisation oder Undo-Engine.

Fachliche Entwürfe enthalten Modus und Revision. Kommentare und Zielüberprüfungen
öffnen beim Fortsetzen ihren jeweiligen Editor. Fach-Payloads tragen
`rebuildFormat: 1`. Fremde neuere Formate werden nicht still interpretiert.
Die neue Datenbank hat einen getrennten Namen.

Orga enthält fachliches Datum und optionale Uhrzeit unabhängig vom Erstellzeitpunkt.
Weiches Löschen setzt eine geplante Erinnerung auf abgebrochen. Wiederherstellen
erhält Aufgaben-/Checklistenstände und aktiviert die Erinnerung nicht automatisch.

## Prüfung und Grenzen

Repositorytests verwenden echtes SQLite im Speicher bzw. temporäre Dateien.
Widgettests und Bildausgaben laufen direkt mit Flutter, mit synthetischen Daten
und ohne Browser. Renderings laden die mitgelieferten Schriften. Browser-
persistenz, native Dateiwähler und Windows-/Android-Geräte bleiben offene
Abnahmen. Weitere Unterschiede: `../docs/rebuild/STATUS.md`.
