# NFR — KREEN Judge Panel Prototype

Versi ringkas — fokus ke NFR yang benar-benar relevan untuk prototype visual/interaksi (bukan template lengkap Performance/Security/Scalability produksi, karena tidak ada backend/beban sungguhan di sini).

## Usability (paling kritis untuk prototype ini)

- **Touch target minimum 48px**, preferred 56–64px untuk kontrol scoring utama. Lihat `design/design-system.md` §4 untuk tabel lengkap per komponen.
- **Tidak ada aksi penting icon-only** — semua tombol punya label teks.
- **Font minimum**: body 16px, instruksi utama 20–24px. Tidak ada teks di bawah 11px kecuali dev-panel (yang memang bukan konten juri).
- **Senior-friendly**: target user 40–60+, first-time-use tanpa training. Diuji lewat pertanyaan checklist di `brd/brd-core.md` §Kondisi Sukses.
- **Mistake prevention**: skor kosong tidak pernah dianggap nol, input invalid tidak pernah silent-round, tidak ada aksi destruktif satu-tap (submit selalu lewat modal konfirmasi).

## Dark-Room / Kontras

- Tidak ada area putih besar di manapun — background dasar `#12090A`, bukan hitam pekat, bukan abu netral terang.
- Gold accent dipakai terbatas (label, nomor, border aktif) — tidak boleh jadi warna dominan yang menyilaukan di ruangan gelap.
- Status "Scored" sengaja **satu-satunya** yang solid fill terang — supaya kontras tapi tidak ada elemen lain yang bersaing menyilaukan.
- Foto kontestan boleh terang (berasal dari materi asli klien) — itu wajar karena mata juri memang harus fokus ke foto, bukan ke chrome UI di sekitarnya.
- Teks sekunder (`--text-secondary` `#B8A89B`) tetap harus terbaca di atas `--bg-base`/`--surface` — jangan diturunkan opacity lebih jauh demi "kelihatan subtle", itu prinsip yang sudah ditegaskan eksplisit di Phase 5 audit (kontras jangan dikorbankan demi estetika).

## Responsive

**Breakpoint acuan yang wajib diverifikasi untuk setiap perubahan visual:**

| Viewport | Device | Prioritas |
|---|---|---|
| 1280×800 | Tablet Android landscape | **Utama** |
| 1440×900 | Laptop | Sekunder |
| 1920×1080 | Desktop | Sekunder |
| 800×1280 | Tablet portrait | Sekunder |

Tidak boleh ada horizontal overflow di breakpoint manapun. Grid kontestan menyesuaikan kolom (§8 di design-system.md), bukan mengecilkan kartu di bawah ukuran nyaman sentuh.

**Orientasi:** landscape adalah target utama untuk produksi Flutter nanti, tapi prototype ini tidak boleh hard-lock orientasi — portrait tetap harus berfungsi penuh (fallback), keputusan hard-lock ditunda sampai diuji di device fisik sungguhan.

## Browser & Platform Compatibility

- **Wajib berjalan tanpa server** — dibuka langsung via `file://` (double-click), di Chrome maupun Safari macOS. Lihat `decisions/adr-002-file-protocol-compatibility.md` untuk audit lengkap kenapa ini bisa tercapai (tidak ada ES module, tidak ada `fetch`, semua path relatif).
- `localStorage` dipakai untuk state antar-halaman — behaviornya **belum diverifikasi identik** di semua kombinasi browser/mode (private browsing Safari punya riwayat membatasi storage untuk `file://`). Prototype harus tetap **tidak crash** kalau localStorage tidak tersedia — `state.js` sudah membungkus semua akses storage dengan `try/catch` dan fallback ke default state.
- Tidak ada dependency eksternal (CDN, npm package, framework) — semua vanilla JS/CSS supaya tidak ada kegagalan load dari internet.

## Reliability (skala prototype)

- Setiap halaman independen — kegagalan load satu halaman tidak merusak halaman lain (tidak ada shared runtime state selain localStorage).
- Autosave disimulasikan (`Saving…` → `Saved ✓`/`Unable to save`) — bukan jaminan sungguhan, murni untuk menguji *desain* state ini sebelum Flutter membangun versi nyata (lihat `PROTOTYPE-NOTES.md`).

## Yang SENGAJA Tidak Dicakup di Sini

Performance budget, security threat model, data retention, scalability, uptime — semua ini tidak relevan untuk prototype tanpa backend/data sungguhan. **Wajib ditambahkan** kalau project ini naik status ke Lapis 1 penuh (lihat trigger reclassification di `_docs/README.md`).
