# Spec: api-gateway

Status: **not started** — no Node.js/Express code exists anywhere in the repo.
Last verified against code: 2026-10-10

## Objective (unchanged)

The "Robust Pipe": a Node.js Express middleware that is the only interface between the public internet and the COBOL business logic. It secures, transports, and translates — it implements no business rules.

## As-Built (what exists today)

- **Nothing.** There is no `middleware/`, no `package.json`, no `npm` scripts, no Express code, no JWT code. `find` for `package.json` returns nothing.
- The COBOL side is **not** invoked as a per-request CLI with exit codes. The shipped binary (`cobol/bin/main_logic`) reads one pipe-delimited line from `input.txt` and writes one result line to `output.txt` (a file contract, not stdout + exit codes).
- `build.bat` still mentions a future `middleware/` (`npm install && npm start`) and an `auth_identity.exe`, but neither the middleware nor that binary target exists in the tree today.

## To add (the entire module is missing)

- [ ] Initialize the Node.js project (`middleware/`), Express server, `.env` for binary path / JWT secret / port.
- [ ] A transport adapter that satisfies the **actual** COBOL contract: write `ACTION|p1|p2|p3|p4` to `input.txt`, run the binary, read `output.txt`. (The original spec assumed stdout + exit codes — reconcile this.)
- [ ] JWT middleware; only `/auth/signup` and `/auth/login` public.
- [ ] Whitelist regex validation of every parameter before it reaches COBOL (command/file-injection guard).
- [ ] Map COBOL results to HTTP: parse the `ERROR|…` / `SUCCESS|…` lines into `{ "error": … }` / `{ "data": … }`.
- [ ] Timeout handling so a hung COBOL process becomes a 504, not a hung server.
- [ ] Tests: injection, missing/expired token, timeout, and result→HTTP contract (the original spec's testing strategy).

## Depends on (blockers)

- The action names and output lines it must translate are those in `SPEC-wallet-core.md`, `SPEC-auth-identity.md`, `SPEC-user-profile.md`. Until `auth-identity`/`user-profile` are actually wired into the binary, the gateway can only front `CHECK_BALANCE`, `TRANSFER`, `GET_USER`, `LIST_USERS`.
- A stable per-request invocation model: today the binary uses `input.txt`/`output.txt` fixed files, which is **not concurrency-safe**. A pipe/server mode (or per-request temp files) is a prerequisite for a real gateway.

## Conventions to conform to (as built)

- No business logic in JS — pass-through only (unchanged intent).
- Pipe-delimited COBOL output → JSON at the boundary.

## Open questions

- Fixed `input.txt`/`output.txt` cannot serve concurrent requests. Which model: per-request temp files, a long-running COBOL server, or a queue?
- JWT expiry policy (24h vs 30d) — left open in the original spec.
