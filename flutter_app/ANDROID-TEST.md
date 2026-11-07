# FLEX Test für Android

Installierbare Flutter-App auf Basis von **0.16.0-rebuild.27+47**. Der aktuelle
Funktionsumfang entspricht dem Wiederaufbau einschließlich Swipe-Navigation,
Darstellungsreglern und Orga-/HÜ-Symbolen.

Build 47 ergänzt lokale Kantenerkennung, einrastende Zuschnittpunkte, Livefilter
mit Vorschaubildern, Mehrfachaufnahmen, Bildersetzung und Drag-and-drop-Reihung.
Unter **Mehr → Scanner** lassen sich Scans, Fotos und Entwürfe verwalten.
[Bedienung und Prüfung](../audit/SCANNER_AUSBAU_BUILD_47.md).

Build 46 ergänzt direkte Scannerzugänge bei Einträgen und je HÜ-Aufgabe/Teilaufgabe,
mit sichtbaren Anhängen und stabiler Zuordnung.
[Bedienung und Prüfung](../audit/SCANNER_ZUGAENGE_BUILD_46.md).

Build 45 ergänzt die untere Bereichsnavigation, kontextabhängige obere Pillen,
normale Kameraaufnahmen, Fotobearbeitung, JPG-Speicherung und Tags.
[Bedienung und Prüfung](../audit/NAVIGATION_FOTOS_BUILD_45.md).

Build 44 ergänzt den Dokumentenscanner mit automatischer Zuordnung, mehrseitiger PDF,
Zuschnitt, Filtern und echter Schwärzung. Entwürfe können fortgesetzt und gelöscht werden.
Bilder und PDFs lassen sich auch in der Webvorschau importieren und bearbeiten.
[Bedienung, Sicherung und Grenzen](../audit/DOKUMENTENSCANNER_BUILD_44.md).

Build 43 fasst die Hauptnavigation auch am Handy in einer gemeinsamen Pille zusammen.
Ausgewählte Beobachtungen im Textfeld sind dunkelgrün, dunkelblau oder dunkelrot.
Kalender und Stundenplan zeigen am heutigen Tag eine waagrechte Linie mit Uhrzeit,
die auch über laufenden Blöcken sichtbar bleibt und sich minütlich aktualisiert.
[Bedienung und Prüfungen](../audit/NAVIGATION_FARBEN_ZEIT_BUILD_43.md).

Build 42 zeigt **Kalender** und **Stundenplan** als eigene Unterseiten. Der Stundenplan
hat dieselbe Tages- und Wochen-Zeitachse wie der Kalender. Datum, Ansicht und
Scrollposition bleiben pro Unterseite erhalten.
[Bedienung und Prüfungen](../audit/KALENDER_UNTERSEITEN_BUILD_42.md).

Build 41 ergänzte den bearbeitbaren PDF-Stundenplan ab 9. November 2026. Flexk-Blöcke
bleiben zusammen; Fach, Wochentag, Stundenumfang, individuelle Uhrzeiten, Lehrkraft und
Raum lassen sich ändern. Zugang: **Kalender → Stundenplan**.
[Bedienung und Prüfungen](../audit/STUNDENPLAN_BUILD_41.md).

Build 40 ordnete den Kalender neu: Tagesachse, echtes Wochenraster, ruhige Monatsansicht,
separate Fälligkeiten und sichtbare Zugänge zu Anlegen, Unterlagen und Verwaltung.
Dateien und Planungen einzelner Stunden bleiben beim Verschieben und Absagen erhalten.
[Funktionsumfang und Prüfungen](../audit/KALENDER_BUILD_40.md).

Build 39 ergänzte kompakte Materialzeilen, Tagesvorbereitung, Unterrichtspakete,
Schülerunterlagen, Planungsverwaltung und eine DOCX-Textvorschau.
[Funktionsumfang und Grenzen](../audit/MATERIALIEN_BUILD_39.md).

Build 38 ergänzte Kalender/Stundenplan, Materialablage, Rückläufe, Orga-Serien und
Entwicklungsübersichten für die FLEX-Klasse. Direkte OneDrive-Anmeldung wartet noch auf
die [Microsoft-Appregistrierung](../docs/ONEDRIVE_EINRICHTEN.md).
[Funktionsumfang und Grenzen](../audit/KLASSENFUNKTIONEN_BUILD_38.md).

