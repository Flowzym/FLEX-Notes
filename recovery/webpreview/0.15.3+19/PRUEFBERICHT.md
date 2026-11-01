# Prüfung des FLEX-Webpreview-Pakets

Geprüft am 1. November 2026. Auftrag: Original erhalten, Version, Quelltexte und Source Maps untersuchen, vorhandene Webvorschau lokal starten, keine Browsertests und keine Veröffentlichung.

## Ergebnis

Das hochgeladene Paket weist **0.15.3+19** aus. Es enthält den gebauten Webstand, aber kein bearbeitbares Flutter-Quellprojekt. Der zuletzt genannte Stand **0.16.0+20** ist damit nicht wiederhergestellt. Hinweise auf diese neuere Version fehlen in den untersuchten Textdateien des Pakets.

Belege: `package/FLEX-Notizbuch-Webvorschau/build/web/version.json` enthält `version: 0.15.3` und `build_number: 19`; `FLUTTER_STATUS.md` und `DIALOG_VERFEINERUNG.md` nennen denselben Stand. Die Hauptanwendung ist minifiziert; ihre Version wurde nicht zusätzlich über eine Browseroberfläche geprüft.

## Original und Integrität

- Originalupload: `/workspace/attachments/94bdd8b2-8f7b-4ae8-952f-3fb0852f1bb9/FLEX-Notizbuch-Flutter-Dialog-Verfeinerung-Webvorschau.zip`.
- Bytegleiche Sicherung: `original/FLEX-Notizbuch-Flutter-Dialog-Verfeinerung-Webvorschau.zip`.
- ZIP-Größe: **21.422.248 Byte**; 72 Dateien, entpackt **60.480.306 Byte**.
- SHA-256: `b29aa3c067014637fa279a19c493e6928322cedc5aa1d45d2f80bd5777cc3693`.
- ZIP-CRC-Prüfung erfolgreich. Alle **71** im beiliegenden `MANIFEST.sha256` aufgeführten Dateien stimmen überein; das Manifest selbst ist die 72. Datei.
- Nach dem Start wurden alle entpackten Dateien erneut byteweise mit dem ZIP verglichen. Originalupload, Sicherung und Paketinhalt sind unverändert.
- Untersuchung und Startskript liegen ausschließlich unter `/workspace/FLEX-Recovery`. `/workspace/FLEX-Notes` bleibt ein leerer Git-Arbeitsstand auf `work` ohne Commits.

Die Prüfsummen belegen die interne Konsistenz und die unveränderte Kopie. Sie sind keine unabhängige Signatur des ursprünglichen Herausgebers.

## Enthaltene Dateien und Wiederherstellbarkeit

| Bestandteil | Tatsächlicher Inhalt | Was daraus wiedergewonnen werden kann |
| --- | --- | --- |
| Webanwendung | 47 Dateien unter `build/web`, darunter `index.html`, `main.dart.js` (4.235.071 Byte), Flutter-Loader, Service Worker und `version.json` | Der vorhandene kompilierte Webstand lässt sich bytegleich erhalten und per HTTP bereitstellen. Die Browserfunktion wurde nicht geprüft. |
| Anwendungscode | Minifiziertes `main.dart.js`; keine `.dart`-Dateien | Kompilierte Logik, Texte, SQL-Anweisungen und Konstanten sind teilweise lesbar. Originale Dart-Dateien, Kommentare, Formatierung, Modulstruktur und vom Compiler entfernte Teile sind daraus nicht verlustfrei rekonstruierbar. Ein Nachbau wäre neue Entwicklungsarbeit. |
| Datenbankschema | `build/web/assets/assets/schema.sql`, ausdrücklich Schema 7, 19 Tabellen und drei explizite Indizes | Das vorhandene SQL-Schema ist als Text vollständig übernehmbar. Es ersetzt weder die Dart-Datenzugriffsschicht noch deren vollständige Migrationsquellen und JSON-Datenmodelle. |
| Assets und Laufzeit | Selawik, Gelasio, Roboto, Material-/Cupertino-Icons, Font-/Asset-Manifeste, Shader-Artefakte, SQLite-Wasm und CanvasKit-/Skwasm-Dateien | Die mitgelieferten Dateien sind bytegleich wiederverwendbar. Die Icon-Schriften können buildseitig reduziert sein; sie belegen nicht den vollständigen ursprünglichen Icon-Bestand. Eigene Hintergrundbilder sind nicht enthalten. |
| Dokumentation | 18 Markdown-Dateien, Startanleitung und Lizenztexte | Beschreibungen von Funktionen, Dialogen, Datenformaten, älteren Reviews und Tests bleiben als Rekonstruktionshilfe erhalten. Verweise auf Dart-Dateien, Tests, Screenshots und Belegverzeichnisse sind keine enthaltenen Quelldateien. |
| Startdateien | `Webvorschau-starten.cmd`, zwei Windows-Server-EXEs für AMD64 und ARM64, Build-Info | Der Windows-Vorschaustarter ist erhalten, wurde hier aber nicht ausgeführt. Die EXEs sind Vorschau-Server, keine native Flutter-Windows-App; ihr Go-Quelltext fehlt. |
| Projekt und native Builds | Kein `pubspec.yaml`, kein `pubspec.lock`, kein `lib/`, kein `test/`, keine Android-/Windows-Projektverzeichnisse und keine Git-Historie | Ein Flutter-Projekt dieses Stands kann damit nicht direkt geöffnet, analysiert oder neu gebaut werden. Keine native Android-App oder native Flutter-Windows-App wiederherstellbar. |
| Nutzerdaten | Keine Nutzer-Datenbank, kein Notizbuch-Backup, keine Datendateien mit Notizen oder eigenen Bildern enthalten | Persönliche Daten werden durch dieses Webpaket nicht wiederhergestellt. Browserdaten müssten aus dem ursprünglichen Browserprofil oder einer gesonderten Sicherung kommen. |
| Version 0.16.0+20 | Nicht enthalten bzw. nicht nachgewiesen | Änderungen nach 0.15.3+19 lassen sich aus diesem Paket nicht bestimmen oder vollständig wiederherstellen. |

