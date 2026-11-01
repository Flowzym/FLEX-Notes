# FLEX-Notizbuch – erster Flutter-Implementierungsstand

Der Flutter-Code liegt unabhängig vom unveränderten HTML-Prototyp in diesem
Verzeichnis. Referenz: `../work/FLEX-Notizbuch/`. Die separat hochgeladene Datei
`FLEX-Notizbuch (37).html` ist bytegleich mit der HTML-Datei im Quellenarchiv.

**Status: Quellen vorbereitet, noch kein erfolgreich kompilierter oder gestarteter
Flutter-Build.** In dieser Cloud fehlen Flutter und Dart; der Netzwerkproxy
verweigert den offiziellen SDK-Download auf `storage.googleapis.com` mit HTTP 403.
Die dafür gespeicherte Netzwerkfreigabe ist noch nicht im laufenden System aktiv.
Es wurden keine Umgebungsversionen veröffentlicht.

## Inhalt dieses Schritts

- Übersicht und Schüler als Hauptnavigation; Klassen-Orga, Entwürfe, Archiv und
  Einstellungen über „…“. Responsive NavigationRail/NavigationBar.
- Schüler anlegen, umbenennen, farblich kennzeichnen, archivieren und wiederherstellen.
  Archivierung blendet offene Verpflichtungen nicht aus der Gesamtübersicht aus.
- Schülerübersicht mit Anstehend, Noch ergänzen und Zuletzt, Suche und Aufgabenfiltern.
- Fünf Fachbereiche sind erreichbar. Der vollständige Editor dieses Schritts ist
  **Orga**. Ziele, Sozialverhalten, Arbeitsverhalten und Hausübung zeigen ausdrücklich
  ihren noch ausstehenden Umsetzungsstand; es werden keine Datenfunktionen vorgetäuscht.
- Orga-Notizen, Aufgaben und Checklisten mit stabilen Punkt-IDs; getrennte Daten für
  Aufgabentermin und Erinnerung, klassenbezogen oder einem Schüler zugeordnet.
- Anlegen/bearbeiten/speichern/laden/erledigen, Wiederöffnen und Erinnerungsquittierung
  sind im Code und in vorbereiteten Repository-/Widget-Tests enthalten.
- Zurück/Escape und App-Lebenszykluswechsel sichern Orga-Entwürfe. Zusätzlich
  Autosave nach 400 ms Schreibpause. Ein noch nicht bestätigter neuer Checklistenpunkt
  ist im Entwurf enthalten. Bei Speicherfehlern bleibt der Editor offen.
- Alte Editorrevisionen werden abgewiesen; ihr Entwurf bleibt zugänglich.
  Änderungen sind als vollständige Vorher-/Nachherfassungen einsehbar.
- Darstellung: hell/dunkel/System, Akzentfarbe, Schriftgröße, kompakte Abstände.
- Vollsicherung als JSON über eine bewusst ausgelöste Kopieraktion; Wiederherstellung
  nur in einem leeren Arbeitsbereich. Ein Dateiauswahldialog ist noch nicht umgesetzt.
- HTML-Backups werden vollständig und unverändert für eine spätere Migration
  vorgemerkt, einschließlich unbekannter Felder. **Noch keine Aktivierung/Migration
  des HTML-Datenbestands.** Verschlüsselte HTML-Sicherungen werden erkannt, aber
  noch nicht in Flutter entschlüsselt. Der bestehende HTML-Prototyp kann sie öffnen.

Neue Arbeitsbereiche starten leer. Die Tests verwenden ausschließlich synthetische
Namen und Inhalte. Noch keine Freigabe für echte Schülerdaten.

## Voraussetzungen und einmalige Vorbereitung

Benötigt werden Flutter Stable mit Dart >= 3.10 (Flutter >= 3.38), Python >= 3.10,
Git und curl. Flutter muss mit seinem `bin`-Verzeichnis im PATH stehen; Dart wird
mitgeliefert. Verwende das offizielle Flutter-SDK, ohne TLS- oder Prüfsummenprüfung
abzuschalten. Unter Windows nach PATH-Änderungen ein neues Terminal öffnen.

In diesem Verzeichnis:

```sh
flutter --version
flutter doctor -v
python tool/prepare.py
```

In der Linux-Cloud `python3` statt `python`, unter Windows ggf. `py` verwenden.
`prepare.py` führt `flutter create --no-pub` in einem temporären Verzeichnis aus
und übernimmt **nur fehlende** Android-/Windows-Runnerdateien und `.metadata`.
Es überschreibt weder Dart-Dateien noch den HTML-Prototyp oder vorhandene Runner.
Anschließend: `flutter pub get`, SHA-256-Prüfung der SQLite-WASM-Datei und
Kompilierung des mitgelieferten Drift-Workers nach `web/drift_worker.js`.

