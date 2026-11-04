# Technischer Review von Build 35

Stand: 4. November 2026, geprüfter Commit `5555de0182f10cc5b2f25a79252df00f81588c7e`.
App-Code und ausgelieferte APK werden durch diesen Review nicht verändert.

## Ergebnis

Die vorhandenen **227 Flutter-Tests bestehen erneut**, Dart-Analyse ohne Befunde,
Formatprüfung ohne Änderungen. Android Lint: **0 Fehler, 1 Aufräumwarnung** zu
`drawable-v21` bei Mindest-API 24. Keine ungelösten Git-Mergekonflikte, keine
Konfliktmarker in App-Code/Tests und zu Beginn ein sauberer Arbeitsbaum.
Das belegt keine vollständige Fehlerfreiheit: Drei neue Reproduktionen zeigen
zwei bisher nicht abgedeckte Funktionsfehler.

## Bestätigte Befunde

### 1. Orga-Typwechsel verwirft vorhandene typbezogene Werte

Priorität: hoch für den nächsten Korrekturlauf; ein versehentlicher Wechsel kann
beim anschließenden Speichern gültige Angaben überschreiben.

Reproduktion auf einem bereits gespeicherten Eintrag:

- Termin am **04.04.2030, 14:30** → nach rechts zu Aufgabe → zurück zu Termin →
  Speichern: Ergebnis **04.11.2026, ohne Uhrzeit** (heutiges Datum im Test).
- Erledigte Aufgabe mit Fälligkeit **04.04.2030** → nach rechts zu Notiz → zurück
  zu Aufgabe → Speichern: Ergebnis **ohne Fälligkeit, wieder offen**.

Ursache: [`selectKind`](../flutter_app/lib/ui/orga_editor.dart) setzt beim Verlassen
eines Typs `dueDate`, `done`, `appointmentDate` und `appointmentTime` zurück.
Beim Zurückwechseln existiert kein Zwischenspeicher. Buttons und Wischen verwenden
dieselbe Methode. Text und Checklisten bleiben erhalten; die vorhandenen Tests
prüften diese, nicht die Datums-/Statuswerte beim Hin- und Zurückwechseln.
Der veröffentlichte Eintrag wird erst mit Speichern geändert; frühere Fassungen
bleiben in der Historie. Der Zwischenstand kann bereits als Entwurf gespeichert werden.

Empfehlung: typbezogene Eingaben während der Sitzung bzw. im Entwurf erhalten und
erst die endgültig gewählte Form beim Veröffentlichen normalisieren. Die beiden
Reproduktionen danach als reguläre Regressionstests übernehmen.

### 2. Konfliktdialog verschweigt abweichende Terminangaben

Priorität: hoch für eine verlässliche Konfliktentscheidung.

Ein gespeicherter Termin und ein älterer Entwurf mit unterschiedlichen Daten und
Uhrzeiten erzeugen einen Konflikt. Der Dialog bietet „Aktuelle behalten“ und
„Andere übernehmen“, zeigt aber **keine Datums-/Uhrzeitgegenüberstellung**.

Ursache: [`conflictFieldLabels`](../flutter_app/lib/ui/conflict_dialog.dart) enthält
`appointmentDate` und `appointmentTime` nicht. Der Vergleich filtert alle nicht
gelabelten Felder aus. Bei einem reinen Terminkonflikt bleibt die Gegenüberstellung
leer. Die Auswahl übernimmt weiterhin die gesamte Fassung.

Empfehlung: Terminangaben in den Vergleich aufnehmen und die Feldliste mit den
aktuellen Datensätzen abgleichen. Ein UI-Test muss beide Werte vor der Entscheidung
nachweisen. Vollständige feldweise Zusammenführung ist zusätzlich eine bereits
bekannte, noch nicht implementierte Funktion.

## Neu gemessene Abdeckung

**6.891 von 8.105 erfassten ausführbaren Dart-Zeilen = 85,0 %.**
Das ist Zeilenabdeckung, keine Aussage über alle Zustandskombinationen oder
korrekte Ergebnisse. Der Testlauf erfasst `main.dart` nicht; die reine Farbkonstanten-
Datei ist ebenfalls nicht im Coverage-Bericht. Kotlin und Android-Plattformcode
sind nicht Teil dieser Zahl.

| Bereich | Zeilenabdeckung |
| --- | ---: |
| Datenzugriff | 91,4 % |
| Fachmodelle | 98,1 % |
| Controller | 100,0 % |
| Backup-Verschlüsselung | 93,6 % |
| Oberfläche | 82,3 % |

