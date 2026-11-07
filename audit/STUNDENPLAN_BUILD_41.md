# Bearbeitbarer Stundenplan · Build 41

Der Kalender enthält unter **Stundenplan** den Plan aus der bereitgestellten PDF,
wöchentlich ab **Montag, 9. November 2026**. Die zwölf Unterrichtsblöcke, zehn
Stundenzeiten, Kürzel und Räume sind übernommen. Flexk bleibt als zusammenhängender
Block erhalten, ebenso TDTE über die siebte und achte Stunde. Unterricht in erfassten
Ferien entfällt automatisch.

## Bedienung

- Am Handy erscheint eine Tagesliste mit direkt erreichbaren Wochentagen; auf breiten
  Displays ein Wochenraster. Zwischen beiden Darstellungen kann gewechselt werden.
- Ein Block öffnet seine Bearbeitung: Bezeichnung, Wochentag, erste/letzte Stunde,
  individuelle Beginn-/Endzeit, Lehrkraft, Raum und Notiz.
- **Block hinzufügen** ergänzt eine eigene Serie. **Block entfernen → Speichern**
  verschiebt die Serie in den Papierkorb; Wiederherstellen ist direkt möglich.
- **Stundenzeiten** ändert das allgemeine Zeitraster sowie Beginn/Ende der Gültigkeit.
  Blöcke folgen geänderten Standardzeiten; individuell abweichende Zeiten bleiben erhalten.
- Änderungen im Stundenplan gelten für die gesamte betroffene Serie. Änderungen nur
  einer Durchführung oder ab einem bestimmten Termin bleiben im Kalender erreichbar.
- Entwürfe werden automatisch gesichert und über die vorhandene Entwurfsübersicht
  wieder mit dem passenden Editor geöffnet; Verwerfen bleibt möglich.

## Bestand und Verknüpfungen

Ein Arbeitsbereich ohne Unterrichtsserien erhält den Plan einmalig. Bereits vorhandene
Serien, auch gelöschte, verhindern ein automatisches Ergänzen. Dann zeigt **Stundenplan**
die PDF-Vorlage mit **Stundenplan übernehmen**; vorhandene Kalendereinträge bleiben erhalten.
Spätere Starts überschreiben weder Änderungen noch Löschungen.

Die Blöcke sind reguläre Kalender-Unterrichtsserien. Material-/Planungszuordnungen,
Ausnahmen und verschobene Einzelstunden bleiben erhalten. Ein Wochentagwechsel
verschiebt die ursprünglichen Ausnahmedaten und zugehörigen Erinnerungsbezüge;
explizit verschobene Durchführungsdaten bleiben unverändert. Änderungen der Stundenzeiten
schreiben keine bereits aufgeteilten Serien wieder zusammen. Zeiträume, die vorbereitete
Durchführungen ausschließen würden, werden mit einer Fehlermeldung abgelehnt.

Stundenplan und abhängige Blöcke werden gemeinsam in einer Datenbanktransaktion geändert.
Veraltete Fassungen oder ungültige Stundenreferenzen führen zum vollständigen Rollback.
Normale Sicherungen, Wiederherstellung und Zusammenführen enthalten den Stundenplan.

Version **0.16.0-rebuild.21+41**, SQLite-Schema 7, App-ID und Testsignatur bleiben erhalten.
Es findet keine Datenlöschung statt. Android wird über die bestehende FLEX Test installiert.
Die Webvorschau bleibt auf derselben Website, damit der lokale Browserbestand erhalten bleibt.

## Prüfungen

Automatisierte Domain-, Datenbank- und Widgettests prüfen die PDF-Übertragung, Wiederholung,
Ferien, einmalige Initialisierung, vorhandene Schülerdaten, Bearbeitung, Hinzufügen,
Löschen/Wiederherstellen, Entwürfe, Fokus während der automatischen Sicherung, Zeitänderungen,
Serienaufteilung, Vorbereitungen, Referenzen, Rollback, Sicherung und Zusammenführen.
Die Darstellung wird bei 320/390/1100 Pixel Breite und doppelter Schriftgröße geprüft.

Die zugehörigen Bilder sind direkt aus Flutter-Widgets erzeugt. Es gibt keinen Browser-
oder physischen Android-Gerätelauf; insbesondere die echte Android-Tastatur und Touch-
Bedienung sind damit nicht als am Gerät abgenommen zu verstehen.

Lokal bestanden: vollständige Suite mit 368 Tests und Coverage; danach 39 gezielte
Prüfungen einschließlich der letzten beiden Ergänzungen (insgesamt jetzt 370 Tests).
Strenge Analyse ohne Meldungen, Formatprüfung, 11 SQLite-Prüfungen und drei
HTTP-Serverprüfungen sind ebenfalls erfolgreich.

[Handy](stundenplan-build-41/timetable-390-1.png) ·
[Wochenraster](stundenplan-build-41/timetable-1100-1.png) ·
[Große Schrift](stundenplan-build-41/timetable-320-2.png) ·
[Block bearbeiten](stundenplan-build-41/timetable-editor-390-1.png)
