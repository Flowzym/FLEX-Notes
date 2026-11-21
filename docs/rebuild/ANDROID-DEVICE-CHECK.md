# Android-Abnahme für Scanner und Teilen

Status: offen. Es ist kein physisches Android-Gerät an die Arbeitsumgebung
angeschlossen; Modell und Android-Version des Zielgeräts stehen noch aus.
Ein erfolgreicher Android-Releasebuild ist kein Nachweis für diese Kameratests.

Für ein Update muss die APK mit derselben Signatur wie die vorhandene Testapp
gebaut werden. Eine Deinstallation ist nicht Teil dieses Ablaufs. Vor dem Test
mit Build 61 eine vollständige Sicherung erstellen und deren Passwort aufbewahren.

| Fall | Durchführung | Abnahmekriterium |
| --- | --- | --- |
| Start | Scannen und Foto aus Material, Schüler und HÜ-Unteraufgabe öffnen; zuerst Berechtigung ablehnen, dann zulassen | Verständliche Rückmeldung; erneuter Start möglich; keine verlorenen Eingaben |
| Kanten | Helles Blatt auf dunklem Tisch, schräg fotografiert; anschließend Buchseite und teilweise verdeckte Ecke | Lesbare Vorschau; automatische Kante plausibel; manuelle Korrektur mit Snapping möglich |
| Schärfe/Licht | Gleiches Blatt bei Tageslicht und schwachem Licht | Vorschau vor Speichern prüfen; unbrauchbares Bild lässt sich gezielt ersetzen |
| Serie | 25 Seiten aufnehmen, umsortieren, einzelne ersetzen, Filter auf eine Teilmenge anwenden | Reihenfolge/Seitenzahl korrekt; übrige Seiten unverändert; keine Abstürze |
| Fortsetzen | Während der Aufnahme zurückkehren, App wechseln, Scanner schließen und wieder öffnen | Zuordnung und Seiten erhalten; Stapelfilter-Rückgängig weiterhin verfügbar |
| Versionen | Datei zweimal ersetzen, frühere Version ansehen und wiederherstellen, eine Version löschen | Richtige Datei wird geteilt; übrige Dateien bleiben zugänglich |
| Teilen | Einzel-PDF, Foto und mehrere Fotos an zwei installierte Ziel-Apps senden; zusätzlich abbrechen | Alle Dateien öffnen korrekt; Dateinamen stimmen; Abbruch erzeugt keinen Fehler |
| Vollsicherung | Sicherung mit Fotos, PDF und offenem Scanentwurf erstellen; in einem separaten Testprofil wiederherstellen | Alle Thumbnails/Dateien öffnen; Scanentwurf und Zuordnungen stimmen |
| Speicherfehler | Auf einem Testgerät mit wenig Speicher speichern; danach Speicher freigeben und erneut versuchen | Vorherige Datei/Entwurf bleibt erhalten; keine falsche Erfolgsmeldung |

Zu protokollieren: Modell, Android-Version, FLEX-Build, freie Speichermenge,
Seitenzahl, Laufzeit für Aufnahme/Filter/PDF/Sicherung, gewählte Teilen-Ziele und
etwaige Fehlermeldungen. Schülerdaten für dieses Protokoll durch Testdaten ersetzen.
