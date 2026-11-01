# FLEX-Notes – Flutter-Wiederaufbau

Arbeitsbranch: **`rebuild/flutter`**, ausgehend von der unveränderten Sicherung
auf `recovery/webpreview`.

Das bearbeitbare Flutter-Projekt liegt unter [flutter_app/](flutter_app/README.md).
Version **0.16.0-rebuild.1+21** ist eine Rekonstruktion aus den Quellen 0.1.0+1,
dem HTML-Prototyp und der Webreferenz 0.15.3+19. Die originalen neueren
Flutter-Quellen fehlen weiterhin. Vollständige Funktions-/Pixelgleichheit wird
nicht behauptet; der [Prüfstand mit offenen Punkten](docs/rebuild/STATUS.md)
beschreibt den tatsächlichen Umfang.

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
