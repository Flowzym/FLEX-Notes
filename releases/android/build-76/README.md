# FLEX für Android · 0.26.0+76

[APK herunterladen](https://github.com/Flowzym/FLEX-Notes/raw/refs/heads/redesign/cream-olive/releases/android/build-76/FLEX-0.26.0%2B76-universal.apk) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

**Direktes Update der FLEX aus Build 62–75.** Kennung und Signatur bleiben gleich;
vorhandene Daten bleiben im selben App-Speicher. Für die ältere FLEX Test gilt
weiterhin die [Umzugsanleitung](../../../docs/rebuild/ANDROID-UMZUG-62.md).

- Kalender mit einer gemeinsamen Datum-/Werkzeugzeile; Stundenplan und Sa/So unter Verwalten.
- Wischen außerhalb des Rasters wechselt Tag/Woche/Monat, im Raster den Zeitraum.
- Freies Zeitfeld antippen für einen Termin mit Datum/Uhrzeit; über belegten
  Blöcken lang drücken. Monatsfelder öffnen einen Termin ohne Uhrzeit.
- Stundenplan nach Wochentagen, unabhängige Blockkopien, Überschneidungshinweise,
  erweiterbare Stundenzeiten und getrennte Ausnahmen/Wiederherstellung.
- Verwendete Stunden sind gegen Entfernen geschützt. Eine abgelaufene Gültigkeit
  lässt sich über eine sichtbare Aktion erweitern.

Version 0.26.0, Build 76; App-Kennung `at.flowzym.flex_notizbuch`.
ARM64, ARMv7, x86_64; 103593236 Bytes.
Git-Verzeichnisobjekt des gebauten `flutter_app/`: `14bcb3d39cdd4a81581d150e527eef9134cd9bfd`.
SHA-256: `df28c810f1b820437c7b9acf93baecde39a330556bd5de244f0fc1c6c393c62f`.
Signatur SHA-256: `9e50d1e2393e2bf867fc33b11e50383fd066f7b2df5026fd1f2a1d2790fdcd79`.

57 unterschiedliche gezielte Tests erfolgreich über mehrere Läufe, Analyse ohne
Befunde. Browserprüfung mit synthetischen Daten bei 320/390 Pixeln und echten
Touch-Ereignissen. Keine vollständige Testsuite in diesem Build. APK-Signatur,
Paketmetadaten, ZIP-Integrität und 16-KB-Ausrichtung geprüft. Privates Signiermaterial
ist nicht enthalten. Die physische Android-Abnahme bleibt offen.

[Änderungen und Prüfnachweise](../../../docs/rebuild/CALENDAR-TOUCH-TIMETABLE-BUILD-76.md) ·
[APK-Prüfung](apk-verification.json) · [Signatur](signature.log) · [Build](android-build.log).
