# Dataset Re-audit — Post-Remediation (P0–P2)

- Code HEAD: `84dd3c38` (`main`, merge PR #703)
- Date: 2026-11-17
- Baseline: audit `e62cec26` → P0 (PR #701) → P1 (PR #702) → P2 (PR #703)
- Plan: `/home/febri/.opencode/plan/cobol-banking-core-remediation-master-plan.md`

## What changed since the R-03 audit

| PR        | Scope                                                                                                                                                                                                                                                                                                                            |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| #701 (P0) | Export preflight guard, `train` profile (810 source files, 5 clone cluster excluded), schema dedupe 13 → 0 duplicates (466 unique tables)                                                                                                                                                                                        |
| #702 (P1) | `TRANSFER-LOGIC` duplicate fetch removed, 9 ESLint warnings → 0 (ratchet `--max-warnings 0`), docs truth (public repo + protection 404, 84 DB suites, 577 routes, CHANGELOG tags), `module_quality.json` (71 modul, 31 recommended), test images pinned (mailpit + clamav digest; minio → quay.io + documented quay-401 blocker) |
| #703 (P2) | `TRANSFER-LOGIC` 615 → 380 baris (4 helper, byte-identical move), dispatch `D-PARAM-MODE` (13× mode-1, 1× mode-3, 180× mode-2; `main_logic` EVALUATE), `LEGACY_TABLES.md` (466 tabel: 93 KEEP / 373 DBA_REVIEW, no DROP)                                                                                                         |

## Verification (this HEAD, local)

| Check                                         | Result                                                                                                   |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `./build.sh`                                  | sukses                                                                                                   |
| `npm run lint`                                | 0 problems (ratchet 0)                                                                                   |
| `npm run format:check`                        | bersih                                                                                                   |
| `npm run test:scripts`                        | 481/481 pass                                                                                             |
| `npm --prefix middleware run test:unit`       | 147/147 pass                                                                                             |
| `node scripts/check_docs.mjs`                 | OK (76 markdown, links valid)                                                                            |
| `node scripts/audit_complexity.mjs --check`   | OK (20 metrics)                                                                                          |
| `node scripts/check_schema_unique_tables.mjs` | OK (466 unique)                                                                                          |
| `node scripts/check_module_quality.mjs`       | OK (71 modules, 31 recommended)                                                                          |
| `tests/run_all.sh fast`                       | GREEN                                                                                                    |
| `tests/run_all.sh probes`                     | 17/17 detected                                                                                           |
| `gitleaks` worktree                           | 0 findings (backup fisik root-owned dilewati — lihat residual R-1)                                       |
| `semgrep`                                     | 0 findings                                                                                               |
| `shellcheck` + `shfmt`                        | clean                                                                                                    |
| Export `source`                               | 842 output (840 sumber + 2 metadata), gitleaks 0, `sha256sum -c` OK, 5 clone tetap ada (reproducibility) |
| Export `train`                                | 822 output (820 sumber + 2 metadata), gitleaks 0, `sha256sum -c` OK, 5 clone tidak ada                   |

Full `tests/run_all.sh full/db` dilimpahkan ke CI (butuh Docker/DDL); CI `main` hijau pada merge commit.

## Scores

| Dimensi         |                                                                                                                   Skor |
| --------------- | ---------------------------------------------------------------------------------------------------------------------: |
| Maintainability |                                                                                                               **8/10** |
| AI Data Value   |                                                                                                             **8.5/10** |
| Tier            |                                                                                                  **A — Solid & Clean** |
| Keputusan       | **Layak** untuk dataset internal/authorized use (sesuai `docs/DATASET_LICENSE_APPROVAL.md`; bukan redistribusi publik) |

## Residuals (bukan blocker rilis internal)

| ID  | Item                                                                                                                                            | Owner             | Bukti                                                                 |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- | --------------------------------------------------------------------- |
| R-1 | Backup fisik `backups/physical/full-20261024T180027Z/` (72 MB, root-owned) masih di workspace; butuh root untuk pindah ke lokasi terenkripsi    | Owner             | MP-01; gitignored + export memakai `git archive`, tidak masuk dataset |
| R-2 | Digest MinIO belum ter-pin (quay.io HTTP 401 tanpa auth di env ini); pakai `quay.io/minio/minio:latest` + catatan                               | Owner (quay auth) | MP-09; hanya dev-test                                                 |
| R-3 | `check_schema_drift.sh` live + `tests/run_all.sh full/db` butuh DB DDL-capable; CI hijau, lokal hanya fast/probes                               | DBA/CI            | CI `main`                                                             |
| R-4 | 40/71 modul FROZEN/REVIEW; 10 modul Tier-1 di bawah floor 70% — sudah diberi label di `module_quality.json`, `train` hanya untuk 31 recommended | Curator           | `manifest/module_quality.json`                                        |
| R-5 | `docs/PRODUCTION_READINESS.md` tetap NOT CERTIFIED (benar apa adanya; bukan target plan ini)                                                    | Owner             | —                                                                     |

## Sign-off

| Peran           | Nama | Tanggal | Tanda tangan/approval |
| --------------- | ---- | ------- | --------------------- |
| Owner           |      |         |                       |
| Data Curator    |      |         |                       |
| Senior Reviewer |      |         |                       |
| DBA             |      |         |                       |
