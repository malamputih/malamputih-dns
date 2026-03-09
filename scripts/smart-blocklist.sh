#!/usr/bin/env bash
# ================================================================
# MalamPutih DNS — Smart Blocklist Generator
# 
# Strategi berlapis:
#   1. Pattern TLD-based  — keyword judi + TLD murahan
#   2. NRD Blocklist      — domain baru < 30 hari (judol jarang pakai domain lama)
#   3. Crawler            — auto-detect dari sumber publik Indonesia
#   4. Scoring            — skor domain berdasarkan pola nama
#
# Penggunaan:
#   bash scripts/smart-blocklist.sh              # full run
#   bash scripts/smart-blocklist.sh --pattern    # pattern filter saja
#   bash scripts/smart-blocklist.sh --nrd        # NRD saja
#   bash scripts/smart-blocklist.sh --crawl      # crawler saja
#   bash scripts/smart-blocklist.sh --dry-run    # tidak tulis file
# ================================================================

set -euo pipefail

# ── Warna ──────────────────────────────────────────────────
R='\033[0;31m';G='\033[0;32m';Y='\033[1;33m'
B='\033[0;34m';C='\033[0;36m';W='\033[1m';N='\033[0m'
log()  { echo -e "${B}[INFO]${N} $1"; }
ok()   { echo -e "${G}[ OK ]${N} $1"; }
warn() { echo -e "${Y}[WARN]${N} $1"; }
err()  { echo -e "${R}[ERR ]${N} $1"; }
head_log() { echo -e "\n${W}${C}━━━ $1 ━━━${N}"; }

# ── Mode ───────────────────────────────────────────────────
DO_PATTERN=true; DO_NRD=true; DO_CRAWL=true; DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --pattern) DO_PATTERN=true;  DO_NRD=false;  DO_CRAWL=false ;;
    --nrd)     DO_PATTERN=false; DO_NRD=true;   DO_CRAWL=false ;;
    --crawl)   DO_PATTERN=false; DO_NRD=false;  DO_CRAWL=true  ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

# ── Path ───────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOMAIN_DIR="$ROOT_DIR/domain"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$DOMAIN_DIR"

# ── Fungsi HTTP ────────────────────────────────────────────
fetch() {
  local url="$1" out="$2"
  curl -fsSL --max-time 45 --retry 3 --retry-delay 5 \
    -H "User-Agent: MalamPutih-DNS/1.0 (+https://dns.purnomoadi.web.id)" \
    -o "$out" "$url" 2>/dev/null
}

# ================================================================
# BAGIAN 1 — PATTERN TLD-BASED FILTER
# Logika: keyword_kuat + TLD_murahan = BLOKIR AMAN
#         keyword_kuat + TLD_legit   = perlu kombinasi 2+ keyword
# ================================================================

