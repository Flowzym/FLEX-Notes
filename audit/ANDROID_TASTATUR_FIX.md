# Android: Tastatur bleibt bei Dialogeingaben geöffnet

Stand: **0.16.0-rebuild.10+30**, 02.11.2026.

## Fehler und Korrektur

Beim Öffnen der Bildschirmtastatur unterschritt die verfügbare Dialoghöhe die
520-px-Grenze. `FlexModal` wechselte dann zwischen einem Layout mit festen Kopf-/Fußzeilen
und einem vollständig scrollbaren Dialog. Die Eingabefelder wurden dabei aus dem alten
Widget-Unterbaum entfernt und neu angelegt. Dadurch wurden `EditableTextState` und
teilweise auch interne Fokus-/Textcontroller verworfen; die Verbindung zur Tastatur
wurde geschlossen.

Die Dialogabschnitte behalten jetzt dauerhafte Identitäten in einem eigenen StatefulWidget.
Kopf, Inhalt und Fuß werden beim Layoutwechsel mit ihren bestehenden Zuständen umgehängt.
Das adaptive Scrollverhalten bleibt bestehen. Fokus, Cursor, Textmarkierung und aktive
IME-Komposition bleiben erhalten; die Tastatur muss nicht erneut angefordert werden.
Die gemeinsame Korrektur gilt für alle `FlexModal`-Dialoge.

Die vorherigen Tests hatten überwiegend den Tastatur-Inset bereits vor dem Aufbau gesetzt.
Der kritische Wechsel bei aktivem Eingabefeld fehlte. Ein neuer Reproduktionstest scheiterte
vor der Korrektur bei 80, 100 und 120 % App-Skalierung jeweils an einem entsorgten
`EditableTextState` und besteht mit der Korrektur.

## Prüfungen

- 11 gezielte Regressionstests: animierte Tastaturhöhen bis 460 px, Schließen und erneutes
  Öffnen, 80/100/120 % App-Skalierung, Eingaben in Kopf-/Fußbereich, aktive Textkomposition.
- Eingabe, Entwurfsspeicherung und abschließendes Speichern mit Tastaturwechseln in allen
  sechs Formularbereichen: Schüler, Orga, Sozial, Arbeit, Ziele und Hausübungen.
- Die Tests senden Text über die bestehende IME-Verbindung, ohne zwischenzeitlich erneut
  Fokus anzufordern. Sie prüfen auch, dass kein `TextInput.hide` ausgelöst wird.
- Vollständiger Flutter-Testlauf mit **171 erfolgreichen Tests**, statische Analyse ohne
  Befunde und erfolgreicher Android-Releasebuild.
- APK-Paketkennung, Versionsnummer, Start-Activity, native Bibliotheken, Signatur und
  16-KB-Ausrichtung werden geprüft. Der Signaturfingerabdruck muss mit der vorherigen APK
  übereinstimmen.

Nachweise: [Fehler vor der Korrektur](evidence/keyboard-reproduction.log),
[gezielte Tests](evidence/keyboard-focused-tests.log),
[Gesamttest](evidence/keyboard-flutter-tests.log),
[Analyse](evidence/keyboard-analyze.log),
[APK-Build](evidence/keyboard-apk-build.log),
[APK-Prüfungen](evidence/keyboard-apk-verification.json),
[Quellprüfsummen](evidence/keyboard-source-sha256.txt).

APK: **64.346.972 Bytes**, SHA-256
`16d8a1fa544363cc8fb0e91796b0c704f767597c97fb37fe559d74d78ac60b7e`.
Die Signatur stimmt mit dem ersten Test-Build überein.

## Installation und Grenzen

Die korrigierte APK ist ein Update für **FLEX Test**: gleiche App-ID
`at.flowzym.flex_notizbuch.test`, gleicher Testschlüssel, Versionscode **30** statt 29.
Über die vorhandene App installieren; nicht deinstallieren. Der Datenbestand bleibt bei
einer normalen Android-Aktualisierung erhalten. Das Datenbankschema wurde nicht geändert.

Die Fokuskorrektur ist durch reproduzierende Flutter-Tests belegt. Hier war weiterhin kein
Android-Gerät angeschlossen; ein realer Tastaturlauf auf dem Nutzergerät steht noch aus.
Keine Browsertests und kein Store-Release.

[Installationsanleitung](../flutter_app/ANDROID-TEST.md) ·
[Erster Android-Build](ANDROID_TESTAPP.md)
