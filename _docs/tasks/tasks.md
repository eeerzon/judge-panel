# Tasks Log — KREEN Judge Panel Prototype

Log historis untuk prototype Judge Mode dan roadmap kelanjutan KREEN Judging. UX lima layar Judge tetap **frozen reference**; Phase 0 menambahkan perencanaan produk/arsitektur tanpa mengubah prototype. Jangan hapus riwayat lama.

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
| 0 | Product / Architecture Foundation | ✅ Selesai — menunggu review |
| 1 | Admin Design Foundation | ✅ Selesai — menunggu review |
| 2 | Admin Operational Core | ✅ Selesai — menunggu review |
| 3 | Multi-round Judge | ✅ Selesai — menunggu review |
| 4A | Master Data | ✅ Selesai — menunggu review |
| 4B | Round Configuration | ✅ Selesai — menunggu review |
| 4C | Governance + Operational Control | ✅ Implementasi prototype — menunggu visual review |
| 5 | Results + Finalization | ✅ Implementasi prototype — menunggu review visual |
| 6 | Advancement + Multi-Round Progression | ✅ Implementasi prototype — menunggu review visual |
| 7 | Flutter Handoff Specification | ✅ Dokumentasi handoff — menunggu review |
| 8 | Production Flutter / API | ⏸ Belum mulai — perlu approval dan reclassification docs |

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

### Judge Prototype Phase 6 — Multi-Page Refactor (historical numbering)
Pecah dari single `index.html` jadi 5 file di `pages/` + shared `localStorage` state (lihat ADR-001). Insiden: laporan bug "unstyled saat double-click" awalnya salah didiagnosis sebagai keterbatasan browser permanen → dipasang warning blocking → user menolak eksplisit → audit ulang menemukan codebase sudah `file://`-compatible sejak awal → warning dihapus (lihat ADR-002 untuk detail lengkap).

### Housekeeping
- Ditemukan & dibersihkan file duplikat basi (`app.js`/`styles.css` lama tertinggal di root `judge-prototype/` setelah refactor, sudah dicek identik dengan `_legacy-single-page/` sebelum dihapus).
- Repo GitHub private dibuat (`gh repo create --private`), commit awal 42 file.

### Phase 0 — Product / Architecture Foundation

Mendokumentasikan domain boundary multi-round, lifecycle Round dan Judge ScoreSheet, capability-based permission matrix, fairness gates, target system map, state ownership, API boundary, serta proposal MVP. Tidak ada perubahan HTML/CSS/JS prototype dan tidak ada Flutter/backend/API/database yang dibuat. Lihat `../product/` dan `../architecture/`.

### Phase 1 — Admin Design Foundation

Membuat area `judge-prototype/admin/` terpisah dengan Admin Shell/Overview dan halaman reference design system. Menambahkan `admin/admin.css` dan `admin/admin.js` agar resource tetap termuat saat dibuka langsung melalui Safari `file://`, untuk sidebar portrait, tabs, modal, drawer, toggle, serta overflow visual pattern. Tidak ada CRUD, state bisnis, persistence, API, atau perubahan pada lima layar Judge Mode.

### Phase 2 — Admin Operational Core

Menambahkan `rounds.html`, `round.html?id=…`, dan `monitoring.html?round=…` ke area Admin. Semua halaman memakai `admin/admin-data.js` sebagai satu sumber mock data round dan status judge. Monitoring hanya memperlihatkan status operasional/progress—tanpa nilai, total score, ranking, atau hasil. State daftar round Empty/Loading/Error tersedia melalui query `?state=empty`, `?state=loading`, dan `?state=error`; semuanya hanya demonstrasi lokal tanpa persistence. Keputusan close dengan judge belum submit, akses admin terhadap submission saat round terbuka, dan definisi offline yang perlu perhatian tetap belum diputuskan.

### Phase 3 — Multi-round Judge

