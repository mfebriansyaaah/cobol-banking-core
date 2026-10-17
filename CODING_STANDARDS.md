# Development and Control Standards

These are **mandatory merge gates** for every code, schema, configuration, and
documentation change. A passing build or CI run alone is not approval for a
financial or regulated control. Reviewers must reject changes that weaken an
invariant, bypass evidence, or claim compliance without accountable approval.

## 1. Product, compliance, and change control

1. **Trace every change.** Each feature or control change must cite an approved
   PRD requirement, control, incident, or explicitly approved technical task.
   Update requirements, implementation notes, tests, and operational evidence
   in the same change. Unscoped “cleanup” must not alter financial behavior.
2. **No regulatory assumptions.** Do not encode jurisdiction-specific KYC,
   AML, sanctions, retention, consumer-protection, or reporting rules until the
   jurisdiction and approved requirement are identified. Mark unresolved
   obligations as blockers, not as implemented controls.
3. **No false readiness claims.** CI green, a passing test, or a code feature
   does not mean the system is licensed, certified, compliant, or production
   ready. External approvals and operational evidence must be recorded by their
   accountable owners.
4. **Financial changes require explicit review.** Any change affecting posting,
   balances, ledger, currency precision, rates, limits, reversals, idempotency,
   or reconciliation requires a written invariant, failure/rollback analysis,
   boundary and concurrency tests, and finance/accounting review before merge.
5. **Schema changes are controlled.** Follow `docs/SCHEMA_POLICY.md`: migration
   plus current-schema baseline plus migration test/update in one change. Never
   rerun the destructive fresh-install schema on live data. Migrations must be
   fail-stop, attributable, and recoverable.
6. **Production data is prohibited in development fixtures.** Do not commit
   credentials, real customer data, production exports, or secrets. Test data
   must be synthetic and isolated. Seed scripts are development-only.

## 2. Financial and data integrity

7. **Journal every value movement.** A financial posting must be balanced,
   atomic, attributable, idempotent where retried, and represented by immutable
   journal entries. A correction is a compensating posting; never edit a posted
   financial fact in place.
8. **One authoritative balance contract.** Any materialized balance is a
   projection of the journal and must be updated atomically, independently
   recomputable, and covered by reconciliation/alerting. Never add a balance
   mutation path without proving its journal effect and rollback behavior.
9. **Currency is explicit.** Use currency-specific precision/minor units and
   approved rounding. No implicit fixed decimal scale, floating-point money,
   silent truncation, or unversioned FX rate. Test zero-decimal and maximum
   supported precision currencies.
10. **Concurrency is part of correctness.** Lock rows deterministically; test
    conflicting requests, retries, deadlocks, timeouts, and crash boundaries.
    Never report success before the durable commit is confirmed.
11. **Least privilege and separation of duties.** Runtime credentials must not
    have DDL rights. Privileged or policy-sensitive changes need the approved
    maker-checker/dual-control workflow once defined; never create a bypass for
    tests or operations.
12. **Audit evidence is not optional.** Sensitive and financial actions record
    actor, subject, time, outcome, correlation/reference, and relevant policy
    decision without secrets. Audit failure behavior must be explicit and
    tested; do not silently discard required evidence.

## 3. COBOL and C boundary

13. **Never `GOBACK` inside a performed paragraph.** `GOBACK` exits the whole
    program. Keep it in the entry paragraph; helpers use `EXIT PARAGRAPH`.
14. **No sentence periods inside inline scope bodies.** Close scopes explicitly
    with `END-IF`, `END-STRING`, or the appropriate terminator.
15. **Dispatch actions by exact-length comparison.** Do not use padded/TRIM
    comparisons for action names.
16. **Performed paragraphs must not fall through.** End each non-final helper
    with `EXIT PARAGRAPH.`
17. **Detect absent parameters from the raw field.** Trimming may make an empty
    field appear present; use raw-field comparison or a presence flag.
18. **Respect the checked buffer contract.** Every C read/write bound must fit
    the exact COBOL field passed. Update `docs/BUFFER_CONTRACT.md` and keep
    `tests/buffer_contract_check.sh` and the sanitizer suite passing whenever
    either side changes. Never add a terminator to a one-byte COBOL result.
19. **Use safe database APIs.** Use bound parameters for values. Any remaining
    escaped SQL path needs an explicit security rationale and adversarial test.
    Never log SQL text or credentials; logs must not contain secrets or
    unnecessary customer data.
20. **C functions must fail safely.** Validate lengths, check return values,
    release resources, avoid undefined behavior, and fail closed for security-
    critical entropy or integrity operations. Run sanitizer tests for memory
    boundary changes.