Die 19 Tabellen im SQL-Text heißen: `devices`, `metadata`, `pupils`, `orga`, `orga_items`, `drafts`, `revisions`, `operations`, `outbox`, `preferences`, `legacy_backups`, `situations`, `situation_pupils`, `context_drafts`, `group_drafts`, `group_saves`, `school_records`, `school_drafts`, `pupil_drafts`.

## Source Maps und Quellenhinweise

- **Genau eine `.map`-Datei:** `build/web/drift_worker.js.map`, 376.944 Byte, Source-Map-Format 3, zu `drift_worker.js`.
- Sie enthält **160 Quellenverweise**: 79 auf das Dart-SDK, 80 auf Abhängigkeiten und einen auf `../tool/drift_worker.dart`.
- **Kein `sourcesContent`** und keine eingebetteten Dart-Quelltexte. Auch die Dart-spezifische Erweiterung enthält Namens-/Frame-Zuordnungen, keine Quelldateien. Die referenzierte Projektdatei fehlt.
- Teilweise rekonstruierbare Abhängigkeitsinformationen aus dieser Map: `async-2.13.1`, `collection-1.19.1`, `drift-2.35.3`, `path-1.9.1`, `sqlite3-3.8.0`, `stack_trace-1.12.2`, `stream_channel-2.1.4`, `typed_data-1.4.0`, `web-1.1.2`. Das ist kein vollständiger Abhängigkeitsstand der Hauptanwendung.
- `drift_worker.js.deps` enthält **683 Pfadzeilen**, darunter ursprüngliche Pfade zu `flutter_app/.dart_tool/package_config.json` und `flutter_app/tool/drift_worker.dart`. Es ist eine Abhängigkeitsliste, kein Quelltextarchiv.
- **`main.dart.js.map` fehlt.** Die Hauptanwendung hat auch keine eingebettete Source Map und keinen `sourceMappingURL`-Verweis.
- **`flutter.js.map` fehlt**, obwohl `flutter.js` und `flutter_bootstrap.js` darauf verweisen. Der fehlende Debug-Verweis liefert HTTP 404; die Loader-Dateien selbst sind vorhanden.
- Sechs `*.js.symbols`-Dateien gehören zur CanvasKit-/Skwasm-Laufzeit. Sie enthalten Funktionssymbole, keine Dart-Quellen der FLEX-App und keine Hauptanwendungs-Source-Map.

## Lokaler Start und tatsächlich ausgeführte Prüfungen

Die unveränderten Dateien aus `package/FLEX-Notizbuch-Webvorschau/build/web` werden mit dem neu angelegten Python-Standardbibliothek-Server `preview_server.py` ausgeliefert. Die Windows-EXEs wurden nicht ausgeführt. Flutter, Dart, Paketinstallation und ein Neubau waren hierfür nicht erforderlich.

