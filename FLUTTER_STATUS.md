# Aktueller Flutter-Stand

**0.30.1+81**, Branch `redesign/cream-olive`.

Build 81 korrigiert die Wischrichtung: links wischen wählt den Reiter rechts.
Die umgekehrte Grundeinstellung aus Build 80 wird einmalig zurückgesetzt;
anschließende eigene Richtungswahl bleibt erhalten. Der Abstand von der
Dreipunktzeile zur oberen Navigation ist um 8 Pixel reduziert.

[Änderungen und Grenzen](docs/rebuild/NAVIGATION-BUILD-80.md) ·
[Private Webvorschau](https://flex-notizbuch-vorschau-40.maoam.chatgpt.site/) ·
[GitHub-PR](https://github.com/Flowzym/FLEX-Notes/pull/1) ·
[Android-APKs](releases/android/build-81/README.md).

Einheitliche Navigationspillen, wählbare Wischrichtung und Standardreiter;
Notizen mittig unter Live. Weitere Bereiche oben rechts, Scanner unten direkt.
Klassen-Orga unter Organisation mit sichtbaren Filtern. Termin-Tags bleiben in
Entwürfen, Vorlagen, Sicherungen und Importkonflikten erhalten und sind suchbar.

Kalendertermine und einzelne Unterrichtsstunden lassen sich per langem Drücken
verschieben und an den Griffen zeitlich anpassen. Wischrichtung bleibt beim Umlauf
von Tag/Woche/Monat gleich; Tages-/Wochenraster nutzen die Höhe besser.

Review-Ergänzungen: Schuljahresabschluss, Archiv und ausdrückliche Löschprüfung;
Pseudonyme für Gesprächsberichte; Eintragsvorlagen/Katalogaustausch; lokales
Fehlerprotokoll; Schüler-Papierkorb, Zeitstempel und Volltextindex. Tabletansicht
mit Schülerliste und Details nebeneinander. Android ergänzt Widget/Shortcuts,
geschützte Benachrichtigungsaktionen, Offline-Diktat und eine eigene Kamera mit
Live-Kantenerkennung ohne Google Play Services.

Schema-8-Migration erhält bestehende Daten. Neue Sicherungen benötigen Build 79;
ältere Sicherungen bleiben lesbar. Vor Installation eine unabhängige vollständige
Sicherung anlegen. APKs verwenden das bestehende dauerhafte Zertifikat.

Der [taggesteuerte Releaseprozess](docs/rebuild/RELEASING.md) ist implementiert,
die Einrichtung der GitHub-Signiersecrets ist wegen fehlenden Zugriffs (403)
noch nicht bestätigt. Branch-/PR-CI baut weiterhin ohne Signierschlüssel.
[Physische Android-Abnahme](docs/rebuild/ANDROID-ACCEPTANCE-BUILD-79.md) und eigene
Microsoft-Appregistrierung bleiben offen. Lokale und automatisierte Prüfungen
belegen keine Kamera-, Diktat- oder Launcherfunktion auf einem konkreten Handy.
