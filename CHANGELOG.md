# Changelog

All notable changes to this repository are recorded here. Versioned tags
exist (`v1.0.1`, `v1.1.0`); entries below are grouped by date on `main`.

## Unreleased

### Added

- DRY remediation wave (maint-13a–13l, 14, 15E/15F): shared copybooks for
  trim/result/validate/auth/entry/outbox/family working-storage, SQL exec
  wrappers with a bind-slot gate (1314 → 82 inline CALL sites, 1300 wrapper
  PERFORMs), ADMIN-GUARD, TXN-FINISH, idempotency assessment close-out, and
  the clone-template freeze decision (`docs/adr/0012-*`, `docs/adr/0013-*`).
- Coverage gates for the copybooks union (`tests/coverage_copybook_baseline.txt`,
  union hit-if-any-host) and per-module ratchet
  (`tests/coverage_module_baseline.txt`), with the COBOL total floor-only
  (see `docs/COVERAGE.md`).
- Gate unit-test pins for every new gate and contract
  (`scripts/test/check_bind_slots_wrapper.test.mjs`,
  `scripts/test/copybook_sql_exec.test.mjs`,
  `scripts/test/coverage_summary.test.mjs`).
- Coverage gate for the gateway and a curated COBOL core, with a nightly full
  report and a PR gateway check (`scripts/ci/coverage.sh`,
  `tests/coverage_baseline.txt`, `docs/COVERAGE.md`).
- Generated repository status, module index, and README statistics
  (`scripts/docs_stats.mjs`, `docs/STATUS.md`, `docs/MODULE_INDEX.md`).
- Documentation drift and local-link checker (`scripts/check_docs.mjs`).
- JWT/refresh secret-rotation runbook (`docs/runbooks/secret-rotation.md`).
- Contributing, security, and changelog documents.
- Issue templates for bug reports and feature requests.
- Route-order regression tests for static-vs-parameterized routes.

### Changed

- Phase 2 maintainability ratchet: 14 JavaScript hotspots above complexity 20
  were split into named helpers across the gateway adapters, integration
  services, and tooling. ESLint's complexity threshold moved from 25 to 20
  (`--max-warnings 0`), so new hotspots fail lint instead of accumulating.
- README now reports generated counts instead of hand-maintained numbers.
- CI runs on Node 24 for built-in test coverage support.
- Gateway coverage runs in a dedicated CI job with a fresh database.
- Coverage and documentation checks are part of the local pre-merge gate where
  practical.

### Fixed

- Parameterized routes that shadowed static endpoints in generated domains.
- Generated route clashes in the reconciliation, transaction, metrics,
  procurement, alert, change, and incident domains.
- Wave dispatch-count mismatches that left action prefixes unreachable.

### Security

- Documented the branch-protection exception and compensating controls.
- Added a proprietary license and a private vulnerability-reporting policy.
- Added a sanitized archive procedure for personal author metadata.
