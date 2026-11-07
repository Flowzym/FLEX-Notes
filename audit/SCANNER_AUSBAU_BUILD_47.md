# Scannerausbau und kompakte Oberfläche – Build 47

Version **0.16.0-rebuild.27+47**, Branch `fix/dialog-reference-audit`.

## Bedienung

Unter **Bearbeiten → Zuschneiden** erkennt FLEX Dokumentränder lokal im Bild.
Vier Ecken können nachgezogen werden; **Einrasten** bindet sie innerhalb einer
kleinen Bildschirmdistanz an erkannte Ecken oder Bildkanten. Unsichere Bilder
bleiben unbeschnitten. Eine separate Vorschau zeigt die entzerrte Seite.
Beim Wechsel zu einem anderen Werkzeug wird der Zuschnitt übernommen.

Die Bildbearbeitung öffnet direkt mit Filtervorschau: Original, Dokument,
Graustufen, Schwarzweiß, Warm und Kühl. Kleine Bilder zeigen die Filterwirkung;
Helligkeit, Kontrast und bei Fotos Sättigung verändern die große Vorschau.
Vorschaurechnungen verwenden verkleinerte Bilder; gespeichert wird mit der
bisherigen Auflösung (maximal 2400 Pixel längste Seite). Veraltete Vorschauen
überschreiben keine neuere Einstellung. Schwärzungen werden weiterhin in die
Pixel eingerechnet, ohne versteckte PDF-Texte oder rückholbare Überlagerungen.

**Mehrfachaufnahme** nimmt mit der normalen Android-Kamera mehrere Seiten/Fotos
auf. Nach jeder Aufnahme: Vorschau, **Nächste Aufnahme** oder **Fertig**.
Jede Aufnahme wird sofort als Entwurf gesichert. Der vorhandene native
Dokumentenscanner bietet weiterhin seine eigene Serienaufnahme. Pro Sammlung
sind bis zu 25 Seiten möglich. Aufnahmen lassen sich an gleicher Position durch
eine Datei oder neue Aufnahme ersetzen, am Griff ziehen oder mit Pfeilen reihen.
Abbruch und fehlgeschlagene Speicherung löschen keine bisher referenzierten Bilder.

**Mehr → Scanner** sammelt Scans, Fotos und Scanentwürfe. Suche nach Namen, Tags
oder Schülern; Filter für PDF/Fotos; Bearbeiten, Öffnen und Exportieren über die
vorhandenen Dateifunktionen. Dateien können in den Papierkorb gelegt und
wiederhergestellt werden. Material und Scannerverwaltung zeigen dieselben Dateien.
Alte Scan-PDFs und lokale Scannerfotos werden ebenfalls erkannt.

Der Tab **Aufzeichnung** heißt **Notizen**. Die obere Navigationsspur ist größer,
die aktive Pille behält ihre Größe. Darüber steht links dezent **FLEX.** mit
zusätzlichem Randabstand. Die untere Leiste ist schwarz. Schülercards haben kleinere
Abstände. Die Übersicht zeigt kompakte Zähler; Anlegen-Aktionen stehen als reine
Symbole rechts beim Titel, mit Beschriftung für Screenreader und Tooltips.

## Daten und Grenzen

Keine SQL-Schemaänderung. Das optionale Materialmerkmal `scanner` kennzeichnet
neue Scannerfotos und -PDFs; alte Dateien brauchen keine Migration. Daten,
Zuordnungen und Scanentwürfe bleiben erhalten. App-ID und Testsignatur bleiben
unverändert; Installation als Update über FLEX Test ist vorgesehen.

Kantenerkennung erfolgt bei der Bearbeitung eines aufgenommenen/importierten Bildes;
sie ist keine neue Kamera-Liveansicht. Die Qualität hängt von sichtbaren Rändern,
Kontrast und Perspektive ab. Die automatische Erkennung ersetzt die manuelle
Kontrolle nicht. Web unterstützt Bild-/PDF-Import, Android zusätzlich die Kamera.
Eine Prüfung auf einem physischen Android-Gerät ist weiterhin offen.

## Prüfung

Die neuen Tests decken Perspektive, Drehung, ungleichmäßiges Licht, Bildrauschen,
Snapping-Abstände, Filtervorschau und volle Exportauflösung, Werkzeugwechsel,
Mehrfachaufnahmen, Abbruch, dauerhafte Seitenreihenfolge, Bildersetzung mit
Speicherfehler sowie Suche, Filter und Wiederherstellung der Scannerverwaltung ab.
Die vollständigen Testergebnisse und Veröffentlichungsnachweise werden nach
Abschluss unter `scanner-ausbau-build47/` abgelegt.
