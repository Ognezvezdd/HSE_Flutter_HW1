"""Test-only API for Android acceptance; never used by the normal application.

Example: python tool/acceptance/api_server.py --state /tmp/cats-state.json
The state file controls public_url, breeds_mode, cats_mode, photos_mode, delay.
Expose ONLY this fixture server through an HTTPS tunnel. No real key is needed.
"""

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
import time
from urllib.parse import urlsplit

KEY = "acceptance-test-key"
BREEDS = [
    {"id": "accept-a", "name": "Acceptance Shorthair", "origin": "Test origin",
     "description": "Synthetic data used only for acceptance checks.",
     "temperament": "Active, Friendly", "life_span": "12 - 15",
     "breed_group": "Short-haired", "intelligence": 4},
    {"id": "accept-b", "name": "Acceptance Longhair", "origin": "Test origin",
     "description": "Second synthetic breed for catalog navigation checks.",
     "temperament": "Calm, Curious", "life_span": "10 - 14",
     "breed_group": "Long-haired"},
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--port", type=int, default=8877)
    args = parser.parse_args()
    image = (Path(__file__).resolve().parents[2] / "assets/branding/app_icon.png").read_bytes()
    lock = threading.Lock()
    counter = 0

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            nonlocal counter
            state = json.loads(args.state.read_text())
            path = urlsplit(self.path).path
            category = (
                "breeds" if path == "/acceptance/v1/breeds" else
                "cats" if path == "/acceptance/v1/images/search" else
                "photos" if path.startswith("/photos/") else "unknown"
            )
            valid_key = self.headers.get("x-api-key") == KEY
            mode = state.get(category + "_mode", "normal")
            with lock:
                if category == "cats":
                    counter += 1
                number = counter
                with args.log.open("a") as output:
                    output.write(json.dumps({"time": time.time(), "path": self.path,
                                             "category": category, "mode": mode,
                                             "valid_test_key": valid_key}) + "\n")
            status, content_type = 200, "application/json"
            if category == "unknown":
                status, body = 404, b"Not found"
            elif category in ("breeds", "cats") and not valid_key:
                status, body = 403, b"Test key rejected"
            elif mode.startswith("http"):
                status, body = int(mode[4:]), b"Controlled HTTP error"
            elif mode == "bad-json":
                body = b"{broken"
            elif mode == "wrong-root":
                body = b'{"unexpected": true}'
            elif mode == "empty":
                body = b"[]"
            elif category == "breeds":
                body = json.dumps(BREEDS).encode()
            elif category == "cats":
                body = json.dumps([{
                    "id": f"acceptance-cat-{number}",
                    "url": state["public_url"] + f"/photos/cat-{number}.png",
                    "breeds": [] if mode == "no-breed" else [BREEDS[number % 2]],
                }]).encode()
            else:
                content_type = "image/png"
                body = b"not a PNG" if mode == "bad-image" else image
            if mode == "slow":
                time.sleep(state.get("delay", 16))
            try:
                self.send_response(status)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(len(body)))
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass  # Expected when the application cancels a timed-out request.

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Fixture API listening on 127.0.0.1:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
