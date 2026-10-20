# Security Audit — KREEN Judge (app Flutter + API + web)

**Tanggal:** 20 Oktober 2026 (audit awal + audit ulang di hari yang sama)
**Cakupan:** app Flutter `judge-mobile` (iOS, Android, web), web build di `judge.kreen.asia`, API `https://newvote.kreenconnect.com/api/v1` (staging).
**Jenis:** audit. Setelah audit awal, hanya **H2** yang diperbaiki (atas permintaan). Temuan lain belum diperbaiki.

## Metode

- Review kode app: penyimpanan token, login/logout, konfigurasi platform, kredensial di source, isi web bundle.
- Pengecekan server **hanya baca (GET)**: header HTTP, CORS, file yang terekspos, pesan error.
- Uji otorisasi: login dengan akun test juri (`juri1.free@test.com`), lalu mencoba endpoint admin dan round yang tidak ditugaskan. Tidak ada data yang diubah.
- **Tidak diuji:** endpoint yang mengubah data (POST/PUT/PATCH/DELETE), akses lintas merchant (multi-tenant), fuzzing/SQL injection, alur reset password, dan infrastruktur server. Lihat [Belum diuji](#belum-diuji).

## Ringkasan

| ID | Temuan | Tingkat | Status (audit ulang) |
|---|---|---|---|
| H1 | Password akun admin asli tertulis di source code dan git history | **Tinggi** | ⚠️ Sebagian: sudah dihapus dari source (belum di-commit), **masih ada di git history** |
| H2 | Logout di app tidak mencabut token di server | **Tinggi** | ✅ **Diperbaiki** dan diverifikasi ke server |
| H3 | Token login disimpan tanpa enkripsi (web: `localStorage`; Android: ikut backup) | **Tinggi** | ❌ Belum |
| M1 | Halaman hasil publik bisa dibuka siapa pun yang tahu slug event | Sedang | ❌ Belum |
| M2 | API dan web bisa diakses lewat HTTP biasa tanpa redirect ke HTTPS, tanpa HSTS | Sedang | ❌ Belum |
| M3 | Web `judge.kreen.asia` tanpa header keamanan; versi nginx terlihat | Sedang | ❌ Belum |
| M4 | CORS `*` di semua endpoint API, termasuk admin | Sedang | ❌ Belum |
| M5 | Batas percobaan login perlu dipastikan cukup ketat | Sedang | ❓ Belum diverifikasi |
| L1 | File `.DS_Store` bisa diunduh dari web | Rendah | ❌ Belum |
| L2 | URL API default di app mengarah ke staging | Rendah | ❌ Belum |
| L3 | Aturan password juri hanya dicek di app (minimal 8 karakter) | Rendah | ❓ Belum diverifikasi |
| L4 | Gambar dari URL API dimuat sebagai elemen `<img>` di web | Rendah | ❌ Belum |
| L5 | JWT HS256: keamanan bergantung pada kerahasiaan secret server | Rendah | ❓ Belum diverifikasi |

## Temuan

### H1 — Password akun admin asli tertulis di source code dan git history

**Lokasi:** `judge-mobile/lib/screens/login_screen.dart` baris 24–33. Masuk ke git history lewat commit `85f028f`.

```dart
('sandikafamily3@gmail.com', 'namakau123', ' (Admin)'),
```

Daftar "Demo access" berisi email dan password akun admin asli. Daftar ini disembunyikan dengan `kShowDemoAccounts = false`. Saya sudah memastikan string tersebut **tidak ada** di `build/web/main.dart.js`, jadi web yang sudah di-deploy aman.

**Risiko:** siapa pun yang menerima source code (developer lain, Codex, vendor, repo yang suatu saat di-push) langsung mendapat akses admin penuh. Ini termasuk melihat dan mengubah semua event, juri, kriteria, hasil, dan advancement. Menghapus baris dari kode **tidak** menghapusnya dari git history.

**Rekomendasi:** ganti password akun tersebut. Hapus daftar demo dari source. Bersihkan history (`git filter-repo`) sebelum repo dibagikan. Simpan akun test di luar repo.

**Audit ulang:** daftar akun dan password sudah **dihapus dari `login_screen.dart`**, tapi perubahan ini belum di-commit. Password itu **masih ada di git history** (commit `85f028f`). Web bundle baru juga dicek ulang dan bersih. Yang tersisa: ganti password akun tersebut (paling penting, karena history tidak bisa ditarik dari orang yang sudah menerimanya) dan bersihkan history sebelum repo dibagikan. Sisa kecil: widget `_DemoButton` sekarang tidak terpakai (peringatan analyzer).

### H2 — Logout di app tidak mencabut token di server

**Lokasi:** `judge-mobile/lib/state/session_store.dart`, fungsi `logout()`. Fungsi ini hanya menghapus token dari perangkat.

**Bukti:** server punya `POST /judge/auth/logout`, dan endpoint itu bekerja. Setelah dipanggil, token yang sama langsung ditolak (`401`). Tapi app **tidak pernah memanggilnya**: di `judge_api.dart` hanya ada `/judge/auth/login`.

**Risiko:** token yang sudah "logout" tetap berlaku sampai kedaluwarsa (`expires_in` 86400 = 24 jam). Tablet juri sering dipakai bergantian. Kalau token sempat tersalin (lihat H3), orang lain tetap bisa memakainya setelah juri logout, termasuk mengisi atau mengubah nilai atas nama juri itu.

**Rekomendasi:** panggil `POST /judge/auth/logout` saat logout. Pertimbangkan masa berlaku token yang lebih pendek ditambah refresh token.

**Perbaikan (audit ulang) — ✅ selesai:**
- `SessionStore.logout()` (`lib/state/session_store.dart`) sekarang mengirim `POST /judge/auth/logout` setiap kali pengguna menekan **Log Out**, di Judge Mode, Admin, dan Mode Selector.
- Sesi di perangkat tetap langsung dihapus. Request ke server berjalan di belakang, jadi tombol Log Out tidak terasa lambat.
- Token dikirim langsung ke request logout (`JudgeApi.logout(token)`, `ApiClient.postWithToken`), karena saat itu sesi di perangkat sudah kosong.
- Tidak dikirim saat sesi berakhir karena server sudah menolak token (`401`) atau token sudah kedaluwarsa, karena token itu sudah tidak berlaku.

**Verifikasi:**
- Ke server asli, memakai kode app dengan akun test juri: token dijawab `200` sebelum Log Out dan **`401` setelah Log Out**.
- Tes otomatis baru: `test/session_logout_test.dart`.
- `main.dart.js` hasil build terbaru memuat panggilan `/judge/auth/logout`.

**Sisa risiko:** kalau perangkat **offline** saat Log Out, request ke server gagal dan token tetap berlaku sampai kedaluwarsa (maksimal 24 jam). Untuk menutup celah ini, perlu masa berlaku token yang lebih pendek atau logout yang dicoba ulang saat online.

### H3 — Token login disimpan tanpa enkripsi

**Lokasi:** `judge-mobile/lib/state/session_store.dart`. Kodenya sendiri sudah memberi catatan "Move it to secure storage". Token disimpan di `SharedPreferences`.

| Platform | Di mana token tersimpan | Siapa yang bisa membaca |
|---|---|---|
| Web | `localStorage` browser | Script apa pun di domain `judge.kreen.asia`, ekstensi browser, siapa pun yang memegang laptop/HP itu |
| Android | File XML di folder app | Backup perangkat: `android:allowBackup` tidak diatur di `AndroidManifest.xml`, jadi default-nya **aktif**. Juga perangkat yang di-root. |
| iOS | `NSUserDefaults` | Ikut backup iCloud/iTunes |

**Risiko:** token admin yang bocor memberi akses penuh selama 24 jam. Ini diperparah oleh H2 dan M4.

**Rekomendasi:** gunakan `flutter_secure_storage` (Keychain/Keystore) di iOS dan Android. Set `android:allowBackup="false"`. Di web, pertimbangkan token yang lebih singkat atau cookie `HttpOnly` dari server.

### M1 — Halaman hasil publik bisa dibuka siapa pun yang tahu slug event

**Endpoint:** `GET /judge/public/events/{slug}/results?round=N`, tanpa login.

Begitu sebuah round **Finalized**, siapa pun bisa melihat nilai **setiap juri per kriteria** untuk semua finalis. Satu-satunya "kunci" adalah slug, padahal slug bukan rahasia: slug yang sama dipakai di URL halaman vote publik, dan mudah ditebak (contoh `testing_stripe_auto`). Admin juga tidak perlu menekan "Copy Public Link" dulu supaya halaman itu bisa dibuka.

Nama dan email juri **tidak** dikirim, dan itu sudah benar. Ada dua catatan anonimitas:
- Label "Juri 1, Juri 2, Juri 3" konsisten di semua kontestan. Kalau susunan panel juri diketahui publik dan urutan nomornya bisa ditebak (misalnya urutan penugasan), identitas per nomor bisa disimpulkan.
- Round dengan **satu juri** otomatis memperlihatkan nilai juri itu.

**Rekomendasi:** pastikan ini keputusan bisnis yang disadari. Pertimbangkan tombol "Publish public results" terpisah per round, dan/atau token acak di link (bukan slug saja). Acak urutan nomor juri per round. Pastikan `result_visibility` atau flag publish ikut dicek server (belum saya verifikasi).

### M2 — API dan web bisa diakses lewat HTTP tanpa redirect ke HTTPS

**Bukti:**
- `http://newvote.kreenconnect.com/api/v1/...` dijawab `200`, tidak diarahkan ke HTTPS.
- `http://judge.kreen.asia/` dijawab `200`.
- Tidak ada header `Strict-Transport-Security` di keduanya.

App sendiri memakai `https://`. Risikonya muncul kalau ada link `http://` yang beredar (misalnya link hasil yang diketik ulang), atau build memakai URL `http` lewat `--dart-define`. Di WiFi publik (venue acara), token dan password bisa disadap.

**Rekomendasi:** redirect permanen (301) dari HTTP ke HTTPS di nginx, lalu tambahkan HSTS.

### M3 — Web `judge.kreen.asia` tanpa header keamanan

Respons hanya membawa `Server: nginx/1.22.1` dan `Content-Type`. Yang tidak ada:
- `Content-Security-Policy`, untuk membatasi script/gambar dari domain lain. Ini memperkecil dampak H3.
- `X-Frame-Options` / `frame-ancestors`. Tanpa ini, halaman admin bisa disisipkan diam-diam di situs lain (clickjacking).
- `Strict-Transport-Security` dan `Referrer-Policy`.

Versi nginx juga terlihat (1.22.1, rilis 2022). Pastikan patch untuk CVE-2023-44487 (HTTP/2 Rapid Reset) sudah diterapkan kalau HTTP/2 aktif, dan sembunyikan versi dengan `server_tokens off`.

### M4 — CORS `*` di semua endpoint API, termasuk admin

Semua respons API, termasuk preflight untuk `PATCH` endpoint admin, membawa `Access-Control-Allow-Origin: *` dan mengizinkan header `Authorization`.

Token dikirim lewat header, bukan cookie, jadi ini **bukan** celah CSRF. Tapi tidak ada pembatasan asal: situs mana pun yang memegang token curian (H3) bisa langsung memanggil semua endpoint dari browser korban.

**Rekomendasi:** batasi origin ke `https://judge.kreen.asia` (dan domain resmi lain). Endpoint publik boleh tetap `*`.

### M5 — Batas percobaan login perlu dipastikan

Yang terlihat: header `X-RateLimit-Limit: 60` (per menit), dan sebelumnya login sempat kena `429 Too Many Attempts`. Jadi pembatasan sudah ada.

Yang perlu dipastikan: apakah batasnya per akun atau hanya per IP. Dengan 60 percobaan per menit per IP, penyerang yang memakai banyak IP masih bisa mencoba banyak password terhadap satu email admin.

**Rekomendasi:** batasi percobaan login gagal **per akun** (misalnya kunci 15 menit setelah 5–10 gagal), dan catat login gagal di log.

### L1 — File `.DS_Store` bisa diunduh dari web

`https://judge.kreen.asia/.DS_Store` dijawab `200` (6 KB). Isinya daftar nama folder, sama dengan yang ada di `build/web` repo. Dampaknya kecil karena isinya hanya nama folder build Flutter, tapi file ini tidak perlu ada.

**Rekomendasi:** hapus dari repo output dan server. Tambahkan `.DS_Store` ke `.gitignore` dan blokir file berawalan titik di nginx.

### L2 — URL API default di app mengarah ke staging

`judge-mobile/lib/api/api_client.dart`:
```dart
defaultValue: 'https://newvote.kreenconnect.com/api/v1', //staging
// defaultValue: 'https://vote.kreen.asia/api/v1', //live
```
Kalau build produksi lupa diberi `--dart-define=KREEN_API_BASE_URL=…`, app produksi memakai staging. Akibatnya data juri dan nilai asli bisa masuk ke server staging, yang biasanya penjagaannya lebih longgar.

**Rekomendasi:** tetapkan URL produksi secara eksplisit per build (flavor atau dart-define wajib), dan tampilkan nama environment di app untuk build non-produksi.

### L3 — Aturan password juri hanya dicek di app

`judge-mobile/lib/admin/screens/masters_screen.dart:286` mengecek password minimal 8 karakter di app. Pastikan server juga memvalidasi panjang dan kekuatan password, karena request bisa dikirim tanpa lewat app.

### L4 — Gambar dari URL API dimuat sebagai elemen `<img>` di web

Di web, poster finalis, banner, dan background dimuat dengan `WebHtmlElementStrategy.fallback` (5 tempat), sehingga browser mengambil gambar dari URL apa pun yang dikirim API. Kalau seseorang bisa mengisi URL poster ke domain miliknya, ia bisa mencatat IP dan waktu setiap juri/peserta yang membuka halaman. Ini tidak memberi akses ke data.

**Rekomendasi:** batasi di server URL gambar hanya ke domain KREEN.

### L5 — JWT HS256: keamanan bergantung pada secret server

Token memakai `HS256`, berlaku 24 jam (`exp − iat = 86400`). Ini aman selama secret JWT di server panjang, acak, dan tidak pernah masuk repo. Kalau ada kebocoran (lihat H1 untuk pola yang sama), ganti secret: semua token lama otomatis tidak berlaku.

## Yang sudah aman (diverifikasi)

| Pengecekan | Hasil |
|---|---|
| Token **juri** ke endpoint admin (dashboard, event, judges, monitoring, results) | `403`, ditolak berdasarkan capability |
| Juri membuka round yang tidak ditugaskan (detail, kontestan, hasil) | `403` "Kamu tidak ditugaskan ke ronde ini." |
| Juri melihat hasil round sendiri saat visibility mati | `403` "Hasil ronde ini belum ditampilkan oleh admin." |
| Token palsu / sudah logout | `401` |
| Pesan error saat input aneh (`round=1'`, `round[]=1`) | Hanya pesan validasi, tanpa stack trace (debug mode tidak aktif) |
| Data di endpoint publik | Tidak ada nama, email, atau ID juri |
| Rahasia di web bundle (`main.dart.js`) | Tidak ditemukan password atau email akun |
| File sensitif di web (`.git`, `.env`, source map) | `404` |
| Konfigurasi iOS | Tidak ada `NSAllowsArbitraryLoads` |
| Header API | `X-Content-Type-Options: nosniff` ada |

## Belum diuji

Area berikut perlu diuji terpisah, sebaiknya di server staging dengan data dummy:

1. **Akses lintas merchant (multi-tenant).** Data membawa `id_merchant`. Perlu dicek apakah admin merchant A bisa membuka, mengubah, atau menghapus event, round, juri, atau hasil milik merchant B dengan menebak ID. Butuh dua akun admin dari merchant berbeda. **Ini prioritas tertinggi untuk diuji berikutnya.**
2. **Endpoint tulis dari sisi juri.** Apakah juri bisa menyimpan nilai ke round yang tidak ditugaskan, ke score sheet juri lain, setelah submit, atau setelah round Closed, dengan memanggil API langsung tanpa app.
3. **Validasi nilai di server.** Nilai di luar rentang min/max kriteria, nilai negatif, atau nilai bukan angka.
4. **Endpoint admin yang mengubah data.** Validasi input (misalnya advancement memilih kontestan dari round lain) dan pencatatan audit di server.
5. **Reset password dan alur akun lain** di luar app ini.
6. **Infrastruktur:** versi PHP/Laravel, patch OS, akses SSH, backup database.

## Audit ulang (20 Oktober 2026)

Setelah H2 diperbaiki, semua temuan dicek ulang dengan cara yang sama:

| Pengecekan | Hasil |
|---|---|
| Log Out lewat kode app → token lama ke `GET /judge/rounds` | `401` ✅ (sebelum Log Out: `200`) |
| Password/email akun di `login_screen.dart` | Tidak ada lagi (belum di-commit) |
| Password di git history | Masih ada (`85f028f`) |
| Password/email di `build/web/main.dart.js` baru | Tidak ada |
| `allowBackup` / secure storage | Belum diatur; token masih di `SharedPreferences` |
| `http://` API dan web | Masih `200`, tanpa redirect |
| Header keamanan `judge.kreen.asia` | Masih hanya `Server: nginx/1.22.1` |
| CORS endpoint admin | Masih `Access-Control-Allow-Origin: *` |
| `https://judge.kreen.asia/.DS_Store` | Masih `200` |
| URL API default | Masih staging |

Catatan: build web yang berisi perbaikan H2 baru ada di lokal (`build/web`) dan **belum di-deploy** ke `judge.kreen.asia`. Pengguna web di server baru mendapat perbaikan ini setelah deploy. App iOS/Android baru mendapatkannya setelah build baru dipasang.

## Urutan perbaikan yang disarankan

1. **H1:** ganti password admin hari ini, sebelum repo dibagikan ke siapa pun; bersihkan git history.
2. **H3:** token pindah ke secure storage; `allowBackup` dimatikan. (H2 sudah selesai.)
3. **M2 dan M3:** redirect HTTPS, HSTS, dan header keamanan di nginx (perubahan konfigurasi kecil).
4. **M1:** putuskan aturan publikasi hasil.
5. **Uji multi-tenant** (Belum diuji #1).
6. Sisanya (M4, M5, L1–L5) secara bertahap.
