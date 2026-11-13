# Aktueller Stand: 0.21.3+67

Einheitlicher 140-ms-Übergang beim Tippen und Wischen zwischen allen oberen
Reitern. Kompakte Materialkarten mit integrierten Aktionen und kleineren
Vorschaubildern in der Listenansicht. Große Schrift bleibt unterstützt.

36 Navigations-/Materialprüfungen und 10 UI-Prüfungen bestanden; Analyse ohne Befunde.

[Änderungen und Prüfbericht](MOTION-MATERIALS-BUILD-67.md) ·
[APK und Prüfnachweise](../../releases/android/build-67/README.md).

---

# Vorheriger Stand: 0.21.2+66

Ruhige untere Navigation mit schmaler Aktivmarkierung und einheitlichen
Linienicons. Alle fünf Bereiche unterstützen Wischen zwischen den oberen
Reitern, auch direkt auf der Navigationspille. Live startet mit Notizen;
die Reihenfolge lautet Notizen, Aktuell, Ablauf.

[Änderungen und Prüfnachweise](NAVIGATION-BUILD-66.md) ·
[APK](../../releases/android/build-66/README.md).

---

# Vorheriger Stand: 0.21.1+65

Kompaktere Abstände zwischen FLEX., Schülername, Seitentitel und Navigation
in den gemeinsamen Eintragungsseiten. Im Arbeitsverhalten rücken Auftrag und
Beobachtung näher zusammen. Bedienflächen, Funktionen und Datenformat bleiben gleich.

21 gezielte UI-/Editorprüfungen bestanden, einschließlich großer Schrift und
verschiedener Bildschirmgrößen. Analyse ohne Befunde; Android- und Web-Release.

[Änderungen und Prüfbericht](SPACING-BUILD-65.md) ·
[APK und Prüfnachweise](../../releases/android/build-65/README.md).

---

# Vorheriger Stand: 0.21.0+64

Individuelle Materialzuordnung in der Schülerübersicht mit unabhängigen
Unterrichtsdaten, Kalenderzugriff und erhaltenen gemeinsamen Dateien.
Breitere Eintragungsköpfe; gleich breite Navigationssegmente mit lesbaren
Beschriftungen auch bei großer Schrift.

519 Flutter-Tests, 11 SQLite-Tests und 3 Servertests bestanden; Analyse ohne Befunde.

[Bedienung und Datenverträglichkeit](PUPIL-MATERIALS-BUILD-64.md) ·
[APK und Prüfnachweise](../../releases/android/build-64/README.md).

---

# Vorheriger Stand: 0.20.0+63

Gemeinsamer Kalender für Unterricht, Termine und Fristen. Separate
Stundenplan-Unterseite entfernt; Grundplan und Stundenzeiten bleiben direkt
bearbeitbar. Einzeltermine und Änderungen ab Datum sind klar getrennt.
Serienänderungen erhalten Dokumentzuordnungen, Planungen und Erinnerungen.

514 Flutter-Tests, 11 SQLite-Tests und 3 Servertests bestanden; Analyse ohne
Befunde. Android- und Web-Release gebaut, Smartphone-Browser geprüft.
Build 63 aktualisiert die neue FLEX aus Build 62 mit derselben Signatur.

[Änderungen und Datenverträglichkeit](CALENDAR-BUILD-63.md) ·
[APK und Prüfnachweise](../../releases/android/build-63/README.md).

---

# Vorheriger Stand: 0.19.1+62

Signierte Android-App **FLEX** mit eigener Kennung neben der vorhandenen FLEX Test.
Dauerhafter Schlüssel, öffentlich festgeschriebener Zertifikatfingerabdruck und
Release-Abbruch bei fehlendem oder falschem Schlüssel. GitHub CI baut ausdrücklich
unsigniert. 30 gezielte Sicherungs-/Materialtests sowie vier Signierprüfungen
bestanden; Android- und Web-Release gebaut und APK geprüft.

[APK und Prüfberichte](../../releases/android/build-62/README.md) ·
[Datenumzug](ANDROID-UMZUG-62.md) · [Buildnachweise und Grenzen](ANDROID-BUILD-62.md).
Physische Installation und Vergleich der persönlichen Daten stehen noch aus.

---

# Vorheriger Stand: 0.19.0+61

Auftragsquellen direkt im Arbeitsverhalten: FLEX-Planungen, Tagesmaterialien,
DOCX-/PDF-Aufgaben und weitere Materialien. Die HÜ-Abgabeprüfung entfällt;
X bietet erneutes Aufgeben an, mit Erhalt des bisherigen Stands.

Vollsicherungen bündeln Notizbuch, lokale Dateien, Scanentwürfe und Dokumentversionen.
Filter-Rückgängig bleibt im Entwurf erhalten; bis zu fünf frühere Dateifassungen
sind wiederherstellbar. Große Editoren sind nach Verantwortlichkeiten aufgeteilt.
OneDrive lässt sich mit einer öffentlichen Client-ID direkt in der App einrichten.

[Änderungen, Prüfnachweise und verbleibende Voraussetzungen](QUALITY-BUILD-61.md).
Physische Android-Abnahme und Microsoft-Appregistrierung bleiben offen.

---

# Vorheriger Stand: 0.18.0+60

