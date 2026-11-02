# FLEX-Notes – Flutter-Wiederaufbau

Arbeitsbranch: **`fix/dialog-reference-audit`**, ausgehend von der unveränderten Sicherung
auf `recovery/webpreview`.

Das bearbeitbare Flutter-Projekt liegt unter [flutter_app/](flutter_app/README.md).
Version **0.16.0-rebuild.11+31** ist eine Rekonstruktion aus den Quellen 0.1.0+1,
dem HTML-Prototyp und der Webreferenz 0.15.3+19. Die originalen neueren
Flutter-Quellen fehlen weiterhin. Vollständige Funktions-/Pixelgleichheit wird
nicht behauptet; der [Prüfstand mit offenen Punkten](docs/rebuild/STATUS.md)
beschreibt den tatsächlichen Umfang.

Der nachgereichte Quellenfund `FLEX-Notes-Quellen-9e5e4b6b8e8c.zip` enthält
**0.16.0-rebuild.4+24**. Dieser bearbeitbare Stand wurde übernommen und anhand
der aktuellen HTML-Datei (37) sowie der späteren Nutzerspezifikation korrigiert.
Das ist eine Weiterentwicklung der gefundenen Rekonstruktion, keine erneute
Rückkehr auf die kleinen 0.1.0-Quellen.

Aktuell: [Schülerkarten, Schülerdialog und Entwürfe](audit/SCHUELERKARTEN_ABGLEICH.md),
[Android-Tastaturkorrektur](audit/ANDROID_TASTATUR_FIX.md),
[Android-Testapp installieren und bauen](flutter_app/ANDROID-TEST.md),
[Android-Anpassungen und Prüfungen](audit/ANDROID_TESTAPP.md).

Wischen, Größenregler und Symbolbedienung — [Änderungen und Prüfungen](audit/SWIPE_DESIGN_ABGLEICH.md).

Vorherige Übersicht, Flächen, Orga-Listen und Modalzugänge: [Änderungen und Prüfungen](audit/UEBERSICHT_ORGA_ABGLEICH.md).

Vorherige Entwurfs-, HÜ- und Kompaktkorrekturen: [Änderungen und vollständiger Prüfumfang](audit/UI_UX_PRUEFUNG.md).

Vorheriger Settings-Abgleich und direkte Karten-Shortcuts: [Abgleich und Prüfungen](audit/SETTINGS_ABGLEICH.md).

Dialogaudit der vorherigen Runde: [Dialogverzeichnis](audit/DIALOGVERZEICHNIS.md),
[Vergleich mit Korrekturen und verbleibenden Abweichungen](audit/FLUTTER_ABGLEICH.md),
[Prüfungen und direkte Renderings](audit/PRUEFNACHWEIS.md).
Import-Zusammenführung und vollständige feldweise Konfliktauflösung bleiben offen.

Nachgereichte App-Details und ihre Umsetzung sind unter
[App-Referenz aus dem alten Chat](docs/rebuild/APP-DETAILS-AUS-ALTEM-CHAT.md)
festgehalten. Der im gefundenen Archiv dokumentierte frühere UI-Schritt korrigierte Navigation, Schülerkarten,
Suchbedienung und Modalrahmen; neue direkte Flutter-Ansichten stehen unter
[Renderings](docs/rebuild/renderings/). Die inzwischen gelieferten Dialog- und Kalender-Screenshots sind im
[Dialog-Abgleich](docs/rebuild/DIALOG-ABGLEICH.md) umgesetzt. Die dunkle
Originaltextur ist als App-Asset enthalten.

## Start und Prüfung

```sh
cd flutter_app
python3 tool/prepare.py
flutter analyze --no-pub
flutter test
flutter build web --no-web-resources-cdn
python3 tool/serve_preview.py --port 8081
```

Flutter 3.47.9 / Dart 3.13.7; Details für Windows, Android und die Cloud-Vorschau
stehen in der [Projektanleitung](flutter_app/README.md). Keine HTML-Einbettung,
keine Browsertests und keine Veröffentlichung der Cloud-Umgebung.

## Unveränderte Wiederherstellungsbasis

| Bestand | Ablage |
| --- | --- |
| Flutter-Originalquellen **0.1.0+1**, zwei ZIPs | [Quellarchive](recovery/flutter-sources/0.1.0+1/) |
| Gebautes Webpreview **0.15.3+19**, Original-ZIP | [Webpreview](recovery/webpreview/0.15.3+19/) |
| Ursprünglicher Prüfbericht | [PRUEFBERICHT.md](recovery/webpreview/0.15.3+19/PRUEFBERICHT.md) |
| HTML-Prototyp und ursprüngliche Unterlagen | [work/FLEX-Notizbuch/](work/FLEX-Notizbuch/) |
| Schema 7 und Dokumentation aus 0.15.3 | [Referenz](reference/webpreview-0.15.3+19/) |
| Historische Flutter-0.1-Anleitungen | [Referenz](reference/flutter-0.1.0/) |

Der Code im aktiven `flutter_app/` wird rekonstruiert; die Originalarchive bleiben
bytegleich. Ihre Versionen werden nicht vermischt oder umetikettiert.
`NEUE_DATEIEN.txt` und `PAKET_MANIFEST.sha256` sind historische Inhaltsnachweise
des 0.1.0-Archivs, kein Manifest des aktuellen Wiederaufbaus.

Originalintegrität vom Repository-Wurzelverzeichnis prüfen:

```sh
sha256sum -c recovery/SHA256SUMS
```

Vollständige Quellenpakete des aktuellen Commits erzeugen:

```sh
python3 flutter_app/tool/package_sources.py --output /gewünschter/ausgabeordner
```

Der Export erzeugt ein Repository-Quellenpaket einschließlich aller Referenzen
und Originalarchive sowie ein eigenständiges Flutter-Quellenpaket, beide mit
Commit-ID und SHA-256. Caches und Build-Ausgaben gehören nicht zu den Quellen.
