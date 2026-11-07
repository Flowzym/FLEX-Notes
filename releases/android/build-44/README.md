# FLEX Test – Android Build 44

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/fix/dialog-reference-audit/releases/android/build-44/FLEX-Test-0.16.0-rebuild.24%2B44-f4f82d8fe99b-universal.apk)

Version **0.16.0-rebuild.24+44**, Android 7.0 oder neuer; ARM64, ARMv7 und x86_64.
Über die vorhandene **FLEX Test** installieren. Ein normales Update mit derselben
App-ID und Signatur behält den bestehenden Datenbestand.

Dokumente direkt bei Schülern, Orga, Unterrichtsstunden, Planungen und Rückläufen
scannen und zuordnen. Mehrseitige PDF, Benennung, Zuschnitt, Drehen, Filter,
Schwärzung sowie fortsetzbare und löschbare Scanentwürfe. PDF-Import und Bearbeitung
sind auch in der Webvorschau verfügbar.

Die Android-Dokumentkamera benötigt Google Play-Dienste und gegebenenfalls einen
einmaligen Moduldownload. Alternativ ist Bild-/PDF-Dateiimport möglich.

Lokal bestanden: **390 Flutter-Tests mit Coverage**, strenge Analyse, Formatprüfung,
11 SQLite- und drei HTTP-Tests. Browserimport, Entwurfswiederaufnahme, PDF-Erzeugung,
Download und Vorschau geprüft. Kein physischer Android-Gerätelauf.
APK-Manifest, Signatur, ZIP-Ausrichtung und 16-KB-ELF-Ausrichtung der 64-Bit-Bibliotheken
geprüft. Die ältere 32-Bit-ARM-PDFium-Bibliothek verwendet 4-KB-Ausrichtung.

[GitHub-Testpipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42394089421)
ist vollständig erfolgreich: Analyse und 390 Tests, Web- und Android-Releasebuild
sowie abschließender Gesamtcheck.

APK: 101734858 Bytes. SHA-256:
`5297bd3102af76ce90d331c760c408d5da45cef0134e89642aab4cc0e897203c`.
Quellcommit: `f4f82d8fe99b7d41112ca14be321f059a0dfa3bf`.

[Bedienung, Sicherung und Grenzen](../../../audit/DOKUMENTENSCANNER_BUILD_44.md) ·
[Installation](../../../flutter_app/ANDROID-TEST.md)
