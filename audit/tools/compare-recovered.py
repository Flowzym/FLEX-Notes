#!/usr/bin/env python3
"""Create a reviewable source diff against the user's untouched extracted ZIP."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('baseline', type=Path, help='Extracted FLEX-Notes directory from the uploaded source ZIP')
args = parser.parse_args()

def digest(data):
    return hashlib.sha256(data).hexdigest()

paths = set()
for tree in [ROOT, args.baseline]:
    for folder in ['flutter_app/lib', 'flutter_app/test']:
        paths.update(str(p.relative_to(tree)) for p in (tree / folder).rglob('*.dart'))
paths.update(['flutter_app/pubspec.yaml', 'flutter_app/pubspec.lock', 'flutter_app/README.md',
              'README.md', 'FLUTTER_STATUS.md', 'docs/rebuild/STATUS.md'])
patch, changes = [], []
for name in sorted(paths):
    before_path, after_path = args.baseline / name, ROOT / name
    before = before_path.read_bytes() if before_path.exists() else b''
    after = after_path.read_bytes() if after_path.exists() else b''
    if before == after:
        continue
    changes.append({'path': name, 'beforeSha256': digest(before) if before_path.exists() else None,
                    'afterSha256': digest(after) if after_path.exists() else None,
                    'beforeBytes': len(before), 'afterBytes': len(after)})
    patch.extend(difflib.unified_diff(before.decode().splitlines(keepends=True), after.decode().splitlines(keepends=True),
                                    fromfile='a/' + name if before_path.exists() else '/dev/null',
                                    tofile='b/' + name if after_path.exists() else '/dev/null'))
(ROOT / 'audit/evidence/changes-from-recovered-source.patch').write_text(''.join(patch))
(ROOT / 'audit/evidence/recovered-diff.json').write_text(json.dumps(changes, ensure_ascii=False, indent=2) + '\n')
print(f'{len(changes)} changed/new source and current documentation files; patch generated against supplied ZIP.')
