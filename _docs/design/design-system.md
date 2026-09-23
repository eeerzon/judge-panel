# Design System — KREEN Judge Panel (King & Queen of the Pacific)

**Status: FROZEN.** Semua keputusan di dokumen ini sudah melalui beberapa putaran review visual eksplisit (lihat `HANDOFF.md` untuk riwayat lengkap tiap fase). **Jangan redesign ulang tanpa instruksi eksplisit dari user** — kalau ada kebutuhan baru yang tidak tercakup di sini, tambahkan token/komponen baru yang konsisten dengan sistem ini, jangan ganti fondasinya.

Semua nilai di dokumen ini diambil langsung dari `judge-prototype/assets/css/tokens.css` dan `components.css` — bukan dari ingatan/perkiraan. Kalau ada perbedaan antara dokumen ini dan CSS aktual, **CSS aktual yang benar** — laporkan sebagai dokumentasi basi, jangan diam-diam dipercaya salah satunya.

---

## 1. Karakter Desain

**Brand:** King & Queen of the Pacific 2026 (pageant, ronde Preliminary).

**Arah visual:** royal, dark, luxury, refined, pageant-specific, premium tapi tenang.

**Bukan:** generic admin panel, tech dashboard, gaming UI, neon interface, minimal corporate SaaS.

**Konteks penggunaan:** ballroom/venue redup, juri usia 40–60+, tablet Android 10–12" landscape sebagai target utama, tapi harus tetap nyaman di laptop/desktop dan tablet portrait.

**Prinsip UX yang membentuk semua keputusan visual di bawah:**
- Touch-first, bukan mouse-first — target sentuh besar, spacing lega.
- Low cognitive load — satu kontestan per layar, hierarki visual sangat jelas (foto → nomor → nama → status).
- Dark-room safe — tidak ada area putih besar, gold dipakai sangat terbatas supaya tidak menyilaukan.
- Status "Scored" harus paling cepat dikenali di antara semua status (satu-satunya yang boleh solid fill terang).

---

## 2. Design Tokens (dari `tokens.css`)

### 2.1 Warna dasar

| Token | Hex | Pemakaian |
|---|---|---|
| `--bg-base` | `#12090A` | Background utama semua layar — deep burgundy/wine-black, **bukan** abu-abu netral |
| `--surface` | `#1B1215` | Card, panel, permukaan level-1 |
| `--surface-alt` | `#22171B` | Permukaan level-2 (tombol default, badge non-aktif, filter pill) |
| `--surface-raised` | `#2A1D21` | Permukaan ter-elevasi (hover state, modal panel) |
| `--border` | `#3A2B2F` | Border default |
| `--border-strong` | `#4A3439` | Border hover/emphasis |

### 2.2 Teks

| Token | Hex | Pemakaian |
|---|---|---|
| `--text-primary` | `#F6F1E8` | Teks utama — warm ivory, **bukan** putih murni |
| `--text-secondary` | `#B8A89B` | Teks sekunder/metadata |

### 2.3 Aksen emas (dipakai sangat terbatas)

| Token | Hex/Value | Pemakaian |
|---|---|---|
| `--accent` | `#C89B4B` | Nomor kontestan, border aktif |
| `--accent-bright` | `#D4AF6A` | Round label, Total Score value, highlight terang |
| `--accent-deep` | `#8C6A35` | Border tombol primary (belum hover) |
| `--accent-soft` | `rgba(200, 155, 75, 0.14)` | Background tint untuk state aktif/primary (filter pill aktif, tombol primary) |

**Aturan pemakaian gold:** label, nomor, border aktif, highlight kecil. **Jangan** dipakai sebagai warna dominan tombol/teks besar — itu sebabnya `--accent-soft` (tint transparan) dipakai untuk background tombol primary, bukan `--accent` solid.

### 2.4 Status palette

