# Build 48 – Dokumentvorschauen, Kalender und Scannerverwaltung

Version `0.16.0-rebuild.28+48` erweitert den bestehenden Flutter-Wiederaufbau.
Datenmodell, App-ID und Update-Signatur bleiben kompatibel. Die Inhalte bleiben
im bisherigen lokalen Arbeitsbereich; Navigation und Miniaturen kopieren keine
Schüler- oder Eintragsdaten in eine neue Datenbank.

## Navigation

- Unten: Kalender, Live, Organisation, Material, Mehr.
- Kalender: Kalender, Stundenplan, Aufgaben, Notizen. Kalender-/Stundenplan-Shortcuts
  übernehmen das betrachtete Datum; beide Ansichten behalten ihre eigene Auswahl.
- Live: Aktuell, Notizen (Schüleraufzeichnung), Ablauf. Kein doppelter Stundenplan.
- Allgemeine Aufgaben und Notizen verwenden vorhandene Orga-Einträge ohne Schülerzuordnung.
  Der bewährte Editor, Fristen, Erinnerungen, Erledigen, Anhänge und Entwürfe bleiben verfügbar.
- Organisation: Orga und Rückläufe. Kein zweiter Kalender.

## Vorschauen

Gemeinsame Miniaturen bei Dateien in Materiallisten, Schülerunterlagen, Einträgen,
HÜ-Aufgaben/Teilaufgaben, Kalenderdetails, Materialauswahl und Scanentwürfen.
PDF: erste Seite. Fotos: ausgerichtete Bildvorschau. DOCX: Textauszug.

Maximal zwei parallele Lade-/Rendervorgänge und 64 kleine Vorschauen im Arbeitsspeicher.
Vorschauen werden nicht zusätzlich dauerhaft gespeichert. Geänderte, ersetzte und
wiederhergestellte Dateien erhalten eine neue Vorschau; alte Pixel werden beim
Quellwechsel sofort ausgeblendet. Schwärzungen in übernommenen Seiten bleiben eingebrannt.

OneDrive-Dateien können bei bestehender App-Verbindung die von Microsoft bereitgestellte
Miniatur verwenden. Graph-Zugangstoken werden nicht an den Thumbnail-CDN-Server gesendet.
Ohne verfügbare lokale Datei bzw. erreichbare Cloud-Vorschau erscheint ein gekennzeichneter
Platzhalter. Für beliebige externe Links wird kein Dokumentinhalt ungefragt heruntergeladen.

## Scanner: an Dokument-Scanner-Abläufen orientiert

Referenz: [CamScanner-Hilfe](https://www.camscanner.com/faq?category=create-save).
FLEX behält seine Gestaltung und kontextbezogene Zuordnung.

- Verwaltung mit großem Vorschauraster, Listenansicht, Namens-/Schüler-/Tag-Suche,
  Format- und Tagfiltern, Sortierung nach Aktualität oder Name.
- Mehrfachauswahl, additive Tags und gemeinsames Verschieben in den Papierkorb bzw.
  Wiederherstellen. Änderungen erfolgen über den vorhandenen transaktionalen Speicher.
- Seiten stehen im Scaneditor vor den Zuordnungsfeldern. Raster und Liste bieten
  Bearbeitung, Bildersetzung, Löschen und Umsortieren per Ziehen oder Pfeilen.
- Aufnahme, Serienaufnahme, Foto und Import befinden sich in der unteren Werkzeugleiste;
  Speichern und Fortsetzen bleiben erreichbar. Kameraaktionen stehen auf Android bereit.
- Der Seiteneditor zeigt größere Filtervorschauen und eine untere Werkzeugleiste für
  Zuschnitt, Filter, Schwärzung, Drehung, Spiegelung bei Fotos und Zurücksetzen.
- Filter lassen sich mit Vorschau gemeinsam auf alle Seiten anwenden. Erst wenn alle
  neuen Seiten geschrieben sind, werden die geordneten Entwurfsreferenzen aktualisiert.
  Ein fehlgeschlagenes Schreiben kann erneut versucht werden; vorherige Dateien werden
  erst nach erfolgreicher Speicherung bereinigt.

Die bestehende Kantenerkennung, einrastende Zuschnittpunkte, Live-Bildanpassung,
Foto-Wiederherstellung nach Prozessunterbrechung und PDF-/JPG-Ausgabe bleiben erhalten.
Es handelt sich nicht um vollständige CamScanner-Funktionsgleichheit; OCR und durchsuchbare
PDFs sind nicht Bestandteil dieser Änderung.
