# Coding Standards & Project Rules — KREEN Judge Panel Prototype

Aturan yang paling sering dilanggar tanpa dibaca dulu — bukan style-guide generik JavaScript/CSS.

## Aturan Wajib (Project Rules — tidak bisa ditebak dari konvensi umum)

1. **Vanilla JS murni, classic script, tanpa framework/bundler.** Tidak ada React/Vue/Svelte, tidak ada Webpack/Vite/npm build step. Alasan: lihat `decisions/adr-002-file-protocol-compatibility.md` — ini bukan preferensi gaya, ini requirement `file://`-compatibility.
2. **Tidak ada `type="module"`, `import`, `export`.** Semua file JS adalah IIFE (`(function () { ... })();`) yang expose satu global object (`window.JudgePrototypeData`, `window.JudgeState`, `window.JudgeNav`, `window.JudgeChrome`).
3. **Tidak ada `fetch`/`XMLHttpRequest`.** Semua data statis inline di `mock-data.js`.
4. **Semua path relatif, tidak pernah absolut.** `../assets/...` dari `pages/*.html`, `assets/...` dari root `index.html`. Jangan pernah `href="/..."` atau `src="/..."`.
5. **Navigasi antar halaman selalu nama file relatif** lewat `window.JudgeNav.goTo*()`. Jangan hardcode `window.location.href = 'http://localhost:8934/...'` atau path lain di luar fungsi navigation.js.
6. **Formula bisnis dan status derivation HANYA di `state.js`.** Kalau butuh menghitung status/total di halaman lain, panggil fungsi `window.JudgeState.*` yang sudah ada — jangan tulis ulang logic-nya secara lokal. Lihat `architecture/system-overview.md` §Business Helpers untuk daftar lengkap fungsi yang tersedia.
7. **Urutan load script tetap:** `mock-data.js` → `state.js` → `navigation.js` → `chrome.js` → script halaman itu sendiri. Jangan diubah urutannya — tiap file mengasumsikan global sebelumnya sudah ter-define.
8. **Chrome/dev-tooling (dev panel, offline banner, preview banner) lewat `chrome.js`**, jangan diduplikasi manual di tiap file halaman.
9. **CSS: jangan hardcode hex warna baru** kalau token yang relevan sudah ada di `tokens.css` — lihat `design/design-system.md` §2 untuk daftar lengkap token dan makna pemakaiannya.
10. **Komentar kode: singkat & teknis saja**, jelaskan *kenapa* (constraint tersembunyi, workaround bug spesifik), bukan *apa* (nama variabel/fungsi sudah menjelaskan itu). Histori panjang/naratif masuk dokumentasi (`HANDOFF.md`/`_docs/`), bukan komentar kode. Lihat contoh komentar existing di `tokens.css`/`components.css` sebagai referensi gaya yang sudah dipakai konsisten di project ini.

## Gotcha CSS yang Pernah Jadi Bug Nyata (jangan diulangi)

1. **`[hidden]` kalah oleh class `display:` lain dengan spesifisitas sama.** Kalau sebuah elemen pakai atribut `hidden` DAN kelas CSS yang set `display: flex/grid/block`, elemen itu **tidak akan tersembunyi** kecuali ada rule eksplisit `.nama-class[hidden] { display: none !important; }` ditulis SEBELUM rule `display:` utamanya. Bug ini terjadi dua kali di project ini (`.offline-banner`, `.submitted-banner`) — kalau menambah elemen baru yang di-toggle via `hidden`, cek pola ini dulu.
2. **Flex item dengan `max-width` + `margin: auto` butuh `width: 100%` eksplisit** untuk benar-benar center-dengan-cap, bukan shrink-wrap ke konten. Lihat komentar panjang di `components.css` sekitar `@media (min-width: 1200px)` untuk penjelasan lengkap — pola ini dipakai di Gallery header dan pernah jadi bug dua kali sebelum ditemukan akar masalahnya.

## Struktur Penambahan Halaman Baru (kalau benar-benar dibutuhkan)

1. Buat `pages/nama-halaman.html` dengan chrome block standar (copy dari halaman existing manapun: preview-banner, offline-banner, dev-panel — lihat markup identik di 5 halaman existing).
2. Buat `assets/js/nama-halaman.js`, load setelah `chrome.js`, panggil `window.JudgeChrome.init()` di awal.
3. Tambahkan fungsi navigasi terkait di `navigation.js` kalau perlu (`goToNamaHalaman()`).
4. Update `architecture/system-overview.md` §Struktur File.
5. Kalau halaman baru punya guard/business rule baru, tambahkan ke `srs/fr-judging-flow.md`.

## Testing Manual (tidak ada automated test di prototype ini)

Setiap perubahan yang menyentuh navigasi/state wajib diverifikasi manual di browser (bukan cuma dibaca kodenya):
1. Buka lewat `file://` langsung (double-click) — pastikan tidak ada console error.
2. Buka lewat `start-server.command` juga — pastikan behavior identik.
3. Test refresh persistence (isi skor → reload → cek tetap ada).
4. Test guard (buka `submitted.html` sebelum submit → harus redirect; `scoring.html?id=999` → harus redirect).
5. Cek 4 breakpoint acuan (`srs/nfr.md` §Responsive) — screenshot, bukan cuma resize window sekilas.

Lihat `HANDOFF.md` bagian "Test results" untuk contoh laporan testing yang diharapkan formatnya.