run_pattern_filter() {
  head_log "PATTERN TLD-BASED FILTER"

  # ── Keyword level 1: SANGAT KUAT (1 keyword cukup untuk TLD murahan)
  # Kata-kata ini hampir tidak pernah muncul di domain situs legit
  local KW_STRONG=(
    togel toto4d toto2d
    judionline judibola judipoker
    slot88 slot777 slot99 slot168 slot303 slot138
    casino casinoindo casinoonline
    taruhan taruhanonline
    sportbook sbobet sbo
    parlay parlaybet
    idn-poker idnpoker idnslot
    joker123 joker388
    pragmatic pgsoft pgslot
    habanero spinix
    sabungayam cockfight
    togelmacau togelsgp togelhk togelsydney
    bandartogel bandarslot bandarcasino bandarpoker
    dominoqq dominobet
    bandarq bandarqq
    pokerv pokervit
    cemekeliling
    capsakeliling
  )

  # ── Keyword level 2: SEDANG (butuh TLD murahan ATAU kombinasi 2 keyword)
  local KW_MEDIUM=(
    slot gacor maxwin scatter
    jackpot bonus deposit withdraw
    poker ceme capsa domino
    baccarat roulette sicbo
    betting bet odds
    spin free-spin freespin
    win winning payout
    rtp bocoran prediksi
    agen daftar login member
    resmi terpercaya terbaik
    server thailand vietnam
  )

  # ── TLD MURAHAN: pakai keyword APAPUN → blokir aman
  # TLD ini sangat jarang dipakai situs legitimate Indonesia
  local TLD_HIGH_RISK=(
    xyz site online fun live vip win bet
    casino poker club pw top icu buzz
    cyou cfd gdn rest uno bid
    review link info-bad
    mobi ws name pro
  )

  # ── TLD SEDANG: butuh keyword KUAT untuk blokir
  # Masih ada situs legit yang pakai ini
  local TLD_MEDIUM_RISK=(
    info biz us co space
    store website tech
  )

  # ── TLD AMAN: TIDAK di-generate (terlalu banyak false positive)
  # .com .net .id .co.id .org — perlu exact domain list manual

  local OUT="$TMP/pattern_result.txt"
  > "$OUT"

  log "Membuat kombinasi pattern..."

  # Kombinasi 1: keyword KUAT + TLD MURAHAN (blokir langsung)
  local count1=0
  for kw in "${KW_STRONG[@]}"; do
    for tld in "${TLD_HIGH_RISK[@]}"; do
      # Berbagai variasi nama domain
      echo "${kw}.${tld}"          >> "$OUT"  # togel.xyz
      echo "www.${kw}.${tld}"      >> "$OUT"  # www.togel.xyz
      echo "${kw}1.${tld}"         >> "$OUT"  # togel1.xyz
      echo "${kw}2.${tld}"         >> "$OUT"  # togel2.xyz
      echo "${kw}88.${tld}"        >> "$OUT"  # togel88.xyz
      echo "${kw}99.${tld}"        >> "$OUT"  # togel99.xyz
      echo "${kw}168.${tld}"       >> "$OUT"  # togel168.xyz
      echo "${kw}303.${tld}"       >> "$OUT"  # togel303.xyz
      echo "${kw}777.${tld}"       >> "$OUT"  # togel777.xyz
      echo "${kw}999.${tld}"       >> "$OUT"  # togel999.xyz
      echo "daftar${kw}.${tld}"    >> "$OUT"  # daftartogel.xyz
      echo "login${kw}.${tld}"     >> "$OUT"  # logintogel.xyz
      echo "link${kw}.${tld}"      >> "$OUT"  # linktogel.xyz
      echo "agen${kw}.${tld}"      >> "$OUT"  # agentogel.xyz
      echo "${kw}indo.${tld}"      >> "$OUT"  # togelindo.xyz
      ((count1++)) || true
    done
  done

  # Kombinasi 2: keyword SEDANG + TLD MURAHAN
  for kw in "${KW_MEDIUM[@]}"; do
    for tld in "${TLD_HIGH_RISK[@]}"; do
      echo "${kw}.${tld}"     >> "$OUT"
      echo "${kw}88.${tld}"   >> "$OUT"
      echo "${kw}99.${tld}"   >> "$OUT"
      echo "${kw}777.${tld}"  >> "$OUT"
    done
  done

  # Kombinasi 3: keyword KUAT + TLD SEDANG
  for kw in "${KW_STRONG[@]}"; do
    for tld in "${TLD_MEDIUM_RISK[@]}"; do
      echo "${kw}.${tld}"     >> "$OUT"
      echo "${kw}88.${tld}"   >> "$OUT"
    done
  done

  local total
  total=$(sort -u "$OUT" | wc -l)
  ok "Pattern filter: $total kombinasi domain dibuat"

  sort -u "$OUT" > "$TMP/pattern_clean.txt"
}

# ================================================================
# BAGIAN 2 — NRD (Newly Registered Domains)
# Domain judol hampir selalu baru didaftarkan < 30 hari
# Sumber: Hagezi NRD + WHOISDS public feed
# ================================================================

