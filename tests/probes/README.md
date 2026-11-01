# Gate detection probes

Probes test the checks, not the code. Each one takes a throwaway copy of
`HEAD`, breaks exactly one thing, and records which gate refuses.

```
tests/run_all.sh probes
```

```
probe                                      expected   actual     caught by
------------------------------------------ ---------- ---------- ---------
p1_broken_route_syntax                     detected   detected   js_syntax
p2_duplicate_route                         detected   detected   route_conflicts
p3a_one_route_without_identity             detected   detected   route_auth
p3b_whole_route_file_without_identity      detected   detected   auth_guard,route_auth
p4_action_without_cobol_handler            detected   detected   action_coverage
p5_dead_bind_slot                          detected   detected   bind_slots
p5b_swapped_bind_slots                     missed     missed     none
p6_deleted_db_suite                        detected   detected   suite_coverage
p7_missing_assertion                       detected   detected   test_counts
p8_field_order_drift                       detected   detected   field_order
p9_action_without_test                     detected   detected   action_coverage_tests

probes: 11 | detected: 10 | missed: 1
OK: every probe matched its recorded expectation
```

## Why the "missed" row matters

`missed` is a measurement, not a pass. It means every static gate accepted
deliberately broken code:

| Probe | What it breaks | Consequence if it ships |
|---|---|---|
| `p5b` | two SQL bind slots swapped (both are passed) | query compiles and runs, returns another customer's data; only a runtime test that checks values can see the order is wrong |

Two gaps from Fase 1 are now closed and their probes flipped to `detected`:
`p3a` (one endpoint losing `tokenIdentity`) by `route_auth`, and `p6` (a
deleted DB suite) by `suite_coverage`. The dead-write half of the old `p5`
is now its own probe, `p5_dead_bind_slot`, caught by `bind_slots`; the true
swap is what remains honestly `missed`.

These are recorded in `expectations.txt` so they cannot be forgotten and
cannot silently improve: when a new gate closes a gap, the probe flips to
`detected`, `run_probes.sh` fails, and the expectation must be updated on
purpose. The reverse also fails — removing a gate that used to catch a probe
is reported as a regression.

## Scope

The harness runs the static layer only:

- `js_syntax` — `node --check` over `middleware/src` and `scripts`
- `manifest` — `scripts/check_manifest.mjs`
- `route_dispatch` — `scripts/check_route_dispatch.mjs`
- `route_conflicts` — `scripts/check_route_conflicts.mjs`
- `action_coverage` — `scripts/check_action_coverage.mjs`
- `case_actions` — `scripts/check_case_actions.mjs`
- `test_helpers` — `scripts/check_test_helpers.mjs`
- `auth_guard` — the per-file `tokenIdentity` check from `scripts/ci/sast.sh`
- `route_auth` — `scripts/check_route_auth.mjs`, per-route `tokenIdentity`
- `bind_slots` — `scripts/check_bind_slots.mjs`, passed bind slots are 1..k
- `suite_coverage` — `scripts/check_suite_coverage.mjs`, DB inventory match
- `test_counts` — `scripts/check_test_counts.mjs --static`, assertion counts match the baseline
- `field_order` — `scripts/check_field_order.mjs`, route field order matches the snapshot
- `action_coverage_tests` — `scripts/check_action_test_coverage.mjs`, every routed action is shell-executed or baselined

No build, no database, no gateway. A defect that only a runtime suite would
catch is reported as `missed` here, which is the honest answer for this layer.
Running the runtime suites per probe would mix in the known-red transfer tests
and cost minutes per probe.

## Safety

- Works on `git archive HEAD` inside `mktemp -d`, never on the checkout.
- The script refuses to run if the sandbox resolves inside the repository.
- Uncommitted changes are ignored by design: probes measure the committed
  state, so a dirty working tree cannot change the result.

## Adding a probe

1. Add `mut_pN_<name>()` to `tests/probes/run_probes.sh` (cwd is the sandbox).
2. Append the probe id to the `PROBES` array.
3. Add `<probe id>=detected|missed` to `expectations.txt` with a comment
   explaining what the mutation represents.
4. Run `tests/run_all.sh probes` and confirm the observed result is what you
   recorded. If it differs, the expectation is wrong, not the run.