Anhänge bereits vor dem Speichern eines Eintrags, gemeinsame Tag-Auswahl und
Tag-Verwaltung, echtes Teilen sowie Stapelfilter mit Seitenauswahl, Vorschau und
Rückgängig-Funktion. Live steht unten mittig; Abstände, Titel, Uhrzeiteingabe und
Swipe-Übergänge sind angepasst.

500 Flutter-Tests, 11 Schematests und 3 Servertests bestanden. Zusätzliche
Nachprüfungen der abschließenden Datenfluss-/Materialänderungen: 34 + 17 Tests.
Analyse ohne Befunde; Release-Webbuild erfolgreich. Android-Geräteprüfung bleibt offen.
[Änderungen, kritisches Review und Prüfgrenzen](QUALITY-BUILD-60.md).

---

# Vorheriger Stand: 0.17.2+59

Schülerzeilen haben mehr Abstand zur Trennlinie: unten 10 statt 2 logische Pixel,
oben 6 statt 2. Jede Zeile ist damit 12 Pixel höher. Die fünf Eintragungsaktionen
bleiben direkt sichtbar und behalten ihre Berührungsflächen. Der vorhandene
Smartphone-Test berücksichtigt, dass die sechste Zeile nun Scrollen benötigen kann.

22 bestehende UI-Tests bestanden; Analyse und Formatprüfung ohne Befunde,
Release-Webbuild erfolgreich. Helle und dunkle Smartphone-Renderings geprüft.

---

# Vorheriger Stand: 0.17.1+58

Gestaltung näher an der freigegebenen Vorlage: Inter, sanfte Flächen/Schatten und
gemeinsame Bedienelemente. Code und Tests konsolidiert; Fehler bei verspätetem
Nachladen, Erinnerungseinstellungen und Scanner-Aufräumen behoben.
486 Flutter-Tests, 11 Schematests und 3 Servertests bestanden; Analyse ohne Befunde.
[Änderungen, Prüfumfang und Grenzen](QUALITY-BUILD-58.md).

Webvorschau und bestehender GitHub-PR werden aktualisiert. Datenmodell und
Vorschau-Adresse bleiben erhalten. Die Android-Geräteabnahme bleibt offen.

---

# Vorheriger Stand: 0.17.0+57

Umsetzung der freigegebenen creme-/salbeifarbenen Smartphone-Entwürfe in der Flutter-App.
Offene Schülerzeilen, einheitliche Navigation und Formulare; zwei Anzeigeeinstellungen.
[Umfang, Datenverträglichkeit und Prüfung](CREAM-SAGE-BUILD-57.md).

Webvorschau und Quellstand sind die Auslieferung dieser Runde. Ein kompatibles Android-Testupdate benötigt weiterhin den ursprünglichen Test-Signierschlüssel.

---

# Vorheriger Stand: 0.16.0-rebuild.26+46

Build 46: [Scannerzugänge und Anhänge je HÜ-Aufgabe](../../audit/SCANNER_ZUGAENGE_BUILD_46.md).

Build 45: [Bereichsnavigation, Fotos und Tags](../../audit/NAVIGATION_FOTOS_BUILD_45.md).

Kontextbezogener Dokumentenscanner mit lokaler PDF-Ablage, Bearbeitung, Schwärzung
und fortsetzbaren Entwürfen. [Umfang, Sicherung und Prüfungen](../../audit/DOKUMENTENSCANNER_BUILD_44.md).
Keine SQL-Schemaänderung; App-ID und Testsignatur bleiben gleich.
Die Kameraabnahme auf einem physischen Android-Gerät steht weiterhin aus.

---

# Vorheriger Stand: 0.16.0-rebuild.17+37

Umgesetzt sind die gewünschten Ergänzungen 1, 2, 3, 5 und 6: automatische verschlüsselte
Sicherungen, Android-Erinnerungen, Import-Zusammenführung mit feldweisen Entscheidungen,
PDF-Gesprächsvorbereitung sowie PIN und optionale Biometrie. Vorlagen gehören nicht zu dieser Runde.

264 Tests der vollständigen Flutter-Testsuite bestanden; statische Analyse ohne Befunde.
Keine SQL-Schemaänderung, gleiche App-ID und Testsignatur. Android-Geräteabnahme bleibt offen.
[Funktionsumfang und Prüfungen](../../audit/GERAETEFUNKTIONEN_BUILD_37.md) ·
[Android-Testapp](../../flutter_app/ANDROID-TEST.md).

---

# Vorheriger Stand: 0.16.0-rebuild.16+36

Die beiden Orga-Fehler aus dem technischen Review sind behoben. Typwechsel behalten
Termindatum/Uhrzeit sowie Aufgabenfälligkeit/Erledigt-Status, auch über gespeicherte
Entwürfe und Datenbankneustart. Konflikte zeigen beide Terminangaben vollständig.

240 Tests der vollständigen Flutter-Testsuite bestanden; Analyse ohne Befunde.
Keine SQL-Schemaänderung, gleiche App-ID und Testsignatur.
[Änderungen und Nachweise](../../audit/ORGA_KORREKTUREN_BUILD_36.md) ·
[Android-Testapp](../../flutter_app/ANDROID-TEST.md).
Die sonstigen im Review genannten Plattform- und Produktlücken bleiben offen.

