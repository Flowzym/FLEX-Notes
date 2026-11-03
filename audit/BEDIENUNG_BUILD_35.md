# Tonwahl, Schalter und Orga-Wischgesten – Build 35

Stand: **0.16.0-rebuild.15+35**, 3. November 2026.

Die aktive Tonpille verwendet Dunkelgrün für Positiv, Dunkelblau für Neutral und
Dunkelrot für Negativ, jeweils mit weißer Schrift. Die gesamte Navigation ist
bei Standardschrift 38 statt 34 px hoch; die Beschriftung wächst von 13 auf 14 px.
Dieselbe Darstellung gilt für den Standardwert unter Einstellungen → Bedienung.

Alle Umschalter zeichnen Spur und Griff 14 % kleiner. Beschriftungen und
Interaktionsflächen werden nicht mitskaliert; die beschrifteten Zeilen bleiben
als Ganzes anklickbar. Die native Schalterbedienung per Ziehen und Tastatur bleibt erhalten.

Kurze horizontale Touch-Gesten wechseln die Tonwahl auch über Eingabefeldern.
Längeres Gedrückthalten zur Textauswahl, vertikales Scrollen, Mausauswahl und
Mehrfinger-Gesten in Textfeldern lösen keinen Wechsel aus. Die Auswahl stoppt
jeweils am ersten bzw. letzten Eintrag.

Orga verwendet dieselbe Gestensteuerung für Notiz → Aufgabe → Termin, sowohl
beim Anlegen als auch beim Bearbeiten und in Klassen-Orga. Texte und Checklisten
bleiben erhalten, Eingabefelder behalten ihren Zustand und Tastaturfokus.
Typgebundene Datums- und Statusfelder folgen derselben Logik wie die oberen Buttons.

## Nachweise

**227 Tests der vollständigen Flutter-Testsuite bestanden**, statische Analyse ohne Befunde.
Ein älterer Kartentest wurde an die bereits in Build 34 gewünschte Zentrierung
der unteren Symbolreihe angepasst.

Neun zusätzliche Tests prüfen Gesten über Beobachtungs-, Auftrags- und Orga-Textfeldern,
Checklisten, genau einen Wechsel pro Geste, Auswahlgrenzen, Textauswahl, Fokus bei
simulierter Bildschirmtastatur, Speichern in SQLite, Schalter per Tap/Drag/Tastatur
und deaktivierte Schalter. Kontrast und Größe werden bei 390 px und bei 320 px
mit 200 % Systemschrift geprüft. Die drei aktiven Farben erreichen mindestens
4,5:1 Kontrast zur weißen Schrift.

- [Gezielte Tests](evidence/app35-focused-tests.log)
- [Vollständige Testsuite](evidence/app35-all-tests.log)
- [Statische Analyse](evidence/app35-analyze.log)
- [Zwölf aktuelle Ansichten](tone-controls-renderings/README.md)
- [Android-Build](evidence/app35-apk-build.log)
- [APK-Verifikation](evidence/app35-apk-verification.json)

Android-Releasebuild erfolgreich; APK-Signatur, Paketkennung, Versionscode 35,
ZIP-Integrität und 16-KB-Ausrichtung der nativen Bibliotheken geprüft.

Keine Änderung an Datenformat oder Datenbankschema. Paketkennung und Testsignatur
bleiben erhalten; über die vorhandene FLEX Test installieren, nicht deinstallieren.
Kein physischer Android-Gerätelauf und keine Browsertests. Die Prüfung der
Bildschirmtastatur ist ein Flutter-Widget-Test mit simuliertem Tastatur-Inset.
