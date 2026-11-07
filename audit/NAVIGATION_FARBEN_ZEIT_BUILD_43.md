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
