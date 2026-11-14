# Aktueller Flutter-Stand

**Webvorschau und Android 0.27.0+77**, Branch `redesign/cream-olive`.

Der fortlaufende [Projektstatus](docs/rebuild/STATUS.md) und die
[Änderungen für Build 77](docs/rebuild/SECURITY-QUALITY-BUILD-77.md) beschreiben den
aktuellen Funktionsumfang, Nachweise und offene Voraussetzungen.

[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/) ·
[GitHub-PR](https://github.com/Flowzym/FLEX-Notes/pull/1) ·
[Startanweisungen](flutter_app/README.md) ·
[Android-Bau und Installation](flutter_app/ANDROID-TEST.md).

Die aktuellen Android-APKs sind Build 77 (ARM64/ARMv7). Sie aktualisieren die neue **FLEX** aus Build 62–76 mit gleicher Kennung und
Signatur. Die ältere **FLEX Test** bleibt separat; deren ursprünglicher
Testschlüssel fehlt weiterhin. [APK](releases/android/build-77/README.md) und
[Umzug mit Notizbuch- und Materialsicherung](docs/rebuild/ANDROID-UMZUG-62.md).
Die neue dauerhafte Signatur ist im Build festgeschrieben; der private Schlüssel
bleibt außerhalb GitHubs. CI baut ausdrücklich unsigniert.
Historische Rekonstruktionsstände stehen im Projektstatus und unter `reference/`.

Vor der neuen Android-Speicherverschlüsselung eine vollständige Sicherung außerhalb
der App speichern. Keine physische Android-Abnahme; große Sicherungen benötigen
noch viel Arbeitsspeicher. Details und Kompatibilitätsgrenzen im Prüfbericht.
