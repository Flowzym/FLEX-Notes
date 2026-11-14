# FLEX 0.29.0+79 für Android

- [ARM64 herunterladen](FLEX-0.29.0%2B79-arm64.apk) · 38,9 MB
- [ARMv7 herunterladen](FLEX-0.29.0%2B79-armv7.apk) · 34,0 MB
- [Änderungen und Prüfbericht](../../../docs/rebuild/REVIEW-CALENDAR-BUILD-79.md)
- [Prüfsummen und Quellcommit](release-manifest.json)
- [Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

Gleiche App-Kennung `at.flowzym.flex_notizbuch` und permanente Signatur; vorgesehen
als Update über die neue FLEX Build 62–78. **Vor dem Update eine unabhängige
vollständige verschlüsselte Sicherung erstellen.** Nicht deinstallieren und keine
App-Daten löschen. Die ältere FLEX Test bleibt separat; siehe
[Umzug](../../../docs/rebuild/ANDROID-UMZUG-62.md).

Schema 8 erhält Schüler, Einträge, Entwürfe und Materialien. Neue Sicherungen
benötigen Build 79; alte Sicherungen bleiben importierbar. Kein Downgrade nach
Migration.

Geprüft: Version/Identität, permanentes Zertifikat, v1/v2/v3-Signatur, ZIP-
Integrität und 16-KB-Ausrichtung, ARM64-ELF-Ausrichtung, SQLCipher, keine privaten
Signierdaten, separate Debugsymbole. ML Kit/Google Play Services sind entfernt.
Dart und Kotlin sind obfuskiert; eine automatisch generierte Flutter-Plugin-URI
bleibt als Buildmetadatum erhalten: [Releasegrenzen](../../../docs/rebuild/RELEASING.md).

[Physische Android-Abnahme](../../../docs/rebuild/ANDROID-ACCEPTANCE-BUILD-79.md)
steht noch aus: insbesondere Live-Kamera, Offline-Diktat, Launcher-Widget und
Benachrichtigungen. Automatisierte Tests sind kein Ersatz für diese Prüfung.
