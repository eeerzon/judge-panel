# BRD Core — KREEN Judge Panel Prototype

**Versi ringkas** — prototype ini tidak melalui proses BRD formal (dikerjakan langsung sebagai eksplorasi UX bertahap per-fase), jadi dokumen ini disusun **mundur (retrospektif)** dari keputusan yang sudah diambil sepanjang Phase 1–6, bukan requirement yang ditulis sebelum eksekusi.

## Tujuan

Membuat **acuan visual dan interaksi (UX reference)** untuk aplikasi Flutter "KREEN Judge Panel" yang akan dipakai juri menilai kontestan pageant **King & Queen of the Pacific 2026**, ronde Preliminary, di atas tablet Android.

Prototype ini **bukan** aplikasi yang akan dipakai sungguhan di event — tujuannya memvalidasi flow, layout, dan keputusan interaksi *sebelum* aplikasi produksi (kemungkinan besar Flutter) dibangun, supaya tim development punya spesifikasi visual yang jelas dan sudah "teruji secara mental" tanpa biaya membangun backend/infrastruktur dulu.

## Target User

- **Juri pageant**, usia 40–60+, tidak semua terbiasa teknologi.
- Duduk di meja juri selama grand final/preliminary, tablet landscape di depan mereka.
- Kondisi ruangan: ballroom/venue redup, banyak pencahayaan panggung, bukan lingkungan terang standar kantor.
- Butuh memahami cara pakai aplikasi **tanpa training panjang** — first-time use harus langsung jelas.

## Scope (yang dibangun)

1. **Standby/screensaver screen** — tampilan idle di meja juri.
2. **Contestant Gallery** — grid 15 kontestan dengan status & filter.
3. **Scoring Page** — input nilai per kriteria, satu kontestan per waktu.
4. **Review & Submit** — ringkasan sebelum submit, dengan guard kelengkapan.
5. **Submitted (locked)** — konfirmasi pasca-submit, read-only.
6. Simulasi state non-bisnis untuk kebutuhan desain masa depan: connection status, save/submit failure, standby timeout — **semua simulasi**, bukan implementasi nyata (lihat `PROTOTYPE-NOTES.md`).

## Out of Scope (eksplisit, ditegaskan berulang kali sepanjang proyek)

- Result/Ranking engine
- Head Judge UI / reopen-after-submit capability
- Melihat skor juri lain / leaderboard / average
- Admin dashboard
- Backend/API sungguhan, autentikasi produksi
- Kode Flutter (prototype ini murni HTML/CSS/JS)

## Kriteria Penilaian (bisnis, sudah final)

5 kriteria, dikelompokkan 3 section, total bobot 100%:

| Section | Kriteria | Bobot |
|---|---|---|
| Interview (30%) | Communication | 10% |
| | Confidence | 10% |
| | Substance | 10% |
| Evening Gown | (standalone) | 30% |
| Stage Presence | (standalone) | 40% |

Skala nilai: 1–10, step 0.25. Formula total: lihat `srs/fr-judging-flow.md` §Formula Skor.

## Kondisi Sukses Prototype

Prototype dianggap berhasil kalau:
- Juri berusia 55+ tanpa penjelasan bisa langsung menjawab: event apa, round apa, dirinya juri siapa, siapa yang belum dinilai, di mana harus tap untuk menaikkan/menurunkan nilai, apakah nilainya sudah tersimpan, dan bagaimana lanjut ke kontestan berikutnya.
- Tidak ada regresi visual di 4 breakpoint acuan (1280×800, 1440×900, 1920×1080, 800×1280).
- Semua file bisa dibuka langsung (`file://`, double-click) tanpa server — supaya mudah di-handoff ke siapapun untuk direview.

## Riwayat Keputusan Penting

Lihat `_docs/HANDOFF.md` untuk riwayat lengkap tiap fase (termasuk revisi yang pernah dibatalkan/diubah arah, misalnya serif→sans-serif, generic dark theme→King & Queen of the Pacific branding, single-page→multi-page). Dokumen BRD ini sengaja tidak mengulang riwayat itu — cukup jadi ringkasan kondisi akhir.