---

# Vorheriger Stand: 0.16.0-rebuild.15+35

Nachprüfung am 4. November: [Technischer Review](../../audit/TECHNIK_REVIEW_BUILD_35.md).
227 vorhandene Tests erneut bestanden; drei zusätzliche Reproduktionen bestätigen
zwei noch offene Fehler: Verlust typbezogener Orga-Werte beim Hin- und Zurückwechseln
und fehlende Terminangaben im Konfliktvergleich. Build 35 ist noch nicht korrigiert.

Aktive Tonpillen sind dunkelgrün, dunkelblau bzw. dunkelrot; die Tonwahl ist etwas
höher, alle Umschalter zeichnen Spur und Griff kleiner. Horizontales Wischen
wechselt die Tonwahl auch über Textfeldern. Orga erlaubt denselben Wechsel
zwischen Notiz, Aufgabe und Termin, auch für bestehende Einträge.
Text, Checklisten und Eingabefokus bleiben dabei erhalten.

227 Tests der vollständigen Flutter-Testsuite bestanden; statische Analyse ohne Befunde.
[Prüfbericht](../../audit/BEDIENUNG_BUILD_35.md) ·
[Zwölf Ansichten](../../audit/tone-controls-renderings/README.md) ·
[Android-Testapp](../../flutter_app/ANDROID-TEST.md).
Kein physischer Android-Gerätelauf, keine Browsertests und keine Schemaänderung.

---

# Vorheriger Stand: 0.16.0-rebuild.14+34

„Zuletzt verwendet“ entfällt in den Beobachtungsformularen, auch beim Bearbeiten.
Vorhandene Auftragstags und Freitexte bleiben erhalten. Beide Symbolreihen auf
Schülerkarten sind zentriert; Symbole und Beschriftungen teilen dieselbe Mittelachse.

32 betroffene Flutter-Tests bestanden, statische Analyse ohne Befunde.
[Prüfnotiz](../../audit/UI_FEINSCHLIFF_BUILD_34.md) ·
[Ansichten](../../audit/card-centering-renderings/) ·
[Android-Testapp](../../flutter_app/ANDROID-TEST.md).

---

# Vorheriger Stand: 0.16.0-rebuild.13+33

Positiv, Neutral und Negativ sind direkt auswählbar und per Wischgeste erreichbar.
Neutral besitzt eigene sachliche Tags und Freitext; neue Installationen starten damit.
Unter Bedienung ist der Standard veränderbar. Ältere Daten bleiben lesbar.

Orga bietet Notiz, Aufgabe und Termin als obere Buttons; Datums- und Statusfelder
passen zum Typ, „Beobachtet am“ entfällt. Deaktivierte Erinnerungen werden zuverlässig
entfernt. Abbrechen schließt mit gesichertem Entwurf ohne Veröffentlichung.
Die Schülersuche liegt als Symbol direkt neben dem Hinzufügen. Die Einstellungen
zeigen ihre Regler und Datenaktionen offen, ohne erklärende Absatztexte.

[Prüfbericht](../../audit/APP_UI_AUDIT_BUILD_33.md) ·
[Android-Testapp](../../flutter_app/ANDROID-TEST.md) ·
[Direkte Flutter-Renderings](../../audit/full-audit-renderings/).
Prüfumfang und verbleibende Plattformgrenzen sind im Bericht dokumentiert.

---

# Vorheriger Stand: 0.16.0-rebuild.12+32

Sozial-/Arbeitsformulare erlauben horizontales Wischen auf der Positiv-/Negativ-Auswahl.
Orga enthält eigenständige Termine mit Datum und optionaler Uhrzeit; vorhandene
Aufgaben, Fälligkeiten und Erinnerungen bleiben getrennt erhalten.
Die Übersicht zeigt die ausgewählte Liste „Anstehend“, „Ergänzen“ oder „Zuletzt“
mit zunächst höchstens fünf Einträgen und einer Aktion für die vollständige Liste.

Suchfelder werden bei Fokusverlust zu Buttons; Suchtext und Filter bleiben erhalten.
Entwürfe lassen sich direkt im Editor löschen, einschließlich Änderungen an bereits
veröffentlichten Einträgen. Autospeicherung und Revisionsprüfung bleiben abgesichert.

[Prüfbericht](../../audit/ORGA_UEBERSICHT_ABGLEICH.md) ·
[Android-Testapp](../../flutter_app/ANDROID-TEST.md) ·
[16 direkte Flutter-Renderings](../../audit/orga-overview-renderings/).
201 Flutter-Tests bestanden, Analyse ohne Befunde, Android-Releasebuild erfolgreich.
Keine Browsertests und kein Android-Gerätelauf.

---

# Vorheriger Stand: 0.16.0-rebuild.11+31

Entwürfe lassen sich in den globalen, schülerbezogenen und Eintrags-Entwurfslisten löschen.
Schülerkarten haben größere, mittige Symbole und Beschriftungen, kompaktere Köpfe
und reine Zahlenbadges. Die obere Seitennavigation ist größer, Sozial-/Arbeitstags
sind kleiner. Buttonbeschriftungen werden auch bei Umbruch zentriert.

