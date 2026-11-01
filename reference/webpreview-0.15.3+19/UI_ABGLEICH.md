# Abgleich der nativen Flutter-Oberfläche mit dem aktuellen HTML

Referenz: `work/FLEX-Notizbuch/FLEX-Notizbuch.html`, identisch mit dem separaten
Upload „FLEX-Notizbuch (37).html“. Die Originaldateien wurden nicht verändert.
Die Flutter-Oberfläche besteht aus Widgets, nicht aus einer WebView.

Maßgeblich sind die zuletzt angehängten Stile und Funktionen, insbesondere
`design-system.css`, `pill-navigation.*`, `cards.js`, `pupil-overview.*`,
`orga-unified.*`, `org-lists.js`, `social-narrative.js`, `goals-refined.js`,
`homework-simple.js`, `bulk-entries.*`, `participants.js`, `review-interface.*` und `settings.*` unter `work/FLEX-Notizbuch/scratch/`.
Ältere Sidebar-Stile im HTML sind nicht die aktuelle Gestaltungsreferenz.

Der gezielte Vergleich der Eintragsdialoge samt Vorher/Nachher-Tabelle steht in
`EINTRAGSDIALOGE_ABGLEICH.md` (vorangegangener Dialogabgleich).

Die Fortsetzung mit Verlauf, Kontextbearbeitung und Gruppenrücknahme ist in
`VERLAUF_KONTEXTE_UND_RUECKGAENGIG.md` beschrieben.

Ziele und Hausübungsrückmeldungen in Version 0.6.0+6: `ZIELE_UND_HAUSUEBUNG.md`.

Gesprächsvorbereitung in Version 0.7.0+7: `GESPRAECHSVORBEREITUNG.md`.

Schülerverwaltung in Version 0.8.0+8: `SCHUELERVERWALTUNG_UND_ENTWUERFE.md`.

Papierkorb in Version 0.9.0+9: `PAPIERKORB_UND_WIEDERHERSTELLUNG.md`.

Endgültiges Leeren in Version 0.10.0+10: `PAPIERKORB_ENDGUELTIG_LEEREN.md`.

Darstellung in Version 0.11.0+11: `DARSTELLUNG_UND_LESBARKEIT.md`.

Passwortgeschützte Sicherungen in Version 0.12.0+12: `BACKUP_VERSCHLUESSELUNG.md`.

UI-/UX-Abgleich in Version 0.13.0+13: `UI_UX_ABGLEICH_2026-11-01.md`.

UI-Feinschliff in Version 0.14.0+14: `UI_VERFEINERUNG.md`.

## In diesem Stand nachgebaut

