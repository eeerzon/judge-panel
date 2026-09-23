# FR — Judging Flow

Functional requirements untuk alur utama prototype. Semua rule di sini **sudah terimplementasi** dan diverifikasi lewat testing manual di browser (lihat `HANDOFF.md` bagian "Test results"). Dokumen ini adalah *deskripsi* dari behavior yang sudah ada, bukan spec untuk dibangun — kalau Codex mengubah behavior, dokumen ini yang harus diupdate mengikuti, bukan sebaliknya.

## Alur Normal

```
standby.html
  → tap di mana saja → contestants.html
      → tap kartu kontestan → scoring.html?id=N&from=gallery
          → Save & Next → id berikutnya, &from tetap
          → Back / tombol keluar di kontestan terakhir → kembali ke contestants.html
      → tombol "Review & Submit" → review.html
          → buka salah satu row → scoring.html?id=N&from=review
              → Back / tombol keluar → kembali ke review.html (BUKAN contestants.html)
          → tombol "Submit Judging" (hanya aktif kalau 15/15 lengkap) → modal konfirmasi → submitted.html
  submitted.html "Return to Standby" → standby.html
  submitted.html "View Submitted Scores" → review.html (read-only)
```

`&from=gallery|review` di URL menggantikan konsep "asal navigasi" — dipakai supaya tombol Back/keluar dari Scoring Page mengembalikan juri ke layar yang benar-benar mereka datangi, bukan selalu ke Gallery.

## FR-1 — Status Kontestan (derived, bukan disimpan langsung)

Status **tidak pernah** disimpan sebagai field terpisah — selalu dihitung ulang dari jumlah kriteria yang terisi (`getContestantStatus()` di `state.js`):

| Kondisi | Status |
|---|---|
| 0 dari 5 kriteria terisi | `not-started` → tampil "Not Scored" |
| 1–4 dari 5 kriteria terisi | `draft` → tampil "Draft · X / 5 criteria" |
| 5 dari 5 kriteria terisi | `scored` → tampil "✓ Scored" |

**Kriteria "terisi"** = nilai `!== null && !== undefined`. Nilai `0` dianggap "belum diisi" secara konsep — tapi karena skala minimal adalah 1, `0` tidak pernah terjadi sebagai nilai valid, hanya `null` yang berarti kosong.

## FR-2 — Formula Total Score

```
weightedSum = Σ (nilai_kriteria × bobot_kriteria)   untuk semua 5 kriteria
totalScore  = weightedSum / 10
```

Bobot: Communication 10, Confidence 10, Substance 10, Evening Gown 30, Stage Presence 40 (total 100, lihat `mock-data.js` → `criteriaList`).

**Aturan mutlak:** total **hanya** dihitung kalau **semua 5 kriteria** terisi (`isContestantComplete()` harus true). Kalau ada satu saja yang kosong, hasilnya `null` dan ditampilkan sebagai `— / 100` — **tidak pernah** menghitung kriteria kosong sebagai nol, dan **tidak pernah** menampilkan total parsial.

Contoh (dari data demo, sudah diverifikasi manual): Communication 8.75, Confidence 9.00, Substance 8.50, Evening Gown 9.25, Stage Presence 9.00 → `(8.75×10 + 9.00×10 + 8.50×10 + 9.25×30 + 9.00×40) / 10 = 90.00`.

**Satu fungsi, dua tempat pakai:** `calculateContestantTotal()` di `state.js` dipanggil baik dari `scoring.js` maupun `review.js` — jangan pernah menulis ulang formula ini di tempat lain.

## FR-3 — Validasi Input Skor

- Skala: `1` s.d. `10`, step `0.25` (`SCORE_MIN`/`SCORE_MAX`/`SCORE_STEP` di `mock-data.js`).
- Stepper `+`/`−`: dari kosong, tombol `+` mengisi ke `1` (minimum), tombol `−` dari kosong tidak melakukan apapun (tidak ada "di bawah kosong").
- Manual entry (tap angka → ketik): validasi berurutan, pesan spesifik per kasus:
  - Bukan angka → "Enter a number."
  - `< 1` → "Minimum score is 1."
  - `> 10` → "Maximum score is 10."
  - Bukan kelipatan 0.25 (mis. `8.33`) → "Use increments of 0.25."