Der Schülerdialog bündelt Bereichsauswahl, Suche und Offen-Filter. Entwürfe und Verlauf
sind im Kopf erreichbar; Bearbeiten, Archivieren und Gesprächsvorbereitung im Kopfmenü.
Bei schmalem Bildschirm oder großer Schrift erhält der Name eine eigene Kopfzeile.
Der Tastatur-Fix aus Build 30 bleibt erhalten. Keine Schemaänderung.

Prüfungen und Grenzen: [aktueller Bericht](../../audit/SCHUELERKARTEN_ABGLEICH.md),
[20 direkte Flutter-Renderings](../../audit/pupil-polish-renderings/).
182 Flutter-Tests bestanden, Analyse ohne Befunde und Android-Releasebuild erfolgreich.
Android-Testapp: [Installation und Bau](../../flutter_app/ANDROID-TEST.md).
Keine Browsertests und kein Android-Gerätelauf.

---

# Vorheriger Stand: 0.16.0-rebuild.10+30

Tastaturkorrektur: Dialogeingaben behalten beim Öffnen und Schließen der
Bildschirmtastatur ihren Fokus, Cursor und Eingabezustand.
[Fehlernachweis und Korrektur](../../audit/ANDROID_TASTATUR_FIX.md).

Android-Testapp **FLEX Test** mit eigener App-ID und Android-Speicherdialog:
[Installation und Bau](../../flutter_app/ANDROID-TEST.md),
[Prüfbericht](../../audit/ANDROID_TESTAPP.md). Kein Android-Gerätelauf.

Übersicht und Schüler lassen sich horizontal durch Wischen wechseln.
Settings bieten getrennte App-Skalierung (80–120 %) und Schriftgröße (80–160 %)
sowie Feld-, Button- und Dialogrundungen. Systemschrift wirkt zusätzlich.
Orga-Listenwerkzeuge und HÜ-Aufgabenstatus werden über Symbole bedient;
HÜ zeigt den gewählten Zustand zusätzlich als Text.

Maßgeblich: [aktueller Prüfbericht](../../audit/SWIPE_DESIGN_ABGLEICH.md),
[186 direkte Flutter-Renderings](../../audit/swipe-renderings/).
171 Flutter-Tests bestanden, Analyse und Android-Releasebuild erfolgreich.
Release-Webbuild und direkte Renderings wurden in der vorherigen UI-Runde geprüft.
Keine Browsertests und kein nativer Windows-/Android-Abnahmelauf.
Sehr große kombinierte Skalierungen brauchen viel Scrollen und erzeugen starke Wortumbrüche.
Import-Zusammenführung, feldweise Konfliktauflösung und geführter Notfall-Reimport bleiben offen.
Keine Freigabe als originalgetreu.

---

# Vorheriger Stand: 0.16.0-rebuild.8+28

Schwarze transparente Karten/Felder, weiße transparente Kopf-/Fußbereiche und Buttons.
Neue Übersicht mit Zusammenfassungen ohne Auswahl-/Abhakbuttons; gemeinsame Positiv/Negativ-Pille.
Alle Schülerkartenbadges enthalten nur eine Anzahl (offene Vorgänge + Entwürfe).
Entwürfe sind über den Kopf des Eintragsmodals ausdrücklich fortsetzbar; aufgegebene HÜ
haben dort einen eigenen Zugang. Neue Eingaben bleiben beim Wechsel erhalten.
Orga-Nummerierung, Aufzählung und Checkliste setzen sich mit Enter korrekt fort.

Maßgeblich: [aktueller Abgleich und Prüfumfang](../../audit/UEBERSICHT_ORGA_ABGLEICH.md),
[168 direkte Flutter-Renderings](../../audit/overview-renderings/).
145 Flutter-Tests, 11 Schematests, 3 Vorschau-Servertests; Analyse und Release-Webbuild erfolgreich.
Keine Browsertests und kein nativer Windows-/Android-Abnahmelauf. Import-Zusammenführung,
feldweise Konfliktauflösung und geführter Notfall-Reimport bleiben offen; keine Freigabe als originalgetreu.

---

# Vorheriger Stand: 0.16.0-rebuild.7+27

Neue Einträge und „Speichern & weiter“ starten immer frisch. Entwürfe werden ausdrücklich
über Liste/Badge geöffnet; leere Formulare erzeugen keinen Entwurf. Nach vollständigem
Zurücksetzen wird nur der eigene unveränderte Entwurf entfernt. Sozial/Arbeit haben
Entwurfsbadges; die kompakte Aufgabenliste gilt für Einzel- und Gruppen-HÜ.

Kleinere Basisschrift, kompaktere Kopf-/Fußbereiche und aktive Tags. Kalendernavigation
bleibt auch bei großer Schrift lesbar. Maßgeblich sind die [UI-/UX-Prüfung](../../audit/UI_UX_PRUEFUNG.md)
und [aktuellen direkten Renderings](../../audit/ux-renderings/).
125 Flutter-Tests, 11 Schematests und 3 Vorschau-Servertests bestanden; Analyse und Release-Webbuild erfolgreich.
Keine Browsertests, kein nativer Windows-/Android-Abnahmelauf. Import-Zusammenführung,
feldweise Konfliktauflösung und geführter Notfall-Reimport bleiben offen; keine Freigabe als originalgetreu.

