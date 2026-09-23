# Tasks Log — KREEN Judge Panel Prototype

Log historis (bukan intake tugas baru — prototype ini dianggap **frozen** per akhir Phase 6). Kalau ada pekerjaan baru, tambahkan entri baru di bawah dengan format yang sama, jangan hapus riwayat lama.

## Status Ringkas

| Fase | Nama | Status |
|---|---|---|
| 1 | Standby Screen | ✅ Selesai |
| 2 | Contestant Gallery | ✅ Selesai |
| 3 | Scoring Page | ✅ Selesai |
| 4 | Review & Submit | ✅ Selesai |
| 5 | Usability & Venue Polish (audit senior-friendly, dark-room, offline/failure states) | ✅ Selesai |
| 6 | Multi-page refactor (`file://`-compatible, localStorage, guard, preview mode) | ✅ Selesai |
| — | GitHub private repo (`laksa-devkreen/kreen-judge-prototype`) | ✅ Selesai |
| — | `_docs/` v5-adjusted (dokumen ini) | ✅ Selesai |

## Detail Per Fase

### Phase 1 — Standby Screen
Layar idle/screensaver, tap-to-start, logo event, judge identity, sync indicator. Revisi: serif → sans-serif (ditegaskan eksplisit "aplikasi operasional, bukan editorial").

### Phase 2 — Contestant Gallery
Grid foto 15 kontestan, filter All/To Score/Scored, status badge. Revisi besar: branding generic → King & Queen of the Pacific (palet burgundy-gold, logo asli klien), placeholder foto hue biru/teal → jewel-tone (ruby/gold/amethyst).

### Phase 3 — Scoring Page
Split layout identity+scoring, stepper `±0.25`, manual entry dengan validasi ketat (tidak silent-round), eksperimen quick-score (kesimpulan: KEEP terbatas di Confidence saja), Total Score block dengan formula weighted yang jadi satu-satunya sumber kebenaran (`calculateContestantTotal`).

### Phase 4 — Review & Submit
List ringkas + summary panel + modal konfirmasi + Submitted screen. Revisi besar: badge Scored di Review awalnya text-only → diubah jadi solid-fill sama seperti Gallery (konsistensi "status paling gampang dikenali"), struktur row diubah jadi grid 3-kolom tetap (Identity | Total Score | Action) supaya button width konsisten antar status.

### Phase 5 — Usability & Venue Polish
Audit senior-friendly + dark-room, ditemukan & diperbaiki 2 bug nyata (`[hidden]` vs `display` specificity di `.offline-banner` dan `.submitted-banner`). Ditambahkan: connection status simulasi (Online/Offline/Syncing/Synced), save/submit failure simulasi, standby inactivity timeout, dev panel "Prototype Controls", copy modal disederhanakan untuk user non-teknis.

### Phase 6 — Multi-Page Refactor
Pecah dari single `index.html` jadi 5 file di `pages/` + shared `localStorage` state (lihat ADR-001). Insiden: laporan bug "unstyled saat double-click" awalnya salah didiagnosis sebagai keterbatasan browser permanen → dipasang warning blocking → user menolak eksplisit → audit ulang menemukan codebase sudah `file://`-compatible sejak awal → warning dihapus (lihat ADR-002 untuk detail lengkap).

### Housekeeping
- Ditemukan & dibersihkan file duplikat basi (`app.js`/`styles.css` lama tertinggal di root `judge-prototype/` setelah refactor, sudah dicek identik dengan `_legacy-single-page/` sebelum dihapus).
- Repo GitHub private dibuat (`gh repo create --private`), commit awal 42 file.

## Pekerjaan yang Eksplisit BELUM/TIDAK Dikerjakan (lihat `brd/brd-core.md` §Out of Scope)

- Result/Ranking engine
- Head Judge UI / reopen-after-submit
- Backend/API/auth sungguhan
- Kode Flutter

## Cara Menambah Entri Baru

```
### Phase N — [Nama]
[Ringkasan apa yang dikerjakan]. [Revisi/keputusan penting kalau ada]. [Bug yang ditemukan & diperbaiki kalau ada].
```
