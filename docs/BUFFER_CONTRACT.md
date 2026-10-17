# C/COBOL buffer contract

C functions receive COBOL fields as bare pointers with no size attached, so
every read and write relies on the table below. **Rule: a C bound must never
exceed the smallest COBOL field ever passed to it; a COBOL field must never
shrink below the C bound that writes it.** `tests/buffer_contract_check.sh`
(enforced by `ci.sh`) pins the COBOL side; `tests/test_c_memory.sh` (ASan)
pins the C side.

Conventions: `PIC X(n)` holds exactly `n` bytes with no terminator.
`strncpy(dst, src, k)` reads at most `k` bytes, so `k` must be at most the
source field size; a write of `k` bytes needs a destination of at least `k`.

| C operation | Bound (bytes) | COBOL field(s) | Size | Why it fits |
|---|---|---|---|---|
| `SET_QUERY` copy | 511 + NUL | `WS-QUERY` / `WS-PREP-SQL` | 512 / 1024 | 511 < 512 (smallest caller); 511 is correct, not a bug |
| `SQL_PREPARE_EXEC*` template copy | 1023 + NUL | `WS-PREP-SQL` | 1024 | 1023 < 1024 |
| prepared bind copy | 256 + NUL | `WS-BIND-1..7` | 256 | read stops inside the field; overlong values truncate (bound params stay safe) |
| `SQL_ESCAPE` trim copy | 100 | `WS-PARAMn-TRIMMED` | 100 | exact fit |
| `GET_RESULT` fill | 16383 | `WS-RESULT` | 16384 | fill < field |
| verify/totp `result[0]` only | 1, no terminator | `WS-VERIFY`, `WS-NEEDS-REHASH` | 1 | single-char comparisons; terminator writes were removed (ADR 0045) |
| `generate_random_code` (`%06d` + NUL) | 7 | `WS-CODE`, `WS-RAND` | 7 | exact fit (`WS-RAND` was 6: fixed, ADR 0045) |
| `generate_mfa_secret` (32 chars + NUL) | 33 | `WS-MFA-SECRET` | 64 | fits |
| `hash_password_v2` output | <= ~111 + NUL | `WS-HASH` | 256 | fits (legacy `SHA256_` hashes are verify-only; the old hasher is removed) |
| result row fields | 255 / 511 + NUL | `temp[256]` / `temp[512]`, `rbuf[][512]` | local | C-side only; overlong values truncate (documented, ADR 0045) |

Notes:

- Overlong *values* truncate; overlong *fields* must never shrink — the
  check script guards the latter.
- `G_RESULT` (16384) is always NUL-terminated by construction (bounded
  `snprintf`/`strncat`, short-literal `strncpy`); `GET_RESULT` relies on it.
- `verify_password` refuses stored PBKDF2 costs above
  `PBKDF2_MAX_ITERATIONS` before burning CPU (ADR 0045).
