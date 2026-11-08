# FLEX Test · Build 53

Version **0.16.0-rebuild.33+53** · Quellstand `58e350deea683dd88832f59a608cc223c768ed6d`.

- Reversible Seitenbearbeitung: Filter bleiben nach Werkzeugwechseln anpassbar. Rückgängig/Wiederholen, Originalvergleich und Zoom; geometrische Zwischenschritte werden verlustfrei verarbeitet, der Export bleibt JPEG/PDF.
- Dokumentfilter mit lokalem Helligkeitsausgleich und adaptivem Schwarzweiß für ungleichmäßig beleuchtete Seiten. Farbige Markierungen bleiben im Dokumentfilter erhalten.
- Zuschneiden mit präziser Eckenauswahl, Lupe, abgedunkeltem Außenbereich, Einrasten und umschaltbarer Vorschau an derselben Bildposition.
- Kompaktere Werkzeuge, Filtervorschauen und Seitenübersicht. Versehentlich entfernte Seiten lassen sich bis zum Schließen/Speichern wiederherstellen.
- Scans & Fotos: Suche bei Bedarf und nur nahe am sichtbaren Bereich geladene Vorschauen. Große Sammlungen, Sortierung, Auswahl, Tags und Papierkorb geprüft.
- Alle 465 Flutter-Tests lokal bestanden; 8 neue Scanner-Regressionstests. Browserdurchlauf mit synthetischem Dokument, Schatten und farbiger Markierung; PDF-Export geprüft. Statische Analyse ohne Befund.

[APK herunterladen](https://raw.githubusercontent.com/Flowzym/FLEX-Notes/refs/heads/fix/dialog-reference-audit/releases/android/build-53/FLEX-Test-0.16.0-rebuild.33%2B53-58e350deea68-universal.apk) · [Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/)

Android: gleiche App-ID und Signatur wie Build 52; als Update installierbar. Signatur, ZIP-Integrität, Manifest und native Bibliotheken geprüft. Keine physische Kameraaufnahme auf einem Android-Gerät getestet.

[APK in OneDrive](https://onedrive.live.com?cid=00B0037104A6A978&id=B0037104A6A978!s8d89b8ec13b14f1c9f43af6c34b1ee94) · Größe und Prüfsumme nach Upload abgeglichen.

GitHub CI: Formatierung, Analyse und Schema-Prüfung bestanden. Beide Versuche von [Lauf 42476226351](https://github.com/Flowzym/FLEX-Notes/actions/runs/42476226351) stoppten vor dem Teststart wegen einer Prüfsummenabweichung beim Download der nativen SQLite-Bibliothek. Die vollständige Testsuite, Android- und Web-Release-Builds wurden deshalb zusätzlich lokal verifiziert.
