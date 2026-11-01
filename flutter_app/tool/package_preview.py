#!/usr/bin/env python3
"""Package the existing Flutter web build with standalone Windows launchers.

Requires Go only when creating this package, not on the recipient's computer.
Does not open a browser, execute Windows programs or publish a cloud service.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tool' / 'preview_server.go'

START_CMD = '''@echo off
setlocal
cd /d "%~dp0"
set "FLEX_PREVIEW_EXE=%~dp0bin\\flex-preview-windows-amd64.exe"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "FLEX_PREVIEW_EXE=%~dp0bin\\flex-preview-windows-arm64.exe"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "FLEX_PREVIEW_EXE=%~dp0bin\\flex-preview-windows-arm64.exe"
if not exist "%FLEX_PREVIEW_EXE%" (
  echo Vorschau-Server fehlt. Bitte das gesamte ZIP entpacken.
  pause
  exit /b 1
)
"%FLEX_PREVIEW_EXE%"
if errorlevel 1 pause
'''

README = '''FLEX - lokale Flutter-Webvorschau {version}

1. Das gesamte ZIP auf deinem Windows-PC in einen neuen Ordner entpacken.
2. Webvorschau-starten.cmd im entpackten Ordner doppelklicken.
3. Der Starter oeffnet den Standardbrowser. Das Serverfenster offen lassen.
   Falls kein Browser aufgeht: http://127.0.0.1:8081/ selbst oeffnen.
4. Beenden: Serverfenster schliessen oder Strg+C druecken.

Flutter, Python und Go sind fuer diesen Start nicht erforderlich.
Unterstuetzt werden Windows x64 und ARM64. Die kleinen Server-EXEs sind
keine nativen Flutter-Apps. Sie liefern nur den mitgelieferten Web-Build aus.
Der Server hoert ausschliesslich auf diesem Computer (127.0.0.1).
Ist Port 8081 belegt, zeigt das Fenster den Fehler. Ein laufender anderer
Server wird nicht automatisch beendet.

Wichtig: Nicht index.html direkt aus dem ZIP oder per Doppelklick oeffnen.
Browserdaten sind an das Browserprofil und die Adresse gebunden. Fuer
dauerhafte Daten die Sicherungsfunktion der App verwenden. Die App beginnt
leer; die Tests verwendeten synthetische Daten. Neuere Originalquellen
fehlen; diese Version ist ein rekonstruierter Zwischenstand.

Geprueft: Flutter-Web-Build, lokaler Linux-Lauf desselben Serverquelltexts,
HTTP-Inhalte/Header, Windows-Kompilierung und Paketpruefsummen.
Nicht geprueft: Ausfuehrung der EXEs unter Windows, Browseroberflaeche und
Browserpersistenz. Die EXEs sind nicht signiert. Keine Cloud-Veroeffentlichung.

Quellenstand: {commit}
Vollstaendige Quellen: separat geliefertes FLEX-Flutter-Quellen-ZIP zu diesem Quellenstand.
Serverquelltext und Bauanleitung: source/
Pruefstand der App: RESTORATION-STATUS.md
Dateipruefsummen: SHA256SUMS
'''


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def package(output, go):
    web = ROOT / 'build' / 'web'
    for name in ['index.html', 'version.json', 'main.dart.js', 'drift_worker.js', 'sqlite3.wasm']:
        if not (web / name).is_file():
            raise RuntimeError(f'{name} missing; run prepare.py and flutter build web --no-web-resources-cdn first')
    info = json.loads((web / 'version.json').read_text())
    version = info['version'] + '+' + info['build_number']
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True))
    go_version = subprocess.check_output([go, 'version'], text=True).strip()
    output.mkdir(parents=True, exist_ok=True)
    target = output / f'FLEX-Webvorschau-{version}-Windows-{commit[:12]}.zip'
    with tempfile.TemporaryDirectory(prefix='flex-local-preview-') as tmp:
        stage = Path(tmp) / 'FLEX-Webvorschau'
        shutil.copytree(web, stage / 'web')
        (stage / 'bin').mkdir()
        (stage / 'source').mkdir()
        shutil.copy2(SOURCE, stage / 'source' / SOURCE.name)
        shutil.copy2(__file__, stage / 'source' / 'package_preview.py')
        (stage / 'source' / 'BUILD.txt').write_text(
            'Server nachbauen: Go installieren; im source-Ordner ausfuehren:\n'
            'go build -trimpath -buildvcs=false -o ../bin/flex-preview-windows-amd64.exe preview_server.go\n'
            'Dazu GOOS=windows und GOARCH=amd64 setzen; fuer ARM64 GOARCH=arm64.\n'
            'Das Paketbau-Skript wird im vollstaendigen Repository unter flutter_app/tool verwendet.\n'
            f'Verwendete Werkzeugversion: {go_version}\n', encoding='utf-8')
        for arch in ['amd64', 'arm64']:
            environment = {**os.environ, 'GOOS': 'windows', 'GOARCH': arch, 'CGO_ENABLED': '0', 'GOTELEMETRY': 'off'}
            subprocess.run([go, 'build', '-trimpath', '-buildvcs=false', '-ldflags=-s -w',
                            '-o', str(stage / 'bin' / f'flex-preview-windows-{arch}.exe'), str(SOURCE)],
                           cwd=ROOT, env=environment, check=True)
        (stage / 'Webvorschau-starten.cmd').write_bytes(START_CMD.replace('\n', '\r\n').encode('ascii'))
        (stage / 'START.txt').write_text(README.format(version=version, commit=commit), encoding='utf-8')
        shutil.copy2(ROOT.parent / 'docs' / 'rebuild' / 'STATUS.md', stage / 'RESTORATION-STATUS.md')
        (stage / 'BUILD.json').write_text(json.dumps({
            'version': version, 'source_commit': commit, 'working_tree_dirty': dirty,
            'go_version': go_version, 'launcher_source_sha256': digest(SOURCE),
            'app_js_sha256': digest(web / 'main.dart.js'),
            'windows_execution_tested': False, 'browser_tests': False,
        }, indent=2) + '\n', encoding='utf-8')
        entries = sorted(p for p in stage.rglob('*') if p.is_file())
        (stage / 'SHA256SUMS').write_text(''.join(
            f'{digest(p)}  {p.relative_to(stage).as_posix()}\n' for p in entries), encoding='utf-8')
        with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for path in sorted(stage.rglob('*')):
                if path.is_file():
                    record = zipfile.ZipInfo(path.relative_to(stage.parent).as_posix())
                    record.compress_type = zipfile.ZIP_DEFLATED
                    record.external_attr = 0o100644 << 16
                    archive.writestr(record, path.read_bytes())
        with zipfile.ZipFile(target) as archive:
            assert archive.testzip() is None
            for p in stage.rglob('*'):
                if p.is_file():
                    assert archive.read(p.relative_to(stage.parent).as_posix()) == p.read_bytes()
    Path(str(target) + '.sha256').write_text(f'{digest(target)}  {target.name}\n', encoding='utf-8')
    print(f'{target} ({target.stat().st_size} bytes); SHA256 {digest(target)}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--go', default='go', help='Path to the Go compiler')
    args = parser.parse_args()
    package(args.output, args.go)
