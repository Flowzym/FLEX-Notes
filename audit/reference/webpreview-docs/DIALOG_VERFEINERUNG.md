# Dialogverfeinerung – 0.15.3+19

Die Änderungen folgen den Rückmeldungen zu den Eintragsdialogen. Der HTML-Prototyp
bleibt unverändert; die Umsetzung liegt ausschließlich im Flutter-Unterordner.

## Kalender und Zeitpunkte

- Die Datumsleiste öffnet einen Kalender mit optionaler Uhrzeit. „Uhrzeit hinzufügen“
  blendet Stunde und Minute direkt im Kalender ein; das Kreuz entfernt die Uhrzeit.
  Der bisherige Uhrzeit-Schalter und der zweite Zeitdialog entfallen.
- „Übernehmen“ übernimmt Datum und Uhrzeit gemeinsam. Schließen verwirft die
  Kalenderänderungen. Ohne Uhrzeit bleibt fachlich von 00:00 unterschieden.
- Dieser Ablauf gilt für die Datumsleisten von Zielen, Sozialverhalten,
  Arbeitsverhalten, Hausübungen, Orga und Gruppenerfassung sowie für Abgabenotizen.
  Erinnerungen verwenden denselben Kalender mit erforderlicher Uhrzeit.
  Reine Fälligkeitstermine bleiben Kalenderdaten ohne Uhrzeit.
- Die Situationsauswahl heißt „Vor Unterricht“, „Unterricht“, „Nach Unterricht“,
  „Pause“. Bereits gespeicherte lange Bezeichnungen bleiben lesbar; der Editor
  zeigt sie gekürzt. Es erfolgt keine Massenänderung bestehender Einträge.

## Darstellung und Felder

- Unter Einstellungen → Darstellung → Dialoge gibt es eine gemeinsame eigene
  Farbe für Kopfzeile, Datumsleiste und Fußzeile. Die beiden Transparenzwerte
  bleiben getrennt. Bei aktivierter Flächenkopplung wird die Farbe wie die anderen
  Flächenfarben gekoppelt; „Zurücksetzen“ stellt die automatische Farbe wieder her.
- Die Farbe ist ein optionales Feld der bestehenden Darstellungspräferenz und
  wird mit der Vollsicherung übertragen. Alte Sicherungen ohne dieses Feld bleiben
  lesbar. Datenbank und inneres Sicherungsformat bleiben Version 7.
- Auswahlbuttons zeichnen ihre durchgehende Fläche nur einmal. Text und
  Favoritenstern verwenden transparente Unterflächen. Damit erhalten beide bei
  teilweiser Transparenz dieselbe Hinterlegung. Filterchips nutzen ebenfalls die
  gewählte Buttonfarbe; aktive Auswahl und Positiv-/Negativfarben bleiben erkennbar.
- Der Abstand unter Positiv/Negativ beträgt jetzt 4 statt 20 Pixel.
- Entwurfshinweise in Eintragsdialogen sind kompakte, insgesamt anklickbare Zeilen
  mit höchstens einer Vorschauzeile. Schülerentwurfshinweise und Statuszeilen
  haben ebenfalls weniger Höhe. Fehlermeldungen bleiben vollständig sichtbar.
- „Weitere Angaben“ und der dazugehörige Trenner entfallen. „Kontext / Quelle“
  verwendet einen Schalter statt eines Aufklapp-Pfeils. „Reaktion / Unterstützung“
  bleibt ein eigener Schalter. „Beteiligt“ ist auch im Arbeitsverhalten verfügbar.
- Ergänzende Ziel-, Hausübungs- und Gruppenfelder sowie „Abgabe & Zeitpunkt“ haben
  einheitliche Bereichsschalter. Hauptinhalte bleiben direkt zugänglich.
  Das Einklappen dieser Abschnitte löscht keine Werte; bereits gefüllte Felder
  werden beim erneuten Öffnen eingeblendet. Empfänger sind zunächst sichtbar.

## Prüfungen

Regressionstests verwenden ausschließlich synthetische Daten. Sie prüfen
Kalenderübernahme und Abbruch, Mitternacht und fehlende Uhrzeit, Entwürfe,
Speicherung eingeklappter Felder, alte Situationsbezeichnungen, gemeinsame
Dialogleistenfarbe mit Backup-Rundlauf und tatsächlich gezeichnete Buttonpixel.
Die Rückmeldungshistorie behält ihren Aufklappzustand auch nach dem Bearbeiten
eines Eintrags und beim Scrollen.

Direkte Flutter-Ansichten 71–74 zeigen den kompakten Desktop-/Mobildialog,
die Bereichsschalter und den Kalender mit Uhrzeit. Aktuelle Ergebniszahlen und
Build-/Startnachweise stehen in `FLUTTER_STATUS.md` und
`flutter_app/review/dialog-evidence/`.

Keine Browserprüfungen oder nativen Windows-/Android-Gerätetests. Kein öffentliches
Deployment und keine Veröffentlichung der Cloud-Umgebung.
