# Navigation · 0.21.2+66

Die untere Leiste markiert den aktiven Bereich mit einer kurzen olivfarbenen
Linie und einer stärkeren Beschriftung. Die große Farbfläche entfällt. Alle
fünf Symbole verwenden dieselbe Zeichenfläche und Strichstärke; die Anordnung
und Berührungsflächen bleiben erhalten.

Die oberen Reiter sind in Kalender, Live, Organisation, Material und Mehr per
Wischen erreichbar. Das funktioniert im Seiteninhalt und auf der oberen Pille.
Am Anfang und Ende bleibt die Auswahl stehen. Eigenständige horizontale
Bedienelemente wie Regler und Textauswahl behalten ihre Gesten; vertikales
Scrollen wechselt keine Seite.

Live startet mit **Notizen → Aktuell → Ablauf**. Interne Seitenkennungen bleiben
unverändert; die sichtbare Reihenfolge und der Zurück-Einstieg sind angepasst.
Sucheingaben und Scrollpositionen der Schülerliste bleiben beim Wechsel erhalten.

## Validierung

Die Prüfung umfasst die vollständige Flutter-Testsuite, gezielte Navigationstests,
die UI-Matrix bei 320–1280 Pixel Breite einschließlich großer Schrift sowie
Touch-Gesten im Release-Browser bei 390 × 844. Der neue Navigationstest prüft alle
fünf Bereiche in beide Richtungen, die Grenzen und die Bedienung des Schriftreglers.
Ältere UI-Tests öffnen die Übersicht jetzt ausdrücklich über „Aktuell“.

Statische Analyse ohne Befunde; Formatierung geprüft. Android- und Web-Release
gebaut. APK-Signatur, Kennung, Version, ZIP-Integrität und 16-KB-Ausrichtung geprüft.
Physische Android-Abnahme bleibt offen. Die konkreten Testzahlen und Protokolle
stehen im [Releasebericht](../../releases/android/build-66/README.md).

Datenmodell, Sicherungen und Speicherverhalten sind unverändert. Build 66
aktualisiert die neue FLEX aus Build 62–65 mit derselben Kennung und Signatur.

[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/) ·
[Android-APK und Prüfnachweise](../../releases/android/build-66/README.md).
