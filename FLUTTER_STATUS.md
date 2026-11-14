# Aktueller Flutter-Stand

**Webvorschau und Android 0.28.0+78**, Branch `redesign/cream-olive`.

[Projektstatus](docs/rebuild/STATUS.md) ·
[Änderungen und Grenzen für Build 78](docs/rebuild/BACKUP-SHARING-BUILD-78.md) ·
[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/) ·
[GitHub-PR](https://github.com/Flowzym/FLEX-Notes/pull/1) ·
[Startanweisungen](flutter_app/README.md) ·
[Android-Bau und Installation](flutter_app/ANDROID-TEST.md).

Vollständige Sicherungen nutzen `.flexbackup` mit blockweiser Verschlüsselung,
Prüfung und Wiederherstellung. Android empfängt PDF, DOCX und Bilder über „Teilen
→ FLEX“ mit Vorschau und Schüler-/Unterrichtszuordnung. OneDrive-Registrierungsvorlage
und verständlichere Einrichtung sind vorbereitet; die eigene Client-ID fehlt noch.

[APKs Build 78](releases/android/build-78/README.md) aktualisieren die neue FLEX
Build 62–77 mit gleicher Kennung und Signatur. Die ältere FLEX Test bleibt separat:
[Umzug](docs/rebuild/ANDROID-UMZUG-62.md). Private Signierdaten bleiben außerhalb
GitHubs; CI baut ausdrücklich unsigniert. Vor dem Update unabhängig sichern.

Neue Sicherungen benötigen Build 78 oder neuer; alte JSON-Sicherungen bleiben
lesbar. Altimport und Browser-Downloads können weiterhin viel Speicher benötigen.
[Geräteabnahme](docs/rebuild/ANDROID-ACCEPTANCE-BUILD-78.md) ist offen; Linux-Messungen
sind kein Nachweis für Android-Kamera, Hintergrundbetrieb oder Keystore-Verhalten.
