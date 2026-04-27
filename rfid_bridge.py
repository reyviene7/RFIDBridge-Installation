# rfid_bridge.py
# Warehouse Fitness — RFID Bridge Service
# Reads RFID cards (HID keyboard), looks up Supabase, triggers ESP32 relay.

import serial
import httpx
import asyncio
import os
import sys
import time
import msvcrt
import threading
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from dotenv import load_dotenv
from pathlib import Path

# ─── Resolve .env next to the EXE or script ───────────────────────────────────
if getattr(sys, 'frozen', False):
    BASE_DIR = Path(sys.executable).parent   # running as .exe
else:
    BASE_DIR = Path(__file__).parent         # running as .py

ENV_PATH = BASE_DIR / ".env"
load_dotenv(dotenv_path=ENV_PATH)

# ─── Logging setup ────────────────────────────────────────────────────────────
LOG_PATH = BASE_DIR / "rfid_bridge.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_PATH, encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ]
)
log = logging.getLogger("rfid_bridge")

# ─── Config ───────────────────────────────────────────────────────────────────
SERIAL_PORT  = os.getenv("SERIAL_PORT",  "COM11")
BAUD_RATE    = int(os.getenv("BAUD_RATE", "115200"))
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
HTTP_PORT    = int(os.getenv("HTTP_PORT", "8765"))

SUPABASE_HEADERS = {
    "apikey":        SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type":  "application/json",
    "Prefer":        "return=minimal",
}

_ser: serial.Serial | None = None
_ser_lock = threading.Lock()

# ─── Serial connect with retry ────────────────────────────────────────────────

def connect_serial():
    global _ser
    while True:
        try:
            with _ser_lock:
                if _ser and _ser.is_open:
                    return
                s = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
                _ser = s
            log.info(f"ESP32 connected on {SERIAL_PORT}")
            return
        except Exception as e:
            log.warning(f"ESP32 not found on {SERIAL_PORT} — retrying in 5s ({e})")
            time.sleep(5)

def serial_watchdog():
    """Background thread: reconnects if ESP32 is unplugged."""
    while True:
        try:
            with _ser_lock:
                ok = _ser and _ser.is_open
            if not ok:
                log.warning("ESP32 disconnected — reconnecting...")
                connect_serial()
        except Exception as e:
            log.error(f"Watchdog error: {e}")
        time.sleep(10)

# ─── HTTP server ──────────────────────────────────────────────────────────────

class DoorHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        if self.path == "/open-door":
            with _ser_lock:
                ready = _ser and _ser.is_open
            if ready:
                with _ser_lock:
                    _ser.write(b"OPEN\n")
                log.info("[DOOR] Manual open triggered from app")
                self._respond(200, b'{"ok": true}')
            else:
                self._respond(503, b'{"ok": false, "error": "ESP32 not connected"}')
        else:
            self.send_response(404)
            self.end_headers()

    def _respond(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

def start_http_server():
    server = HTTPServer(("localhost", HTTP_PORT), DoorHandler)
    log.info(f"Door API listening on http://localhost:{HTTP_PORT}")
    server.serve_forever()

# ─── RFID lookup + log ────────────────────────────────────────────────────────

async def lookup_and_log(uid: str):
    uid = uid.strip().upper()
    if not uid:
        return
    log.info(f"[SCAN] UID: {uid}")

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            res     = await client.get(
                f"{SUPABASE_URL}/rest/v1/members",
                headers=SUPABASE_HEADERS,
                params={"rfid_uid": f"eq.{uid}", "select": "*"}
            )
            members = res.json()

            if members:
                m      = members[0]
                access = m["membership_type"] in ["vip", "24hour"]
                active = m["membership_status"] == "active"
                if access and active:   status, reason = "granted", None
                elif not access:        status, reason = "denied",  "Regular/Walk-in use front desk entrance"
                else:                   status, reason = "denied",  f"Membership is {m['membership_status']}"
                entry = {
                    "uid": uid, "holder_name": m["name"], "holder_role": "member",
                    "membership_type": m["membership_type"],
                    "membership_status": m["membership_status"],
                    "status": status, "reason": reason,
                }
            else:
                res2    = await client.get(
                    f"{SUPABASE_URL}/rest/v1/coaches",
                    headers=SUPABASE_HEADERS,
                    params={"rfid_uid": f"eq.{uid}", "select": "*"}
                )
                coaches = res2.json()
                if coaches:
                    c     = coaches[0]
                    entry = {
                        "uid": uid, "holder_name": c["name"], "holder_role": "coach",
                        "membership_type": None, "membership_status": None,
                        "status": "denied" if c["status"] == "on-leave" else "granted",
                        "reason": "Coach is on leave" if c["status"] == "on-leave" else None,
                    }
                else:
                    res3  = await client.get(
                        f"{SUPABASE_URL}/rest/v1/staff",
                        headers=SUPABASE_HEADERS,
                        params={"rfid_uid": f"eq.{uid}", "select": "*"}
                    )
                    staff = res3.json()
                    if staff:
                        entry = {
                            "uid": uid, "holder_name": staff[0]["name"],
                            "holder_role": "frontdesk", "membership_type": None,
                            "membership_status": None, "status": "granted", "reason": None,
                        }
                    else:
                        entry = {
                            "uid": uid, "holder_name": None, "holder_role": None,
                            "membership_type": None, "membership_status": None,
                            "status": "unknown", "reason": "Card not registered in system",
                        }

            post_res = await client.post(
                f"{SUPABASE_URL}/rest/v1/rfid_access_log",
                headers=SUPABASE_HEADERS, json=entry
            )
            if post_res.status_code not in (200, 201):
                log.warning(f"Supabase log error {post_res.status_code}: {post_res.text}")

            symbol = "✅" if entry["status"] == "granted" else "❌"
            log.info(f"{symbol} [{entry['status'].upper()}] {entry.get('holder_name') or 'Unknown'} | UID: {uid}")

            if entry["status"] == "granted":
                with _ser_lock:
                    ready = _ser and _ser.is_open
                if ready:
                    with _ser_lock:
                        _ser.write(b"OPEN\n")
                    log.info("[RELAY] OPEN sent to ESP32")
                else:
                    log.warning("[RELAY] ESP32 not connected — cannot open lock")

    except Exception as e:
        log.error(f"lookup_and_log error: {e}")

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    log.info("=" * 44)
    log.info("  Warehouse Fitness — RFID Bridge v1.0")
    log.info(f"  ESP32 port : {SERIAL_PORT}")
    log.info(f"  Supabase   : {SUPABASE_URL}")
    log.info(f"  Log file   : {LOG_PATH}")
    log.info("=" * 44)

    if not SUPABASE_URL or not SUPABASE_KEY:
        log.error("MISSING: SUPABASE_URL or SUPABASE_KEY not set in .env — exiting.")
        sys.exit(1)

    # Connect ESP32 (blocks until connected)
    connect_serial()

    # Watchdog thread — reconnects if unplugged
    t_watchdog = threading.Thread(target=serial_watchdog, daemon=True)
    t_watchdog.start()

    # HTTP server thread
    t_http = threading.Thread(target=start_http_server, daemon=True)
    t_http.start()

    log.info("Waiting for card scans...\n")

    loop   = asyncio.new_event_loop()
    buffer = ""

    while True:
        if msvcrt.kbhit():
            ch = msvcrt.getwch()
            if ch in ('\r', '\n'):
                uid = buffer.strip()
                buffer = ""
                if uid:
                    loop.run_until_complete(lookup_and_log(uid))
            elif ch == '\x03':   # Ctrl+C
                log.info("Exiting...")
                with _ser_lock:
                    if _ser:
                        _ser.close()
                break
            else:
                buffer += ch
        else:
            time.sleep(0.01)

if __name__ == "__main__":
    main()
