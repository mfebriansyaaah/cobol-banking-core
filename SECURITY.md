# Security Policy

## Supported versions

Only the current `main` branch is supported. There are no maintained release
branches or backports.

## Reporting a vulnerability

Do not open a public issue for a security vulnerability.

Use one of these private channels:

1. GitHub Security Advisories for this repository, or
2. Contact the repository owner directly through the GitHub account
   `@mfebriansyaaah`.

Include:

- affected component and version/commit,
- reproduction steps or a proof of concept,
- impact and attack preconditions,
- any suggested fix or mitigation.

Do not include real customer data, credentials, or production secrets in the
report. Use synthetic examples.

## Scope

In scope:

- authentication, session, MFA, and step-up flows,
- authorization and role checks,
- wallet, transfer, ledger, and reconciliation invariants,
- SQL handling in the COBOL bridge and gateway,
- secret handling and configuration guards,
- PII exposure in logs, errors, and responses.

Out of scope:

- findings that require a compromised host or database administrator,
- denial of service that only affects a local development environment,
- generated test fixtures that contain synthetic data.

## Security controls in this repository

- `scripts/ci/sast.sh` and `scripts/ci/sast_extra.sh` scan for SQL injection and
  auth-bypass patterns.
- `tests/probes/run_probes.sh` verifies that the gates detect deliberately
  broken routes, bind slots, and DB inventory.
- `tests/run_all.sh full` covers table cases, DB suites, gateway tests,
  integration, fuzz, migration-apply and schema-rebuild drills, and performance.
- `scripts/ci/coverage.sh` measures gateway coverage and a curated COBOL core
  floor; see [docs/COVERAGE.md](docs/COVERAGE.md).
- Production configuration refuses development secrets and development
  database defaults.
- New passwords (signup, reset, change) are checked against Pwned Passwords
  via k-anonymity (5-char prefix only; full password/hash never leaves the
  process). Breached -> `BREACHED_PASSWORD` (400); API down -> fail open
  with a metric (rate limits still apply). Enforced when `PWNED_ENFORCE=1`
  or in production (unless `PWNED_DISABLE=1`); unit suites stay offline
  without an explicit `PWNED_ENDPOINT`.

## Branch protection exception

The repository is private on GitHub Free, where branch protection and rulesets
are unavailable. The approved exception and compensating controls are in
[docs/GOVERNANCE.md](docs/GOVERNANCE.md). The lack of server-side enforcement is
a known risk; merge discipline and CI are the controls.

## AI review

AI code review is not enabled until the owner approves a tool and the data
handling policy. Treat AI review as not implemented until that approval is
recorded in the repository governance notes.

## Disclosure

We aim to acknowledge a report within a reasonable time and coordinate a fix
and disclosure date with the reporter. Do not disclose the issue publicly
before coordination.
