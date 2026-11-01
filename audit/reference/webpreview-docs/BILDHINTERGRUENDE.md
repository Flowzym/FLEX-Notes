# Desktop- und Mobilhintergründe – 0.15.2+18

Unter **Einstellungen → Darstellung → Hintergrund** gibt es getrennte Bildfelder
für Desktop und Mobil. Bis einschließlich 700 logischer Pixel Fensterbreite wird
das mobile Bild verwendet, darüber das Desktopbild. Größenwechsel und Drehung
aktualisieren die Auswahl unmittelbar. Fehlt eine Variante, dient das vorhandene
Bild als Ersatz. Für jede Ansicht lässt sich die Bilddarstellung getrennt wählen:
Fläche füllen, Einpassen, Strecken, Originalgröße oder Kacheln. Standard bleibt
„Fläche füllen“. Die Auswahl folgt der Fensterbreite, auch beim Ersatzbild.
Vorschau, Speicherung und Sicherung berücksichtigen beide Modi. Unterschiede und
Settings-Korrekturen: `SETTINGS_KORREKTUREN.md`.

Die Verarbeitung und lokale Speicherung verwenden die vorhandenen Bildfunktionen.
JPEG, PNG und WebP sind erlaubt, je Bild bis 12 MB und 48 Megapixel. Die Aufbereitung
begrenzt die längste Kante auf 1600 Pixel. Beide Varianten, ihre Namen und die
Darstellung sind Bestandteil der Vollsicherung. Bisherige Ein-Bild-Einstellungen
und ältere Sicherungen funktionieren weiter. SQLite und Vollsicherungsinhalt bleiben
Version 7; die beiden neuen Felder sind optionale Darstellungswerte.

„Bild verwenden“ schaltet beide Varianten gemeinsam ein/aus und behält die Dateien.
„Bild entfernen“ bzw. „Mobiles Bild entfernen“ entfernt nur die jeweilige Variante.
Abdunklung, Bildtönung und Lesbarkeitsschutz gelten für beide. Die bestehenden
Stilvorlagen „Bild dezent“ und „Bild klar“ funktionieren auch mit nur einem mobilen
Bild. Ein abgebrochener oder fehlerhafter Bildimport ersetzt keine gespeicherten Bilder.

## Übermittelte Tafelmotive

Die zwei grünen Tafelhintergründe sind im Chat sichtbar, wurden dieser Cloud aber
nicht als Bilddateien mit Dateipfad oder herunterladbarer Datei-ID bereitgestellt.
Sie sind deshalb **noch nicht fest in das App-Paket eingebunden**. Es wurden keine
nachgebildeten oder fremden Ersatzbilder verwendet. Für die feste Einbindung wird
eine ZIP-Datei mit beiden Originalen benötigt. Alternativ lassen sie sich in der
App bereits über die zwei Bildfelder direkt vom eigenen Gerät auswählen.

## Prüfung

Neue Tests prüfen automatische Auswahl einschließlich der Grenze bei 700 Pixeln,
Ersatzbild, alte Einstellungen, Datenbank-/Sicherungsrundlauf, ungültige Bilddaten,
Fenstergrößenwechsel und die unabhängige Dateiauswahl samt Abbruch und Entfernen.
Die Testbilder sind kleine synthetische Raster, nicht die Motive aus dem Chat.
Prüfzahlen und Buildstand: `FLUTTER_STATUS.md`. Keine Browsertests.
