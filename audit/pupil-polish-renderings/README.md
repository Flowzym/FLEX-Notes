# Direkte Flutter-Renderings: Schülerkarten und Dialog

20 PNGs aus `test/pupil_polish_test.dart`, synthetische Schüler und Einträge.
Dateinamen: Ansicht, Breite, Systemschriftfaktor, App-Skalierung in Prozent.
Jede der fünf Konfigurationen enthält Karten, Schülerübersicht, Sozial- und Arbeitstags.

Konfigurationen: 320/390/1200 Pixel bei Standardgröße, 320 Pixel bei doppelter
Systemschrift und 320 Pixel bei 120 % App-Skalierung; jeweils 1000 Pixel Höhe.
Dies sind direkte Flutter-Engine-Renderings, keine Android- oder Browser-Screenshots.

Manuell betrachtet: Karten und Sozialtags bei 390 Pixel, Schülerübersicht bei
390 und 1200 Pixel sowie 320 Pixel mit doppelter Schrift und mit 120 % Skalierung.
Symbole und Beschriftungen stehen mittig; Zahlenbadges überlagern die Symbole nicht.
Der Schülerdialog nutzt bei kleiner Breite getrennte Zeilen für Name und Kopfaktionen.
Bei doppelter Schrift bleiben starke Umbrüche in langen Eintragstiteln; der Inhalt
ist scrollbar. Die Lesbarkeit wurde nicht durch Begrenzen der Systemschrift erkauft.

Prüfsummen aller PNGs: [SHA256SUMS](SHA256SUMS).
