# Runbooks

Operational procedures. Read
[incident-response](incident-response.md) first when something is on fire;
the rest are referenced from it and from the on-call rotation.

| Runbook | When to use it |
| --- | --- |
| [ci-failure](ci-failure.md) | Triaging automated `ci-failure` issues from scheduled CI |
| [incident-response](incident-response.md) | Active incident: declare, mitigate, communicate, resolve |
| [disaster-recovery](disaster-recovery.md) | Full loss / failover scenarios beyond a single incident |
| [rollback](rollback.md) | Reverting a bad deploy or migration |
| [operations](operations.md) | Day-to-day operations |
| [vault-kms](vault-kms.md) | Vault and KMS access |
| [capacity](capacity.md) | Capacity planning and runner sizing |
| [secret-rotation](secret-rotation.md) | Rotating JWT and service secrets |
| [maintainability](maintainability.md) | Keeping the codebase maintainable |
| [dataset-sanitization](dataset-sanitization.md) | Producing a PII-free history mirror for dataset distribution |
