# 0082 - Target runtime for production-grade COBOL

Status: Accepted (technical decision; operations/security ratification pending)
Date: 2026-10-21
Deciders: repository owner (technical); operations and security owners pending
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

**Option A - GnuCOBOL/MySQL/Linux.**

Accepted by the repository owner on 2026-10-21 as the technical target runtime.
This is a technical architecture decision; it does not satisfy G0-SIGNOFF or any
compliance gate. Operations and security owners must ratify the operational
controls before production.

### Portability constraints

- Do not add platform-specific APIs, transaction managers, or file systems to
  the curated COBOL modules.
- Keep database access behind the existing bridge interface.
- Keep online invocation behind the gateway/worker protocol.
- Isolate record layouts in copybooks and keep batch/file access behind a
  narrow module boundary.
- Keep the generated reference module isolated and out of production scope.
- Reopen this ADR if the licensed entity mandates z/OS/CICS/DB2 or a mainframe
  operations model; in that case, use Option B or C rather than growing
  platform-specific code inside the curated core.

### Consequences of Option A

- The current CI, tests, runbooks, and development workflow remain valid.
- Production evidence is still required: SLOs, HA, DR, security assessment,
  observability, data governance, and change control.
- Mainframe compatibility is not provided by this decision; a later port would
  be a separate project.

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

Accepted as a technical decision by the repository owner on 2026-10-21,
recorded in `docs/GATE0_DECISIONS.md` item 17. This ADR does not authorize
production use of any platform; business, compliance, operations, and security
sign-offs remain required.
