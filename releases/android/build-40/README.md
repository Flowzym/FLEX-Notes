# FLEX Test – Android Build 40

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-40/FLEX-Test-0.16.0-rebuild.20%2B40-7987ca903e1d-universal.apk)

Version **0.16.0-rebuild.20+40**, Android 7.0 oder neuer; ARM64, ARMv7 und x86_64.
Über die vorhandene **FLEX Test** installieren. App-ID, Datenbankschema und
Testsignatur bleiben gleich; ein normales Update behält den Datenbestand.

- Kalender öffnet direkt den Tagesablauf; Tag, echtes Wochenraster und Monatsansicht.
- HÜ, Aufgaben, Zielprüfungen und Rückläufe separat als Fälligkeiten.
- Sichtbare Zugänge zu Anlegen, Unterlagen und Verwaltung.
- Planungen und Dateien je Unterrichtsstunde; bleiben beim Verschieben und Absagen erhalten.
- Große Schrift, schmale Displays und Überschneidungen berücksichtigt.

**352 Flutter-Tests mit Coverage**, davon 22 neue Prüfungen, strenge Analyse,
Formatprüfung, 11 SQLite-Tests und 3 HTTP-Tests bestanden. Android- und Web-Releasebuild,
APK-Signatur, App-ID, Manifest, ZIP- und ELF-Ausrichtung für 16-KB-Seiten geprüft.
Die abschließende responsive Darstellung wurde zusätzlich mit 10 Kalender-Widgettests geprüft.
Kein physischer Android-Gerätelauf und kein Browserlauf.

[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42298060865): **alle Prüfungen erfolgreich**.

APK: 79461672 Bytes. SHA-256:
`5fff887133e12cc17c4bc1947a4471071aa236eb2a8d30912d3bca720168e4ce`.
Quellcommit: `7987ca903e1ddb639b76507d41e4f0d361a6bd3e`.

[Kalenderänderungen und Flutter-Ansichten](../../../audit/KALENDER_BUILD_40.md) ·
[Installation](../../../flutter_app/ANDROID-TEST.md)
