# FLEX 0.28.0+78 für Android

- [ARM64 herunterladen – für aktuelle Android-Handys](FLEX-0.28.0%2B78-arm64.apk) · 40,7 MB
- [ARMv7 herunterladen – für ältere 32-Bit-Geräte](FLEX-0.28.0%2B78-armv7.apk) · 36,1 MB
- [Änderungen und Prüfbericht](../../../docs/rebuild/BACKUP-SHARING-BUILD-78.md)
- SHA-256: [ARM64](FLEX-0.28.0%2B78-arm64.apk.sha256) / [ARMv7](FLEX-0.28.0%2B78-armv7.apk.sha256)

Neue vollständige Sicherungen werden blockweise verarbeitet und benötigen deutlich
weniger Arbeitsspeicher. Android kann PDFs, DOCX und Bilder über „Teilen → FLEX“
empfangen und Schülern sowie Unterricht zuordnen.

App-Kennung und dauerhafte Signatur bleiben gleich: Installation über die neue
**FLEX Build 62–77** ist vorgesehen. Vor dem Update eine vollständige verschlüsselte
Sicherung außerhalb der App speichern. App nicht deinstallieren oder deren Daten
löschen. Beim Wechsel von Build 62–76 gilt zusätzlich die
[Migration zur verschlüsselten Ablage](../../../docs/rebuild/SECURITY-QUALITY-BUILD-77.md).

Neue `.flexbackup`-Dateien benötigen Build 78 oder neuer. Ältere JSON-Sicherungen
bleiben importierbar. Die ältere **FLEX Test** ist eine separate App;
[Umzugsanleitung](../../../docs/rebuild/ANDROID-UMZUG-62.md).

Geprüft: dauerhafte Signatur, Kennung `at.flowzym.flex_notizbuch`, VersionCode 78,
ZIP-Integrität, Einzelarchitektur, SQLCipher und 16-KB-Ausrichtung der ARM64-
Bibliotheken. Keine privaten Signierdaten im Paket. Die
[physische Android-Abnahme](../../../docs/rebuild/ANDROID-ACCEPTANCE-BUILD-78.md)
ist noch offen, ebenso die eigene Microsoft-Appregistrierung.

[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
