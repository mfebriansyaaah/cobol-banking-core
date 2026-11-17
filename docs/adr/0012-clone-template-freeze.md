# ADR 0012: Clone-template freeze (no generator, no REPLACING skeleton)

## Status

Accepted (DRY-08 spike, Nov 2026). The 92%-clone question is closed: the
template relationship is over, the five small clones are frozen as
independent modules, and no propagation machinery will be built.

## Context

`scripts/generate_module.py` stamps new SQL-backed modules out of
`cobol/src/cost_center_core.cob` (see `docs/MODULE_AUTHORING.md`). Five
modules still carry that shape at 637 lines and 0.95 similarity
(`tests/clone_baseline.txt`, shape CLONE9):

- `account_core`, `compliance_calendar_core`, `notification_template_core`,
  `report_schedule_core`, `sla_tracker_core`

Three more share the ancestry but have diverged further and are already
independent in practice (`fixed_asset_core` 1114 lines sim 0.71,
`merchant_settlement_core` 1293 lines sim 0.71,
`tax_management_core` 1353 lines sim 0.69).

The template itself moved on: `cost_center_core` is 526 lines today
(shrunk by the DRY waves, including the #679 shared-wrapper rollout),
while the five clones stayed 637 lines. The "template" is now a diverged
sibling, not a common ancestor.

## Spike (all in /tmp, reproducible)

**Option 1 — regenerate from a spec.** Regenerating `sla_tracker` from
the current template with the correct historical args:

```sh
scripts/generate_module.py sla_tracker SLT_ sla_tracker sla_ref sla_name sla_type
```

yields a 52-line diff against the frozen file, and every hunk is domain
logic that regeneration would destroy: template columns
`budget_amount`/`spent_amount`/`allocated_at` and actions `ALLO`/`CLOSE`
vs the clone's `target_response`/`actual_response`/`activated_at`,
`close_reason`, `CALC`/`DELETE`. The script's spec
(domain/prefix/table/fields) cannot express per-domain columns, actions,
or messages — capturing them would mean writing a new DSL, then proving
byte-identical reproduction × 5. Verdict: **no-go**. The spec is
insufficient and the template is no longer common.

**Option 2 — `COPY ... REPLACING` full-program skeleton.** Two independent
killers, the first mechanical:

1. GnuCOBOL 3.2.0 (this repo's toolchain) rejects `==pseudo-text==`
   delimiters with a syntax error:

   ```cobol
   COPY "skel.cpy" REPLACING ==GREETING== BY =="HELLO"==.
   -- error: syntax error, unexpected =
   ```

   Whole-word `REPLACING GREETING BY HELLO` compiles, but partial-token
   substitution (`==PREFIX==CREATE`) is impossible with it — every
   varying point would need a full-word token, exploding the token count.

2. Even if it compiled, every source-level gate would go blind:
   `check_bind_slots` (`LITERAL_RE`, `WRAP_RE`), the placeholder counter,
   and the duplication scanner read `.cob` source with no COPY
   preprocessing, so they would see tokens instead of SQL. Gating a
   skeleton language means rewriting every gate to expand `COPY
   REPLACING` first.

   Verdict: **no-go** on this toolchain, and undesirable even where it
   compiles.

**Option 3 — freeze + propagation gate.** Admission control already
exists and already binds: `check_clone_budget` fails any new clone-like
L0/L1 module and its baseline must only shrink. What does not exist —
deliberately — is a "template change must be mirrored" gate
(`check_generated_clones` as specified would compare regeneration
output against the frozen files and fail forever on the 52-line domain
drift proven above, unless the drift is blessed case-by-case, which is
process theater). Since the domains diverged, template changes do not
apply to the clones anyway; a propagation gate would enforce fiction.

## Decision

Freeze:

1. The five 637-line clones are independent modules. They evolve by
   normal PRs, covered by the same gates as everything else
   (per-module coverage ratchet, duplication baseline, bind slots).
2. `cost_center_core` is a regular module, not a canonical source. Do
   not "sync" the clones to it.
3. No `check_generated_clones`, no skeleton, no generator DSL.
   `generate_module.py` stays for stamping genuinely-new domains
   (documented in `docs/MODULE_AUTHORING.md`), not for governing old ones.
4. `check_clone_budget` remains the admission ratchet: no *new* clones
   without a proven Tier-1 link.

## Consequences

- A template-shaped improvement (e.g. a wrapper rollout) is applied to
  the five files by hand, like any other family rollout — mechanical,
  reviewable, gate-verified. This is what waves 13h–13hc already did.
- If a future change genuinely spans all five identically, prefer
  extracting the shared paragraph into `cobol/copy/` (ADR-0009 playbook)
  over resurrecting the template.
- Revisit only if a *sixth* template-shaped module is ever proposed:
  that is the point where the DSL conversation becomes honest again.
  Until then the question stays closed.
