> Historischer Zwischenstand vor dem nachgereichten Quellen-ZIP. Die damalige Quellblockade ist aufgehoben. Maßgeblich ist [FLUTTER_ABGLEICH.md](FLUTTER_ABGLEICH.md).

# Flutter-Abgleich: belegte Abweichungen und offene Umsetzung

**Die angeforderte Korrektur des aktuellen Flutter-Stands ist blockiert: dessen Dart-Quellen und Tests fehlen.** Dieses Dokument ist ein konkreter Quellvergleich mit dem verfügbaren Stand 0.1.0+1 und ein getrennt gekennzeichneter Abgleich der historischen Dokumentation von 0.15.3+19. Es behauptet weder aktuelle Flutter-Tests noch korrigierten Anwendungscode.

## Welcher Bestand tatsächlich vorliegt

Repository `https://github.com/Flowzym/FLEX-Notes`, abgerufener Commit `8a97a94`, Standardbranch laut Repository-Metadaten `recovery/webpreview`. Lokal liegt die Untersuchung auf `fix/dialog-reference-audit`. Der Commit enthält eine Wiederherstellungssicherung, keinen aktuellen Flutter-Arbeitsbaum.

| Bestand | Nachgewiesen | Verwendbarkeit |
| --- | --- | --- |
| Hochgeladenes HTML (37) und Spezifikation | Unveränderte Referenzkopien, Hashmanifest | Maßgebliche Original-/Änderungsquelle |
| Flutter-Quellarchive 0.1.0+1 | 14 Dart-Dateien, `pubspec.yaml`, zwei Testdateien, Schema 1 | Quellvergleich möglich; vier Fachbereiche noch Platzhalter |
| Webpreview 0.15.3+19 | Kompiliertes `main.dart.js`, Assets, Schema 7, 18 Markdown-Berichte | Historische Inhalte/Abhängigkeiten untersuchbar; kein aktuelles Dart-Projekt |
| Flutter 0.16.0+20 | Nur in vorhandener Wiederherstellungsdokumentation genannt | Keine Quellen, keine Tests, kein Build nachgewiesen |

Die alten Quellen wurden unter `reference/flutter-0.1.0+1/` **unverändert** zur Einsicht entpackt. Sie werden nicht als aktuelle App ausgegeben. Im Webpreview fehlen `lib/`, `test/`, `pubspec.yaml`, `pubspec.lock` und eine Source Map mit den FLEX-App-Quelltexten. Minifiziertes JavaScript ist kein verlustfrei korrigierbares Flutter-Projekt. Die frühere Angabe „319 Tests / 74 Renderings“ gehört zum beigelegten historischen Bericht und wurde in dieser Arbeit nicht reproduziert.

Der Nutzer hat während der Arbeit bestätigt, dass der aktuelle bearbeitbare Stand nicht mehr existiert. Die Korrektur dieses verlorenen Stands kann deshalb nicht ausgeführt werden. Eine Rekonstruktion auf Basis der alten Quellen wurde als abweichender Arbeitsumfang zur Klärung gestellt. Ein Neuaufbau der gesamten App auf Basis 0.1.0+1 wäre eine eigene Rekonstruktion mit Datenmodellarbeit, keine Korrektur des erwähnten aktuellen Stands.

## Dialogweiser Abgleich mit den tatsächlich verfügbaren Dart-Dateien

Abkürzung `ui/` = `reference/flutter-0.1.0+1/lib/ui/`. Die Referenzanforderungen stehen im [Dialogverzeichnis](DIALOGVERZEICHNIS.md); die Nummern D01–D22 sind identisch.

