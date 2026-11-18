# FLEX für Android · 0.35.0+86

Die Android-Ausgabe verwendet die App-Kennung `at.flowzym.flex_notizbuch`. Build 86 ist für ARM64-Geräte signiert und aktualisiert dort bestehende FLEX-Installationen mit derselben Signatur. Die Webvorschau verwendet denselben Flutter-Quellstand. Vor der Installation eine vollständige verschlüsselte Sicherung außerhalb der App speichern.

Die frühere „FLEX Test“ hat die eigene Kennung `at.flowzym.flex_notizbuch.test`. Für Daten aus dieser App gilt die [Umzugsanleitung](../docs/rebuild/ANDROID-UMZUG-62.md).

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
FLEX_SIGNING_PROPERTIES=/privater/ordner/signing.properties flutter build apk \
  --release --no-pub --split-per-abi --target-platform android-arm64 \
  --obfuscate --split-debug-info=/privater/ordner/symbole/build-86
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

## Abnahme auf einem Schulhandy

Für den Durchlauf eine Testperson und Beispieldateien verwenden. Persönliche Daten bleiben in der produktiven Installation.

| Bereich | Ablauf und erwartetes Ergebnis |
| --- | --- |
| Installation | Das passende Paket über die vorhandene FLEX installieren. Die bisherige Testzuordnung eines Materials ist nach dem ersten Öffnen vorhanden. |
| OneDrive | Mit dem Schulkonto anmelden, zu FLEX zurückkehren und zwei Dateien über die Ordnersuche wählen. Dateien einem Schüler mit Unterrichtsdatum zuordnen. Nach Neustart und im Flugmodus die heruntergeladene Kopie öffnen. |
| Kamera | Erstmals Kamerazugriff erlauben. Kariertes Heft, reflektierendes Arbeitsblatt und Blatt auf dunklem Tisch aufnehmen. Vorschaukontur mit dem Zuschnitt vergleichen, eine Seite wiederholen und eine Serie unterbrechen. Nach der Rückkehr Anzahl und Reihenfolge prüfen. Die Dokumentkamera erkennt Ränder lokal mit CameraX. |
| Schwärzung | Ein erfundenes Wort schwärzen, die fertige Vorschau vergrößern und die tatsächlich geteilte PDF auf einem anderen Gerät öffnen. |
| Benachrichtigung | Testaufgabe in zwei Minuten erinnern lassen und das Handy sperren. FLEX danach öffnen. Die zugestellte Meldung bleibt verfügbar. „Später“ verschiebt sie, „Erledigt“ beendet sie. Mit der schulüblichen Akkuspareinstellung wiederholen. |
| Homescreen und Bedienung | FLEX über das Widget nach einem Kaltstart öffnen. Mit TalkBack und großer Schrift eine HÜ kontrollieren, den Kalender mit Wochenende eine Woche vorwärts wischen und wieder zum heutigen Tag springen. |
| Schuljahr | Einen Testeintrag mit Scan archivieren. Vollständige Sicherung in einem leeren Testprofil wiederherstellen. Archiv, Seitenvorschau, Zuordnung und Daten nach Wiederöffnung prüfen. |

Native Android-JVM-Tests und simulierte Microsoft-Antworten decken Teile dieser Abläufe ab. Kameratrefferquote, gerätespezifische Energiesparregeln und der Anmeldedialog des Schulkontos werden auf dem tatsächlichen Gerät beurteilt.
