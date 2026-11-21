# FLEX 0.30.0+80 für Android

- [ARM64 herunterladen](FLEX-0.30.0%2B80-arm64.apk) · 38,9 MB
- [ARMv7 herunterladen](FLEX-0.30.0%2B80-armv7.apk) · 34,0 MB
- [Navigation, Standardansichten und Termin-Tags](../../../docs/rebuild/NAVIGATION-BUILD-80.md)
- [Prüfsummen und Quellcommit](release-manifest.json)
- [Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

Gleiche App-Kennung `at.flowzym.flex_notizbuch` und permanente Signatur wie
Build 62–79. Als Update installieren, nicht vorher deinstallieren oder App-Daten
löschen. Vor dem Update eine unabhängige vollständige Sicherung anlegen. Die
ursprüngliche FLEX Test bleibt separat; siehe [Umzug](../../../docs/rebuild/ANDROID-UMZUG-62.md).

Schema 8 bleibt unverändert. Bestehende Einträge, Schüler, Entwürfe und Materialien
bleiben erhalten. Termin-Tags und neue Navigationseinstellungen mit Build 80 oder
neuer bearbeiten; ältere Versionen kennen diese zusätzlichen Angaben nicht.

Beide Pakete sind auf App-Identität, permanentes Zertifikat, v1/v2/v3-Signatur,
ZIP-Integrität, 16-KB-Ausrichtung, SQLCipher und fehlende private Signierdaten
geprüft. ARM64-Bibliotheken erfüllen auch die ELF-Ausrichtung. Debugsymbole und
R8-Zuordnung liegen separat; keine DWARF-Debugsektionen in der App-Bibliothek.
Eine generierte Flutter-Plugin-URI bleibt als Buildmetadatum erhalten.

[ARM64-Prüfung](verification-arm64.json) · [ARMv7-Prüfung](verification-armv7.json)

Die [physische Android-Abnahme](../../../docs/rebuild/ANDROID-ACCEPTANCE-BUILD-79.md)
bleibt offen. Browser- und automatisierte Tests ersetzen keine Prüfung von
Kamera, Diktat, Launcher oder Benachrichtigungen auf einem konkreten Handy.
