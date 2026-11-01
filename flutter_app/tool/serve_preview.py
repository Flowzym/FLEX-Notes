#!/usr/bin/env python3
"""Serve a locally built Flutter app; does not open a browser or deploy it."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'build' / 'web'

class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map,
                      '.wasm': 'application/wasm', '.js': 'application/javascript'}

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8081)
    parser.add_argument('--bind', default='127.0.0.1')
    args = parser.parse_args()
    if not (ROOT / 'index.html').is_file():
        parser.error('First run: flutter build web --no-web-resources-cdn')
    with ThreadingHTTPServer((args.bind, args.port), partial(Handler, directory=str(ROOT))) as server:
        print(f'FLEX rebuild preview: {args.bind}:{args.port}; {ROOT}', flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
