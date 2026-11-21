# Android-Bau und Auslieferung · 0.19.0+61

Stand: 12. November 2026. Anwendungscode:
`969820806b31e1f9220727f9a9a29e23d2baee27`.

## Vorhandene Prüfung

[FLEX CI #45](https://github.com/Flowzym/FLEX-Notes/actions/runs/43091734629)
hat Analyse/Tests, Webbuild/Servertests und Android-Releasebuild erfolgreich
abgeschlossen. Die 511 Flutter-Tests sind im
[Funktions- und Prüfbericht](QUALITY-BUILD-61.md) dokumentiert.

Die [Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site)
verwendet denselben Anwendungscode. Der erneut erzeugte Release-Webbuild enthält
dieselbe `main.dart.js` wie die veröffentlichte Fassung; die bestehende Adresse
und die gespeicherten Browserdaten bleiben erhalten.

## Erneuter lokaler Bau

- Release-Webbuild erfolgreich; zusätzlich als ZIP archiviert.
- Android-Release erfolgreich als `FLEX-Test-0.19.0+61-unsigned.apk` gebaut
  (102.486.160 Bytes). **Nicht installierbar, noch nicht zur Verteilung als Update.**
- App-ID, Versionsnummer 61, ZIP-Integrität und enthaltene ARM64-, ARMv7- und
  x86_64-Bibliotheken geprüft. ZIP-Ausrichtung und die 64-Bit-ELF-Ladeabschnitte
  erfüllen die 16-KB-Ausrichtung.
- `apksigner` bestätigt, dass keine Signatur vorliegt. Es wurde kein neuer
  Signierschlüssel eingesetzt.

Der lokale Bau verwendet Flutter 3.47.9, Temurin JDK 21.0.13, Android SDK 36,
Build Tools 36.0.0 und NDK 28.2.13676358. Die Build-Werkzeuge liegen außerhalb
des Quellrepositories. SHA-256 und Protokolle stehen im unten verlinkten Nachweis.

## Signatur für ein kompatibles Update

Die zuletzt bereitgestellte APK ist Build 56, App-ID
`at.flowzym.flex_notizbuch.test`, Anzeigename `FLEX Test`.
Ihr dokumentiertes Zertifikat hat SHA-256:

```text
de26d14a7212166d71f48e7eec46fe30ab474c5d48f08c1eef64fb4a176da443
```

Der damalige Build verwendete einen lokalen Android-Debug-Keystore. Seine private
Schlüsseldatei ist in der aktuellen Arbeitsumgebung, den vorhandenen Quell-ZIPs
und der Git-Historie nicht vorhanden. Die OneDrive-Suche nach `keystore` und
`.jks` sowie die Dateiliste am Ablageort der letzten APK lieferten keinen Schlüssel.
Das APK-Zertifikat enthält den öffentlichen Schlüssel; daraus lässt sich der
private Schlüssel nicht wiederherstellen.

Deshalb wird keine anders signierte APK als kompatibles Update angeboten. Die
bestehende App braucht nicht deinstalliert zu werden. Die aktuelle Vorbereitung
verändert weder ihre App-ID noch ihre lokalen Daten.

## Reproduzierbare Vorbereitung

`flexUnsignedRelease=true` entfernt ausdrücklich die Signierung des Release-
Builds. Ohne diese Eigenschaft bleibt der bisherige CI-/Entwicklungsbau unverändert.
Keystores und lokale Signaturkonfiguration sind in Git ausgeschlossen.

```sh
ORG_GRADLE_PROJECT_flexUnsignedRelease=true flutter build apk --release --no-pub
```

Ein solches APK ist ein technisches Zwischenprodukt und **nicht installierbar**.
Sobald der ursprüngliche Keystore wieder verfügbar ist, kann das geprüfte APK
mit Androids `apksigner` signiert werden. Passwörter gehören in eine geschützte
lokale Umgebung, nicht in Git, Buildprotokolle oder den Chat. Vor der Ausgabe
müssen Zertifikat und Paketkennung mit Build 56 übereinstimmen. Die Verteilung
als installierbares Update bleibt bis dahin offen.

Die lokalen Ergebnisse dieses Bauvorgangs werden unter
[`android-build-61/verification.json`](android-build-61/verification.json)
festgehalten.
