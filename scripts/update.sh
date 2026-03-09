#!/usr/bin/env bash
# ============================================================
# MalamPutih DNS — Blocklist Update Script
# Mengunduh, menggabungkan, dan mendeduplikasi blocklist
# dari berbagai sumber terpercaya.
#
# Penggunaan:
#   bash scripts/update.sh
#   bash scripts/update.sh --dry-run   (tidak tulis file)
# ============================================================

set -euo pipefail

# ── Warna output ──────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }
head_log() { echo -e "\n${BOLD}${CYAN}$1${NC}"; }

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true && warn "Mode DRY RUN aktif — tidak ada file yang ditulis."

# ── Direktori ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOMAIN_DIR="$ROOT_DIR/domain"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ── Sumber Blocklist ───────────────────────────────────────
declare -A SOURCES=(
  ["oisd_big"]="https://big.oisd.nl/domainswild"
  ["hagezi_pro"]="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/pro.txt"
  ["hagezi_tif"]="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/tif.txt"
  ["hagezi_porn"]="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/porn.txt"
  ["hagezi_gambling"]="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/gambling.txt"
  ["hagezi_fake"]="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/fake.txt"
  ["stevenblack"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  ["adguard"]="https://v.firebog.net/hosts/AdguardDNS.txt"
  ["abpindo"]="https://raw.githubusercontent.com/ABPindo/indonesianadblockrules/master/subscriptions/abpindo.txt"
  ["goodbyeads"]="https://raw.githubusercontent.com/jerryn70/GoodbyeAds/master/Hosts/GoodbyeAds.txt"
  ["easylist_annoy"]="https://secure.fanboy.co.nz/fanboy-annoyance.txt"
  ["nz_filter"]="https://raw.githubusercontent.com/nicehash/NiceHash-Filter/main/domains.txt"
)

# ── Fungsi: Download satu sumber ──────────────────────────
download_source() {
  local name="$1" url="$2" out="$TMP_DIR/${name}.txt"
  log "Mengunduh: $name ..."
  if curl -fsSL --max-time 60 --retry 3 --retry-delay 5 \
      -H "User-Agent: MalamPutih-DNS/1.0 (+https://dns.purnomoadi.web.id)" \
      -o "$out" "$url" 2>/dev/null; then
    local count
    count=$(wc -l < "$out")
    ok "$name → ${count} baris"
    echo "$out"
  else
    warn "Gagal mengunduh: $name ($url)"
    echo ""
  fi
}

# ── Fungsi: Parse berbagai format ke domain list ──────────
parse_to_domains() {
  local file="$1"
  [[ -z "$file" || ! -f "$file" ]] && return
  # Ekstrak domain dari:
  # - Format hosts:     0.0.0.0 example.com  atau  127.0.0.1 example.com
  # - Format adblock:   ||example.com^
  # - Format plain:     example.com
  awk '
    /^[[:space:]]*#/ { next }           # skip komentar
    /^[[:space:]]*$/ { next }           # skip baris kosong
    /^0\.0\.0\.0[[:space:]]/ {          # format hosts 0.0.0.0
      print $2; next
    }
    /^127\.0\.0\.1[[:space:]]/ {        # format hosts 127.0.0.1
      print $2; next
    }
    /^\|\|/ {                           # format adblock ||domain^
      gsub(/^\|\|/, ""); gsub(/\^.*$/, ""); gsub(/\/.*$/, "")
      if (length($0) > 0) print $0
      next
    }
    /^[a-zA-Z0-9]/ {                   # format plain domain
      split($0, a, "#"); domain=a[1]
      gsub(/[[:space:]]/, "", domain)
      if (domain ~ /^[a-zA-Z0-9]([a-zA-Z0-9\-]*\.)+[a-zA-Z]{2,}$/) print domain
    }
  ' "$file"
}

# ── Fungsi: Baca whitelist ─────────────────────────────────
load_whitelist() {
  local wl="$DOMAIN_DIR/whitelist.txt"
  [[ -f "$wl" ]] || { echo ""; return; }
  grep -v '^#' "$wl" | grep -v '^[[:space:]]*$' | tr '[:upper:]' '[:lower:]'
}

# ── Main ───────────────────────────────────────────────────
head_log "🛡️  MalamPutih DNS — Blocklist Updater"
echo "   Waktu: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "   Mode:  $([ "$DRY_RUN" = true ] && echo 'DRY RUN' || echo 'PRODUCTION')"
echo ""

# 1. Download semua sumber
head_log "📥 Mengunduh sumber blocklist..."
DOWNLOADED_FILES=()
for name in "${!SOURCES[@]}"; do
  file=$(download_source "$name" "${SOURCES[$name]}")
  [[ -n "$file" ]] && DOWNLOADED_FILES+=("$file")
done

# 2. Custom blocklist lokal
CUSTOM="$DOMAIN_DIR/custom-blocklist.txt"
if [[ -f "$CUSTOM" ]]; then
  log "Memuat custom blocklist lokal..."
  DOWNLOADED_FILES+=("$CUSTOM")
fi

# 3. Parse & gabungkan semua
head_log "⚙️  Memproses & menggabungkan..."
MERGED="$TMP_DIR/merged.txt"
for f in "${DOWNLOADED_FILES[@]}"; do
  parse_to_domains "$f" >> "$MERGED"
done

TOTAL_RAW=$(wc -l < "$MERGED")
log "Total domain mentah: $TOTAL_RAW"

# 4. Normalisasi: lowercase, hapus www., strip spasi
log "Normalisasi domain..."
sed -i 's/[[:space:]]//g' "$MERGED"
tr '[:upper:]' '[:lower:]' < "$MERGED" > "$TMP_DIR/lower.txt"
# Hapus domain yang diawali www. dan jadikan non-www juga
awk '{
  print $0
  if ($0 ~ /^www\./) { sub(/^www\./, ""); print }
}' "$TMP_DIR/lower.txt" > "$TMP_DIR/normalized.txt"

