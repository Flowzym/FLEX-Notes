# Orga, Übersicht und Eingaben

Stand: **0.16.0-rebuild.12+32**, 03.11.2026.

## Änderungen

- Sozial und Arbeit: horizontales Wischen auf der Positiv-/Negativ-Auswahl wechselt
  die aktive Seite. Auswahl und Texte bleiben erhalten. Vertikales Scrollen sowie
  Gesten, die im Textfeld beginnen, wechseln die Seite nicht.
- Orga bietet die Arten Notiz, Aufgabe und Termin. Termine besitzen ein Datum und
  optional eine Uhrzeit; ohne Uhrzeit gelten sie ganztägig. Der direkte Zugang ist
  in der Übersicht, in Klassen-Orga und im Orga-Bereich des Schülerdialogs erreichbar.
  Termine erscheinen bei „Anstehend“, solange ihr Zeitpunkt noch nicht vorbei ist.
  Ganztägige Termine bleiben bis zum Tagesende anstehend. Vergangene Termine bleiben
  in Orga und den zuletzt dokumentierten Einträgen auffindbar.
- Termine werden unabhängig von Aufgabenfälligkeit und Erinnerung gespeichert.
  Die zusätzlichen Felder liegen in der vorhandenen Orga-Metadatentabelle und in
  den JSON-Payloads von Entwürfen/Revisionen. Vollsicherung und Wiederherstellung
  erhalten sie; alte Payloads ohne Terminfelder bleiben lesbar. Kein SQL-Schemawechsel.
- Klassen-Orga, Schülerliste und Schülerdialog nutzen einklappende Suche. Beim
  Fokusverlust oder Abschicken wird das Feld zum Suchbutton. Ein gesetzter Filter
  wird am Button angezeigt und kann dort gelöscht werden. Kein zeitgesteuertes
  Schließen während der Eingabe; die Tastaturkorrektur bleibt erhalten.
- Alle Entwurfseditoren besitzen eine Löschaktion, sobald Änderungen oder ein
  gespeicherter Entwurf vorliegen. Nach Bestätigung wird der Editor geschlossen.
  Laufende Schreibvorgänge werden vor dem Löschen abgewartet, Debounce und weitere
  Eingaben während der Aktion gesperrt. Neuere Entwurfsrevisionen werden geschützt;
  Speicherfehler lassen Eingaben und Originaldatensatz erhalten.
- Übersicht: kompakte Bereichsauswahl mit Anzahlen, getrennte Listen für Anstehendes,
  Ergänzungen und zuletzt Dokumentiertes. Zunächst höchstens fünf kurze Zusammenfassungen;
  alle übrigen sind über „Alle … anzeigen“ erreichbar. Details und Bearbeiten liegen
  im Eintragsdialog. Die Desktopbreite ist auf eine lesbare Spalte begrenzt.

## Nachweise

**201 Flutter-Tests bestanden**, statische Analyse ohne Befunde und erfolgreicher
Android-Releasebuild. Die bestehenden Tastaturtests bleiben erfolgreich.

19 neue Tests prüfen Termine einschließlich Backup/fehlerhaftem Import, aktive und
vergangene Zeitpunkte, Wischgesten mit erhaltener Auswahl, Suchfilter bei Fokus- und
Tastaturwechsel, den Klassenterminzugang sowie das Löschen in sieben Editorbereichen.
Ein gesonderter Test hält Autospeicherung an, simuliert Eingabe während des Löschens,
einen Speicherfehler und eine inzwischen neuere Entwurfsrevision.

- [Gezielte Tests](evidence/orga-focused-tests.log)
- [Gesamter Flutter-Testlauf](evidence/orga-flutter-tests.log)
- [Statische Analyse](evidence/orga-analyze.log)
- [Android-Releasebuild](evidence/orga-apk-build.log)
- [APK-Verifikation](evidence/orga-apk-verification.json)
- [Quellprüfsummen](evidence/orga-source-sha256.txt)
- [Direkte Renderings](orga-overview-renderings/README.md)

APK: **64625536 Bytes**, SHA-256
`05c9d994a29d7588f513ff40cdec6ed6c9c8444d62dc66a14a524b6947324c83`.
Paketkennung, Versionscode 32, Start-Activity, native Bibliotheken und unveränderte
Testsignatur sowie ZIP-/ELF-Ausrichtung für 16-KB-Seiten wurden geprüft.

## Installation und Grenzen

Build 32 wird mit derselben Testsignatur und App-ID wie Build 31 ausgeliefert.
Über die vorhandene **FLEX Test** installieren; nicht deinstallieren.
Die App zeigt Erinnerungen weiterhin innerhalb der App; Orga-Termine richten keine
Systembenachrichtigungen oder externen Kalendereinträge ein.

Die Prüfungen laufen lokal mit der Flutter-Engine. Kein Android-Gerät angeschlossen,
keine Browsertests, kein neuer Webbuild und kein Store-Release. Große Systemschrift
bleibt unterstützt und benötigt auf schmalen Geräten mehr Scrollen.

[Android-Installation](../flutter_app/ANDROID-TEST.md) ·
[Vorheriger Kartenabgleich](SCHUELERKARTEN_ABGLEICH.md)
