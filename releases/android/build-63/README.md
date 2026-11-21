# FLEX für Android · 0.20.0+63

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/redesign/cream-olive/releases/android/build-63/FLEX-0.20.0%2B63-universal.apk) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

**Direktes Update der neuen FLEX aus Build 62.** App-Kennung und Signatur
bleiben gleich; vorhandene Daten bleiben im selben App-Speicher. Für die ältere
**FLEX Test** gilt weiterhin die [Umzugsanleitung](../../../docs/rebuild/ANDROID-UMZUG-62.md).

Kalender und Stundenplan sind in Tag, Woche und Monat vereint. Unterricht kann
ausgeblendet werden; Grundplan und Stundenzeiten sind direkt bearbeitbar.
Einzeltermine und Änderungen ab Datum bleiben getrennt. Serienänderungen
übernehmen verknüpfte Planungen, Dateien und Erinnerungen atomar.

- Version: 0.20.0, Buildnummer 63; App-Kennung: `at.flowzym.flex_notizbuch`.
- Größe: 102494352 Bytes; ARM64, ARMv7 und x86_64.
- Git-Verzeichnisobjekt des gebauten `flutter_app/`: `a78bdc75c70a6735cac7333473b88b9aa1cdf5ae`.
- SHA-256: `b4f5ceaa38b95eb2785bef5cdc9ebd0ddefe93020a9c096068a327e3d8699e60`.
- Signatur SHA-256: `9e50d1e2393e2bf867fc33b11e50383fd066f7b2df5026fd1f2a1d2790fdcd79` (identisch mit Build 62).

Alle 514 Flutter-Tests, 11 SQLite-Tests und 3 Vorschau-Servertests bestanden.
Analyse ohne Befunde. Android- und Web-Release gebaut, Signatur, Paketmetadaten,
ZIP-Integrität und 16-KB-Ausrichtung geprüft. Release-Webbuild im Smartphone-Browser
mit synthetischen Testdaten durchgespielt, ohne JavaScript-Seitenfehler.
Eine Installation auf echter Android-Hardware ist noch nicht geprüft.

[Änderungen, Prüfung und Grenzen](../../../docs/rebuild/CALENDAR-BUILD-63.md) ·
[APK-Bericht](apk-verification.json) · [Flutter-Tests](full-tests.log) ·
[Browserprüfung](browser-check.json) · [Wochenansicht](browser-week.png) ·
[Tagesansicht](browser-day.png).

Privates Signiermaterial ist nicht Bestandteil dieses Releases.
