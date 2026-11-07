# Dokumentenscanner · Build 44

FLEX erhält einen gemeinsamen Scanner mit direkten Zugängen bei Schülern,
Orga, Zielen, Beobachtungen, Hausübungen, Unterrichtsstunden, Planungen,
Materialpaketen, Rücklauflisten und Gesprächsunterlagen. Ein Dokument wird
einmal gespeichert und kann mehreren Einträgen zugeordnet werden.

## Bedienung

- **Dokumente** öffnet die zugehörigen PDFs und Scanentwürfe. Bei neuen
  Orga-/Schülereinträgen speichert **Speichern und Dokumente öffnen** zuerst
  den validierten Eintrag; erst dann wird der Scanner zugeordnet geöffnet.
- **Scannen** startet auf Android die Dokumentkamera mit Kantenerkennung und
  Perspektivkorrektur. **Bilder / PDF hinzufügen** ist auch im Browser verfügbar.
- Name, Kategorie, Schüler und Eintragszuordnungen sind im Scanner sichtbar
  und veränderbar. Die Vorschläge stammen aus dem aufrufenden Bereich, nicht
  aus einer automatischen Analyse personenbezogener Bildinhalte.
- Mehrere Seiten lassen sich bearbeiten, sortieren und entfernen. Je Seite
  stehen Vierpunkt-Zuschnitt, Drehen, Farbe/Graustufen/Schwarzweiß, Helligkeit,
  Kontrast und rechteckige Schwärzungen zur Verfügung.
- **Später fortsetzen** sichert den Entwurf. Er ist beim zugehörigen Eintrag
  und in der allgemeinen Entwurfsliste erreichbar und löschbar.
- **PDF speichern** erzeugt eine lokale PDF und öffnet ihre Dokumentaktionen.
  Vorhandene PDFs können als Kopie bearbeitet oder ausdrücklich ersetzt werden.
  Ersetzen prüft die ursprüngliche Revision und überschreibt keine inzwischen
  geänderte Fassung.

## Dateien, Zuordnungen und Schwärzung

Android speichert Dateien im privaten App-Bereich, die Webversion in IndexedDB
am bisherigen Ursprung. Seiten sind auf 2400 Pixel Kantenlänge, 25 Seiten pro
Dokument und 20 MB pro Ausgabe begrenzt. Bei einer fehlgeschlagenen
Metadatenspeicherung bleiben die Seiten für den nächsten Versuch erhalten.
Ein gescheiterter PDF-Abschluss lässt den Entwurf bestehen; eine neu geschriebene,
nicht referenzierte PDF wird wieder entfernt.

Die PDF wird ausschließlich aus neu erzeugten Seitenbildern aufgebaut.
Bildmetadaten und eingebettete Vorschaubilder werden verworfen. Importierte PDFs
werden gerastert; ursprüngliche Textobjekte, Formulare, Anlagen, Aktionen und
Metadaten gelangen nicht in die Ausgabe. Schwärzungen ersetzen die Pixel vor
dem PDF-Aufbau. Sie sind keine abziehbaren schwarzen PDF-Overlays. Bestehende
Originale, zuvor exportierte Kopien und frühere Sicherungen werden dadurch
nicht nachträglich verändert. Bereits in eine Seite übernommene Schwärzungen
lassen sich durch spätere Filter nicht entfernen.

Zuordnungen werden beim Speichern gegen vorhandene Einträge geprüft. Beim
endgültigen Leeren des Eintragspapierkorbs bleiben PDF und Schülerzuordnung
erhalten; nur der entfernte Eintragsbezug entfällt. Noch verknüpfte Scanentwürfe
müssen vorher bearbeitet oder verworfen werden. Verknüpfte Scans erscheinen
auch bei der betreffenden Unterrichtsstunde und ihren Materialvorschlägen.

## Sicherung und Plattformgrenzen

Gespeicherte Scan-PDFs gehören zur vorhandenen **verschlüsselten Materialsicherung**.
Die normale Notizbuchsicherung enthält Metadaten und Verweise, keine Bild- oder
PDF-Dateien. Scanentwürfe sind für das Fortsetzen auf demselben Gerät gedacht;
ihre Seiten sind nicht Bestandteil der Materialsicherung. Für einen Gerätewechsel
Scans abschließen und Notizbuch- sowie Materialsicherung übertragen.

