"""Export source-inspection evidence, not UI/rendering test results."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
data = json.loads((root / 'evidence/dom-inventory.json').read_text())

def cell(value):
    if isinstance(value, (dict, list)):
        value = json.dumps(value, ensure_ascii=False)
    return str(value).replace('|', '\\|').replace('\n', '<br>').replace('\r', '').replace('<', '&lt;').replace('>', '&gt;').replace('&lt;br&gt;', '<br>')

lines = ['# HTML-Elemente: vollständige Aufnahme der erfassten Zustände', '',
         'Erzeugt aus `evidence/dom-inventory.json`. ' + data['method'] + '.', '',
         'Die Reihenfolge ist DOM-Reihenfolge nach den letzten JavaScript-Erweiterungen. '
         'CSS-Grid/Flex kann die optische Reihenfolge ändern. „Verborgen“ berücksichtigt HTML-Attribute, '
         'die Klasse hidden und ausdrücklich im Inspektor aufgeführte CSS-Regeln; dies ist keine vollständige '
         'CSS-Kaskade. Bedingt nicht erzeugte Inhalte werden in anderen Zuständen bzw. im manuellen '
         '[Dialogverzeichnis](DIALOGVERZEICHNIS.md) erfasst. Synthetische Namen und Werte sind keine Original-Nutzerdaten.', '',
         f'{len(data["inventory"])} dauerhaft erzeugte benannte Dialoge, ein dynamischer Passwortdialog, '
         f'{len(data["states"])} aufgenommene Quellenzustände.', '', '## Originalkataloge', '']
for key, value in data['catalogs'].items():
    lines += [f'### {key}', '', '```json', json.dumps(value, ensure_ascii=False, indent=2), '```', '']
for name, state in data['states'].items():
    lines += [f'## {name}', '', f'Dialog/Container: `{state["id"]}`. Klassen: `{state["classes"]}`.', '',
              '| Nr. | Element / ID | Originaltext / zugänglicher Name | Wert / Platzhalter / Auswahl | Zustand |',
              '| --- | --- | --- | --- | --- |']
    for el in state['elements']:
        name_parts = [el.get('text', '')]
        if el.get('aria'): name_parts.append('aria-label: ' + el['aria'])
        if el.get('title'): name_parts.append('Tooltip: ' + el['title'])
        values = []
        if 'value' in el: values.append('Wert: ' + el['value'])
        if el.get('placeholder'): values.append('Platzhalter: ' + el['placeholder'])
        if el.get('options'): values.append('Optionen: ' + json.dumps(el['options'], ensure_ascii=False))
        flags = []
        if el['hidden']: flags.append('verborgen')
        if el['collapsed']: flags.append('eingeklappt')
        for k in ['type','checked','disabled','required','maxlength','pressed','expanded']:
            if k in el: flags.append(f'{k}={el[k]}')
        lines.append('| ' + ' | '.join(cell(v) for v in [el['order'], el['kind'] + (' #' + el['id'] if el.get('id') else ''), '\n'.join(p for p in name_parts if p), '\n'.join(values), ', '.join(flags) or 'normal']) + ' |')
    lines.append('')
lines += ['## Laufdiagnostik', '', '```json', json.dumps(data['errors'], ensure_ascii=False, indent=2), '```', '',
          'Eine leere Diagnostikliste bestätigt nur, dass dieser Inspektionslauf keine jsdom-Ausnahme meldete. '
          'Sie ist kein Nachweis für Layout, vollständige Fachkorrektheit, Flutter oder reale Plattformbedienung.', '']
(root / 'DOM_ELEMENTE.md').write_text('\n'.join(lines))

source = (root / 'reference/FLEX-Notizbuch-37.html').read_text()
lines = ['# Originalmeldungen: statische Fundstellen', '',
         'Alle Fundstellen der unten erkannten Meldungsaufrufe, mit Original-Zeilennummer. '
         'Enthält bewusst auch frühere, später überschriebene Funktionen. Gültigkeit und Zustandsbindung '
         'stehen im manuellen Dialogverzeichnis; diese Liste allein beschreibt nicht die letzte UI-Fassung.', '',
         '| HTML-Zeile | Aufruf | Originalargument / Meldung |', '| --- | --- | --- |']
pattern = re.compile(r'''\b(toast|warn|editorError|bulkError|Error)\(((?:'[^'\\]*(?:\\.[^'\\]*)*'|"[^"\\]*(?:\\.[^"\\]*)*"|`[^`]*`))''')
for match in pattern.finditer(source):
    lines.append('| ' + ' | '.join(cell(v) for v in [source.count('\n', 0, match.start()) + 1, match[1], match[2]]) + ' |')
(root / 'ORIGINALMELDUNGEN.md').write_text('\n'.join(lines) + '\n')
assert len(data['inventory']) == 21
assert len({r['id'] for r in data['inventory']}) == 21
assert not data['errors'], data['errors']
assert {'Sicherung öffnen', 'Sicherung verschlüsseln'}.issubset(data['states'])
print(f'Exported {len(data["states"])} source states; 21 unique named dialog elements; both password modes.')
