# Android Build 62 · dauerhafte Signatur und getrennter Umzug

Stand: 12. November 2026. App-Version **0.19.1+62**.

Der ursprüngliche private Testschlüssel ist weiterhin nicht verfügbar.
Deshalb erhält die neue FLEX eine eigene App-Kennung und einen dauerhaft
beizubehaltenden Schlüssel. FLEX Test wird weder ersetzt noch gelöscht.
Es gibt keine Änderung am SQL-Schema oder an den fachlichen Datenmodellen.

| Eigenschaft | Wert |
| --- | --- |
| Neuer App-Name | FLEX |
| Neue App-Kennung | `at.flowzym.flex_notizbuch` |
| Alte Test-App | `at.flowzym.flex_notizbuch.test` |
| Debug-App | `at.flowzym.flex_notizbuch.dev` / FLEX Dev |
| Neues Zertifikat SHA-256 | `9e50d1e2393e2bf867fc33b11e50383fd066f7b2df5026fd1f2a1d2790fdcd79` |
| APK SHA-256 | `e1ddb5f85866da3756476e1446b02cff66d8e48a479935fb687b47aa8bb6c445` |
| APK-Größe | 102494352 Bytes |
| Architekturen | ARM64, ARMv7, x86_64 |

## Schutz des Updatewegs

Release-Builds benötigen eine externe Properties-Datei mit dem privaten Schlüssel.
Vor dem Signieren wird das Zertifikat gegen den eingecheckten Fingerabdruck
geprüft. Fehlender oder falscher Schlüssel stoppt den Build. Die explizite
CI-Option baut ohne Signatur; CI prüft zusätzlich, dass ihr Ergebnis unsigniert
bleibt. Der private Keystore und die Zugangsdaten sind von Git ausgeschlossen.
Im Repository liegt nur das öffentliche Zertifikat.

Eine private Wiederherstellungs-ZIP mit Keystore, Zugangsdaten und Anleitung
wurde außerhalb des Repositorys vorbereitet. Eine lokale Kopie allein ist keine
dauerhafte externe Sicherung; die private Ablage und eine zusätzliche Offlinekopie
müssen gesichert sein. Die ZIP enthält Klartext-Zugangsdaten und darf nicht als
öffentlicher Release-Anhang veröffentlicht werden.

## Lokale Prüfung

- Android-Release und Web-Release erfolgreich gebaut.
- APK-Signatur und erwarteter Zertifikatfingerabdruck bestätigt.
- App-ID, Name und Version aus dem fertigen APK geprüft; eigener Dateiprovider,
  keine gemeinsame Benutzerkennung und keine alte Test-App-Kennung im Manifest.
- ZIP-Integrität, ZIP-16-KB-Ausrichtung und 16-KB-Ausrichtung der 64-Bit-ELF-Segmente
  geprüft; keine privaten Signierdateien oder Zugangsdaten im APK.
- Vier Gradle-Prüfungen: fehlender Schlüssel abgewiesen, falscher Schlüssel
  abgewiesen, ausdrücklich unsignierte CI-Konfiguration erfolgreich,
  Debug-Konfiguration ohne privaten Schlüssel erfolgreich.
- 30 Tests aus `backup_codec_test`, `backup_merge_test`, `consolidation_test` und
  `material_services_test` bestanden: alte Sicherungen, Verschlüsselung,
  Zusammenführen, vollständige Sicherung/Wiederherstellung und Materialdateien.

Die letzte vollständige Prüfung des unveränderten fachlichen Dart-Codes für
Build 61 umfasste 511 Flutter-Tests, Analyse/Formatierung, 11 Schema- und drei
Servertests. [Build-61-Nachweise](QUALITY-BUILD-61.md).

## Grenzen und Auslieferung

Eine echte Android-Installation sowie Kamera, System-Teilen, Biometrie,
Benachrichtigungen und der persönliche Datenumzug sind noch nicht auf Hardware
abgenommen. Die direkte OneDrive-Anmeldung benötigt weiterhin eine eigene
Microsoft-Appregistrierung. Neue Vollsicherungen benötigen Build 61 oder neuer.

[Signierte APK und Prüfberichte](../../releases/android/build-62/README.md) ·
[Umzugsanleitung](ANDROID-UMZUG-62.md) ·
[Build- und Wiederherstellungsanleitung](../../flutter_app/ANDROID-TEST.md) ·
[Bestehende private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
