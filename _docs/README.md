# _docs — KREEN Judge Panel Prototype

## Status handoff saat ini

Phase 7 menghasilkan spesifikasi untuk rebuild Flutter/backend, **tanpa mengimplementasikannya**. **FUNCTIONAL UX PROTOTYPE: FROZEN. VISUAL POLISH: REFERENCE QUALITY, NOT PIXEL-FINAL.** Mulai dari [`flutter/FLUTTER-IMPLEMENTATION-HANDOFF.md`](flutter/FLUTTER-IMPLEMENTATION-HANDOFF.md); keputusan produksi yang masih terbuka ada di [`decisions/production-decisions-pending.md`](decisions/production-decisions-pending.md). Dokumen HTML/JS lama adalah riwayat dan referensi UX, bukan rancangan arsitektur produksi.

## Docs tier: Prototype-adjusted (bukan Lapis 1 penuh, bukan Lapis 4 minimal)

Standar dokumentasi normatif project ini adalah **v5** (Lapis 1 baseline = 18 file, berlaku untuk semua project berkode). Project ini **sengaja tidak** memenuhi Lapis 1 penuh karena statusnya masih **prototype visual/interaksi, bukan aplikasi produksi**:

- Tidak ada backend, tidak ada database sungguhan, tidak ada auth sungguhan.
- Tidak ada real user selain judge yang menguji UX secara internal.
- Tidak ada risiko keamanan/finansial/data pribadi produksi.

Tapi project ini **juga tidak masuk Lapis 4 (minimal `CLAUDE.md` + `brd-core.md`)** karena:

- Akan **dilanjutkan sebagai basis kerja di Codex** — agent lain butuh konteks desain & business rule yang lengkap tanpa harus reverse-engineer dari kode.
- Sudah melalui fase prototype Judge/Admin terstruktur (lihat `tasks/tasks.md`) dengan banyak keputusan desain yang tidak boleh hilang.
- **Design system-nya besar dan sudah final** — kalau tidak didokumentasikan sekarang, siapapun yang melanjutkan (termasuk Codex) berisiko menebak-nebak token warna/spacing dari CSS mentah dan pelan-pelan merusak konsistensi visual yang sudah disetujui berkali-kali.

**Set file yang dipakai** (subset dari 18 file Lapis 1, dipilih berdasarkan relevansi ke prototype):

