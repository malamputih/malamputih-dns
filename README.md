# 🛡️ MalamPutih DNS — Blocklist

<div align="center">

![MalamPutih DNS](https://img.shields.io/badge/MalamPutih-DNS-F5C400?style=for-the-badge&logo=shield&logoColor=black)
![Domains](https://img.shields.io/badge/dynamic/json?color=F5C400&label=Domain%20Diblokir&query=$.total&url=https://raw.githubusercontent.com/YOUR_USERNAME/malamputih-dns/main/stats.json&style=for-the-badge)
![Last Update](https://img.shields.io/github/last-commit/YOUR_USERNAME/malamputih-dns?color=F5C400&label=Update%20Terakhir&style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-F5C400?style=for-the-badge)

**DNS server gratis untuk memblokir judi online, iklan, pornografi, malware & tracker.**  
Terenkripsi penuh dengan DNS over TLS (DoT) & DNS over HTTPS (DoH).

[🌐 Website](https://dns.purnomoadi.web.id) • [📋 Laporkan Situs](#laporkan-situs) • [⚙️ Setup](#panduan-setup)

</div>

---

## 🌐 DNS Server Address

| Protokol | Alamat | Keterangan |
|---|---|---|
| **IPv4** | `43.157.240.28` | Standar, kompatibel semua perangkat |
| **DNS over TLS** | `dns.purnomoadi.web.id` | Terenkripsi |
| **DNS over HTTPS** | `dns.purnomoadi.web.id/dns-query` | Terenkripsi via HTTPS |

---

## ⚙️ Panduan Setup

### Android (Rekomendasi — DoT)
1. Settings → Network & Internet → Advanced → **Private DNS**
2. Pilih "Private DNS provider hostname"
3. Masukkan: `dns.purnomoadi.web.id`
4. Tap **Save**

### iOS
1. Settings → Wi-Fi → tap ikon **ⓘ** di jaringan aktif
2. Configure DNS → **Manual**
3. Tambahkan: `43.157.240.28`
4. Tap **Save**

### Windows
1. Control Panel → Network → Adapter Settings
2. Klik kanan → Properties → **TCP/IPv4** → Properties
3. Preferred DNS: `43.157.240.28`
4. Klik **OK**

### macOS
1. System Preferences → Network → Advanced → tab **DNS**
2. Klik **+** → masukkan `43.157.240.28`
3. Klik **OK** → **Apply**

### Router
1. Buka panel admin router (`192.168.1.1`)
2. Cari menu DNS / WAN / Internet
3. Primary DNS: `43.157.240.28`
4. Save & restart router

---

## 📋 Sumber Blocklist

Blocklist MalamPutih DNS dikompilasi dari sumber-sumber terpercaya berikut:

| Sumber | URL | Kategori |
|---|---|---|
| OISD Big | [big.oisd.nl](https://big.oisd.nl) | Umum (ads, tracking, malware) |
| Hagezi Pro | [hagezi/dns-blocklists](https://github.com/hagezi/dns-blocklists) | Multi-kategori |
| Hagezi TIF | [hagezi/dns-blocklists](https://github.com/hagezi/dns-blocklists) | Threat Intelligence |
| Hagezi Porn | [hagezi/dns-blocklists](https://github.com/hagezi/dns-blocklists) | Konten dewasa |
| Hagezi Gambling | [hagezi/dns-blocklists](https://github.com/hagezi/dns-blocklists) | Judi online |
| StevenBlack | [StevenBlack/hosts](https://github.com/StevenBlack/hosts) | Ads & malware |
| AdguardDNS | [firebog.net](https://v.firebog.net/hosts/AdguardDNS.txt) | Iklan |
| ABPIndo | [ABPindo](https://github.com/ABPindo/indonesianadblockrules) | Indonesia-specific |
| GoodbyeAds | [jerryn70/GoodbyeAds](https://github.com/jerryn70/GoodbyeAds) | Mobile ads |

Blocklist diperbarui otomatis setiap **24 jam** via GitHub Actions.

---

## 🚨 Laporkan Situs

### Situs Berbahaya Belum Diblokir
→ [Buat Issue: Block Request](../../issues/new?template=block-request.md&labels=block-request)

### Situs Legal Terblokir (False Positive)
→ [Buat Issue: Unblock Request](../../issues/new?template=false-positive.md&labels=false-positive)

---

## 🔧 Penggunaan Blocklist

Kamu bisa menggunakan blocklist ini langsung di DNS server kamu sendiri:

```
# Blocklist gabungan (semua kategori)
https://raw.githubusercontent.com/malamputih/malamputih-dns/main/domain/blocklist.txt

# Whitelist
https://raw.githubusercontent.com/malamputih/malamputih-dns/main/domain/whitelist.txt
```

### Technitium DNS Server
1. Buka Settings → Blocking
2. Tambahkan URL blocklist di atas
3. Set interval update: 24 jam

### Pi-hole
```bash
# Tambahkan ke /etc/pihole/adlists.conf
https://raw.githubusercontent.com/malamputih/malamputih-dns/main/domain/blocklist.txt
```

---

## 🔒 Kebijakan Privasi

- ❌ **Tidak menyimpan** query log
- ❌ **Tidak mencatat** IP address pengguna  
- ❌ **Tidak mengumpulkan** data personal apapun
- ✅ **DNSSEC** aktif untuk validasi keaslian DNS
- ✅ **DoT & DoH** untuk enkripsi query

---

## 🤝 Kontribusi

Kontribusi sangat disambut! Kamu bisa:

1. **Fork** repository ini
2. Tambahkan domain ke `domain/custom-blocklist.txt`
3. Buat **Pull Request** dengan deskripsi yang jelas
4. Atau langsung [buat Issue](../../issues/new)

---

## 📄 Lisensi

MIT License — bebas digunakan, dimodifikasi, dan didistribusikan.

---

<div align="center">
  
Dibuat oleh [MalamPutih DNS](https://dns.purnomoadi.web.id)  
untuk internet Indonesia yang lebih aman.

</div>
