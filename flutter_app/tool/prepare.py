#!/usr/bin/env python3
"""Generate official Flutter runners without replacing application sources.
Requires Flutter/Dart in PATH. Downloads only the pinned SQLite WASM artifact.
"""
import argparse
import hashlib
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
WASM_URL = 'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.8.0/sqlite3.wasm'
# From the SHA-256 verified pub.dev sqlite3 3.8.0 package, lib/src/hook/asset_hashes.dart.
WASM_SHA256 = 'efd308be92a34f3aa15f289a37f213b0230fd80888a1364326ee29579d892d37'

def run(args, cwd=ROOT):
    subprocess.run([str(x) for x in args], cwd=cwd, check=True)

def web_asset():
    target = ROOT/'web/sqlite3.wasm'
    if target.exists():
        if hashlib.sha256(target.read_bytes()).hexdigest() == WASM_SHA256: return
        raise RuntimeError('Existing sqlite3.wasm differs; preserve it and inspect before replacing.')
    target.parent.mkdir(exist_ok=True)
    curl = shutil.which('curl')
    if not curl: raise RuntimeError('curl is required to download the verified WASM asset.')
    with tempfile.TemporaryDirectory(prefix='flex-web-') as tmp:
        artifact = pathlib.Path(tmp)/'sqlite3.wasm'
        run([curl, '--fail', '--location', '--silent', '--show-error', '--max-time', '120', WASM_URL, '--output', artifact])
        if hashlib.sha256(artifact.read_bytes()).hexdigest() != WASM_SHA256: raise RuntimeError('SQLite WASM checksum mismatch.')
        shutil.copy2(artifact, target)
    print('Verified SQLite WASM asset ready.')

def prepare():
    flutter, dart = shutil.which('flutter'), shutil.which('dart')
    if not flutter or not dart: raise RuntimeError('Flutter and Dart are required in PATH. No application sources were changed.')
    # Generate in a temporary directory. Copy only missing native runner files.
    with tempfile.TemporaryDirectory(prefix='flex-runners-') as tmp:
        generated = pathlib.Path(tmp)/'flex_notizbuch'
        run([flutter, 'create', '--no-pub', '--project-name', 'flex_notizbuch', '--org', 'at.flowzym', '--platforms=windows,android,web', '--empty', generated])
        for name in ['windows','android','.metadata']:
            src = generated/name
            if src.is_file():
                if not (ROOT/name).exists(): shutil.copy2(src, ROOT/name)
                continue
            for path in src.rglob('*'):
                dest = ROOT/name/path.relative_to(src)
                if path.is_dir(): dest.mkdir(parents=True, exist_ok=True)
                elif not dest.exists():
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, dest)
    run([flutter, 'pub', 'get'])
    web_asset()
    run([dart, '--suppress-analytics', 'compile', 'js', '-O2', 'tool/drift_worker.dart', '-o', 'web/drift_worker.js'])
    print('Next: flutter analyze; flutter test; flutter build web --no-web-resources-cdn')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets-only', action='store_true', help='Download and verify SQLite WASM without Flutter.')
    args = parser.parse_args()
    try: web_asset() if args.assets_only else prepare()
    except (RuntimeError, subprocess.CalledProcessError) as e:
        print(f'Preparation stopped: {e}', file=sys.stderr); sys.exit(1)