run_nrd() {
  head_log "NRD — NEWLY REGISTERED DOMAINS"

  local NRD_SOURCES=(
    # Hagezi NRD 30 hari — sangat efektif untuk judol
    "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/nrd-30day.txt"
    # Hagezi NRD 14 hari — lebih agresif
    "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/nrd-14day.txt"
    # WHOISDS daily NRD feed
    "https://whoisds.com/whois-database/newly-registered-domains/$(date -d '2 days ago' '+%Y-%m-%d').zip/nrd"
  )

  local NRD_ALL="$TMP/nrd_all.txt"
  > "$NRD_ALL"

  for url in "${NRD_SOURCES[@]}"; do
    local fname
    fname="$TMP/nrd_$(echo "$url" | md5sum | cut -c1-8).txt"
    log "Mengunduh NRD: $(basename "$url" | cut -c1-50)..."
    if fetch "$url" "$fname"; then
      # Parse: bisa format hosts, adblock, atau plain
      grep -E '^[a-zA-Z0-9]' "$fname" \
        | grep -v '^#' \
        | awk '{print $NF}' \
        | tr '[:upper:]' '[:lower:]' \
        | grep -E '^[a-z0-9]([a-z0-9\-]*\.)+[a-z]{2,}$' \
        >> "$NRD_ALL" || true
      ok "  $(wc -l < "$fname") baris dari $(basename "$url" | cut -c1-40)"
    else
      warn "  Gagal: $url"
    fi
  done

  local nrd_total
  nrd_total=$(sort -u "$NRD_ALL" | wc -l)
  log "Total NRD mentah: $nrd_total domain"

  # ── Filter NRD: hanya simpan yang MENGANDUNG keyword judi
  # Ini cara cerdas: dari jutaan NRD, ambil yang namanya mencurigakan
  local JUDI_KEYWORDS=(
    togel slot casino poker sbobet
    taruhan bet gambling judol judi
    jackpot spin gacor maxwin scatter
    toto baccarat roulette
    pragmatic pgsoft joker
    bandar agen daftar-slot
  )

  log "Memfilter NRD berdasarkan keyword judi..."
  local NRD_FILTERED="$TMP/nrd_filtered.txt"
  > "$NRD_FILTERED"

  # Buat grep pattern dari keyword
  local PATTERN
  PATTERN=$(printf '%s|' "${JUDI_KEYWORDS[@]}" | sed 's/|$//')

  grep -iE "($PATTERN)" "$NRD_ALL" >> "$NRD_FILTERED" || true

  local filtered_total
  filtered_total=$(wc -l < "$NRD_FILTERED")
  ok "NRD setelah filter keyword: $filtered_total domain mencurigakan"

  # Simpan juga full NRD (tanpa filter) untuk referensi
  sort -u "$NRD_ALL" > "$TMP/nrd_full.txt"
}

# ================================================================
# BAGIAN 3 — CRAWLER
# Auto-detect domain judol baru dari sumber publik Indonesia
# Sumber: Kominfo trust+, laporan komunitas, certificate transparency
# ================================================================

