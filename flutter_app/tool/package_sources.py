#!/usr/bin/env python3
"""Export committed sources reproducibly; exclude local caches and build output."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])

def package(output, flutter_only):
    commit = git('rev-parse', 'HEAD').decode().strip()
    name = ('FLEX-Flutter' if flutter_only else 'FLEX-Notes') + f'-Quellen-{commit[:12]}.zip'
    path = output / name
    tracked = git('ls-tree', '-r', '--name-only', '-z', 'HEAD').decode().split('\0')
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for item in tracked:
            if not item or flutter_only and not item.startswith('flutter_app/'):
                continue
            destination = item.removeprefix('flutter_app/') if flutter_only else item
            info = zipfile.ZipInfo(('FLEX-Flutter/' if flutter_only else 'FLEX-Notes/') + destination)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, git('show', f'HEAD:{item}'))
        archive.writestr('SOURCE-COMMIT.txt', commit + '\n')
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise RuntimeError('ZIP verification failed')
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    Path(str(path) + '.sha256').write_text(f'{digest}  {path.name}\n')
    print(f'{path} ({path.stat().st_size} bytes) SHA256 {digest}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    package(args.output, False)
    package(args.output, True)
