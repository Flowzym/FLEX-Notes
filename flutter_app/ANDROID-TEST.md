# FLEX für Android · Build 65

**0.21.1+65** ist als signierte Universal-APK verfügbar:
[APK und Prüfnachweise](../releases/android/build-65/README.md).

Die neue **FLEX** hat die App-Kennung `at.flowzym.flex_notizbuch` und wird neben
**FLEX Test** (`at.flowzym.flex_notizbuch.test`) installiert. Die alte Installation
und ihr Speicher bleiben erhalten. Ein direktes Update der alten Test-App ist
ohne deren ursprünglichen privaten Signierschlüssel nicht möglich.

**Vor dem Wechsel die [Umzugsanleitung](../docs/rebuild/ANDROID-UMZUG-62.md)
befolgen.** Eine Installation überträgt keine Daten automatisch. Die alte App
erst nach geprüftem Import und zusätzlicher Sicherung entfernen.

Build 65 kann direkt über die neue FLEX aus Build 62–64 installiert werden.
App-Kennung, Signatur und lokaler Speicher bleiben dabei erhalten.
[Kompaktere Eintragungsseiten und Prüfbericht](../docs/rebuild/SPACING-BUILD-65.md).

## Dauerhafte Signatur

Der öffentliche Signaturfingerabdruck lautet:

```text
9e50d1e2393e2bf867fc33b11e50383fd066f7b2df5026fd1f2a1d2790fdcd79
```

`android/release-certificate.pem` enthält ausschließlich das öffentliche
Zertifikat. `android/release-certificate.sha256` bindet Release-Builds an diesen
Schlüssel. Es gibt keinen automatischen Rückfall auf eine Debug-Signatur.
Künftige Updates müssen diese App-Kennung und Signatur sowie eine höhere
Buildnummer verwenden.

Der private PKCS12-Keystore und seine Zugangsdaten gehören **nicht ins Repository**.
Die vorbereitete private Wiederherstellungs-ZIP enthält beides. Die ZIP ist nicht
selbst verschlüsselt und muss vertraulich sowie zusätzlich außerhalb der
Buildumgebung aufbewahrt werden. Ihr Ablageort ist kein öffentlicher Download.
Den Schlüssel bei einem Umgebungswechsel wiederherstellen, niemals neu erzeugen.

## Release bauen

Flutter-Version und Abhängigkeiten stehen in der CI-Konfiguration und im Lockfile.
Java 21 und das Android SDK werden benötigt. Nach `flutter pub get`:

```sh
FLEX_SIGNING_PROPERTIES=/privater/ordner/signing.properties flutter build apk --release
```

Die Properties-Datei enthält `storeFile`, `storePassword`, `keyAlias` und
`keyPassword`. Ein relativer `storeFile`-Pfad wird relativ zu dieser Datei
aufgelöst. Der Build prüft den Zertifikatfingerabdruck vor dem Signieren.
Passwörter nicht als Kommandoargumente oder im Buildprotokoll ausgeben.

Für reine Kompilierprüfungen ohne privaten Schlüssel:

```sh
ORG_GRADLE_PROJECT_flexUnsignedRelease=true flutter build apk --release
```

Dieses CI-Ergebnis bleibt unsigniert und ist kein Installationsdownload.
Debug-Builds verwenden die getrennte Kennung `at.flowzym.flex_notizbuch.dev`
und heißen **FLEX Dev**.

## Geprüft und noch offen

Signatur, App-Kennung, Version, ZIP-Integrität, unterstützte Architekturen und
16-KB-Ausrichtung sind geprüft. Das Zertifikat stimmt mit Build 62–64 überein.
21 gezielte UI-/Editorprüfungen bestanden; statische Analyse ohne Befunde.
Der Release-Webbuild wurde zusätzlich im Smartphone-Browser mit Testdaten geprüft.
Die vollständige Testsuite wurde zuletzt für Build 64 ausgeführt; für diese
reine Abstandsanpassung wurden die betroffenen UI- und Editorprüfungen wiederholt.

Installation, Kamera, Biometrie und Erinnerungen auf einem echten Handy sowie
der Umzug des persönlichen Datenbestands sind noch nicht abgenommen.
[Nachweise](../docs/rebuild/SPACING-BUILD-65.md).

Die [ältere Build-61-Dokumentation](../docs/rebuild/ANDROID-BUILD-61.md)
beschreibt den vorherigen Stand ohne verfügbaren Test-Signierschlüssel.
