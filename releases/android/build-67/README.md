# FLEX für Android · 0.21.3+67

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/redesign/cream-olive/releases/android/build-67/FLEX-0.21.3%2B67-universal.apk) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

**Direktes Update der neuen FLEX aus Build 62–66.** Kennung und Signatur bleiben
gleich; vorhandene Daten bleiben im selben App-Speicher. Für die ältere FLEX Test
gilt weiterhin die [Umzugsanleitung](../../../docs/rebuild/ANDROID-UMZUG-62.md).

- Einheitlicher 140-ms-Übergang beim Tippen und Wischen zwischen allen oberen
  Reitern: kleine gerichtete Bewegung und kurze Einblendung, ohne Nachfedern.
- Kompakte Materialkarten: kleinere Vorschau, zusammengefasste Angaben und
  direkt integrierte Aktionen. Die separate volle Aktionszeile entfällt.
- Große Schrift, sichtbare Aktionen und Such-/Scrollzustand bleiben erhalten.

Version 0.21.3, Build 67; App-Kennung `at.flowzym.flex_notizbuch`.
ARM64, ARMv7, x86_64; 102674488 Bytes.
Git-Verzeichnisobjekt des gebauten `flutter_app/`: `4316c5fa280dece08696345c8f2c4ac321b3ca0f`.
SHA-256: `531fb95cbc4ca3e39c460b8d7bd2538055f71eed14cb80bf0feb09c3d7e4667a`.
Signatur SHA-256: `9e50d1e2393e2bf867fc33b11e50383fd066f7b2df5026fd1f2a1d2790fdcd79`.

## Prüfung

36 Navigations-/Materialprüfungen und 10 UI-Prüfungen bestanden. Der neue Test
vergleicht den Übergang beim Tippen und Wischen in allen fünf Bereichen,
einschließlich Richtung, Zwischenposition und Abschluss. Vorhandene Tests prüfen
Such-/Scrollzustand, Regler, Mehrfachauswahl, Favoriten, Bereitlegen, Wiederherstellung
und Materialzuordnung. Analyse ohne Befunde; Formatierung geprüft.

Release-Webbuild im normalen Chromium-Touchmodus bei 390 × 844 geprüft:
Seitenwechsel in allen fünf Bereichen und Rückwechsel über die Pille visuell
kontrolliert. Materialkarten zusätzlich bei 600 Pixel Breite geprüft.
Keine JavaScript-Seitenfehler. Android- und Web-Release gebaut; APK-Signatur,
Paketmetadaten, ZIP-Integrität und 16-KB-Ausrichtung geprüft.

Die vollständige Testsuite wurde zuletzt für Build 66 ausgeführt. Physische
Android-Abnahme bleibt offen. Datenmodell und Sicherungsformat bleiben
unverändert. Privates Signiermaterial ist nicht Bestandteil dieses Releases.

[Änderungen](../../../docs/rebuild/MOTION-MATERIALS-BUILD-67.md) ·
[APK-Prüfung](apk-verification.json) · [Navigation/Material](navigation-material-tests.log) ·
[UI-Matrix](ui-tests.log) · [Browserprüfung](browser-check.json) ·
[Material Smartphone](browser-material.png) · [Material 600 Pixel](browser-material-wide.png).
