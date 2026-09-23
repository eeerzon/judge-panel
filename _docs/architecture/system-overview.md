# System Overview — KREEN Judge Panel Prototype

## Struktur File

```
judge-prototype/
  index.html               launcher dev-only (BUKAN entry point judge) — buka pages/standby.html untuk mulai flow nyata
  start-server.command     OPSIONAL — serve via http://localhost:8934, tidak wajib (semua file:// compatible)
  _legacy-single-page/     backup arsip prototype versi single-page sebelum Phase 6 (jangan edit, referensi historis saja)

  pages/
    standby.html           idle/lock screen
    contestants.html        grid 15 kontestan
    scoring.html             ?id=N wajib — satu kontestan per waktu
    review.html               list + summary + modal submit
    submitted.html             konfirmasi pasca-submit — DIJAGA guard

  assets/
    css/
      tokens.css            :root variables saja
      components.css         semua styling komponen + shell layout (2200+ baris, sengaja tidak dipecah lagi — lihat komentar di file itu)
      pages.css               tambahan khusus launcher/dev (preview banner, launcher card)
    js/
      mock-data.js            window.JudgePrototypeData — data statis (event/judge/round/15 kontestan/rubrik skor), TIDAK PERNAH dimutasi
      state.js                window.JudgeState — SATU-SATUNYA modul yang baca/tulis localStorage, semua business logic
      navigation.js           window.JudgeNav — semua fungsi pindah halaman + guard
      chrome.js               window.JudgeChrome — dev panel/offline banner/preview banner/connection status/standby timeout (dipakai semua halaman)
      standby.js, contestants.js, scoring.js, review.js, submitted.js
                              satu file per halaman, menghubungkan DOM halaman itu ke State+Nav
    images/                  15 foto banner kontestan + logo KQP
```

## Urutan Load Script (wajib, di semua halaman `pages/*.html`)

```html
<script src="../assets/js/mock-data.js"></script>
<script src="../assets/js/state.js"></script>
<script src="../assets/js/navigation.js"></script>
<script src="../assets/js/chrome.js"></script>
<script src="../assets/js/{nama-halaman}.js"></script>
```

Semua classic script (bukan `type="module"`) — urutan ini penting karena tiap file mengasumsikan global sebelumnya sudah ada (`window.JudgePrototypeData` → `window.JudgeState` → `window.JudgeNav` → `window.JudgeChrome` → logic halaman).

## State Model

**Satu sumber kebenaran:** `window.JudgeState` (di `state.js`), didukung oleh `localStorage` dengan key tunggal `kreenJudgePrototype`.

### Schema localStorage

```js
{
  scores: {
    "<contestantId>": {
      communication: number|null,
      confidence: number|null,
      substance: number|null,
      eveningGown: number|null,
      stagePresence: number|null
    },
    // ... untuk semua 15 id
  },
  notes: { "<contestantId>": string, ... },
  isSubmitted: boolean,
  submittedAt: string|null,   // ISO timestamp
  currentContestantId: number|null,
  connectionState: 'online'|'offline'|'syncing'|'synced',  // simulasi Phase 5
  simulateSaveFailure: boolean,   // simulasi Phase 5
  simulateSubmitFailure: boolean  // simulasi Phase 5
}
```

### Business Helpers (`window.JudgeState`, jangan duplikasi logic ini di tempat lain)

| Fungsi | Kegunaan |
|---|---|
| `getContestant(id)` | Ambil data statis kontestan dari `mock-data.js` |
| `getContestantScores(id)` | Ambil object skor kontestan dari state |
| `getContestantStatus(id)` | `{status, scoredCount, total}` — derived, bukan disimpan |
| `isContestantComplete(id)` | Boolean shortcut untuk `status === 'scored'` |
| `calculateContestantTotal(id)` | Formula weighted score, `null` kalau belum lengkap |
| `countByStatus()` | `{scored, draft, notStarted, total}` untuk semua kontestan |
| `areAllContestantsComplete()` | Gate untuk tombol submit |
| `isSubmitted()` | Boolean status submission |
| `setScore(id, key, value)` | Tulis satu nilai kriteria (no-op kalau sudah submitted) |
| `setNote(id, text)` | Tulis catatan kontestan (no-op kalau sudah submitted) |
| `submitJudging()` | Validasi ulang kelengkapan + set `isSubmitted`/`submittedAt` |
| `resetState()` | Kembalikan ke seed default (dipakai launcher "Reset Prototype State") |

**Aturan:** kalau halaman baru butuh fakta bisnis (status, total, kelengkapan), tambahkan fungsi baru di `state.js` — jangan hitung ulang secara lokal di file halaman.

## Navigation (`window.JudgeNav`)

Semua pindah halaman lewat `window.location.href` dengan **nama file relatif saja** (bukan URL absolut/`http://`):

```js
goToStandby()              // 'standby.html'
goToContestants()          // 'contestants.html'
goToScoring(id, from)      // 'scoring.html?id=' + id + '&from=' + from   // from: 'gallery'|'review'
goToReview()                // 'review.html'
goToSubmitted()             // 'submitted.html'
```

`from` menggantikan konsep "shared JS memory" yang ada di versi single-page lama — karena setiap `pages/*.html` adalah dokumen browser terpisah, tidak ada variabel JS yang bertahan lintas-navigasi kecuali lewat `localStorage` atau URL.

### Guard

```js
guardScoringId(rawId)   // null & redirect ke contestants.html kalau id invalid (kecuali ?preview=1)
guardSubmitted()        // redirect ke review.html kalau belum isSubmitted (kecuali ?preview=1)
isPreviewMode()         // true kalau ?preview=1 ada di URL
```

## Preview Mode

`?preview=1` di URL manapun di `pages/`:
- Bypass guard (`guardScoringId`/`guardSubmitted`).
- **Tidak pernah** menulis ke `localStorage` — render display-only.
- Menonaktifkan standby-inactivity-timeout (supaya reviewer tidak ter-lempar ke Standby saat sedang melihat halaman).
- `scoring.html?...&preview=1` selalu render read-only, terlepas dari `isSubmitted` sungguhan.
- `submitted.html?preview=1` render data mock ("15 contestants scored", "Submitted at 21:42") tanpa membaca state asli.

## `file://` Compatibility (kenapa prototype ini bisa dibuka double-click)

Lihat `decisions/adr-002-file-protocol-compatibility.md` untuk audit lengkap. Ringkasan constraint yang **wajib dipertahankan**:

- Tidak ada `type="module"`, `import`/`export`.
- Tidak ada `fetch`/`XMLHttpRequest` untuk data lokal.
- Tidak ada path absolut (`/assets/...`) — semua relatif terhadap file HTML (`../assets/...` dari `pages/`, `assets/...` dari root `index.html`).
- Navigasi selalu nama file relatif, tidak pernah `http://localhost` di-hardcode.

## Dev-Only Layer (bukan bagian produk, jangan dihilangkan asal-asalan)

- **Dev panel** (`chrome.js` + markup di tiap halaman): simulasi connection state, save/submit failure, force-standby, reset. Sengaja bergaya "debug tool" (monospace, dashed border) supaya tidak tertukar dengan UI produk.
- **Launcher** (`index.html` root): navigasi cepat untuk review — Normal Flow, Preview Screens (semua 5 halaman + `?preview=1`), Reset Prototype State.
- **`start-server.command`**: opsional, untuk test flow HTTP penuh — tidak diperlukan untuk review visual biasa.