- **Tidak pernah silent-round.** Input `8.33` ditolak dengan pesan error, bukan diam-diam dibulatkan ke `8.25`. Teks yang diketik user tetap tampil di field (bukan reset ke nilai lama) supaya mereka tahu persis apa yang perlu dikoreksi, dan field otomatis refocus dengan kursor di akhir.
- Field kosong (dikosongkan manual) = valid, berarti nilai jadi `null` lagi (skor dihapus).

## FR-4 — Quick Score (Confidence saja)

Preset `7 / 8 / 9 / 10` **hanya** muncul di kriteria Confidence, satu-satunya eksperimen UX yang disengaja tidak diperluas ke semua kriteria. Kesimpulan dari eksperimen (lihat `HANDOFF.md` Phase 5): **KEEP** sebagai preset "skor umum", jangan diperluas — memperluas ke semua kriteria berisiko membuat setiap kriteria punya 3 cara input berbeda yang memecah fokus juri.

## FR-5 — Guard Halaman

| Halaman | Guard | Bypass |
|---|---|---|
| `scoring.html?id=N` | `N` harus kontestan valid, kalau tidak → redirect `contestants.html` | `?preview=1` fallback ke kontestan #1 (tidak redirect) |
| `submitted.html` | Harus `isSubmitted === true`, kalau tidak → redirect `review.html` | `?preview=1` render mock "15 scored, 21:42" tanpa baca/tulis state asli |
| `contestants.html`, `review.html` | **Tanpa guard** — sengaja bisa dibuka kapan saja, termasuk 0/15 (fungsi Review justru menunjukkan yang belum lengkap) | — |
| Aksi Submit | `submitJudging()` mengecek ulang `areAllContestantsComplete()` di `state.js` — bukan cuma tombol UI yang di-disable | Tidak ada bypass — berlaku bahkan kalau UI di-manipulasi |

## FR-6 — Read-Only Setelah Submit

Begitu `isSubmitted === true`:
- **Scoring Page**: semua kontrol nilai (`+`/`−`/manual/quick-score/note) nonaktif. Previous/Next/Back tetap berfungsi (masih boleh lihat, tidak boleh ubah). Progress badge berubah jadi "Submitted", label tombol "Next →" (tanpa "Save &").
- **Contestant Gallery**: banner "Judging Submitted" tampil, semua kartu status Scored, tombol header CTA berubah jadi "View Submission".
- **Review**: catatan "Judging submitted. These scores are locked..." tampil, tidak ada tombol "Continue"/"Score"/"Submit Judging" di manapun.

Tidak ada mekanisme un-submit dari UI — hanya reset localStorage (`Reset Prototype State` di launcher, atau manual clear) yang mengembalikan ke draft.

## FR-7 — Privasi/Fairness Data

**Tidak boleh** ditampilkan di manapun dalam aplikasi ini:
- Skor juri lain
- Ranking/posisi
- Average/skor gabungan semua juri
- Prediksi hasil akhir

Yang boleh ditampilkan hanya: foto, nomor, nama, negara kontestan, dan progress/skor milik **judge yang sedang login** (Judge 03 — hardcoded di `mock-data.js` untuk prototype, akan jadi data session sungguhan di produksi).

## FR-8 — Preview Mode (khusus dev, bukan flow judge)

`?preview=1` di URL manapun: render tanpa guard state, **tidak pernah** menulis ke localStorage, **tidak pernah** mengubah `isSubmitted`. Dipakai murni untuk review visual satu halaman tanpa harus jalani flow lengkap dari awal. Lihat `architecture/system-overview.md` §Preview Mode untuk detail teknis.
