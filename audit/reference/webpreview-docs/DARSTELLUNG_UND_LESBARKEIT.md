# Darstellung und Lesbarkeit – Version 0.11.0+11

**Nachtrag 0.15.2:** Manuelle Transparenzänderungen an Leseflächen schalten den
übersteuernden Lesbarkeitsschutz aus; schnelles Ändern mehrerer Werte ist korrigiert.
Aktueller Stand: [SETTINGS_KORREKTUREN.md](SETTINGS_KORREKTUREN.md).

Referenz sind `synchronizeAppearance`, `applySurfaceAppearance`,
`applyControlAppearance`, `applyModalAppearance`, `appearancePresets`,
`applyReadability` und die zuletzt angehängten Einstellungen der aktuellen
HTML-Datei. Alle Originaldateien bleiben unverändert.

## Nachgebaute Bedienung

Unter **… → Einstellungen → Darstellung** stehen die Stilvorlagen **Ruhig**,
**Bild dezent** und **Bild klar**. Bildvorlagen werden erst nach der Auswahl eines
Bildes freigegeben. „Ruhig“ schaltet das Bild aus, bewahrt es aber für später auf.
**Bild verwenden**, Tönungsfarbe, Tönungsstärke und Abdunklung sind getrennt.
Das Bild wird erst mit **Bild entfernen** aus der Darstellung entfernt.

**Alle Flächen gemeinsam einstellen** übernimmt beim Einschalten die Buttonwerte.
Danach werden Farbänderungen auf Kopfbereich, Schülerkarten, Buttons, Eingabefelder
und Dialoghintergrund übertragen. Transparenzänderungen gelten zusätzlich für
Dialogkopf und Dialogfuß. Nach dem Ausschalten bleiben die zuletzt gemeinsamen
Werte bestehen und können wieder unabhängig geändert werden. Stilvorlagen
verwenden dabei die Reihenfolge der Kopplungsregeln des Prototyps.

Die Gruppen **Hauptoberfläche**, **Schaltflächen & Eingaben** und **Dialoge** bieten
getrennte Farben, sieben Transparenzwerte, die originalen Farbvorschläge,
automatische Farbanpassung und Zurücksetzen je Fläche. **0 %** ist deckend,
**100 %** entfernt die Farbfüllung. Text, Symbole und aktive Auswahlen werden nicht
transparent. Die Fußzeile umfasst auch Datum und Nachbereitung in Eintragsdialogen.
Akzentfarbe, Kartenrundung, Schriftgröße und kompakte Abstände bleiben verfügbar.

Die Live-Vorschau verwendet dieselben Komponenten wie die tatsächliche Oberfläche:
Kopfbereich, Schülerkarte, Dialogkopf/-fuß, Button und Eingabefeld. Sie zeigt
synthetische Inhalte und legt keinen Schülerdatensatz an. Auf schmalen Fenstern
kann die Vorschau auf- und zugeklappt werden; ihr Zustand wird getrennt von der
Scrollposition aufbewahrt.

Regler ändern die sichtbare Darstellung sofort. Nach 250 ms Pause beziehungsweise
beim Loslassen wird gespeichert. Auch das Verlassen der Einstellungsseite sichert
einen noch ausstehenden Wert. Langsame Speicherungen werden in Reihenfolge
abgearbeitet, während neuere Eingaben sichtbar bleiben. Bei einem Fehler wird der
zuletzt erfolgreich gespeicherte Stand wieder angezeigt; die Fehlermeldung bleibt
auch nach einem Seitenwechsel erreichbar.

## Farben, Bilder und Lesbarkeit

`SurfaceAppearance` enthält unveränderliche Flächenwerte und die Kopplungsregeln.
`FlexPalette` berechnet Füllung, wahrgenommene Hintergrundfarbe und passende
Schriftfarben. Buttons, Schreibfelder, Auswahllisten sowie Dialogkopf/-fuß haben
jeweils eigene Vordergrundfarben. Auch positive/negative Tags bleiben unterscheidbar.

