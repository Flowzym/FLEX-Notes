# FLEX für Android · 0.25.0+75

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/redesign/cream-olive/releases/android/build-75/FLEX-0.25.0%2B75-universal.apk) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

**Direktes Update der FLEX aus Build 62–67.** Kennung und Signatur bleiben gleich;
vorhandene Daten bleiben im selben App-Speicher. Für die ältere FLEX Test gilt
weiterhin die [Umzugsanleitung](../../../docs/rebuild/ANDROID-UMZUG-62.md).

- Monatskalender mit feinen Trennern zwischen allen Tagen.
- Neues Entwicklungsmodal: kompakter Verlauf, Themen-/Tonartfilter,
  Originaleinträge und Auswahl für die Gesprächsvorbereitung.
- Dokumentserien und Dokumentseite ersetzen nutzen ebenfalls die Android-
  Dokumentkamera mit Live-Randerkennung. Falls diese nicht starten kann, wird
  die normale Kamera ausdrücklich als Alternative angeboten.
- Enthält auch die Webänderungen aus Build 68–74, insbesondere individuelle
  Abläufe, Kalenderbedienung, Schüler-/Personenzuordnung und Rücklaufanhänge.

Live-Randerkennung benötigt funktionierende Google Play-Dienste. Normale Fotos
bleiben über die Fotokamera möglich. Installation und echte Kameraaufnahme auf
einem Handy sind noch nicht abgenommen.

Version 0.25.0, Build 75; App-Kennung `at.flowzym.flex_notizbuch`.
ARM64, ARMv7, x86_64; 103413012 Bytes.
Git-Verzeichnisobjekt des gebauten `flutter_app/`: `1e5963bec7cf46acda80c218c3fdfc1a88cfd284`.
SHA-256: `0aa30f3aa16080e113f31ff425c47979ffb3e070b835aa9b9a230d6c1dd7ce42`.
Signatur SHA-256: `9e50d1e2393e2bf867fc33b11e50383fd066f7b2df5026fd1f2a1d2790fdcd79`.

59 gezielte Tests erfolgreich über mehrere Läufe, Analyse ohne Befunde.
Browserprüfung mit synthetischen Daten bei 320/390 Pixeln. Keine vollständige
Testsuite in diesem Build. APK-Signatur, Paketmetadaten, ZIP-Integrität und
16-KB-Ausrichtung geprüft. Privates Signiermaterial ist nicht enthalten.

[Änderungen und Prüfnachweise](../../../docs/rebuild/CALENDAR-DEVELOPMENT-SCANNER-BUILD-75.md) ·
[APK-Prüfung](apk-verification.json) · [Signatur](signature.log) · [Build](android-build.log).
