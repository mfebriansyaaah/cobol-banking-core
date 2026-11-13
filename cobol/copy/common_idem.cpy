      *> Unified idempotency mirror (maint-14A): dual-store CLAIM /
      *> COMPLETE / DELETE for money actions with a client-supplied key.
      *> ADR-0008 protocol is unchanged; the ten per-action `*_request`
      *> tables stay the decision-makers in this release and
      *> idempotency_request is written alongside every transition so the
      *> suites can prove the mirror converges. No legacy table is dropped
      *> here; reads cut over in a later PR.
      *>
      *> Caller contract (host declares all of these; the copybook never
      *> declares storage):
      *>   WS-IDEM-SCOPE      PIC X(32)  - action scope, e.g. "COL_PAY".
      *>                                  Unknown scopes fail closed.
      *>   WS-IDEM-ENTITY-VAL PIC X(64)  - trimmed entity id (case_id, ...).
      *>   WS-IDEM-KEY        PIC X(64)  - trimmed idempotency key.
      *>   WS-IDEM-AMOUNT     PIC X(30)  - trimmed amount bound + compared.
      *>   WS-IDEM-DETAILS    PIC X(500) - extra replay details (14B scopes;
      *>                                  SPACES in 14A).
      *>   WS-IDEM-CODE       PIC X(40)  - full in-progress error, e.g.
      *>                                  "ERROR|PAY_IN_PROGRESS".
      *> Managed by the copybook (host declares, caller does not set):
      *>   WS-IDEM-TABLE      PIC X(40)  - legacy table for the scope.
      *>   WS-IDEM-ENTITY     PIC X(30)  - legacy entity column, or SPACES
      *>                                  for global keys (14B scopes).
      *> Shared outcomes (host declares; same names the inline code used):
      *>   WS-IDEM-STATUS/OWNED/ROW/AMT/STALE, WS-ERR. COMPLETE reports
      *> through the host STEP-OK/STEP-FAIL flag (it runs inside the
      *> action transaction); CLAIM/DELETE report through WS-ERR.
      *> Requires the standard WS-PREP-SQL, WS-BIND-1..6, WS-RESULT.
       IDEM-CLAIM.
           MOVE SPACES TO WS-IDEM-STATUS WS-IDEM-ROW WS-IDEM-AMT WS-IDEM-STALE
           MOVE "0" TO WS-IDEM-OWNED
           MOVE SPACES TO WS-ERR WS-IDEM-TABLE WS-IDEM-ENTITY
           EVALUATE WS-IDEM-SCOPE
               WHEN "COL_PAY"
                   MOVE "collection_pay_request" TO WS-IDEM-TABLE
                   MOVE "case_id" TO WS-IDEM-ENTITY
               WHEN OTHER
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
                   EXIT PARAGRAPH
           END-EVALUATE
           IF WS-IDEM-ENTITY = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "SELECT CONCAT(status, '|', CAST(amount AS CHAR), '|', updated_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE)) FROM "
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE idempotency_key = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-KEY TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE SPACES TO WS-PREP-SQL
               STRING "SELECT CONCAT(status, '|', CAST(amount AS CHAR), '|', updated_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE)) FROM "
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                   " = ? AND idempotency_key = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-1
               MOVE WS-IDEM-KEY TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               PERFORM IDEM-INSERT
               IF WS-ERR NOT = SPACES
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "RETRY"
                   MOVE SPACES TO WS-IDEM-STATUS
                   PERFORM IDEM-SELECT
                   IF WS-ERR NOT = SPACES
                       EXIT PARAGRAPH
                   END-IF
               ELSE
                   PERFORM IDEM-MIRROR-SYNC
                   EXIT PARAGRAPH
               END-IF
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
                   EXIT PARAGRAPH
               ELSE
                   MOVE WS-RESULT TO WS-IDEM-ROW
               END-IF
           END-IF
           IF WS-ERR = SPACES AND WS-IDEM-ROW NOT = SPACES
               PERFORM IDEM-DECIDE
               IF WS-ERR = SPACES AND WS-IDEM-OWNED = "1" AND WS-IDEM-STATUS = "PENDING"
                   PERFORM IDEM-MIRROR-SYNC
               END-IF
           END-IF
           IF WS-IDEM-STATUS = "DONE" AND WS-ERR = SPACES
               PERFORM IDEM-MIRROR-DONE
           END-IF.
           EXIT PARAGRAPH.

       IDEM-SELECT.
      *> Re-read the legacy row (after a 1062 race on INSERT).
           IF WS-IDEM-ENTITY = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "SELECT CONCAT(status, '|', CAST(amount AS CHAR), '|', updated_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE)) FROM "
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE idempotency_key = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-KEY TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE SPACES TO WS-PREP-SQL
               STRING "SELECT CONCAT(status, '|', CAST(amount AS CHAR), '|', updated_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE)) FROM "
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                   " = ? AND idempotency_key = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-1
               MOVE WS-IDEM-KEY TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
           ELSE
               MOVE WS-RESULT TO WS-IDEM-ROW
           END-IF.
           EXIT PARAGRAPH.

       IDEM-INSERT.
      *> First claim: INSERT the legacy PENDING row. 1062 means another
      *> attempt won the race and the caller must re-read.
           IF WS-IDEM-ENTITY = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "INSERT INTO " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " (idempotency_key, amount, status) VALUES (?, ?, 'PENDING')" DELIMITED BY SIZE
                   INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-KEY TO WS-BIND-1
               MOVE WS-IDEM-AMOUNT TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE SPACES TO WS-PREP-SQL
               STRING "INSERT INTO " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " (" DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                   ", idempotency_key, amount, status) VALUES (?, ?, ?, 'PENDING')" DELIMITED BY SIZE
                   INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-1
               MOVE WS-IDEM-KEY TO WS-BIND-2
               MOVE WS-IDEM-AMOUNT TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               IF WS-RESULT = "ERROR|EXEC_FAILED|1062"
                   MOVE "RETRY" TO WS-IDEM-STATUS
               ELSE
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
                   EXIT PARAGRAPH
               END-IF
           ELSE
               MOVE "PENDING" TO WS-IDEM-STATUS
               MOVE "1" TO WS-IDEM-OWNED
           END-IF.
           EXIT PARAGRAPH.

       IDEM-DECIDE.
      *> Replay / conflict / in-progress / stale-takeover on the legacy
      *> row. Byte-identical outcomes to the inline code this replaces:
      *> DONE + equal amount replays, DONE + different amount conflicts, a
      *> fresh PENDING owned by someone else is refused, a stale PENDING is
      *> taken over with a guarded UPDATE (lost race reports in-progress).
           UNSTRING WS-IDEM-ROW DELIMITED BY "|" INTO WS-IDEM-STATUS WS-IDEM-AMT WS-IDEM-STALE
           END-UNSTRING
           IF WS-IDEM-STATUS = "DONE"
               IF FUNCTION TRIM(WS-IDEM-AMT) NOT = FUNCTION TRIM(WS-IDEM-AMOUNT)
                   MOVE "ERROR|IDEMPOTENCY_CONFLICT" TO WS-ERR
               END-IF
           ELSE
               IF WS-IDEM-STALE NOT = "1"
                   MOVE WS-IDEM-CODE TO WS-ERR
               ELSE
                   IF WS-IDEM-ENTITY = SPACES
                       MOVE SPACES TO WS-PREP-SQL
                       STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                           " SET updated_at = NOW() WHERE idempotency_key = ? AND status = 'PENDING'"
                           DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
                       MOVE WS-IDEM-KEY TO WS-BIND-1
                       CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                       END-CALL
                   ELSE
                       MOVE SPACES TO WS-PREP-SQL
                       STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                           " SET updated_at = NOW() WHERE " DELIMITED BY SIZE
                           FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                           " = ? AND idempotency_key = ? AND status = 'PENDING'" DELIMITED BY SIZE
                           INTO WS-PREP-SQL END-STRING
                       MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-1
                       MOVE WS-IDEM-KEY TO WS-BIND-2
                       CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                       END-CALL
                   END-IF
                   CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                   IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                       MOVE WS-IDEM-CODE TO WS-ERR
                   ELSE
                       MOVE "PENDING" TO WS-IDEM-STATUS
                       MOVE "1" TO WS-IDEM-OWNED
                   END-IF
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       IDEM-MIRROR-SYNC.
      *> Dual-write: the legacy row is PENDING and owned by this attempt,
      *> so the unified mirror follows it (DELETE + INSERT PENDING). The
      *> legacy row is the mutex, so no two owners can interleave here. A
      *> mirror failure compensates by deleting our legacy PENDING row and
      *> failing closed, keeping the key usable instead of blocking it
      *> behind the stale window.
           MOVE "DELETE FROM idempotency_request WHERE scope = ? AND entity_ref = ? AND idem_key = ?" TO WS-PREP-SQL
           MOVE WS-IDEM-SCOPE TO WS-BIND-1
           MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
           MOVE WS-IDEM-KEY TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               PERFORM IDEM-COMPENSATE
               EXIT PARAGRAPH
           END-IF
           MOVE "INSERT INTO idempotency_request (scope, entity_ref, idem_key, amount, details, status) VALUES (?, ?, ?, ?, ?, 'PENDING')" TO WS-PREP-SQL
           MOVE WS-IDEM-SCOPE TO WS-BIND-1
           MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
           MOVE WS-IDEM-KEY TO WS-BIND-3
           MOVE WS-IDEM-AMOUNT TO WS-BIND-4
           MOVE WS-IDEM-DETAILS TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               PERFORM IDEM-COMPENSATE
           END-IF.
           EXIT PARAGRAPH.

       IDEM-MIRROR-DONE.
      *> Dual-write heal: the legacy row is DONE, so the mirror converges
      *> to DONE with the stored amount. Runs on every replay, which also
      *> repairs a mirror left PENDING by a crash between the legacy and
      *> mirror completions (the legacy row stays the truth either way).
           MOVE "DELETE FROM idempotency_request WHERE scope = ? AND entity_ref = ? AND idem_key = ?" TO WS-PREP-SQL
           MOVE WS-IDEM-SCOPE TO WS-BIND-1
           MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
           MOVE WS-IDEM-KEY TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE "INSERT INTO idempotency_request (scope, entity_ref, idem_key, amount, details, status) VALUES (?, ?, ?, ?, ?, 'DONE')" TO WS-PREP-SQL
           MOVE WS-IDEM-SCOPE TO WS-BIND-1
           MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
           MOVE WS-IDEM-KEY TO WS-BIND-3
           MOVE WS-IDEM-AMT TO WS-BIND-4
           MOVE WS-IDEM-DETAILS TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
           END-IF.
           EXIT PARAGRAPH.

       IDEM-COMPENSATE.
      *> Mirror sync failed after the legacy PENDING row was taken: drop
      *> our own legacy row so the key stays usable, then fail closed. The
      *> DONE path never compensates (a DONE legacy row is never touched).
           IF WS-IDEM-ENTITY = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "DELETE FROM " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE idempotency_key = ? AND status = 'PENDING'" DELIMITED BY SIZE
                   INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-KEY TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE SPACES TO WS-PREP-SQL
               STRING "DELETE FROM " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                   " = ? AND idempotency_key = ? AND status = 'PENDING'" DELIMITED BY SIZE
                   INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-1
               MOVE WS-IDEM-KEY TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE "0" TO WS-IDEM-OWNED
           MOVE SPACES TO WS-IDEM-STATUS
           MOVE "ERROR|DB_ERROR" TO WS-ERR.
           EXIT PARAGRAPH.

       IDEM-COMPLETE.
      *> Dual-write completion inside the action transaction: the legacy
      *> row flips to DONE first (it stays the truth if the mirror write
      *> crashes; the next replay heals the mirror), then the mirror
      *> follows. Any failure sets the host STEP-FAIL flag and the caller
      *> rolls everything back.
           IF WS-IDEM-ENTITY = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " SET status = 'DONE' WHERE idempotency_key = ?" DELIMITED BY SIZE
                   INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-KEY TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE SPACES TO WS-PREP-SQL
               STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " SET status = 'DONE' WHERE " DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                   " = ? AND idempotency_key = ?" DELIMITED BY SIZE
                   INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-1
               MOVE WS-IDEM-KEY TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF
           MOVE "UPDATE idempotency_request SET status = 'DONE' WHERE scope = ? AND entity_ref = ? AND idem_key = ?" TO WS-PREP-SQL
           MOVE WS-IDEM-SCOPE TO WS-BIND-1
           MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
           MOVE WS-IDEM-KEY TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "INSERT INTO idempotency_request (scope, entity_ref, idem_key, amount, details, status) VALUES (?, ?, ?, ?, ?, 'DONE')" TO WS-PREP-SQL
               MOVE WS-IDEM-SCOPE TO WS-BIND-1
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
               MOVE WS-IDEM-KEY TO WS-BIND-3
               MOVE WS-IDEM-AMOUNT TO WS-BIND-4
               MOVE WS-IDEM-DETAILS TO WS-BIND-5
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       IDEM-DELETE.
      *> Dual-write refusal cleanup: drops our own PENDING legacy row (the
      *> status guard never touches DONE) and the mirror row, so the key
      *> stays usable. Mirrors IDEM-COMPENSATE without the error outcome.
           IF WS-IDEM-OWNED = "1" AND WS-IDEM-KEY NOT = SPACES
               IF WS-IDEM-ENTITY = SPACES
                   MOVE SPACES TO WS-PREP-SQL
                   STRING "DELETE FROM " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                       " WHERE idempotency_key = ? AND status = 'PENDING'" DELIMITED BY SIZE
                       INTO WS-PREP-SQL END-STRING
                   MOVE WS-IDEM-KEY TO WS-BIND-1
                   CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                       BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                       BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                   END-CALL
               ELSE
                   MOVE SPACES TO WS-PREP-SQL
                   STRING "DELETE FROM " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                       " WHERE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                       " = ? AND idempotency_key = ? AND status = 'PENDING'" DELIMITED BY SIZE
                       INTO WS-PREP-SQL END-STRING
                   MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-1
                   MOVE WS-IDEM-KEY TO WS-BIND-2
                   CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                       BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                       BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                   END-CALL
               END-IF
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               MOVE "DELETE FROM idempotency_request WHERE scope = ? AND entity_ref = ? AND idem_key = ?" TO WS-PREP-SQL
               MOVE WS-IDEM-SCOPE TO WS-BIND-1
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
               MOVE WS-IDEM-KEY TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               MOVE "0" TO WS-IDEM-OWNED
           END-IF.
           EXIT PARAGRAPH.
