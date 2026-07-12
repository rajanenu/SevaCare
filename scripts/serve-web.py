#!/usr/bin/env python3
"""Serve the Flutter web build with revalidation forced.

Plain `python -m http.server` sends no Cache-Control, so browsers
heuristically cache main.dart.js and a rebuilt bundle stays invisible
(same trap as prod — see CLAUDE.md "stale client"). `no-cache` still
allows conditional requests: an unchanged bundle costs a 304, a rebuilt
one is re-downloaded. Usage:

    python3 scripts/serve-web.py [port]   # default 8087, serves sevacare-flutter/build/web
"""
import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8087
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "sevacare-flutter", "build", "web")


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, *args):
        pass  # keep the terminal quiet


os.chdir(ROOT)
http.server.ThreadingHTTPServer(("0.0.0.0", PORT), NoCacheHandler).serve_forever()
