# Signierte Android-Releases

FLEX verwendet weiterhin das permanente Zertifikat aus
`flutter_app/android/release-certificate.sha256`. Ein anderer Schlüssel wird vom
Gradle-Build abgewiesen. Für APKs bleiben v1/v2 für ältere Geräte aktiv; v3 ist
zusätzlich verpflichtend. R8/Resource Shrinking und Dart-Obfuskierung sind aktiv.
Der AGP-Abhängigkeitsblock wird nicht in APK/AAB übernommen. Laufzeitbibliotheken
und ihre Lizenzangaben bleiben erhalten.

Die APKs enthalten keine DWARF-Debugsektionen; die privaten Dart-/R8-Symbole
werden getrennt verwahrt. Eine von Flutter erzeugte Pluginregistrierungs-URI
(`.dart_tool/flutter_build/dart_plugin_registrant.dart`) bleibt trotz
Obfuskierung als Laufzeitkonstante mit dem Buildpfad erhalten. Die Obfuskierung
ist daher kein Nachweis, dass sämtliche Compiler-Metadaten entfernt sind.
Diese bekannte SDK-Grenze wird nicht durch nachträgliches Patchen der APK umgangen.

## Tag und Pipeline

Ein Release-Tag muss exakt `vVERSION+BUILD` aus `flutter_app/pubspec.yaml` heißen,
beispielsweise `v0.29.0+79`. Der Workflow
[android-release.yml](../../.github/workflows/android-release.yml) führt zuerst die
vollständige CI aus und baut danach zwei signierte APKs aus genau diesem Tag.
Er überprüft Paketname, Version, Zertifikat, APK-v3-Signatur, ZIP-Integrität,
16-KB-ZIP-Ausrichtung und die SQLCipher-Bibliothek. Er erzeugt einen **Releaseentwurf**
mit APKs, SHA-256-Prüfsummen, Commit-Zuordnung und verschlüsselten Debugsymbolen.

Die normalen Branch-/PR-Builds erhalten keine Signierschlüssel und bleiben
unsigniert. Der Release-Workflow läuft ausschließlich bei einem gepushten
Release-Tag, nicht bei Pull Requests.

## Einmalige Einrichtung auf GitHub

Unter Repository → Settings → Secrets and variables → Actions benötigt der
Workflow diese Repository-Secrets:

- `FLEX_RELEASE_KEYSTORE`: Base64 des bestehenden permanenten Keystores.
- `FLEX_RELEASE_STORE_PASSWORD`: dessen Speicherpasswort.
- `FLEX_RELEASE_KEY_PASSWORD`: dessen Schlüsselpasswort.
- `FLEX_RELEASE_KEY_ALIAS`: vorhandener Schlüsselalias.
- `FLEX_SYMBOLS_PASSWORD`: eigenes starkes Passwort für das verschlüsselte
  Symbolarchiv; getrennt und dauerhaft sichern.

Die Dateien werden nur im temporären Runner-Verzeichnis mit Modus 0600 erzeugt
und auch bei Fehlschlägen entfernt. Keine Secrets in Git, APKs, Befehlsargumente,
Debugsymbole oder Releasebeschreibungen kopieren. Zugriff auf Release-Tags sollte
in den GitHub-Rulesets auf die zuständigen Maintainer beschränkt sein.

**Stand Build 79:** Der Workflow ist implementiert. Die Secret-Verwaltung war aus
dieser Arbeitsumgebung nicht erreichbar (`403 Forbidden`); die Einrichtung und
ein vollständiger signierter GitHub-Release-Lauf sind daher noch nicht bestätigt.
Lokale signierte Builds verwenden weiterhin den vorhandenen privaten Schlüssel.
Es wurde kein unkonfigurierter Release-Tag veröffentlicht.

## Lokaler Build desselben Tags

Der private Signierpfad und das Symbolverzeichnis liegen außerhalb des Repos:

```bash
cd flutter_app
python3 tool/android_release.py check-tag --tag 'v0.29.0+79'
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos --fatal-warnings
flutter test --concurrency=2
FLEX_SIGNING_PROPERTIES=/private/flex/signing.properties \
  flutter build apk --release --no-pub --split-per-abi \
  --target-platform android-arm,android-arm64 --obfuscate \
  --split-debug-info=/private/flex/symbols/v0.29.0+79
python3 tool/android_release.py verify --out /private/flex/releases/v0.29.0+79
```

Die CI-Werkzeugversionen stehen in `.github/actions/setup-flutter` und den
Workflows. Paket-Lockfile, Gradle-Wrapper und dauerhaftes Zertifikat gehören zur
Build-Zuordnung. Signierte Binärdateien sind nicht als bitidentisch reproduzierbar
zugesichert.

## Fehler mit Debugsymbolen untersuchen

Dart-Dateien `app.android-*.symbols` und die R8-Datei `mapping.txt` immer dem
konkreten Commit/Build zuordnen. Sie sind kein öffentliches Releasezubehör im
Klartext. Das GitHub-Archiv wird mit GPG/AES256 verschlüsselt; nur lokal in einem
privaten Verzeichnis entschlüsseln. Dart-Stacktraces lassen sich anschließend mit
`flutter symbolize -i stacktrace.txt -d app.android-arm64.symbols` lesen.

Der datensparsame In-App-Fehlerbericht speichert bewusst keine unbereinigten
Stacktraces oder Eintragstexte. In obfuskierten Builds können deshalb weniger
Quellpositionen verfügbar sein; bekannte Fehlergruppen bleiben erkennbar.
