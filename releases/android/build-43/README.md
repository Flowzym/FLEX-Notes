# FLEX Test – Android Build 43

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-43/FLEX-Test-0.16.0-rebuild.23%2B43-bbef5e872c9f-universal.apk)

Version **0.16.0-rebuild.23+43**, Android 7.0 oder neuer; ARM64, ARMv7 und x86_64.
Über die vorhandene **FLEX Test** installieren. App-ID, Schema und Testsignatur
bleiben gleich; ein normales Update behält den bestehenden Datenbestand.

- Gemeinsame Navigationspille auch am Handy, mit sichtbaren Bereichen bei großer Schrift.
- Beobachtungen im Textfeld: positiv dunkelgrün, neutral dunkelblau, negativ dunkelrot.
- Waagrechte Linie mit aktueller Uhrzeit in Kalender und Stundenplan (heutige Tagesansicht),
  sichtbar über laufenden Unterrichtsblöcken und minütlich aktualisiert.

Lokal bestanden: **375 Flutter-Tests mit Coverage**, strenge Analyse, Formatprüfung,
11 SQLite-Tests und drei HTTP-Tests. Nach der abschließenden Verdichtung der
Navigation zusätzlich alle 22 Navigations-/Design-/Klassen-UI-Tests.
Der fertige Webbuild wurde im lokalen Chromium bei 390 × 844 und 1280 × 900 Pixeln
geprüft. Kein physischer Android-Gerätelauf. APK-Signatur, App-ID, Manifest, ZIP- und
ELF-Ausrichtung für 16-KB-Seiten sind geprüft.

[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42385043662):
**alle Prüfungen erfolgreich**, einschließlich 375 Tests, Analyse und beider Releasebuilds.

APK: 79691112 Bytes. SHA-256:
`4680305e10f3d5731d1b613500ee00a63d13964cb09dd77f09593769faa40fbb`.
Quellcommit: `bbef5e872c9f244c113ef15e9a84d29b82727182`.

[Bedienung und Prüfnachweise](../../../audit/NAVIGATION_FARBEN_ZEIT_BUILD_43.md) ·
[Installation](../../../flutter_app/ANDROID-TEST.md)
