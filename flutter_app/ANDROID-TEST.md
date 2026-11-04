# FLEX Test für Android

Installierbare Flutter-App auf Basis von **0.16.0-rebuild.16+36**. Der aktuelle
Funktionsumfang entspricht dem Wiederaufbau einschließlich Swipe-Navigation,
Darstellungsreglern und Orga-/HÜ-Symbolen.

Orga behält Datum, Uhrzeit, Fälligkeit und Erledigt-Status beim Hin- und
Zurückwechseln des Eintragstyps, auch über gesicherte Entwürfe und Neustarts.
Der Konfliktdialog zeigt abweichende Termindaten und Uhrzeiten beider Fassungen.
Alle bisherigen Bedienungs- und Designanpassungen bleiben enthalten.
Die Korrektur für den Fokusverlust beim Öffnen der Tastatur bleibt enthalten.
App-ID und Testsignatur bleiben gleich; die neue APK kann über die vorhandene
**FLEX Test** installiert werden. Eine Deinstallation ist nicht erforderlich.

## Installation

[APK Build 35 auf GitHub herunterladen](../releases/android/build-36/README.md).

1. Die bereitgestellte `FLEX-Test-…-universal.apk` auf das Android-Gerät laden.
2. Die APK in Downloads öffnen. Falls Android danach fragt, für den verwendeten
   Browser bzw. Dateimanager „Unbekannte Apps installieren“ erlauben.
3. Installieren und **FLEX Test** öffnen.

Android **7.0 oder neuer**; die Universal-APK enthält ARM64, ARMv7 und x86_64.
Es sind weder Flutter noch ein lokaler Webserver auf dem Gerät nötig.
Die Test-App hat die eigene Kennung `at.flowzym.flex_notizbuch.test` und einen
eigenen lokalen Datenbestand. Sie startet leer und übernimmt keine Browserdaten.
Eigene kompatible FLEX-Sicherungen lassen sich über die Sicherungsfunktion importieren.

Sicherungsexport, Textausgabe und Entwurfsrettung verwenden den Android-Dialog
„Speichern unter“. Der gewählte Dokumentanbieter erhält die Datei; eine allgemeine
Speicherberechtigung ist nicht nötig. Ein Abbruch wird nicht als Erfolg gemeldet.

Für spätere Updates muss derselbe Test-Signaturschlüssel verwendet werden.
Die bereitgestellte APK ist für die manuelle Installation test-signiert, nicht für
den Play Store. Eine Deinstallation entfernt die lokalen App-Daten; zum Übertragen
oder Sichern zuerst die Exportfunktion verwenden.

## Nachbauen

Verwendete Werkzeuge: Flutter 3.47.9 / Dart 3.13.7, JDK 21, Android SDK 36,
Build Tools 36.0.0, NDK 28.2.13676358. Gradle wird über den Wrapper bereitgestellt.

```sh
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Ausgabe: `build/app/outputs/flutter-apk/app-release.apk`.
Release-Modus verwendet derzeit bewusst die lokale Android-Debugsignatur für die
Test-App. Den Keystore für nachfolgende Testupdates behalten, nicht ins Repository
oder in ein öffentliches Quellenpaket aufnehmen. Ein Store-Release braucht eine
eigene Veröffentlichungs- und Signaturkonfiguration.

[Orga-/Übersichtsupdate und Prüfungen](../audit/ORGA_UEBERSICHT_ABGLEICH.md) ·
[Schülerkarten-Update und Prüfungen](../audit/SCHUELERKARTEN_ABGLEICH.md) ·
[Tastaturkorrektur und Prüfungen](../audit/ANDROID_TASTATUR_FIX.md) ·
[Erster Android-Build](../audit/ANDROID_TESTAPP.md)
