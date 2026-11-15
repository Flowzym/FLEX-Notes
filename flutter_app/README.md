# FLEX – bearbeitbares Flutter-Projekt

Aktuell: **0.32.0+83**, Branch `redesign/cream-olive`.
[Materialverwaltung und Prüfungen](../docs/rebuild/MATERIAL-BUILD-83.md) ·
[Projektstatus](../docs/rebuild/STATUS.md) ·
[Android-APKs](../releases/android/build-83/README.md) ·
[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).

Die App verwendet Flutter-Widgets und direkt gezeichnete Symbole; sie bettet den
HTML-Prototyp nicht ein. Sie entwickelt die wiedergefundenen Rekonstruktionsquellen
weiter. Historische Quellen und Prüfungen bleiben im Repository erhalten.
Nutzerdaten liegen im jeweiligen Browser bzw. Gerät. Android schützt die Datenbank
mit SQLCipher und Materialdateien mit AES-GCM/Keystore; Webspeicher erhält dadurch
keine zusätzliche Geräteverschlüsselung. Automatisierte Tests ersetzen keine
[physische Android-Abnahme](../docs/rebuild/ANDROID-ACCEPTANCE-BUILD-79.md).

## Neue Funktionen einrichten

- **Einstellungen → Daten:** automatische Sicherungen mit Ordner, Passwort, Intervall
  und Aufbewahrung; letzte erfolgreiche Sicherung und Wiederherstellung.
- **Einstellungen → Bedienung:** Android-Erinnerungen sowie App-PIN/optionale Biometrie.
- **Sicherung importieren:** in bestehenden Arbeitsbereichen mit Vorschau zusammenführen.
  Gleichnamige Schüler zuordnen und Unterschiede pro Feld auswählen; lokale Werte sind vorausgewählt.
- **Gespräch vorbereiten:** Zeitraum/Bereiche/Einträge auswählen, zusammenstellen und als PDF sichern.

Automatische Sicherungen, OS-Erinnerungen und App-Sperre werden auf Android angeboten.
Die Zugangssperre und die Android-Speicherverschlüsselung sind getrennte Schutzmaßnahmen.
Gerätespezifische Geheimnisse und Berechtigungen sind nicht Bestandteil exportierter Sicherungen.

Android bietet außerdem „Teilen → FLEX“ für PDF, DOCX und Bilder mit Vorschau und
Schüler-/Unterrichtszuordnung. [OneDrive-Einrichtung](../docs/rebuild/ONEDRIVE-SETUP.md).

## Automatische Prüfungen

Bei Änderungen an App oder Workflows führt [FLEX CI](../docs/CI.md) Formatprüfung,
Analyse, Flutter-/SQLite-Tests sowie Android- und Web-Builds auf GitHub aus.
Testabdeckung und Protokolle sind als Actions-Artefakte verfügbar.

## Start

Verwendete Werkzeuge: Flutter **3.47.9**, Dart **3.13.7**. Flutter und das
mitgelieferte Dart müssen im PATH liegen; zusätzlich wird Python 3 benötigt.
Die aufgelösten Abhängigkeiten sind in `pubspec.lock` festgehalten.

```sh
python3 tool/prepare.py
flutter analyze --no-pub
flutter test
flutter build web --no-web-resources-cdn
python3 tool/serve_preview.py --port 8081
```

Unter Windows kann `py` statt `python3` verwendet werden. Wenn der Server auf
dem eigenen Computer läuft, im dortigen Browser `http://127.0.0.1:8081` öffnen.
In einer Cloud-Umgebung bindet `--bind 0.0.0.0` den Server an deren Netzwerkschnittstellen.
Das erzeugt jedoch keinen externen Vorschau-Link und keine Portweiterleitung.
Der eingebettete Chat-Browser konnte den Cloud-Server unter `127.0.0.1:8081`
nicht erreichen. Eine Portauswahl in dieser Oberfläche ist nicht belegt.
Das Python-Skript öffnet selbst keinen Browser und veröffentlicht keine Cloud-Umgebung.

## Windows-Vorschau ohne Flutter-Installation

Das gesonderte Windows-Vorschau-ZIP enthält den gebauten Flutter-Webstand und
kleine Serverprogramme für x64 und ARM64:

1. Das komplette ZIP auf dem Windows-PC in einen neuen Ordner entpacken.
2. `Webvorschau-starten.cmd` doppelklicken.
3. Der Standardbrowser wird geöffnet; das Serverfenster bleibt offen.
   Falls erforderlich, dort `http://127.0.0.1:8081/` selbst aufrufen.

