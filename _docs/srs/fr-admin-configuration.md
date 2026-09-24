# FR — Admin Configuration and Governance Prototype

## Round configuration

Contestant master dan Judge master adalah data event-level. Round Contestants, Round Judges, dan Criteria berada dalam shared Round Workspace. Assignment dan criteria biasa hanya dapat diubah ketika Round Draft. Required/Optional adalah atribut assignment, bukan atribut Judge master.

## Phase 4C — Operational control

- Admin Submission Detail menampilkan judge, round, status, waktu, progress, koneksi, daftar contestant, dan drill-down skor per criterion. Monitoring row tidak menampilkan skor. Judge 03 memakai skor Judge state jika sudah ada submission nyata; judge mock lain memakai angka referensi yang diberi label prototype, bukan data resmi.
- Reopen hanya tersedia untuk Submitted/Resubmitted ketika Round Open, memakai alasan wajib. Skor Judge dipertahankan; status menjadi Reopened dan membutuhkan resubmission.
- Resubmit mencatat timestamp baru serta mempertahankan original submission/reopen history pada prototype localStorage.
- Excused membutuhkan alasan; assignment tetap terlihat tetapi keluar dari required submission denominator. Restore hanya saat Open dan mengembalikan status serta flag required sebelumnya.
- Removed hanya untuk assignment tanpa scoring activity; record tidak dihapus. Judge dengan aktivitas diarahkan menggunakan Excused atau governance Reopen.
- Close Round hanya ketika semua judge aktif yang Required sudah Submitted/Resubmitted. Optional dan Excused tidak memblokir. Jika belum siap, UI memberi sebab dan tautan Monitoring, bukan hanya tombol disabled.
- Setelah Closed, penilaian Judge read-only; Monitoring dan Submission Detail Admin tetap dapat dibaca. Tidak ada Finalize/Results engine pada fase ini.
- Audit Log adalah preview lokal untuk Submit, Reopen, Resubmit, Excuse, Restore, Remove, dan Close. Tidak ada audit backend atau authentication.

## Scope boundary

Prototype ini memakai state lokal Admin/Judge dan normal page refresh untuk sinkronisasi lintas mode. Aturan izin dan audit produksi harus ditegakkan oleh backend pada implementasi mendatang; tampilan dan localStorage di sini bukan security boundary.

## Phase 5 — Results and Finalization

- Round Results berada dalam shared Round Workspace; Global Results adalah overview hasil per round, bukan ranking lintas round.
- Hanya round Closed dengan seluruh Required aktif Submitted/Resubmitted yang dapat menampilkan Provisional Admin Result. Open tidak menampilkan ranking.
- Official Combined Score memakai rata-rata total contestant 0–100 dari Judge assigned + Required + Submitted/Resubmitted; Optional, Excused, dan Removed tidak dihitung. Result Detail menandai Included atau alasan Not Counted dan mempertahankan riwayat yang tersedia.
- Ranking mengurutkan combined score dua desimal menurun. Nomor contestant hanya secondary display order. Skor sama berbagi rank dan diberi TIED; Finalize terblokir hingga Admin menekan Acknowledge Tie. Tidak ada tie-break otomatis.
- Finalize memerlukan konfirmasi dan menyimpan snapshot resmi immutable secara konsep. Round berubah Closed → Finalized, seluruh edit normal tetap terkunci; hasil resmi kemudian dibaca dari snapshot, bukan dihitung ulang.
- Judge visibility default OFF, hanya dapat diubah setelah Finalized, dan terpisah dari status round. Judge Results direct-entry memeriksa Finalized + ON + assignment aktif, lalu hanya menampilkan rank, contestant, dan combined score tanpa skor/identitas Judge lain.
- Audit preview mencatat results calculated, finalize, visibility ON/OFF. Ini bukan audit produksi. Tidak ada advancement, backend/API, Flutter, atau production auth pada fase ini.

## Phase 6 — Advancement and Multi-Round Progression

- Round Results Finalized menyediakan entry point Advancement menuju round berikutnya menurut urutan. Final tidak memiliki advancement. Global Results tetap overview hasil per round tanpa kontrol progression.
- Top N dari snapshot resmi dipilih sebagai saran, bukan otomatis dikonfirmasi. Admin dapat mengubah selection; alasan wajib jika berbeda atau ada tie di batas kualifikasi. Preview memperlihatkan Advancing/Not Advancing sebelum modal konfirmasi.
- Konfirmasi menyimpan advancement record terpisah dan mengganti target-round contestant assignment dengan ID event-level terpilih. Hasil resmi source tidak berubah. Penyesuaian karena withdrawal saat target Draft memerlukan alasan dan history; reset dengan alasan hanya saat target Draft.
- Target round dapat meng-copy Judge assignments/Required dan Criteria dari source secara opsional dengan konfirmasi. Contestants dan skor tidak ikut di-copy. Open target memerlukan contestant >0, Judge >0, minimal satu Required, criteria valid dan bobot efektif 100%.
- Judge My Rounds menampilkan sejarah semua round. Round baru yang Open dan assigned dapat dimasuki; roster, rubric, submission, skor, hasil, dan visibility scoped per round. Tidak ada carry-forward score atau overall cross-round score.
