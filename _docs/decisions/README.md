# Architecture Decision Records — KREEN Judge Panel Prototype

## Kapan bikin ADR baru

Bikin ADR baru kalau mengubah/menambah:
- Pola arsitektur inti (state management, navigasi, struktur file)
- Constraint teknis yang mempengaruhi semua halaman (mis. kalau `file://`-compatibility harus dikorbankan demi fitur tertentu)
- Keputusan yang pernah dipertimbangkan dua arah dan salah satunya dipilih dengan alasan non-trivial

**Jangan** bikin ADR untuk keputusan visual kecil (itu masuk `design/design-system.md`) atau bugfix biasa.

## Index

| ADR | Judul | Status |
|---|---|---|
| [001](adr-001-multipage-localstorage.md) | Multi-page HTML + localStorage (bukan single-page + JS memory) | Accepted |
| [002](adr-002-file-protocol-compatibility.md) | `file://` compatibility wajib — no ES modules, no fetch, relative paths | Accepted |

Keputusan untuk implementasi produksi yang **belum** disetujui dicatat terpisah di [production-decisions-pending.md](production-decisions-pending.md). ADR prototype di atas tidak berarti arsitektur `localStorage`/`file://` harus dibawa ke Flutter.
