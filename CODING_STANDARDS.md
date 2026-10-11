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

## COBOL / SQL boundary (appended)

11. **Never embed a padded field in SQL.** A `PIC X(n)` field padded with spaces is fine for `WHERE … =` comparisons (MySQL `PAD SPACE` semantics) but must never be stored or hashed: pass it as a substring with a computed length (`WS-PARAM1-TRIMMED(1:WS-P1-LEN)`), otherwise the row is stored with trailing spaces inside `UNIQUE`/`VARCHAR` columns and hash inputs silently mismatch. A trim that only does `MOVE SPACE TO WS-FIELD(WS-I:1)` when the char is already `SPACE` is a **no-op** — the scan must capture the last non-space index.
12. **The bridge returns exactly one row.** `SQL_EXECUTE`/`GET_RESULT` read a single `mysql_fetch_row`; any "list" must be aggregated into one value in SQL (`GROUP_CONCAT`) until a multi-row call exists on the bridge.

## HTTP gateway

13. **The composed input line must stay under the COBOL record size.** `main_logic` reads `PIC X(500)`; `middleware/src/validation.js` must reject a request whose joined `ACTION|p1|p2|p3|p4` line would exceed that record, before writing `input.txt`.
