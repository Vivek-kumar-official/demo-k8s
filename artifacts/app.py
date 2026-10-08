#!/usr/bin/env python3
import os
import time
import threading
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler

APP_VERSION = os.getenv("APP_VERSION", "v1")
READY_DELAY_SECONDS = int(os.getenv("READY_DELAY_SECONDS", "0"))
NEVER_READY = os.getenv("NEVER_READY", "false").lower() in ("1", "true", "yes")

HOSTNAME = socket.gethostname()
START_TIME = time.time()
READY_TIME = None
READY = False


def set_ready_after_delay():
    global READY, READY_TIME
    if NEVER_READY:
        return
    if READY_DELAY_SECONDS <= 0:
        READY = True
        READY_TIME = time.time()
        return

    def mark_ready():
        global READY, READY_TIME
        READY = True
        READY_TIME = time.time()

    t = threading.Timer(READY_DELAY_SECONDS, mark_ready)
    t.daemon = True
    t.start()


class Handler(BaseHTTPRequestHandler):
    server_version = "demo-service/1.0"

    def _send(self, code, body, content_type="text/plain"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body.encode("utf-8"))))
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def log_message(self, format, *args):
        print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), format % args))

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/health":
            body = "ok"
            self._send(200, body)
            return

        if path == "/ready":
            if READY:
                self._send(200, "ready")
            else:
                self._send(503, "not ready")
            return

        if path == "/version":
            if READY:
                uptime = time.time() - START_TIME
                ready_after = None
                if READY_TIME:
                    ready_after = READY_TIME - START_TIME
                payload = {
                    "version": APP_VERSION,
                    "instance": HOSTNAME,
                    "uptime_seconds": round(uptime, 3),
                    "ready_after_seconds": (round(ready_after, 3) if ready_after is not None else None),
                }
                import json

                self._send(200, json.dumps(payload), "application/json")
            else:
                self._send(503, "not ready")
            return

        self._send(404, "not found")


def run():
    set_ready_after_delay()
    port = int(os.getenv("PORT", "8080"))
    server = HTTPServer(("0.0.0.0", port), Handler)
    print(f"Starting demo service on :{port} with APP_VERSION={APP_VERSION} READY_DELAY={READY_DELAY_SECONDS} NEVER_READY={NEVER_READY}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    run()