run_crawler() {
  head_log "CRAWLER — AUTO-DETECT DOMAIN JUDOL BARU"

  local CRAWL_OUT="$TMP/crawl_result.txt"
  > "$CRAWL_OUT"

  # ── 3a. Certificate Transparency Log
  # Setiap domain baru yang pakai HTTPS punya sertifikat.
  # crt.sh bisa dicari berdasarkan keyword!
  log "Mencari di Certificate Transparency (crt.sh)..."

  local CT_KEYWORDS=("togel" "slot88" "slot777" "judionline" "slotgacor" "casinoonline")

  for kw in "${CT_KEYWORDS[@]}"; do
    local ct_file="$TMP/ct_${kw}.json"
    if fetch "https://crt.sh/?q=%25${kw}%25&output=json" "$ct_file"; then
      # Parse JSON: ambil field name_value
      python3 -c "
import json, sys, re
try:
    data = json.load(open('$ct_file'))
    domains = set()
    for entry in data:
        for field in ['name_value', 'common_name']:
            val = entry.get(field, '')
            # Pisahkan multi-domain (ada yang pakai newline atau spasi)
            for d in re.split(r'[\n\s]+', val):
                d = d.strip().lstrip('*.')
                if re.match(r'^[a-z0-9]([a-z0-9\-]*\.)+[a-z]{2,}$', d.lower()):
                    domains.add(d.lower())
    for d in domains:
        print(d)
except:
    pass
" 2>/dev/null >> "$CRAWL_OUT" || true
      ok "  crt.sh[$kw]: $(grep -c "." "$ct_file" || echo 0) sertifikat ditemukan"
    else
      warn "  crt.sh[$kw]: timeout/gagal"
    fi
    sleep 1  # rate limit crt.sh
  done

  # ── 3b. URLhaus — database URL malware & phishing aktif
  log "Mengunduh URLhaus database..."
  local uh_file="$TMP/urlhaus.txt"
  if fetch "https://urlhaus.abuse.ch/downloads/text_online/" "$uh_file"; then
    grep -v '^#' "$uh_file" \
      | grep -oE 'https?://[^/]+' \
      | sed 's|https\?://||' \
      | tr '[:upper:]' '[:lower:]' \
      | grep -E '^[a-z0-9]([a-z0-9\-]*\.)+[a-z]{2,}$' \
      >> "$CRAWL_OUT" || true
    ok "URLhaus: $(wc -l < "$uh_file") URL aktif diproses"
  fi

  # ── 3c. PhishTank — database phishing aktif
  log "Mengunduh PhishTank feed..."
  local pt_file="$TMP/phishtank.csv"
  if fetch "https://data.phishtank.com/data/online-valid.csv.bz2" "$pt_file.bz2" 2>/dev/null; then
    bunzip2 -c "$pt_file.bz2" 2>/dev/null \
      | grep -oE 'https?://[^/,]+' \
      | sed 's|https\?://||' \
      | tr '[:upper:]' '[:lower:]' \
      >> "$CRAWL_OUT" || true
    ok "PhishTank: diproses"
  else
    warn "PhishTank: gagal (mungkin butuh API key)"
  fi

  # ── 3d. OpenPhish — phishing feed gratis
  log "Mengunduh OpenPhish feed..."
  local op_file="$TMP/openphish.txt"
  if fetch "https://openphish.com/feed.txt" "$op_file"; then
    grep -oE 'https?://[^/]+' "$op_file" \
      | sed 's|https\?://||' \
      | tr '[:upper:]' '[:lower:]' \
      >> "$CRAWL_OUT" || true
    ok "OpenPhish: $(wc -l < "$op_file") URL diproses"
  fi

  # ── 3e. Kominfo Trust+ Positif (domain diblokir pemerintah)
  # Ini sumber emas untuk judol Indonesia
  log "Mencoba Kominfo Trust+ Positif feed..."
  local ktrust_file="$TMP/kominfo_trust.txt"
  if fetch "http://trustpositif.kominfo.go.id/files/domains.txt" "$ktrust_file" 2>/dev/null; then
    grep -v '^#' "$ktrust_file" \
      | tr '[:upper:]' '[:lower:]' \
      | grep -E '^[a-z0-9]([a-z0-9\-]*\.)+[a-z]{2,}$' \
      >> "$CRAWL_OUT" || true
    ok "Kominfo Trust+: $(wc -l < "$ktrust_file") domain"
  else
    warn "Kominfo Trust+: tidak dapat diakses (mungkin hanya tersedia dari IP Indonesia)"
  fi

  local crawl_total
  crawl_total=$(sort -u "$CRAWL_OUT" | wc -l)
  ok "Crawler total: $crawl_total domain unik ditemukan"
}

# ================================================================
# BAGIAN 4 — DOMAIN SCORING
# Skor setiap domain berdasarkan pola nama
# Score >= threshold → masuk blocklist
# ================================================================

