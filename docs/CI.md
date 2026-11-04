# Automatische Prüfungen auf GitHub

Workflow: [FLEX CI](https://github.com/Flowzym/FLEX-Notes/actions/workflows/flutter-ci.yml).
Die Konfiguration liegt in [flutter-ci.yml](../.github/workflows/flutter-ci.yml),
die gemeinsame SDK-Einrichtung in [setup-flutter/action.yml](../.github/actions/setup-flutter/action.yml).

Die Pipeline startet bei Pushes und Pull Requests, die `flutter_app/` oder `.github/`
ändern. Der aktive Entwicklungsbranch ist `fix/dialog-reference-audit`;
`recovery/webpreview` bleibt die unveränderte historische Basis. Ein neuer Push
beendet einen noch laufenden älteren Prüflauf desselben Branches/PRs.

## Prüfungen

1. **Analysis and tests:** unveränderte Paketauflösung aus `pubspec.lock`, Dart-Formatierung,
   statische Analyse mit Fehlerstatus auch für Hinweise/Warnungen, SQLite-Vertragstests
   sowie sämtliche Flutter-Tests mit Testabdeckung. Dazu gehören Repository-,
   Sicherungs-, Konflikt-, Eingabe-, Swipe-, Dialog- und Layoutprüfungen.
2. **Android release build:** nach erfolgreichen Tests mit Java 21, Android SDK 36,
   Build Tools 36.0.0 und NDK 28.2.13676358. Der JVM-Speicher ist für kleine GitHub-Runner
   begrenzt. Auch fehlende, absichtlich nicht eingecheckte Gradle-Wrapperdateien werden
   vom Flutter-SDK neu angelegt.
3. **Web build and preview server:** SQLite-WASM-Prüfsumme, kompilierter Drift-Worker,
   Web-Releasebuild mit lokalen CanvasKit-Ressourcen und HTTP-Vertragstests des
   Vorschau-Servers. Diese Prüfungen öffnen keinen Browser.
4. **CI passed:** grün nur, wenn alle drei Prüfgruppen erfolgreich waren. Fehler,
   abgebrochene oder übersprungene Teilprüfungen ergeben keinen erfolgreichen Gesamtcheck.

Eine fehlgeschlagene Formatierung, Analyse oder Testausführung verhindert die Build-Jobs.
Shell-Pipelines verwenden `pipefail`; das Mitschreiben von Logs verdeckt deshalb keine Fehler.

## Ergebnisse ansehen

Unter **GitHub → Actions → FLEX CI** den Lauf für den gewünschten Commit öffnen.
Rot markierte Schritte enthalten die Fehlerausgabe. Testprotokoll, LCOV-Testabdeckung,
PDF-Testausgabe und Buildprotokolle werden, soweit erzeugt, für **14 Tage** als Artefakte
aufbewahrt – auch bei einem fehlgeschlagenen Prüfschritt.

Der Gesamtcheck `CI passed` kann später als erforderlicher Statuscheck in einer
Branch-Regel ausgewählt werden. Diese Einrichtung ändert keine Branch-Schutzregeln.
Der Workflow enthält zusätzlich `workflow_dispatch`; der manuelle Startknopf von GitHub
setzt voraus, dass die Workflow-Datei auch im jeweiligen Standardbranch vorhanden ist.

## Reproduzierbarkeit und Grenzen

- Flutter **3.47.9** wird aus dem offiziellen Git-Tag ausgecheckt und zusätzlich gegen
  Commit `c197ca5199e9ee5661e865596c9c07294dfab51c` geprüft. So hängt die Einrichtung nicht
  von einem derzeit nicht verfügbaren Stable-Tarball ab. Dart kommt aus diesem SDK.
- GitHub Actions sind auf vollständige Commit-Hashes festgelegt. SDK-Artefakte und
  Pakete werden nach SDK-Ziel und Lockfile gecacht. `pub get --enforce-lockfile`
  lehnt eine abweichende Auflösung oder geänderte Paket-Prüfsummen ab.
- Der Repository-Checkout lädt nur App und Workflow-Konfiguration; historische APKs
  und Wiederherstellungsarchive werden nicht mit heruntergeladen.
- Die Jobs benötigen nur lesenden Repository-Zugriff und keine eigenen Secrets.
  Es werden ausschließlich synthetische Testdaten verwendet.
- Der Android-Build verwendet den kurzlebigen Debugschlüssel des Runners. Er prüft
  die Release-Konfiguration, wird aber nicht als Update-APK veröffentlicht. Der
  Signaturschlüssel der installierten FLEX Test bleibt außerhalb von GitHub Actions.
- Die Pipeline ersetzt keine Android-Geräteprüfung von Biometrie, Doze,
  Benachrichtigungen oder Dokumentanbietern. Sie veröffentlicht keine App und
  greift nicht auf vorhandene Nutzerdaten zu.

## Lokal ausführen

Im Verzeichnis `flutter_app/` mit dem oben genannten Flutter-SDK:

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool/drift_worker.dart packages/flex_device/lib
flutter analyze --no-pub --fatal-infos --fatal-warnings
python3 -m unittest discover -s tool -p test_schema.py -v
flutter test --no-pub --coverage --reporter expanded
flutter build apk --release --no-pub
python3 tool/prepare.py --assets-only
dart compile js -O2 tool/drift_worker.dart -o web/drift_worker.js
flutter build web --release --no-pub --no-web-resources-cdn
python3 -m unittest discover -s tool -p test_preview_server.py -v
```

Android benötigt die genannten Java-/Android-Werkzeuge; die Vorschau-Servertests
benötigen Go (CI: **1.27.3**). `FLEX_TEST_ARTIFACT_DIR` ist optional und bestimmt,
wo der PDF-Test seine Beispielausgabe ablegt. Ohne diese Variable hinterlässt er
keine Datei und benötigt kein bestimmtes Arbeitsverzeichnis.
