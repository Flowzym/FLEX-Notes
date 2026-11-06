# FLEX Test – Android Build 39

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-39/FLEX-Test-0.16.0-rebuild.19%2B39-3f6afe99cb69-universal.apk)

Version **0.16.0-rebuild.19+39**, Android 7.0 oder neuer; ARM64, ARMv7 und x86_64.
Über die vorhandene **FLEX Test** installieren. App-ID, Datenbankschema und
Testsignatur sind unverändert; ein normales Update behält den Datenbestand.

- Kompakte Dateiliste, direktes Öffnen, Favoriten, Suche und gemeinsame Mehrfachaktionen.
- Unterlagen für einen Tag bereitlegen, ordnen und offline laden; Zugänge in Übersicht/Kalender.
- Wiederverwendbare Unterrichtspakete und Unterlagen direkt beim Schüler.
- Planungen mit Zeitraum, Stand, Unterrichtsverknüpfungen, Dateien und Nachbereitung.
- DOCX-Textvorschau mit Originalzugang; geprüfter Ordnerimport nach OneDrive-Einrichtung.

Die direkte **OneDrive-Anmeldung benötigt weiterhin eine Microsoft-Client-ID**.
[Einrichtung](../../../docs/ONEDRIVE_EINRICHTEN.md). Dateiimport und gespeicherte Links
bleiben nutzbar. Word-Layout, Bilder und Druck erfolgen über das Original.

330 Flutter-Tests mit Coverage, 25 neue Prüfungen, strenge Analyse, Formatprüfung,
11 SQLite-Tests und 3 HTTP-Serverprüfungen bestanden. Android- und Web-Releasebuild,
APK-Signatur, Manifest und 16-KB-Ausrichtung geprüft. Direkte Flutter-Renderbilder
und große Schrift auf schmalen Displays geprüft. Kein physischer Android-Gerätelauf,
kein Browserlauf und keine echte Microsoft-Anmeldung in der Testumgebung.

[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42290885316) – läuft.

APK: 79182948 Bytes. SHA-256:
`a537f4d70c38781a8b8557bef5a65b51e245d0782f32573a4456256a63a9de76`.
Quellcommit: `3f6afe99cb698146ab4bc7d0b147ac0464a4fa0d`.

[Funktionsumfang und Grenzen](../../../audit/MATERIALIEN_BUILD_39.md) ·
[Installation](../../../flutter_app/ANDROID-TEST.md)
