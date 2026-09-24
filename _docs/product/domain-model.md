# Domain Model — KREEN Judging

## Purpose

Dokumen ini menetapkan **domain boundary** untuk target KREEN Judging App. Ini bukan database schema, API contract final, atau instruksi membangun backend. Tujuannya adalah menjaga perluasan dari prototype satu judge/satu round menjadi sistem multi-round tanpa menduplikasi data master atau mengaburkan ownership.

## Prinsip Struktur

```text
Event
├── Contestant Master
├── Judge Master
├── Branding / Settings
└── Round
    ├── RoundContestant
    ├── RoundJudgeAssignment
    ├── CriterionGroup / Criterion
    ├── ScoreSheet / Score
    ├── Submission / Reopen
    └── Result
```

- `Contestant` dan `Judge` adalah master tingkat Event. Mereka **tidak** diduplikasi untuk setiap round.
- Round menentukan siapa yang ikut, siapa yang menilai, dan rubric apa yang berlaku.
- Score selalu memiliki konteks `event + round + judge + contestant + criterion`.
- Backend target production adalah sumber data otoritatif. Local database Flutter nantinya hanya salinan kerja offline.

## Entity Boundaries

| Entity | Purpose & ownership | Relationship | Lifecycle relevance | Target source of truth |
|---|---|---|---|---|
| Event | Wadah operasional satu pageant/event; dimiliki Super Admin/Event Admin. | Memiliki contestant/judge master dan rounds. | Menjadi konteks untuk branding, timezone, dan policy. | Backend |
| Round | Unit penjurian yang berdiri sendiri; dimiliki Event. | Memiliki participation, assignment, criteria, sheets, result. | `Draft → Open → Closed → Finalized`. | Backend |
| Contestant | Identitas kontestan master pada Event. | Diikutkan ke round lewat `RoundContestant`. | Active/inactive event-level; tidak menentukan eligibility round sendiri. | Backend |
| RoundContestant | Keikutsertaan dan urutan tampil contestant dalam sebuah Round. | Menghubungkan Round dan Contestant. | Dapat ditambah/diubah hanya pada status round yang diizinkan. | Backend |
| Judge | Identitas juri master pada Event. | Ditugaskan ke round lewat `RoundJudgeAssignment`; memiliki session. | Active/inactive event-level. | Backend |
| RoundJudgeAssignment | Penugasan judge untuk satu Round, termasuk required/display order. | Menghubungkan Round dan Judge; menghasilkan satu ScoreSheet per judge/round. | Assignment harus stabil saat Open kecuali prosedur berwenang. | Backend |
| CriterionGroup | Kelompok presentasi rubric, misalnya Interview. | Milik satu Round dan menaungi Criterion. | Konfigurasi hanya sebelum/selama status yang diizinkan. | Backend |
| Criterion | Unit nilai; memuat label, bobot, min/max/step, required, urutan. | Milik Round, opsional berada pada CriterionGroup; direferensikan Score. | Rubric yang dipakai ScoreSheet harus tidak berubah ketika judging sudah mulai tanpa prosedur migrasi eksplisit. | Backend |
| ScoreSheet | Kumpulan score satu Judge untuk satu Round. | Memiliki Score per RoundContestant × Criterion dan Submission state. | `Not Started → In Progress → Submitted → Reopened → Resubmitted`. | Backend; local DB sebagai working copy offline |
| Score | Nilai dan catatan untuk satu criterion seorang contestant pada ScoreSheet. | Terkait ScoreSheet, RoundContestant, Criterion. | Menentukan status contestant `Not Scored/Draft/Scored` secara derived. | Backend; local DB sebagai working copy offline |
| Submission | Rekam submit score sheet termasuk timestamp/idempotency acknowledgement. | Satu ScoreSheet dapat memiliki riwayat submission. | Menandai lock dari sisi judge setelah server mengonfirmasi. | Backend |
| Reopen | Rekam keputusan berwenang untuk membuka ulang submission, lengkap dengan alasan. | Terkait ScoreSheet, actor yang reopen, dan Submission sebelumnya. | Menjadikan ScoreSheet editable kembali hingga resubmit. | Backend + AuditLog |
| Result | Hasil agregat resmi per Round dan contestant. | Dibentuk dari total per-contestant milik Judge yang eligible. | Provisional setelah Closed; snapshot resmi terkunci saat Finalized. | Backend |
| AuditLog | Jejak tindakan sensitif dan perubahan konfigurasi. | Merekam actor, entity, action, timestamp, context. | Wajib untuk submit, reopen, close/finalize, assignment, dan visibility. | Backend append-only policy |
| DeviceSession | Identitas/pairing sesi perangkat dan aktivitasnya. | Terhubung ke judge atau admin session sesuai kebijakan auth. | Dapat revoked/unlinked; mendukung last seen dan monitoring. | Backend; local device identity sebagai cache terbatas |

## Derived Concepts (Bukan Entity Tersendiri)

### Status contestant pada score sheet

Status ini harus dihitung dari Score yang required, bukan disimpan sebagai field yang dapat menyimpang.

| Kondisi nilai required | Status |
|---|---|
| Belum ada nilai | `not_started` / Not Scored |
| Sebagian terisi | `draft` |
| Semua terisi valid | `scored` |

### Total pribadi judge

Total satu contestant pada satu ScoreSheet dihitung dari Criterion yang berlaku untuk Round itu. Rumus dan representasi total belum boleh diasumsikan identik untuk setiap Round; konfigurasi Round adalah sumber rubric.