---

# Vorheriger Stand: 0.16.0-rebuild.6+26

Die Schülerkarten-Shortcuts öffnen sofort das zugehörige Eintragsmodal und setzen
passende neue Einzelentwürfe fort. Die Einstellungen wurden anhand der HTML-Struktur
und der später dokumentierten Änderungen ergänzt und korrigiert.

Maßgeblich für diese Runde: [Settings-Abgleich mit vollständiger Wertzuordnung](../../audit/SETTINGS_ABGLEICH.md),
[aktuelle direkte Renderings](../../audit/settings-renderings/), Tests und Buildnachweise unter `audit/evidence/settings-*`.
Vorschau ist ein lokaler Flutter-Webbuild; keine Browsertests und kein nativer Windows-/Android-Abnahmelauf.
Die grünen Originalhintergrunddateien fehlen weiterhin. Die offenen Import- und Konfliktlücken des
Dialogaudits bleiben dokumentiert; **keine Freigabe als vollständig originalgetreu**.

---

# Vorheriger Dialogaudit: 0.16.0-rebuild.5+25

Der Nutzer hat das Quellenpaket `FLEX-Notes-Quellen-9e5e4b6b8e8c.zip`
nachgereicht. Sein vollständiger Stand 0.16.0-rebuild.4+24 wurde übernommen;
der folgende Schritt korrigiert Dialoge anhand der aktuellen HTML-Referenz (37)
und der späteren ausdrücklichen Nutzervorgaben.

Maßgeblich sind jetzt das [vollständige Dialogverzeichnis](../../audit/DIALOGVERZEICHNIS.md),
der [dialogweise Abgleich](../../audit/FLUTTER_ABGLEICH.md) und der
[aktuelle Prüfnachweis](../../audit/PRUEFNACHWEIS.md). Dort stehen auch die
wesentlichen offenen Abweichungen bei Import, Konflikten, Übersicht und
historischen Formaten. **Nicht als „originalgetreu“ freigegeben.**

In dieser Runde: lokale Flutter-Tests und direkte Flutter-Renderings, keine
Browsertests, kein neuer Web-/Windows-/Android-Releasebuild und keine
Veröffentlichung. Ausgeliefert wird der bearbeitbare Quellstand mit Nachweisen.
Die folgenden Abschnitte gehören unverändert zum gefundenen Archiv und sind
historische Berichte; ihre Testzahlen und damaligen offenen Punkte werden nicht
als aktuelles Ergebnis ausgegeben.

---

# Aktueller Stand: 0.16.0-rebuild.4+24

Sozial- und Arbeitsverhalten sowie der Kalender wurden an die jetzt gelieferten
Screenshots angeglichen. Umfang, Speicherung, Prüfungen und Grenzen stehen im
[Dialog-Abgleich](DIALOG-ABGLEICH.md). Neu sind insbesondere einzelne Zusatz-
bereiche, persistente Favoriten/Auswahllisten, „Speichern & weiter“ und die
integrierte optionale Uhrzeit. 60 Tests und Analyse ohne Befunde; neue direkte
Flutter-Ansichten unter `renderings/reference-*`, Nachweise unter `evidence/dialog-*`.

Die folgenden Abschnitte sind historische Prüfstände; deren Aussagen zu fehlenden
Dialog-Screenshots, offenen Beobachtungskatalogen und „Speichern & weiter“ für
Beobachtungen werden durch den aktuellen Dialog-Abgleich ersetzt. Andere
fachliche Grenzen gelten weiterhin.

---

# Vorheriger Hintergrundstand: 0.16.0-rebuild.3+23

## Originalhintergrund vom 01.11.2026

Das nachgereichte `Background Mobile 01 Dark small.png` ist bytegleich als
App-Asset eingebaut (1061 × 1500 Pixel). Im dunklen Modus erscheint es als
Standard auf Mobilgeräten und Desktop; eigene Bilder behalten Vorrang.
Flächenfüllende, zentrierte Darstellung ohne Verzerrung ist voreingestellt.
Andere Bildmodi bleiben verfügbar. Der helle Modus behält seinen Verlauf.
Herkunft und SHA-256: [Asset-Dokumentation](../../flutter_app/assets/backgrounds/README.md).
Die zuvor fehlenden grünen Tafeltexturen und historischen Original-Screenshots
sind damit nicht wiederhergestellt; dieses Bild ist die jetzt gelieferte Vorlage.

Für diesen Stand neu ausgeführt:

- Flutter-Analyse: keine Befunde.
- Gesamtsuite: 56 Tests bestanden.
- Zusätzlicher Renderlauf des bestehenden UI-Tests: bestanden; echte Flutter-
  Ansichten für Desktop, Mobil, HÜ und Kommentar unter `renderings/background-*`.
  Desktop und Mobil wurden visuell geprüft; ausschließlich synthetische Schüler.
- Webbuild erfolgreich, einschließlich Wasm-Vorprüfung.
- Lokale HTTP-Prüfung von Einstieg, Version, App-JavaScript und Hintergrund:
  Status 200, bytegleich, COOP/COEP vorhanden; Bild stimmt mit Original-SHA überein.
- Drei Vorschau-Serverprüfungen bestanden.

