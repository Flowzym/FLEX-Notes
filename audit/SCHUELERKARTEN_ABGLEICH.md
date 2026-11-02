# Schülerkarten, Schülerdialog und Entwürfe

Stand: **0.16.0-rebuild.11+31**, 02.11.2026.

## Änderungen

- Alle Entwurfslisten bieten eine Löschaktion mit Bestätigung. Abbrechen erhält den
  Entwurf; Fehler lassen sich erneut versuchen. Doppeltippen löst nur einen Vorgang aus.
  Die vorhandenen Revisionsprüfungen verhindern das Löschen inzwischen geänderter
  Entwürfe. Veröffentlichte Einträge bleiben erhalten.
- Der Kopf des Schülerdialogs öffnet die Entwürfe aller Bereiche dieses Schülers,
  einschließlich Gruppenerfassungen und Schülerbearbeitung. Andere Schüler bleiben
  außerhalb dieser Liste. Entwürfe im Eintragsmodal bleiben ebenfalls direkt zugänglich.
- Der Schülerdialog zeigt sechs kompakte Bereiche mit Symbol und Beschriftung.
  Suche und Offen-Filter gelten für die gemeinsame Liste aus Fach- und Orga-Einträgen.
  Das Plus legt einen Eintrag an. Bearbeiten, Gesprächsvorbereitung und Archivieren
  stehen im Kopfmenü, Verlauf und Entwürfe daneben. Bei wenig Platz stehen Name und
  Kopfaktionen in getrennten Zeilen.
- Schülerkarten: Symbole von 24 auf 32 logische Pixel, Symbol und Text jeweils mittig,
  Zahlenbadges oberhalb der Symbole ohne Überlagerung, Kopf-Mindesthöhe von 52 auf 44.
- Die Seitennavigation ist höher und etwas breiter. Sozial-/Arbeitstags verwenden
  kleinere Schrift und Abstände. Buttonbeschriftungen sind auch bei Umbruch zentriert.
- Der Tastatur-Fix aus Build 30 bleibt enthalten; das Datenbankschema ist unverändert.

## Nachweise

**182 Flutter-Tests erfolgreich**, darunter 11 gezielte neue Tests. Statische Analyse
ohne Befunde und Android-Releasebuild erfolgreich. Die bestehenden 11 Tests für
Fokus, Tastaturverbindung und Texteingabe bleiben erfolgreich.

Gezielte Tests decken Löschbestätigung, Abbruch, Fehler/Wiederholung, Mehrfachtippen,
Schülerzuordnung, gemeinsame Suche/Filter sowie die Karten- und Dialoggeometrie ab.
Die Render-Matrix verwendet 320, 390 und 1200 Pixel Breite, zusätzlich 200 % Systemschrift
und 120 % App-Skalierung. Die Tests erzeugen 20 direkte Flutter-PNGs ohne Browser.

- [Gezielte Tests](evidence/pupil-focused-tests.log)
- [Vollständiger Flutter-Testlauf](evidence/pupil-flutter-tests.log)
- [Statische Analyse](evidence/pupil-analyze.log)
- [Android-Releasebuild](evidence/pupil-apk-build.log)
- [APK-Prüfergebnis](evidence/pupil-apk-verification.json)
- [Quellprüfsummen](evidence/pupil-source-sha256.txt)
- [Renderings und Sichtprüfung](pupil-polish-renderings/README.md)

APK: **64.461.584 Bytes**, SHA-256
`1f8a3305e650a64d3468d0134c351853d4843a138465856c14c43d2c92a08fe1`.
Paketkennung, Versionscode 31, Start-Activity, Release-Modus, native Bibliotheken,
Signatur und ZIP-/ELF-Ausrichtung für 16-KB-Seiten wurden geprüft. Der Signaturfingerabdruck
stimmt mit der vorherigen Testapp überein.

## Installation und Grenzen

Build 31 ist ein Update für **FLEX Test** mit derselben App-ID und Testsignatur wie
Build 30. Über die vorhandene App installieren; eine Deinstallation ist nicht nötig.
Android 7.0 oder neuer, Universal-APK für ARM64, ARMv7 und x86_64.

Die Prüfungen ersetzen keinen Test auf einem Android-Gerät. Hier war kein Gerät
angeschlossen; der reale Tastaturlauf bleibt auf dem Nutzergerät zu prüfen.
Keine Browsertests, kein neuer Webbuild und kein Store-Release.

[Android-Installation](../flutter_app/ANDROID-TEST.md) ·
[Tastaturkorrektur](ANDROID_TASTATUR_FIX.md)
