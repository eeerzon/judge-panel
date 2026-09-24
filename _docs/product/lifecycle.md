# Lifecycle — Round dan Judge Submission

## Principle

Lifecycle Round dan lifecycle ScoreSheet seorang Judge adalah dua state machine terpisah. Round mengatur operasi event; ScoreSheet mengatur pekerjaan dan lock penilaian individu. UI maupun backend tidak boleh menyamakan keduanya.

## Round Lifecycle

```text
Draft → Open → Closed → Finalized
```

| State | Meaning | Allowed mutations | Not allowed |
|---|---|---|---|
| Draft | Konfigurasi sedang disiapkan, belum ada judging. | Nama/order, participant, judge assignment, criteria, settings. | Score/submit judge, results visibility untuk judge. |
| Open | Judging aktif bagi judge yang assigned. | Operasional terbatas dan monitoring; perubahan konfigurasi hanya lewat prosedur khusus yang belum ditentukan. | Close tanpa capability, Judge melihat combined result/ranking, Finalize langsung. |
| Closed | Input baru terkunci; hasil provisional dapat direview Admin. | Review hasil dan Finalize jika guard lolos. | Judging baru, reopen, visibility Judge, perubahan rubric/participant. |
| Finalized | Hasil resmi terkunci pada snapshot. | Read-only; Admin dapat mengubah visibility hasil untuk Judge. | Mutasi score/criteria/result, reopen, dan exception biasa. |

### Allowed transitions

| Transition | Authorized capability/role concept | Preconditions |
|---|---|---|
| Draft → Open | `open_round`; Super Admin/Event Admin sesuai policy | Participants, assignments, and criteria valid; effective required scoring weight = 100%; unresolved configuration errors = 0. |
| Open → Closed | `close_round`; Super Admin/Event Admin/Head Judge sesuai policy | Prototype: semua judge aktif yang `required` harus Submitted/Resubmitted; optional dan Excused tidak memblokir. Kebijakan produksi tetap perlu persetujuan. |
| Closed → Finalized | `finalize_results`; Super Admin pada prototype | Result tersedia, semua Required aktif terhitung, dan setiap tie telah diakui secara eksplisit. Konfirmasi menyimpan snapshot. |

### Invalid transitions

- Draft → Closed/Finalized tanpa membuka round.
- Open → Finalized tanpa melalui Closed.
- Finalized → Open/Closed dalam MVP tanpa prosedur exception yang terdokumentasi dan diaudit.
- Mengubah criteria yang sudah dipakai score sheet tanpa migrasi/versioning rule yang disetujui.

## Judge ScoreSheet Lifecycle

```text
Not Started → In Progress → Submitted → Reopened → Resubmitted
```

| State | Meaning | Judge can do | Authorized admin/head judge can do |
|---|---|---|---|
| Not Started | Belum ada score tersimpan. | Mulai scoring jika Round Open dan assignment aktif. | Monitor status. |
| In Progress | Ada draft score, belum submit. | Edit score/note, review, submit jika lengkap. | Monitor status; tidak melihat score tanpa `view_all_scores`. |
| Submitted | Backend mengonfirmasi submit; sheet locked bagi judge. | Read-only view. | Monitor; reopen jika memiliki capability. |
| Reopened | Submission resmi dibuka kembali dengan alasan. | Edit dan submit ulang jika Round/policy mengizinkan. | Memantau dan mencatat alasan reopen. |
| Resubmitted | Submit setelah Reopened telah dikonfirmasi backend. | Read-only view. | Reopen lagi hanya melalui policy yang sama. |

### Derived transitions

- `Not Started → In Progress`: score valid pertama tersimpan ke working copy.
- `In Progress → Submitted`: semua required score lengkap dan backend mengonfirmasi submit idempotently.
- `Submitted/Resubmitted → Reopened`: actor dengan `reopen_submission` memberikan alasan; tindakan masuk AuditLog.
- `Reopened → Resubmitted`: score sheet kembali lengkap dan submit dikonfirmasi backend.

### Invalid transitions

- Submit sheet yang tidak lengkap.
- Mengedit sheet Submitted/Resubmitted tanpa Reopen.
- Judge membuka ulang submission miliknya sendiri.
- Reopen tanpa reason dan audit record.
- Membiarkan UI lokal menyatakan Submitted tanpa acknowledgement authoritative dari backend pada aplikasi produksi.

## Fairness and Visibility Gates

