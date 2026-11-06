# Action Registry (PR-050)

One generated metadata file for every gateway action: route shape, dispatch
program, linkage, and domain disposition. Sources of truth stay where they
are (route files, `main_logic.cob`, manifests); this file is derived.

## Build & gate

```sh
node scripts/build_action_registry.mjs --write   # regen after review
node scripts/check_action_registry.mjs .         # gate (wired in run_all.sh)
```

Entry shape: `action`, `module`, `prefix`, `method`, `path`, `fields` (slot
names, `""` = BLANK), `required`, `public`, `stepUp`, `tokenIdentity`,
`linkageLevel`, `t1Actions`, `t1Calls`, `tested`, `domain`, `status`,
plus `duplicatePaths` when one action serves several paths (first wins at
runtime, same as Express).

## Rules

- Never hand-edit `manifest/actions.json` (stamp + gate enforce this).
- New routes/dispatch entries must regen the registry in the same commit.
- Unmapped actions (no dispatch program) warn here; `check_route_dispatch`
  owns that invariant and fails the build.
