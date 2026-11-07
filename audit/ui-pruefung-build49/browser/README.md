# Browserprüfung · Build 49

Chromium gegen den lokal gebauten Release-Webstand `ef9d740f26f485a5a200175f36d44b90799efb23`, bedient mit Playwright über die sichtbare Flutter-Semantik und Maus/Tastatur. Alle Daten sind synthetisch; keine produktiven Schülerdaten wurden importiert oder verändert.

## Durchgespielte Abläufe

1. Live → Notizen: zwölf Schüler anzeigen, Schüler öffnen, sichtbare Filter wechseln, bestehende Beobachtung öffnen, Text ändern und speichern.
2. Organisation: Notiz anlegen, anschließend bearbeiten und in eine Aufgabe ändern, speichern, erledigen und wieder öffnen; Rückläufe anzeigen.
3. Kalender: Kalender und Stundenplan öffnen, Wochen- und Tagesansicht wechseln; allgemeine Aufgaben und Notizen öffnen.
4. Material: Dateien, Pakete und Planungen öffnen; Kontextaktionen und gefüllte Listen ansehen.
5. Mehr → Scanner: zwei Testbilder importieren, Seite öffnen, Graustufen-Filter mit Vorschau anwenden, Reihenfolge ändern, Name und zwei Tags vergeben, PDF speichern und herunterladen. PDF mit PyMuPDF geprüft: zwei Seiten, je ein eingebettetes Bild. Raster und Liste zeigen Vorschauen.
6. Einstellungen, Bedienung und Daten auf Desktopbreite öffnen. Import und Export zusätzlich durch die Widget-Suite einschließlich großer Schrift geprüft.
7. In einem neuen Browserprofil dieselbe synthetische Sicherung importieren, alle 92 neuen Objekte zusammenführen und Schüler sowie den erhaltenen Standardstundenplan anzeigen. Ergebnis erfolgreich, keine JavaScript-Seitenfehler; rund 24 Sekunden Vorschau und 148 Sekunden Zusammenführen. Diese Laufzeit bleibt ein offener Performancepunkt und ist nicht als Messung auf einem Android-Gerät zu verstehen.

Die Ergebnisdatei und Screenshots dokumentieren diese Abläufe. Die renderbasierte Flutter-Suite prüft darüber hinaus alle 19 Unterseiten und sieben Editorvarianten in vier Layouts einschließlich 180 % Schriftgröße und simulierter Bildschirmtastatur. Die vollständige bestehende Suite ergänzt Fehler-, Wiederaufnahme-, Scanner- und Datenfälle.

Die beiden Scanner-Testbilder stammen aus `audit/dokumente-kalender-build48/browser/probe.jpg` und `perspective.jpg`. Native Kamera, Tastatur, Dateiauswahl, Fingerabdruck und Benachrichtigungen wurden nicht auf einem physischen Android-Gerät geprüft. Ein erfolgreicher Browserdurchlauf ist kein Nachweis für diese Hardwarepfade.