Build 37 ergänzte automatische verschlüsselte Sicherungen, Android-Benachrichtigungen,
Sicherungsimporte mit Feldentscheidungen, PDF-Gesprächsvorbereitung und eine PIN-/Biometriesperre.
Alle bisherigen Bedienungs- und Tastaturkorrekturen bleiben enthalten.
App-ID und Testsignatur bleiben gleich; die neue APK kann über die vorhandene
**FLEX Test** installiert werden. Eine Deinstallation ist nicht erforderlich.

## Installation

[APK Build 47 auf GitHub herunterladen](../releases/android/build-47/README.md).

1. Die bereitgestellte `FLEX-Test-…-universal.apk` auf das Android-Gerät laden.
2. Die APK in Downloads öffnen. Falls Android danach fragt, für den verwendeten
   Browser bzw. Dateimanager „Unbekannte Apps installieren“ erlauben.
3. Installieren und **FLEX Test** öffnen.

Android **7.0 oder neuer**; die Universal-APK enthält ARM64, ARMv7 und x86_64.
Es sind weder Flutter noch ein lokaler Webserver auf dem Gerät nötig.
Die Test-App hat die eigene Kennung `at.flowzym.flex_notizbuch.test` und einen
eigenen lokalen Datenbestand. Sie übernimmt keine Browserdaten. Der Stundenplan der FLEX-Klasse wird einmalig
angelegt, sofern noch keine Unterrichtsserien existieren. Vorhandene Stundenpläne
werden nicht überschrieben; die PDF-Vorlage lässt sich dann ausdrücklich übernehmen.
Eigene kompatible FLEX-Sicherungen lassen sich über die Sicherungsfunktion importieren.

Sicherungsexport, Textausgabe und Entwurfsrettung verwenden den Android-Dialog
„Speichern unter“. Der gewählte Dokumentanbieter erhält die Datei; eine allgemeine
Speicherberechtigung ist nicht nötig. Ein Abbruch wird nicht als Erfolg gemeldet.

Für spätere Updates muss derselbe Test-Signaturschlüssel verwendet werden.
Die bereitgestellte APK ist für die manuelle Installation test-signiert, nicht für
den Play Store. Eine Deinstallation entfernt die lokalen App-Daten; zum Übertragen
oder Sichern zuerst die Exportfunktion verwenden.

## Einrichtung und Geräteprüfung

Unter **Einstellungen → Daten → Automatische Sicherungen** einen dauerhaft erreichbaren
Ordner wählen, ein Sicherungspasswort mit mindestens zwölf Zeichen vergeben und die erste
Sicherung abwarten. Passwort getrennt aufbewahren; auf einem neuen Gerät wird es benötigt.
Täglich/wöchentlich und 7/14/30 Dateien sind wählbar. Geprüfte Sicherungen sind über
**Sicherungen öffnen** erreichbar; nach einem Gerätewechsel über **Sicherung importieren**.
Auf Android können Energiesparen, ein Offline-Dokumentanbieter oder ein erzwungener App-Stopp
Hintergrundarbeiten verzögern/verhindern. Letzter Erfolg und Fehler werden angezeigt.

Unter **Einstellungen → Bedienung** Benachrichtigungen erlauben und die gewünschten
Erinnerungsarten wählen. Zeitgenaue Alarme erfordern eine zusätzliche Android-Freigabe;
sonst verwendet die App Androids ungefähre Zustellung. Die OS-Benachrichtigung enthält
keine Schülernamen oder Notizen. Antippen öffnet nach einer gegebenenfalls nötigen
Entsperrung den Eintrag. Abgeschlossene/gelöschte Einträge werden aus dem Plan entfernt.

Die App-Sperre benötigt eine PIN mit 6–12 Ziffern; Biometrie ist optional und muss am
Gerät eingerichtet sein. Die Sperre schützt den Zugang und die Android-Vorschau,
verschlüsselt aber nicht die SQLite-Datenbank. PIN und Sicherungspasswort sind getrennt.
Android-Systembackups/-Geräteübertragungen sind für diese App deaktiviert; für einen
Gerätewechsel die ausdrücklich exportierte FLEX-Sicherung verwenden.

Noch am echten Gerät abzunehmen: Update über Build 38 mit vorhandenen Daten, Ordnerzugriff
nach App-Ende/Neustart, Benachrichtigungen nach Prozessende/Neustart, Verhalten bei Doze,
Biometrie/Abbruch und Speichern/Öffnen einer PDF-Datei. Automatisierte Tests und ein
Releasebuild ersetzen diese hardware- und herstellerspezifischen Prüfungen nicht.

[Funktionsumfang und technische Nachweise](../audit/GERAETEFUNKTIONEN_BUILD_37.md).

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
