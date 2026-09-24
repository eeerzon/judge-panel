# Permission Matrix — KREEN Judging

## Model

Role adalah paket capability awal, bukan satu-satunya mekanisme authorization. Sistem target harus memeriksa capability pada aksi dan scope Event/Round terkait; jangan mengandalkan pola `role == admin`.

Role concepts:

- `super_admin` — otoritas penuh lintas event sesuai policy organisasi.
- `event_admin` — administrasi event yang ditugaskan.
- `head_judge` — pengawasan penjurian dalam scope yang ditugaskan.
- `judge` — menilai round yang ditugaskan.

Legenda: **✓** capability default; **—** tidak diberikan secara default; **P** perlu policy/assignment eksplisit sebelum diberikan.

| Capability | super_admin | event_admin | head_judge | judge |
|---|:---:|:---:|:---:|:---:|
| `manage_event` | ✓ | P | — | — |
| `manage_round` | ✓ | ✓ | P | — |
| `manage_contestants` | ✓ | ✓ | P | — |
| `manage_judges` | ✓ | ✓ | P | — |
| `manage_criteria` | ✓ | ✓ | P | — |
| `open_round` | ✓ | ✓ | P | — |
| `close_round` | ✓ | ✓ | P | — |
| `view_live_monitoring` | ✓ | ✓ | ✓ | — |
| `view_all_scores` | ✓ | P | P | — |
| `view_results` | ✓ | ✓ | P | P (only exposed when visibility gate passes) |
| `reopen_submission` | ✓ | P | ✓ | — |
| `finalize_results` | ✓ | P | P | — |
| `manage_result_visibility` | ✓ | ✓ | P | — |
| `manage_advancement` (umbrella; split below for sensitive actions) | ✓ | P | P | — |
| `confirm_advancement` | ✓ | P | P | — |
| `override_advancement` | ✓ | P | P | — |
| `reset_advancement` | ✓ | P | — | — |
| `manage_devices` | ✓ | P | — | — |
| `view_audit_log` | ✓ | P | P | — |
| `score_round` | — | — | P (only if also assigned Judge) | ✓ (assigned rounds only) |
| `submit_score_sheet` | — | — | P (only if also assigned Judge) | ✓ (own assigned sheet only) |

## Scope Rules

- Semua capability harus dievaluasi dalam scope Event dan, bila relevan, Round.
- `judge` tidak dapat membaca/mengubah ScoreSheet Judge lain, termasuk bila mengetahui identifier-nya.
- `view_results` untuk Judge tidak melewati fairness gate: Round harus `Finalized`, visibility harus aktif, dan Judge harus assigned pada Round itu. Halaman Judge tidak boleh mengekspos breakdown Judge lain.
- `view_live_monitoring` tidak otomatis berarti `view_all_scores`.
- Reopen memerlukan reason dan selalu membuat AuditLog.

## Deferred Policy Decisions

- Apakah Event Admin default boleh `view_all_scores` atau hanya Head Judge/Super Admin?
- Siapa yang boleh Close ketika tidak semua Judge submit?
- Siapa yang boleh Finalize dan apakah dual approval diperlukan?
- Scope Head Judge: seluruh event atau round tertentu?

Tidak ada code authorization yang dibangun pada Phase 0.

## Phase 4C Prototype Capability Notes

UI governance memodelkan `reopen_submission`, `manage_judges`, `close_round`, `view_all_scores`, dan `view_audit_log`. Super Admin dalam demo dapat melihat Submission Detail, memberi exception assignment, reopen dengan alasan, close berdasarkan required judge, dan membuka Audit Log preview. Ini hanya referensi visual/capability; tidak ada login, enforcement role produksi, actor identity tepercaya, atau audit persistence produksi.

## Phase 5 Prototype Capability Notes

Super Admin demo dapat melihat hasil provisional setelah Closed, mengakui tie, menjalankan `finalize_results`, lalu mengelola `manage_result_visibility`. Judge hanya mendapat hasil resmi ketika Finalized + visibility ON + assignment aktif. Guard browser/localStorage ini membuktikan alur UX, **bukan** batas keamanan; backend produksi harus mengotorisasi setiap request hasil dan tidak mengirim skor Judge lain ke klien Judge.

## Phase 6 Prototype Capability Notes

Super Admin demo dapat mengonfirmasi Top N, memilih manual dengan alasan, menyesuaikan target Draft karena withdrawal, meng-copy konfigurasi, membuka target, dan me-reset advancement selama target Draft. Capability produksi, kebutuhan second approval, serta kebijakan reset setelah Open belum diputuskan. LocalStorage dan audit preview bukan enforcement.
