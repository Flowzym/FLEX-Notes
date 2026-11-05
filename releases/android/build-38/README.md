# FLEX Test – Android Build 38

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-38/FLEX-Test-0.16.0-rebuild.18%2B38-6b9495403337-universal.apk)

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

304 Flutter-Tests (40 neue), 11 SQLite-Tests, Formatprüfung und statische Analyse bestanden.
Android- und Web-Releasebuild, 3 HTTP-Serverprüfungen, APK-Signatur, Manifest, native
Materialfunktionen und 16-KB-Ausrichtung erfolgreich geprüft.
[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42099150513).
Kein physischer Android-Gerätelauf; Microsoft-Anmeldung wurde mit Testantworten geprüft.

APK: 77232584 Bytes. SHA-256:
`5137378768bc0b28008e5485b85c00323274621dcdf68c4913033e6b7f17c32a`.
Quellcommit: `6b9495403337854be7a4d75ad20dc6611b1a3acc`.

[Funktionsumfang, Grenzen und Prüfungen](../../../audit/KLASSENFUNKTIONEN_BUILD_38.md) ·
[Installation](../../../flutter_app/ANDROID-TEST.md)
