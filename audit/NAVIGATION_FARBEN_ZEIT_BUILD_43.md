# Navigation, Beobachtungsfarben und aktuelle Zeit · Build 43

Die Hauptnavigation liegt auch auf schmalen Displays in einer gemeinsamen Pille.
Alle Bereiche bleiben direkt sichtbar; bei großer Schrift brechen sie innerhalb
der gemeinsamen Fläche um.

Ausgewählte Beobachtungen im Textfeld behalten ihre jeweilige Farbe: positiv
dunkelgrün, neutral dunkelblau, negativ dunkelrot. Dies gilt für Sozial- und
Arbeitsverhalten sowie die individuellen Beobachtungen bei Gruppeneinträgen.
Weiße Beschriftung und Löschsymbole bleiben lesbar. Wechsel zwischen den Kategorien,
Freitext, Fokus und Speicherung ändern die Zuordnung der ausgewählten Tags nicht.

Die heutige Tagesansicht in Kalender und Stundenplan zeigt eine waagrechte Linie
mit Uhrzeit. Sie wird über laufende Blöcke gezeichnet und lässt Berührungen zum
Eintrag durch. Die Zeit aktualisiert sich minütlich und bei Rückkehr in die App.
Auch vor bzw. nach Unterrichtszeiten bleibt die aktuelle Zeit auf der Achse
darstellbar; an anderen Tagen erscheint keine Jetzt-Markierung.

## Prüfung

Neue Regressionen prüfen die sichtbare Linienfarbe über einem Unterrichtsblock,
das Antippen durch die Linie, Minutenwechsel in beiden Unterseiten, andere Tage
und frühe/späte Uhrzeiten. Bestehende Tests prüfen zusätzlich die farbliche
Zuordnung gemischter Beobachtungen bei Tabwechsel und Speicherung sowie die
Einschließung aller Navigationsziele bei großer Schrift.

Der Test mit 200% Schrift und 120% UI-Zoom berührt den sichtbaren Teil einer
überhohen Übersichtskarte; deren geometrische Mitte kann außerhalb des Displays
liegen. Die Bedienung und die HÜ-Symbole werden weiterhin geprüft.

SQLite-Schema, App-ID und Android-Testsignatur bleiben gleich. Der Build enthält
keine Nutzerdaten. Ein physischer Android-Gerätelauf gehört nicht zu diesen Prüfungen.

Lokal erfolgreich: **375 Flutter-Tests mit Coverage**, Analyse ohne Warnungen,
Formatprüfung, 11 SQLite-Tests und drei HTTP-Tests. Nach der letzten Verdichtung
der Navigation zusätzlich alle 22 Navigations-/Design-/Klassen-UI-Tests.

Der Web-Releasebuild wurde im lokalen Chromium bei 390 × 844 und 1280 × 900 Pixeln
geprüft: gemeinsame Navigation, Zeitlinie in beiden Tagesansichten und keine
Linie an anderen Tagen. Auf beiden Breiten zusätzlich gemischte Beobachtungen,
Freitext, Fokus während automatischer Sicherung sowie Speichern/Neuladen.
Die Prüfung nutzte frische lokale Testprofile ohne Nutzerdaten.

[Kalender am Handy](navigation-farben-zeit-build-43/calendar-phone.png) ·
[Stundenplan am Handy](navigation-farben-zeit-build-43/timetable-phone.png) ·
[Desktop](navigation-farben-zeit-build-43/calendar-desktop.png) ·
[Beobachtungsfarben](navigation-farben-zeit-build-43/mixed-observations-phone.png) ·
[Browser-Prüfergebnis](navigation-farben-zeit-build-43/result.json) ·
[Desktop-Beobachtungen](navigation-farben-zeit-build-43/mixed-observations-desktop.png) ·
[Beobachtungsprüfung](navigation-farben-zeit-build-43/observation-results.json).

Die bestehende private Webvorschau wurde am gleichen Ursprung auf Build 43
aktualisiert; der Zugriff bleibt auf den Eigentümer beschränkt. Die Android-APK
ist auf GitHub und im verifizierten persönlichen OneDrive vorhanden.
Signatur, Dateigröße, SHA-256 und OneDrive-Prüfsumme sind geprüft.

Die [GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42385043662)
ist vollständig erfolgreich: **375 Tests**, Analyse, Formatierung, Web- und Android-
Releasebuild sowie Abschlussprüfung. Quellcommit: `bbef5e872c9f244c113ef15e9a84d29b82727182`.
