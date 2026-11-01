# FLEX-Notizbuch: Übergabe vom 31.10.2026

Die aktuelle hochgeladene HTML und die HTML im Quellen-ZIP sind identisch:
SHA-256 `9e4be0426d89cac006d2f3ef540c2d6f132d7d46edeef15141eade9e727b0b07`.
Alle Dateien aus dem Originalarchiv liegen unverändert unter `work/FLEX-Notizbuch/`.
Es gab keine vorhandenen Flutter-Arbeiten. Neue Quellen liegen unter `flutter_app/`.

**Noch kein startbarer Flutter-Build verifiziert.** Flutter/Dart fehlen und der
SDK-Download von `storage.googleapis.com` ist durch die aktive Netzwerkrichtlinie
gesperrt (HTTP 403). Die schon gespeicherte Domainfreigabe wurde nicht erneut
angelegt und nicht veröffentlicht. Im laufenden System ist sie noch nicht aktiv.

## Tatsächlich geprüft

| Prüfung | Ergebnis |
| --- | --- |
| Vorhandene 12 lokale Node-Suiten | Bestanden |
| Ursprüngliches SQLite-Zielschema | Bestanden |
| Neues Flutter-SQL-Schema, 11 lokale Tests | Bestanden |
| 14 Dart-Dateien, Syntaxparser | Ohne Parserfehler; keine Typprüfung |
| SQLite-WASM-Download und SHA-256 | Bestanden |
| Originaldateien gegen Quellenarchiv | Bytegleich |
| Flutter/Dart-Analyzer und 14 vorbereitete Flutter-Tests | Nicht ausgeführt – SDK fehlt |
| Web-/Windows-/Android-Build | Nicht ausgeführt |
| Flutter-Prozessstart | Nicht ausgeführt |
| Browsertests | Gemäß Auftrag nicht ausgeführt |

Java 21 ist in der Linux-Cloud vorhanden, Android SDK/adb fehlen. Windows-Builds
benötigen den Windows-Rechner mit Visual-Studio-C++-Toolchain; dessen Zustand kann
hier nicht geprüft werden. Es gibt weder APK noch EXE noch gestartete Webvorschau.

## Neue Dateien und Umfang

- `flutter_app/lib/domain/`: Modelle, Regeln, Speichervertrag.
- `flutter_app/lib/data/`: transaktionaler SQLite/Drift-Speicher, Revisionen, Outbox,
  Entwürfe, Vollsicherung/Wiederherstellung und unveränderte HTML-Backup-Vormerkung.
- `flutter_app/lib/application/`: Controller für Oberfläche und Repository.
- `flutter_app/lib/ui/`: Hauptnavigation, Schüler, Orga-Editor, Übersichten,
  Entwürfe, Darstellung und Datenaktionen.
- `flutter_app/assets/schema.sql`: DDL der separaten Flutter-Datenbank.
- `flutter_app/test/`: 12 Repository-/Domänentests und 2 Widget-Tests, vorbereitet.
- `flutter_app/tool/`: SQL-Prüfung, sichere Runner-Vorbereitung, Drift-Worker-Quelle.
- `flutter_app/web/`: Einstieg und prüfsummenverifiziertes SQLite-WASM.
- `flutter_app/README.md`, `ARCHITEKTUR.md`, Paketdefinition, Analysekonfiguration,
  Ignore-Regeln und Lizenz des mitgelieferten SQLite-Moduls.

Quellcode der vier übrigen Schülerbereiche, vollständige HTML-Datenmigration,
Datenbankverschlüsselung, native Benachrichtigungen, Synchronisation und Scanner
sind noch nicht implementiert. Die UI kennzeichnet ausstehende Bereiche ausdrücklich.

## Fortsetzung nach aktivem SDK-Zugriff

1. Offizielles Flutter-SDK installieren und `flutter doctor -v` ausführen.
2. In `flutter_app/`: `python3 tool/prepare.py` (Windows: `py tool/prepare.py`).
   Dies generiert fehlende Plattformrunner, löst Abhängigkeiten auf und baut den Web-Worker.
3. `dart format lib test tool/drift_worker.dart`, `flutter analyze`, `flutter test`.
4. Web bauen und den Entwicklungsprozess starten; lokale HTTP-Prüfung, keine Browsertests.
5. Android-SDK-Voraussetzungen und Windows-Toolchain am jeweiligen Host vervollständigen.
6. Kompilier-/Laufzeitbefunde beheben; erst danach den Ablauf als startbar bestätigen.

Die ausführlichen Befehle und Grenzen stehen in `flutter_app/README.md`.