**Lesbarkeitsschutz** macht Leseflächen bei eingeschaltetem Bild deckend, ohne die
gespeicherten Transparenzwerte zu überschreiben. Gewählte Flächenfarben bleiben
berücksichtigt. Karten und Kopfbereich werden bei voller Transparenz nicht
weichgezeichnet. Bild, Tönung und Abdunklung liegen in getrennten Hintergrundebenen;
sie verblassen keine Texte oder Bedienelemente. Das gleiche lokale Bild erscheint
auch in Dialogen. Bereits geladene Bildbytes werden bei Reglerbewegungen nicht
jedes Mal neu dekodiert.

Die Kontrasttests beziehen sich auf berechnete einfarbige beziehungsweise
zusammengesetzte Flächen und prüfen mindestens 4,5:1 für normale und sekundäre
Schrift. Sie garantieren keinen Kontrast zu jedem einzelnen Pixel eines beliebigen
Bildes bei ausgeschaltetem Lesbarkeitsschutz. Dafür bleibt der Hinweis des
Prototyps zu unruhigen Bildern sichtbar. Zusätzlich erhalten allgemeine Lesepanels
bei aktiviertem Schutz einen deckenden Hintergrund.

## Speicherung und Kompatibilität

Datenbank und Vollsicherungsformat bleiben **Version 7**; es gibt keine neue
Datenbankmigration. Neue Darstellungswerte ergänzen den bestehenden
`preferences.appearance`-Eintrag. Alte Flutter-Einstellungen ohne diese Werte
bleiben lesbar: gespeicherte Deckkraftwerte, Hintergrundbild, Rundung,
Schriftgröße und Schnellzugriffsreihenfolge werden übernommen. Ein älteres Bild
erhält beim Lesen keine zusätzlich erfundene Farbtönung.

Vollsicherungen enthalten auch die neuen Flächenwerte und Bildoptionen. Ungültige
Transparenzen, nicht endliche Werte, ungültige Farben oder widersprüchliche
gekoppelte Werte werden abgewiesen. Ein entsprechender Fehler in einer Sicherung
rollt den gesamten Import zurück. Änderungen an der Darstellung verändern keine
Schüler, Einträge, Entwürfe oder fachlichen Änderungsverläufe.

`NotebookController` trennt den gespeicherten Stand von der sichtbaren Vorschau.
Schreibvorgänge werden geordnet; eine frühere Speicherung kann eine neuere
Vorschau nicht überschreiben. Die bestehende Speicherpflege-Sitzungssperre des
Repositorys gilt weiterhin.

## Prüfung und verbleibende Unterschiede

Synthetische Tests prüfen Kopplung/Entkopplung, Stilvorlagen, Transparenzgrenzen,
Kontrast, unveränderte Bildaufbewahrung, Alt-Einstellungen, SQLite-Dateineustart,
Sicherungswiederherstellung, fehlerhafte Importe und verzögerte Schreibvorgänge.
Widgettests prüfen reale Eingabedialoge mit hellen Feldern, unveränderte Texte und
Tags, mobile Darstellung bei 320 Pixel Breite mit größerer Schrift/Tastatur,
Seiten- und Größenwechsel sowie Fehlermeldungen nach dem Verlassen der Seite.
Sechs zusätzliche direkte Flutter-Renderings zeigen die neuen Einstellungen.
Aktuelle Ergebnisse: `FLUTTER_STATUS.md`.

Die native HEX-/Palettenauswahl ersetzt weiterhin den systemabhängigen
HTML-Farbwähler. Die bestehende Flutter-Bildauswahl akzeptiert Dateien bis 5 MB
und speichert eine begrenzte PNG-Fassung; der HTML-Prototyp hat andere
Eingangs-/Komprimierungsgrenzen. Schriftmetriken, native Dateidialoge und sämtliche
Pixelabstände sind noch nicht als identisch abgenommen. Browser- oder Gerätetests
wurden in diesem Schritt nicht durchgeführt.