| Dialog / Ansicht | Im Quellstand 0.1.0+1 tatsächlich vorhanden | Konkrete Abweichung / notwendige Korrektur | Status aktueller Code |
| --- | --- | --- | --- |
| D01 Schülerübersicht | `_entries` in `ui/notebook_screen.dart` als Hauptseiteninhalt | Kein schwebender Schülerdialog; Material-Hauptnavigation/Chip-Zugänge statt Referenzrahmen | Quelle fehlt |
| D01 Sozialverhalten | Platzhalter-Scaffold, `notebook_screen.dart:99` | Keine Formularfelder, Tag-/Freitextverbindung, optionalen Angaben, Datum oder Fachspeicherung | Quelle fehlt |
| D01 Arbeitsverhalten | Derselbe Platzhalter | Kein separater Auftrag, Originalkatalog, Favoriten, Tagdaten oder Beobachtungsmodell | Quelle fehlt |
| D01 Orga | `OrgaEditor`, vollständige Seite via `MaterialPageRoute`, `notebook_screen.dart:29` | Modalrahmen fehlt; eigener Titel + Notiz + separater Checklistenbereich statt gemeinsamer Originaleingabe; Reihenfolge, Beschriftungen und Fuß weichen ab | Quelle fehlt |
| D01 Ziele: Liste/neu | Platzhalter | Ziel, Kriterium, Schritt, Zieltermin, Stand/Prüfungen fehlen vollständig | Quelle fehlt |
| D01 HÜ: Liste/neu/Notiz | Platzhalter | Aufgaben/Teilaufgaben, Mehrfachempfänger, vier direkte Stände, Kommentarshortcut, Abgabe/Verlauf fehlen vollständig | Quelle fehlt |
| D01 Verlauf | Nur Orga-Änderungsdialog `_history` | Technisches Vorher/Nachher-JSON statt fachlichem Verlauf mit Bereich, Datum, Suche und Einzelbearbeitung | Quelle fehlt |
| D02 Schüler hinzufügen | `_pupilEditor`, Material-AlertDialog, `notebook_screen.dart:43` | Titel `Schüler anlegen`, Aktion `Speichern` statt Hinzufügen; vier statt zehn Farben; kein eigener Farbpicker; kein dauerhafter Schülerentwurf | Quelle fehlt |
| D03 Schüler verwalten | Derselbe Dialog plus separate Archivaktion | `Schüler bearbeiten` statt Verwalten; Archivieren speichert außerhalb des Editors sofort; Name/Farbe/Archiv nicht gemeinsam; Entwurfsschutz fehlt | Quelle fehlt |
| D04 Auswahl bearbeiten | Nicht implementiert | Katalogtexte, zwei Listen, unabhängige Sterne/Änderungen, Schutz vor Fehlpersistenz fehlen | Quelle fehlt |
| D05 Eintrag bearbeiten | Nur OrgaEditor | Vier andere Fachmodelle/Bearbeitungsvarianten fehlen; Orga hat abweichende Felder, Datum/Nachbereitung und Aktionen | Quelle fehlt |
| D06 Für mehrere erfassen | Nicht implementiert | Empfänger, gemeinsamer Kontext, individuelle Texte/Bewertungen und atomare Gruppe fehlen | Quelle fehlt |
| D07 HÜ bearbeiten | Nicht implementiert | Stabile Aufgaben-IDs, Teilaufgabenverhalten, Termine und Erhalt der Rückmeldungen fehlen | Quelle fehlt |
| D08 Aufgabenkommentar | Nicht implementiert | Kommentar-only-Modus, Fokus, Aufgabenbindung, Entwurfmodus und Konfliktbehandlung fehlen | Quelle fehlt |
| D09 Ziel überprüfen | Nicht implementiert | Drei Entscheidungen, bedingter nächster Prüftermin, Belege und Historie fehlen | Quelle fehlt |
| D10 Gemeinsame Situation | Nicht implementiert | Separater gemeinsamer Text, Beteiligte und Einzelbeobachtungszugänge fehlen | Quelle fehlt |
| D11 Gesicherte Entwürfe | `_drafts`, nur Orga; Hauptseitenliste | Keine übrigen Editortypen und keine typ-/modusgerechte Fortsetzung; kein eigener Modalrahmen | Quelle fehlt |
| D12 Entwurf nicht gesichert | Orga-Fehler im offenen Editor; `_close` blockiert | Originaler Warnungsdialog mit Weiterbearbeiten/Export/Verwerfen fehlt; Fehlerblockade vorhanden, jedoch keine UI-Parität | Quelle fehlt |
| D13 Gespräch vorbereiten | Nicht implementiert | Zeitraum, Einzelauswahl, Namensoption, Vorschau und TXT-Ausgabe fehlen | Quelle fehlt |
| D14 Kalender | `showDatePicker`, danach `showTimePicker`, `orga_editor.dart:85` | Zwei getrennte Material-Dialoge; keine gemeinsame Datum/Zeit-Auswahl; Beobachtungsdatum fehlt im Orga-Modell/UI | Quelle fehlt |
| D15 Datensicherung | `settings.dart:24`, AlertDialog `Flutter-Vollsicherung` | JSON kopieren statt Originaldateiablauf; feste 700×400-Inhaltsbox; kein gemeinsamer kleiner Rahmen oder Schutzoption | Quelle fehlt |
| D16 Passwort | Nicht implementiert | Verschlüsselungs-/Öffnungsdialog fehlt | Quelle fehlt |
| D17 Sicherung prüfen | `_import`, Textfeld für JSON; Flutter-Restore / HTML vormerken | Kein Datei-/Passwortablauf oder Original-Importreview; HTML-Migration ausdrücklich ausstehend. Nicht durch UI-only-Änderung als fertig ausgeben | Quelle fehlt |
| D18 Speicherpflege/Leeren | Nicht implementiert | Vorschau/Backup/Bestätigung/Bereinigungsablauf fehlen | Quelle fehlt |
| D19 Papierkorb | Nicht implementiert | Reversible Löschung/Wiederherstellung fehlen; Archiv ist kein Papierkorb | Quelle fehlt |
| D20 Änderungskonflikte | Repository weist veraltete Orga-Revision ab | Kein Feldvergleich/Alternativen-Dialog; allgemeiner Fehler ersetzt keine explizite Übernahme | Quelle fehlt |
| D21 Klassen-Orga Liste | `_aux == 'class'`, Seiteninhalt | Klassenkontext korrekt ohne Schülerpflicht, aber kein Modal und abweichende Filtertexte | Quelle fehlt |
| D22 Klassen-Orga Editor | `OrgaEditor` mit `pupilId == null` | Keine künstliche Schülerpflicht; ansonsten abweichende Vollbild-/Titel-/Listen-/Erinnerungsbedienung wie Schüler-Orga | Quelle fehlt |
| Zusätzlicher Flutter-Dialog | `_drafts`: `Entwurf verwerfen?`, `Behalten`, `Verwerfen` | Material-AlertDialog; im HTML kein gleiches zusätzliches benanntes Element. Bei Beibehaltung in gemeinsamen Rahmen integrieren | Quelle fehlt |
| Einstellungen/Farb-/Bildwahl | Vier Akzentfarben, Schriftgrößen, kompakt, hell/dunkel/System | Gemeinsame Leistenfarbe, getrennte Transparenzen, Farbpicker, Hintergrundbilder und Bildmodi fehlen | Quelle fehlt |

