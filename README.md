# FLEX-Notes – Wiederherstellungssicherung

Dieser Branch `recovery/webpreview` sichert die verfügbaren Originalarchive und den Prüfbericht vom 1. November 2026. Er enthält **keine vollständige Wiederherstellung des zuletzt genannten Flutter-Arbeitsstands `0.16.0+20`**.

## Gesicherte Versionsstände

| Version | Vorhanden | Fehlend / Grenze |
| --- | --- | --- |
| **0.1.0+1** | Zwei ältere Flutter-Quellarchive; beide `pubspec.yaml` nennen diese Version. Je Archiv sind 14 Dart-Dateien enthalten. | Ihre Buildfähigkeit wurde nicht geprüft. Sie bilden nicht den neueren Entwicklungsstand ab. |
| **0.15.3+19** | Unverändertes Webpreview-ZIP mit gebauter Webanwendung, SQL-Schema 7, Assets und Dokumentation; dazu der gesicherte Prüfbericht. | Die zugehörigen Flutter-/Dart-Quellen, `pubspec.yaml`, `pubspec.lock`, Tests und nativen Projektdateien fehlen im Webpreview-Paket. |
| **0.16.0+20** | Nur die Angabe des Nutzers zum zuletzt bearbeiteten Stand. | **Die neueren Flutter-Quellen und ein Build dieser Version fehlen in den gesicherten Materialien.** |

Die Versionsstände liegen getrennt und wurden nicht zusammengeführt. Insbesondere wurden die Quellen von `0.1.0+1` weder als `0.15.3+19` noch als `0.16.0+20` ausgegeben.

## Ablage

- [Webpreview-Original 0.15.3+19](recovery/webpreview/0.15.3+19/FLEX-Notizbuch-Flutter-Dialog-Verfeinerung-Webvorschau.zip)
- [Prüfbericht zum Webpreview](recovery/webpreview/0.15.3+19/PRUEFBERICHT.md)
- [Quellarchiv 0.1.0+1](recovery/flutter-sources/0.1.0+1/FLEX-Notizbuch-Flutter-Quellen.zip)
- [Archiv „Neue Dateien“ 0.1.0+1](recovery/flutter-sources/0.1.0+1/FLEX-Notizbuch-Flutter-Neue-Dateien.zip)
- [SHA-256-Prüfsummen der sechs gesicherten Dateien](recovery/SHA256SUMS)

Die beiden bereits vorhandenen `.zip.sha256`-Begleitdateien der Quellarchive wurden ebenfalls unverändert übernommen. Die Quellarchive stammen aus `/workspace/exports`; das Webpreview stammt aus dem vom Nutzer hochgeladenen ZIP. Alle Archive und der Prüfbericht wurden bytegleich kopiert. Das Webpreview-ZIP wurde nicht neu gepackt oder verändert.

## Wiederherstellbarkeit

Das Webpreview erhält den kompilierten Stand **0.15.3+19**. Seine 47 Webdateien, das SQL-Schema mit 19 Tabellen, mitgelieferte Schriften und weitere Laufzeitdateien sowie 18 Markdown-Dokumente sind verfügbar. Persönliche Notizbuchdaten oder Nutzersicherungen sind nicht enthalten.

Es gibt genau eine Source Map: `drift_worker.js.map` mit 160 Quellenverweisen, aber **ohne eingebettete Quelltexte (`sourcesContent`)**. Die referenzierte Projektdatei `tool/drift_worker.dart` fehlt. Auch `main.dart.js.map` und die vom Flutter-Loader referenzierte `flutter.js.map` fehlen. Die Laufzeit-Symboldateien liefern keine Dart-Quellen der FLEX-App. Minifiziertes `main.dart.js` ersetzt kein bearbeitbares Flutter-Projekt und erlaubt keine verlustfreie Rückgewinnung der Originalquellen.

Für die exakte Wiederherstellung des zuletzt bearbeiteten Stands wird ein zusätzliches Quellarchiv oder ein Git-Stand von **0.16.0+20** benötigt. Auch die Flutter-Quellen von **0.15.3+19** liegen in den hier gesicherten Materialien nicht vor.

## Integrität prüfen

Im Wurzelverzeichnis des Repositorys:

```sh
sha256sum -c recovery/SHA256SUMS
```

SHA-256 des unveränderten Webpreview-Originals:

```text
b29aa3c067014637fa279a19c493e6928322cedc5aa1d45d2f80bd5777cc3693
```

Die ZIP-CRC-Prüfung aller drei Archive und der Vergleich mit den vorhandenen Prüfsummen waren erfolgreich. Beim Webpreview stimmen alle 71 Dateien des internen Manifests überein. Der Prüfbericht wurde als unveränderte Momentaufnahme übernommen: Seine lokalen Pfade, Prozessangaben und Verweise auf zusätzliche Prüfdateien beziehen sich auf die damalige Cloud-Sitzung und garantieren keinen laufenden Server nach einem Checkout. Die zusätzlichen lokalen Prüfdateien und das Startskript sind nicht Bestandteil dieser Sicherung.

Es wurden keine Browsertests ausgeführt. Der in der Cloud gestartete HTTP-Server und die Datei-/Prüfsummenprüfungen belegen keine geprüfte Browseroberfläche oder Datenpersistenz. Diese Sicherung veröffentlicht keine Cloud-Umgebung und führt kein Deployment aus.
