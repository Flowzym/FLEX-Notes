# FLEX Desktop

Eigenständige Windows-Anwendung für die FLEX-Klasse. Eigener Programmeinstieg,
Windows-Runner, Datenbank und Desktop-Oberfläche; keine verbreiterte Android-Seite.

## Arbeitsbereiche

- Arbeitsplatz mit Schüleraktionen und Tageskontext.
- Wochenmappe mit Tagesauswahl, Terminen, Fristen, HÜ, Rückläufen und individuell
  geplanten Unterlagen. Weitere Materialien lassen sich für den Unterrichtstag
  bereitlegen. Die Woche lässt sich als PDF auf dem Gerät speichern.
- Klasse & Journal mit Schülerliste, Verlauf und Hausübungskontrolle.
- Dauerhaft sichtbarer Editor für Sozial, Arbeit, Ziele, HÜ, Notizen, Aufgaben,
  Termine, Rückläufe, Planungen und Unterricht. Entwürfe bleiben beim Wechsel erhalten.
- Tages-, Wochen- und Monatskalender. Termine anlegen, ziehen und am unteren Rand
  verlängern. Stundenplan und Fristen werden gemeinsam angezeigt.
- Unterrichtsplanung mit Zuständen, Schülern, Materialien und Nachbereitung.
- Materialliste mit PDF-/Bild-/DOCX-Textvorschau, Mehrfachimport,
  Mehrfachzuordnung und individuellen Unterrichtsdaten. Der OneDrive-Explorer
  unterstützt Ordnerregeln und Schülerkürzel. Kürzel und Dateinamen lassen
  sich im Schülerprofil pro Schuljahr pflegen.
- Organisation mit kombinierbaren Filtern für Eintragsart und Bearbeitungsstand,
  überfälligen Aufgaben und Rückläufen. Die Suche berücksichtigt Unteraufgaben
  und Personen.
- Strg+K durchsucht Einträge, Profile, Dateien und Planungen. Pfeiltasten und
  Eingabe öffnen einen Treffer oder starten eine neue Eingabe.
- Verschlüsselte FLEX-Sicherungen, Import mit Vergleich, Entwürfe und Papierkorb.

## Windows installieren

Der Workflow **FLEX Desktop** erzeugt einen Installer und ein portables ZIP für
Windows x64. Beim portablen Paket den vollständigen Ordner entpacken und
`flex_desktop.exe` starten. Der Installer installiert ohne Administratorrechte.
Daten liegen im Benutzerprofil außerhalb des Programmordners und bleiben bei
Updates und Deinstallation erhalten. Die Windows-Programme sind nicht mit einem
kommerziellen Authenticode-Zertifikat signiert.

Android und Desktop speichern unabhängig. Eine vollständige `.flexbackup`-
Sicherung übernimmt Einträge und Dateien. OneDrive liefert Materialien, keinen
automatischen Abgleich der Notizbücher. Für die Anmeldung per Microsoft-Code muss
in Entra die Unterstützung öffentlicher Clients aktiviert sein; die Android-
MSAL-Weiterleitung wird unter Windows nicht verwendet.

## Entwicklung

Flutter 3.47.9 (`c197ca5199e9ee5661e865596c9c07294dfab51c`).
Die Fachlogik und Repository-Implementierung werden als lokale Paketabhängigkeit
von `../flutter_app` verwendet. Es werden keine mobilen Seiten als Hauptseiten
oder mobile Navigationscontainer eingebunden.

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
python3 tool/prepare_web.py
flutter build web --release --no-pub --no-web-resources-cdn --no-wasm-dry-run
# Auf Windows mit Visual Studio Desktop development with C++:
flutter build windows --release --no-pub
```

Web: SQLite/WASM mit eigenem Datenbanknamen `flex_desktop_v1`. `?demo=1` öffnet
`flex_desktop_demo_v1` mit ausschließlich erfundenen Daten. Demo niemals implizit
in einen echten Arbeitsplatz importieren. Windows nutzt zusätzlich eine eigene
Anwendungsidentität (`at.flowzym` / `FLEX Desktop`).

Strg K: suchen/wechseln. Strg N: neue Notiz. Strg Eingabe: speichern.
Die Datensicherung umfasst auch Datentypen, die noch keinen eigenen Desktop-
Spezialeditor haben. Native Android-Kamera/Randerkennung, Android-Benachrichtigungen
und Widgets gehören nicht zu diesem Windows-Build. Importierte Unterrichtsabläufe,
Historien, Archivdaten und Scannerentwürfe bleiben im Datenformat erhalten; nicht
jeder Android-Spezialdialog ist schon am Desktop verfügbar.

Die lokale Windows-Datenbank ist nicht zusätzlich verschlüsselt. Exportierte
Sicherungen können verschlüsselt werden. Windows-Anmeldeschutz bzw. BitLocker
bleiben von FLEX unabhängig.