- Ketika Round `Open`, combined score/ranking tidak boleh diberikan ke Judge.
- Judge tidak boleh melihat score Judge lain pada state apa pun.
- Hasil Judge hanya tersedia jika Round `Finalized`, visibility ON, dan Judge masih assigned pada round tersebut.
- Gates ini harus diberlakukan backend, bukan hanya disembunyikan dari UI.

## Result Lifecycle (terpisah dari Round)

```text
Unavailable → Provisional Admin Result → Finalized Official Result
                                      Judge visibility: Hidden → Visible (dapat OFF lagi)
```

- Saat Open, tidak ada ranking Admin atau Judge. Saat Closed dan seluruh Required aktif Submitted/Resubmitted, Admin dapat melihat hasil provisional. Formula dapat dihitung ulang sebelum Finalized, walau Phase 4C tidak mengizinkan reopen setelah Closed.
- Finalize membekukan rank, combined score, eligible Judge, dan breakdown dalam snapshot. Setelah itu halaman Admin/Judge hanya memakai snapshot untuk hasil resmi.
- Visibility default OFF dan tidak mengubah round/result lifecycle. Judge yang assigned hanya mendapat rank, identitas contestant, dan combined score ketika ON; tidak melihat skor/identitas Judge lain yang dipasangkan dengan skor.
- Prototype memakai localStorage untuk demonstrasi; backend masa depan wajib menegakkan seluruh guard dan privacy, bukan mempercayai UI.

## Phase 6 Progression State (bukan status Round kelima)

```text
Finalized Result → Advancement Pending → Advancement Confirmed
                                      ↓
                         Target Contestants assigned → Configure Target → Open Target
```

- Source harus Finalized; target round berikutnya harus Draft. Top N hanya saran sampai Admin mengonfirmasi. Tie pada cutoff dan pilihan berbeda dari Top N wajib diberi alasan; official result tetap tidak berubah.
- Target dapat meng-copy Judge assignment/Required dan Criteria secara opsional, tidak pernah meng-copy contestant atau skor. Konfigurasi sumber dan target independen; `carryForwardScores = false`.
- Open target memerlukan assignment contestant, Judge (termasuk minimal satu Required), criteria valid, dan bobot efektif 100%. Judge Mode membaca roster/rubric target dan memulai sheet skor kosong yang terisolasi.
- Confirmed advancement boleh di-reset dengan alasan hanya jika target masih Draft. Penyesuaian contestant Draft (contoh withdrawal dan pengganti) memerlukan alasan dan masuk history. Setelah target Open, reset/penyesuaian biasa tidak tersedia.

## Open Policy Decisions

- Apakah reopen diizinkan setelah Round Closed? Bagaimana koreksi/versioning setelah Finalized?
- Apakah aggregation formula, inclusion Optional Judge, tie-break otomatis, dan manual rank override akan dapat dikonfigurasi?
- Apakah semua assigned judge harus Submitted sebelum Close?
- Apa konsekuensi jika Judge dihapus atau tidak hadir ketika Round sudah Open?

## Phase 4C Governance Prototype

- Submission mengikuti `Submitted → Reopened → Resubmitted`. Reopen butuh alasan, mempertahankan skor, dan menambah history lokal (`roundId`, `judgeId`, reason, actor, reopenedAt, resubmittedAt). Judge tidak dapat self-reopen.
- Saat Open, assignment judge dapat diberi exception `Excused` dengan alasan, lalu `Restore` sebelum round Closed. Flag Required/Optional sebelumnya dipertahankan. `Removed` hanya untuk judge tanpa aktivitas skor; record tetap terlihat.
- Kesiapan Close menghitung hanya judge aktif dengan `required=true`. Semua harus Submitted/Resubmitted; Not Started, In Progress, dan Reopened memblokir. Optional dan Excused tidak memblokir.
- Close mengubah Round `Open → Closed`, mengunci edit dan submit Judge, serta mempertahankan Monitoring dan Submission Detail sebagai read-only. Phase 5 menambahkan Results dan Finalized di atas alur ini.
- Semua action governance (Reopen, Resubmit, Excuse, Restore, Remove, Close) tampil di audit preview lokal. Ini bukan audit/authorization produksi.
- Untuk baris Amanda yang awalnya hanya mock `Submitted`, reopen pertama mengisi *hanya skor demo yang masih kosong* supaya alur lintas mode dapat dicoba; skor yang sudah ada tidak ditimpa. Submit nyata berikutnya memakai skor Judge state.
