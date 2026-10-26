# Rencana Konversi 14 Skeleton Module → Real SQL-backed

## Ringkasan
- **14 skeleton module** tersisa (auth_password & hashlen adalah utility, bukan domain).
- Setiap modul: ~161 action stub → ~9 real SQL-backed action.
- Pola standar: copy dari `report_builder_core.cob` atau `backup_drill_core.cob`, sesuaikan domain.

## Grup Prioritas

### Grup A — Compliance & Risk (P1)
| # | Modul | Prefix | Tabel | Est. Effort | Dependensi |
|---|---|---|---|---|---|
| 1 | `aml_screening` | AML_ | aml_screening, aml_screening_audit | 1 PR | loan_application, customer |
| 2 | `sanctions_list` | SCL_ | sanctions_list, sanctions_list_audit | 1 PR | (standalone) |
| 3 | `fraud_case` | FRC_ | fraud_case, fraud_case_audit | 1 PR | transaction, account |

### Grup B — Finance & Accounting (P1)
| # | Modul | Prefix | Tabel | Est. Effort | Dependensi |
|---|---|---|---|---|---|
| 4 | `cost_center` | CSC_ | cost_center, cost_center_audit | 1 PR | gl_allocation |
| 5 | `fixed_asset` | FAS_ | fixed_asset, fixed_asset_audit | 1 PR | cost_center |
| 6 | `consolidation` | CNS_ | consolidation, consolidation_audit | 1 PR | cost_center, fixed_asset |

### Grup C — Treasury & FX (P2)
| # | Modul | Prefix | Tabel | Est. Effort | Dependensi |
|---|---|---|---|---|---|
| 7 | `fx_hedging` | FXH_ | fx_hedging, fx_hedging_audit | 1 PR | fx_deal, treasury |
| 8 | `billpay` | BLP_ | billpay, billpay_audit | 1 PR | payment_clearing |

### Grup D — IT Ops & Data (P2)
| # | Modul | Prefix | Tabel | Est. Effort | Dependensi |
|---|---|---|---|---|---|
| 9 | `incident_postmortem` | IPM_ | incident_postmortem, audit | 1 PR | incident_core |
| 10 | `change_approval` | CHA_ | change_approval, audit | 1 PR | (standalone) |
| 11 | `capacity_forecast` | CFC_ | capacity_forecast, audit | 1 PR | (standalone) |
| 12 | `data_lineage` | DLN_ | data_lineage, audit | 1 PR | (standalone) |
| 13 | `metric_definition` | MDF_ | metric_definition, audit | 1 PR | (standalone) |
| 14 | `analytics_snapshot` | ASP_ | analytics_snapshot, audit | 1 PR | report_builder |

## Urutan Eksekusi (14 PR)

```
Sprint 1 (Compliance & Risk):
  PR 1: aml_screening (AML_)    → real logic + migration + route + tests
  PR 2: sanctions_list (SCL_)   → real logic + migration + route + tests
  PR 3: fraud_case (FRC_)       → real logic + migration + route + tests

Sprint 2 (Finance & Accounting):
  PR 4: cost_center (CSC_)      → real logic + migration + route + tests
  PR 5: fixed_asset (FAS_)      → real logic + migration + route + tests
  PR 6: consolidation (CNS_)    → real logic + migration + route + tests

Sprint 3 (Treasury & Payments):
  PR 7: fx_hedging (FXH_)       → real logic + migration + route + tests
  PR 8: billpay (BLP_)           → real logic + migration + route + tests

Sprint 4 (IT Ops & Data):
  PR 9:  incident_postmortem (IPM_)
  PR 10: change_approval (CHA_)
  PR 11: capacity_forecast (CFC_)
  PR 12: data_lineage (DLN_)
  PR 13: metric_definition (MDF_)
  PR 14: analytics_snapshot (ASP_)
```

## Template per PR (checklist)

Setiap PR harus memenuhi:

- [ ] Branch: `feat/<domain>-<modul>`
- [ ] Copy template dari `report_builder_core.cob` atau `backup_drill_core.cob`
- [ ] Ganti prefix action (e.g. AML_CREATE, AML_LIST, ...)
- [ ] Buat migration `011X_<modul>.sql` dengan tabel + audit table
- [ ] Buat route file `middleware/src/routes/<modul>.js`
- [ ] Daftarkan route di `middleware/src/routes/index.js`
- [ ] Buat test cases `tests/cobol/cases/<modul>.cases` (5 cases)
- [ ] Buat DB test `tests/db/<modul>_db_tests.sh` (13 tests)
- [ ] Daftarkan db_reset di `tests/lib/db.sh`
- [ ] Daftarkan di `tests/run_all.sh`
- [ ] Update `tests/baseline_counts.txt`
- [ ] Update `tests/warning_baseline.txt` (modul=0)
- [ ] Update `README.md` status table
- [ ] Regenerate manifest: `node scripts/generate_manifest.mjs`
- [ ] Build hijau: `./build.sh`
- [ ] Tests hijau: `tests/run_all.sh full`
- [ ] Commit + push + PR
- [ ] CI hijau → merge

## Estimasi Total
- **14 PR** × ~1 hari kerja = **~14 hari kerja**
- Setelah selesai: 108 real logic modul (94 + 14), 2 skeleton (auth_password, hashlen — utility)
- COBOL lines: ~85,000+ real logic

## Catatan
- `auth_password` dan `hashlen` adalah utility module, tidak perlu dikonversi (delegate ke auth_core / hash_lib).
- Setiap modul mengikuti pola 9 action: CREATE, LIST, GET, <DOMAIN_ACTION>, CLOSE, SUMMARY, AUDIT, VALIDATE.
- <DOMAIN_ACTION> disesuaikan per domain (e.g. AML_SCREEN, FAS_DEPRECIATE, CNS_CONSOLIDATE).
- Gunakan prefix 3-4 huruf + underscore untuk action names (max 10 chars untuk EVALUATE).