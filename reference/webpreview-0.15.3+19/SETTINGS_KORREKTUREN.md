# Einstellungen und Bilddarstellung – 0.15.2+18

## Transparenz und schnelle Änderungen

Zwei konkrete Ursachen wurden korrigiert:

1. Bei einem aktiven Bild übersteuerte der Lesbarkeitsschutz die Transparenz der
   Leseflächen. Ein Regler konnte einen neuen Wert anzeigen und speichern, obwohl
   die Fläche weiter vollständig deckend blieb. Manuelles Verändern der Transparenz
   von Kopfbereich, Karte, Dialogfläche oder Dialogleisten schaltet diesen Schutz
   jetzt aus. Bei gekoppelten Flächen gilt das auch für den gemeinsamen Regler.
   Der Hinweis neben dem Schutzschalter erklärt dieses Verhalten. Man kann den
   Schutz ausdrücklich wieder einschalten; die gewählten Transparenzwerte bleiben
   dabei erhalten. Eine isolierte Änderung an Buttons/Eingabefeldern schaltet den
   Schutz der anderen Leseflächen nicht aus.
2. Einige Einstellungsaktionen verwendeten den bei der letzten Darstellung
   eingefangenen Zustand; Flächenwerte kamen zusätzlich aus dem animierten Theme.
   Schnelle aufeinanderfolgende Änderungen konnten so einen vorherigen Wert
   zurücksetzen. Aktionen verwenden jetzt den aktuellen Controller-Datenstand.
   Die Theme-Animation verzögert die Live-Anzeige nicht mehr. Speicherung läuft
   weiterhin geordnet; Fehler stellen den letzten gespeicherten Stand wieder her.

Die Kontrolle umfasst alle sieben Transparenzen, getrennte und gekoppelte Flächen,
den Datenbankrundlauf und tatsächliche Pixel im gerenderten Hintergrund. Schrift
und Symbole bleiben deckend. Aktive Auswahlen und primäre Speicheraktionen bleiben
bewusst hervorgehoben; diese Ausnahme steht auch in den Button-Einstellungen.

## Weitere sichtbare Korrekturen

- „Kompakte Abstände“ verkleinert jetzt auch die Abstände und Höhe der Schülerkarten.
  Die Schriftgröße bleibt erhalten, die Karten-Shortcuts behalten mindestens
  56 logische Pixel Mindesthöhe.
- Eine Änderung der Hintergrundfarbe schaltet ein aktives Bild nicht mehr aus.
  Bei Einpassen/Originalgröße erscheint die Farbe in den freien Bereichen; ein
  deckender Standardverlauf übermalt diese Farbe dort nicht mehr.
- Die Bildvorschau verwendet dieselben Darstellungsregeln wie der App-Hintergrund.
  Bilder werden beim Bewegen anderer Regler nicht bei jedem Schritt neu dekodiert.

## Fünf Bildmodi, getrennt für Desktop und Mobil

| Einstellung | Wirkung |
| --- | --- |
| Fläche füllen / Filled | Proportional die gesamte Fläche füllen; Randbereiche dürfen abgeschnitten werden. |
| Einpassen / Scaled | Ganzes Bild proportional sichtbar; freie Flächen zeigen den Hintergrund. |
| Strecken / Stretched | Breite und Höhe genau anpassen; Proportionen können sich ändern. |
| Originalgröße | Zentriert in gespeicherter Bildgröße; große Bilder werden beschnitten. |
| Kacheln | In gespeicherter Bildgröße wiederholen. |

Der Modus gilt für die jeweilige Fensterbreite, auch wenn wegen eines fehlenden
Bildes die andere Bildvariante verwendet wird. Alte Einstellungen erhalten den
bisherigen Standard „Fläche füllen“. Beide Modi bleiben in lokaler Speicherung
und Vollsicherung erhalten. Keine neue SQL-Migration, inneres Sicherungsformat v7.
„Gespeicherte Größe“ meint das durch den vorhandenen Bildimport aufbereitete Bild
(maximal 1600 Pixel längste Kante), nicht unbegrenzte Abmessungen der Originaldatei.

Die grüne Desktop-/Mobiltafel aus dem Chat ist weiterhin noch nicht als Datei
verfügbar und daher nicht fest in die App eingebunden. Diese Änderung funktioniert
mit den bereits unterstützten eigenen Bilddateien. Details: `BILDHINTERGRUENDE.md`.

## Nachweise und Grenzen

Die neuen Tests prüfen sichtbare Pixel für alle fünf Modi, Beschnitt, freie Flächen,
Kachelung, echte Transparenzwirkung, schnelle aufeinanderfolgende Einstellungen,
Lesbarkeitsschutz/Kopplung, kompakte Karten, unabhängige Desktop-/Mobilwahl sowie
Speichern und Wiederherstellen. Zahlen und Buildnachweise: `FLUTTER_STATUS.md`.
Es werden nur synthetische Testdaten und Bildmuster verwendet. Keine Browsertests
und keine neue native Windows-/Android-Abnahme.
