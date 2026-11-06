# Materialien und Planungen · Build 39

Stand: 06.11.2026. Version **0.16.0-rebuild.19+39**, weiterhin eine FLEX-Klasse.
Die vier Hauptseiten bleiben Übersicht, Schüler, Kalender und Materialien.
Der hochgeladene FLEX-Explorer dient als fachliche Referenz; seine hartcodierten
Schülernamen, Ordnerregeln und browserlokalen Daten wurden nicht übernommen.

## Bedienung

- Kompakte Dateizeilen öffnen ein Dokument direkt. Favorit und Materialangaben
  besitzen eigene Schaltflächen. Suche berücksichtigt Titel, Fach, Thema, Notiz,
  Schlagwörter, Dokumentart, Quellpfad und zugeordnete Schülernamen.
- Mehrfachauswahl zeigt eine gemeinsame, am unteren Rand erreichbare Aktionsleiste:
  für einen Tag bereitlegen, Schüler zuordnen, zu einem Unterrichtspaket hinzufügen,
  offline laden und in den Papierkorb verschieben. „Schüler“ ergänzt Zuordnungen;
  einzelne Zuordnungen lassen sich beim Schüler oder in den Materialangaben entfernen.
- Die Suchabfrage, Filter und Scrollposition bleiben beim Seitenwechsel erhalten.
  Favoriten, Dokumentart und Fach helfen beim Eingrenzen der Dateiliste.
- **Bereitgelegt:** Tagesauswahl, Reihenfolge per Griff ändern, einzelne Dateien
  vom Tag entfernen, alle bereitgelegten Dateien offline laden. Unterricht,
  zugehörige Planungen und Wochenpläne liefern Vorschläge. Keine automatische
  Übernahme alter Tageslisten. Kalender und Übersicht öffnen dieselbe Tagesauswahl;
  in der Übersicht erscheint der Zugang nur bei vorhandenen Unterlagen/Vorschlägen.
- **Unterrichtspakete:** benannte, wiederverwendbare Dateisammlungen mit optionalem
  Fach, Thema, Notiz und Schülerzuordnung. Ein Paket lässt sich im Materialwähler
  vollständig auswählen, etwa für Unterricht, Planung, Tagesvorbereitung oder Rücklauf.
- **Planungen:** Name als einziges Pflichtfeld, dazu optional Zeitraum, Fach/Thema,
  Schüler, Unterrichtsverknüpfungen, Dateien und Nachbereitung. Sichtbare Zustände
  Geplant, Begonnen, Durchgeführt und Verschoben. Kalender und Unterricht zeigen
  die passenden Planungen. Ausführliche DOCX-/PDF-Planungen bleiben als Dateien
  verknüpft; FLEX verlangt keine Abschrift ihrer Inhalte.
- **Schüler → Unterlagen:** direkt zugeordnete Dateien, Pakete und Planungen öffnen;
  weitere Dateien zuordnen und Planungen für diesen Schüler anlegen.
- Dokumentarten: Dokument, Arbeitsblatt, Lösung, Wochenplan, Lernplan,
  Unterrichtsplanung, Protokoll, Elterninformation und Vorlage. Zielgruppen:
  Alle, Schüler, Lehrkraft, Eltern. Vorhandene Rückläufe nutzen dieselbe Ablage.
- Die bisher „Materialpaket“ genannte verschlüsselte Dateisicherung heißt jetzt
  **Materialsicherung**, um sie von Unterrichtspaketen zu unterscheiden.

## OneDrive und Dokumentanzeige

Die direkte Microsoft-Anmeldung benötigt weiterhin eine eigene öffentliche Client-ID;
sie ist in diesem Build nicht enthalten. Lokaler Dateiimport und gespeicherte HTTPS-/
OneDrive-Links bleiben nutzbar. [Einrichtung](../docs/ONEDRIVE_EINRICHTEN.md).