score_domains() {
  local input_file="$1"
  local output_file="$2"

  log "Menjalankan domain scoring..."
  python3 << PYEOF
import re, sys

# Keyword dengan bobot skor
KEYWORDS = {
    # Skor tinggi — sangat spesifik judol
    'togel': 90, 'toto': 80, 'slot88': 95, 'slot777': 95,
    'judionline': 95, 'casino': 85, 'sbobet': 95, 'taruhan': 85,
    'joker123': 95, 'idn-poker': 95, 'idnpoker': 95,
    'pragmatic': 80, 'pgsoft': 80, 'habanero': 80,
    'sabungayam': 90, 'bandarq': 90, 'dominoqq': 90,
    'bandarslot': 90, 'bandartogel': 90,

    # Skor sedang
    'slot': 50, 'gacor': 60, 'maxwin': 65, 'scatter': 55,
    'jackpot': 60, 'poker': 55, 'betting': 65, 'bet': 40,
    'spin': 40, 'bonus': 30, 'deposit': 35, 'withdraw': 40,
    'win': 25, 'rtp': 55, 'bocoran': 60, 'prediksi': 45,
    'daftar': 20, 'agen': 25, 'member': 20,
}

# TLD dengan bobot
TLD_SCORE = {
    'xyz': 40, 'site': 40, 'online': 35, 'fun': 45, 'live': 35,
    'vip': 40, 'win': 50, 'bet': 60, 'casino': 70, 'poker': 65,
    'club': 30, 'pw': 45, 'top': 30, 'icu': 40, 'buzz': 35,
    'cyou': 45, 'cfd': 45, 'gdn': 40, 'rest': 35, 'uno': 40,
    'info': 10, 'biz': 15, 'us': 5,
}

# Pola struktural yang mencurigakan
def structural_score(domain):
    score = 0
    name = domain.split('.')[0]

    # Banyak angka di belakang nama (slot88, win777, togel123)
    if re.search(r'[a-z]{3,}[0-9]{2,}$', name): score += 20
    if re.search(r'[0-9]{3,}', name): score += 15

    # Panjang nama domain (judol sering pakai nama panjang random)
    if len(name) > 15: score += 10
    if len(name) > 20: score += 10

    # Banyak tanda hubung (slot-gacor-maxwin-terpercaya)
    hyphens = name.count('-')
    if hyphens >= 2: score += 15
    if hyphens >= 3: score += 15

    # Kombinasi huruf+angka random (entropy tinggi)
    if re.search(r'[a-z][0-9][a-z]|[0-9][a-z][0-9]', name): score += 10

    return score

THRESHOLD = 70  # Skor minimum untuk masuk blocklist

results = []
seen = set()

with open('$input_file', 'r') as f:
    for line in f:
        domain = line.strip().lower()
        if not domain or domain.startswith('#') or domain in seen:
            continue
        if not re.match(r'^[a-z0-9]([a-z0-9\-]*\.)+[a-z]{2,}$', domain):
            continue
        seen.add(domain)

        score = 0
        domain_lower = domain.replace('-', '')

        # Skor keyword
        for kw, pts in KEYWORDS.items():
            if kw.replace('-','') in domain_lower:
                score += pts

        # Skor TLD
        parts = domain.split('.')
        tld = parts[-1] if len(parts) > 1 else ''
        score += TLD_SCORE.get(tld, 0)

        # Skor struktural
        score += structural_score(domain)

        if score >= THRESHOLD:
            results.append((score, domain))

# Urutkan dari skor tertinggi
results.sort(reverse=True)

with open('$output_file', 'w') as f:
    f.write('# MalamPutih DNS — Smart Scored Blocklist\n')
    f.write('# Format: domain (skor dalam komentar untuk debug)\n')
    f.write(f'# Total: {len(results)} domain\n')
    f.write(f'# Threshold: {THRESHOLD}\n\n')
    for score, domain in results:
        f.write(f'{domain}\n')

print(f'Scoring selesai: {len(results)} domain lolos threshold {THRESHOLD}')
PYEOF
}

# ================================================================
# MAIN — Gabungkan semua hasil
# ================================================================

echo -e "\n${W}${C}🛡️  MalamPutih DNS — Smart Blocklist Generator${N}"
echo "   $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "   Mode: Pattern=$DO_PATTERN NRD=$DO_NRD Crawl=$DO_CRAWL DryRun=$DRY_RUN"

