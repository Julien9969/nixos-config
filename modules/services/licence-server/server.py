#!/usr/bin/env python3
"""
Self-hosted license server.

Run the server:      server.py serve
Admin (CLI only):    server.py init | create | list | revoke | unrevoke | reset-machines

Design:
  - Licenses live in SQLite (only a SHA-256 hash of each key is stored).
  - /v1/verify checks the license and returns a token signed with Ed25519.
  - The client embeds the PUBLIC key only, so it can verify tokens offline
    but cannot forge them.
  - Each token carries `grace_until`: how long the client may run without
    reaching the server. A revoked license is refused on the next online check.
"""
import argparse
import base64
import hashlib
import json
import os
import secrets
import sqlite3
import sys
import time
from collections import defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

# ----------------------------------------------------------------- config
DATA_DIR = os.environ.get("LICENSE_DATA_DIR", "/var/lib/licserver")
DB_PATH = os.path.join(DATA_DIR, "licenses.db")
KEY_PATH = os.path.join(DATA_DIR, "ed25519_private.pem")
HOST = os.environ.get("LICENSE_HOST", "127.0.0.1")
PORT = int(os.environ.get("LICENSE_PORT", "8787"))
# How long a client may stay offline after its last successful check.
# 0 = unlimited (never block when offline; revocation only applies when online).
GRACE_DAYS = int(os.environ.get("LICENSE_GRACE_DAYS", "0"))
# Grace used when the client HAS internet but cannot reach this server.
# 0 = unlimited (default): if the service is shut down, nobody loses access.
UNREACHABLE_GRACE_HOURS = int(os.environ.get("LICENSE_UNREACHABLE_GRACE_HOURS", "0"))
# Set to 1 when running behind a reverse proxy that sets X-Forwarded-For.
TRUST_PROXY = os.environ.get("LICENSE_TRUST_PROXY", "0") == "1"
RATE_LIMIT_PER_MIN = int(os.environ.get("LICENSE_RATE_LIMIT", "30"))
MAX_BODY = 4096
KEY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no ambiguous chars