# 5. Filter domain tidak valid
log "Memfilter domain tidak valid..."
grep -E '^[a-z0-9]([a-z0-9\-]*\.)+[a-z]{2,}$' "$TMP_DIR/normalized.txt" \
  | grep -v '^\.' | grep -v '\.\.' \
  | grep -v '^localhost$' \
  | grep -v '^broadcasthost$' \
  > "$TMP_DIR/valid.txt" || true

# 6. Hapus duplikat & urutkan
log "Deduplikasi & sorting..."
sort -u "$TMP_DIR/valid.txt" > "$TMP_DIR/deduped.txt"
TOTAL_DEDUPED=$(wc -l < "$TMP_DIR/deduped.txt")
log "Setelah deduplikasi: $TOTAL_DEDUPED domain"

# 7. Terapkan whitelist
head_log "✅ Menerapkan whitelist..."
WHITELIST=$(load_whitelist)
FINAL="$TMP_DIR/final.txt"
if [[ -n "$WHITELIST" ]]; then
  WL_FILE="$TMP_DIR/whitelist_clean.txt"
  echo "$WHITELIST" > "$WL_FILE"
  WL_COUNT=$(wc -l < "$WL_FILE")
  log "Whitelist: $WL_COUNT domain dikecualikan"
  grep -vxFf "$WL_FILE" "$TMP_DIR/deduped.txt" > "$FINAL" || true
else
  cp "$TMP_DIR/deduped.txt" "$FINAL"
fi

TOTAL_FINAL=$(wc -l < "$FINAL")
REMOVED=$((TOTAL_DEDUPED - TOTAL_FINAL))

# 8. Tulis output
head_log "💾 Menulis output..."
HEADER="# MalamPutih DNS Blocklist
# Diperbarui: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
# Total domain: $TOTAL_FINAL
# Sumber: ${#SOURCES[@]} blocklist + custom list
# Website: https://dns.purnomoadi.web.id
# Repository: https://github.com/YOUR_USERNAME/malamputih-dns
#
# Format: plain domain list (satu domain per baris)
# Kompatibel dengan: Technitium DNS, Pi-hole, AdGuard Home, dnsmasq
"

OUTPUT_FILE="$DOMAIN_DIR/blocklist.txt"

if [[ "$DRY_RUN" == "false" ]]; then
  mkdir -p "$DOMAIN_DIR"
  { echo "$HEADER"; cat "$FINAL"; } > "$OUTPUT_FILE"
  ok "Blocklist ditulis → $OUTPUT_FILE"

  # Tulis stats.json untuk badge GitHub
  STATS_FILE="$ROOT_DIR/stats.json"
  cat > "$STATS_FILE" << EOF
{
  "total": $TOTAL_FINAL,
  "updated": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "sources": ${#SOURCES[@]},
  "raw": $TOTAL_RAW,
  "duplicates_removed": $((TOTAL_RAW - TOTAL_DEDUPED)),
  "whitelisted": $REMOVED
}
EOF
  ok "Stats ditulis → $STATS_FILE"
else
  warn "DRY RUN: tidak menulis file"
fi

# 9. Ringkasan
head_log "📊 Ringkasan"
echo "   Domain mentah (raw)    : $TOTAL_RAW"
echo "   Setelah deduplikasi    : $TOTAL_DEDUPED"
echo "   Dikecualikan whitelist : $REMOVED"
echo -e "   ${BOLD}TOTAL FINAL            : $TOTAL_FINAL domain${NC}"
echo ""
ok "Update selesai! 🎉"
