# ADR-002: `file://` Compatibility Wajib — No ES Modules, No Fetch, Relative Paths Saja

**Status:** Accepted (Phase 6, direvisi ulang setelah insiden salah diagnosis)

## Konteks

Setelah refactor ke multi-page (ADR-001), muncul laporan bahwa membuka `pages/scoring.html` lewat double-click di Finder menampilkan halaman tanpa styling/data sama sekali. Respons pertama terhadap laporan ini **salah**: langsung dianggap sebagai keterbatasan browser yang tidak bisa diperbaiki, lalu dipasang warning block "This prototype needs a local server" di semua halaman + `start-server.command` dijadikan seolah wajib.

User menolak solusi ini secara eksplisit — tujuan prototype ini adalah **file handoff**: bisa dibuka satu per satu, developer/client cukup double-click, tanpa install/run apapun.

## Audit Ulang

Audit kode menyeluruh (grep semua `pages/*.html`, `index.html`, `assets/js/*.js`) menemukan: **tidak ada satupun** hal berikut di codebase —
- `type="module"`, `import`, `export`
- `fetch(`, `XMLHttpRequest`
- Path absolut (`href="/`, `src="/`)
- URL absolut (`http://`, `localhost`) di navigasi

Artinya struktur kode **sudah** `file://`-compatible sejak awal — warning yang dipasang sebelumnya adalah reaksi berlebihan terhadap satu laporan bug yang gagal direproduksi ulang terhadap struktur kode yang sebenarnya (kemungkinan besar laporan awal berasal dari cara buka file yang berbeda, misalnya Finder Quick Look/preview pane yang punya sandbox JS terpisah dari browser sungguhan — bukan double-click-ke-browser biasa).

## Keputusan

**Tidak pernah menambahkan** hal-hal berikut ke codebase ini, secara permanen:

1. **ES modules** (`type="module"`, `import`/`export`) — behavior `file://` untuk ES module module resolution dibatasi/berbeda antar browser. Semua script tetap **classic script** (`<script src="...">`, IIFE-wrapped), urutan load eksplisit (lihat `architecture/system-overview.md`).
2. **`fetch`/`XMLHttpRequest`** untuk data lokal (HTML partial, JSON, config, asset) — semua data prototype hidup sebagai JS inline (`window.JudgePrototypeData` di `mock-data.js`), bukan file yang di-load via HTTP request.
3. **Path absolut** (`/assets/...`) — selalu relatif terhadap file HTML (`../assets/...` dari `pages/`, `assets/...` dari root).
4. **URL absolut di navigasi** (`http://localhost:8934/...`) — `navigation.js` selalu assign `window.location.href` ke nama file relatif saja (`'scoring.html?id=' + id`), tidak pernah full URL.

`localStorage` tetap dipakai untuk shared state (ADR-001) — dengan catatan behavior-nya belum diverifikasi identik di semua kombinasi browser (lihat `srs/nfr.md` §Browser Compatibility); `state.js` membungkus semua akses storage dengan `try/catch` + fallback ke default state supaya kegagalan storage **tidak pernah** membuat prototype crash, hanya membuatnya non-persistent untuk sesi itu.

`start-server.command` tetap disediakan sebagai **kenyamanan opsional** (untuk test flow HTTP penuh dengan persistensi terjamin), bukan requirement.

## Konsekuensi

- **Positif:** siapapun bisa buka file manapun langsung, tidak perlu tahu cara jalankan server, cocok untuk handoff ke client/developer non-teknis.
- **Negatif:** setiap penambahan fitur baru (termasuk oleh Codex) harus dicek dulu terhadap 4 larangan di atas sebelum ditambahkan — godaan umum yang harus dihindari: menambah bundler/build step, menambah dependency npm, atau memecah data ke file JSON terpisah yang di-`fetch`.
- **Pelajaran proses:** jangan menyimpulkan root cause dari asumsi platform security model tanpa audit kode aktual dulu — lihat riwayat insiden ini di `HANDOFF.md` untuk detail lengkap kronologi salah-diagnosis → koreksi.
