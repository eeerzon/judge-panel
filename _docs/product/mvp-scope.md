# MVP Scope Proposal — KREEN Judging

## Purpose

Proposal ini mendefinisikan boundary awal. Ia bukan approval untuk membangun seluruh daftar sekaligus. Perubahan dari proposal ini harus ditandai eksplisit saat planning/review berikutnya.

## MVP In Scope

| Area | Minimum deliverable |
|---|---|
| Admin workspace | Admin shell, Event Overview, Rounds list, Round Overview. |
| Judge entry | My Rounds dan pemilihan round sebelum flow Judge yang existing. |
| Round-aware judging | Existing Standby, Contestants, Scoring, Review, Submitted memperoleh konteks round tanpa redesign UX. |
| Participants | Contestant master dan assignment contestant per Round. |
| Judges | Judge master dan assignment judge per Round. |
| Rubric | Criteria/criterion group per Round, dengan validasi configuration. |
| Operations | Live Monitoring status/progress/connectivity, tanpa menampilkan nilai secara default. |
| Governance | Reopen submission dengan reason dan audit trail minimum. |

## Deferred Until Business Rules Are Approved

- Combined Results.
- Ranking.
- Tie break.
- Advancement ke round berikutnya.
- Judge result visibility.

Tidak boleh membuat UI Results atau mengasumsikan formula ranking sebelum bagian **Decision Required** disetujui.

## Decision Required — Results

1. Rumus combined result.
2. Apakah seluruh Judge assigned wajib submit sebelum Round dapat Closed/dihitung.
3. Penanganan Judge absent/removed.
4. Tie-break rule.
5. Apakah reopen/resubmit menghitung ulang result, dan sampai status round mana.
6. Finalization lock dan exception authority.
7. Level visibility hasil Judge: ranking saja, ranking + combined score, atau bentuk lain.

## Explicitly Out of Scope for Phase 0

- Flutter implementation.
- Backend/API/database schema atau migration.
- Login/device pairing nyata.
- Result/ranking UI.
- Perubahan visual/behavior lima layar Judge frozen.

## MVP Acceptance Boundary

MVP dianggap siap untuk phase implementasi ketika domain model, lifecycle, permission matrix, and result decisions yang blocker sudah direview dan disetujui; bukan hanya karena tampilan admin sudah dibuat.