Protokolle: `evidence/background-*`. Flutter 3.47.9 / Dart 3.13.7.
Keine Browsertests oder Windows-/Android-Gerätetests; die nachstehenden
fachlichen Grenzen gelten weiterhin. Das Windows-Vorschaupaket wird aus diesem
Webbuild erstellt; vollständige Quellen werden separat als ZIP ausgeliefert.
Die früheren Aussagen zu ausgelieferten Paketen und Prüfzahlen im folgenden
Abschnitt dokumentieren den vorherigen Stand.

---

# Vorheriger Wiederaufbau – 0.16.0-rebuild.2+22

**0.16.0-rebuild.2+22** ist ein bearbeitbares Flutter-Projekt aus erhaltenen
Quellen und neu rekonstruierten Funktionen. Es ist kein wiedergefundenes Original
von 0.16.0+20 und noch kein vollständiger Funktions-/Pixelabgleich mit 0.15.3.

## Herkunft

- Basisbranch `recovery/webpreview`, Commit `8a97a94d2854b43427c1016748b2adab431879f5`.
- Geprüfte Extraktion von 173 Quelldateien und Referenzdateien aus 0.1.0+1,
  gesichert im Zwischencommit `9e80ba7` auf `rebuild/flutter`.
- HTML-Prototyp unter `work/` unverändert; keine dauerhafte HTML-Einbettung.
- Webpreview-Original 0.15.3+19 und Quellarchive 0.1.0+1 unverändert unter
  `recovery/`. Die ursprünglichen neueren Flutter-Quellen fehlen weiterhin.
- Das SQL-Schema 7 stammt bytegleich aus dem Webpreview. Schriften Selawik und
  Gelasio samt Lizenzen wurden aus demselben Paket übernommen.
- Die fünf Hauptsymbole sind neue Flutter-Vektorzeichnungen anhand der im Chat
  sichtbaren Bildvorlage. Die PNG-Originaldatei war nicht als lokale Datei verfügbar.

## Implementiert und lokal geprüft

Die nachgereichte [App-Referenz aus dem alten Chat](APP-DETAILS-AUS-ALTEM-CHAT.md)
präzisiert die jüngsten Vorgaben. Ihre historischen Testzahlen gelten nicht als
Prüfnachweis dieser Rekonstruktion. Der vorherige Wiederaufbau hatte erhebliche
UI-Abweichungen; der folgende Schritt korrigiert diese konkret, ohne einen
visuellen Originalabgleich vorzutäuschen.

| Bereich | Tatsächlicher Stand |
| --- | --- |
| Navigation und Schülerkarten | Zentrierte Pillen Übersicht / Schüler / …; Seiten- und untere Navigation entfernt. Karten mit farbigem Rand, Serifennamen, Pfeil und fünf gefüllten Symbolen in 3+2-Anordnung, einschließlich offener/fälliger Zähler. |
| Schülersuche | Anfangs verborgen; Lupe bei Neuer Schüler und Download öffnet mit Textfokus. Leeren erhält die offene Suche; Schließen leert den Filter. |
| Schüler / Orga | Überlieferte Anlage, Bearbeitung, Archiv, Aufgaben, Checklisten, unabhängige Erinnerung, Historie und Entwürfe; fachliches Datum und optionale Uhrzeit ergänzt; Editoren in gemeinsamer Dialoghülle. |
| Sozial-/Arbeitsverhalten | Eigene persistente Einträge, positive/negative Tags und Freitext, Auftrag, Situation, Quelle, Unterstützung, Beteiligte ohne fremde Einzelbewertung, Zielbezug mit damaligem Zieltext. |
| Ziele | Ziel, Kriterium, Unterstützung, Schülerperspektive, Zieltermin und separater Prüftermin; Überprüfungen mit Fortführen/Erreicht/Beendet/Wieder öffnen und verknüpften Beobachtungen. |
| Hausübung | Aufgaben und Teilaufgaben mit stabilen IDs, Fach/Termin, unabhängige Aufgabenstände, Abgabe und Kommentar, chronologischer Rückmeldungsverlauf mit Korrektur/Löschung. |
| **Direkte HÜ-Standbuttons** | **Offen / Vollständig / Teilweise / Nicht erledigt** direkt pro Aufgabe; keine HÜ-Checkboxen als Standbedienung. Gleicher Stand und Doppelklick erzeugen keine zusätzliche Historie; Speicherfehler erhält den gespeicherten Stand, Wiederholung ist möglich. Vollständig-Zähler ergänzt. |
| **Sprechblasen-Kommentar** | Gefüllte Sprechblase pro Aufgabe, vorhandene Kommentare hervorgehoben; Kommentar öffnet mit Textfokus und Standinformation. Kommentar und Abgabe verändern den Aufgabenstand nicht. |
| **Schüler-Tags** | Empfänger bei HÜ sowie Schüler-/Beteiligtenauswahl als Chips/Tags. Mehrere HÜ-Empfänger werden atomar gespeichert; Aufgaben-IDs und Zustände bleiben je Kind getrennt. |
| **Einheitliche Modals** | Auch die Schülerbereichslisten öffnen als Modals. Außenabstand mobil 10 / Desktop 16, Radius 24, Standard-Maximalbreite 640; Kommentar/Kalender 430. Alle fünf Bereichslisten und Editoren auf Desktop und bei 320 px mit Tastatur geprüft. |
| Eintragsdarstellung | Kompakter Entwurfsstatus, exakte Zeitpunkt-Tags, Abschnitt Kontext / Quelle, Reaktion / Unterstützung. Optionale Uhrzeit direkt im Kalender ohne eigenen Schalter. Schrift/Farbe ausgewählter Chips im tatsächlich gerenderten Widget geprüft. |
| **Gefüllte Icons** | Zielscheibe/Pfeil, Personen, Dokument, Haus und Kalender in gemeinsamer skalierbarer Flutter-Zeichnung. |
| Entwürfe | Fachliche Editoren speichern nach Schreibpause, bei Escape/Schließen und Lebenszykluswechsel. Kommentar-/Überprüfungsentwürfe behalten ihren Dialogmodus. Revisionen schützen auch beim endgültigen Speichern vor dem Entfernen neuerer Entwürfe. |
| Gruppenrücknahme | HÜ-Gruppen idempotent gespeichert; Rücknahme nur bei unveränderten Einträgen ohne Bearbeitungsentwurf, Wiederherstellung der Eingaben als neuer Entwurf. |
| Papierkorb | Ziele, Beobachtungen, HÜ und Orga weich löschen und wiederherstellen, mit neuer Revision. Löschen von Orga beendet geplante Erinnerungen; Wiederherstellen reaktiviert sie nicht. |
| Darstellung | Freie Hex-Farben für Dialogleisten/Karten/Buttons, optional gekoppelte Farben, getrennte Deckkraft, Gelasio-Überschriften, separate Desktop-/Mobilbilder mit fünf Bildmodi. Bilder bleiben lokal und werden in Sicherungen aufgenommen. |
| Konsistentes Laden | Ein gemeinsamer SQLite-Snapshot verhindert gemischte Ansichten während gleichzeitiger Änderungen. |
| Gesprächsvorbereitung | Auswahl fachlicher Einträge, Text-/Bereichs-/Datumsfilter und bewusstes Kopieren einer Textunterlage. |
| Sicherungen | Alle rekonstruierten Tabellen inklusive Verlauf/Entwürfen; atomare Wiederherstellung in leeren Bestand, zusätzlicher Import des erhaltenen Flutter-0.1-Formats. Datei- oder Zwischenablage-Ausgabe, Passwortschutz vorausgewählt. |
| Verschlüsselung | PBKDF2-SHA256 (310000 Iterationen), AES-256-GCM, frische Salt/IV; kompatibler äußerer `FLEX-Encrypted`-Container mit authentifiziertem Inhalt. |
| Schema | Echte Dateimigration 1 → 7 getestet. Neue Fach-Payloads tragen `rebuildFormat: 1`; unbekannte Formate werden abgewiesen. |

