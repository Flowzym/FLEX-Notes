# FLEX Test – Android Build 45

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-45/FLEX-Test-0.16.0-rebuild.25%2B45-daf10dc3c2f2-universal.apk)

Version **0.16.0-rebuild.25+45**, Android 7.0 oder neuer; ARM64, ARMv7 und x86_64.
Über die bestehende FLEX Test installieren. App-ID und Signatur sind unverändert.

Neue untere Bereichsnavigation, kontextabhängige obere Pillen, Fotos mit eigener
Bearbeitung, Tags und PDF/JPG-Ausgabe. Wenn die Dokumentkamera nicht startet,
wechselt FLEX zur normalen Kamera. Konkrete Kamerafehler bleiben lesbar.

Lokal bestanden: **397 Flutter-Tests mit Coverage**, strenge Analyse und Formatprüfung,
11 SQLite- und drei HTTP-Tests. APK-Signatur, Manifest und Ausrichtung geprüft.
64-Bit-Bibliotheken unterstützen 16-KB-Seiten; ARMv7-PDFium verwendet 4 KB.
Kein physischer Android-Gerätetest.

[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42398342688)

APK: 101998386 Bytes. SHA-256:
`38cd9aa2b04f36389f2cc6320b1f73029c6cf6319a933f5fb5cd038586f52b82`.
Quellcommit: `daf10dc3c2f20494259c53e8252b72660f799ec5`.

[Bedienung und Prüfstand](../../../audit/NAVIGATION_FOTOS_BUILD_45.md)