## Phase 5 — Result V1

- Judge eligible jika assignment pada round masih `assigned`, `required=true`, bukan Excused/Removed, dan submission `Submitted`/`Resubmitted`. Optional tidak ikut hasil resmi meski pernah submit. Riwayatnya tetap dapat dibaca Admin.
- Combined Score = rata-rata aritmetika **total contestant per eligible Judge** (skala 0–100), dibulatkan ke dua desimal. Tidak merata-ratakan skor criterion lintas Judge.
- Official ranking hanya tersedia saat round `Closed` dan seluruh required aktif sudah submit. Sebelum Finalized, ini adalah Provisional Admin Result; Judge tidak melihatnya.
- Urutan adalah combined score menurun, lalu nomor contestant menaik hanya demi tampilan stabil. Nilai sama pada presisi dua desimal mendapat rank bersama dan label TIED; nomor contestant bukan tie-break. Finalize mensyaratkan acknowledgement tie, tanpa mengubah rank atau skor.
- Finalize menyimpan snapshot lokal berisi waktu, aktor, eligible Judge IDs, item/rank/combined score dan breakdown. Saat `Finalized`, seluruh tampilan hasil resmi membaca snapshot, bukan menghitung ulang. Visibility Judge adalah state terpisah, default OFF, dan baru dapat dinyalakan setelah Finalized.
- Prototype memakai `kreenAdminConfiguration` di localStorage. Ini hanya model UX; backend produksi harus menghitung, menyimpan snapshot immutable, mengotorisasi akses, dan membuat audit append-only secara otoritatif.

## Boundary terhadap Prototype Existing

Prototype sekarang memodelkan satu `event`, satu `judge`, satu `round`, 15 contestant, dan satu score blob di `localStorage`. Struktur tersebut tetap valid sebagai UX reference untuk **satu ScoreSheet**, tetapi tidak cukup untuk model di atas. Tidak ada perubahan kode prototype dalam Phase 0.

## Non-Goals

- Tidak menentukan tabel/kolom database atau jenis ID.
- Tidak menentukan endpoint API.
- Tidak menentukan rumus alternatif di luar Result V1 atau arsitektur result engine produksi.
- Tidak mengimplementasikan entity atau persistence.

## Phase 4 Configuration Addendum

Contestant dan Judge adalah event-level master. Round hanya menyimpan participation/assignment melalui `RoundContestant` dan `RoundJudgeAssignment`; assignment Judge memiliki `required`. Criteria adalah konfigurasi per round dengan parent/group satu level dan effective scored weight sebagai derived value. Reopen history menyimpan `judgeId`, `roundId`, reason, timestamp, dan actor.

## Phase 4B Configuration Rules

- `RoundContestant` mereferensikan contestant master dan tidak menyalin identity, nomor event, atau foto. Assignment dapat berubah hanya saat Round berstatus `Draft`.
- `RoundJudgeAssignment` menyimpan `judgeId`, `roundId`, `required`, dan `assignmentStatus`. Judge master tetap menjadi sumber identity/contact; assignment menjadi sumber readiness round.
- Criteria mendukung satu parent/group level. Parent non-scored tidak ikut menjumlahkan bobot; hanya criterion dengan `isScored: true` masuk ke effective scored weight.
- Effective scored weight dihitung melalui satu helper domain dan harus bernilai 100% sebelum konfigurasi dianggap valid.
- Round `Open`, `Closed`, dan `Finalized` menampilkan konfigurasi sebagai read-only. UI lock adalah guard presentasi prototype; enforcement production tetap menjadi tanggung jawab backend.

## Deferred Result Decisions

Aggregation formula configurable, automatic tie-break, inclusion policy untuk Optional Judge, reopen setelah Closed, koreksi setelah Finalized, result versioning, dan manual rank override belum ditetapkan. Tidak ada advancement/Top N progression pada Phase 5.

## Phase 6 — Advancement

`Advancement` adalah keputusan terpisah dari `Result` resmi. Record prototype berisi `sourceRoundId`, `targetRoundId`, contestant IDs terpilih, identitas snapshot hasil sumber, metode `top_n`/`manual`, alasan, aktor, waktu, dan riwayat penyesuaian. Konfirmasi hanya boleh dari Result Finalized menuju round berikutnya menurut `order`, selama target masih Draft.

Default adalah Top N menurut urutan snapshot; Admin harus meninjau, preview, lalu konfirmasi. Perbedaan dari default atau tie tepat di cutoff membutuhkan alasan. Advancement tidak mengubah rank/skor/snapshot sumber. Target hanya menyimpan ID contestant event-level, bukan salinan master.

`advancementCount` milik source round: Preliminary 10, Top 10 5, Final `null`. Judge assignments dan criteria tetap milik target round; copy konfigurasi opsional membuat salinan independen. `carryForwardScores = false`: setiap round punya score sheet dan hasil sendiri, tanpa agregat lintas round. Reset advancement hanya saat target Draft, dengan alasan dan history; setelah Open tidak ada reset biasa.

### DECISION REQUIRED sebelum produksi

Manual override boleh atau tidak; capability/role pemberi override; apakah alasan cukup atau perlu persetujuan kedua; representasi formal withdrawal; perubahan target count setelah Finalized; reset setelah target Open; apakah seluruh peserta tied di cutoff maju; kebijakan score carry-forward; progression bercabang; dan peserta yang melewati round belum diputuskan. Aturan Phase 6 hanya kebijakan UX prototype.