Flutter, Python und Go müssen beim Empfänger nicht installiert sein. Der Server
bindet ausschließlich `127.0.0.1`; es gibt keine Veröffentlichung und keinen Tunnel.
Eine vorhandene Anwendung auf Port 8081 führt zu einer Fehlermeldung und wird
nicht beendet. Browserprofil und Adresse bestimmen den lokalen Datenstand.

Das Paket im Repository-Checkout erzeugen (Go erforderlich; vorhandener Web-Build):

```sh
python3 tool/test_preview_server.py
python3 tool/package_preview.py --output /gewünschter/ausgabeordner
```

`GO_BINARY` wählt für den Test den Go-Compiler; das Paketwerkzeug akzeptiert
`--go /pfad/zu/go`. Der Starterquelltext liegt in `tool/preview_server.go` und
zusätzlich im Vorschau-ZIP. Geprüft sind ein Linux-Lauf ohne Browser und die
Windows-Kompilierung. Windows-Ausführung und Browserpersistenz sind ungetestet;
die Server-EXEs sind nicht signiert. Sie sind keine native Flutter-Windows-App.

## Entwicklung und native Plattformen

Alternativ für die Entwicklung:

```sh
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081
```

Windows- und Android-Runnerquellen sind enthalten. Die [Android-App](ANDROID-TEST.md)
wird als **FLEX** mit dauerhafter Signatur gebaut; die ursprüngliche FLEX Test bleibt
separat. Zum Releasebau die dort dokumentierte externe Signierkonfiguration verwenden.
Zum nativen Entwicklungsstart sind die jeweiligen Plattformwerkzeuge erforderlich
(`flutter doctor`, danach `flutter run -d windows` oder `flutter run -d <Android-Gerät>`).
Kein nativer Windows-Build und keine Tests auf Android-/Windows-Geräten.

## Daten und Versionsgrenzen

- Neue Arbeitsbereiche starten leer. Tests verwenden synthetische Daten.
- Der Webspeicher verwendet weiterhin `flex_notizbuch_rebuild_v1`. Android migriert
  die lokale Datenbank in die verschlüsselte Geräteablage. Speicher historischer
  Webpreview-Installationen wird nicht automatisch geöffnet oder verändert.
- Die DDL entspricht dem erhaltenen SQL-Schema 7. Die zusätzlichen Fach-Payloads
  sind mit `rebuildFormat: 1` ausdrücklich als Rekonstruktion gekennzeichnet.
- Eine echte SQLite-Datei des erhaltenen Schemas 1 kann nach Schema 7 migriert
  werden. Unbekannte Zwischenversionen werden vor Änderungen abgewiesen.
- Der innere Notizbuchstand heißt `FLEX-Flutter-Rebuild-Backup`, Version 1, Schema 7.
  Originale Flutter-0.1-Sicherungen sind importierbar. Kompatibilität mit den
  fehlenden neueren Flutter-Quellen bzw. ihren Payloads ist nicht nachgewiesen.
- Neue vollständige Sicherungen verwenden das blockweise verarbeitete binäre Format
  `FLEXBACKUP3` / `.flexbackup` mit PBKDF2-SHA256 und AES-256-GCM; Build 78 oder neuer
  ist zum Öffnen erforderlich. Alte JSON-/FLEX-Encrypted-Sicherungen bleiben lesbar.
  Containerkompatibilität bedeutet nicht automatisch kompatible innere Daten.
- HTML-Sicherungen werden unverändert vorgemerkt, nicht automatisch als aktive Daten
  übernommen. Browser-Downloads und ältere JSON-Importe können weiterhin viel Speicher
  benötigen. Grenzen und Vergleichsmessungen stehen im aktuellen Prüfbericht.

## Quellenpakete

```sh
python3 tool/package_sources.py --output /gewünschter/ausgabeordner
```

Im Git-Checkout exportiert das Skript den aktuellen **Commit** als vollständiges Repository-
Quellenpaket und als separates Flutter-Quellenpaket, jeweils mit SHA-256-Datei.
Uncommittete Änderungen, SDK, Caches und Build-Ausgaben werden nicht eingepackt.

Aktueller Umfang und Prüfstand: `../docs/rebuild/STATUS.md`; im separaten
Flutter-Quellen-ZIP zusätzlich `RESTORATION-STATUS.md`. Das Paket kann ohne Git
vorbereitet, getestet und gebaut werden; erneutes Exportieren erfordert einen
Git-Checkout. Historische
README-/Architekturdokumente von 0.1.0 sind unter `../reference/flutter-0.1.0/`
erhalten; sie beschreiben nicht den aktuellen Implementierungsstand.
