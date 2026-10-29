# Changelog

All notable changes to this repository are recorded here. This project does
not publish versioned releases yet; entries are grouped by date on `main`.

## Unreleased

### Added

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
