#!/usr/bin/env python3
# Copyright 2026 The Authors (see AUTHORS file)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Stands in for the REST API so check-rate-limit can be tested deterministically.

Scenarios are selected by path prefix, which is what the action's api_url input
already is, so one server covers every case without restarts:

  http://127.0.0.1:PORT/normal       plenty of budget left
  http://127.0.0.1:PORT/low          almost no budget left
  http://127.0.0.1:PORT/disabled     rate limiting off, as GHES reports it
  http://127.0.0.1:PORT/intercepted  200, but not a rate limit payload

Usage: mock_api.py PORT
"""

import http.server
import json
import sys
import time

# core is hourly, search is a one minute window, which is the difference
# callers have to be able to see.
SCENARIOS = {
    "normal": {
        "core": {"limit": 5000, "used": 1000, "remaining": 4000, "window": 3600},
        "search": {"limit": 30, "used": 5, "remaining": 25, "window": 60},
    },
    "low": {
        "core": {"limit": 5000, "used": 4950, "remaining": 50, "window": 3600},
        "search": {"limit": 30, "used": 5, "remaining": 25, "window": 60},
    },
}

DISABLED_BODY = {
    "message": "Rate limiting is not enabled.",
    "documentation_url": "https://docs.github.com/rest/rate-limit",
}


class Handler(http.server.BaseHTTPRequestHandler):
    """Serves GET /{scenario}/rate_limit."""

    def do_GET(self):  # noqa: N802 - name fixed by BaseHTTPRequestHandler
        parts = self.path.strip("/").split("/")
        if len(parts) != 2 or parts[1] != "rate_limit":
            self._respond(404, {"message": f"Not Found: {self.path}"})
            return

        scenario = parts[0]
        if scenario == "disabled":
            self._respond(404, DISABLED_BODY)
            return

        # What an SSO proxy in front of the instance returns: 200, wrong body.
        if scenario == "intercepted":
            self._respond(200, {"message": "sign in to continue"})
            return

        if scenario not in SCENARIOS:
            self._respond(404, {"message": f"Unknown scenario: {scenario}"})
            return

        now = int(time.time())
        resources = {
            name: {k: v for k, v in bucket.items() if k != "window"}
            | {"reset": now + bucket["window"]}
            for name, bucket in SCENARIOS[scenario].items()
        }
        self._respond(200, {"resources": resources, "rate": resources["core"]})

    def log_message(self, fmt, *args):
        sys.stderr.write(f"mock_api: {fmt % args}\n")

    def _respond(self, status, body):
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
