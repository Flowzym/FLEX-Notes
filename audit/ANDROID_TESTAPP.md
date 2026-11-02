# Android-Testapp

Historischer erster APK-Build. Das nachfolgende Update behebt den
[Fokusverlust beim Öffnen der Tastatur](ANDROID_TASTATUR_FIX.md).

Stand: **0.16.0-rebuild.9+29**, 02.11.2026. Android-Ausgabe des aktuellen
Flutter-Wiederaufbaus; keine Aussage über Originaltreue oder Store-Freigabe.

## Android-Anpassungen

- App-Name **FLEX Test**, getrennte App-ID `at.flowzym.flex_notizbuch.test`.
  Vorhandene andere App-Installationen und Browserdaten bleiben getrennt.
- Universal-APK im Release-Modus, mit lokaler Testsignatur. Mindestversion Android
  7.0 / API 24; Ziel-SDK 36. Enthält ARM64, ARMv7 und x86_64.
- Der vorhandene `file_selector` unterstützt unter Android keine Auswahl eines
  Speicherziels. `saveTextFile` verwendet dort deshalb einen MethodChannel zum
  Android Storage Access Framework (`ACTION_CREATE_DOCUMENT`). Damit funktionieren
  Sicherungsexport, Textausgabe und Entwurfsrettung über denselben zentralen Pfad.
- Dateiinhalt wird als UTF-8 übergeben und nach der Zielauswahl in einem Hintergrundthread
  geschrieben. Erst ein vollständig geschlossener Stream meldet Erfolg. Abbruch,
  fehlendes Ziel, Schreibfehler und eine bereits laufende Auswahl werden behandelt.
  Kein Zugriff auf beliebige Speicherpfade und keine zusätzliche Speicherberechtigung.
- Web- und Desktop-Speicherpfade sowie Datenbankschema bleiben unverändert.

## Prüfungen

**160 Flutter-Tests bestanden**, statische Analyse ohne Befunde, Android-Releasebuild
erfolgreich. Die Abschlussnachweise liegen unter `evidence/android-*`:

- [Gesamttest](evidence/android-flutter-tests.log), [Analyse](evidence/android-analyze.log).
- [APK-Build](evidence/android-apk-build.log), [Quellprüfsummen](evidence/android-source-sha256.txt).
- [Signatur](evidence/android-signature.log), [Paketmetadaten](evidence/android-badging.log),
  [struktureller APK-Nachweis](evidence/android-apk-verification.json).

Die drei neuen Dart-Tests
prüfen die Kanalargumente samt Unicode/MIME-Typ, Abbruch ohne Erfolg und Fehlerweitergabe
mit anschließendem Wiederholungsversuch. Sie ersetzen keine Android-Dateianbietertests.

Die fertige APK wurde mit Android Build Tools geprüft: richtige Paketkennung,
Mindestversion, Architekturen und gültige v2-Signatur. Start-Activity und native
Speicherbrücke sind in den DEX-Dateien vorhanden; Flutter-, App- und SQLite-Bibliotheken
sind für alle drei Architekturen enthalten. ZIP-Ausrichtung und alle ELF-LOAD-Segmente
unterstützen 16-KB-Seiten. Das sind Strukturprüfungen, kein Nachweis eines Gerätelaufs.
Größe **64.346.968 Bytes**, SHA-256
`c9383ff0c842be8bd72ab5b3624f6d288ac39799a5016960cf0e612b510994e6`.
Die bereitgestellte Ausgabe enthält zusätzlich Prüfsumme und Buildmanifest mit Quellencommit.

Für den ersten Build wurden Android SDK/NDK und ein vollständiges JDK eingerichtet.
Der erste Versuch mit der vorhandenen reinen Java-Laufzeit scheiterte vor der Kompilierung
am fehlenden Java-Compiler. Der abschließende Build verwendet Temurin JDK 21.0.9.
Eine Meldung über nicht verfügbare Android-Buildtelemetrie betrifft nur die Buildumgebung.

## Grenzen

Kein angeschlossenes Android-Gerät und kein Emulatorlauf. Installation, Systemtastatur,
Dateianbieter, Start und Persistenz nach einem Android-Prozessneustart müssen daher
noch auf einem Gerät geprüft werden. Keine Browsertests. Die vorhandenen fachlichen
und visuellen Grenzen der Rekonstruktion gelten weiter.

[Installations- und Bauanleitung](../flutter_app/ANDROID-TEST.md) ·
[Vorheriger UI-Prüfbericht](SWIPE_DESIGN_ABGLEICH.md)