| Token | Value | Pemakaian |
|---|---|---|
| `--status-scored-fill` | `#1E9E5C` | Background solid badge "✓ Scored" — **satu-satunya status yang solid fill**, sengaja kontras tinggi karena harus paling cepat dikenali di grid |
| `--status-scored-fill-border` | `#167A47` | Border badge Scored |
| `--status-scored-text` | `#F3FFF6` | Teks di atas fill Scored (near-white untuk kontras maksimal) |
| `--status-scored-icon` | `#C8F7DC` | Ikon/dot Scored, juga dipakai untuk teks "Saved ✓" (bright mint, bukan warna fill) |
| `--status-scored-glow` | `rgba(30, 158, 92, 0.35)` | Box-shadow glow tipis di badge Scored |
| `--status-draft-color` | `#D9B76B` | Teks/dot status Draft — muted gold, **bukan** solid fill |
| `--status-draft-bg` | `rgba(200, 155, 75, 0.14)` | Background tint Draft |
| `--status-draft-border` | `rgba(200, 155, 75, 0.38)` | Border Draft |
| `--status-error-color` | `#E0897A` | Warna error/warning — validasi skor invalid, "Unable to save", offline indicator, dev-panel active state. Warm coral, **bukan** merah terang |
| `--success` | `#8FBF9E` | (legacy token, dipakai minimal) |

**Kenapa Scored beda treatment dari Draft/Not Scored:** Scored adalah satu-satunya status yang harus "berteriak" — juri harus bisa scan grid 15+ kontestan dan langsung tahu siapa yang sudah selesai. Draft/Not Scored sengaja tetap muted karena itu bukan yang sedang dicari juri (mereka mencari yang *belum* Scored lewat filter, bukan warna).

### 2.5 Tipografi

```css
--font-ui: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
```

**Full sans-serif** — tidak ada serif di manapun dalam sistem ini (versi awal prototype sempat pakai Georgia untuk judul standby, direvisi eksplisit ke sans-serif karena ini "aplikasi operasional, bukan editorial"). Dev panel & launcher pakai monospace terpisah (`ui-monospace, "SF Mono", Menlo, monospace`) khusus untuk menandai elemen itu sebagai "bukan bagian produk".

### 2.6 Layout shell

```css
--scoring-shell-max-width: 1600px;
```

Cap lebar untuk header/body/footer Scoring Page di layar ultra-wide. Gallery pakai cap terpisah `1500px` (lihat §6.2).

---

## 3. Skala Tipografi (dari penggunaan aktual di komponen)

| Konteks | Ukuran | Weight | Catatan |
|---|---|---|---|
| Judul halaman (Gallery "Contestants") | 28px | 700 | |
| Nama event (Gallery header) | 22px | 700 | |
| Judul modal | 22px | 700 | |
| Nama kontestan (card, Scoring identity) | 18–20px | 600 | Scoring identity 20px, Gallery card 18px |
| Nomor kontestan | 20–24px | 700 | tabular-nums selalu |
| Total Score value | 32–36px | 700 | tabular-nums, warna `--accent-bright` |
| Score value (stepper) | 32px (view) / 28px (edit input) | 700 | tabular-nums |
| Body/subtitle | 16px | 400–500 | |
| Metadata (negara, judge identity, progress text) | 13–15px | 500 | |
| Label kecil uppercase (Total Score label, section heading) | 11–13px | 600–700, letter-spacing 0.06–0.16em | |
| Dev panel (semua teks) | 11px | — | monospace, sengaja kecil untuk membedakan dari produk |

**Baseline aksesibilitas (dari Phase 5 audit):** body minimal 16px, instruksi utama 20–24px, tidak ada teks di bawah 11px (dan yang 11px eksklusif untuk dev-panel/label uppercase kecil, bukan konten yang harus dibaca juri).

---

## 4. Spacing & Touch Target

**Minimum touch target: 48px.** Preferred untuk kontrol scoring utama: 56–64px.

