# Navigation und Termin-Tags · Build 80

Version **0.30.0+80** vereinheitlicht die oberen Navigationspillen einschließlich
Tag/Woche/Monat. Live zeigt **Aktuell · Notizen · Ablauf**. „Heute“ ist ein
Textbutton. Die drei Punkte rechts neben „FLEX.“ öffnen die weiteren Bereiche;
unten führt „Scanner“ direkt zur Dokumenten- und Bildverwaltung.

## Einstellungen

Unter **Weitere Bereiche → Einstellungen → Bedienung → Standardansichten**
lässt sich festlegen, ob Wischen nach links oder rechts zum nächsten Reiter
führt. Beide Richtungen laufen ohne Ende durch; die Seitenanimation folgt dem
Finger. Die Einstellung gilt für die oberen Bereichsreiter und Tag/Woche/Monat.
Wischen im Kalenderraster verschiebt weiterhin den Zeitraum.

Die Startreiter für Live, Organisation, Material und Mehr sowie die
Kalenderansicht sind wählbar. Beim ersten Öffnen nach Appstart gilt der Standard.
Während der Nutzung bleibt der zuletzt gewählte Reiter erhalten. Ein geänderter
Standard wird beim nächsten Bereichswechsel übernommen. Einstellungen bleiben
nach Neustart und Sicherungswiederherstellung erhalten.

## Organisation und Termine

- Klassen-Orga ist ein eigener Reiter unter Organisation. Der bisherige
  Menüeintrag entfällt. Er zeigt Klasseneinträge einschließlich Rückläufen.
- Status- und Typfilter stehen als direkt sichtbare Buttons über der Liste.
- Termine erhalten eigene Tags, etwa „Schularbeit“, „Test“ oder selbst
  eingegebene Begriffe. Tags erscheinen in Einträgen und Kalenderdetails und
  sind durchsuchbar.
- Tags bleiben beim Typwechsel, in Entwürfen, Sicherungen, Importkonflikten und
  Eintragsvorlagen erhalten. ICS-Exporte übernehmen sie als Kategorien.

## Daten und Prüfung

Schema 8 bleibt bestehen; zusätzliche Termin- und Anzeigeangaben verwenden die
bestehenden Metadaten. Ältere Einträge ohne Tags und bisherige Einstellungen
bleiben lesbar. Neue Felder sollten mit Build 80 oder neuer bearbeitet werden.

Geprüft sind Speicherung/Wiederherstellung der Einstellungen, beide
Wischrichtungen samt Umlauf, neue Navigationswege, Termin-Tags einschließlich
Umlauten, Typwechsel, Vorlagen, ICS und feldweises Zusammenführen. Alle **650
Flutter-Tests** sind erfolgreich; Analyse und Formatkontrolle ohne Befund.
Android- und Web-Releasebuilds sind erfolgreich. Zehn Browseransichten wurden
mit synthetischen Daten bei 320 und 390 Pixeln kontrolliert, ohne JavaScriptfehler.
Physische Android-Geräteprüfungen bleiben gesondert offen.

[Android-Download und Signaturprüfung](../../releases/android/build-80/README.md) ·
[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)
