# Sicherheit und Qualität · Build 77

Stand: 14.11.2026 · Flutter **0.27.0+77**, Datenbankschema weiterhin **7**.
Ausgangspunkt ist das externe statische APK-Review von Build 75, abgeglichen
mit dem aktuellen Quellcode und Build 76. Dieser Schritt setzt das erste
Sicherheits-/Qualitätspaket um; er übernimmt nicht die gesamte vorgeschlagene Roadmap.

## Android: verschlüsselter Gerätespeicher

- SQLCipher über die unterstützten Native-Asset-Hooks von `sqlite3` 3.8.0.
  Eine transitive Paketnennung allein hatte bisher keine Datenbank verschlüsselt.
- Zufälliger 256-Bit-Datenbankschlüssel, geschützt durch AES-GCM im Android
  Keystore. Der verpackte Schlüssel liegt im vom Systembackup ausgeschlossenen
  App-Verzeichnis. Er hängt nicht von der PIN ab, damit geplante Sicherungen
  weiterhin im Hintergrund arbeiten können.
- Beim ersten Start wird die bestehende Datenbank in eine separate verschlüsselte
  Datei exportiert. Schema, Nutzdaten, Sequenzen, Integrität und Fremdschlüssel
  werden verglichen; erst nach erfolgreicher Prüfung wird umbenannt und die alte
  Datenbank samt Journaldateien entfernt. Ein abgebrochener Zwischenschritt lässt
  sich mit erhaltenem Original wiederholen. Ein falscher oder verlorener Schlüssel
  führt zu einer Fehlermeldung, niemals zu einer leeren Ersatzdatenbank.
- Der vorhandene prozessweite Android-Sicherungsmutex schützt die Vorbereitung
  gegen gleichzeitige Vordergrund-/WorkManager-Initialisierung. Die verschlüsselte
  Datenbank verwendet einen eigenen Drift-Isolatnamen.
- Lokale Materialdateien werden mit AES-256-GCM und frischen IVs verschlüsselt.
  Der Dateischlüsselname ist authentifiziert; manipulierte oder unter anderem
  Namen eingeschobene Inhalte werden abgewiesen. Bestandsdateien werden atomar
  umgestellt. Bereits verschlüsselte Dateien werden beim Start nur am Kopf erkannt.
- PDF-Vorschau und externe Viewer benötigen vorübergehend lesbare Dateien im
  privaten Cache. Renderdateien werden unmittelbar entfernt, alte Viewer-Kopien
  beim nächsten Start bereinigt. Systemkamera, Play-Dienste und andere Apps können
  eigene temporäre oder ausdrücklich geteilte Kopien besitzen. Keine Zusage einer
  vollständigen Verschlüsselung sämtlicher OS-/Fremdapp-Caches oder sicheren
  forensischen Löschung.

**Vor Installation eine vollständige verschlüsselte Sicherung außerhalb der App
speichern.** Build 77 aktualisiert FLEX 62–76 mit gleicher Kennung und Signatur.
Die App nicht deinstallieren und ihre Daten nicht löschen. Nach der Migration
kein Downgrade auf Build 76: ältere Versionen können die neue Ablage nicht lesen.
Bei Verlust des Geräteschlüssels ist eine unabhängige Sicherung nötig.

Die Webvorschau bleibt bei ihrem bisherigen lokalen Browserspeicher; dort findet
keine SQLCipher-Migration statt. Für Linux wird SQLCipher nur in den automatischen
Migrationstests verwendet. Kein neuer Windows-Release und keine Windows-Abnahme.

## PIN und Sicherungen

Die PIN war bereits mit PBKDF2-SHA256 gehasht und nicht im Klartext gespeichert.
Neue PINs verwenden nun 600.000 statt 210.000 Iterationen. Bestehende PINs werden
erst nach erfolgreicher PIN-Eingabe mit neuem Salt umgestellt. Biometrie und
Fehlversuchsbegrenzung bleiben erhalten. Eine fehlgeschlagene Speicherung hebt
die Sperre nicht auf.

Neue Notizbuch-/Vollsicherungen verwenden einen versionierten v2-Container mit
600.000 PBKDF2-SHA256-Iterationen und einzeln authentifizierten 1-MiB-Blöcken.
Reihenfolge, Gesamtgröße, Format und Blockposition sind kryptografisch gebunden.
Alte v1-Sicherungen mit 310.000 Iterationen bleiben lesbar. Materialsicherungen
verwenden entsprechend FLEXMAT2; FLEXMAT1 bleibt importierbar. Unabhängig erzeugte
Altdaten-Fixtures prüfen diese Kompatibilität.

**Neue Sicherungen benötigen Build 77 oder neuer zum Öffnen.** Die JSON-Erfassung
und der Import halten weiterhin den vollständigen Datenbestand im Speicher.
Blockweise Verschlüsselung ist daher keine durchgehende Streaming-Sicherung.

### Offene Leistungsgrenze

Ein separater Linux-/Dart-JIT-Test verschlüsselte und entschlüsselte erfolgreich
100.000.048 Byte synthetisches JSON: 23,2 s Verschlüsselung, 19,2 s Entschlüsselung,
maximaler Prozess-RSS 1.002.602.496 Byte (ca. 956 MiB). Das ist ein Codec-Rundlauf,
kein vollständiger Android-Sicherungs-/Wiederherstellungstest und kein Vergleich
mit Build 76. Der Speicherbedarf großer Sicherungen bleibt zu hoch; erforderlich
ist als nächster technischer Schritt ein durchgehend gestreamter Erfassungs-,
Export- und Importpfad mit Messung auf einem speicherarmen Android-Gerät.