**Teilen / Exportieren** nutzt auf Android die System-Dateiauswahl. OneDrive kann
dort verwendet werden, sofern die installierte OneDrive-App einen Dateianbieter
bereitstellt. Automatischer OneDrive-Upload, Upload-Warteschlange und OCR sind
nicht Teil dieses Builds. Die bestehende direkte OneDrive-Anbindung bleibt lesend
und benötigt weiterhin eine Microsoft-Client-ID.

Die Android-Dokumentkamera benötigt Google Play-Dienste und gegebenenfalls einen
einmaligen Moduldownload. Auf Geräten ohne diese Dienste bleibt der Dateiimport.
Nach der Einrichtung laufen PDF-Erzeugung und Bearbeitung lokal. Eine Prüfung
an einem physischen Android-Gerät steht aus; insbesondere Kamera, erster
Moduldownload, Hintergrundwechsel und OneDrive-Dateianbieter sind dort noch
abzunehmen. App-ID, Signaturschlüssel und SQLite-Schema bleiben unverändert.

## Automatische Prüfung

Neue Tests prüfen Normalisierung, Metadatenentfernung, tatsächliche PDF-Rasterung,
fehlende Textebene nach Schwärzung, sichtbare schwarze Pixel, Entwürfe nach
Schreibfehlern, Revisionen, Mehrfachzuordnungen, Dateibereinigung und Sicherungen.
Widgettests prüfen Import, Fokus während automatischer Sicherung, Fortsetzen,
Sortieren, PDF-Abschluss, Kameraabbruch, Entwurfslöschung sowie die Koordinaten
der Schwärzung in Hoch-/Querformat auf 320 Pixel breiten Displays.

Die zusätzlichen Kopfaktionen umbrechen bei schmaler oder vergrößerter Darstellung,
damit vorhandene Navigation, Entwürfe und HÜ-Zugänge bedienbar bleiben.
Lokal erfolgreich: **390 Flutter-Tests mit Coverage**, strenge Analyse ohne
Warnungen, unveränderte Formatierung, elf SQLite- und drei HTTP-Tests. Der
Android-Releasebuild ist signiert und enthält alle drei bisher unterstützten
Architekturen. App-ID, Manifest, ZIP-Ausrichtung und 16-KB-Ausrichtung sämtlicher
64-Bit-Bibliotheken wurden geprüft; die ältere ARMv7-PDFium-Bibliothek nutzt 4 KB.

Der fertige Webbuild wurde im lokalen Chromium bei 390 × 844 und 1280 × 900
Pixeln mit synthetischen Daten geprüft: Bild-/PDF-Import, Name und Eingabefokus,
Neuladen und Fortsetzen, mehrseitige PDF, Download, PDF-Vorschau, automatischer
Orga-/Schülerbezug und Kategorie. Ein mit der Maus geschwärzter Ausschnitt wurde
übernommen, als PDF heruntergeladen und unabhängig mit PyMuPDF auf schwarze
Bildpixel und fehlende Textebene geprüft. Es wurden keine Browserfehler gemeldet.
Dies ersetzt keine Leistungs- oder Kameramessung auf einem physischen Android-Gerät.

[Scanner am Handy](dokumentenscanner-build-44/scanner-phone.png) ·
[PDF-Vorschau](dokumentenscanner-build-44/pdf-phone.png) ·
[Zuordnung beim Orga-Eintrag](dokumentenscanner-build-44/context-scanner-desktop.png) ·
[Schwärzung](dokumentenscanner-build-44/redaction-desktop.png) ·
[Browser-Prüfung](dokumentenscanner-build-44/result.json) ·
[Zuordnungs-/Schwärzungsprüfung](dokumentenscanner-build-44/context-result.json).

Die bestehende private [Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)
läuft am gleichen Ursprung auf Build 44. Alle generierten Dateien wurden vor
Veröffentlichung gegen den geprüften lokalen Build verglichen. Die Zugriffsliste
bleibt auf den Eigentümer beschränkt. [Bereitstellungsnachweis](dokumentenscanner-build-44/deployment.json).

Die [Android-APK](../releases/android/build-44/README.md) liegt auf GitHub und im
verifizierten persönlichen OneDrive. Direkter Download (HTTP 200, Größe und
APK-Kennung), Signatur, SHA-256 und OneDrive-Prüfsumme sind geprüft.
Quellcommit: `f4f82d8fe99b7d41112ca14be321f059a0dfa3bf`.

[GitHub-Testpipeline für diesen Quellstand](https://github.com/Flowzym/FLEX-Notes/actions/runs/42394089421).
