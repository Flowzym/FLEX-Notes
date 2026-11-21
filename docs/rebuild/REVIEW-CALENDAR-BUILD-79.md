# Review-Ergänzungen und Kalender · Build 79

FLEX **0.29.0+79**, eine FLEX-Klasse, bisherige App-Kennung und permanentes
Signierzertifikat. Bestehende Daten werden beim Öffnen auf Schema 8 migriert.
Es werden dabei keine Schüler oder Einträge gelöscht. Neue Sicherungen benötigen
Build 79; Sicherungen aus älteren Versionen bleiben importierbar. Kein Downgrade
der bereits migrierten Installation.

## Kalender bedienen

- Wischen auf der oberen Tag/Woche/Monat-Auswahl läuft auch über die Enden in
  derselben Richtung weiter. Wischen im Kalender wechselt den Zeitraum.
- Einen zeitgebundenen Termin oder Unterrichtsblock lange drücken und ziehen:
  Zeit verschieben; in der Woche auch auf einen anderen Tag.
- Nach dem langen Drücken verändern die Griffe am Anfang und Ende die Dauer.
  Vorschau und Uhrzeiten folgen dem Finger, das Raster beträgt 15 Minuten.
  Am oberen/unteren Rand scrollt die Ansicht mit. Erst Loslassen speichert.
- „Rückgängig“ stellt die vorherige Zeit wieder her. Bei Unterricht wird nur
  diese einzelne Stunde geändert, nicht die gesamte wiederkehrende Reihe.
- Tages-/Wochenraster nutzen den Platz bis zur unteren Navigation; die Liste
  unter der Monatsansicht ist kompakter. Neue Termine weiterhin durch Antippen
  eines freien Zeitfelds anlegen.

## Ausgewählte Review-Punkte

