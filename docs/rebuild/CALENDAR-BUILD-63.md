# Gemeinsamer Kalender · 0.20.0+63

Unterricht, Termine und Fristen stehen in einer gemeinsamen Tages-, Wochen- und
Monatsansicht. Die separate Stundenplan-Unterseite entfällt. Im Kalenderbereich
bleiben die beiden Seiten **Kalender** und **Aufgaben**, einschließlich Swipe.

## Bedienung

- **Unterricht** blendet Unterrichtsblöcke ein oder aus, ohne Daten zu verändern.
  Datum, Ansichtsmodus und Filter bleiben beim Wechsel zur Aufgabenliste erhalten.
- **Stundenplan bearbeiten** öffnet den Grundplan mit Blockbearbeitung,
  Wiederherstellung, neuen Blöcken und Stundenzeiten.
- Ein Unterrichtstermin öffnet seine Details, Materialien und Planungen.
  **Nur diesen Termin bearbeiten** ändert genau diese Durchführung.
  **Stundenplan ab [Datum] ändern** erhält frühere Durchführungen und teilt die
  Serie ab dem ausgewählten ursprünglichen Termin.
- Lange Unterrichtsblöcke sind zurückhaltender eingefärbt. In schmalen
  Wochen-Spalten bleiben überlappende Gespräche innerhalb des Unterrichts sichtbar;
  Antippen bietet die beteiligten Einträge einzeln an.
- Fälligkeiten stehen über der Zeitleiste. Die Monatsmarkierungen heben Termine,
  Fristen und Ferien hervor; der Unterricht des ausgewählten Tages bleibt darunter
  erreichbar. Die aktuelle Uhrzeit wird waagrecht markiert, die Beschriftung steht
  in der Zeitspalte und verdeckt keine Blocktitel.

## Daten und Verknüpfungen

Kalender und Stundenplan verwendeten bereits dieselben Unterrichtsdokumente.
Die Zusammenführung benötigt weder eine SQL-Migration noch eine erneute Übernahme
der PDF-Vorlage. Bestehende Einträge, Ferien, Ausnahmen und geänderte Stundenzeiten
bleiben erhalten.

Beim Aufteilen einer Serie werden Planung, datierte Dokumentzuordnungen und
Erinnerungsziele zusammen mit der Serie in einer Transaktion aktualisiert.
Verschobene frühere Stunden behalten ihre bisherige Zuordnung. Änderungen, die
vorbereitete Durchführungen oder vorgemerkte Verknüpfungen ausschließen würden,
werden zurückgewiesen, statt die Zuordnungen stillschweigend zu verlieren.

## Android-Update

Die APK verwendet dieselbe App-Kennung `at.flowzym.flex_notizbuch` und dasselbe
dauerhafte Signierzertifikat wie Build 62. Sie ist ein Update der neuen **FLEX**.
Für die ältere **FLEX Test** gilt weiterhin die [Umzugsanleitung](ANDROID-UMZUG-62.md).

## Prüfungen

- Gesamte Flutter-Suite: **514 Tests bestanden**. Angepasste UI-Tests prüfen
  Kalender/Aufgaben, Datum und Filter beim Seitenwechsel, den Grundplaneditor,
  Stundenzeiten und die Einzel-/Serienbearbeitung. Neue Domänentests decken
  Serienaufteilung, verschobene Termine, Dateien, Planungen und Erinnerungen ab.
- **11 SQLite-Tests und 3 Vorschau-Servertests bestanden**.
- `flutter analyze --no-pub`: ohne Befunde; Dart-Formatierung geprüft.
- Release-Webbuild im Chromium-Smartphonefenster (390 × 844): Wochenansicht,
  Unterricht ein-/ausblenden, Grundplan öffnen, Aufgabenwechsel und Rückkehr
  mit erhaltener Monatsansicht. Keine JavaScript-Seitenfehler.
- Signierter Android-Release und Web-Release erfolgreich gebaut. APK-Version,
  Kennung, gleiches Zertifikat wie Build 62, ZIP-Integrität, ARM64/ARMv7/x86_64
  und 16-KB-Ausrichtung geprüft. Kein privates Signiermaterial in der APK.

[APK und Prüfnachweise](../../releases/android/build-63/README.md) ·
[Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/).

Die physische Android-Installation und der persönliche Datenbestand werden hier
nicht geprüft. Die lokalen Smartphone- und Browserprüfungen verwenden Testdaten.