## Prüfungen dieses Wiederaufbaus

- Flutter **3.47.9**, Dart **3.13.7**, aufgelöste Pakete in `pubspec.lock`.
- `flutter analyze --no-pub`: **keine Befunde**.
- `flutter test`: **56 Tests bestanden**. Einschließlich echter SQLite-
  Migration, atomarem Rollback, Revisionen, Rückmeldungsreihenfolge, Gruppen,
  Entwürfen, Backup-Rundlauf, Passwort-/Manipulationsprüfung und Widgettests
  zu den gewünschten Änderungen. Zusätzlich geprüft: Orga-Papierkorb,
  Darstellungs-/Bilddaten im Sicherungsrundlauf, gleichzeitiges Lesen/Schreiben
  und konkurrierende Entwurfsänderungen. Fünf zusätzliche Fälle prüfen die
  nachgereichten UI-Vorgaben, Suchfokus, Kartengeometrie, Standänderungen bei
  Doppelklick/Fehler, Chip-Schrift/-Farbe und direkte Flutter-Renderings.
- Der Kryptografie-Kompatibilitätstest nutzt einen synthetischen Container,
  den die ursprünglichen HTML-Kryptofunktionen unter **Node/Web Crypto** erzeugt
  haben. Dies ist kein Browserlauf.
- Widgettests prüfen unter anderem 320 Pixel Breite mit 1,35-facher Schrift und simulierter Tastatur,
  Fokus nach Sprechblasen-Klick, Tag-Empfänger, Ziele und Mitternacht/fehlende Zeit.
- Direkte Flutter-Bildausgabe mit geladenen Originalschriften unter `renderings/`.
  Die neuen Desktop-/Mobilansichten wurden visuell angesehen. Kein pixelgenauer Abgleich mit der
  kompilierten Referenz-Web-App und keine Browseraufnahme.
- `flutter build web --no-web-resources-cdn`: erfolgreich; Wasm-Vorprüfung bestanden.
- Lokaler Server auf **0.0.0.0:8081** gestartet. 13 Ressourcen einschließlich
  App-JavaScript, SQLite-Wasm, Drift-Worker, CanvasKit, Schema und Schriften per
  HTTP geprüft: Status 200, bytegleiche Inhalte und erforderliche COOP-/COEP-
  Header. `version.json` meldet `0.16.0-rebuild.2+22`. Dies bestätigt die
  Auslieferung, nicht die Ausführung im Browser oder OPFS-Persistenz.
