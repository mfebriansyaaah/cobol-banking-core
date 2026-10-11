# CODING_STANDARDS.md

Rules a reviewer enforces on every COBOL/C-bridge diff. Mechanical violations should ideally fail `ci.sh` before review even starts; the judgement calls below are the ones no script can substitute.

## COBOL

1. **Never `GOBACK` inside a performed paragraph.** `GOBACK` returns from the *whole program*, not from the `PERFORM`. A helper paragraph called by `PERFORM` ends by flowing into the next paragraph or via `EXIT PARAGRAPH`. Keep `GOBACK` only in the entry paragraph.
2. **No sentence periods inside `IF`/`ELSE` scope bodies.** A period terminates the nearest open scope, not the statement. End inline scope statements bare; close with `END-IF.` / `END-STRING.` / `END-EVALUATE.`.
3. **Match action names by exact-length substring** (`LS-CMD-ACTION(1:8) = "GET_USER"`), never by `FUNCTION TRIM(...) = " literal"` — TRIM does not reliably strip in this GnuCOBOL/linkage setup and padded comparisons fail.
4. **`PERFORM`ed helper paragraphs must not fall through** into the next paragraph: `PERFORM` executes to the end of the paragraph (i.e., into the *next* paragraph's code). Put `EXIT PARAGRAPH.` at the end of every helper that is not last.
5. **Password/connection literals belong in config, never in test scripts or source.** Tests read credentials from the local MySQL client config (`~/.my.cnf` or `mysql` defaults), not from hardcoded values.

## C bridge (`sql_bridge.c`)

6. **Never null-pad a buffer COBOL will treat as alphanumeric.** `strncpy` fills the remainder with `\0`; `libcob` then refuses the WRITE (`status 71`, invalid data for LINE SEQUENTIAL). Fill the rest of the buffer with spaces before returning (`memset(result, ' ', N)`).
7. **Copy at most the COBOL field's size** from COBOL-visible buffers. A `PIC X(512)` field must be read with a ≤511-byte copy — reading 1023 bytes walks into adjacent working-storage and corrupts queries/results.

## Tests

8. **Every test resets DB state first** (order-independence). A suite that passes only in a specific sequence is a bug.
9. **Expected error names are a contract**: `ERROR|MISSING_ACTION`, `ERROR|INVALID_ACTION`, `ERROR|ACCOUNT_NOT_FOUND`, `ERROR|TARGET_NOT_FOUND`, `ERROR|INSUFFICIENT_FUNDS`, `ERROR|NOT_FOUND`, `SUCCESS|TRANSFER_OK`, `SUCCESS|LIST_DONE`. Renaming one requires updating both suites and the module that emits it, in the same PR.

## Language

10. **English only.** Every artifact is written in English: commit messages, PR titles and descriptions, documentation, code identifiers (variables, functions, paragraphs, `PROGRAM-ID`s), and inline comments. A reviewer rejects any non-English identifier, comment, or doc line, and any commit/PR text in another language.
