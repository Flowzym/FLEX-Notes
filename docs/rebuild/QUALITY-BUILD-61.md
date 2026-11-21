# FLEX 0.19.0+61 · Gemeinsame Sicherung, Aufträge und Dokumentverlauf

## Umsetzung

### Hausübung

„Abgabe prüfen“ und die aktuelle Abgabeanzeige entfallen. Ältere Abgaberückmeldungen
bleiben im Verlauf erhalten. Beim Antippen von X erscheint „Erneut aufgeben?“.
„So belassen“ speichert ausschließlich den nicht erledigten Stand. Bestätigung
legt eine neue offene HÜ für denselben Schüler an, mit auswählbarer Fälligkeit.
Eine ausgewählte Unteraufgabe wird als eigene Aufgabe übernommen; bei einer
Hauptaufgabe werden ihre Unteraufgaben mitgenommen. IDs und Dateiverweise werden
atomar zugeordnet. Der ursprüngliche Stand bleibt erhalten. Es gibt keinen Zähler.

### Auftrag im Arbeitsverhalten

„Planung / Material zuordnen“ öffnet direkt am Auftrag die Auswahl für den
Eintragungstag, FLEX-Planungen und weitere Materialien. Tagesvorschläge berücksichtigen
bereitgelegte Dateien, Unterricht und verknüpfte Planungen. OneDrive ist ebenfalls
von dort erreichbar.

FLEX-Planungsnotizen sowie Textabschnitte aus DOCX und textbasierten PDFs lassen
sich einzeln auswählen. Dokument-ID, Titel, ausgewählter Text und gegebenenfalls
PDF-Seite bleiben am Eintrag gespeichert. Die Quelle kann wieder geöffnet werden;
bei entfernten Quellen bleibt der gewählte Text erhalten. Eine Verknüpfung ersetzt
keine Dateikopie: Online-Dateien müssen für Offlinezugriff heruntergeladen sein.
Bild-PDFs ohne Text können vollständig verknüpft werden; OCR ist hier nicht enthalten.
Die Textauswahl ist auf 300 Abschnitte und PDF-Dateien bis 100 Seiten begrenzt.

### Vollständige Sicherung

Manueller Export und automatische Android-Sicherung enthalten nun gemeinsam:
Notizbuch, Entwürfe, lokale Dokumente, Fotos, Scanseiten, Filter-Rückgängig und
aufbewahrte Dokumentversionen, einschließlich Papierkorb. OneDrive-Verweise sind
enthalten; nur bereits lokal vorhandene Dateien sind offline gesichert.

Jede Datei wird auf Dateiformat und SHA-256 geprüft. Fehlende Dateien führen zu
einer Fehlermeldung; es wird keine unvollständige Vollsicherung ausgegeben.
Wiederherstellung und Zusammenführen zeigen vorab die geprüfte Dateianzahl.
Dateien werden erst nach Bestätigung geschrieben und zurückgelesen, dann folgt
die Datenbanktransaktion. Bestehende Datei-Schlüssel mit abweichendem Inhalt werden
nicht überschrieben. Fehler bei der Übernahme entfernen neu geschriebene Dateien.
Bestehende lokale Daten werden beim Zusammenführen weiter pro Feld abgeglichen.

Die Verschlüsselung verwendet AES-256-GCM und PBKDF2-SHA256 mit 310.000 Runden;
die Vollsicherung hat eine eigene authentisierte Formatkennung. Alte JSON- und
Materialsicherungen bleiben lesbar. Neue Vollsicherungen benötigen Build 61 oder
neuer. Materialpakete bleiben für den Austausch einer Dateiauswahl verfügbar.
Auch die Sicherung vor der Speicherpflege enthält jetzt die Dateien und ist
passwortgeschützt. Grenzen: 20 MB Notizbuch, 20 MB pro Datei, 100 MB lokale Dateien
pro Vollsicherung. Große Sicherungen brauchen entsprechend freien Arbeitsspeicher.

### Scanner-Verlauf

