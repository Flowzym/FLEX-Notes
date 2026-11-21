# Android-Abnahme · Build 78

Status: **vorbereitet, nicht am Gerät durchgeführt**. Automatisierte Tests ersetzen
keine Prüfung von Kamera, Biometrie, SAF-Anbietern und Android-Lebenszyklus.
Alle Schritte zunächst mit einem synthetischen Testnotizbuch durchführen.

## Installation und vorhandene Daten

- [ ] Vor dem Update vollständige verschlüsselte Sicherung außerhalb der App erstellen.
- [ ] Build 78 über die neue FLEX Build 77 installieren, ohne App-Daten zu löschen.
- [ ] Schüler, Einträge, Entwürfe, Materialien, Bildversionen und Einstellungen vergleichen.
- [ ] App beenden, neu starten und Gerät neu starten; Bestand erneut prüfen.
- [ ] Separat Update von einem unverschlüsselten Build 62–76 prüfen: Migration bleibt
      atomar; bei Fehler bleibt das Original erhalten. Danach kein Downgrade.

## Sicherungen

- [ ] Neue `.flexbackup` verschlüsselt exportieren; auf zweiter Testinstallation öffnen.
- [ ] Vorschau, Zusammenführen, vollständiges Wiederherstellen und Anlagen prüfen.
- [ ] Alte JSON-v1/v2-Sicherung importieren, einschließlich Dateien und Versionen.
- [ ] Falsches Passwort, abgeschnittene Datei und manipulierte Datei: keine Übernahme.
- [ ] Sicherung während eines SAF-Schreibvorgangs abbrechen/Prozess beenden.
      Alte Sicherungen und letzter erfolgreicher Zeitpunkt müssen erhalten bleiben.
- [ ] Automatische Sicherung im gewählten lokalen Ordner und ggf. OneDrive-Anbieter:
      Schreiben, Lesen und Umbenennen zulässig; sonst verständlicher Fehler.
- [ ] Hintergrundsicherung bei geschlossener App sowie nach Neustart abwarten.
      Android darf den Zeitpunkt wegen Energieverwaltung verschieben.
- [ ] Große synthetische Sicherung (bis 100 MB) auf dem Zielgerät messen; kein OOM.
      Freien Speicher und eventuell verbliebene `.partial`-Dateien kontrollieren.

## Geteilte Dateien

- [ ] PDF, DOCX und Bild aus Dateien-App und OneDrive einzeln sowie gemeinsam teilen.
- [ ] FLEX vorher geschlossen, bereits geöffnet und durch PIN gesperrt testen.
- [ ] Gesperrte App zeigt weder Vorschauen noch personenbezogene Daten vor Entsperren.
- [ ] Vorschaubilder, Auswahl, Umbenennen, Kategorie, Schüler, Unterricht und Datum prüfen.
- [ ] „Später“, Neustart, Wiederöffnen über Materialseite: Dateien weiterhin vorhanden.
- [ ] Eingang entfernen: nur lokale Kopien entfernt, Originale unverändert.
- [ ] Übernehmen, erneut öffnen, Rückkehr aus Quell-App: kein doppelter Import.
- [ ] Übergrößen, ungültige PDF/DOCX/Bilder und verweigerte URI-Leserechte abweisen;
      vorhandene Daten und bereits wartende Dateien bleiben erhalten.
- [ ] Eingangsbild erneut exportieren: JPEG-Dateiendung, lesbarer Inhalt, keine GPS-EXIF.

## Kamera, Sperre und Bedienung

- [ ] Scanner mit Live-Rändern, Mehrfachaufnahme, Filtern, Zuschneiden und Ersatzbild.
- [ ] Kamera verweigern und erneut erlauben; Entwürfe bleiben erhalten.
- [ ] PIN/Biometrie, Appwechsel während Entsperren und Android-Zurück/predictive back.
- [ ] Termin-/Aufgabenerinnerung bei geschlossener App, Neustart und verschobenem Termin.
- [ ] TalkBack-Reihenfolge und Beschriftung im Dateieingang und in Sicherungsdialogen.
- [ ] Große Android-Schrift, 320-Pixel-Breite, Tastatur und Querformat ohne abgeschnittene Aktionen.

## OneDrive

- [ ] Eigene Registrierung mit öffentlichen Clientflows und delegiertem Files.Read anlegen.
- [ ] Öffentliche Client-ID in FLEX konfigurieren; persönlichen Microsoft-Account anmelden.
- [ ] Dateien lesen, offline bereitstellen, abmelden, Berechtigung widerrufen.
- [ ] Kein Client-Geheimnis in App, Repository oder APK hinterlegen.

Ergebnisse mit Gerät, Android-Version, Buildnummer, Datum und reproduzierbaren
Schritten dokumentieren. Bis dahin bleiben diese Punkte ausdrücklich offen.
