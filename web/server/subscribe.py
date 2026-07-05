#!/usr/bin/env python3
"""Tiny zero-dependency subscribe endpoint for krokva.com.

Accepts POST /subscribe {"email": "..."} (JSON or form-encoded), stores the
address in a SQLite DB (deduped), and returns {"ok": true}. Listens only on
127.0.0.1; nginx reverse-proxies /subscribe to it. The DB lives OUTSIDE the
web root so it is never publicly downloadable.
"""
import datetime
import json
import os
import re
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

DB = os.environ.get("KROKVA_SUB_DB", "/var/lib/krokva-subscribe/subscribers.db")
PORT = int(os.environ.get("KROKVA_SUB_PORT", "8891"))
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def init_db():
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    con = sqlite3.connect(DB)
    con.execute(
        """CREATE TABLE IF NOT EXISTS subscribers(
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            email      TEXT UNIQUE NOT NULL,
            city       TEXT,
            beta       INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            ip         TEXT,
            user_agent TEXT,
            invited_at TEXT
        )"""
    )
    # migrate pre-existing DBs that lack newer columns
    cols = [r[1] for r in con.execute("PRAGMA table_info(subscribers)")]
    if "city" not in cols:
        con.execute("ALTER TABLE subscribers ADD COLUMN city TEXT")
    if "beta" not in cols:
        con.execute("ALTER TABLE subscribers ADD COLUMN beta INTEGER NOT NULL DEFAULT 0")
    con.commit()
    con.close()


class Handler(BaseHTTPRequestHandler):
    server_version = "krokva-sub/1.0"

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.rstrip("/") == "/subscribe/health":
            return self._json(200, {"ok": True})
        return self._json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        if self.path.rstrip("/") != "/subscribe":
            return self._json(404, {"ok": False, "error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", 0) or 0)
            if length > 10_000:
                return self._json(413, {"ok": False, "error": "too large"})
            raw = self.rfile.read(length) if length else b""
            ctype = self.headers.get("Content-Type", "")
            if "application/json" in ctype:
                data = json.loads(raw or b"{}")
                email = (data.get("email") or "")
                city = (data.get("city") or "")
                beta = 1 if data.get("beta") in (True, 1, "1", "true", "on") else 0
            else:
                q = parse_qs(raw.decode("utf-8", "ignore"))
                email = q.get("email", [""])[0]
                city = q.get("city", [""])[0]
                beta = 1 if q.get("beta", ["0"])[0] in ("1", "true", "on") else 0
            email = email.strip().lower()
            city = city.strip()[:64]
        except Exception:
            return self._json(400, {"ok": False, "error": "bad request"})

        if not EMAIL_RE.match(email) or len(email) > 254:
            return self._json(400, {"ok": False, "error": "invalid email"})

        ip = self.headers.get("X-Forwarded-For", self.client_address[0]).split(",")[0].strip()
        ua = (self.headers.get("User-Agent", "") or "")[:400]
        try:
            con = sqlite3.connect(DB)
            con.execute(
                "INSERT OR IGNORE INTO subscribers(email, city, beta, created_at, ip, user_agent) VALUES(?,?,?,?,?,?)",
                (email, city, beta, datetime.datetime.now(datetime.timezone.utc).isoformat(), ip, ua),
            )
            con.commit()
            con.close()
        except Exception:
            return self._json(500, {"ok": False, "error": "storage error"})
        return self._json(200, {"ok": True})

    def log_message(self, *args):
        pass  # stay quiet; systemd/nginx already log


if __name__ == "__main__":
    init_db()
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
