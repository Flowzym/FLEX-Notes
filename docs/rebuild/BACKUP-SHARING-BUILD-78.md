# FLEX 0.28.0+78 · Sicherungen und Dateieingang

## Verhalten

Vollständige manuelle und automatische Sicherungen verwenden das binäre Format
`.flexbackup` (Version 3). Materialdateien werden nacheinander gelesen, geprüft und
in Blöcken von 64 KiB verschlüsselt. Die App hält keinen vollständigen Base64-
Dateibaum mehr im Arbeitsspeicher. Fortschritt und Fehler bleiben sichtbar.
Vor der Importauswahl wird die gesamte Datei geprüft; vor der Datenbankübernahme
werden die Dateien erneut gelesen und verifiziert. Geänderte Quellen, falsche
Passwörter, fehlende Blöcke, Manipulation und zusätzliche Daten werden abgewiesen.
Bei einem Importfehler werden nur neu angelegte Dateien zurückgenommen.

Passwortgeschützte Archive verwenden PBKDF2-HMAC-SHA256 mit 600.000 Durchläufen,
einem zufälligen 128-Bit-Salt und AES-256-GCM. Ein zufälliges 64-Bit-Nonce-Präfix
plus 32-Bit-Blocknummer verhindert Nonce-Wiederverwendung innerhalb eines Archivs;
der frisch abgeleitete Schlüssel gilt nur für dieses Archiv. Header und Nummer
sind authentifizierte Zusatzdaten jedes Blocks. Der verpflichtende authentifizierte
Abschluss enthält Anzahl und Gesamtgröße. Die teure Schlüsselableitung läuft unter
Android außerhalb des UI-Isolates, kleine AES-Blöcke nutzen die native Bibliothek.

Android liest/schreibt über begrenzte Plattformkanal-Nachrichten und SAF-Streams.
Automatische Sicherungen erhalten zunächst `.partial` und werden nach vollständiger
Leseprüfung umbenannt. Erst danach aktualisiert FLEX den Sicherungszeitpunkt und
räumt ältere eigene Sicherungen auf. Nach Prozessabbruch können unvollständige
`.partial`-Dateien im gewählten Ordner liegen bleiben; sie erscheinen nicht als
wiederherstellbare automatische Sicherungen. Der Dateianbieter muss Umbenennen
unterstützen. Ohne diese Unterstützung bleibt der Sicherungslauf erfolglos und
vorhandene Sicherungen erhalten.

## Android: Teilen → FLEX

PDF, DOCX, JPG, PNG und WebP können einzeln oder gemeinsam aus einer anderen App
übergeben werden. FLEX akzeptiert freigegebene Content-URIs und kopiert sie in einen
verschlüsselten Eingang. Die Originale in der Quell-App werden nicht verändert.
Die Übersicht zeigt Vorschaubilder, Auswahl und Dateinamen; Kategorie, Schüler,
Unterricht und ein geplanter Einsatztermin pro ausgewähltem Schüler sind zuordenbar.
Bilder werden normalisiert und als JPEG gespeichert; Dateiendung und MIME-Typ passen
zur Ausgabe. „Später“ erhält den Eingang auch nach einem Neustart. Er ist außerdem
auf der Materialseite erreichbar. Die App-Sperre verhindert die automatische Anzeige
vor dem Entsperren. Wiederholtes Übernehmen nach einer fehlgeschlagenen Quittierung
erzeugt keine doppelten Materialeinträge.

Grenzen: 20 MB pro Datei, 20 Dateien und 100 MB im Eingang. DOCX erhält das bestehende
Dokument-Cover statt einer gerenderten Word-Seite. Noch nicht übernommene Eingänge
gehören nicht zum Notizbuch und sind daher noch nicht in dessen Sicherung enthalten.
Der native Kaltstart, Fremdanbieter und Android-Berechtigungen benötigen Geräteabnahme.

## OneDrive