# ----------------------------------------------------------------- helpers
def b64e(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def normalize_key(key: str) -> str:
    return key.strip().upper().replace(" ", "")


def hash_key(key: str) -> str:
    return hashlib.sha256(normalize_key(key).encode()).hexdigest()


def db() -> sqlite3.Connection:
    os.makedirs(DATA_DIR, exist_ok=True)
    con = sqlite3.connect(DB_PATH, timeout=10)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA foreign_keys=ON")
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS licenses (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            key_hash     TEXT UNIQUE NOT NULL,
            product      TEXT NOT NULL,
            owner        TEXT NOT NULL DEFAULT '',
            max_machines INTEGER NOT NULL DEFAULT 1,
            expires_at   INTEGER,              -- unix seconds, NULL = never
            revoked      INTEGER NOT NULL DEFAULT 0,
            created_at   INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS activations (
            license_id INTEGER NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,
            machine_id TEXT NOT NULL,
            first_seen INTEGER NOT NULL,
            last_seen  INTEGER NOT NULL,
            PRIMARY KEY (license_id, machine_id)
        );
        """
    )
    return con


def load_private_key() -> Ed25519PrivateKey:
    with open(KEY_PATH, "rb") as f:
        return serialization.load_pem_private_key(f.read(), password=None)


def public_key_b64(priv: Ed25519PrivateKey) -> str:
    raw = priv.public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw
    )
    return base64.b64encode(raw).decode()


def sign_token(priv: Ed25519PrivateKey, payload: dict) -> str:
    body = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return b64e(body) + "." + b64e(priv.sign(body))


# ----------------------------------------------------------------- verify logic
def verify_license(key: str, machine_id: str, product: str):
    """Returns (http_status, response_dict)."""
    now = int(time.time())

    def deny(reason):
        # Signed, so a fake server (e.g. someone who took over a lapsed domain)
        # cannot revoke users by answering "no".
        proof = sign_token(PRIV, {"denied": reason, "machine_id": machine_id,
                                  "product": product, "issued_at": now})
        return 403, {"ok": False, "reason": reason, "proof": proof}

    con = db()
    try:
        row = con.execute(
            "SELECT * FROM licenses WHERE key_hash=?", (hash_key(key),)
        ).fetchone()
        if row is None or row["product"] != product:
            return deny("invalid_license")
        if row["revoked"]:
            return deny("revoked")
        if row["expires_at"] is not None and row["expires_at"] < now:
            return deny("expired")

        act = con.execute(
            "SELECT 1 FROM activations WHERE license_id=? AND machine_id=?",
            (row["id"], machine_id),
        ).fetchone()
        if act is None:
            count = con.execute(
                "SELECT COUNT(*) FROM activations WHERE license_id=?", (row["id"],)
            ).fetchone()[0]
            if count >= row["max_machines"]:
                return deny("too_many_machines")
            con.execute(
                "INSERT INTO activations VALUES (?,?,?,?)",
                (row["id"], machine_id, now, now),
            )
        else:
            con.execute(
                "UPDATE activations SET last_seen=? WHERE license_id=? AND machine_id=?",
                (now, row["id"], machine_id),
            )
        con.commit()

        payload = {
            "license_id": row["id"],
            "product": product,
            "machine_id": machine_id,
            "issued_at": now,
            "expires_at": row["expires_at"],
            # no internet at all: long grace
            "grace_until": (now + GRACE_DAYS * 86400) if GRACE_DAYS > 0 else None,
            # internet works but this server is unreachable: short grace
            "unreachable_grace_until": (
                now + UNREACHABLE_GRACE_HOURS * 3600) if UNREACHABLE_GRACE_HOURS > 0 else None,
        }
        return 200, {"ok": True, "token": sign_token(PRIV, payload)}
    finally:
        con.close()


# ----------------------------------------------------------------- HTTP
_hits = defaultdict(deque)


def rate_limited(ip: str) -> bool:
    now = time.time()
    q = _hits[ip]
    while q and q[0] < now - 60:
        q.popleft()
    if len(q) >= RATE_LIMIT_PER_MIN:
        return True
    q.append(now)
    return False


class Handler(BaseHTTPRequestHandler):
    server_version = "licserver"
    sys_version = ""

    def _client_ip(self):
        if TRUST_PROXY:
            fwd = self.headers.get("X-Forwarded-For")
            if fwd:
                return fwd.split(",")[0].strip()
        return self.client_address[0]

    def _send(self, status, obj):
        data = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"ok": True})
        else:
            self._send(404, {"ok": False, "reason": "not_found"})

    def do_POST(self):
        if self.path != "/v1/verify":
            return self._send(404, {"ok": False, "reason": "not_found"})
        if rate_limited(self._client_ip()):
            return self._send(429, {"ok": False, "reason": "rate_limited"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > MAX_BODY:
                raise ValueError
            body = json.loads(self.rfile.read(length))
            key = str(body["key"])
            machine_id = str(body["machine_id"])
            product = str(body["product"])
            if not (0 < len(machine_id) <= 128 and 0 < len(product) <= 64):
                raise ValueError
        except Exception:
            return self._send(400, {"ok": False, "reason": "bad_request"})
        try:
            status, resp = verify_license(key, machine_id, product)
        except Exception as e:  # never leak internals
            sys.stderr.write(f"verify error: {e!r}\n")
            return self._send(500, {"ok": False, "reason": "server_error"})
        self._send(status, resp)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self._client_ip(), fmt % args))


# ----------------------------------------------------------------- admin CLI
def cmd_init(_):
    os.makedirs(DATA_DIR, exist_ok=True)
    if os.path.exists(KEY_PATH):
        print("Private key already exists, not overwriting.", file=sys.stderr)
    else:
        priv = Ed25519PrivateKey.generate()
        pem = priv.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
        fd = os.open(KEY_PATH, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as f:
            f.write(pem)
        print(f"Private key written to {KEY_PATH}")
    db().close()
    print("Put this PUBLIC key in your client (PUBLIC_KEY_B64):")
    print(public_key_b64(load_private_key()))


def cmd_create(a):
    key = "-".join(
        "".join(secrets.choice(KEY_ALPHABET) for _ in range(4)) for _ in range(4)
    )
    expires = int(time.time() + a.days * 86400) if a.days else None
    con = db()
    cur = con.execute(
        "INSERT INTO licenses (key_hash, product, owner, max_machines, expires_at, created_at)"
        " VALUES (?,?,?,?,?,?)",
        (hash_key(key), a.product, a.owner, a.max_machines, expires, int(time.time())),
    )
    con.commit()
    print(f"License id : {cur.lastrowid}")
    print(f"License key: {key}   (shown only once, give it to the user)")


def fmt_ts(ts):
    return time.strftime("%Y-%m-%d", time.localtime(ts)) if ts else "never"


def cmd_list(_):
    con = db()
    rows = con.execute(
        "SELECT l.*, (SELECT COUNT(*) FROM activations a WHERE a.license_id=l.id) AS n,"
        " (SELECT MAX(last_seen) FROM activations a WHERE a.license_id=l.id) AS seen"
        " FROM licenses l ORDER BY l.id"
    ).fetchall()
    print(f"{'ID':>3}  {'PRODUCT':<14}{'OWNER':<18}{'MACH':<6}{'EXPIRES':<12}{'STATUS':<8}LAST SEEN")
    for r in rows:
        print(
            f"{r['id']:>3}  {r['product']:<14}{r['owner']:<18}"
            f"{r['n']}/{r['max_machines']:<4}{fmt_ts(r['expires_at']):<12}"
            f"{'REVOKED' if r['revoked'] else 'active':<8}{fmt_ts(r['seen'])}"
        )


def _set_revoked(a, value):
    con = db()
    cur = con.execute("UPDATE licenses SET revoked=? WHERE id=?", (value, a.id))
    con.commit()
    print("ok" if cur.rowcount else "no such license id")


def cmd_reset(a):
    con = db()
    cur = con.execute("DELETE FROM activations WHERE license_id=?", (a.id,))
    con.commit()
    print(f"removed {cur.rowcount} machine activation(s)")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("serve").set_defaults(fn=None)
    sub.add_parser("init").set_defaults(fn=cmd_init)
    c = sub.add_parser("create")
    c.add_argument("--product", required=True)
    c.add_argument("--owner", default="")
    c.add_argument("--max-machines", type=int, default=1)
    c.add_argument("--days", type=int, default=0, help="validity in days (0 = never expires)")
    c.set_defaults(fn=cmd_create)
    sub.add_parser("list").set_defaults(fn=cmd_list)
    r = sub.add_parser("revoke"); r.add_argument("id", type=int)
    r.set_defaults(fn=lambda a: _set_revoked(a, 1))
    u = sub.add_parser("unrevoke"); u.add_argument("id", type=int)
    u.set_defaults(fn=lambda a: _set_revoked(a, 0))
    rm = sub.add_parser("reset-machines"); rm.add_argument("id", type=int)
    rm.set_defaults(fn=cmd_reset)

    a = p.parse_args()
    if a.fn is not None:
        return a.fn(a)

    global PRIV
    PRIV = load_private_key()
    db().close()
    print(f"licserver listening on {HOST}:{PORT} (offline grace {GRACE_DAYS}d, "
          f"server-unreachable grace {UNREACHABLE_GRACE_HOURS}h)", flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
