# Self-hosted license server

Small Python license system: one server (stdlib HTTP + SQLite), one client file.
Online checks enforce revocation; offline use keeps working for a grace period.

## How it works

```
client ── POST /v1/verify {key, machine_id, product} ──▶ server
client ◀── signed token (Ed25519): machine_id, expires_at, grace_until ── server
```

- **Server online, license valid** → client gets a signed token and caches it.
- **Server online, license revoked/expired** → client deletes its cache, access denied.
- **No network** → client verifies the cached token locally (signature, machine, expiry, `grace_until`). No block until the grace period ends.
- The client only holds the **public** key: it can verify tokens but never forge them.
- Keys are stored as SHA-256 hashes on the server. Each license has a machine limit.

**Revocation timing:** a revoked user loses access the next time their software reaches the
server. When the server can't be reached, the client picks a grace period by checking whether
the machine has internet at all (TCP probe to 1.1.1.1 / 8.8.8.8 / 9.9.9.9):

| Situation | Grace (from last good check) | Setting |
|---|---|---|
| No internet at all | unlimited (default) | `LICENSE_GRACE_DAYS` (`0` = unlimited) |
| Internet works, license server doesn't answer | unlimited (default) | `LICENSE_UNREACHABLE_GRACE_HOURS` (`0` = unlimited) |

**Defaults are "never punish an unreachable server":** if you shut the service down, every
already-activated install keeps working forever. Only an explicit, *signed* denial from the
server (revoked / expired / invalid) removes access. Unsigned answers (fake server, captive
portal, a lapsed domain taken over by someone else) are ignored and treated as "unreachable".
If you ever want stricter behavior, set the two values above to a number of days/hours; a user
who blocks your server then loses access after that long.

Consequences of the defaults: revocation only reaches users who go online while the server is
up, and users who never activated before the shutdown can't activate afterwards.

## Install (server, Debian/Ubuntu example)

```bash
sudo useradd --system --home /var/lib/licserver --shell /usr/sbin/nologin licserver
sudo mkdir -p /opt/licserver && sudo cp server.py /opt/licserver/
sudo python3 -m venv /opt/licserver/venv
sudo /opt/licserver/venv/bin/pip install cryptography
sudo cp licserver.service /etc/systemd/system/
sudo systemctl daemon-reload

# first run: generate signing key + DB, prints the PUBLIC key for your client
sudo -u licserver LICENSE_DATA_DIR=/var/lib/licserver /opt/licserver/venv/bin/python /opt/licserver/server.py init

sudo systemctl enable --now licserver
```

The service listens on `127.0.0.1:8787`. Put it behind a reverse proxy with HTTPS
(Caddy, nginx, or a Tailscale/Cloudflare tunnel), and set `LICENSE_TRUST_PROXY=1`.

## Admin (run on the server)

```bash
A="sudo -u licserver env LICENSE_DATA_DIR=/var/lib/licserver /opt/licserver/venv/bin/python /opt/licserver/server.py"
$A create --product mysoft --owner alice --max-machines 2 --days 365
$A list
$A revoke 3          # / unrevoke 3
$A reset-machines 3  # free activation slots
```

The license key is printed once at creation; only its hash is stored.

## Client

```python
from licclient import LicenseClient

lic = LicenseClient("https://license.example.com", "mysoft", "<PUBLIC_KEY_B64>")
lic.set_key(user_entered_key)      # once, e.g. from an "Activate" dialog
status = lic.check()               # at startup, then e.g. every few hours
if not status.ok:
    sys.exit(f"License: {status.reason}")
```

Call `check()` periodically while the app runs, so a revocation is noticed during a session.

## Honest limits

- With unlimited grace, blocking the server in the hosts file/firewall keeps a revoked license
  working. That's the deliberate trade-off for "shutting down never locks anyone out". If you
  set finite grace values, a determined user can still block the probe hosts too, so the
  client sees "no internet"; offline detection can't be made unforgeable.
- Python source is easy to patch: someone can edit the client to skip `check()`.
  This design stops casual sharing and enforces revocation; it is not DRM.
  For stronger protection, compile the check (Nuitka/Cython) or enforce it
  server-side (the licensed feature calls your API).
- Moving the cached token between machines fails (it is bound to `machine_id`).
- Rolling the clock back is partly guarded (token issue time), not fully.
- Always use HTTPS; the signature protects tokens, HTTPS protects license keys in transit.
