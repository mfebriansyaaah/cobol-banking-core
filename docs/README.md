# Documentation Index

Single entry point for `docs/`. Everything listed here is **living
documentation** — current and maintained. Historical records live in
[`archive/`](archive/README.md) and are not listed here.

Conventions: root docs use `UPPER_SNAKE.md`; `runbooks/` and `adr/`
use kebab-case. Numbers that a script can compute are generated and
gated (see [ADR-0007](adr/0007-generated-docs.md)); prose explains,
never counts. Every document below must stay linked here — enforced by
`scripts/check_docs.mjs` (docs index coverage).

## Start here

| Document | About |
| --- | --- |
| [domain_overview](DOMAIN_OVERVIEW.md) | System overview: gateway, COBOL core, bridge, database |
| [GOVERNANCE](GOVERNANCE.md) | Governance and merge policy |
| [BRANCHING](BRANCHING.md) | Branching and merge model |
| [OWNERSHIP](OWNERSHIP.md) | Code and docs ownership |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | How to contribute |

## Architecture & design

| Document | About |
| --- | --- |
| [DATA_MODEL](DATA_MODEL.md) | Data model and table ownership |
| [data_dictionary](DATA_DICTIONARY.md) | Column catalogue, generated from `database/schema.sql` |
| [module_classification](MODULE_CLASSIFICATION.md) | Module tier classification (Tier 1/2/3) |
| [module_authoring](MODULE_AUTHORING.md) | Guide for authoring new COBOL modules |
| [TIER1_LINKAGE](TIER1_LINKAGE.md) | Tier-1 linkage levels and evidence |
| [CODE_CANDIDATES](CODE_CANDIDATES.md) | Refactor candidates tracked against the manifest |
| [MODULE_INDEX](MODULE_INDEX.md) | Generated module inventory |
| [MODULE_QUALITY](MODULE_QUALITY.md) | Generated per-module quality rollup |
| [ACTION_REGISTRY](ACTION_REGISTRY.md) | Action registry (PR-050) |
| [ACTION_TEST_COVERAGE](ACTION_TEST_COVERAGE.md) | Action test coverage triage and burndown |
| [openapi.yaml](openapi.yaml) | Generated REST API reference (not hand-edited) |

## Delivery: CI, testing, coverage

| Document | About |
| --- | --- |
| [CI](CI.md) | CI status, jobs, and gates |
| [CI_RUNNERS](CI_RUNNERS.md) | CI runner capacity and pinning proposal |
| [TESTING](TESTING.md) | Local database setup and test safety model |
| [COVERAGE](COVERAGE.md) | Coverage gates and curated-set policy |
| [COMPLEXITY_BASELINE](COMPLEXITY_BASELINE.md) | Generated complexity baseline |
| [RELEASE](RELEASE.md) | Release checklist |
| [DOMAIN_STATUS](DOMAIN_STATUS.md) | Domain implementation status board |
| [STATUS](STATUS.md) | Generated repository status |

## Security, privacy & compliance

| Document | About |
| --- | --- |
| [SECURITY_MODEL](SECURITY_MODEL.md) | Security model (PR-071) |
| [SECURITY_HISTORY_REVIEW](SECURITY_HISTORY_REVIEW.md) | Security history review |
| [PRIVACY](PRIVACY.md) | Privacy and PII policy (UU PDP) |
| [DPIA](DPIA.md) | Data protection impact assessment, identity verification |
| [AML](AML.md) | AML / sanctions screening (PR-090) |
| [IDENTITY](IDENTITY.md) | Identity verification (PR-083/084) |
| [EMAIL_DELIVERABILITY](EMAIL_DELIVERABILITY.md) | Email deliverability (PR-089) |
| [INTEGRATION_HARDENING](INTEGRATION_HARDENING.md) | Integration hardening (PR-089) |
| [RISK](RISK.md) | Device/geo risk signals (PR-092) |
| [DATA_RETENTION](DATA_RETENTION.md) | Data retention for documents (PR-096) |

## Domains & integrations

| Document | About |
| --- | --- |
| [INTEGRATIONS](INTEGRATIONS.md) | External integrations (PR-080) |
| [INTEGRATION_BACKLOG](INTEGRATION_BACKLOG.md) | Integration backlog items |
| [EXTERNAL_NEEDS](EXTERNAL_NEEDS.md) | Closing the external-dependency gaps |
| [FX](FX.md) | FX reference rates (PR-091) |
| [CORPORATE](CORPORATE.md) | Corporate registry (GLEIF) |
| [LEGACY_TABLES](LEGACY_TABLES.md) | Legacy tables report (report-only, no DROP) |

## Data & datasets

| Document | About |
| --- | --- |
| [DATASET_CARD](DATASET_CARD.md) | Dataset card (audit snapshot) |
| [DATASET_DECISION](DATASET_DECISION.md) | Dataset decision (R-03) |
| [DATASET_LICENSE_APPROVAL](DATASET_LICENSE_APPROVAL.md) | Dataset license approval |
| [DATASET_REAUDIT](DATASET_REAUDIT.md) | Dataset re-audit, post-remediation |

## Operations

See [runbooks/](runbooks/README.md): incident response, disaster recovery,
rollback, on-call, vault/KMS, capacity, secret rotation, maintainability.

| Document | About |
| --- | --- |
| [PRODUCTION_READINESS](PRODUCTION_READINESS.md) | Production readiness final audit (PR-075) |
| [SLO](SLO.md) | Service-level objectives baseline (PR-045) |

## Architecture decisions

See [adr/](adr/README.md): 13 records (0001–0013), all with explicit status.

## History

Superseded planning records live in [`archive/`](archive/README.md).
They are frozen and must not be updated; new decisions go in the docs above.
