# Bereichsnavigation, Fotos und Tags – Build 45

Version: **0.16.0-rebuild.25+45**. Arbeitsbranch: `fix/dialog-reference-audit`.

## Bedienung

Die untere Leiste enthält Übersicht, Live, Organisation, Material und Mehr.
Übersicht und Live → Ablauf sind ausdrücklich Platzhalter. Die App startet bei
Live → Aktuell, der bisherigen Übersicht. Live → Aufzeichnung ersetzt die bisherige
Schüler-Navigation. Live → Stundenplan und Organisation → Kalender verweisen direkt
aufeinander und übernehmen das ausgewählte Datum. Wiederholtes Wechseln berücksichtigt
auch zwischenzeitlich manuell geänderte Daten. Live bleibt per Wischen bedienbar.

Material enthält Dateien, Bereitgelegt, Pakete und Planungen. Mehr enthält Archiv,
Papierkorb, Daten, Einstellungen sowie Entwürfe, Klassen-Orga, Rückläufe,
Gruppenerfassungen, Konflikte und den Material-Papierkorb. Daten ist eine eigene Seite;
Einstellungen enthält Darstellung und Bedienung.

Die oberen Pillen zeigen nur die Unterseiten des jeweiligen Bereichs. Ihr Grundkörper
ist flacher; die aktive Pille steht seitlich sowie oben und unten über. Bei Platzmangel
werden alle Ziele auf weitere Zeilen verteilt. Navigationsbeschriftungen skalieren
oben bis 150 %, unten bis 130 %, damit auch mit stark vergrößerter App und Schrift
Inhalt erreichbar bleibt. Die Schrift der Inhalte bleibt davon unabhängig.
Der Kalender kann bei geringer Höhe zusätzlich als Ganzes gescrollt werden.

## Scan und Foto

Der bestehende Scanner hat eine separate Aktion **Foto aufnehmen** für Android.
Sie verwendet die installierte Kamera ohne Dokumenterkennung und benötigt keine
Google-Play-Dienste. Der Dokumentenscan versucht ML Kit und wechselt bei nicht verfügbarer Dokumenterkennung
automatisch zur normalen Kamera. Dabei bleibt die Ausgabe auf PDF und die Aufnahme
erhält die Dokumentwerkzeuge. Native Kamerafehler werden verständlich angezeigt,
statt pauschal einen Speicher- oder Berechtigungsfehler zu behaupten. Im Browser können
Bilder und PDFs über die Dateiauswahl hinzugefügt werden.

Fotos haben rechteckigen Zuschnitt, Drehen, Spiegeln, Original/Warm/Kühl/Schwarzweiß,
Helligkeit, Kontrast, Sättigung und Schwärzung. Die Ausgabe ist wahlweise eine gemeinsame
PDF oder je Bild ein JPG mit fortlaufender Benennung. JPGs lassen sich in Material
öffnen, vergrößern, erneut bearbeiten und exportieren. Bilder werden bis 20 MB bzw.
40 Megapixel angenommen und auf maximal 2400 Pixel Kantenlänge normalisiert; Metadaten
und eingebettete Vorschauen werden entfernt. Schwärzungen werden in Pixel eingerechnet.

Tags werden mit Komma getrennt eingegeben, Leerwerte entfernt und gleiche Tags ohne
Beachtung der Groß-/Kleinschreibung zusammengeführt. Sie bleiben in Entwürfen,
Materialien und verschlüsselten Materialsicherungen erhalten und werden mit durchsucht.
Schüler- und Eintragszuordnungen sind bei PDF und JPG gleich.

Die Kameraablage bleibt bis zur bestätigten Entwurfsspeicherung erhalten. Nach einem
Neustart kann der zugehörige Entwurf die Aufnahme wiederherstellen. Mehrere JPGs werden
in einer Datenbanktransaktion eingetragen; Fehler behalten den Entwurf und entfernen
nur die neuen, nicht übernommenen Ausgabedateien. Bestehende Dateien werden nur über
die ausdrückliche Ersetzen-Option und mit Revisionsprüfung ersetzt.

## Daten und Grenzen

Keine Datenbankmigration oder Löschung bestehender Einträge. Android-Anwendungs-ID
und Signatur bleiben gleich. Aktualisierung über die bestehende App installieren.
Die private Webvorschau bleibt auf derselben Adresse. Kein automatischer OneDrive-Upload
von Fotos. Notebook-Sicherungen enthalten Dokumentmetadaten; die Dateien selbst gehören
weiterhin in die separate Materialsicherung. Entwurfsbilder bleiben lokal.

Die echte Kameraübergabe muss zusätzlich auf einem physischen Android-Gerät geprüft
werden; in dieser Umgebung steht keines zur Verfügung. Automatisierte Tests prüfen
unter anderem Wiederaufnahme, Speicherausfälle, JPG/PDF, Tags, Zuordnungen,
Materialsicherung und die Navigation bei schmalen Ansichten und großer Schrift.

## Durchgeführte Prüfungen

- 397 Flutter-Tests mit Coverage, darunter Kamera-Ausweichweg, konkrete native Fehler,
  Aufnahme-Wiederherstellung, Tags, JPG-Sicherung, atomare Speicherung und große Schrift.
- Strenge Analyse und Formatprüfung ohne Befund; 11 SQLite- und drei HTTP-Tests.
- Chromium bei 390 × 844: Bereichsnavigation und Kalender-/Stundenplan-Wechsel,
  Fotoimport, Benennung, Tags, warmer Filter mit echter Zeigerbedienung, Entwurf schließen,
  Seitenneuladen, Wiederaufnahme, JPG speichern, herunterladen und öffnen.
  Export mit Pillow geprüft: JPEG 600 × 800, keine EXIF-Metadaten, Farbfilter sichtbar.
- APK-Manifest, Update-Signatur, ZIP-Ausrichtung und 64-Bit-ELF-Ausrichtung geprüft.
  Download auf GitHub: HTTP 200, vollständige Dateigröße und APK-Kennung.
  OneDrive: Dateigröße und QuickXor-Prüfsumme identisch.
- Private Webvorschau auf derselben Adresse erfolgreich aktualisiert; weiterhin
  nur Eigentümerzugriff. Keine Nutzerinhalte in den ausgelieferten Dateien.

[Prüfdateien und synthetische Bildschirmaufnahmen](navigation-fotos-build45/) ·
[Android-Download](../releases/android/build-45/README.md) ·
[GitHub-Pipeline](https://github.com/Flowzym/FLEX-Notes/actions/runs/42398342688).