Der letzte Stapelfilter wird im Scanentwurf gespeichert und kann nach Schließen
und Wiederöffnen verlustfrei zurückgenommen werden. Nicht bearbeitete Seiten und
die Reihenfolge bleiben erhalten. Beim Ersetzen eines gespeicherten Dokuments
werden bis zu fünf frühere Dateifassungen aufbewahrt. Unter „Versionen“ lassen sie
sich ansehen, wiederherstellen und einzeln endgültig löschen. Verdrängte oder
entfernte Dateien werden bereinigt, sofern keine andere Datei/kein Entwurf sie nutzt.
Erfolgreiche Speicherungen werden bei einem nachfolgenden Aufräumfehler nicht als
fehlgeschlagen ausgegeben. Frühere Versionen können Inhalte vor einer Schwärzung
enthalten; die Versionsansicht weist darauf hin. Teilen verwendet die aktuelle Datei.

### Konsolidierung

Die bisherigen großen Dateien wurden nach Verantwortlichkeiten aufgeteilt:
Schul-Editor in Entwurfs-/Lebenszykluslogik, Formulare, Beobachtungsansicht und
Dialogdarstellung; Materialverwaltung in Seite, Datei-/OneDrive-Aktionen und
Mehrfachauswahl; Scanner in Bearbeitung/Erfassung und Darstellung. Auftragsquellen,
Vollsicherung und Dokumentversionen haben eigene Domain-, Service- und UI-Bausteine.
Die gemeinsame Zustandsführung bleibt erhalten; die Regressionstests prüfen die
bestehenden Abläufe nach der Aufteilung.

## Externe Voraussetzungen

**Android-Gerät:** Ein Releasebuild und simulierte Kamera-/Bildtests ersetzen keine
Prüfung mit echten Arbeitsblättern auf dem Zielhandy. In dieser Umgebung ist kein
physisches Android-Gerät angeschlossen. Modell/Android-Version wurden angefragt.
Die praktische Abnahme bleibt offen; [der Geräteprüfablauf](ANDROID-DEVICE-CHECK.md)
hält konkrete Fälle und Abnahmekriterien fest.

**OneDrive:** Gewünscht ist ein privates Microsoft-Konto. Die öffentliche Client-ID
kann jetzt direkt in FLEX hinterlegt und korrigiert werden; ein Neubau ist dafür
nicht mehr nötig. Anmeldung und Token bleiben außerhalb der Notizbuchsicherung.
Die Microsoft-Appregistrierung selbst fehlt weiterhin. Der verfügbare OneDrive-
Connector kann Dateien verwalten, aber keine Entra-Appregistrierung anlegen.
Die geführte Einrichtung in FLEX und [die Einrichtungshinweise](ONEDRIVE-SETUP.md)
bereiten diesen Schritt vor. Eine erfolgreiche Anmeldung mit einem echten Konto
wird erst nach Registrierung geprüft.

## Prüfstand

- 511 Tests der vollständigen Flutter-Suite bestanden, einschließlich bestehender
  Sicherungs-, Konflikt-, Scanner-, Tastatur- und UI-Regressionstests.
- 11 neue Tests für Vollsicherung/Rollback, Versionsbegrenzung, erneutes Aufgeben,
  Auftragsquellen, DOCX-Texte und OneDrive-Konfiguration; in den 511 enthalten.
- Nach der letzten Beschriftungsänderung die drei Auftrags-/HÜ-UI-Tests erneut bestanden.
- Statische Analyse ohne Befunde; Formatprüfung: 177 Dateien, keine Änderungen.
- 11 SQLite-Schematests und 3 Vorschau-Servertests bestanden.
- Release-Webbuild erfolgreich. Browserprüfung bei 390 × 844 mit bereits
  vorhandenem synthetischem Profil: Zuordnen/Speichern von Material und einzelnen
  PDF-Aufgaben einschließlich Seitenreferenz; HÜ-X-Vorschlag mit Abbrechen.
- GitHub führt Analyse/Tests sowie Web- und Android-Releasebuild für den neuen
  Quellstand aus; der Lauf ist im [PR](https://github.com/Flowzym/FLEX-Notes/pull/1)
  sichtbar. Ein erfolgreicher Android-Bau ist keine Geräteabnahme.
