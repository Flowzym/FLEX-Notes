# Passwortgeschützte Sicherungen – Version 0.12.0+12

Der Flutter-Nachbau übernimmt den Dateischutz aus dem aktuellen HTML-Prototyp.
Referenz ist die unveränderte Datei `work/FLEX-Notizbuch/scratch/backup-crypto.js`.
Die 145 Originaldateien werden nicht verändert.

## Bedienung

Unter **… → Einstellungen → Daten → Exportieren** ist **Sicherung mit Passwort
verschlüsseln** vorausgewählt. Das Passwort muss wie im HTML mindestens zwölf
Zeichen lang sein. Wie im HTML genügt ein Passwortfeld. Die Augen-Schaltfläche
kann es sichtbar machen. Nach erfolgreicher Ausgabe wird der
Dialog geschlossen. Dateiabbruch und Schreibfehler melden keinen Erfolg und
lassen einen neuen Versuch zu. Klartext ist durch Abschalten der Verschlüsselung
weiterhin ausdrücklich wählbar.

**Importieren** erkennt geschützte Dateien automatisch. Falsche Passwörter oder
veränderte verschlüsselte Daten bleiben ohne Auswirkung auf den Datenbestand.
Ein neuer Passwortversuch ist im selben Dialog möglich. Erst nach erfolgreichem
Öffnen erscheint **Sicherung prüfen** mit einer gesonderten Übernahmeaktion.
Abbruch vor der Bestätigung verändert keine Daten.

Die Pflichtsicherung vor **Papierkorb endgültig leeren** verwendet denselben
Exportdialog. Sie sichert weiterhin exakt den zur Bereinigung geprüften Stand.
Erst eine erfolgreiche Dateiausgabe schaltet die bisherige Bestätigung frei;
Passwortfehler, Verschlüsselungsfehler oder Dateiabbruch geben keine Löschung frei.
Ein inzwischen veränderter Datenstand wird weiterhin abgewiesen.

Passwörter werden nicht in Einstellungen, Entwürfen, Sicherungsinhalten oder Logs
aufbewahrt. Passwortfelder verwenden keine Wiederherstellung, Autovervollständigung
oder persönliche Tastaturvorschläge. Beim erneuten Öffnen sind sie leer.
Ohne Passwort gibt es keine Wiederherstellung. Vollständiges forensisches Löschen
von Stringkopien aus dem Arbeitsspeicher wird nicht zugesichert.

## Format und technische Trennung

Die neue Abhängigkeit `cryptography` ist auf **2.9.0** festgelegt. Sie stellt die
Standardverfahren bereit; die App implementiert keine eigenen Kryptoprimitiven.
Der Container bleibt mit der HTML-Referenz kompatibel:

| Feld | Wert |
| --- | --- |
| format / version | FLEX-Encrypted / 1 |
| Schlüsselableitung | PBKDF2-SHA256, 310000 Iterationen, 256 Bit |
| salt | 16 zufällige Bytes, Base64 |
| Verschlüsselung | AES-256-GCM |
| iv | 12 zufällige Bytes, Base64 |
| Zusatzdaten | UTF-8 von FLEX-Encrypted-1 |
| ciphertext | Verschlüsselte UTF-8-JSON-Daten mit angehängtem 16-Byte-Authentifizierungstag, Base64 |

Jede Ausgabe verwendet neue Zufallswerte. Unbekannte Formatversionen,
abweichende Ableitungsparameter, beschädigte Base64-Felder und falsche Längen
werden abgewiesen. Die Authentifizierung erfolgt vor dem Lesen des Klartexts als
JSON. Passwörter werden weder getrimmt noch normalisiert; Unicode und Leerzeichen
sind Bestandteil des Passworts.

`security/backup_codec.dart` behandelt Format und Kryptografie.
`application/backup_protection.dart` führt die Arbeit auf nativen Plattformen in
einem Isolate aus; im Web verwendet die Bibliothek Web Crypto, soweit verfügbar.
Dateiein- und -ausgabe haben eigene Schnittstellen, Dialoge enthalten nur den
Bedienungsablauf. Während laufender Vorgänge sind Doppelklick und Schließen gesperrt.