| Bereich | Native Umsetzung |
| --- | --- |
| Hauptnavigation | Zentrierte Pillen Übersicht / Schüler / …; angehobene aktive Pille; keine Sidebar und keine untere Navigation; Wischen zwischen den Hauptseiten |
| Weitere Bereiche | Archiv, Einstellungen, Entwürfe, Änderungskonflikte, Gruppenerfassungen, Klassen-Orga |
| Schüler | Suche, Hinzufügen, Bearbeiten, Farbe, Archivieren, Auswahl; Karten mit farbigem Rand, Serifennamen und fünf aus der Referenz nachgezeichneten Symbolen; 3+2-Anordnung |
| Schülerverwaltung | Zehn Originalfarben, eigene Farbe in einem separaten Farbwähler mit Farbfeld, Reglern und Hexwert, unbenutzte Farbe vorgeschlagen; Name/Farbe/Archivstatus gemeinsam speichern; dauerhafte Entwürfe mit eigener Versionsprüfung, Fortsetzen/Verwerfen, feldweiser Konfliktvergleich und lesbarer Änderungsverlauf |
| Schülerdialog | Filter Alle / Diese Woche / Offen, Suche, fünf Schnellzugriffe, Anstehend / Noch ergänzen / Zuletzt, Aufklappen, Verlauf |
| Gesamtübersicht | Überfällig / Heute / Demnächst / Ohne Termin / Noch ergänzen; getrennte Aufgaben- und Erinnerungsereignisse |
| Orga | Ein gemeinsames Feld „Notiz oder Aufgabe“; Listensymbolleiste und Vorschau; Als Aufgabe / Termin / Aufgabe erledigt; Erinnern / Zeitpunkt / Erinnerungstext / Quittierung; gespeicherte Einträge und Filter |
| Bearbeitung | Im Dialog statt auf einer zusätzlichen Vollbildseite; Speichern und Speichern & weiter; Entwürfe bei Schreibpause, Schließen, Escape und Lebenszykluswechsel |
| Ziele | Liste In Arbeit / abgeschlossen; Ziel, Zielkriterium, nächster Schritt, Zieltermin; Erreicht / Wieder öffnen; Überprüfung mit Entscheidungen Fortführen/Erreicht/Beendet, getrenntem Prüftermin, Belegen und Verlauf; Zielbezug in Beobachtungen |
| Sozialverhalten | Positiv / Negativ; originale Auswahltexte; Zeitpunkt der Situation; Beobachtung; Noch ergänzen |
| Arbeitsverhalten | Originale Auswahltexte, Positiv / Negativ, Auftrag mit zuletzt verwendeten Tags und konkrete Beobachtung |
| Hausübung | Aufgaben und Teilaufgaben mit stabilen IDs; Fach, Termin; einzelne Aufgabenstände und Kommentare; Notiz, Abgabe, chronologischer Rückmeldungsverlauf mit Korrektur/Löschen, Rückmeldungen im Schülerverlauf; erledigte Hausübungen |
| Mehrere Schüler | Mehrere auswählen / Sichtbare auswählen / Für mehrere erfassen; Sozialverhalten, Arbeitsverhalten, Hausübung und Orga; unabhängige Formulare beim Bereichswechsel; mobile Darstellung |
| Gruppenbeobachtung | Ein gemeinsamer Ablauf, eigene Texte und positive/negative Auswahlen je Kind; leere Einzelbeobachtung automatisch unter Noch ergänzen; Quelle Selbst beobachtet / Berichtet / Eigene Einordnung |
| Gemeinsame Situationen | Separater, versionierter Kontext mit beteiligten Schülern und weiteren Namen; nur erwähnte Kinder sehen Als beteiligt genannt ohne eigene Bewertung; Kontext und zusätzliche Beteiligte bearbeiten, Einzelbeobachtung direkt öffnen, Entwurf, Konfliktschutz und Verlauf |
| Gruppen-Hausübung/Orga | Eigene Aufgaben-/Checklisten-IDs und Zustände je Kind; gemeinsame Transaktion; unveränderte Trennung von Termin, Erinnerung, Quittierung und Erledigung |
| Einstellungen | Darstellung / Bedienung / Daten; originale Stilvorlagen, Live-Vorschau, gekoppelte oder getrennte Farben und sieben Transparenzen, automatische Schriftkontraste, Lesbarkeitsschutz, lokales Bild mit Tönung/Abdunklung und Aus-/Einschalten; Rundung, Schriftgröße und Schnellzugriffe |
| Papierkorb | Gemeinsamer Dialog unter Einstellungen → Daten; Schüler-/Klassen-Orga und alle Schülerbereiche; Rückgängig im offenen Dialog; Wiederherstellen mit unveränderten Inhalten/IDs und prüfbarem Erinnerungszustand; begonnene Entwürfe bleiben geschützt |
| Endgültiges Leeren | Betroffene Inhalte prüfen; Vollsicherung aus demselben Stand, Bestätigung und LÖSCHEN; atomare Bereinigung von Entwürfen/Verlauf/Operationen/Gruppenbelegen, unbenutzten Kontexten und Zielverweisen; Schutz gegen veraltete Fenster und Wiederanlage |
| Sicherungen | Dateiauswahl; Passwortschutz wie im HTML vorausgewählt, optional Klartext; Passwortprüfung vor Übernahme; eigene Vollsicherung in leeren Bestand wiederherstellen; auch verschlüsselte HTML-Originaldateien unverändert aufbewahren; Pflichtsicherung vor Bereinigung mit demselben Exportdialog |
| Verlauf | Eigener Detaildialog mit Bereich, Textsuche, Von/Bis und offener Nachbereitung; direkte Bearbeitung mit Rückkehr; laufender Eingabeentwurf bleibt erhalten |
| Gesprächsvorbereitung | Von/Bis, Einzelauswahl/Alle/Leeren, Beteiligtennamen optional, fachliche Angaben und offene Erinnerungen, geprüfte Vorschau, Kopieren und TXT-Datei; ungültige und veraltete Ausgaben geschützt |
| Gruppenrücknahme | Unveränderte Gruppen atomar zurücknehmen, Erinnerungen beenden, neuen Entwurf wiederherstellen; Revisionen und ursprüngliche Inhalte bleiben erhalten |
| Änderungen | Lesbarer Änderungsverlauf; veraltete Editorfassungen werden abgewiesen; explizite Übernahme eines geprüften Konfliktentwurfs als neue Revision |