- Die elf ursprünglichen SQL-Tests und der Architektur-SQL-Test bestanden.
- Alle Originalarchive und der gesicherte Prüfbericht wurden bytegleich geprüft.

Prüfprotokolle stehen unter `evidence/`; die Bildausgabe unter `renderings/`.
Der Cloud-Server ist ein temporärer interner Prozess und muss nach einem Neustart
der Umgebung erneut gestartet werden. Der Nutzerbrowser meldete für
`http://127.0.0.1:8081/` **ERR_CONNECTION_REFUSED**, während der Server innerhalb
der Cloud weiterhin HTTP 200 lieferte. Eine Weiterleitung in den eingebetteten
Browser ist hier nicht verfügbar; eine Portauswahl in dessen Oberfläche ist
nicht belegt. Die frühere Anleitung, dort Port 8081 auszuwählen, war unzutreffend.

Als lokale Alternative kann `tool/package_preview.py` ein Windows-ZIP mit
dem geprüften Web-Build, Server-EXEs für x64/ARM64 und `Webvorschau-starten.cmd` erzeugen.
Das vollständige ZIP wird auf dem Windows-PC entpackt; der Starter öffnet dessen
Standardbrowser und bindet nur die dortige Loopback-Adresse. Flutter, Python und
Go sind beim Empfänger nicht nötig. Go-Serverquellen sind im Paket und Repository
enthalten. Der Hilfsserver wurde unter Linux per HTTP geprüft; Windows-Ausführung
und Browserpersistenz bleiben ungetestet. Keine Cloud-Veröffentlichung oder
Konfigurationspublikation, kein öffentlicher Tunnel.

Das zuvor gelieferte Windows-Paket gehört zu **0.16.0-rebuild.1+21** und enthält
die aktuellen UI-Korrekturen noch nicht. In dieser Runde wurde kein neues ZIP
erstellt. Die folgenden Starterprüfungen beziehen sich auf jenes frühere Paket.

Der Vorschau-Starter bestand drei lokale Tests: Auslieferung aus seinem eigenen
Paketordner unabhängig vom Arbeitsverzeichnis (auch mit Leerzeichen im Pfad),
Erkennung fehlender Webdateien und Konflikte mit einem belegten Port. Die
Windows-Binaries wurden mit Go 1.27.3 erzeugt und ihre PE-Zielarchitekturen geprüft.
Alle Dateien jenes ZIP wurden anhand der enthaltenen SHA-256-Liste geprüft; sein
Flutter-Web-Build entspricht bytegleich dem Stand `4e79901`.
Nachweise: `evidence/local-preview.json` und `evidence/local-preview-tests.txt`.

## Noch offen gegenüber der 0.15.3-Referenz

- Vollständige Funktions- und Pixelgleichheit. Die neuen Darstellungsoptionen
  sind rekonstruiert; exakte Geometrie, gekoppelte Transparenzen und sämtliche
  ursprünglichen Reglerstufen sind nicht vollständig abgeglichen.
- Vollständige Katalog-/Favoritenpflege für Auswahltexte und Auftragsvorschläge.
- Noch nicht vollständig angeglichen: Aufklappverhalten der HÜ-Karten,
  „Speichern & weiter“, sämtliche Übersichtsgruppen und Wischbedienung zwischen
  Hauptseiten. Die beschriebenen Original-Screenshots und Tafeltexturen fehlen.
- Eigener gemeinsamer Kontexteditor mit Konfliktauflösung; Gruppenerfassung
  individueller Verhaltensbeobachtungen und Orga-Gruppen entsprechend der Referenz.
- Dauerhafte Stammdatenentwürfe, Stammdaten-Papierkorb und endgültiges Leeren
  mit sämtlichen Referenzprüfungen. Die neue Fach-Papierkorbbedienung ersetzt dies
  nicht stillschweigend.
- Vollständiger bereichsübergreifender Verlauf einschließlich aller Orga-Felder
  und Gesprächsunterlagen mit sämtlichen Export-/Filteroptionen der Referenz.
- Geführtes Übertragen einer konflikthaften Bearbeitung auf die neueste Revision.
  Der aktuelle Konfliktschutz weist veraltete Änderungen ab und erhält Entwürfe.
- Import/Migration unbekannter Flutter-Formate 0.15.3/0.16.0. Schema 7 allein
  beweist keine Payload-Kompatibilität. Die Rekonstruktion nutzt daher eine
  getrennte Datenbank und einen eigenen inneren Sicherungsformatnamen.

## Nicht ausgeführt / keine entsprechende Zusage

Keine Browsertests, keine praktische Prüfung von OPFS/IndexedDB oder mehreren
Browserfenstern, keine Windows-/Android-Gerätetests, kein nativer Flutter-Release-Build
und keine Release-Signierung. Native Dateiwähler wurden nicht praktisch geprüft.
Die lokale Datenbank bleibt unverschlüsselt. HTML-Altdaten werden nur vorgemerkt;
die vollständige Migration, Synchronisation, Scanner und native Benachrichtigungen
bleiben offen, wie teilweise bereits im Referenzstand.

Neue Arbeitsbereiche enthalten keine Testschüler. Tests verwenden ausschließlich
synthetische Inhalte. Es wurde keine Cloud-Umgebung veröffentlicht.
