# Kalender, Entwicklung und Dokumentkamera · 0.25.0+75

Die Monatsansicht erhält ein durchgehendes feines Raster zwischen allen Tagen,
auch in den leeren Zellen am Monatsanfang und -ende. Tagesauswahl, Markierungen
und die vorhandene Zeitraum-Navigation bleiben nutzbar.

## Entwicklung

Das Schüler-Entwicklungsmodal verwendet kurze, nach Wochen gruppierte Einträge
anstelle großer vollständiger Eintragskarten. Die jüngste belegte Woche ist
geöffnet. Zeitraum, Bereich und Tonart lassen sich direkt wählen; häufige Themen
führen zu den zugehörigen Beobachtungen. Die Suche erreicht auch alle übrigen
Tags und Freitexte. Es werden dokumentierte Einträge gezählt, keine allgemeinen
Bewertungen des Schülers; mehrere Tonarten pro Eintrag bleiben möglich.

Ein Antippen öffnet den Originaleintrag mit seinen bisherigen Aktionen. Reine
Arbeitsaufträge ohne Beobachtungstext zeigen ihren Auftrag bzw. ihre verknüpfte
Planung. Ausgewählte Einträge lassen sich in die Gesprächsvorbereitung übernehmen.
Ein Filterwechsel leert die Auswahl, damit keine unsichtbaren Einträge unbemerkt
übernommen werden. Ziele und Überprüfungen bleiben als eigener aufklappbarer
Bereich erreichbar. Datenmodell und gespeicherte Einträge werden nicht verändert.

## Ränder während der Aufnahme

Der vorhandene native Android-Dokumentenscanner (Google ML Kit, FULL-Modus)
erkennt Dokumentränder in seiner Kameraoberfläche vor der Aufnahme. Jetzt nutzen
auch **Dokument-Serien** und **Dokumentseite ersetzen → Neu aufnehmen** diesen
Aufnahmeweg. Zuvor starteten diese Wege die gewöhnliche Fotokamera. Beim Ersetzen
wird genau eine Seite angefordert; die übrige Reihenfolge bleibt bestehen.
Normale Fotos verwenden weiterhin die Fotokamera.

Wenn die Dokumentkamera nicht verfügbar ist, bietet ein Dialog ausdrücklich
„Ohne Randerkennung“ als Alternative an. Die App wechselt nicht mehr unbemerkt
auf eine einfache Kamera. Dafür werden funktionierende Google Play-Dienste
benötigt. Vor dem Kamerawechsel wird der Scanentwurf gesichert; ein Abbruch ohne
aufgenommene Seiten hinterlässt keinen leeren Entwurf.

Es handelt sich um die konsequente Verwendung des vorhandenen Android-Scanners,
nicht um einen neuen eigenen Erkennungsalgorithmus. In der Webvorschau bleibt
der Datei-/Bildimport verfügbar. Die physische Aufnahme, Randgenauigkeit bei
verschiedenen Lichtverhältnissen und Installation auf einem Handy sind noch
nicht abgenommen.

## Prüfung

59 betroffene Tests erfolgreich über mehrere Läufe: Entwicklung, Klassen-UI,
Kalender-UI und Scanner. Im ersten Lauf bestanden 55 von 58 Tests; drei bestehende
Scanner-Testabläufe benötigten Anpassungen an die neue Dokumentserie bzw. den
expliziten Fallbackdialog und bestanden danach. Ein zusätzlicher Test für reine
Arbeitsaufträge entstand aus der Browserprüfung; alle drei Entwicklungstests
bestanden abschließend erneut. Keine vollständige Testsuite in diesem Build.

Statische Analyse ohne Befunde. Release-Webbuild mit lokalen Webressourcen
(`--no-web-resources-cdn`) und signierte Android-Universal-APK. Signatur, Kennung,
Version, ZIP-Integrität, drei Architekturen und 16-KB-Ausrichtung geprüft.

Browserprüfung mit synthetischen Daten bei 320 und 390 Pixeln: Monatsraster,
Entwicklungsübersicht, Filter, Auswahl, Originaleintrag und Ziele. Screenshots und
Protokolle: [evidence/build-75](evidence/build-75/).

[APK und Installationshinweise](../../releases/android/build-75/README.md) ·
[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).