Die Screenshots in `flutter_app/build/review/` werden von
`flutter test test/ui_review_test.dart` direkt mit der Flutter-Engine erzeugt.
Sie enthalten ausschließlich synthetische Daten. Das ist kein Browser- oder
Pixelvergleich mit einem gerenderten HTML-Prototyp.

## Noch keine vollständige Funktions- und Pixelgleichheit

Der native Nachbau wurde um Gruppenabläufe und gemeinsame Kontexte erweitert. Er ist jedoch
noch kein vollständig abgenommener 1:1-Nachbau sämtlicher HTML-Funktionen.
Insbesondere offen bzw. eingeschränkt:

- Die Darstellungsregler einschließlich Kopplung, Lesbarkeitsschutz und getrennter
  Flächen sind jetzt umgesetzt. Schriftmetriken, sämtliche Pixelabstände und das
  tatsächliche Plattformverhalten sind noch nicht als identisch abgenommen.
  Die Bildaufbereitung übernimmt jetzt die HTML-Grenzen: 12 MiB, 48 MP, lange Kante
  1600 px, JPEG mit Qualität 82/60 und maximal 1,2 Millionen Zeichen als Data-URL.
  Die Encoder von Browser und Dart können bei gleichen Qualitätswerten andere Bytes erzeugen.
- Der systemabhängige HTML-Farbwähler wird durch einen nativen Flutter-Farbwähler
  mit Farbfeld, Farbton/Sättigung/Helligkeit und Hexwert ersetzt; sein Aussehen
  ist plattformübergreifend gleich, aber nicht identisch mit allen Browser-/OS-Pickern.
  Schülerformulare haben jetzt dauerhaften Entwurfsschutz.
- Physische Speicherkompaktierung fehlt. Reversible Löschung/Wiederherstellung
  und endgültige logische Bereinigung sind jetzt vorhanden. Die Bereinigung wird
  zum Schutz offener Formulare über Einstellungen → Daten gestartet.
- HTML-Altdatenmigration, Import-Zusammenführung und
  Übernahme aller alten Beziehungen/Entwürfe sind nicht implementiert. Vorhandene
  HTML-Sicherungen werden deshalb nicht als Teilmigration aktiviert. Der gemeinsame
  Verschlüsselungscontainer ist umgesetzt; die enthaltenen Datenmodelle bleiben verschieden.
- Offline gebündelte Schriften: Selawik (Segoe-UI-Alternative) und Gelasio
  (Georgia-kompatible Metriken). CSS-Schriftgrößen, Zeilenhöhe und Dialogabstände
  wurden angeglichen. Glyphen, Kerning und Rendering bleiben gegenüber den
  proprietären Originalschriften unterschiedlich; keine pixelidentische Abnahme.
- Windows-/Android-Geräteverhalten und Dateidialoge sind hier nicht nativ geprüft.
  Weboberfläche und Browserpersistenz wurden gemäß Auftrag nicht im Browser getestet.

Synchronisation, Scanner und native Benachrichtigungen bleiben spätere Schritte.
Die App wird leer ausgeliefert. Die synthetischen Vorschau- und Testdatensätze
werden nicht in die Nutzerdatenbank eingefügt.
