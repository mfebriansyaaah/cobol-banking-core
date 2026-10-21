# 0082 - Target runtime for production-grade COBOL

Status: Proposed
Date: 2026-10-21
Deciders: repository owner, architecture, operations, security
Related: `docs/PRODUCTION_GRADE_PLAN.md`, `docs/GATE0_DECISIONS.md` item 17,
`docs/adr/0001-invocation-model.md`, `docs/adr/0002-auth-db-stack.md`

## Context

The repository runs on GnuCOBOL 3.2, MySQL/MariaDB, a C bridge, and a
Node.js/Express gateway. The October 2026 volume sprint added a generated
reference module and brought COBOL net to 62.544 lines. The owner now wants a
production-grade codebase, but "enterprise COBOL" can mean two different
platforms:

- **A. Enterprise-grade engineering on the current stack.** GnuCOBOL,
  MySQL/MariaDB, Linux, the existing C bridge and gateway, hardened with
  modules, copybooks, observability, deployment, and operations.
- **B. Mainframe enterprise platform.** IBM z/OS, CICS or IMS, DB2, VSAM, JCL,
  RACF, MQ, and the associated operations and change-control tooling.
- **C. Portable core with adapters.** Keep the COBOL business logic portable
  and put CICS/DB2/VSAM or GnuCOBOL/MySQL adapters behind a narrow interface.

The choice changes the deployment, security, performance, testing, and skills
requirements. It is a Gate 0 decision, not a code-only decision.

## Decision

**Pending.** This ADR records the options and their consequences. No option is
selected until the owner and the accountable operations/security owners sign
it in `docs/GATE0_DECISIONS.md` item 17.

Until the decision is made:

- Do not add platform-specific APIs, transaction managers, or file systems to
  the curated COBOL modules.
- Keep database access behind the existing bridge interface.
- Keep online invocation behind the gateway/worker protocol.
- Keep the generated reference module isolated and out of production scope.

## Consequences by option

### A. GnuCOBOL / MySQL / Linux

- Lowest migration cost; the current CI, tests, and runbooks remain valid.
- The team must own GnuCOBOL runtime support, C bridge safety, MySQL
  operations, and Linux hardening.
- Production evidence is still required: SLOs, HA, DR, security assessment,
  and change control.
- Best fit for a prototype-to-product path where the business logic matters
  more than mainframe compatibility.

### B. z/OS / CICS / DB2 / VSAM

- Highest compatibility with regulated-bank mainframe operations and skills.
- Requires a port of the COBOL dialect, transaction model, file access, JCL,
  security (RACF), scheduling, and observability.
- The current Node gateway, C bridge, MySQL schema, and shell CI are not the
  production runtime; they become development or adapter tooling.
- Multi-month migration and a mainframe environment are prerequisites.

### C. Portable core with adapters

- Keeps the door open to both platforms; the core avoids platform-specific
  constructs.
- Requires a clean interface for transactions, database access, file access,
  and error mapping.
- Adds abstraction cost and requires tests on both adapters.
- Best fit if the target platform is not yet decided but the business logic
  must start now.

## Decision criteria

1. Target jurisdiction and regulator expectations.
2. Existing operations skills and data-center commitments.
3. Required transaction volumes, latency, and availability.
4. Vendor support and licensing for the COBOL runtime.
5. Cost and timeline of porting versus hardening the current stack.
6. Availability of mainframe environments for development and disaster
   recovery.

## Status

Proposed. Sign-off is recorded in `docs/GATE0_DECISIONS.md` item 17. This ADR
does not authorize production use of any platform.
