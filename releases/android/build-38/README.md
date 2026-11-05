# FLEX Test – Android Build 38

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-38/FLEX-Test-0.16.0-rebuild.18%2B38-d4240fa9597a-universal.apk)

Version **0.16.0-rebuild.18+38**, Android 7.0 oder neuer; ARM64, ARMv7 und x86_64.
Über die vorhandene **FLEX Test** installieren, nicht deinstallieren.
Paketkennung, Datenbankschema und Testsignatur bleiben gleich. Ein normales Update
behält die gespeicherten Daten; eine aktuelle Sicherung bleibt vor einem Testupdate sinnvoll.

- Kalender/Stundenplan mit Tag, Woche, Monat, A/B-Wochen, Ferien und Einzeländerungen.
- Materialien und Planungen: DOCX/PDF, OneDrive-/HTTPS-Links, lokale Dateien, Offlinekopien.
- Rückläufe für Formulare, Zustimmung, Material und Beiträge inklusive Teilzahlungen/PDF.
- Wiederkehrende Orga-Aufgaben/Termine und verschiebbare Erinnerungen.
- Entwicklungsübersicht pro Schüler mit Filtern und Gesprächsauswahl.

**Direkte OneDrive-Anmeldung ist noch nicht aktiviert:** Es fehlt die eigene öffentliche
Microsoft-Client-ID. [Einrichtungsschritte](../../../docs/ONEDRIVE_EINRICHTEN.md).
Dateiauswahl und gespeicherte Links funktionieren bereits.

305 Flutter-Tests mit Coverage auf GitHub (41 neue), 11 SQLite-Tests, Formatprüfung und statische Analyse bestanden.
Android- und Web-Releasebuild, 3 HTTP-Serverprüfungen, APK-Signatur, Manifest, native
Materialfunktionen und 16-KB-Ausrichtung erfolgreich geprüft.
[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42100131746).
Kein physischer Android-Gerätelauf; Microsoft-Anmeldung wurde mit Testantworten geprüft.

APK: 77232584 Bytes. SHA-256:
`a685a55b1ca6fba1a6d9ae1eab8da1746f76b4fe5342fbbfdc5f53ae1a37ee7c`.
Quellcommit: `d4240fa9597ab9292d53c71e14764e8cb3de185d`.

[Funktionsumfang, Grenzen und Prüfungen](../../../audit/KLASSENFUNKTIONEN_BUILD_38.md) ·
[Installation](../../../flutter_app/ANDROID-TEST.md)
