# FLEX 0.27.0+77 für Android

- [ARM64 herunterladen – für aktuelle Android-Handys](FLEX-0.27.0%2B77-arm64.apk) · 40,2 MB
- [ARMv7 herunterladen – für ältere 32-Bit-Geräte](FLEX-0.27.0%2B77-armv7.apk) · 35,5 MB
- [Prüfbericht und offene Grenzen](../../../docs/rebuild/SECURITY-QUALITY-BUILD-77.md)
- SHA-256: [ARM64](FLEX-0.27.0%2B77-arm64.apk.sha256) / [ARMv7](FLEX-0.27.0%2B77-armv7.apk.sha256)

**Vor dem Update eine vollständige verschlüsselte Sicherung außerhalb von FLEX
speichern.** Die Datenbank und gespeicherten Materialien werden beim ersten Start
in die verschlüsselte Geräteablage übertragen. App-Kennung und Signatur bleiben
gleich: Installation über FLEX Build 62–76 ist vorgesehen. App nicht deinstallieren
oder deren Daten löschen. Die automatische Migration ist mit Dateidatenbanken
getestet, aber noch nicht auf einem physischen Android-Gerät abgenommen.

Kein Downgrade nach der Umstellung. Neue Sicherungen benötigen Build 77 oder neuer;
ältere Sicherungen bleiben importierbar. Ohne unabhängige Sicherung können Daten
bei Verlust des Geräteschlüssels nicht wiederhergestellt werden.

Die ältere **FLEX Test** (`at.flowzym.flex_notizbuch.test`) bleibt eine separate App.
Für sie gilt weiterhin die [Umzugsanleitung](../../../docs/rebuild/ANDROID-UMZUG-62.md).

Geprüft: gleiche dauerhafte Signatur, Kennung `at.flowzym.flex_notizbuch`, VersionCode
77 in beiden APKs, ZIP-Integrität, passende Einzelarchitektur, SQLCipher-Bibliothek
und 16-KB-Ausrichtung der ARM64-Bibliotheken. Keine privaten Signierdaten im Paket.
Ein Gerätestest bleibt erforderlich; insbesondere große Sicherungen benötigen noch
viel Arbeitsspeicher. [Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