| Elemen | Ukuran |
|---|---|
| Stepper button (`+`/`−`) | `56×56px`, border-radius 14px |
| Filter pill / Standby action / Scoring back button | `48px` height |
| Quick-score button | min `48×48px` |
| Primary CTA (Scoring nav, Review footer, Modal) | min-height `56px` (modal `52px`) |
| Review row badge/action button | `120×48px` tetap (lebar sama persis antara "Continue"/"Score"/"✓ Scored") |
| Dev panel button | `36px` default, `44px` di `@media (pointer: coarse)` |
| Card grid gap | `20px` (Gallery), `24px` (Review row internal grid) |
| Section padding standar | `40px` sisi kiri/kanan desktop, turun ke `20px` di portrait/mobile |

**Pola spacing responsif:** side-padding besar (32–40px) di desktop/tablet landscape, menyempit ke 20px di portrait — tidak pernah di bawah 16px.

---

## 5. Border Radius

| Skala | Value | Pemakaian |
|---|---|---|
| Kecil | `6–10px` | Dev panel button, standby-action, scoring-back-btn |
| Medium | `12–14px` | Tombol utama (score-btn, scoring-nav-btn, review-footer-btn), card kontestan Review |
| Besar | `16px` | Contestant card (Gallery) |
| Pill | `24px` | Filter pill |
| Circle | `50%` | Dot indikator (status-dot, connection-dot) |

---

## 6. Komponen

### 6.1 Standby Screen

- Logo event (`event-logo-image`) ukuran responsif `min(260px, 46vh)` desktop landscape → `min(300px, 46vh)` di ≥1024px landscape → `min(200px, 30vh)` portrait → `min(160px, 26vh)` di ≤480px.
- Radial glow halus di belakang logo + vignette gelap — **calm, bukan gaming splash screen**.
- Tap instruction (`.tap-instruction`) 22px, animasi `pulse-fade` 2.6s infinite (opacity 0.55↔1) — bukan animasi besar/mencolok.
- Seluruh layar adalah tap target tunggal (bukan satu tombol kecil "START").
- Footer: judge identity (kiri) + connection status (kanan), keduanya secondary/subtle.

### 6.2 Contestant Gallery

- Grid kontestan: `repeat(4, 1fr)` default, `repeat(5, 1fr)` di ≥1680px, `repeat(3, 1fr)` di ≤1100px landscape, `repeat(2, 1fr)` di portrait. Gap `20px` (16px di portrait).
- Container di-cap `max-width: 1500px` dan di-center di ≥1200px (lihat komentar CSS panjang di `components.css` soal flex-item shrink-wrap bug — **jangan** hapus `width: 100%` yang menyertai `max-width`/`margin:auto` di pola ini, itu fix untuk bug nyata yang pernah terjadi dua kali).
- Kartu kontestan: foto 3:4 (`aspect-ratio` via `.contestant-photo`, `object-fit: cover`), fallback gradient hue-per-nomor + inisial kalau foto gagal load.
- Hierarki dalam kartu: **Foto → Nomor → Nama → Negara → Status badge**. Tidak ada skor/ranking di kartu ini (privasi/fairness — lihat `srs/fr-judging-flow.md`).

### 6.3 Scoring Page

- Split layout: identity panel kiri (foto besar, nomor, nama, negara, progress badge, Total Score block) + scoring panel kanan (scrollable, per-kriteria).
- **Score control** (komponen paling penting):
  ```
  [ − ]     8.75     [ + ]
  ```
  - Tombol `56×56px`, disabled state opacity 0.32.
  - Value 32px bold tabular-nums, tap untuk masuk mode edit manual (`inputmode="decimal"`).
  - State kosong tampil `—` (bukan `0`) — skor yang belum diisi **tidak pernah** dianggap nol.
  - Increment/decrement step `0.25`, range `1–10` (`SCORE_MIN`/`SCORE_MAX`/`SCORE_STEP` di `mock-data.js`).
  - Quick-score preset (`7 8 9 10`) **hanya di kriteria Confidence** — hasil eksperimen Phase 5, kesimpulan: KEEP tapi jangan diperluas ke semua kriteria (lihat `HANDOFF.md` Phase 5 untuk alasan lengkap).
  - Error validasi tampil sebagai teks kecil di bawah kontrol, warna `--status-error-color`, **tidak pernah** silent-round nilai invalid.
