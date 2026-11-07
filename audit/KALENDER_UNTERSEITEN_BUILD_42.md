# Kalender und Stundenplan als Unterseiten · Build 42

Im Kalenderbereich stehen **Kalender** und **Stundenplan** als eigene Unterseiten
nebeneinander. Der Stundenplan verwendet dieselbe Tagesachse und dasselbe Wochenraster
wie der Kalender. Beide Ansichten sind auf allen Displaygrößen direkt wählbar.
Datumsauswahl, vorheriger/nächster Zeitraum, Heute und der Wechsel vom Wochenkopf
zu einem einzelnen Tag funktionieren in beiden Unterseiten gleich.

Datum, Ansichtsmodus und Scrollposition bleiben pro Unterseite erhalten. Der Kalender
behält außerdem Monatsansicht, Filter, Termine und Fälligkeiten. Der Stundenplan zeigt
die zugehörigen Unterrichtsblöcke mit Datum, Zeit, Stundenumfang und Lehrkraft/Raum.
Ferien und verschobene Einzelstunden werden aus denselben gespeicherten Daten abgeleitet.

Die Stundenplanübersicht ist kein Modal mehr. Antippen eines Blocks öffnet weiterhin
dessen Serienbearbeitung. Block hinzufügen, Stundenzeiten und Verwalten sind unten
ständig erreichbar. Unter Verwalten lassen sich auch entfernte Blöcke wiederherstellen.
Entwürfe, Sicherungen und bisherige Einträge bleiben unverändert erhalten; SQLite-
Schema 7, App-ID und Android-Testsignatur bleiben gleich.

## Prüfung

Lokal bestanden: **372 Flutter-Tests mit Coverage**, strenge Analyse, Formatprüfung,
11 SQLite-Tests und drei HTTP-Serverprüfungen. Darin enthalten sind die angepassten
Bearbeitungs-/Entwurfstests und neue Regressionen für unabhängige Unterseitenzustände,
Scrollpositionen, datierte Einzelverschiebungen und erhaltene Kalendereinträge.

Direkte Flutter-Renderings mit 320/390/1100 Pixel Breite und doppelter Schriftgröße:
[Woche auf dem Handy](kalender-unterseiten-build-42/timetable-390-1.png) ·
[Tag auf dem Handy](kalender-unterseiten-build-42/timetable-day-390-1.png) ·
[Breite Wochenansicht](kalender-unterseiten-build-42/timetable-1100-1.png) ·
[Große Schrift](kalender-unterseiten-build-42/timetable-320-2.png).

Ein physischer Android-Gerätelauf ist nicht Bestandteil dieser Prüfung.

Zusätzlich wurde der fertige Web-Releasebuild in lokalem Chromium mit 1280 × 900
und 390 × 844 Pixeln geprüft: Tages-/Wochenwechsel, Wechsel der Unterseiten mit
erhaltener Auswahl, Bearbeitung eines Blocks, Fokus während der automatischen
Entwurfssicherung und Persistenz nach vollständigem Neuladen. Keine JavaScript-
Seitenfehler. Die Prüfung nutzte getrennte lokale Testprofile ohne Nutzerdaten.

[Browser: Woche](kalender-unterseiten-build-42/browser-week-desktop.png) ·
[Browser: Handy-Woche](kalender-unterseiten-build-42/browser-week-phone.png) ·
[Browser: Handy-Tag](kalender-unterseiten-build-42/browser-day-phone.png) ·
[Browser-Prüfergebnis](kalender-unterseiten-build-42/browser-checks.json).

Die [GitHub-Pipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42377770028) ist vollständig erfolgreich:
372 Flutter-Tests, Analyse, Android-/Web-Releasebuild und Abschlussprüfung.
Die private Webvorschau ist unter derselben Adresse aktualisiert. Android Build 42
ist auf GitHub und im verifizierten persönlichen OneDrive verfügbar; App-Signatur,
Dateigröße, SHA-256 und OneDrive-Prüfsumme wurden geprüft.