Die Anmeldung erklärt die öffentliche Client-ID und typische Registrierungsfehler.
Die [Registrierungsvorlage](../../flutter_app/config/onedrive-public-client.json)
fordert ausschließlich die delegierte Graph-Berechtigung `Files.Read` an.
[Einrichtungsanleitung](ONEDRIVE-SETUP.md). Es wurde keine Microsoft-App registriert,
kein Client-Geheimnis erzeugt und kein Azure-Abonnement aktiviert. Die Anmeldung
mit echtem Konto bleibt bis zur Registrierung offen. Android-Dateiübergabe kann
unabhängig davon verwendet werden.

## Messung und Grenzen

Gleicher Linux-Flutter-Testprozess, synthetisches Notizbuch mit fünf Dateien à
20.000.000 Byte, vollständiger Export, Prüfung und tatsächliche Wiederherstellung:

| Messung | Bisheriges Format v2 | Neues Format v3 |
| --- | ---: | ---: |
| Archivgröße | 177.793.888 Byte | 100.040.660 Byte |
| RSS vor der Arbeit | 275.505.152 Byte | 275.849.216 Byte |
| Maximaler RSS | 1.689.825.280 Byte | 508.170.240 Byte |
| Export | 21,0 s | 13,7 s |
| Prüfung | 19,9 s | 12,5 s |
| Wiederherstellung | 1,1 s | 13,9 s |

Der neue Import liest und prüft bewusst ein zweites Mal statt sämtliche Dateien
zwischenzuspeichern. Rundlauf beider Formate erfolgreich. Das sind JIT-Testwerte
unter Linux, keine Android-Laufzeitmessung. Die neue Verarbeitung hält weiterhin
die größte Einzeldatei (bis 20 MB), das Notizbuch (bis 20 MB) und Arbeitskopien;
sie ist nicht beliebig skalierbar. Gesamtgrenze für lokale Dateiinhalte: 100 MB.

Alte JSON-Sicherungen bleiben importierbar, benötigen dabei weiterhin die bisherige
Pufferung. Browser können Blob-Downloads ebenfalls vollständig im Speicher halten.
Neue `.flexbackup`-Dateien benötigen Build 78 oder neuer zum Öffnen. Vorhandene
Notizbuchdaten und frühere Sicherungen werden nicht konvertiert oder gelöscht.

## Prüfnachweise

Siehe [gesammelte Nachweise](evidence/build78/). Das Testpaket umfasst Fehler- und
Rundlauftests der neuen Archive, eine unabhängig mit Python erzeugte AES-GCM/PBKDF2-
Testdatei, Wiederholbarkeit und Rollback von Dateieingängen, Bildnormalisierung,
Sperrverhalten sowie Layout bei 320 Pixeln und vergrößerter Schrift.

**615 Flutter-Tests**, **11 SQLite-Schematests**, **2 native JVM-Tests** und
**3 Serverprüfungen** bestanden. Codeanalyse und Formatprüfung ohne Befunde;
signierte ARM64/ARMv7-Releasebuilds und Webbuild erfolgreich. Die Browserprüfung
bestätigt verschlüsselten Export, Importvorschau einschließlich neun Dateien sowie
OneDrive-Einrichtung bei 320/390 Pixeln ohne JavaScript-Seitenfehler. Die APK-Prüfung kontrolliert die bestehende Signatur, Kennung,
VersionCode, ZIP-Integrität, Architektur und 16-KB-Ausrichtung. Private Schlüssel
und Passwörter sind nicht Teil des Repositorys oder der Pakete.

## Noch abnehmen

Die [Android-Abnahme](ANDROID-ACCEPTANCE-BUILD-78.md) ist vorbereitet, aber mangels
verbundenem Gerät noch nicht durchgeführt. Dazu gehören Update/Migration, Kamera,
Biometrie, Hintergrundbetrieb, Fremdanbieter-Dateiübergabe, SAF und Benachrichtigungen.
TalkBack und erhöhte Android-Schriftgröße sind ebenfalls am Gerät zu prüfen.
Die Microsoft-Registrierung und eine echte OneDrive-Anmeldung bleiben offen.