| Bereich | Umsetzung / Zugang | Grenzen |
| --- | --- | --- |
| Begriffe | Versions-, Wiederherstellungs- und Unterrichtstexte vereinfacht | Historische Prüfberichte behalten ihre damaligen Formulierungen. |
| Schuljahresabschluss | Mehr → Daten → Schuljahr abschließen: Zeitraum, offene Aufgaben/Ziele behalten, verschlüsselte Vollsicherung, Archivierung; Wiederöffnen unter Archiv | Keine automatische Löschung; Schüler bleiben in der FLEX-Klasse. |
| Aufbewahrung | Mehr → Daten → Aufbewahrung & Löschprüfung: Fristen für Papierkorb/Importkopien, fällige Schuljahresarchive, gezielte Auswahl | Endgültiges Entfernen erst nach Sicherung, Bestätigung und „LÖSCHEN“. Offene Entwürfe blockieren das Entfernen ihrer Bezüge. |
| Pseudonymisierung | Gesprächsvorbereitung: Namen ersetzen, zusätzliche Namen ergänzen, Vorschau vor PDF-/Text-Export | Ersetzt bekannte Namen in diesem Bericht. Beliebiger Freitext kann identifizierend bleiben; eingebettete Dateien/Scans werden nicht automatisch anonymisiert. |
| Android-Schnellzugriff | Widget für Notizen, Kalender, Scan und HÜ sowie vier App-Shortcuts; Widget aus Einstellungen anheften | Zeigt keine Schülerdaten auf dem Homescreen. App-Sperre bleibt vorgeschaltet; Launcher-Gerätetest offen. |
| Benachrichtigungen | Erledigt für Orga-Aufgaben, Später um eine Stunde für unterstützte Erinnerungen | App wird für die geschützte Aktion geöffnet. Revision, geänderte Erinnerung und doppelte Zustellung werden geprüft. |
| Tablet/Foldable | Ab 1000 logischen Pixeln Schülerliste und Schülerdetails nebeneinander, alle fünf Erfassungsaktionen sichtbar | Bei sehr großer Schrift Rückfall auf die einspaltige Bedienung; kein spezielles Scharnier-Layout. |
| Diktat | Mikrofon an Beobachtungs-/Eintragstexten; lokale Erkennung, bearbeitbare Vorschau, ausdrückliches Einfügen | Android 12+ und vorhandener Offline-Sprachdienst erforderlich; keine Netzwerk-Erkennung als stiller Ersatz. |
| Eintragsvorlagen | Vorlagenaktion im Editor, Verwaltung in Einstellungen; Text/Tags/Checklisten/HÜ-Aufgaben übernehmen | Schüler, Termine, Erinnerungen, Anlagen und Verlauf werden nicht in Vorlagen kopiert. Freitext vor dem Speichern prüfen. |
| Kataloge | Separater JSON-Export/Import mit Vorschau, Zusammenführen oder Ersetzen | Enthält nur Katalogfelder, keine Schüler-/Eintragsdatensätze. Selbst eingetragene Namen im Katalog werden nicht automatisch entfernt. |
| Scanner | Eigene CameraX-Kamera mit Live-Umriss, Stabilitätsanzeige, optionaler automatischer Auslösung, Mehrfachaufnahme, Fokus, Zoom und Licht | Erkennung ist heuristisch. Manuell auslösen und korrigieren bleibt möglich; echte Kamera-/Lichtbedingungen noch nicht geprüft. |
| Unterbrochene Aufnahme | Verschlüsselte Zwischenablage je Entwurf; native Seiten erst nach erfolgreicher Flutter-Speicherung quittieren; große Kameraaufnahmen vor der Bitmap-Allokation verkleinern | Wiederaufnahme und doppelte Übergabe automatisiert geprüft, Prozessabbruch am Gerät offen. |
| Releaseprozess | R8/Resource Shrinking, Dart-Obfuskierung, v3-Signatur, private Debugsymbole, kein AGP-Abhängigkeitsblock; taggesteuerter Releaseentwurf | GitHub-Secret-Verwaltung lieferte 403. Signierter GitHub-Release-Lauf erst nach Secret-Einrichtung; siehe [RELEASING](RELEASING.md). |
| Fehlerdiagnose | Einstellungen → Fehlerbericht: lokale Vorschau, teilen, leeren; höchstens 100 Ereignisse/14 Tage | Keine Eintragstexte, Namen, URLs, Dateipfade oder unveränderten Exception-Texte. Kein automatisches Senden. |
| Datenmodell | FTS5 mit Aktualisierungstriggern, JSON-Indizes, Schülerzeitstempel/Papierkorb, Geräteattribute, erweiterbarer Protokollbereich | Unbekannte Protokolle werden beim Import abgewiesen. Noch keine automatische Gerätesynchronisierung; kein erfundenes Schlüsselmaterial. |

Der Scanner bindet ML Kit und Google Play Services nicht mehr ein. Die lokalen
Android-Daten bleiben mit SQLCipher beziehungsweise AES-GCM/Keystore geschützt.
Die Webvorschau verwendet weiterhin den vorhandenen Browserspeicher; diese
Android-Speicherverschlüsselung gilt dort nicht.

## Nachweise

Die automatisierten Prüfungen umfassen echte SQLite-Migration von Schema 7,
Altimport, FTS-Aktualisierung, Archivierung/Wiederöffnung, Löschtransaktionen mit
Rollback, Vorlagen/Katalogimport, Diktat-Abbruch, doppelte Benachrichtigungen,
Kalenderziehen/-skalieren/-abbrechen, Wochenwechsel sowie Tablet- und
Schmalbildschirm-Layouts. Bildbearbeitung/PDF und verschlüsselte Sicherungen
bleiben Bestandteil der vollständigen bestehenden Testsuite.

Prüfprotokolle und gerenderte Ansichten liegen unter
[`build-79/`](build-79/). Physische Android-Abnahme ist offen:
[Geräteprüfschritte](ANDROID-ACCEPTANCE-BUILD-79.md).

## Installation

[APKs](../../releases/android/build-79/README.md) aktualisieren die neue FLEX
Build 62–78. Vor dem Update eine unabhängige verschlüsselte Sicherung anlegen;
App nicht deinstallieren oder deren Daten löschen. Die ältere FLEX Test bleibt
eine separate Installation: [Umzug](ANDROID-UMZUG-62.md).
