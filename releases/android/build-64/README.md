# FLEX für Android · 0.21.0+64

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/redesign/cream-olive/releases/android/build-64/FLEX-0.21.0%2B64-universal.apk) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

**Direktes Update der neuen FLEX aus Build 62/63.** Kennung und Signatur bleiben
gleich, vorhandene Daten bleiben im selben App-Speicher. Für die ältere FLEX Test
gilt weiterhin die [Umzugsanleitung](../../../docs/rebuild/ANDROID-UMZUG-62.md).

- Schülerübersicht → Materialien: Dateien individuell zuordnen, mit eigenen
  Unterrichtsdaten je Schüler. Termine ändern, ergänzen oder entfernen;
  gemeinsame Dateien und die Planung anderer Schüler bleiben erhalten.
- Geplante Materialien erscheinen auch bei den Unterlagen des Kalendertags.
- Eintragungsköpfe geben dem Schülernamen mehr Platz; direkte Aktionen bleiben
  sichtbar. Zurück sichert weiterhin den Entwurf.
- Navigationssegmente sind gleich breit. Bei großer Schrift werden gleichmäßige
  Reihen gebildet, ohne Wörter zu zerlegen.

Version 0.21.0, Build 64; App-Kennung `at.flowzym.flex_notizbuch`.
ARM64, ARMv7, x86_64; 102576296 Bytes.
Git-Verzeichnisobjekt des gebauten `flutter_app/`: `0e9612118155a62e37aa317c9d817d1bb9a69591`.
SHA-256: `13494562ffa8c3fcac41ba57ef47256c8f226df004208a90256635438a30bebf`.
Signatur SHA-256: `9e50d1e2393e2bf867fc33b11e50383fd066f7b2df5026fd1f2a1d2790fdcd79`.

519 Flutter-Tests und 19 abschließende Material-/Navigationstests bestanden;
11 SQLite- und 3 Servertests bestanden. Analyse ohne Befunde. Android- und
Web-Release gebaut; APK-Signatur, Paketmetadaten, ZIP-Integrität und
16-KB-Ausrichtung geprüft. Smartphone-Browser (390 × 844): Zuordnung,
Datumsänderung, Wiederöffnen nach Neuladen, Navigation und Eintragungskopf geprüft.
Installation auf echter Android-Hardware bleibt offen.

Neue Sicherungen mit schülerbezogenen Unterrichtsdaten benötigen Build 64 oder
neuer. Ältere Sicherungen bleiben lesbar. Privates Signiermaterial ist nicht
Bestandteil dieses Releases.

[Bedienung und Prüfbericht](../../../docs/rebuild/PUPIL-MATERIALS-BUILD-64.md) ·
[APK-Prüfung](apk-verification.json) · [Tests](full-final-tests.log) ·
[Browserprüfung](browser-check.json) · [Materialansicht](browser-pupil-materials.png) ·
[Eintragungskopf](browser-entry.png).
