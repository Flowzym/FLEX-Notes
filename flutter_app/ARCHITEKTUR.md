# Architektur der Flutter-App

Aktualisiert für 0.17.1+58. Aktueller Prüfumfang:
[`docs/rebuild/QUALITY-BUILD-58.md`](../docs/rebuild/QUALITY-BUILD-58.md).

## Herkunft

Die überlieferte 0.1.0-Implementierung liefert SQLite/Drift, Schülerverwaltung,
Orga, Revisionen, Entwürfe und Controller. Der HTML-Prototyp und die Dokumente
des Webpreview beschreiben den Ausbau. Die erhaltene SQL-DDL 7 wird bytegleich
als `assets/schema.sql` verwendet. Neuere originale Dart-Quellen fehlen.
Die aktuelle Webvorschau wird aus derselben Flutter-App gebaut; der historische
HTML-Prototyp wird nicht in die App eingebettet.

## Schichten

- `domain/models.dart`: Schüler-/Orga-Modelle und Darstellung.
- `domain/school.dart`: rekonstruierte Beobachtungen, Ziele, Aufgaben,
  Rückmeldungen, Überprüfungen und typisierte Entwürfe.
- `data/database.dart`: Drift, explizite DDL und Migration 1 → 7.
- `data/sqlite_notebook.dart`, `data/school_store.dart`: parametrisierte SQL-
  Zugriffe, Validierung, Transaktionen, Revisionen, Operationen und Outbox.
- `application/notebook_controller.dart`: Laden und Mutationen. Generations-
  nummern verhindern, dass ältere Nachladevorgänge neuere Ergebnisse ersetzen.
  Jeder Gesamtabzug wird in einer gemeinsamen SQLite-Lesetransaktion geladen;
  nach dem Freigeben des Controllers werden ausstehende Ergebnisse verworfen.
- `ui/flex_modal.dart`, `ui/detail_flow.dart`: gemeinsame Dialog-/Seitenhülle
  mit erhaltenem Eingabezustand bei Tastatur- und Größenwechseln.
- `ui/app_navigation.dart`, `ui/notebook_screen.dart`: untere Bereichsnavigation
  und obere kontextbezogene Navigationskapseln. Hauptbereiche sind Kalender,
  Live, Organisation, Material und Mehr.
- `ui/pupil_card.dart`: offene Schülerzeilen mit fünf direkt sichtbaren Aktionen.
- `ui/school_editor.dart`: Editoren einschließlich Kommentar-Fokus,
  Empfänger-Tags, Entwürfen und Zielüberprüfung.
- `ui/school_workspace.dart`: HÜ-Standbuttons, Rückmeldungsverlauf, Papierkorb,
  Gruppenrücknahme und Gesprächsauswahl.
- `ui/flex_icons.dart`: gemeinsame Symbole für die fachlichen Bereiche.
- `ui/appearance_settings.dart`, `ui/surfaces.dart`, `ui/app.dart`: feste
  Creme-/Salbei-Gestaltung und gemeinsame Flächen-/Schrift-/Formularregeln.
  Einstellbar bleiben Hell/Dunkel/System und Schriftgröße. Alte Bild-, Farb-,
  Deckkraft- und Formeinstellungen werden nicht mehr angewendet.
- `ui/calendar_page.dart`: gemeinsame Kalender-/Stundenplanansichten mit
  Datumsnavigation und aktueller Zeitmarkierung.
- `ui/scan_editor.dart`: Scan-/Fotobearbeitung, Entwürfe, Ersetzen und Ausgabe;
  gespeicherte Metadaten und das nachfolgende Aufräumen alter Dateien bleiben
  getrennte Schritte.
- `services/reminders.dart`: Terminableitung und native Planung. Änderungen
  an Einstellungen werden auch über Berechtigungsabfragen hinweg serialisiert.
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
Widgettests und Bildausgaben laufen direkt mit Flutter und synthetischen Daten.
Renderings laden dieselben lokalen Inter-Schriften wie die App. Ergänzende
Chromium-Durchgänge prüfen Browser-Persistenz, Entwürfe, Veröffentlichung und
Sicherungsexport. Statische Analyse, SQLite-Tests, gesamte Flutter-Suite sowie
Web- und Android-Build sind Bestandteil von GitHub Actions. Physische Android-
Kamera, Biometrie und Hintergrund-Erinnerungen sowie echte OneDrive-Anmeldung
benötigen weiterhin gesonderte Abnahmen. Der aktuelle Stand und die Nachweise
stehen in [`docs/rebuild/STATUS.md`](../docs/rebuild/STATUS.md).
