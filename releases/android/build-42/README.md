# FLEX Test – Android Build 42

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-42/FLEX-Test-0.16.0-rebuild.22%2B42-51f7fc21c3ba-universal.apk)

Version **0.16.0-rebuild.22+42**, Android 7.0 oder neuer; ARM64, ARMv7 und x86_64.
Über die vorhandene **FLEX Test** installieren. App-ID, Schema und Testsignatur
bleiben gleich; ein normales Update behält den bestehenden Datenbestand.

- **Kalender → Stundenplan** ist jetzt eine eigene Unterseite.
- Tages- und Wochenansicht mit derselben Zeitachse und Bedienung wie im Kalender.
- Datum, Ansicht und Scrollposition bleiben beim Wechsel der Unterseiten erhalten.
- Blöcke antippen und bearbeiten; Hinzufügen, Stundenzeiten und Verwaltung unten erreichbar.
- Der Kalender behält Monatsansicht, Filter, Termine und Fälligkeiten.

Lokal bestanden: **372 Flutter-Tests mit Coverage**, strenge Analyse, Formatprüfung,
11 SQLite-Tests, drei HTTP-Tests sowie der fertige Webbuild im lokalen Chromium
bei 1280 × 900 und 390 × 844 Pixeln. Browserprüfung umfasst Navigation, Bearbeitung,
Fokus während der automatischen Sicherung und Persistenz nach Neuladen.
Kein physischer Android-Gerätelauf. APK-Signatur, App-ID, Manifest, ZIP- und
ELF-Ausrichtung für 16-KB-Seiten sind geprüft.

[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42377770028): **alle Prüfungen erfolgreich**, einschließlich
372 Flutter-Tests, Android-/Web-Releasebuild und Abschlussprüfung.

APK: 79691112 Bytes. SHA-256:
`f196d9b05052ce90c7b7157b52d93922650b16acf6b75c1a8bf5ae95bb0cc0a4`.
Quellcommit: `51f7fc21c3ba02c0abdf4a2180cea8304e22bac7`.

[Unterseiten und Prüfnachweise](../../../audit/KALENDER_UNTERSEITEN_BUILD_42.md) ·
[Installation](../../../flutter_app/ANDROID-TEST.md)
