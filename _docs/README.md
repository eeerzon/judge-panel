# _docs — KREEN Judge Panel Prototype

## Docs tier: Prototype-adjusted (bukan Lapis 1 penuh, bukan Lapis 4 minimal)

Standar dokumentasi normatif project ini adalah **v5** (Lapis 1 baseline = 18 file, berlaku untuk semua project berkode). Project ini **sengaja tidak** memenuhi Lapis 1 penuh karena statusnya masih **prototype visual/interaksi, bukan aplikasi produksi**:

- Tidak ada backend, tidak ada database sungguhan, tidak ada auth sungguhan.
- Tidak ada real user selain judge yang menguji UX secara internal.
- Tidak ada risiko keamanan/finansial/data pribadi produksi.

Tapi project ini **juga tidak masuk Lapis 4 (minimal `CLAUDE.md` + `brd-core.md`)** karena:

- Akan **dilanjutkan sebagai basis kerja di Codex** — agent lain butuh konteks desain & business rule yang lengkap tanpa harus reverse-engineer dari kode.
- Sudah melalui **6 fase kerja terstruktur** (lihat `tasks/tasks.md`) dengan banyak keputusan desain yang tidak boleh hilang.
- **Design system-nya besar dan sudah final** — kalau tidak didokumentasikan sekarang, siapapun yang melanjutkan (termasuk Codex) berisiko menebak-nebak token warna/spacing dari CSS mentah dan pelan-pelan merusak konsistensi visual yang sudah disetujui berkali-kali.

**Set file yang dipakai** (subset dari 18 file Lapis 1, dipilih berdasarkan relevansi ke prototype):

| Kategori Lapis 1 | Dipakai? | Alasan |
|---|---|---|
| `CLAUDE.md` | ✅ | Wajib selalu |
| `brd/brd-core.md` | ✅ (versi ringkas) | Konteks tujuan & scope |
| `srs/fr-*.md` | ✅ (1 file, `fr-judging-flow.md`) | Business rules sudah cukup padat di satu alur |
| `srs/nfr.md` | ✅ (versi ringkas) | Sudah dibahas detail di Phase 5 audit |
| `decisions/` + ADR | ✅ (2 ADR) | Keputusan arsitektur (multi-page+localStorage, `file://`-compatibility) butuh alasan tertulis |
| `architecture/system-overview.md` | ✅ | Wajib untuk siapapun yang lanjut kerja |
| `referensi/coding-standards.md` | ✅ | Aturan kode yang gampang dilanggar tanpa dibaca |
| `quality/definition-of-done.md` | ✅ (versi ringkas) | Supaya Codex tahu kapan berhenti |
| `tasks/tasks.md` | ✅ (log historis, bukan intake baru) | Rekam jejak 6 fase |
| `design/design-system.md` | ✅✅ **PALING LENGKAP** | Diminta eksplisit — inilah dokumen terpenting di set ini |
| `architecture/adr-*` full ADR set, `quality/test-strategy.md`, `quality/release-checklist.md`, `security/security-baseline.md`, `operations/*` | ❌ Tidak dibuat | Tidak relevan untuk prototype tanpa backend/deployment/data sensitif |

## ⚠️ Trigger reclassification wajib ke Lapis 1 penuh

Begitu SALAH SATU dari ini terjadi, **set dokumentasi ini harus di-upgrade ke Lapis 1 baseline penuh (18 file)** sebelum lanjut development:

1. Ada backend/API sungguhan yang dibangun (bukan simulasi `state.js`).
2. Ada data judge/kontestan sungguhan yang tersimpan (bukan mock data).
3. Aplikasi mulai dipakai di event pageant sungguhan (bukan demo internal).
4. Project berpindah ke Flutter/produksi.
5. Ada lebih dari 1 developer yang mengerjakan bersamaan.

## Index dokumen

- [`design/design-system.md`](design/design-system.md) — **Baca ini duluan.** Token warna, tipografi, spacing, komponen, state, breakpoint. Sumber kebenaran visual.
- [`brd/brd-core.md`](brd/brd-core.md) — Tujuan, scope, target user, out-of-scope.
- [`srs/fr-judging-flow.md`](srs/fr-judging-flow.md) — Alur fungsional 5 layar + business rules (formula skor, validasi, guard).
- [`srs/nfr.md`](srs/nfr.md) — Touch target, kontras dark-room, responsive breakpoint, browser support.
- [`architecture/system-overview.md`](architecture/system-overview.md) — Struktur file, state model, localStorage schema, page guards, navigation flow.
- [`decisions/README.md`](decisions/README.md) — Index ADR.
- [`referensi/coding-standards.md`](referensi/coding-standards.md) — Aturan kode wajib (project rules).
- [`quality/definition-of-done.md`](quality/definition-of-done.md) — Kriteria selesai untuk perubahan di prototype ini.
- [`tasks/tasks.md`](tasks/tasks.md) — Log 6 fase kerja yang sudah selesai.
- [`HANDOFF.md`](HANDOFF.md) — Handoff teknis detail per fase (existing, sangat lengkap, jangan dihapus).
- [`PROTOTYPE-NOTES.md`](PROTOTYPE-NOTES.md) — Apa yang disimulasikan vs nyata, jangan dibawa ke produksi (existing, jangan dihapus).

## Cara pakai untuk Codex

1. Baca `CLAUDE.md` (prinsip tidak bisa diganggu gugat).
2. Baca `design/design-system.md` sebelum menyentuh CSS/komponen apapun.
3. Baca `architecture/system-overview.md` sebelum menyentuh `state.js`/navigasi.
4. Baca `referensi/coding-standards.md` sebelum menulis JS baru.
5. Cek `decisions/` kalau mau mengubah pola arsitektur (multi-page, localStorage, `file://`-compatibility) — ada alasan kenapa itu dipilih.
