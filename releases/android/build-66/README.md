# FLEX für Android · 0.21.2+66

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/redesign/cream-olive/releases/android/build-66/FLEX-0.21.2%2B66-universal.apk) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

**Direktes Update der neuen FLEX aus Build 62–65.** Kennung und Signatur bleiben
gleich; vorhandene Daten bleiben im selben App-Speicher. Für die ältere FLEX Test
gilt weiterhin die [Umzugsanleitung](../../../docs/rebuild/ANDROID-UMZUG-62.md).

- Untere Leiste: schmale olivfarbene Aktivmarkierung, stärkere Beschriftung und
  einheitliche Linienicons; keine große Farbfläche.
- Wischen zwischen den oberen Reitern in Kalender, Live, Organisation, Material
  und Mehr, auch direkt auf der Pille. Kein Umspringen an den Rändern.
- Live startet mit Notizen, gefolgt von Aktuell und Ablauf. Suche, Scrollpositionen
  und unabhängige Reglergesten bleiben erhalten.

Version 0.21.2, Build 66; App-Kennung `at.flowzym.flex_notizbuch`.
ARM64, ARMv7, x86_64; 102658100 Bytes.
Git-Verzeichnisobjekt des gebauten `flutter_app/`: `e7e3e5f051719d1e791d460550cad76bba975690`.
SHA-256: `16a368aead4e44a408887252b07edc74aff5bc0b3b25ccb24e4f6c01db4638aa`.
Signatur SHA-256: `9e50d1e2393e2bf867fc33b11e50383fd066f7b2df5026fd1f2a1d2790fdcd79`.

## Prüfung

Der vollständige Lauf umfasst 520 Flutter-Tests: 511 bestanden zunächst,
neun ältere UI-Tests erwarteten noch die vorherige Startseite bzw. Reihenfolge.
Nach Anpassung dieser Testnavigation bestanden alle 82 Prüfungen der acht
betroffenen Testdateien, einschließlich dieser neun Fälle. Zusätzlich bestanden
19 UI-Matrix-/Tonwahlprüfungen. Analyse ohne Befunde; Formatierung geprüft.

Release-Webbuild in Chromium bei 390 × 844 mit synthetischen Daten geprüft:
Touch-Wechsel über den Seiteninhalt in allen fünf Bereichen, Rückwechsel
über die Pille, korrekte aktive Markierung; keine JavaScript-Seitenfehler.
Android- und Web-Release gebaut; APK-Signatur, Paketmetadaten, ZIP-Integrität und
16-KB-Ausrichtung geprüft. Physische Android-Abnahme bleibt offen.

Datenmodell und Sicherungsformat bleiben unverändert. Privates Signiermaterial
ist nicht Bestandteil dieses Releases.

[Änderungen](../../../docs/rebuild/NAVIGATION-BUILD-66.md) ·
[APK-Prüfung](apk-verification.json) · [Gesamtlauf](full-tests.log) ·
[Abschließende Tests](final-navigation-tests.log) · [UI-Matrix](ui-tests.log) ·
[Browserprüfung](browser-check.json) · [Live](browser-live.png) · [Material](browser-material.png).
