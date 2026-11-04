# Orga-Typwechsel und Terminkonflikte – Build 36

Stand: **0.16.0-rebuild.16+36**, 4. November 2026.
Die beiden im [technischen Review von Build 35](TECHNIK_REVIEW_BUILD_35.md)
reproduzierten Fehler sind korrigiert.

Beim Hin- und Zurückwechseln zwischen Notiz, Aufgabe und Termin bleiben die
Angaben des jeweiligen Typs erhalten: Termindatum/Uhrzeit sowie Fälligkeit und
Erledigt-Status. Das gilt für Buttons und Swipes. Ein eigener unveränderlicher
Entwurfswert hält die ausgeblendeten Angaben fest; er wird gemeinsam mit dem
Entwurf gesichert und bleibt nach Backup/Wiederherstellung sowie SQLite-Neustart
verfügbar. Beim Veröffentlichen enthält der Eintrag nur die Angaben seines
endgültig gewählten Typs. Ausdrücklich geleerte Datums-/Uhrzeitfelder bleiben leer.

Ein unverändert zurückgeschalteter Eintrag hinterlässt keinen zusätzlichen Entwurf.
Beim Zurückkehren zu einer erledigten Aufgabe wird eine inzwischen geplante
Erinnerung beendet; erledigte Aufgaben bekommen dadurch keine aktive Erinnerung.

Der Konfliktdialog stellt Termindatum und Terminzeit beider Fassungen gegenüber,
mit deutschem Datumsformat und „Ganztägig“ bei fehlender Uhrzeit. Die Zeitzone einer
Erinnerung wird ebenfalls berücksichtigt. Ein neuer Feldabgleich prüft, dass alle
benutzerrelevanten Orga-Felder im Vergleich berücksichtigt werden. Die Entscheidung
übernimmt wie bisher die gesamte gewählte Fassung; eine feldweise Zusammenführung
ist damit nicht eingeführt.

## Prüfung

**240 Tests der vollständigen Flutter-Testsuite bestanden**, statische Analyse ohne
Befunde. Die 13 neuen Regressionstests prüfen:

- ursprüngliche Termin-/Aufgabenwerte nach Hin- und Zurückwischen;
- ausdrücklich geänderte und geleerte Werte nach erneutem Typwechsel;
- Entwurf schließen, Backup wiederherstellen, Dateidatenbank schließen/öffnen,
  fortsetzen und speichern – einschließlich Checkliste und unverändertem Original;
- Entfernen des eigenen Entwurfs nach Rückkehr zum unveränderten Ausgangszustand;
- sichtbare Termindifferenzen auf schmaler und breiter Ansicht und beide
  Konfliktentscheidungen bis zum gespeicherten Ergebnis;
- Vollständigkeit der Orga-Feldbeschriftungen, alte Entwürfe ohne Zusatzfeld,
  Rollback bei ungültigem Entwurfsdatum und konsistente Erinnerungszustände.

Die drei früher fehlgeschlagenen Reproduktionen wurden in die reguläre Suite
übernommen und erweitert: [Regressionstests](../flutter_app/test/orga_type_conflict_test.dart).
Die alten Fehlerprotokolle bleiben als historische Nachweise erhalten.

- [Vollständige Testsuite](evidence/app36-all-tests.log)
- [Statische Analyse](evidence/app36-analyze.log)
- [Android-Build](evidence/app36-apk-build.log)
- [APK-Verifikation](evidence/app36-apk-verification.json)

Android-Releasebuild erfolgreich; APK-Signatur, Versionscode 36, Paketkennung,
ZIP-Integrität und 16-KB-Ausrichtung der nativen Bibliotheken geprüft.

## Daten und Plattformgrenzen

Keine Änderung des SQL-Schemas. Das optionale JSON-Feld `orgaTypeDraft` erweitert
nur Orga-Entwürfe; alte Entwürfe bleiben lesbar. Vorhandene veröffentlichte Einträge
werden durch das Update nicht umgeschrieben. App-ID und Testsignatur bleiben gleich.
Build 36 über FLEX Test installieren, nicht deinstallieren.

Kein physischer Android-Gerätelauf und keine Browsertests. Die weiteren im Review
dokumentierten Prüf- und Produktlücken bleiben bestehen. Dieser Build korrigiert
die beiden bestätigten Orga-Fehler.