- Aktuelle Serverbindung: **0.0.0.0:8080**, damit der Vorschau-Proxy den Server über die Containerschnittstelle erreichen kann. Beim ersten Start war nur Loopback gebunden; dies wurde nach der gemeldeten Nichterreichbarkeit in der Cloud-Vorschau korrigiert. `http://127.0.0.1:8080` auf dem eigenen Rechner führt weiterhin nicht automatisch zu diesem Server. Es wurde kein Deployment oder öffentlicher Tunnel eingerichtet.
- Der Server wurde nach der Bindungskorrektur neu gestartet. Die aktuelle PID steht in `preview-server.pid` und `preview-reachability.json`; die PID des ersten Starts war 947.
- Startbefehl bei gestopptem Server: `python3 -u /workspace/FLEX-Recovery/preview_server.py`.
- Startseite: HTTP 200, bytegleich zu `index.html`.
- Alle **47 Webdateien**: HTTP 200 und bytegleich zu den extrahierten Dateien.
- Alle sieben Wasm-Dateien: korrekter MIME-Typ `application/wasm`; SHA-256 stimmt jeweils mit `flutter_bootstrap.js` überein.
- Header: `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`, `Cache-Control: no-store`.
- CanvasKit ist im Bootstrap auf lokale Dateien eingestellt; die Schriftmanifeste referenzieren mitgelieferte Schriften einschließlich Roboto. Der kompilierte Flutter-Code enthält zusätzlich einen externen Font-Fallback. Vollständiger Offlinebetrieb für alle Zeichen ist ohne Browserprüfung nicht nachgewiesen.
- **Keine Browsertests**, keine visuelle Kontrolle, keine JavaScript-Ausführung im Browser, keine Prüfung von Browserpersistenz, Datenmigration oder nativen Plattformen. Ein erfolgreicher HTTP-Start beweist diese Eigenschaften nicht.
- Die in den Paketdokumenten genannten 319 Tests, Flutter-/Dart-Versionen und Renderings sind historische Angaben des Pakets. Sie wurden hier nicht wiederholt; die zugehörigen Testquellen und Prüfbelege fehlen.
- Keine Veröffentlichung, kein Deployment, kein Git-Push und keine Änderung der Umgebungskonfiguration.

Maschinenlesbare Nachweise: `manifest-verification.json`, `http-verification.json`, `recovery-inventory.json` und `preview-reachability.json`. Nach der Bindungskorrektur wurden Startseite, Version, Bootstrap, Hauptanwendung, Datenbank-Worker und SQLite-Wasm sowohl über Loopback als auch über die Containerschnittstelle erfolgreich per HTTP abgerufen und byteweise verglichen. Der vollständige Zugriff über die Vorschauansicht im Browser ist weiterhin nicht geprüft. Original und extrahiertes Paket wurden erneut als unverändert bestätigt.

## Zusätzlicher Fund außerhalb des Uploads

Bereits vor dieser Untersuchung lagen unter `/workspace/exports` zwei andere Archive:

- `FLEX-Notizbuch-Flutter-Quellen.zip`: 173 ZIP-Einträge, 14 Dart-Dateien; SHA-256 `8b7b79cbb212157d1cea02548341314bdc1a69269e05c7d78e71320e53a747d9`.
- `FLEX-Notizbuch-Flutter-Neue-Dateien.zip`: 28 ZIP-Einträge, 14 Dart-Dateien; SHA-256 `95bf88fe62d028a9d0aedeb7c3bfb6923752dfb93f68ea0fa3fc4d0f5d5d8034`.

Beide enthalten `FLEX-Notes/flutter_app/pubspec.yaml` mit **0.1.0+1**. Das ist ein zusätzlicher älterer Quellenfund, kein Bestandteil des geprüften Webpreview-Pakets und kein Nachweis für Quellen von 0.15.3+19 oder 0.16.0+20. Die Archive wurden nur gelesen, weder entpackt noch verändert; ihre Buildfähigkeit wurde nicht geprüft.

Für eine exakte Wiederherstellung des zuletzt genannten Arbeitsstands wird weiterhin ein Quellarchiv oder Git-Stand von **0.16.0+20** benötigt. Das Webpaket liefert eine erhaltene ausführbare Referenz des älteren Stands, das SQL-Schema und dokumentierte Anforderungen.
