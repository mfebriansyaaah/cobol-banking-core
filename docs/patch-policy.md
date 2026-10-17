# Patch and dependency policy

Status: policy draft. Cadence owners and exception approvers are owner
decisions (Gate 0); the rules below apply once ratified.

## Scope

- `middleware/package.json` / `package-lock.json` (Node runtime + gateway
  dependencies), base OS packages on hosts, MySQL/MariaDB server.
- COBOL toolchain (`cobc`) and C libraries change only with a bridge
  rebuild + full `./ci.sh`.

## Rules

1. Dependencies are pinned via `package-lock.json`. Direct dependency
   changes require a lockfile update in the same commit.
2. CI runs `npm audit --omit=dev --audit-level=high` on every run. A new
   high/critical advisory fails CI until it is fixed or an exception is
   recorded here (advisory id, exposure assessment, expiry date).
3. Security patches land within the owner-approved window of disclosure;
   the window itself (e.g. critical ≤ 7 days) is TBD by owners.
4. `npm audit fix` output is reviewed, never applied blindly: check for
   breaking changes against the gateway contract suite.
5. Base-image/OS/DB patches follow the deploy runbook with a backup
   taken first; rollback is the previous image plus backup restore.

## Vulnerability response

Report → assess exposure (is the vulnerable path reachable from the
gateway/bridge?) → patch or record an exception → regression test if
behavior changed → note in the release record. Suspected exploitation
is an incident (`runbooks/incident-response.md`), not a routine patch.
