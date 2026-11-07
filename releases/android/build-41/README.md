# FLEX Test – Android Build 41

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-41/FLEX-Test-0.16.0-rebuild.21%2B41-a99c5ed6f1e4-universal.apk)

Version **0.16.0-rebuild.21+41**, Android 7.0 oder neuer; ARM64, ARMv7 und x86_64.
Über die vorhandene **FLEX Test** installieren. App-ID, Datenbankschema und
Testsignatur bleiben gleich; ein normales Update behält den Datenbestand.

- **Kalender → Stundenplan** öffnet den Plan der FLEX-Klasse aus der PDF.
- Wöchentlich ab 9. November 2026; Flexk und TDTE bleiben zusammenhängende Blöcke.
- Fach, Wochentag, Stundenumfang, individuelle Zeiten, Lehrkraft, Raum und Notiz bearbeiten.
- Neue Blöcke ergänzen, entfernen und wiederherstellen; allgemeine Stundenzeiten anpassen.
- Tagesliste und Wochenraster; Entwürfe, Materialien und Vorbereitungen bleiben verknüpft.

Lokal bestanden: vollständige Suite mit **368 Flutter-Tests und Coverage**, anschließend
39 gezielte Prüfungen einschließlich der letzten beiden Ergänzungen (**370 Tests insgesamt**).
Strenge Analyse, Formatprüfung, 11 SQLite-Tests und drei HTTP-Tests ebenfalls erfolgreich.
APK-Signatur, App-ID, Manifest, ZIP- und ELF-Ausrichtung für 16-KB-Seiten geprüft.
Kein physischer Android-Gerätelauf und kein Browserlauf.

[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42366241167).

APK: 79691112 Bytes. SHA-256:
`a326cc5531c184e61d4303485b41a3f0400df179ffac58be5564ff2dfbd26843`.
Quellcommit: `a99c5ed6f1e4c6983c45b360489808d8b1278c29`.

[Stundenplan und Flutter-Ansichten](../../../audit/STUNDENPLAN_BUILD_41.md) ·
[Installation](../../../flutter_app/ANDROID-TEST.md)