21. **All business logic is implemented and decided in COBOL.** COBOL is the
    mandatory, sole authority for financial calculations/postings, business
    authorization, eligibility, limits, pricing/fees, fraud/compliance
    outcomes, and business state transitions. C, JavaScript, SQL triggers,
    stored procedures, jobs, and external integrations must not implement or
    override these rules. If a technical layer performs defense-in-depth
    checks, COBOL must independently enforce the authoritative rule and tests
    must prove both paths agree.
22. **Other languages are infrastructure adapters only.** C/JavaScript may
    implement capabilities COBOL does not provide directly (HTTP/network and
    process transport, database-driver calls, cryptographic primitives,
    serialization, queues/provider clients, and observability), plus
    syntactic/size validation and safe error mapping. They must not decide
    business outcomes for convenience. Any exception requires an approved ADR,
    security and finance review, an explicit scope, and tests proving that
    COBOL remains the source of truth. A capability that COBOL can provide
    must be implemented there unless an approved exception documents why it
    cannot safely do so.

## 4. SQL and database

23. **Name columns explicitly.** No `SELECT *`, positional schema assumptions,
    or inserts without a column list.
24. **Indexes and constraints are product controls.** Add/retain constraints
    for uniqueness, references, valid state, and nonnegative/valid amounts.
    A performance or integrity constraint change must include evidence and a
    migration test.
25. **Do not hide database errors.** A migration or posting failure must be
    attributable, must not be recorded as successful, and must have a defined
    retry/recovery behavior. Never swallow errors merely to make CI pass.

## 5. API, identity, and security

26. **Identity comes from verified credentials.** Actor/sender/subject identity
    used for authorization comes from the verified token or trusted service
    context, never a caller-controlled body field.
27. **Validate before invoking COBOL.** Reject malformed fields and composed
    records exceeding the fixed input buffer before invocation. Keep explicit
    body, timeout, queue, and rate limits.
28. **Preserve neutral responses.** Authentication, recovery, and enrollment
    flows must not reveal account existence or secret state without an approved
    policy exception and threat analysis.
29. **No secrets in logs, errors, or fixtures.** Redact tokens, passwords,
    verification/MFA codes, connection strings, and unnecessary PII. Public
    errors must not expose SQL, stack traces, or internal paths.
30. **Configuration is discoverable and checked.** Every environment variable
    read by gateway or core must have a documented default/meaning in
    `middleware/.env.example`; `tests/env_check.sh` is mandatory.
31. **Access changes are revocable.** Role/status/password/MFA/session changes
    must explicitly define effects on current access and refresh sessions, and
    test those effects.

## 6. Tests and evidence

32. **Every requirement has a test/evidence link.** Add deterministic unit,
    integration, negative, authorization, and failure-path tests appropriate to
    the risk. Money movement requires balance/journal assertions, not just HTTP
    status assertions.
33. **Tests are order-independent and isolated.** Reset only their own
    synthetic fixtures; use unique identifiers. No shared seeded-row mutation
    may make another suite pass or fail accidentally.
34. **No silent skips or swallowed failures.** A missing dependency, seed, or
    required service must fail the relevant suite. Do not use `set +e`, ignored
    exit codes, `|| true`, or broad redirection to conceal a failure.
35. **Keep count and contract baselines current.** Update
    `tests/baseline_counts.txt`, `docs/STATUS.md`, and the relevant contract
    tests together when assertions intentionally change. Any decrease needs an
    explicit reason.
36. **Run the full gate.** `./ci.sh` must finish `ALL GREEN`. Targeted tests do
    not substitute for the full suite before a PR.
37. **Negative controls for guardrails.** New static/contract checks should
    demonstrate that a deliberately broken fixture is rejected, where
    practical, so a vacuous checker cannot pass.
38. **Shell suite convention.** Each shell suite remains self-contained with
    local helpers and explicit assertion accounting; shared helpers are not
    introduced without demonstrating that they reduce, rather than multiply,
    failure coupling.

## 7. Review and communication

39. **English repository artifacts.** Source, comments, docs, commit messages,
    and PR text are in English. User-facing discussion may use the user's
    language.
40. **Atomic, reviewable commits.** One logical change per commit; no generated
    binaries, local secrets, temporary fixtures, or unrelated cleanup.
41. **Document deliberate gaps.** A known limitation must name impact, scope,
    mitigation, owner/decision if known, and exit criteria. Do not label a
    deferred control “complete.”
42. **No direct integration-branch commits.** Work on a topic branch and merge
    through review. The only local `main` commit permitted is the generated
    post-merge `docs: sync HISTORY.md ...` sync.