Der Ordnerimport liest nach erfolgter Anmeldung PDF-/DOCX-Metadaten einschließlich
Unterordnern. Vorschau vor dem Speichern, neue Dateien vorausgewählt, Korrektur von
Titel, Fach, Dokumentart, Zielgruppe und Schülerzuordnung. Vorhandene Dateien müssen
zum Aktualisieren ausdrücklich ausgewählt werden. IDs verwenden Laufwerk und
Datei-ID: Umbenennen/Verschieben innerhalb desselben Laufwerks erzeugt keine Dublette.
Eigene Bezeichnungen, Zuordnungen, Favoriten, Papierkorbstatus und der Stand einer
Offlinekopie bleiben erhalten. Keine Löschungen oder Änderungen an OneDrive-Originalen.
Grenzen: 2.000 PDF-/DOCX-Dateien, 250 Ordner, 10.000 gelistete Einträge; Verknüpfungen
auf fremde Laufwerke werden nicht durchlaufen. Abbruch/Fehler speichert keinen Teilimport.

DOCX erhält auf Android eine lokale Textvorschau für Überschriften, Absätze, Listen
und einfache Tabellen. Kein Word-Layoutnachbau: Abbildungen, Seitenumbrüche und komplexe
Formatierungen erfordern **Original öffnen**. Keine Bearbeitung von Office-Dateien,
kein XLSX/CSV-Editor, keine Volltextindizierung des Dokumentinhalts. PDF nutzt weiterhin
die native Anzeige. Offlinekopien und lokale Vorschau sind Android-Funktionen;
Web/Windows behalten Links und Metadaten.

## Datenerhalt

Materialien, Unterrichtspakete, Planungen und Tageslisten liegen im vorhandenen
transaktionalen Speicher mit Revision und Änderungsverlauf. SQL-Schema 7 bleibt bestehen.
Die reguläre Notizbuchsicherung enthält alle Metadaten und Zuordnungen; Dateiinhalte
liegen wie bisher separat in der verschlüsselten Materialsicherung. Beim Import einer
Materialsicherung werden fehlende Schüler ausdrücklich angezeigt; deren Zuordnungen
können ohne die zugehörige Notizbuchsicherung nicht wiederhergestellt werden.

Zuordnungen enthalten Datei-IDs, keine Dateikopien. Das Entfernen vom Tag, von einem
Schüler oder aus einem Paket löscht die Datei nicht. Papierkorb und Wiederherstellung
bewahren Verweise. Ungültige Verweise und veraltete Fassungen rollen den gesamten
Speichervorgang zurück. Planungs-/Paketeditoren verwenden die bestehende Entwurfssicherung.
Zusammenführen von Sicherungen ordnet auch die neuen Schülerverweise korrekt zu.

## Validierung

**330 Flutter-Tests** in der vollständigen Suite und die abschließenden Material-UI-Prüfungen
bestanden. Strenge statische Analyse, Formatprüfung, 11 SQLite-Tests und 3
HTTP-Serverprüfungen bestanden. Android- und Web-Releasebuild sowie APK-Signatur,
Manifest und 16-KB-Ausrichtung geprüft.
[GitHub-Pipeline auf dem Quellstand der APK: vollständig erfolgreich](https://github.com/Flowzym/FLEX-Notes/actions/runs/42290885316).

[Materialansicht](materialien-build-39/materialien.png) ·
[Tagesvorbereitung](materialien-build-39/bereitgelegt.png) – direkte Flutter-Renderbilder
auf einem 390 × 844 großen Testdisplay mit Beispieldaten.

Automatisierte Prüfungen umfassen Datenerhalt, Sicherungswiederherstellung und
Zusammenführen, ungültige/stale Sammeländerungen, Datei-IDs nach Umbenennung, Abbruch
und Grenzen beim Einlesen, Offline-Download-Rollback, DOCX-Inhaltsverarbeitung sowie
Bedienabläufe und große Schrift auf schmalen Displays. Direkte Flutter-Renderbilder
wurden visuell geprüft. Kein Browser-Testlauf.

Die endgültigen Testzahlen, APK-Prüfsummen und der GitHub-CI-Lauf stehen beim
[Android-Build 39](../releases/android/build-39/README.md).
Kein physischer Android-Gerätelauf: Update mit echten Bestandsdaten, Word-Übergabe,
native PDF-Anzeige, Offlinebetrieb und echte Microsoft-Anmeldung bleiben am Gerät
abzunehmen. Paketkennung und bisherige Testsignatur werden beim APK-Bau überprüft.
