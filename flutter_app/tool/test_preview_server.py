"""Test the native preview server over loopback HTTP, without a browser.

Requires an existing build/web and a Go compiler (GO_BINARY overrides its path).
"""
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import unittest
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


class PreviewServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='flex preview test ')
        cls.addClassCleanup(cls.temp.cleanup)
        cls.directory = Path(cls.temp.name)
        cls.binary = cls.directory / 'bin' / 'server.exe'
        cls.binary.parent.mkdir()
        shutil.copytree(ROOT / 'build' / 'web', cls.directory / 'web')
        subprocess.run([os.environ.get('GO_BINARY', 'go'), 'build', '-trimpath',
                        '-buildvcs=false', '-o', str(cls.binary),
                        str(ROOT / 'tool' / 'preview_server.go')], check=True)
        with socket.socket() as free:
            free.bind(('127.0.0.1', 0))
            cls.port = free.getsockname()[1]
        cls.client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        cls.server = subprocess.Popen([str(cls.binary), '-open-browser=false', '-port', str(cls.port)],
                                      cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        cls.addClassCleanup(cls.stop)
        for _ in range(50):
            try:
                with cls.client.open(cls.url('version.json'), timeout=.5) as response:
                    if response.status == 200:
                        return
            except OSError:
                if cls.server.poll() is not None:
                    raise RuntimeError(cls.server.communicate()[0])
                time.sleep(.1)
        raise RuntimeError('Preview server did not start')

    @classmethod
    def stop(cls):
        cls.server.terminate()
        cls.server.communicate(timeout=10)

    @classmethod
    def url(cls, path):
        return f'http://127.0.0.1:{cls.port}/{path}'

    def test_executable_relative_root_and_required_resources(self):
        # The executable's folder includes spaces; cwd is deliberately elsewhere.
        paths = ['index.html', 'version.json', 'flutter_bootstrap.js', 'main.dart.js',
                 'drift_worker.js', 'sqlite3.wasm', 'canvaskit/canvaskit.js',
                 'canvaskit/canvaskit.wasm', 'assets/assets/schema.sql',
                 'assets/assets/fonts/Selawik-Regular.ttf']
        for path in paths:
            with self.subTest(path=path), self.client.open(self.url(path), timeout=5) as response:
                self.assertEqual(response.status, 200)
                self.assertEqual(response.read(), (self.directory / 'web' / path).read_bytes())
                self.assertEqual(response.headers['Cross-Origin-Opener-Policy'], 'same-origin')
                self.assertEqual(response.headers['Cross-Origin-Embedder-Policy'], 'require-corp')
                if path.endswith('.wasm'):
                    self.assertEqual(response.headers.get_content_type(), 'application/wasm')

    def test_port_conflict_preserves_existing_server(self):
        result = subprocess.run([str(self.binary), '-open-browser=false', '-port', str(self.port)],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertIn('konnte nicht starten', result.stderr)
        with self.client.open(self.url('version.json'), timeout=5) as response:
            self.assertEqual(response.status, 200)

    def test_incomplete_export_reports_error(self):
        result = subprocess.run([str(self.binary), '-open-browser=false', '-root', str(self.directory / 'bin')],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertIn('index.html fehlt', result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
