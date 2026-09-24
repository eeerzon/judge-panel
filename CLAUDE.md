# KREEN Judge Panel Prototype — King & Queen of the Pacific

**docs_tier: prototype-adjusted** (bukan Lapis 1 penuh 18-file, bukan Lapis 4 minimal — lihat `_docs/README.md` untuk justifikasi dan trigger reclassification wajib ke Lapis 1 saat project ini lanjut jadi aplikasi Flutter produksi.)

## Apa ini

Prototype HTML/CSS/JS multi-halaman untuk **KREEN Judge Panel** — aplikasi scoring juri berbasis tablet untuk pageant **King & Queen of the Pacific 2026**, ronde Preliminary. Tidak ada backend, tidak ada build step. Setiap halaman bisa dibuka langsung via double-click (`file://`) — lihat `_docs/architecture/system-overview.md`.

**Bukan** aplikasi produksi. Prototype ini adalah **UX reference yang dibekukan (frozen)** untuk acuan pembuatan aplikasi Flutter, dan sekarang dilanjutkan sebagai basis kerja di **Codex**.

## Prinsip Tidak Bisa Diganggu Gugat

1. **Desain/UX sudah frozen** — jangan redesign ulang tanpa instruksi eksplisit. Semua keputusan visual (dark burgundy theme, gold accent terbatas, status badge solid untuk "Scored") sudah melalui beberapa putaran review dan disetujui. Lihat `_docs/design/design-system.md` sebagai sumber kebenaran tunggal.
2. **Tidak ada fitur bisnis baru** tanpa instruksi eksplisit: no Result/Ranking engine, no Head Judge UI, no skor juri lain, no admin dashboard, no backend/API/auth sungguhan.
3. **Formula & status derivation cuma ada di satu tempat** (`assets/js/state.js`) — jangan duplikasi rumus total score atau logic status di halaman lain.
4. **File `file://`-compatible wajib dipertahankan**: tidak boleh ada ES module (`type="module"`, `import`/`export`), tidak boleh `fetch`/`XMLHttpRequest` untuk data lokal, tidak boleh path absolut (`/assets/...`). Semua load lewat `<script src>`/`<link>` relatif. Ini bukan preferensi gaya — ini requirement supaya prototype bisa dibuka double-click tanpa server.
5. **Push branch sendiri boleh, jangan push/merge ke `main`** kecuali diminta eksplisit.

## Prinsip Karpathy

- **Think Before Coding** — pahami dulu satu screen/flow secara utuh sebelum mengetik, terutama karena ini multi-page: perubahan di `assets/js/state.js` mempengaruhi 5 halaman sekaligus.
- **Simplicity First** — vanilla JS, tanpa framework/bundler/build step. Jangan tambahkan React/Vue/Tailwind CLI/npm hanya karena "lebih modern" — itu akan merusak requirement `file://` di atas.
- **Surgical Changes** — prototype ini sudah lolos banyak putaran QA visual (lihat `_docs/HANDOFF.md`). Ubah hanya bagian yang diminta, jangan refactor menyeluruh tanpa diminta.
- **Goal-Driven Execution** — tujuan akhir prototype ini adalah *acuan visual/interaksi yang bisa dibaca developer lain (termasuk Codex)*, bukan kode produksi. Prioritaskan kejelasan dokumentasi di atas elegansi kode.

Referensi: https://github.com/multica-ai/andrej-karpathy-skills

## Peta `_docs/`

| File | Isi |
|---|---|
| `_docs/README.md` | Index dokumentasi + penjelasan kenapa docs tier ini dipakai |
| `_docs/design/design-system.md` | **Paling penting** — token warna, tipografi, spacing, semua komponen UI, state, breakpoint untuk 5 layar Judge. Sumber kebenaran visual. |
| `_docs/design/admin-design-system.md` | Token/komponen visual khusus Admin workspace (prototype-only). |
| `_docs/brd/brd-core.md` | Tujuan, scope, out-of-scope, target user |
| `_docs/srs/fr-judging-flow.md` | Alur fungsional per layar Judge + business rules (formula skor, guard, validasi) |
| `_docs/srs/fr-admin-configuration.md` | Alur fungsional Admin (rounds, judges, rubric, monitoring, governance) |
| `_docs/srs/nfr.md` | Non-functional requirements: touch target, kontras, responsive, browser support |
| `_docs/architecture/system-overview.md` | Struktur file, state model, localStorage schema, page guards |
| `_docs/architecture/state-ownership.md` | Siapa (Judge/Admin/localStorage key) yang memiliki bagian state mana |
| `_docs/architecture/target-system-map.md` | Peta target arsitektur produksi (Flutter+backend), bukan implementasi |
| `_docs/architecture/api-boundary.md`, `_docs/api/api-boundary.md` | Dua dokumen boundary API pelengkap — enforcement principle vs. candidate resource/route; keduanya kontrak kandidat, bukan implementasi |
| `_docs/product/` | `mvp-scope.md`, `lifecycle.md`, `domain-model.md`, `permission-matrix.md`, `prototype-entry-flow.md` — model domain/lifecycle/permission yang jadi dasar Admin+multi-round |
| `_docs/decisions/` | ADR — kenapa multi-page+localStorage, kenapa harus `file://`-compatible, plus `production-decisions-pending.md` (keputusan bisnis yang belum disetujui) |
| `_docs/flutter/` | **Handoff Flutter** — `FLUTTER-IMPLEMENTATION-HANDOFF.md` (baca duluan), `screen-inventory.md`, `widget-map.md`, `local-storage.md`, `sync-strategy.md`, `prototype-mapping.md` |
| `_docs/referensi/coding-standards.md` | Aturan kode wajib (project rules) — paling sering dilanggar kalau tidak dibaca |
| `_docs/quality/definition-of-done.md` | Kriteria "selesai" untuk perubahan di prototype ini |
| `_docs/tasks/tasks.md` | Log fase kerja yang sudah selesai (Phase 1–7+) |
| `_docs/HANDOFF.md` | Handoff teknis detail (existing, jangan dihapus) |
| `_docs/PROTOTYPE-NOTES.md` | Batasan/simulasi yang tidak boleh dibawa ke produksi, termasuk catatan supersede untuk Admin/multi-round/Results (existing, jangan dihapus) |