Native Runner, Worker-Kompilat und `pubspec.lock` konnten hier noch nicht erzeugt
werden. Nach erfolgreicher Vorbereitung gehören die erzeugten Runnerdateien,
`.metadata` und `pubspec.lock` zum versionierten Projekt. Die Paketversionen der
wesentlichen Laufzeitbibliotheken sind in `pubspec.yaml` festgelegt; transitive
Abhängigkeiten sind erst nach dem tatsächlichen Resolverlauf gesperrt.

Das bereits verifizierte `web/sqlite3.wasm` stammt aus sqlite3.dart 3.8.0.
Prüfsumme: `efd308be92a34f3aa15f289a37f213b0230fd80888a1364326ee29579d892d37`.
Lizenz: `third_party/sqlite3-LICENSE`.

## Nächste Prüf- und Startschritte – hier noch nicht ausgeführt

```sh
dart format lib test tool/drift_worker.dart
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

Der letzte Befehl startet nur den Entwicklungsprozess; er öffnet keinen Browser.
Keine Browsertests ausführen. Ein Prozessstart muss noch anhand des Logs und einer
lokalen HTTP-Anfrage geprüft werden. Die Flutter-Widget-Tests laufen ohne Browser.
Die Webvorschau benötigt den festen lokalen Port, weil eine andere Webadresse einen
anderen lokalen Datenstand besitzt. Im Speicher verbleibende oder unsicher mehrfach
geöffnete IndexedDB-Fallbacks werden beim Start abgewiesen; kein stiller RAM-Ersatz
für dauerhafte Speicherung. Die aktuelle Browserfunktion wurde nicht getestet.

Für **Windows** zusätzlich Visual Studio 2022 mit „Desktopentwicklung mit C++“,
Windows SDK und CMake-Komponenten installieren. In einem Windows-Terminal:

```powershell
flutter doctor -v
flutter run -d windows
flutter build windows
```

Windows-Builds können in dieser Linux-Cloud nicht erstellt werden. Die tatsächliche
Konfiguration des genannten Windows-Rechners wurde nicht geprüft.

Für **Android**: Android Studio/SDK, Platform-Tools, passende SDK-/Build-Tools und
gegebenenfalls NDK gemäß dem generierten Flutter-Projekt, akzeptierte SDK-Lizenzen
und ein Emulator oder USB-Gerät. Java 21 ist hier vorhanden; SDK, adb und sdkmanager
fehlen. Der von Flutter/Android Studio gewählte JDK muss zum generierten Gradle-/AGP-
Stand passen; maßgeblich ist `flutter doctor -v`.

```sh
flutter doctor --android-licenses
flutter devices
flutter run -d <ANDROID-GERAETE-ID>
flutter build apk --debug
```

Ein Release-APK, Signierung und Installation auf echten Geräten sind nicht geprüft.

## Bereits ausgeführte lokale Prüfungen

- Zwölf unveränderte Node-Suiten des HTML-Prototyps: bestanden.
- Ursprüngliche SQLite-Zielschema-Prüfung: bestanden.
- `python3 tool/test_schema.py`: 11 Tests des neuen SQL-Schemas bestanden.
  Dies prüft echte SQLite-Constraints, Rollback und Datei-Reopen, nicht Dart-Code.
- 14 Dart-Dateien mit Tree-sitter-Dart syntaktisch geparst: keine Parserfehler.
  Dies ist **kein** Dart-Analyzer, Flutter-Test oder Compilerlauf.
- `python3 tool/prepare.py --assets-only`: erfolgreich, SHA-256 geprüft;
  Wiederholung verwendet dieselbe bereits geprüfte Datei.
- Vergleich aller Originaldateien mit dem ZIP: unverändert.

Vorbereitet, aber **nicht ausgeführt**: 12 Dart-Domänen-/Repositorytests und
2 Flutter-Widget-Tests in `test/`. Noch kein Flutter-Prozess, Web-Build, APK oder EXE.

## Schichten und Grenzen

`lib/domain/` enthält Modelle, Invarianten und das Repository-Interface.
`lib/data/` implementiert SQLite/Drift mit explizitem SQL und Parametern.
`lib/application/` koordiniert Laden/Änderungen. `lib/ui/` enthält Darstellung und
Editorzustand. Das SQL-Schema ist in `assets/schema.sql`, die Architekturabwägungen
stehen in `ARCHITEKTUR.md`.

Die native Datenbank liegt im Application-Support-Verzeichnis. Die Webvorschau
nutzt einen separaten SQLite-Datenstand in OPFS/IndexedDB. Alle fachlichen Mutationen
schreiben Revision, logische Operation und Outbox atomar. Die Outbox wird noch
nicht versendet. Lokale Datenbank und Flutter-JSON-Export sind unverschlüsselt.
Keine Synchronisation, kein Dokumentenscanner und keine nativen Benachrichtigungen.
