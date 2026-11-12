# Von FLEX Test zu FLEX · Build 62

Die neue App heißt **FLEX** und kann neben **FLEX Test** installiert werden.
Die alte App bleibt mit ihren Daten auf dem Handy. Daten werden beim Installieren
nicht automatisch übernommen. Die Anleitung gilt für den Wechsel von der zuletzt
ausgelieferten Test-App Build 56.

## 1. In FLEX Test vorbereiten

- Begonnene Scan-/Fotoentwürfe fertigstellen und als PDF oder Foto speichern.
- Materialien, die offline mitkommen sollen, vollständig herunterladen.
- Benötigte Dateien aus dem Material-Papierkorb zuvor wiederherstellen: Der alte
  Materialexport umfasst nur aktive Materialien. Später können sie in der neuen
  App wieder in den Papierkorb verschoben werden.

## 2. Beide Sicherungen außerhalb der alten App speichern

- Unter **Mehr → Daten** das Notizbuch exportieren und das Sicherungspasswort
  aufbewahren.
- Unter **Material → Materialsicherung erstellen** alle gewünschten Materialien
  auswählen und exportieren.

Beide Dateien in einem zugänglichen Ordner speichern, beispielsweise Downloads
oder OneDrive. Prüfen, dass sie dort vorhanden und nicht leer sind. Der alte
Notizbuchexport allein enthält keine lokalen PDF-/Fotodateien. Reine Links bleiben
Links; sie machen eine Online-Datei nicht automatisch offline verfügbar.

## 3. Neue FLEX installieren

[FLEX 0.19.1+62 herunterladen](../../releases/android/build-62/README.md) und
die APK auf dem Handy öffnen. Falls Android nachfragt, die Installation für
den verwendeten Browser oder Dateimanager erlauben.

Anschließend **FLEX** öffnen; **FLEX Test** bleibt bestehen. Die neue App startet
mit einem eigenen Datenbestand. Kein Löschen oder Deinstallieren der alten App
ist für diesen Schritt erforderlich.

## 4. Zuerst Notizbuch, dann Materialien importieren

1. In **FLEX → Mehr → Daten → Sicherung importieren** die Notizbuchdatei wählen
   und mit ihrem Passwort öffnen.
2. Wegen des vorbereiteten Stundenplans kann „Sicherungen zusammenführen“
   erscheinen. Neue Einträge auswählen; bei Unterschieden am Stundenplan bewusst
   die gewünschten importierten Werte übernehmen. Mit **Auswahl zusammenführen**
   bestätigen. Bei wirklich leerem Datenbestand bietet die App stattdessen
   **Sicherung wiederherstellen** an.
3. Unter **Material → Materialpaket öffnen** die zweite Datei importieren.
   **Auch bereits vorhandene Dokumente auswählen:** Deren Metadaten kamen bereits
   mit dem Notizbuch, die lokalen Dateien fehlen aber noch. Der Hinweis
   „Vorhandene Metadaten und Offlinekopie ersetzen“ bezeichnet diese Ergänzung.
   Mit **Übernehmen** bestätigen.

Diese Reihenfolge erhält die Verknüpfungen mit Schülern, Einträgen und HÜ-Aufgaben.
Die Materialauswahl wählt bereits bekannte Dokumente nicht automatisch erneut aus.

## 5. Alt und neu vergleichen

- Schüler, Einträge, HÜ samt Unteraufgaben, Kalender und angepassten Stundenplan
  stichprobenartig vergleichen; auch ältere und archivierte Einträge prüfen.
- Mehrseitige Scans und Fotos direkt bei ihren zugehörigen Einträgen öffnen.
- Einige lokale Anhänge ohne Internet öffnen. Ein Vorschaubild allein belegt
  noch nicht, dass die vollständige Datei übertragen wurde.
- Erst nach erfolgreichem Vergleich PIN/Biometrie, Benachrichtigungen,
  automatische Sicherung und gegebenenfalls OneDrive in der neuen App einrichten.
  Diese gerätegebundenen Einstellungen werden nicht automatisch übernommen.
- Anschließend Erinnerungen in der alten App deaktivieren, wenn sie sonst doppelt
  erscheinen würden.

## 6. Neue vollständige Sicherung erstellen

In **FLEX → Mehr → Daten → Exportieren** eine neue verschlüsselte Vollsicherung
erstellen und außerhalb der App speichern. Build 62 bündelt Notizbuch, lokale
Dateien, Scanentwürfe und Dokumentversionen. Fehlende lokale Dateien werden als
Fehler gemeldet; in diesem Fall den Materialimport vervollständigen.

**FLEX Test und beide ursprünglichen Exporte behalten, bis der Vergleich und
die neue Vollsicherung erfolgreich sind.** Die persönlichen Daten können nur
auf dem Handy geprüft werden; ein erfolgreicher Build ersetzt diesen Schritt nicht.
