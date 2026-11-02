# FLEX-Dialogaudit

Maßgeblicher Arbeitsstand: **0.16.0-rebuild.11+31**, korrigiert auf Grundlage des nachgereichten Quellen-ZIP **0.16.0-rebuild.4+24**. Keine Freigabe als „originalgetreu“.

- [Schülerkarten und Entwürfe](SCHUELERKARTEN_ABGLEICH.md): kompakte Tags, zentrierte Symbole, neuer Schülerdialog und Entwürfe löschen.
- [Android-Tastaturkorrektur](ANDROID_TASTATUR_FIX.md): Fokus und Tastaturverbindung bei wechselnder Dialoghöhe erhalten.
- [Erste Android-Testapp](ANDROID_TESTAPP.md): Universal-APK, eigene App-ID und Android-Speicherdialog.
- [UI-Prüfstand](SWIPE_DESIGN_ABGLEICH.md): Wischen, unabhängige App-/Schriftgröße, zusätzliche Rundungen und Symbolbedienung; 157 Tests und 186 direkte Renderings.
- [Vorheriger UI-Abgleich](UEBERSICHT_ORGA_ABGLEICH.md): Übersicht, neutrale Flächen, Orga-Listen, Zahlenbadges und Zugänge über den Modalkopf; 145 Tests und 168 direkte Renderings.
- [Dialogverzeichnis](DIALOGVERZEICHNIS.md): alle 22 tatsächlich vorhandenen Dialogtypen; Originalfolge, Texte, Zustände, Datenbeziehungen und spätere Nutzeränderungen.
- [Flutter-Abgleich](FLUTTER_ABGLEICH.md): je Dialog Abweichung im gefundenen Quellstand, konkrete Korrektur und noch offene Unterschiede.
- [Prüfnachweis](PRUEFNACHWEIS.md): lokale Tests, direkte Engine-Renderings, tatsächlich betrachtete Bilder und Grenzen.
- [Elemente und Zustände](DOM_ELEMENTE.md): automatisch erzeugte elementweise Detailaufnahme von 65 HTML-Quellzuständen; kein Rendering.
- [Originalmeldungen](ORIGINALMELDUNGEN.md): statische Fundstellen, einschließlich historischer, später überschriebener Funktionen.
- `reference/`: unveränderte aktuelle HTML-/Spezifikationskopien, 18 historische Berichte, alte Flutter-0.1-Quellen. Der **aktive** Code liegt unter `../flutter_app/`.
- `evidence/`: Herkunft, Hashnachweise, aktueller Analyselauf/Gesamttest, Quelle-zu-Quelle-Patch und Manifest.
- `renderings/`: synthetische Flutter-PNGs, Manifest und dokumentierte Sichtprüfung.

HTML-Quelleninspektion reproduzieren:

```sh
npm ci --prefix audit/tools --cache /tmp/flex-audit-npm-cache --no-audit --no-fund
node audit/tools/inspect-dom.cjs
python3 audit/tools/export-elements.py
```

Der Node/jsdom-Lauf verwendet synthetische Daten, Ersatzfunktionen für native Dialog-/MediaQuery-/Animationsaufrufe und keine CSS-Layoutengine. Bekannte CSS-Ausblendungen werden markiert. Er ist kein Browserlauf und kein visueller Nachweis. Davon getrennt erzeugt `flutter test` echte Flutter-Bilder; siehe Prüfnachweis.

Der [frühere Abgleich mit 0.1](FLUTTER_ABGLEICH_0.1_HISTORISCH.md) beschreibt ausschließlich den damaligen Zwischenstand vor dem Quellenfund. Die dortige Quellblockade ist aufgehoben.
