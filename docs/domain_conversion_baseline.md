# Domain Conversion Baseline (Wave 0 — PR-000C)

> Tanggal: 2026-10-29
> Base remote: `origin/main b916481` (PR #450)
> Branch kerja: `feat/collateral-domain-nyata`
> Tujuan: titik acuan sebelum konversi domain lanjutan. Semua PR domain
> berikutnya wajib hijau terhadap baseline ini atau lebih baik.

## Gate

- `check_manifest`: 605 COBOL sources, 599 route files, 682 dispatch — PASSED
- `check_route_conflicts`: 10 known duplicate, 0 shadow baru — PASSED
- `check_action_coverage`: 5341 actions covered, 1 known gap (KCP_UPDATE) — PASSED
- `check_route_auth`: 2946 mutating guarded, 8 public exemptions — PASSED
- `check_suite_coverage`: 519 DB suites match baseline — PASSED
- `check_test_helpers`: semua `db_*` helper defined — PASSED
- `check_warnings`: 0 core warnings (collateral_core 0/0) — PASSED
- `cobol_table_tests`: 2733/2733 — PASSED
- `middleware test`: 741/741 — PASSED (diukur sebelum Wave 0 formal)

## Pilot Collateral (acuan pola)

- Migrasi: `0648_collateral_domain`, `0649_collateral_gl` — applied
- `collateral_domain_db_tests`: 30/30
- `collateral_db_tests` (legacy): 13/13
- `collateral_loan_flow`: 11/11
- GL accounts: 1510/4210/5210; journal balanced via `GL_JOURNAL_POST`

## Template test per domain

- Table: `tests/cobol/cases/<domain>.cases` (validasi tanpa DB)
- DB: `tests/db/<domain>_db_tests.sh` + `db_reset_<domain>` di `tests/lib/db.sh` + entry `tests/baseline_counts.txt`
- Integration: `tests/integration/<domain>_flow.sh` (min 2 core)
- Gateway: route auth + field order via `middleware/test`

## Aturan

- Jangan turunkan angka di atas tanpa persetujuan + update dokumen ini.
- Setiap PR domain update baseline bila menambah suite (tambah entry, bukan hapus).
- `run_all.sh full` tetap DoD final sebelum merge ke main.