- **Total Score block**: label kecil uppercase → angka besar (36px, `--accent-bright`) → `/100` kecil. `—/100` selama ada kriteria kosong.
- Read-only state (setelah submit): semua kontrol `disabled`, banner hijau solid "Submitted" di atas daftar kriteria, label tombol berubah dari "Save & Next →" jadi "Next →".

### 6.4 Review & Submit

- List (bukan grid foto) — 3 kolom per row: `minmax(0,1fr) 140px 140px` (Identity | Total Score | Action/Badge).
- Row height min `88px`, foto `56×56px` di dalam row (bukan foto besar seperti Gallery).
- Badge "✓ Scored" solid fill hijau (sama seperti Gallery), tombol "Continue"/"Score" **lebar sama persis** (`120×48px`) supaya tidak ada layout shift antar status.
- Summary panel: progress count + progress bar tipis + status count chips (Scored/Draft/Not Scored) — **tidak ada** average/ranking/skor juri lain.
- Footer sticky: "Complete Remaining Scores" (kalau belum lengkap) **atau** "Submit Judging" solid-fill hijau (`is-ready` — reuse token Scored) kalau 15/15 lengkap.

### 6.5 Modal Konfirmasi Submit

- `max-width: 520px`, `border-radius: 18px`, background `--surface-raised`.
- Copy singkat: "Submit Preliminary Judging?" → "You have scored all N contestants." → secondary note tentang lock (Head Judge reopen-flow **sengaja dihapus** dari copy demi clarity untuk user non-teknis).
- Dua state konten yang saling eksklusif (`hidden` toggle): confirm body vs. failed body ("Submission failed" + tombol "Try Again").
- Tombol modal min-height `52px`, gap cukup antara Cancel dan Submit Scores (tidak boleh berdekatan).

### 6.6 Submitted Screen

- Checkmark besar solid `--status-scored-fill`, judul "Judging Submitted", round, jumlah kontestan, timestamp, catatan lock, 2 tombol aksi.

### 6.7 Dev Panel & Launcher (BUKAN bagian produk)

- Dev panel: strip collapsed di atas setiap halaman, monospace, border dashed, background hampir hitam solid (`rgba(18,9,10,0.96)`) — sengaja terlihat seperti debug tool, bukan UI juri. **Jangan** styling ulang supaya "lebih cantik" — justru harus tetap terlihat beda dari produk.
- Launcher (`index.html` root): card sederhana, bukan styling produk, untuk navigasi dev/preview saja.

---

## 7. Status Badge Reference (lengkap)

| Status | Class | Visual |
|---|---|---|
| Scored | `.status-scored` (Gallery card) / `.review-row-badge` (Review) | Solid fill `#1E9E5C`, teks `#F3FFF6`, border `#167A47`, glow tipis |
| Draft | `.status-draft` | Tint `rgba(200,155,75,0.14)`, teks `#D9B76B`, border `rgba(200,155,75,0.38)` |
| Not Scored | `.status-not-started` | Netral, `--surface-alt` + `--text-secondary` |
| Save error | `.save-status.is-error` | `--status-error-color` |
| Connection warning | `.connection-status.is-warning` | `--status-error-color`, bold |
| Connection normal/synced | `.connection-status.is-good` | `--success` dot, teks tetap `--text-secondary` (subtle) |

**Prinsip:** status tidak pernah cuma warna — selalu ada teks + (kecuali Scored) dot ikon. Warna sendirian tidak boleh jadi satu-satunya sinyal.

---

## 8. Breakpoint Reference