## Besonders relevante Befunde am alten Code

1. **Aufgabentermin wird beim Ausschalten sofort gelöscht:** `orga_editor.dart:109`, `_entry.copyWith(... dueDate: value ? _entry.dueDate : null)`. Das unterscheidet sich von der HTML-Entwurfslogik und von der späteren Vorgabe, reine Sichtbarkeitsschalter ohne Datenverlust zu verwenden. Ein Fix muss zwischen Aufgabenaktivierung, Sichtbarkeit, Entwurf und gespeichertem Modell unterscheiden.
2. **Speichern & weiter fehlt:** im alten Orga-Fuß stehen `Als Entwurf schließen` und `Speichern`. Der aktuelle Auftrag fordert Commit vor dem Wechsel zum nächsten aktiven Schüler und neuen Eintragszustand. Ohne neues Fachmodell nicht als erledigt markieren.
3. **Schüler-Schließen verliert ungespeicherten Text:** `Navigator.pop` im AlertDialog, kein Schülerentwurfsrepository. Nur Orga hat Autosave/PopScope. Ein allgemeines „alle Entwürfe geschützt“ wäre falsch.
4. **Tastatur-/Großschriftgrenzen nicht nachgewiesen:** Orga-Fuß außerhalb der ListView; Sicherung feste Höhe, Schüler/Import Column ohne responsiven gemeinsamen Dialog. Ein Überlauf ist aus dem Code plausibel, wurde hier aber mangels Flutter-Laufzeit nicht als reproduzierter Renderfehler ausgegeben.
5. **Fachlich richtige vorhandene Grundlage:** Aufgabenabschluss, Wiederöffnen und Quittierung sind im Orga-Modell getrennt. `pupilId == null` unterstützt Klasse. Fehler im Orga-Schließpfad verhindern Schließen. Diese Eigenschaften bei einer späteren Korrektur erhalten.

## Historische Dokumentation: Konflikte und späteres Soll

Die 18 Dokumente wurden nach Version/Bezug ausgewertet. Ihre Testzahlen sind historische Behauptungen, keine aktuelle Abnahme.