Menambahkan `pages/my-rounds.html` sebagai entry point Judge Mode dan mengubah state prototype ke schema v2 yang scoped per round (`scoresByRound`, `notesByRound`, `submissionByRound`, `activeRoundId`). Judge pages menerima konteks `?round=…`, menggunakan contestant/criteria round-specific, dan menolak round invalid/unassigned dengan safe state. Preliminary tetap menjadi satu-satunya round assigned pada mock saat ini; Top 10 dan Final tersedia sebagai state Not Available/preview untuk membuktikan isolasi data. Preview mode tetap tersedia, migration state lama dipetakan ke Preliminary, dan Judge screen visual tidak dirombak.

## Implementation Roadmap

Roadmap ini adalah rencana bertahap. Phase berikutnya tidak dimulai tanpa review/approval eksplisit. Rule Result V1 telah disetujui untuk Phase 5; formula dan policy alternatif tetap ditunda.

### Phase 1 — Admin Design Foundation

- **Goal:** Menetapkan perluasan design system untuk Admin Mode tanpa mengubah Judge Mode frozen.
- **Dependencies:** Phase 0 approved; scope Admin MVP dikonfirmasi.
- **Deliverables:** Admin shell, sidebar/top-context pattern, round tabs, list/table/card, operational status, empty/loading/error patterns, dan responsive landscape/portrait spec.
- **Acceptance criteria:** Konsisten dengan token burgundy-gold existing; Admin lebih data-dense tanpa menjadi SaaS generic; Judge screens tidak berubah.
- **Out of scope:** Data persistence, auth, API, Results UI, Flutter.

### Phase 2 — Admin Operational Core

- **Goal:** Membuat referensi UI operasional pertama untuk admin.
- **Dependencies:** Phase 1 approved.
- **Deliverables:** Admin Shell, Event Overview, Rounds list, Round Overview, Live Monitoring berbasis status.
- **Acceptance criteria:** Status Round dan progress judge terbaca cepat; monitoring tidak menampilkan nilai tanpa permission context; responsive spec terpenuhi.
- **Out of scope:** Results calculation, real-time backend, assignment/criteria editor lengkap.

### Phase 3 — Multi-round Judge

- **Goal:** Menambahkan konteks multi-round tanpa merombak UX scoring.
- **Dependencies:** Phase 0/1 approved; model My Rounds reviewed.
- **Deliverables:** My Rounds, round-aware context untuk Judge flow, Submitted return to My Rounds, read-only submission detail.
- **Acceptance criteria:** Existing Judge flow tetap usable dan visualnya tidak regress; Judge tidak dapat mengakses round yang tidak assigned.
- **Out of scope:** Result visibility dan production auth.

### Phase 4 — Configuration

- **Goal:** Melengkapi konfigurasi event/round pada desain dan kemudian implementasi yang disetujui.
- **Dependencies:** Assignment/rubric rules reviewed.
- **Deliverables:** Contestant master + round participation, Judge master + assignment, Criteria/CriterionGroup configuration + weight validation.
- **Acceptance criteria:** Master data tidak diduplikasi per round; criteria efektif tervalidasi sebelum Open.
- **Out of scope:** Database schema final dan result rules.

### Phase 4B — Round Configuration

Membangun Round Contestants, Round Judges, dan Criteria Configuration memakai shared Admin Shell dan Round Workspace. Assignment tetap mereferensikan master event-level, konfigurasi terkunci pada round non-Draft, required judge readiness ditampilkan, dan effective scored weight divalidasi melalui helper domain tunggal. Reopen, Audit Log, Results, backend/API, dan Flutter tetap di luar scope.

### Phase 4C — Governance + Operational Control

- **Goal:** Mendemonstrasikan operasi onsite end-to-end sebagai prototype UX, bukan enforcement produksi.
- **Deliverables:** Admin Submission Detail, Reopen/Resubmit, Required/Optional readiness, Excused/Restore/Removed, Close Round, exception states, dan Audit Log preview lokal.
- **Acceptance criteria:** Required aktif menentukan Close; reason wajib untuk Reopen/Excused; Judge tidak self-reopen; Closed read-only; setiap governance action terlihat di audit preview; cross-mode demo berjalan lewat refresh.
- **Out of scope:** Results/ranking/finalize, backend/API, auth, production audit, device/session, Flutter.

