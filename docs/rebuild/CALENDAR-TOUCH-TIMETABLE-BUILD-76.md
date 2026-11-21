# Kalenderbedienung und Stundenplanverwaltung · 0.26.0+76

## Kalender

Tag/Woche/Monat stehen oben; direkt darunter passen Datumsnavigation, Heute,
Unterrichtsschalter, Filter, Unterlagen und Verwalten in eine gemeinsame Zeile.
Die Werkzeuge sind beschriftete Symbole mit Tooltips und Bedienhilfe; das kompakte
Datum öffnet die Datumsauswahl. Stundenplan und Sa/So liegen unter Verwalten.
Die Wochenendauswahl bleibt beim Zeitraumwechsel wirksam, auch wenn am Wochenende
Einträge liegen. Ausgeblendete Wochenendeinträge bleiben über den bestehenden
Hinweis erreichbar.

Wischen außerhalb des Kalenderrasters wechselt zyklisch zwischen Tag, Woche und
Monat. Wischen im Raster bewegt den gewählten Zeitraum vor/zurück; bei großer
Schrift behält die horizontale Spaltennavigation ihre eigene Geste. Die schnellen
Übergänge behalten auch beim Sprung vom letzten zum ersten Reiter ihre Richtung.

Ein freies Zeitfeld öffnet den vorhandenen Termin-Editor mit dem berührten Datum
und einer auf 15 Minuten abgerundeten Startzeit. Langes Drücken über einem belegten
Block legt an dieser Stelle einen weiteren Termin an; normales Antippen öffnet
weiterhin den bestehenden Eintrag. Im Monatsraster öffnet ein Tag direkt einen
Termin ohne Uhrzeit. Die vorhandene Schüler-/Personenzuordnung, Entwürfe,
Wiederholungen und Anhänge stehen im Editor bereit. Abbrechen einer unveränderten
leeren Eingabe erzeugt keinen Eintrag. Eine Endzeit oder frei gezogene Zeitspanne
wird mit diesem Schritt nicht neu eingeführt.

## Stundenplan

Die Verwaltung hat Bereiche für Wochenplan, Stundenzeiten und Änderungen.
Der Plan ist nach Wochentagen gegliedert, mit Zeiten, Fach, Lehrkraft, Raum und
Stundenbereich. Die Bezugswoche lässt sich wechseln; neue Blöcke beginnen in der
gewählten Woche. Gültigkeit und Wiederholungsrhythmus werden berücksichtigt.
Kalenderferien und einzelne Ausfälle verändern den angezeigten Grundplan nicht.
Zeitliche Überschneidungen tatsächlicher Durchführungen werden angezeigt, aber
nicht grundsätzlich verhindert.

Jeder Wochentag bietet direkt Hinzufügen. Blöcke lassen sich öffnen, bearbeiten
und als neue eigenständige Serie kopieren. Kopien übernehmen Bezeichnung, Zeiten,
Stundenbereich, Lehrkraft, Raum, Notiz und Wiederholungsrhythmus. Frühere Ausnahmen,
Planungs-/Dateizuordnungen, Erinnerungsziele und die Identität der Originalserie
werden nicht kopiert. Einzeltermine können weiterhin im Kalender bearbeitet
oder verschoben werden; dort ist auch das Ändern einer Serie ab Datum verfügbar.

Die Stundenzeitenübersicht zeigt Zeitspannen und Minuten. Im Editor lassen sich
bis zu 20 Stunden anlegen und unbenutzte Stunden entfernen. Stunden, die noch von
einem Block verwendet werden (einschließlich Papierkorb), sind geschützt. Die
bestehende atomare Aktualisierung passt abhängige Blockzeiten an und erhält
individuelle Zeiten. Nach dem Gültigkeitsende ist Hinzufügen deaktiviert; eine
sichtbare Aktion öffnet die Gültigkeitseinstellungen. Ungültige oder überlappende Stundenzeiten werden abgewiesen.

Änderungen bündelt einzelne Ausfälle/Verschiebungen, frühere Serien und entfernte
Blöcke. Rücknahme von Ausfall oder Zeitänderung bewahrt die Vorbereitung; entfernte
Blöcke können wiederhergestellt werden. Sonstiger Unterricht, Ferien und ICS
bleiben unter Kalender verwalten zugänglich. Keine Datenmodelländerung.

## Prüfung

57 unterschiedliche gezielte Prüfungen erfolgreich über mehrere Läufe: 50
vorhandene Kalender-, Stundenplan-, Serien- und Integrationsprüfungen sowie sieben
zusätzliche UI-Prüfungen. Neue Fälle prüfen getrennte Gesten, Zeitauswahl und
Speicherung, Wochen-/Monatszuordnung, langes Drücken, unabhängige Kopien,
Ausnahmerücknahme, Erweiterung/Entfernen von Stundenzeiten und die Sperre nach
dem Gültigkeitsende.

Der erste neue Testlauf deckte einen Tooltip-Konflikt beim langen Drücken auf;
dieser wurde behoben. Ein Kopiertest benötigte einen tatsächlich überlappenden
Ausgangsblock. Beide Nachprüfungen bestanden. Nach der letzten Reiteranpassung
bestanden drei Layoutprüfungen bei 320/390/1100 Pixeln und bis 2-facher Schrift
sowie die Stundenzeiten- und Kopierprüfung erneut. Die Kopie bleibt auch beim
Öffnen vom Samstag in der angezeigten Planwoche verankert.
Statische Analyse ohne Befunde. Release-Webbuild mit lokalen Rendering-Ressourcen
und signierte Android-Universal-APK erstellt und technisch geprüft.

Browserprüfung mit synthetischen Daten bei 320/390 Pixeln einschließlich echter
Touch-Ereignisse. Screenshots und Protokolle unter [evidence/build-76](evidence/build-76/).
Keine vollständige Testsuite oder physische Android-Abnahme in diesem Build.

[APK und Installation](../../releases/android/build-76/README.md) ·
[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