| Breakpoint | Kondisi | Efek utama |
|---|---|---|
| `min-width: 1024px` + landscape | Tablet landscape besar / laptop | Logo standby membesar |
| `min-width: 1200px` | Desktop | Gallery container di-cap `1500px` + center |
| `min-width: 1680px` | Desktop lebar | Grid kontestan jadi 5 kolom |
| `max-width: 1100px` + landscape | Tablet landscape sempit | Grid kontestan turun ke 3 kolom |
| `orientation: portrait` | Semua device portrait | Grid 2 kolom, spacing menyempit, logo mengecil |
| `max-width: 480px` | Phone (bukan target utama, tapi tidak boleh pecah) | Font judul mengecil lebih lanjut |
| `pointer: coarse` | Device dengan sentuhan kasar | Dev-panel button naik ke 44px |

**Target device utama:** Android tablet 10–12" landscape (referensi uji: 1280×800). Sekunder: 1440×900 (laptop), 1920×1080 (desktop), 800×1280 (tablet portrait) — keempatnya diverifikasi berkali-kali sepanjang Phase 1–6, nol overflow.

---

## 9. Imagery

- Foto kontestan: rasio 3:4, `object-fit: cover`, sumber banner promosi asli klien (bukan foto polos — ada teks nama/negara "terbakar" di gambar, ini keterbatasan aset, bukan keputusan desain).
- Fallback kalau foto gagal load: gradient linear 160deg dari hue unik per nomor kontestan (`PHOTO_HUES` di `mock-data.js`, palet jewel-tone: ruby/gold/amethyst/emerald — dipilih supaya harmonis dengan tema burgundy-gold, revisi dari palet biru/teal awal yang terasa "dingin").
- Logo event: PNG dengan background solid (bukan transparan) — kalau ditampilkan besar di Standby, pertimbangkan CSS `mask-image` radial untuk menyamarkan seam kotak (sudah diterapkan di versi awal, cek riwayat kalau logo diganti).

---

## 10. Motion

Minimal, tidak pernah dekoratif besar:
- `pulse-fade` 2.6s di tap instruction Standby.
- `transform: scale(0.96)` di tombol saat `:active`.
- Transisi warna border/background standar (`hover`), tanpa durasi eksplisit di kebanyakan tempat (instant/browser-default) — prototype ini sengaja tidak berinvestasi di animasi halus karena itu bukan yang sedang diuji.

---

## 11. Aksesibilitas Bawaan Sistem Ini

- Kontras teks-di-atas-fill selalu dicek manual (mis. `--status-scored-text` near-white di atas fill hijau, bukan asal pakai `--text-primary`).
- Semua kontrol interaktif punya `:focus-visible` outline (`2px solid var(--accent)`).
- Status tidak pernah color-only (§7).
- Tidak ada aksi penting yang icon-only tanpa label teks.
- `font-variant-numeric: tabular-nums` di semua angka yang bisa berubah (skor, nomor, posisi) supaya tidak "loncat" lebar saat update.

---

## 12. Kalau Codex Perlu Menambah Komponen Baru

1. Cek dulu apakah token warna/spacing yang dibutuhkan sudah ada di §2–5 — jangan hardcode hex baru kalau salah satu token existing sudah cukup dekat maknanya.
2. Kalau butuh warna benar-benar baru, tambahkan sebagai token baru di `tokens.css` dengan komentar alasan (ikuti gaya komentar existing — semua token gold/status di file itu sudah dikomentari kenapa dipilih).
3. Komponen baru **harus** tetap classic `<link>`/`<script src>` — lihat `referensi/coding-standards.md` §"file:// compatibility" sebelum menambah dependency apapun.
4. Kalau ragu apakah sesuatu "masih dalam sistem ini" atau "redesign", **tanya user dulu** — jangan asumsi diam-diam. Ini prinsip yang berulang kali ditegaskan sepanjang riwayat proyek ini (lihat `HANDOFF.md`).