ALL_DOMAINS="$TMP/all_combined.txt"
> "$ALL_DOMAINS"

# Jalankan modul yang dipilih
[[ "$DO_PATTERN" == "true" ]] && run_pattern_filter && cat "$TMP/pattern_clean.txt" >> "$ALL_DOMAINS"
[[ "$DO_NRD"     == "true" ]] && run_nrd          && cat "$TMP/nrd_filtered.txt"   >> "$ALL_DOMAINS"
[[ "$DO_CRAWL"   == "true" ]] && run_crawl        && cat "$TMP/crawl_result.txt"   >> "$ALL_DOMAINS" 2>/dev/null || true

head_log "SCORING & FINALISASI"

# Normalisasi
tr '[:upper:]' '[:lower:]' < "$ALL_DOMAINS" \
  | sed 's/^www\.//' \
  | grep -E '^[a-z0-9]([a-z0-9\-]*\.)+[a-z]{2,}$' \
  | sort -u > "$TMP/normalized.txt"

log "Total sebelum scoring: $(wc -l < "$TMP/normalized.txt") domain"

# Scoring
SCORED="$TMP/scored.txt"
score_domains "$TMP/normalized.txt" "$SCORED"

SCORED_TOTAL=$(grep -c '^[^#]' "$SCORED" || true)

# Terapkan whitelist
WL="$DOMAIN_DIR/whitelist.txt"
FINAL="$TMP/final_smart.txt"
if [[ -f "$WL" ]]; then
  WL_CLEAN="$TMP/wl.txt"
  grep -v '^#' "$WL" | grep -v '^[[:space:]]*$' | tr '[:upper:]' '[:lower:]' > "$WL_CLEAN"
  WL_COUNT=$(wc -l < "$WL_CLEAN")
  grep -vxFf "$WL_CLEAN" "$SCORED" > "$FINAL" || true
  ok "Whitelist diterapkan: $WL_COUNT domain dikecualikan"
else
  cp "$SCORED" "$FINAL"
fi

FINAL_TOTAL=$(grep -c '^[^#]' "$FINAL" || echo 0)

# Tulis output
if [[ "$DRY_RUN" == "false" ]]; then
  OUTPUT="$DOMAIN_DIR/smart-blocklist.txt"
  {
    echo "# MalamPutih DNS — Smart Blocklist"
    echo "# Dibuat: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "# Metode: Pattern TLD-based + NRD + Crawler + Scoring"
    echo "# Total: $FINAL_TOTAL domain"
    echo "# Website: https://dns.purnomoadi.web.id"
    echo ""
    grep '^[^#]' "$FINAL" | sort -u
  } > "$OUTPUT"
  ok "Ditulis → $OUTPUT"

  # Update stats.json
  if [[ -f "$ROOT_DIR/stats.json" ]]; then
    python3 -c "
import json
with open('$ROOT_DIR/stats.json','r') as f: d=json.load(f)
d['smart_blocked']=$FINAL_TOTAL
d['smart_updated']='$(date -u +%Y-%m-%dT%H:%M:%SZ)'
with open('$ROOT_DIR/stats.json','w') as f: json.dump(d,f,indent=2)
print('stats.json diperbarui')
" 2>/dev/null || true
  fi
fi

head_log "RINGKASAN AKHIR"
echo ""
echo "   Pattern combinations  : $(wc -l < "$TMP/pattern_clean.txt" 2>/dev/null || echo 0)"
echo "   NRD filtered          : $(wc -l < "$TMP/nrd_filtered.txt" 2>/dev/null || echo 0)"
echo "   Crawler results       : $(sort -u "$TMP/crawl_result.txt" 2>/dev/null | wc -l || echo 0)"
echo "   Setelah scoring       : $SCORED_TOTAL"
echo -e "   ${W}FINAL (setelah whitelist): $FINAL_TOTAL domain${N}"
echo ""
ok "Smart blocklist selesai! 🎉"
