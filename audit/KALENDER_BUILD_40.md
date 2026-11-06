# Kalender · Build 40

## Bedienung

Der Tagesablauf beginnt direkt unter Datum und Tag/Woche/Monat. Der vorherige
Block aus Filtern und Verwaltungsaktionen steht nicht mehr vor den Stunden.
Anlegen, Unterlagen und Verwalten bleiben als beschriftete Zugänge erreichbar.

- **Tag:** gemeinsame Zeitachse, räumliche Dauer der Stunden, aktueller/nächster
  Unterricht und Zeitmarkierung. Unterricht und Termine lassen sich direkt öffnen.
- **Woche:** ausgerichtete Wochentage mit gemeinsamer Stundenachse. Montag bis
  Freitag im Normalfall; Samstag/Sonntag sind zuschaltbar und bei vorhandenen
  Einträgen automatisch enthalten. Bei großer Schrift scrollt das Raster horizontal.
- **Monat:** ruhiges Raster mit Markierungen und Legende; darunter die Einträge
  des gewählten Tages. Ein eigener Zugang öffnet dessen Tagesansicht.
- **Fälligkeiten:** HÜ, Aufgaben, Zielprüfungen und Rückläufe stehen getrennt vom
  Stundenraster. Die Gruppierung öffnet weiterhin jeden ursprünglichen Eintrag,
  einschließlich des jeweiligen Schülers und Datums.
- **Überschneidungen:** im Tagesraster nebeneinander; bei zu wenig Platz als
  beschriftete Gruppe, deren Dialog alle betroffenen Einträge öffnet.
- **Verwaltung:** Stundenplan, Ferien/Ausfälle, Papierkorb und ICS-Import/-Export.
  Filter sind über einen sichtbaren Zugang erreichbar; erledigte Einträge lassen
  sich einblenden. Die vier Hauptseiten und ihre Swipe-Navigation bleiben erhalten.

## Vorbereitung einer konkreten Stunde

Im Stundendialog stehen Planung und direkt zu öffnende Dateien vor den weiteren
Aktionen. „Dateien dieser Stunde“ und „Planung zuordnen“ gelten ausschließlich für
die gewählte Durchführung. Eine neue Planung wird zusammen mit ihrer Zuordnung
in einer Datenbanktransaktion gespeichert. Eine Planung kann mehreren Stunden
zugeordnet werden; Änderungen an einer solchen Planung gelten entsprechend gemeinsam.

Serien-Dateien bleiben der Standard für unveränderte Stunden. Ein explizit leeres
Override bedeutet bewusst keine Zuordnung. Planung und Dateien bleiben an der
ursprünglichen Durchführung, wenn diese verschoben oder abgesagt wird. Wieder-
einplanen bzw. Zurücknehmen einer Zeitänderung löscht diese Vorbereitung nicht.
Einzelne Textänderungen schreiben unveränderte Serienwerte nicht als feste Kopie fest.

Beim Aufteilen „Diese und folgende“ gehen künftige Ausnahmen auf die neue Serie
über; vorhandene Serienplanungen bleiben auch mit dieser verknüpft. Ein ICS-Update
ersetzt nur importierte Felder. Würde eine geänderte Wiederholungsregel angepasste
Stunden ausschließen, wird die Übernahme mit einer konkreten Fehlermeldung abgebrochen.

## Daten und Prüfungen

Version **0.16.0-rebuild.20+40**. App-ID `at.flowzym.flex_notizbuch.test`, SQLite-
Schema 7 und Testsignatur bleiben erhalten. Es gibt keine Datenlöschung oder
Tabellenmigration. Ein normales Android-Update bewahrt den bestehenden App-Speicher.
Reguläre Sicherungen und Zusammenführungen übernehmen die neuen Referenzen;
zugehörige Dateibytes bleiben Bestandteil der separaten Materialsicherung.

22 zusätzliche automatisierte Prüfungen decken unter anderem Zeitraster und
Überschneidungen, Fälligkeiten pro Schüler, Tages-/Wochen-/Monatsnavigation,
320/390/1100 Pixel Breite, doppelte Schriftgröße, Verschieben über das Serienende,
Zuordnung je Stunde, Serienaufteilung, Import, Sicherung/Wiederherstellung,
Zusammenführen und Transaktions-Rollback bei veralteten Daten ab.

Lokal bestanden: **352 Flutter-Tests mit Coverage**, strenge Analyse ohne Meldungen,
Formatprüfung, 11 SQLite-Tests und 3 HTTP-Serverprüfungen. Die abschließende responsive
Darstellung wurde zusätzlich mit allen 10 Kalender-Widgettests nachgeprüft.
Auch die [GitHub-Pipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42298060865)
ist vollständig erfolgreich: Analyse/Tests, Android, Web und Abschlussprüfung.
APK-Metadaten und Pipeline-Ergebnis stehen beim
[Android-Build 40](../releases/android/build-40/README.md).

Die beigefügten Bilder stammen direkt aus Flutter-Widget-Renderings mit Testdaten.
Es gab keinen Browserlauf und keinen physischen Android-Gerätelauf. Die tatsächliche
Touch-Bedienung, Android-Tastatur und Systembenachrichtigungen müssen deshalb weiter
am Gerät beurteilt werden. Die direkte OneDrive-Anmeldung benötigt weiterhin die
eigene Microsoft-Client-ID; diese Kalenderänderung richtet sie nicht ein.

## Direkte Flutter-Ansichten

[Tag auf dem Handy](kalender-build-40/calendar-day-390-1.png) ·
[Woche auf dem Handy](kalender-build-40/calendar-week-390-1.png) ·
[Monat](kalender-build-40/calendar-month-390-1.png) ·
[Woche auf breitem Display](kalender-build-40/calendar-week-1100-1.png) ·
[320 Pixel mit doppelter Schriftgröße](kalender-build-40/calendar-day-320-2.png)