### Phase 5 — Results + Finalization (implemented; awaiting review)

- **Goal:** Membangun hasil resmi hanya setelah rule bisnis disetujui.
- **Rule V1:** Combined = rata-rata total contestant dari Judge assigned + Required + Submitted/Resubmitted; Optional/Excused/Removed tidak dihitung. Tie dua desimal berbagi rank dan wajib diakui sebelum Finalize tanpa tie-break otomatis.
- **Deliverables:** Round Results, Result Detail, Global Results, snapshot Finalized, visibility OFF/ON, Judge Results read-only, audit preview, dan localStorage bridge.
- **Acceptance criteria:** Open tidak punya ranking; Closed menampilkan hasil provisional Admin; Finalized memakai snapshot; Judge hanya dapat melihat hasil saat Finalized + visibility ON + assigned.
- **Out of scope:** Advancement/Top N, backend/API, Flutter, production auth/result engine, dan koreksi pasca-Finalized.

### Phase 6 — Advancement + Multi-Round Progression

- **Goal:** Menghubungkan Preliminary → Top 10 → Final sebagai prototype UX end-to-end.
- **Deliverables:** Top-N selection, manual override/tie reason, preview/confirm, independent advancement record, target assignment, copy config opsional, Open target, Judge multi-round, reset/adjustment Draft, progression overview, audit preview.
- **Acceptance criteria:** Hasil source tidak berubah; target mengikuti pilihan terkonfirmasi; Judge roster/rubric/score sheet terisolasi; mekanisme Top 10 → Final memakai helper yang sama; Final tidak punya advancement.
- **Out of scope:** Backend/API, Flutter, carry-forward score, score lintas round, winner ceremony, production policy.

### Phase 7 — Flutter Handoff Specification (documentation only)

- **Goal:** Membekukan functional UX prototype sebagai acuan dan memetakan seluruh layar, komponen, state ownership, offline/sync, capability, API boundary, Results, dan Advancement untuk rebuild produksi.
- **Deliverables:** `_docs/flutter/` (handoff utama, screen inventory, widget map, local storage, sync, prototype mapping), `_docs/api/api-boundary.md`, dan register keputusan produksi.
- **Acceptance criteria:** Seluruh 24 halaman HTML + 2 placeholder terpetakan; batas server/local/UI jelas; submit idempotent dan conflict handling dijelaskan; keputusan produksi terbuka ditandai; tidak ada kode Flutter/backend baru.
- **UX status:** Functional UX prototype **FROZEN**; visual polish **REFERENCE QUALITY, NOT PIXEL-FINAL**.

### Phase 8 — Production Flutter / API (not started)

- **Goal:** Mengimplementasikan aplikasi produksi local-first dan backend authoritative.
- **Dependencies:** UX prototype approved/frozen, production architecture selected, docs upgraded to required production baseline.
- **Deliverables:** Flutter clients, local DB, sync queue, backend/API, auth, authorization, audit, testing/release plan.
- **Acceptance criteria:** Offline durability, idempotent submit, server enforcement, observability, and production quality gates verified.
- **Out of scope:** Tidak ada asumsi teknologi/vendor sebelum keputusan arsitektur eksplisit.

## Pekerjaan yang Eksplisit BELUM/TIDAK Dikerjakan (lihat `brd/brd-core.md` §Out of Scope)

- Result engine produksi, formula alternatif, dan advancement produksi (prototype UX Results/Advancement sudah dibuat pada Phase 5–6)
- Head Judge UI / production authorization for reopen-after-submit (prototype Admin reopen exists in Phase 4C)
- Backend/API/auth sungguhan
- Kode Flutter

## Cara Menambah Entri Baru

```
### Phase N — [Nama]
[Ringkasan apa yang dikerjakan]. [Revisi/keputusan penting kalau ada]. [Bug yang ditemukan & diperbaiki kalau ada].
```