Niedrigere Teilabdeckung: Backupdialog **53,2 %**, weitere Dialogabläufe **61,4 %**,
Konfliktdialog **66,7 %**, Bereichsansichten **67,6 %**. Diese Bereiche verdienen
zusätzliche Tests kompletter Abläufe und Fehlerfälle, nicht nur höhere Prozentwerte.

## Was weiterhin nicht nachgewiesen ist

- **Android-Gerät:** echte Bildschirmtastaturen, Textauswahl/Swipes, Zurück-Geste,
  Rotation, Hintergrund/Vordergrund und Prozessabbruch mit ungespeicherten Eingaben.
- **Update mit realen Daten:** Installation über eine vorhandene ältere FLEX Test
  und Kontrolle des vorhandenen Bestands. Signatur/Paketkennung und SQLite-Neustart
  sind geprüft; der echte Android-Updateablauf ist es nicht.
- **Dokumentanbieter:** vollständiger Export/Import auf Android mit Downloads,
  OneDrive, Abbruch, fehlendem Platz und entzogenem Zugriff. Bisherige Exporttests
  simulieren die MethodChannel-Antwort; Android Lint führt keinen Dateidialog aus.
- **Last und Dauerbetrieb:** große Klassen-/Eintrags-/Historienbestände, lange
  Bearbeitungssitzungen, viele aufeinanderfolgende Sicherungen; keine belastbaren
  Laufzeit-/Speichermessungen auf schwächeren Geräten.
- **Barrierefreiheit:** reale TalkBack-Bedienung, Fokusreihenfolge und verständliche
  Ansagen. Große Schrift und mehrere Layoutgrößen sind bereits getestet.
- **Sicherheits-/Abhängigkeitsaudit:** keine umfassende Prüfung aller Abhängigkeiten,
  Android-Systembackups oder des Geräteschutzes. Verschlüsselte Exportdateien sind
  getestet; die aktive lokale Datenbank ist nicht appseitig verschlüsselt.
- **Automatisierung:** keine eingecheckte GitHub-Actions-Pipeline, keine Android-
  `integration_test`-/Instrumentierungstests. Grüne lokale Tests werden nicht bei
  jedem zukünftigen Push automatisch erzwungen.
- **Browser/Windows:** kein aktueller Lauf auf diesen Zielplattformen; Browsertests
  wurden entsprechend dem bestehenden Projektumfang nicht ausgeführt.

Bekannte Produktgrenzen bleiben: Import-Zusammenführung, feldweise Konfliktauflösung,
geführter Reimport einer Entwurfsrettung. Orga-Erinnerungen sind Hinweise innerhalb
der App, keine Android-Systembenachrichtigungen.

## Einschätzung der Codequalität

Datenmodelle, SQLite-Zugriff, Controller und UI sind getrennt; Schreibvorgänge nutzen
Transaktionen und Revisionsprüfungen. Die Tests enthalten Rollbacks, konkurrierende
Entwurfsänderungen, Backup-Roundtrips und Fehlerfälle. Das ist eine tragfähige Basis.

Wartungsschulden bestehen dennoch: `school_editor.dart` umfasst 2.106 Zeilen,
`notebook_screen.dart` 1.478 und `orga_editor.dart` 913. Große UI-Klassen verbinden
Darstellung, Formularzustand, Autosicherung und Navigation. Gerade gemeinsame
Wechsel-/Konfliktregeln sollten fachlich gekapselt und mit Zustandsübergängen getestet
werden. „Analyzer sauber“ bedeutet daher nicht „alle Funktionen korrekt verzahnt“.

## Nachweise und Reproduktion

- [Vollständige 227 Tests](review-build35/tests.log)
- [Dart-Analyse](review-build35/analyze.log) · [Formatprüfung](review-build35/format.log)
- [Android Lint](review-build35/android-lint.txt)
- [Abdeckung je Datei](review-build35/coverage-summary.json)
- [Drei fehlgeschlagene Reproduktionen](review-build35/repro-tests.log)
- [Ausführbare Reproduktionen](review-build35/repro_test.dart)

Die Reproduktionen prüfen das gewünschte Verhalten und schlagen auf Build 35
absichtlich als Fehlernachweis fehl. Sie liegen außerhalb der regulären Suite,
damit deren historischer Prüfumfang erkennbar bleibt. Aus `flutter_app/` ausführen:

```sh
flutter test --no-pub ../audit/review-build35/repro_test.dart
flutter test --no-pub --coverage
flutter analyze --no-pub
```

Android Lint wurde mit `:app:lintRelease -x :app:compileFlutterBuildRelease`
gegen die vorhandenen Release-Ausgaben ausgeführt. Es wurde keine neue APK verteilt.