Die Dateigrenze beträgt 28 MB für den verschlüsselten JSON-Container; dessen
unverschlüsselter Inhalt darf höchstens 20 MB UTF-8 umfassen. Der zusätzliche Platz
berücksichtigt Base64. Dateistreams werden begrenzt eingelesen; falsche oder fehlende
Größenangaben erlauben kein unbegrenztes Sammeln im App-Puffer. Größere Daten werden
abgewiesen und nicht abgeschnitten. Die Größenlimits des Plattform-Dateiwählers
selbst und dessen Verhalten müssen noch auf Geräten geprüft werden.

## Kompatibilität und Datenübernahme

SQLite-Schema und Flutter-Vollsicherungsformat bleiben **Version 7**.
Unverschlüsselte Flutter-Sicherungen 1–7 bleiben nutzbar. Geschützte
Flutter-Vollsicherungen werden nach dem Öffnen vom bestehenden transaktionalen
Wiederherstellungspfad geprüft und nur in einen leeren Arbeitsbereich übernommen.
Schüler, Beziehungen, Erinnerungen, Entwürfe, Verlauf und Darstellung bleiben dabei
im bestehenden Sicherungsformat enthalten.

Geschützte aktuelle HTML-Sicherungen (Version 3, Schema 5) können nun geöffnet und
geprüft werden. Beim Vormerken wird die verschlüsselte Originaldatei bytegleich
aufbewahrt, nicht ihre entschlüsselte Fassung und nicht ihr Passwort. Wiederholtes
Vormerken derselben Originaldatei erzeugt keine Kopie. Die ursprüngliche Datei ist
auch Bestandteil späterer Flutter-Vollsicherungen.

Die gemeinsame Verschlüsselungshülle bedeutet keine Gleichheit der enthaltenen
Datenmodelle: HTML-Daten werden weiterhin **nicht als Flutter-Einträge aktiviert**.
Vollständige Migration einschließlich Beziehungen, Zusammenführung, Historien und
Entwürfen bleibt offen. Bei späterer Verarbeitung einer vorgemerkten geschützten
HTML-Datei wird ihr Passwort erneut benötigt. Der HTML-Prototyp kann Flutter-Daten
nicht als seinen eigenen Datenbestand importieren.

Der Dateischutz verschlüsselt weder die lokale SQLite-/Browserdatenbank noch schon
vorhandene Klartextdateien. Synchronisation und Geräteschlüssel sind unverändert
späteren Schritten vorbehalten.

## Lokale Nachweise

Ausschließlich synthetische Daten. Flutter-Tests prüfen echte Ver- und
Entschlüsselung, Zufälligkeit, Manipulationen, falsche Passwörter, Format- und
Größengrenzen, Datei-Neustart nach Wiederherstellung und unveränderte HTML-Aufbewahrung.
Widgettests prüfen Mindestlänge, sichere Voreinstellung, Klartextwahl,
Abbruch, Fehler, erneuten Versuch, Bestätigung und mobile Bedienung.

`tool/test_backup_interop.cjs` führt die unveränderten HTML-Kryptografiefunktionen
mit Node Web Crypto aus. Die von diesen Funktionen erzeugte synthetische Testdatei
wird in Dart entschlüsselt; die von Dart erzeugte Datei wird mit denselben
HTML-Funktionen geöffnet. Das ist ein lokaler Formatvergleich, kein Browsertest.

Nach `flutter test --no-pub test/backup_codec_test.dart`:
`node tool/test_backup_interop.cjs`.
Die Fixture-Erzeugung mit `--generate-fixture` wird nur zum bewussten Erneuern der
synthetischen Referenzdatei benötigt. Aktuelle Ergebnisse: `FLUTTER_STATUS.md`.
