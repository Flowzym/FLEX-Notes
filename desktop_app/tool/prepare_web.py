#!/usr/bin/env python3
"""Prepare the same verified SQLite engine and schema as FLEX Android."""
from pathlib import Path
import importlib.util
import shutil
import subprocess
ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT.parent / 'flutter_app'
spec = importlib.util.spec_from_file_location('flex_prepare', MOBILE / 'tool/prepare.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)
prepare.web_asset()
shutil.copy2(MOBILE / 'web/sqlite3.wasm', ROOT / 'web/sqlite3.wasm')
assert (ROOT / 'assets/schema.sql').read_bytes() == (MOBILE / 'assets/schema.sql').read_bytes(), 'Desktop schema must match the shared repository'
subprocess.run(['dart', 'compile', 'js', '-O2', 'tool/drift_worker.dart', '-o', 'web/drift_worker.js'], cwd=ROOT, check=True)
