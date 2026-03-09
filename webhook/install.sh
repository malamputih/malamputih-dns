#!/usr/bin/env bash
# ================================================================
# MalamPutih DNS — Install Webhook
# Jalankan sebagai root di server:
#   bash webhook/install.sh
# ================================================================

set -euo pipefail
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m';NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log()  { echo -e "${CYAN}[..] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }
err()  { echo -e "${RED}[ERR] $1${NC}"; exit 1; }

[[ "$EUID" -ne 0 ]] && err "Jalankan sebagai root: sudo bash webhook/install.sh"

echo -e "\n${CYAN}🛡️  MalamPutih DNS — Webhook Installer${NC}\n"

# ── 1. Generate secret acak ────────────────────────────────
SECRET=$(openssl rand -hex 32)
echo -e "${YELLOW}⚠️  Simpan secret ini — akan dipakai di GitHub Secrets:${NC}"
echo -e "${CYAN}   WEBHOOK_SECRET = ${SECRET}${NC}\n"

# ── 2. Install Flask ───────────────────────────────────────
log "Install Flask..."
pip3 install flask --break-system-packages -q
ok "Flask terinstall"

# ── 3. Buat direktori ──────────────────────────────────────
log "Membuat /opt/malamputih..."
mkdir -p /opt/malamputih
cp "$(dirname "$0")/webhook.py" /opt/malamputih/webhook.py
ok "File disalin ke /opt/malamputih/"

# ── 4. Tulis service file dengan secret yang sudah digenerate
log "Membuat systemd service..."
TECHNITIUM_TOKEN="8339edc7f42c80c9935e92946494629055cdc0d2eac65f9ecb6272eda62f2c7f"
cat > /etc/systemd/system/malamputih-webhook.service << EOF
[Unit]
Description=MalamPutih DNS Webhook Server
After=network.target dns.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/malamputih
ExecStart=/usr/bin/python3 /opt/malamputih/webhook.py
Restart=always
RestartSec=5
Environment="WEBHOOK_SECRET=${SECRET}"
Environment="TECHNITIUM_TOKEN=${TECHNITIUM_TOKEN}"
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
ok "Service file dibuat"

# ── 5. Enable & start service ──────────────────────────────
log "Mengaktifkan service..."
systemctl daemon-reload
systemctl enable malamputih-webhook
systemctl restart malamputih-webhook
sleep 2

if systemctl is-active --quiet malamputih-webhook; then
  ok "Service berjalan!"
else
  err "Service gagal start. Cek: journalctl -u malamputih-webhook -n 20"
fi

# ── 6. Tambahkan Nginx location ────────────────────────────
log "Menambahkan route /webhook ke Nginx..."
NGINX_CONF="/etc/nginx/sites-available/malamputih-dns"

if grep -q "/webhook" "$NGINX_CONF" 2>/dev/null; then
  warn "Route /webhook sudah ada di Nginx, skip."
else
  # Sisipkan sebelum blok location /api/
  sed -i '/location \/api\//i\
\
    location /webhook {\
        proxy_pass http:\/\/127.0.0.1:9876\/webhook;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_read_timeout 30s;\
    }\
' "$NGINX_CONF"

  nginx -t && systemctl reload nginx
  ok "Nginx dikonfigurasi"
fi

# ── 7. Test ────────────────────────────────────────────────
log "Test endpoint health..."
sleep 1
HEALTH=$(curl -sf http://127.0.0.1:9876/health 2>/dev/null || echo "failed")
if echo "$HEALTH" | grep -q "ok"; then
  ok "Webhook server merespons!"
else
  warn "Webhook belum merespons — cek: systemctl status malamputih-webhook"
fi

# ── Ringkasan ──────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━ INSTALASI SELESAI ━━━${NC}"
echo ""
echo -e "Endpoint publik : ${CYAN}https://dns.purnomoadi.web.id/webhook/github${NC}"
echo -e "Health check    : ${CYAN}https://dns.purnomoadi.web.id/webhook/health${NC}"
echo ""
echo -e "${YELLOW}Langkah selanjutnya — tambahkan ke GitHub Secrets:${NC}"
echo -e "  WEBHOOK_SECRET = ${CYAN}${SECRET}${NC}"
echo -e "  WEBHOOK_URL    = ${CYAN}https://dns.purnomoadi.web.id/webhook/github${NC}"
echo ""
echo -e "${YELLOW}Dan tambahkan GitHub Webhook di:${NC}"
echo -e "  Repo → Settings → Webhooks → Add webhook"
echo -e "  Payload URL   : https://dns.purnomoadi.web.id/webhook/github"
echo -e "  Content type  : application/json"
echo -e "  Secret        : ${SECRET}"
echo -e "  Events        : Just the push event"
echo ""
