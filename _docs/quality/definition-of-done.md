# Definition of Done — KREEN Judge Panel Prototype

Versi ringkas untuk skala prototype. Prinsip utama: **"Done means verified, not implemented"** — kode yang sudah ditulis tapi belum dicoba di browser sungguhan bukan "selesai".

## Checklist Sebelum Menandai Perubahan Selesai

- [ ] Perubahan sudah dicoba **di browser sungguhan** (bukan cuma dibaca kodenya) — via `file://` langsung DAN via `start-server.command`, hasilnya identik.
- [ ] Console browser bersih — tidak ada error (khususnya perhatikan: `Cannot use import statement`, `Failed to fetch`, `Not allowed to load local resource`, `net::ERR_FAILED` — semua ini indikasi pelanggaran `decisions/adr-002-file-protocol-compatibility.md`).
- [ ] Tidak ada regresi visual di 4 breakpoint acuan (`srs/nfr.md` §Responsive): 1280×800, 1440×900, 1920×1080, 800×1280.
- [ ] Kalau mengubah warna/spacing/komponen: dicek dulu terhadap `design/design-system.md` — kalau butuh nilai baru, token baru ditambahkan ke `tokens.css` dengan komentar alasan, bukan hardcode hex di tempat pemakaian.
- [ ] Kalau mengubah business logic (status, formula skor, guard): perubahan **hanya** di `state.js`/`navigation.js`, dan `srs/fr-judging-flow.md` diupdate mengikuti.
- [ ] Kalau menambah dependency/pattern baru (library, `fetch`, ES module): **berhenti** — itu melanggar ADR-002, konsultasikan ke user dulu sebelum lanjut.
- [ ] Guard bisnis tetap berfungsi setelah perubahan: `submitted.html` tanpa `?preview=1` sebelum submit tetap redirect; `scoring.html?id=` invalid tetap redirect; Scoring tetap read-only setelah submit.
- [ ] Dokumentasi terkait diupdate (bukan cuma kode) — `_docs/` yang relevan, dan `HANDOFF.md` kalau perubahan cukup besar untuk masuk riwayat fase.

## Yang BUKAN Termasuk "Selesai"

- Kode yang "kelihatannya benar" tapi belum di-screenshot/dicoba klik sungguhan.
- Perubahan visual tanpa perbandingan before/after eksplisit terhadap `design/design-system.md`.
- Menambah fitur bisnis baru (Result/Ranking/Head Judge/dll.) — itu di luar scope prototype ini sama sekali (lihat `brd/brd-core.md` §Out of Scope), bukan sekadar "belum selesai".

## Bug Workflow (kalau menemukan bug, bukan menulis fitur baru)

Urutan wajib: **reproduce dulu → cari root cause → fix → verify ulang**. Jangan langsung menebak-nebak penyebab dan menambal gejala — insiden `decisions/adr-002-file-protocol-compatibility.md` adalah contoh nyata kegagalan melakukan ini (langsung diasumsikan "browser security restriction" tanpa audit kode dulu, hasilnya solusi yang salah arah dan harus dibatalkan).
