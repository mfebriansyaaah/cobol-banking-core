# Domain Data Audit (Wave 0 — PR-000D)

> Tanggal: 2026-10-29
> DB: `cobol_db` lokal (test fixtures, bukan produksi)
> Tujuan: putuskan drop vs migrate sebelum PR schema tiap domain.

## Hasil (COUNT(*), test DB)

| Tabel | Rows | Bentuk | Keputusan |
|---|---|---|---|
| `collateral` | 2 | domain (valuation/pledge/allocation added 0648) | KEEP — kanonik |
| `collateral_mgmt` | 1 | adapted (pledged_value/haircut) | KEEP compat, deprecated; drop setelah 1 siklus |
| `collateral_repossession` | 1 | generik (`budget_amount`) | KEEP compat, deprecated; pengganti nyata = status di `collateral` + GL link |
| `collateralized` | 1 | generik/produk | KEEP compat, deprecated |
| `letter_of_credit` | 1 | domain (lc_amount/drawn) | KEEP — seed Trade Finance |
| `bank_guarantee` | 1 | domain (guarantee/claimed) | KEEP — seed Trade Finance |
| `merchant` | 1 | domain (volume/settled) | KEEP — seed Merchant |
| `merchant_settlement` | 1 | domain (settlement/paid) | KEEP — seed Merchant |
| `tax_management` | 1 | domain (max/collected) | KEEP — seed Tax |
| `tax_withholding` | 1 | generik | DEPRECATED; desain ulang di PR-401 |
| `chargeback` | 1 | generik | DEPRECATED; desain ulang di PR-501 |
| `payroll_processing` | 1 | domain (total/processed) | KEEP — seed Payroll |
| `fixed_asset` | 1 | domain (cost/depreciation) | KEEP — seed Fixed Asset |
| `loyalty_program` | 1 | generik | DEPRECATED; desain ulang di PR-801 |

## Aturan

- Test DB hanya fixtures; tidak ada data bisnis nyata yang perlu migrasi.
- Jangan DROP tabel legacy di PR yang sama dengan pengenalan tabel baru.
- Drop fisik hanya setelah: 1) route alias 1 siklus, 2) konsumen pindah, 3) backup + rollback drill.
- Setiap PR schema wajib cantumkan query verifikasi: row count, orphan check, duplicate ref.
