#!/usr/bin/env python3
# ================================================================
# MalamPutih DNS — Webhook Server
# Menerima trigger dari GitHub Actions → update Technitium
#
# Install:  pip3 install flask --break-system-packages
# Jalankan: python3 /opt/malamputih/webhook.py
# Service:  systemctl start malamputih-webhook
# ================================================================

import os
import hmac
import hashlib
import subprocess
import logging
from datetime import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)

# ── Konfigurasi ────────────────────────────────────────────
WEBHOOK_SECRET = os.environ.get("WEBHOOK_SECRET", "GANTI_DENGAN_SECRET_KAMU")
TECHNITIUM_TOKEN = os.environ.get("TECHNITIUM_TOKEN", "8339edc7f42c80c9935e92946494629055cdc0d2eac65f9ecb6272eda62f2c7f")
TECHNITIUM_HOST = "http://127.0.0.1:5380"
PORT = 9876  # Port webhook (tidak perlu expose ke publik, cukup via Nginx)

# ── Logging ────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
log = logging.getLogger(__name__)

# ── Verifikasi signature GitHub ────────────────────────────
def verify_signature(payload: bytes, signature: str) -> bool:
    if not signature or not signature.startswith("sha256="):
        return False
    expected = hmac.new(
        WEBHOOK_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)

# ── Trigger update Technitium ──────────────────────────────
def trigger_technitium_update() -> dict:
    import urllib.request
    import json

    url = f"{TECHNITIUM_HOST}/api/blocklist/forceUpdate?token={TECHNITIUM_TOKEN}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "MalamPutih-Webhook/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
            if data.get("status") == "ok":
                log.info("✅ Technitium blocklist update berhasil")
                return {"success": True, "message": "Technitium update triggered"}
            else:
                log.warning(f"⚠️  Technitium response: {data}")
                return {"success": False, "message": str(data)}
    except Exception as e:
        log.error(f"❌ Gagal trigger Technitium: {e}")
        return {"success": False, "message": str(e)}

# ── Routes ─────────────────────────────────────────────────

@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "service": "MalamPutih DNS Webhook",
        "status": "running",
        "time": datetime.utcnow().isoformat() + "Z"
    })

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})

@app.route("/webhook/github", methods=["POST"])
def github_webhook():
    # Verifikasi signature
    sig = request.headers.get("X-Hub-Signature-256", "")
    if not verify_signature(request.data, sig):
        log.warning(f"⛔ Signature tidak valid dari {request.remote_addr}")
        return jsonify({"error": "Invalid signature"}), 401

    # Ambil event type
    event = request.headers.get("X-GitHub-Event", "unknown")
    payload = request.get_json(silent=True) or {}

    log.info(f"📥 GitHub event: {event} dari {request.remote_addr}")

    # Hanya proses push ke branch main
    if event == "push":
        branch = payload.get("ref", "")
        if "main" not in branch and "master" not in branch:
            return jsonify({"message": f"Ignored branch: {branch}"}), 200

        # Cek apakah file blocklist yang berubah
        changed = []
        for commit in payload.get("commits", []):
            changed += commit.get("modified", [])
            changed += commit.get("added", [])

        blocklist_changed = any("blocklist" in f or "domain/" in f for f in changed)

        if not blocklist_changed:
            log.info("ℹ️  Push tidak mengubah blocklist, skip update")
            return jsonify({"message": "No blocklist changes, skipped"}), 200

        log.info("🔄 Blocklist berubah, trigger Technitium update...")
        result = trigger_technitium_update()
        return jsonify(result), 200 if result["success"] else 500

    # Ping event dari GitHub (test webhook)
    elif event == "ping":
        log.info("🏓 Ping dari GitHub — webhook aktif!")
        return jsonify({"message": "pong", "status": "webhook active"}), 200

    # Event lain diabaikan
    return jsonify({"message": f"Event '{event}' ignored"}), 200


@app.route("/webhook/manual", methods=["POST"])
def manual_trigger():
    """Endpoint untuk trigger manual (dengan Bearer token)"""
    auth = request.headers.get("Authorization", "")
    expected = f"Bearer {WEBHOOK_SECRET}"
    if not hmac.compare_digest(auth, expected):
        return jsonify({"error": "Unauthorized"}), 401

    log.info("🔧 Manual trigger diterima")
    result = trigger_technitium_update()
    return jsonify(result), 200 if result["success"] else 500


if __name__ == "__main__":
    log.info(f"🚀 MalamPutih Webhook Server berjalan di port {PORT}")
    log.info(f"   Endpoint: POST /webhook/github")
    log.info(f"   Health  : GET  /health")
    app.run(host="127.0.0.1", port=PORT, debug=False)