| Thema | Historischer Bericht | Aktueller Auftrag / Originalbeleg |
| --- | --- | --- |
| Mobile Detaildialoge | 0.5/0.13 beschreibt Vollfläche/Vollhöhe für Ziele, HÜ, Kontext | Spätere Spezifikation verlangt erkennbare Modals mit Rand auch mobil; alte Angabe ist überholt |
| HÜ-Checkbox und `Kommentar & Stand` | 0.6 beschreibt Checkbox plus gemeinsames Feedbackformular | Spätere Spezifikation ersetzt Checkbox durch direkte vier Stände und eigenen Kommentar-Modus |
| Einzelne Empfänger | Früher Checkbox/Schalter | Später Tagbuttons, gleiche tatsächliche IDs und Mehrfachauswahl erhalten |
| Optionale Inhalte | Früher „Weitere Angaben“, Quelle als Details | 0.15.3 und Nutzerspezifikation: keine zusätzliche Überschrift/Trennlinie, Schalter „Kontext / Quelle“, Werte beim Einklappen behalten |
| Datum | Frühere Einzelpicker; HTML-Endfassung bereits ein Zeitkalender | 0.15.3 beschreibt integriertes Hinzufügen/Entfernen und gemeinsame Übernahme; lokal neu prüfen |
| Gesprächsvorschau | 0.13-Tabelle erwähnt „geschützte Textbearbeitung“ | Eigener Gesprächsbericht und HTML belegen nicht editierbare Vorschau; keine erfundene Protokollbearbeitung |
| Auswahllisten | 0.5 beschreibt Umordnen/dauerhaften Katalogentwurf | HTML-Editor bietet Text, Entfernen, Hinzufügen; zusätzliche Flutter-Funktionen separat kennzeichnen |
| Gemeinsame Situation | Flutter-Bericht beschreibt Teilnehmerbearbeitung | HTML-D10 ändert nur Text; zusätzliche Flutter-Fachlogik erhalten, aber nicht als Originalbedienung ausgeben |
| Papierkorb | Flutter ergänzt Klassen-Orga, Erinnerungsreaktivierung, Vorschau und geprüfte Pflichtsicherung | Sinnvolle bestehende Erweiterungen; kein Beweis für byte-/pixelgleiche HTML-Oberfläche |
| Hintergrund | 0.11 nennt 5-MB-PNG; später 0.13/0.15.2 12 MiB/48 MP, JPEG, fünf Modi, getrennte Bilder | Neuere Dokumentation maßgeblich; Original-HTML hat nur eine Bildvariante und cover |
| Schriften | Selawik/Gelasio statt Segoe UI/Georgia | Metrisch ähnliche Ersatzschriften, keine gesicherte Glyphen-/Pixelgleichheit |
| R1–R7 | Review meldete Fehler, 0.15.0 erklärt sie korrigiert | Ohne Tests/Quellen keine erneute Bestätigung oder Wiederanwendung. Besonders Ein-Schüler-Fortsetzung, Entwurfskonkurrenz, Tastatur als Regression prüfen |

## Auszuführende lokale Flutter-Prüfung nach Bereitstellung

Keine Browsertests. Keine Bewertung anhand eines kompilierten Webbuilds. Die Tests müssen den tatsächlichen Anwendungscode verwenden, synthetische Daten in einer temporären SQLite-Datei und injizierbare Speicherfehler. Keine Testkopie der Implementierung.

