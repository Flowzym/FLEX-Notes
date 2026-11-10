# FLEX 0.17.0+57 · Creme und Salbei

Die freigegebenen Smartphone-Entwürfe bilden jetzt die gemeinsame Oberfläche der Flutter-App: warmes Creme, ruhiges Salbei/Olive, dunkle Schrift, feine Konturen und offene Schülerzeilen. Die Umsetzung verwendet die bestehenden Daten und Fachabläufe.

## Oberfläche

- Kleines FLEX. über der Kontextnavigation; zusammenhängende Navigationspille, helle untere Bereichsleiste und zusammengehörige aktive Symbole/Beschriftungen.
- Notizen zeigt jeden Schüler als offene Zeile mit allen fünf direkten Aktionen: Ziele, Sozial, Arbeit, HÜ, Orga. Zähler sitzen am unteren rechten Symbolrand; Namen und Aktionen bleiben getrennt lesbar.
- Gemeinsame Kopf-, Formular- und Fußgestaltung für Sozial, Arbeit, Ziele, HÜ und Orga. Orga-Typen bleiben direkt sichtbar; Entwürfe, Verlauf, aufgegebene HÜ und Dokumente bleiben erreichbar. Bei knapper Breite wechseln Kopfaktionen in eine weitere Zeile.
- Kalender und Stundenplan verwenden dieselben ruhigen Flächen, Tages-/Wochenraster, klare Datumsbereiche und die waagrechte Zeitmarkierung. Die aktuelle Wochenspalte ist leicht hinterlegt. Kurze Termine behalten ihre Berührungsfläche; lange Unterrichtsblöcke erhalten eine kompakte Darstellung mit vollständiger Zeitspanne.
- Material, Scannerverwaltung, Aufgaben, Schülerdetails, Archiv, Papierkorb und Daten übernehmen die gemeinsame Schrift-, Farb-, Formular-, Dialog- und Button-Gestaltung. Scannerfunktionen und Dateizuordnung bleiben bestehen.

## Einstellungen und Daten

Die bisherigen Bild-, Farb-, Transparenz-, Form- und Oberflächenskalierungsregler sind entfernt. Unter Darstellung bleiben **Hell / Dunkel / System** und **Schriftgröße 80–160 %** mit Vorschau und Standardgröße.

Alte Darstellungswerte werden beim Einlesen ignoriert; der erste Einstieg verwendet das freigegebene helle Design. Gültige Schriftgröße, Standard-Beobachtungston, Materialansicht/-sortierung und Shortcut-Reihenfolge bleiben erhalten. Neue Präferenzen verwenden `designVersion: 1`. Die Schriftgröße wird mit der Systemschriftgröße kombiniert; das Layout und Tastaturkoordinaten werden nicht mehr skaliert.

Kein SQL-Schemawechsel, keine Änderung der Datensatz- oder Anhangs-IDs, kein Zurücksetzen des Browser-Speichers. Die bestehende Vorschau-Adresse bleibt erhalten. Sicherungsimport, Entwürfe, Revisionen und Neustart wurden auch mit alten Darstellungspräferenzen geprüft.

## Prüfung

Nachweise: [Evidenz](cream-sage/verification.json). Reale Flutter-Renderings stehen in diesem Verzeichnis; sie verwenden ausschließlich synthetische Testdaten.

Geprüft werden sämtliche Hauptbereiche und Eintragungsarten bei 390 px hell/dunkel, 320 px mit 1,8-facher Systemschrift, Tablet und Desktop. Zusätzliche Fälle prüfen doppelte Schrift, Tastaturhöhenwechsel mit erhaltenem Fokus/Text, große Optionsbeschriftungen, Namen im HÜ-Kopf, Datenmigration, Speicherkonflikte, Dokumentzuordnung und Scanner-Bearbeitung. Die vorhandenen Verhaltenstests bleiben aktiv; reine Erwartungen an alte Farben, Kartenraster und entfernte Designregler wurden auf die freigegebene Darstellung umgestellt.

## Android-Abgrenzung

Die App-ID bleibt `at.flowzym.flex_notizbuch.test`. Der bisherige private Test-Signierschlüssel liegt in dieser Arbeitsumgebung nicht vor. Deshalb wird keine anders signierte APK als kompatibles Update angeboten. Der Android-Build wird getrennt durch die GitHub-Testpipeline geprüft; deren temporäre Signatur ist kein Ersatz für den installierten Testschlüssel. Ein Installations-/Kameralauf auf einem physischen Android-Gerät ist hier nicht erfolgt.
