# Fail-closed CSPRNG for secrets and codes

Status: accepted
Date: 2026-10-16
Phase: Cross-domain security hardening (FASE B).

## Context

Every security-sensitive random value — password salts, verification/reset
codes, and MFA/TOTP secrets — was read from `/dev/urandom`, but on any failure
the code fell back to an unseeded `rand()` or a fixed constant
(`get_secure_random_uint32` returned `123456`). Unseeded `rand()` is
deterministic across processes, so those fallbacks made codes and secrets
predictable (CWE-338 / insecure randomness). A missing OS entropy source would
have silently degraded authentication rather than failing.

## Decision

- Add a single, shared helper `cobol/c_lib/random_lib.c`
  (`secure_random_bytes`, declared in `random_lib.h`) used by `hash_lib.c` and
  `totp_lib.c`.
- It reads from the OS CSPRNG (`/dev/urandom` on POSIX, `CryptGenRandom` on
  Windows), retrying on `EINTR` and looping until the buffer is full.
- **It fails closed**: if the OS source is unavailable or short, it writes a
  fatal line to stderr and `abort()`s. No `rand()` or constant fallback
  remains anywhere in the secret/code/salt path. Failing the request is
  preferable to issuing a guessable credential.
- `hash_lib.c` and `totp_lib.c` no longer open files or call `rand()`
  themselves; they delegate to the helper.

## Consequences

- A broken OS entropy source is a hard error (5xx) instead of a silent
  predictability bug — the safe direction for a banking system.
- Behaviour on the normal path is unchanged; the helper is exercised by the new
  `tests/test_rng.sh` (builds clean, returns fresh non-zero bytes) and the MFA
  and password-salt freshness checks.
- `cobol/c_lib/random_lib.c` is added to `build.sh`.
