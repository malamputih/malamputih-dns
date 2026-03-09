# Scripts

## update.sh
Update blocklist utama dari 9 sumber eksternal.
```bash
bash scripts/update.sh
bash scripts/update.sh --dry-run
```

## smart-blocklist.sh
Generator cerdas dengan 3 metode + scoring:
```bash
bash scripts/smart-blocklist.sh           # semua metode
bash scripts/smart-blocklist.sh --pattern # pattern TLD saja
bash scripts/smart-blocklist.sh --nrd     # NRD saja
bash scripts/smart-blocklist.sh --crawl   # crawler saja
bash scripts/smart-blocklist.sh --dry-run # tidak tulis file
```

## Bagaimana scoring bekerja?

Setiap domain diberi skor 0-200:
- **Keyword judi** → +25 hingga +95 (tergantung spesifisitas)
- **TLD berisiko** → +10 hingga +70
- **Pola struktural** → +10 hingga +35 (angka di belakang, banyak tanda hubung, dll)

Domain dengan skor **≥ 70** masuk blocklist.

Contoh:
| Domain | Keyword | TLD | Struktural | Total | Blokir? |
|---|---|---|---|---|---|
| `togel88.xyz` | togel=90 | xyz=40 | angka=20 | **150** | ✅ |
| `slot.online` | slot=50 | online=35 | - | **85** | ✅ |
| `slotmachine.com` | slot=50 | com=0 | - | **50** | ❌ |
| `timetracker.xyz` | - | xyz=40 | - | **40** | ❌ |
