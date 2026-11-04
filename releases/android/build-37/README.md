# FLEX Test – Android Build 37

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-37/FLEX-Test-0.16.0-rebuild.17%2B37-55e9e963077f-universal.apk)

Version **0.16.0-rebuild.17+37**, Android 7.0 oder neuer; ARM64, ARMv7 und x86_64.
Über die vorhandene **FLEX Test** installieren; nicht deinstallieren.
Paketkennung, Datenbankschema und Testsignatur sind unverändert.

- Automatische verschlüsselte Sicherungen, Status und Wiederherstellung.
- Android-Erinnerungen für Termine, Aufgaben/Hausübungen und Zielüberprüfungen.
- Sicherungen zusammenführen: Vorschau, Dubletten und Entscheidungen pro Feld.
- Gesprächsvorbereitung mit Bereichs-/Zeitraumauswahl als PDF.
- App-PIN und optionale biometrische Entsperrung.

**Einrichten:** Sicherungen unter Einstellungen → Daten; Erinnerungen und App-Sperre
unter Einstellungen → Bedienung. Sicherungspasswort getrennt aufbewahren.
Die PIN-Sperre verschlüsselt die lokale Datenbank nicht.

264 Tests der vollständigen Flutter-Testsuite bestanden, darunter 24 neue Tests;
abschließende PDF-Umbruchkorrektur zusätzlich gezielt geprüft. Statische Analyse ohne Befunde.
APK-Signatur, Android-Manifest, nativer Sicherungszugriff und 16-KB-Ausrichtung geprüft.
Kein physischer Android-Gerätelauf; Doze, Neustart, Dokumentanbieter und Biometrie noch am Gerät abzunehmen.
Quellcommit: `55e9e963077f39d8c9527b01835255faeea6d889`.

[Änderungen und Prüfungen](../../../audit/GERAETEFUNKTIONEN_BUILD_37.md) ·
[Installation und Einrichtung](../../../flutter_app/ANDROID-TEST.md)