| Kategori Lapis 1 | Dipakai? | Alasan |
|---|---|---|
| `CLAUDE.md` | ✅ | Wajib selalu |
| `brd/brd-core.md` | ✅ (versi ringkas) | Konteks tujuan & scope |
| `srs/fr-*.md` | ✅ (`fr-judging-flow.md` dan `fr-admin-configuration.md`) | Alur Judge dan Admin prototype |
| `srs/nfr.md` | ✅ (versi ringkas) | Sudah dibahas detail di Phase 5 audit |
| `decisions/` + ADR | ✅ (2 ADR) | Keputusan arsitektur (multi-page+localStorage, `file://`-compatibility) butuh alasan tertulis |
| `architecture/system-overview.md` | ✅ | Wajib untuk siapapun yang lanjut kerja |
| `referensi/coding-standards.md` | ✅ | Aturan kode yang gampang dilanggar tanpa dibaca |
| `quality/definition-of-done.md` | ✅ (versi ringkas) | Supaya Codex tahu kapan berhenti |
| `tasks/tasks.md` | ✅ (log historis, bukan intake baru) | Rekam jejak Judge prototype dan Admin Phase 0–7 |
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
- [`design/admin-design-system.md`](design/admin-design-system.md) — Admin Mode foundation dan Phase 2 operational patterns; memperluas visual language tanpa mengubah Judge Mode frozen.
- [`brd/brd-core.md`](brd/brd-core.md) — Tujuan, scope, target user, out-of-scope.
- [`srs/fr-judging-flow.md`](srs/fr-judging-flow.md) — Alur fungsional 5 layar + business rules (formula skor, validasi, guard).
- [`srs/nfr.md`](srs/nfr.md) — Touch target, kontras dark-room, responsive breakpoint, browser support.
- [`architecture/system-overview.md`](architecture/system-overview.md) — Struktur file, state model, localStorage schema, page guards, navigation flow.
- [`decisions/README.md`](decisions/README.md) — Index ADR.
- [`referensi/coding-standards.md`](referensi/coding-standards.md) — Aturan kode wajib (project rules).
- [`quality/definition-of-done.md`](quality/definition-of-done.md) — Kriteria selesai untuk perubahan di prototype ini.
- [`tasks/tasks.md`](tasks/tasks.md) — Log 6 fase kerja yang sudah selesai.
- [`flutter/FLUTTER-IMPLEMENTATION-HANDOFF.md`](flutter/FLUTTER-IMPLEMENTATION-HANDOFF.md) — Handoff utama Flutter/backend dan urutan implementasi yang diusulkan.
- [`flutter/screen-inventory.md`](flutter/screen-inventory.md) — 24 halaman HTML + 2 placeholder, state dan navigation level.
- [`flutter/widget-map.md`](flutter/widget-map.md) — Komponen Flutter reusable dan tanggung jawabnya.
- [`flutter/local-storage.md`](flutter/local-storage.md) — Kepemilikan state dan penyimpanan Judge offline yang durable.
- [`flutter/sync-strategy.md`](flutter/sync-strategy.md) — Bootstrap, queue, retry, conflict, dan submit idempotent.
- [`flutter/prototype-mapping.md`](flutter/prototype-mapping.md) — Pemetaan setiap halaman HTML ke layar/data/action Flutter.
- [`api/api-boundary.md`](api/api-boundary.md) — API domain/candidate routes; bukan kontrak final atau implementasi.
- [`decisions/production-decisions-pending.md`](decisions/production-decisions-pending.md) — Register policy/architecture yang masih perlu approval.
- [`HANDOFF.md`](HANDOFF.md) — Handoff teknis detail per fase (existing, sangat lengkap, jangan dihapus).
- [`PROTOTYPE-NOTES.md`](PROTOTYPE-NOTES.md) — Apa yang disimulasikan vs nyata, jangan dibawa ke produksi (existing, jangan dihapus).

### Phase 0 — Product / Architecture Foundation

Dokumen berikut mendefinisikan target KREEN Judging multi-round. Dokumen ini adalah planning boundary; tidak mengubah UX frozen prototype atau berarti Flutter/backend telah dibangun.

- [`product/domain-model.md`](product/domain-model.md) — Entity boundary Event, Round, assignment, scoring, audit, dan device session.
- [`product/lifecycle.md`](product/lifecycle.md) — State machine Round dan Judge ScoreSheet, termasuk fairness gates.
- [`product/permission-matrix.md`](product/permission-matrix.md) — Role concepts dan capability matrix awal.
- [`product/mvp-scope.md`](product/mvp-scope.md) — Proposal MVP, deferred Results, dan decision required.
- [`product/prototype-entry-flow.md`](product/prototype-entry-flow.md) — Login lokal, fixture akun/capability, mode selector, switch, logout, dan batasan prototipe.
- [`architecture/target-system-map.md`](architecture/target-system-map.md) — Target dual-mode product/system map dan mapping dari prototype.
- [`architecture/state-ownership.md`](architecture/state-ownership.md) — Backend/local DB/UI responsibility dan derived state rules.
- [`architecture/api-boundary.md`](architecture/api-boundary.md) — Boundary enforcement API target tanpa mendesain endpoint.
- [`tasks/tasks.md`](tasks/tasks.md) — Roadmap prototype Phase 0–7 dan status pekerjaan produksi berikutnya.

## Cara pakai untuk Codex

1. Baca `CLAUDE.md` (prinsip tidak bisa diganggu gugat).
2. Baca `design/design-system.md` sebelum menyentuh CSS/komponen apapun.
3. Baca `architecture/system-overview.md` sebelum menyentuh `state.js`/navigasi.
4. Baca `referensi/coding-standards.md` sebelum menulis JS baru.
5. Cek `decisions/` kalau mau mengubah pola arsitektur (multi-page, localStorage, `file://`-compatibility) — ada alasan kenapa itu dipilih.