## Schwärzung und Dokumentversionen

- Schwärzungen bleiben auch nach Geometrieänderungen als solche gekennzeichnet;
  Rückgängig stellt den passenden Bearbeitungszustand wieder her.
- Beim Ersetzen eines geschwärzten Dokuments ist „Frühere Versionen entfernen“
  vorausgewählt. Eine separate Bestätigung erklärt Original-/Versionsverlust.
  Abbrechen erhält Dokument und Entwurf.
- Erst nach dem Speichern werden nicht anderweitig referenzierte Original- und
  Versionsdateien entfernt. Dokumente und offene Entwürfe mit denselben Bytes
  bleiben geschützt; Bereinigungsfehler werden gemeldet.
- Vorhandene externe Sicherungen, andere Kopien und geteilte Dateien werden nicht
  nachträglich bereinigt. Der Dialog nennt diese Grenzen ausdrücklich.

## Oberfläche und Auslieferung

- Eigenes creme-/olivfarbenes FLEX-Icon, Adaptive Icon und Android-Themed-Icon;
  passendes Web-Favicon und verständlicher Startzustand während der Vorbereitung.
- Veraltete Test-/Prototypbezeichnungen und mehrere technische Fehlermeldungen
  vereinfacht; „Datenschutz & Speicher“ unter Einstellungen → Bedienung ergänzt.
  Die Hinweise unterscheiden Android/Web, Geräteschlüssel, Sicherung, Teilen,
  Schwärzung sowie die Google-Play-Dienste des Dokumentenscanners.
- Zwei signierte APKs statt einer großen Universaldatei: ARM64 rund 40,2 MB,
  ARMv7 rund 35,5 MB. Beide tragen VersionCode 77 und den bisherigen Zertifikat-
  Fingerabdruck. SQLCipher ist enthalten, gewöhnliches `libsqlite3.so` nicht.
- SQLCipher-/OpenSSL-Lizenzen liegen als Assets vor und erscheinen in den
  Lizenzhinweisen. Cupertino-Fallbackschrift bleibt nach Buildprüfung erhalten.
- GitHub CI führt zusätzlich die nativen AES-GCM-Tests aus und speichert deren
  Ergebnisse. Private Signierschlüssel werden nicht in GitHub hinterlegt; CI
  baut weiterhin ausschließlich unsigniert.

## Prüfung und Grenzen

Erfolgreich abgeschlossen: **600 Flutter-Tests**, **11 SQLite-Schematests**,
**2 native JVM-Tests** und **3 Vorschau-Servertests**. Statische Analyse ohne Befunde;
214 Dart-Dateien bestehen die Formatprüfung. Release-Webbuild und beide signierten
Android-Builds erfolgreich. Die GitHub-Ausführung wird nach dem Push separat
angezeigt; lokale Erfolge sind keine vorweggenommene grüne Remote-Pipeline.

Die [Nachweise](evidence/build-77/) enthalten Analyse, Formatprüfung, vollständige
Flutter-Suite, SQLite-Schematests, native JVM-Tests, Browserprüfung, Releasebuilds,
APK-Signatur-/Integritäts-/16-KB-Prüfungen und den synthetischen Belastungstest.
Die Browserprüfung verwendet ausschließlich synthetische Daten bei 320 und
390 Pixeln; vorhandene lokale Schüler und Materialien bleiben zugänglich.

Im ersten Gesamtlauf waren elf Tests rot: veraltete Navigations-/Beschriftungs-
erwartungen, ein mehrdeutiger Widget-Finder, die inzwischen geänderte
Unteraufgaben-Erledigung sowie ein unvollständiger neuer Schema-Testdatensatz.
Die Erwartungen wurden mit dem aktuellen Verhalten abgeglichen und die Fixture
vervollständigt. Es wurden keine Tests entfernt oder Assertions ersatzlos gelöscht.
Die abschließenden Protokolle sind maßgeblich. Ein Servertest musste wegen eines
schreibgeschützten Standard-Go-Caches und gesperrter Loopback-Sockets mit
Workspace-Cache und freigegebenem lokalen Netzwerkzugriff neu starten.

**Noch nicht abgenommen:** Installation/Migration auf einem echten Handy,
Android-Keystore nach Neustart, Hintergrundsicherung nach Prozessende,
Kamera/Scanner, Biometrie, Predictive Back und Erinnerungsberechtigungen unter
aktuellen Android-Versionen. Linux-SQLCipher- und JVM-Tests ersetzen diese
Geräteprüfungen nicht. Migrationstests decken vollständiges Schema/Nutzdaten,
falschen Schlüssel, Unterbrechung und erhaltene Originaldateien ab.

Spätere Schritte bleiben „Teilen → FLEX“, eine eigene Microsoft-Appregistrierung
für OneDrive und die vollständige Streaming-Sicherung. Obfuskierung mit separat
verwahrten Symbolen und zusätzliche Signaturverfahren sind nicht Teil dieses
Builds; die bisherige v2-Signatur bleibt gültig. Keine automatische Synchronisierung
oder Änderung der Freigabe der privaten Webvorschau.