| Matrix | Varianten / belegbares Ergebnis |
| --- | --- |
| Breite und Höhe | 320×640, 390×844, 800×900, 1440×1000; bei jeder Dialogfamilie Außenabstand, Rundung, Maximalbreite, sichtbarer App-Hintergrund |
| Schrift | Skalierung 1,0 / 1,3 / 2,0; lange Schülernamen, Beobachtungen, Aufgaben, Validierungsfehler |
| Tastatur | `viewInsets.bottom` 0 / 240 / 300; Fokus im letzten Feld, Scrollen zu Speichern und Schließen; kein RenderFlex-Overflow; bei geringer Resthöhe gesamter Dialog bedienbar |
| Formularzustand | Leer, gültig befüllt, optional ein/aus, vorhandener Datensatz, fehlerhaft, Speicherfehler, Konflikt, fortgesetzter Entwurf |
| Tags | Originalkatalog/Reihenfolge; Stern wählt nicht; gemischte positive/negative Auswahl; ausgewählte Vorschläge verschwinden; Entfernen/Fokus; Arbeitsauftrag mehrfach; Sozialzeitpunkt einmal; Freitext unverändert |
| Optionale Felder | Sichtbarkeit separat; eingeklappte Werte nach Speichern/Reload erhalten, wo spätere Vorgabe dies verlangt; Zielzuordnungsentfernung als ausdrückliche fachliche Aktion |
| Datum/Zeit | Datum allein, 00:00, andere Zeit, Entfernen, Kalenderabbruch, Monatswechsel, Datum leer/ungültig; alle fachlichen Termine unabhängig |
| Entwürfe | X, Zurück, Escape, Android-pop, Außenklick gemäß Vertrag, Lebenszyklus; kein leerer Entwurf; zwei verschiedene Entwürfe unterscheidbar; passender Kommentar-Modus beim Fortsetzen |
| Speicherung | Transaktion, Journaleintrag, Reload aus Datei, Fehler-Rollback, erneuter Versuch; bei Fehler kein Schließen/Weiter; letzter/einziger Schüler ohne Wiederverwendung alter Eintrags-ID |
| HÜ-Stand | No-op auf identischem Stand, schnelle doppelte Klicks, unabhängige Teilaufgaben, Kommentar/andere Aufgaben erhalten, sichtbarer Kartenfehler mit Retry |
| HÜ-Kommentar-Konflikt | Kommentar beginnen → extern Stand ändern → aktuelle Fassung ausdrücklich übernehmen → Kommentar speichern → neuer Stand bleibt erhalten |
| Orga | Notiz/Checkliste/Aufgabe; Termin und Erinnerung separat; erledigen beendet Erinnerung, quittieren lässt Aufgabe unverändert; Klasse ohne Schüler |
| Darstellung | Reale gerenderte Tagbeschriftung und durchgehende Sternfläche; gemeinsame Kopf-/Fußfarbe in allen Rahmen; Transparenzen mit darunterliegender Kontrastfläche und nach Reload; Hintergrundmodus in Vorschau und App identisch |

Direkte Bilder über `flutter test`/`RenderRepaintBoundary.toImage` mit echten gebündelten Schriftdateien erzeugen, nicht Ahem-Testschrift. PNGs je Dialog/Zustand benennen, Dimensionen/Skalierung/Tastaturhöhe und geprüfte Quellrevision in einem Manifest festhalten. Danach Bilder wirklich visuell öffnen und mit der CSS-/Inhaltsreferenz prüfen; ein gespeichertes PNG allein ist keine Sichtprüfung. Widgettests müssen reale Aktionen und Persistenzwirkung nachweisen, nicht nur Textvorkommen.

Vorgesehene Befehle im **bereitgestellten aktuellen** Projekt: `flutter pub get`, `flutter analyze`, `flutter test`; gezielte UI-/Renderingtests gemäß dessen tatsächlicher Teststruktur. Es wurden keine fiktiven Dart-Dateipfade oder bestandenen Testzahlen erfunden.

## In dieser Arbeit tatsächlich ausgeführt

- Aktuelles Repository abgerufen, Commit und Archivinhalt kontrolliert.
- Original-HTML, spätere Spezifikation, Quellarchiv-Dokumentation und 18 Webpreview-Berichte gelesen/verglichen.
- 21 benannte HTML-Dialoge plus dynamischen Passwortdialog aus Quellcode und erzeugtem DOM ermittelt.
- 65 Quellenzustände mit synthetischen Daten in Node/jsdom aufgenommen, einschließlich ausgewählter leerer/befüllter/fehlerhafter Ansichten und Entwurfsfortsetzung; kein Browser, kein CSS-Layout, keine Pixelabnahme.
- Referenzkopien mit SHA-256 versehen und bytegleich zu den Herkunftsdateien geprüft.
- **Keine aktuellen Dart-Anwendungskorrekturen**, **keine Flutter-Tests**, **keine direkten Flutter-Renderings**. Diese Schritte sind offen, weil das aktuelle Quellprojekt fehlt; in der Umgebung ist zudem kein Flutter/Dart installiert. Ein Versuch, den offiziellen Releaseindex zu laden, erhielt HTTP 404; es wurde kein SDK-Erfolg behauptet.

**Abnahmestatus: nicht als „originalgetreu“ freigegeben.** Benötigt wird das aktuelle Flutter-Quellprojekt (mindestens `lib/`, `test/`, `pubspec.yaml`, `pubspec.lock`, Assets und zugehörige Dokumentation) oder sein erreichbarer Git-Branch/Commit. Der Webbuild allein reicht nicht.
