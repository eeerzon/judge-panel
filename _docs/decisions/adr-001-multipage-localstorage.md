# ADR-001: Multi-page HTML + localStorage (bukan single-page + JS memory)

**Status:** Accepted (Phase 6)

## Konteks

Prototype awal (Phase 1–5) dibangun sebagai **satu file `index.html`** dengan 5 `<main class="screen">` yang di-toggle lewat atribut `hidden`, state disimpan di array JS in-memory (`CONTESTANTS`) di dalam satu closure `app.js`. Ini bekerja baik untuk eksplorasi UX cepat, tapi punya kelemahan untuk tujuan **handoff ke developer lain**:

- Developer/client tidak bisa membuka satu screen spesifik langsung — harus klik-klik dari Standby dulu.
- Tim dev tidak bisa "review halaman Scoring saja" tanpa menjalankan seluruh flow.
- Semua kode (5 screen + semua logic) ada di 1 file besar (~1200 baris `app.js`, ~2300 baris CSS) — sulit dinavigasi untuk orang baru.

## Keputusan

Pecah jadi **5 file HTML terpisah** di `pages/`, masing-masing dokumen browser independen, dengan **shared state via `localStorage`** (bukan JS memory, karena JS memory tidak bertahan lintas-navigasi halaman sungguhan) dan **shared CSS/JS via file terpisah** yang di-load tiap halaman.

## Alternatif yang Dipertimbangkan

1. **Tetap single-page, tambah anchor/hash routing** (`#scoring`, `#review`) — ditolak karena tidak benar-benar memberi file terpisah yang bisa dibuka independen; developer masih harus load 1 file besar yang sama.
2. **Multi-page + sessionStorage** — ditolak karena `sessionStorage` tidak bertahan lintas-tab dan tidak ideal untuk skenario "buka halaman Scoring langsung dari Preview link" tanpa riwayat navigasi.
3. **Multi-page + query-string-encoded state** (seluruh state di URL) — ditolak, terlalu rumit untuk 15 kontestan × 5 kriteria dan tidak scalable.

## Konsekuensi

- **Positif:** setiap halaman bisa dibuka/direview independen (lihat ADR-002 untuk kenapa ini juga bisa tanpa server), state tetap konsisten lintas-halaman lewat `localStorage`, kode per-halaman lebih kecil dan fokus.
- **Negatif:** butuh disiplin baru — "shared memory" digantikan URL params (`?id=`, `&from=`) dan `localStorage`, developer baru harus paham pola ini sebelum menambah halaman baru (lihat `architecture/system-overview.md`).
- **Trade-off yang diterima sadar:** `localStorage` bukan sumber kebenaran yang cocok untuk produksi (lihat `PROTOTYPE-NOTES.md`) — ini keputusan **khusus prototype**, produksi Flutter harus pakai local database + backend sungguhan, bukan port `state.js` apa adanya.
