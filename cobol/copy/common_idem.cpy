      *> Unified idempotency mirror (maint-14A/14B): dual-store CLAIM /
      *> COMPLETE / DELETE / LINK for money actions with a client-supplied
      *> key. ADR-0008 protocol is unchanged; the ten per-action `*_request`
      *> tables stay the decision-makers in this release and
      *> idempotency_request is written alongside every transition so the
      *> suites prove the mirror converges. No legacy table is dropped
      *> here; reads cut over in a later PR.
      *>
      *> Caller contract (host declares all of these; the copybook never
      *> declares storage):
      *>   WS-IDEM-SCOPE      PIC X(32)  - action scope, e.g. "COL_PAY".
      *>                                  Unknown scopes fail closed.
      *>   WS-IDEM-ENTITY-VAL PIC X(64)  - trimmed entity id (case_id, ...);
      *>                                  SPACES for global keys (DEP_OPEN).
      *>   WS-IDEM-KEY        PIC X(64)  - trimmed idempotency key.
      *>   WS-IDEM-AMOUNT     PIC X(30)  - trimmed amount bound + compared
      *>                                  (AMOUNT mode) or stored (DETAILS).
      *>   WS-IDEM-CODE       PIC X(40)  - full in-progress error, e.g.
      *>                                  "ERROR|PAY_IN_PROGRESS".
      *>   WS-IDEM-V1..V5     PIC X(100) - DETAILS-mode tuple values, e.g.
      *>                                  OPEN email/principal/curr/term/rate.
      *>   WS-IDEM-DETAIL-COLS PIC X(200) - DETAILS-mode SQL column list
      *>                                  (plain names), e.g. OPEN 5-tuple;
      *>                                  SPACES selects AMOUNT mode.
      *>   WS-IDEM-DETAILS    PIC X(500) - DETAILS blob, built by the
      *>                                  copybook from V1..V5 (hosts leave
      *>                                  it alone); mirrored verbatim.
      *>   WS-IDEM-IDCOL      PIC X(30)  - adoption id column, e.g.
      *>                                  "deposit_id" (DEP_OPEN); SPACES =
      *>                                  none (DETAILS mode requires one).
      *>   WS-IDEM-SETCOL     PIC X(30)  - COMPLETE journal column, e.g.
      *>                                  "gl_journal_id" / "fund_gl_journal_id";
      *>                                  SPACES = status-only complete.
      *>   WS-IDEM-JIDVAL     PIC X(20)  - COMPLETE journal id bind; SPACES
      *>                                  takes the no-journal variant.
      *>   WS-IDEM-JIDNULL    PIC X      - "1" binds the journal with
      *>                                  NULLIF(?, '') (spaces mean NULL).
      *>   WS-IDEM-GUARD      PIC X      - "1" appends AND status='PENDING'
      *>                                  to the COMPLETE filter.
      *>   WS-IDEM-DIRECT     PIC X      - "1" reports COMPLETE failure via
      *>                                  WS-ERR (no transaction); default
      *>                                  sets the host STEP-FAIL flag.
      *>   WS-IDEM-LINKVAL    PIC X(20)  - IDEM-LINK id value.
      *> Managed by the copybook (host declares, caller does not set):
      *>   WS-IDEM-TABLE      PIC X(40)  - legacy table for the scope.
      *>   WS-IDEM-ENTITY     PIC X(30)  - legacy entity column, or SPACES
      *>                                  for global keys.
      *> Shared outcomes (host declares; same names the inline code used):
      *>   WS-IDEM-STATUS/OWNED/ROW/AMT/STALE/MATCH/REFID, WS-ERR. MATCH is
      *>   the DETAILS compare flag ("1" equal); REFID carries the adoption
      *>   id (DEP_OPEN deposit_id). COMPLETE reports through STEP-FAIL
      *>   inside the action transaction, or WS-ERR in DIRECT mode; CLAIM /
      *>   DELETE report through WS-ERR.
      *> Requires the standard WS-PREP-SQL, WS-BIND-1..6, WS-RESULT.
       IDEM-RESET.
      *> Input hygiene: every wrapper and inline call-site PERFORMS this
      *> first, then sets its own fields. The gateway server reuses one
      *> process across requests, so any field a caller does not set would
      *> otherwise leak the previous request's values (a global-key claim
      *> once inherited another action's entity id in the mirror). DETAILS
      *> is excluded: CLAIM builds it, COMPLETE heals with it.
           MOVE SPACES TO WS-IDEM-SCOPE WS-IDEM-ENTITY-VAL WS-IDEM-KEY
           MOVE SPACES TO WS-IDEM-AMOUNT WS-IDEM-CODE
           MOVE SPACES TO WS-IDEM-V1 WS-IDEM-V2 WS-IDEM-V3 WS-IDEM-V4
           MOVE SPACES TO WS-IDEM-V5 WS-IDEM-DETAIL-COLS WS-IDEM-IDCOL
           MOVE SPACES TO WS-IDEM-SETCOL WS-IDEM-JIDVAL WS-IDEM-JIDNULL
           MOVE SPACES TO WS-IDEM-GUARD WS-IDEM-DIRECT WS-IDEM-LINKVAL
           MOVE SPACES TO WS-IDEM-MATCH WS-IDEM-REFID.
           EXIT PARAGRAPH.

       IDEM-RESOLVE-SCOPE.
      *> Single source of scope -> legacy table/entity mapping. Resolved
      *> on every entry (CLAIM/COMPLETE/DELETE/LINK) because split modules
      *> (ADR-0010) claim in the callee and complete in the caller, whose
      *> working storage is separate: the mapping must not ride along in
      *> host memory. Unknown scopes fail closed (TABLE stays SPACES).
           MOVE SPACES TO WS-IDEM-TABLE WS-IDEM-ENTITY
           MOVE "amount" TO WS-IDEM-AMTCOL
           EVALUATE WS-IDEM-SCOPE
               WHEN "COL_PAY"
                   MOVE "collection_pay_request" TO WS-IDEM-TABLE
                   MOVE "case_id" TO WS-IDEM-ENTITY
               WHEN "CARD_CAPTURE"
                   MOVE "card_capture_request" TO WS-IDEM-TABLE
                   MOVE "card_id" TO WS-IDEM-ENTITY
               WHEN "CARD_REPAY"
                   MOVE "card_repay_request" TO WS-IDEM-TABLE
                   MOVE "card_id" TO WS-IDEM-ENTITY
               WHEN "CARD_REVERSE"
                   MOVE "card_reverse_request" TO WS-IDEM-TABLE
                   MOVE "card_id" TO WS-IDEM-ENTITY
               WHEN "DEP_OPEN"
                   MOVE "deposit_open_request" TO WS-IDEM-TABLE
                   MOVE SPACES TO WS-IDEM-ENTITY
                   MOVE "principal" TO WS-IDEM-AMTCOL
               WHEN "DEP_CLOSE"
                   MOVE "deposit_close_request" TO WS-IDEM-TABLE
                   MOVE "deposit_id" TO WS-IDEM-ENTITY
               WHEN "DEP_SETTLE"
                   MOVE "deposit_settle_request" TO WS-IDEM-TABLE
                   MOVE "deposit_id" TO WS-IDEM-ENTITY
               WHEN "LOAN_DISBURSE"
                   MOVE "loan_disburse_request" TO WS-IDEM-TABLE
                   MOVE "loan_id" TO WS-IDEM-ENTITY
               WHEN "LOAN_REPAY"
                   MOVE "loan_repay_request" TO WS-IDEM-TABLE
                   MOVE "loan_id" TO WS-IDEM-ENTITY
               WHEN "PMC_SETTLE"
                   MOVE "payment_settle_request" TO WS-IDEM-TABLE
                   MOVE "clearing_id" TO WS-IDEM-ENTITY
           END-EVALUATE.
           EXIT PARAGRAPH.

       IDEM-CLAIM.
           MOVE SPACES TO WS-IDEM-STATUS WS-IDEM-ROW WS-IDEM-AMT WS-IDEM-STALE
           MOVE SPACES TO WS-IDEM-MATCH WS-IDEM-REFID WS-IDEM-DETAILS
           MOVE "0" TO WS-IDEM-OWNED
           MOVE SPACES TO WS-ERR
           PERFORM IDEM-RESOLVE-SCOPE
           IF WS-IDEM-TABLE = SPACES
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               EXIT PARAGRAPH
           END-IF
           IF WS-IDEM-DETAIL-COLS NOT = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING FUNCTION TRIM(WS-IDEM-V1) DELIMITED BY SIZE "|"
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-V2) DELIMITED BY SIZE "|"
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-V3) DELIMITED BY SIZE "|"
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-V4) DELIMITED BY SIZE "|"
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-V5) DELIMITED BY SIZE
                   INTO WS-IDEM-DETAILS END-STRING
           END-IF
           IF WS-IDEM-DETAIL-COLS = SPACES
               PERFORM IDEM-SELECT-AMOUNT
           ELSE
               PERFORM IDEM-SELECT-DETAILS
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               PERFORM IDEM-INSERT
               IF WS-ERR NOT = SPACES
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "RETRY"
                   MOVE SPACES TO WS-IDEM-STATUS
                   IF WS-IDEM-DETAIL-COLS = SPACES
                       PERFORM IDEM-SELECT-AMOUNT
                   ELSE
                       PERFORM IDEM-SELECT-DETAILS
                   END-IF
                   CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                   IF WS-RESULT(1:5) = "ERROR"
                       MOVE "ERROR|DB_ERROR" TO WS-ERR
                   ELSE
                       MOVE WS-RESULT TO WS-IDEM-ROW
                   END-IF
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

       IDEM-SELECT-AMOUNT.
      *> Legacy SELECT, AMOUNT mode: the row carries status, amount and the
      *> stale flag; match/refid ride along as constants for one parse shape.
           IF WS-IDEM-ENTITY = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "SELECT CONCAT(status, '|', CAST(" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-AMTCOL) DELIMITED BY SIZE
                   " AS CHAR), '|', updated_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE), '|', '1', '|', '') FROM "
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE idempotency_key = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-KEY TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE SPACES TO WS-PREP-SQL
               STRING "SELECT CONCAT(status, '|', CAST(" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-AMTCOL) DELIMITED BY SIZE
                   " AS CHAR), '|', updated_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE), '|', '1', '|', '') FROM "
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                   " = ? AND idempotency_key = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-1
               MOVE WS-IDEM-KEY TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF.
           EXIT PARAGRAPH.

       IDEM-SELECT-DETAILS.
      *> Legacy SELECT, DETAILS mode (DEP_OPEN): the row carries status,
      *> amount and stale plus the tuple-match flag and the adoption id.
      *> The match compares the caller's tuple in SQL so the fetched row
      *> never embeds user data in the pipe stream.
           IF WS-IDEM-ENTITY = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "SELECT CONCAT(status, '|', CAST(" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-AMTCOL) DELIMITED BY SIZE
                   " AS CHAR), '|', updated_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE), '|', (CONCAT_WS('|', "
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-DETAIL-COLS) DELIMITED BY SIZE
                   ") = ?), '|', COALESCE(CAST(" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-IDCOL) DELIMITED BY SIZE
                   " AS CHAR), '')) FROM " DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE idempotency_key = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-DETAILS TO WS-BIND-1
               MOVE WS-IDEM-KEY TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE SPACES TO WS-PREP-SQL
               STRING "SELECT CONCAT(status, '|', CAST(" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-AMTCOL) DELIMITED BY SIZE
                   " AS CHAR), '|', updated_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE), '|', (CONCAT_WS('|', "
                   DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-DETAIL-COLS) DELIMITED BY SIZE
                   ") = ?), '|', COALESCE(CAST(" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-IDCOL) DELIMITED BY SIZE
                   " AS CHAR), '')) FROM " DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " WHERE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                   " = ? AND idempotency_key = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-DETAILS TO WS-BIND-1
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
               MOVE WS-IDEM-KEY TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF.
           EXIT PARAGRAPH.

       IDEM-INSERT.
      *> First claim: INSERT the legacy PENDING row. 1062 means another
      *> attempt won the race and the caller must re-read.
           IF WS-IDEM-DETAIL-COLS NOT = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "INSERT INTO " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " (idempotency_key, " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-DETAIL-COLS) DELIMITED BY SIZE
                   ", status) VALUES (?, ?, ?, ?, ?, ?, 'PENDING')" DELIMITED BY SIZE
                   INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-KEY TO WS-BIND-1
               MOVE WS-IDEM-V1 TO WS-BIND-2
               MOVE WS-IDEM-V2 TO WS-BIND-3
               MOVE WS-IDEM-V3 TO WS-BIND-4
               MOVE WS-IDEM-V4 TO WS-BIND-5
               MOVE WS-IDEM-V5 TO WS-BIND-6
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
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
      *> DONE + equal details replays, DONE + different details conflicts,
      *> a fresh PENDING owned by someone else is refused, a stale PENDING
      *> is taken over with a guarded UPDATE (lost race reports in-progress).
           UNSTRING WS-IDEM-ROW DELIMITED BY "|" INTO WS-IDEM-STATUS WS-IDEM-AMT WS-IDEM-STALE WS-IDEM-MATCH WS-IDEM-REFID
           END-UNSTRING
           IF WS-IDEM-STATUS = "DONE"
               IF WS-IDEM-DETAIL-COLS NOT = SPACES
                   IF WS-IDEM-MATCH NOT = "1"
                       MOVE "ERROR|IDEMPOTENCY_CONFLICT" TO WS-ERR
                   END-IF
               ELSE
                   IF FUNCTION TRIM(WS-IDEM-AMT) NOT = FUNCTION TRIM(WS-IDEM-AMOUNT)
                       MOVE "ERROR|IDEMPOTENCY_CONFLICT" TO WS-ERR
                   END-IF
               END-IF
           ELSE
               IF WS-IDEM-STALE NOT = "1"
                   MOVE WS-IDEM-CODE TO WS-ERR
               ELSE
                   IF WS-IDEM-DETAIL-COLS NOT = SPACES
                       IF WS-IDEM-MATCH NOT = "1"
                           MOVE "ERROR|IDEMPOTENCY_CONFLICT" TO WS-ERR
                       END-IF
                   END-IF
                   IF WS-ERR = SPACES
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
      *> to DONE with the stored amount and details. Runs on every replay,
      *> which also repairs a mirror left PENDING by a crash between the
      *> legacy and mirror completions (the legacy row stays the truth
      *> either way). A single upsert: a no-change UPDATE reports
      *> AFFECTED_0, which must not be mistaken for a missing row. The
      *> journal link is written only by IDEM-COMPLETE and never clobbered
      *> here.
           IF WS-IDEM-JIDVAL NOT = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "INSERT INTO idempotency_request (scope, entity_ref, idem_key, amount, details, status, gl_journal_id) VALUES (?, ?, ?, ?, ?, 'DONE', ?) ON DUPLICATE KEY UPDATE status = 'DONE', amount = VALUES(amount), details = VALUES(details)"
                   DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-SCOPE TO WS-BIND-1
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
               MOVE WS-IDEM-KEY TO WS-BIND-3
               MOVE WS-IDEM-AMT TO WS-BIND-4
               MOVE WS-IDEM-DETAILS TO WS-BIND-5
               MOVE WS-IDEM-JIDVAL TO WS-BIND-6
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE SPACES TO WS-PREP-SQL
               STRING "INSERT INTO idempotency_request (scope, entity_ref, idem_key, amount, details, status) VALUES (?, ?, ?, ?, ?, 'DONE') ON DUPLICATE KEY UPDATE status = 'DONE', amount = VALUES(amount), details = VALUES(details)"
                   DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-SCOPE TO WS-BIND-1
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
               MOVE WS-IDEM-KEY TO WS-BIND-3
               MOVE WS-IDEM-AMT TO WS-BIND-4
               MOVE WS-IDEM-DETAILS TO WS-BIND-5
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
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
      *> rolls everything back; DIRECT mode (no transaction) reports via
      *> WS-ERR for the caller to handle. The journal column (SETCOL),
      *> NULLIF form, PENDING guard and DIRECT mode are caller-selected;
      *> each combination is its own straight-line branch below.
           PERFORM IDEM-RESOLVE-SCOPE
           IF WS-IDEM-TABLE = SPACES
               IF WS-IDEM-DIRECT = "1"
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
               ELSE
                   SET STEP-FAIL TO TRUE
               END-IF
               EXIT PARAGRAPH
           END-IF
           IF WS-IDEM-SETCOL = SPACES
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
           ELSE
               IF WS-IDEM-JIDNULL = "1"
                   MOVE SPACES TO WS-PREP-SQL
                   STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                       " SET status = 'DONE', " DELIMITED BY SIZE
                       FUNCTION TRIM(WS-IDEM-SETCOL) DELIMITED BY SIZE
                       " = NULLIF(?, '') WHERE " DELIMITED BY SIZE
                       FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                       " = ? AND idempotency_key = ?" DELIMITED BY SIZE
                       INTO WS-PREP-SQL END-STRING
                   MOVE WS-IDEM-JIDVAL TO WS-BIND-1
                   MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
                   MOVE WS-IDEM-KEY TO WS-BIND-3
                   CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                       BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                       BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                   END-CALL
               ELSE
                   IF WS-IDEM-ENTITY = SPACES
                       IF WS-IDEM-GUARD = "1"
                           MOVE SPACES TO WS-PREP-SQL
                           STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                               " SET status = 'DONE', " DELIMITED BY SIZE
                               FUNCTION TRIM(WS-IDEM-SETCOL) DELIMITED BY SIZE
                               " = ? WHERE idempotency_key = ? AND status = 'PENDING'" DELIMITED BY SIZE
                               INTO WS-PREP-SQL END-STRING
                       ELSE
                           MOVE SPACES TO WS-PREP-SQL
                           STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                               " SET status = 'DONE', " DELIMITED BY SIZE
                               FUNCTION TRIM(WS-IDEM-SETCOL) DELIMITED BY SIZE
                               " = ? WHERE idempotency_key = ?" DELIMITED BY SIZE
                               INTO WS-PREP-SQL END-STRING
                       END-IF
                       MOVE WS-IDEM-JIDVAL TO WS-BIND-1
                       MOVE WS-IDEM-KEY TO WS-BIND-2
                       CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                       END-CALL
                   ELSE
                       MOVE SPACES TO WS-PREP-SQL
                       STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                           " SET status = 'DONE', " DELIMITED BY SIZE
                           FUNCTION TRIM(WS-IDEM-SETCOL) DELIMITED BY SIZE
                           " = ? WHERE " DELIMITED BY SIZE
                           FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                           " = ? AND idempotency_key = ?" DELIMITED BY SIZE
                           INTO WS-PREP-SQL END-STRING
                       MOVE WS-IDEM-JIDVAL TO WS-BIND-1
                       MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
                       MOVE WS-IDEM-KEY TO WS-BIND-3
                       CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                       END-CALL
                   END-IF
               END-IF
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               IF WS-IDEM-DIRECT = "1"
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
               ELSE
                   SET STEP-FAIL TO TRUE
               END-IF
               EXIT PARAGRAPH
           END-IF
           IF WS-IDEM-JIDVAL = SPACES
               MOVE "UPDATE idempotency_request SET status = 'DONE' WHERE scope = ? AND entity_ref = ? AND idem_key = ?" TO WS-PREP-SQL
               MOVE WS-IDEM-SCOPE TO WS-BIND-1
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
               MOVE WS-IDEM-KEY TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE "UPDATE idempotency_request SET status = 'DONE', gl_journal_id = ? WHERE scope = ? AND entity_ref = ? AND idem_key = ?" TO WS-PREP-SQL
               MOVE WS-IDEM-JIDVAL TO WS-BIND-1
               MOVE WS-IDEM-SCOPE TO WS-BIND-2
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-3
               MOVE WS-IDEM-KEY TO WS-BIND-4
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               IF WS-IDEM-DIRECT = "1"
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
               ELSE
                   SET STEP-FAIL TO TRUE
               END-IF
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               IF WS-IDEM-JIDVAL NOT = SPACES
                   MOVE "INSERT INTO idempotency_request (scope, entity_ref, idem_key, amount, details, status, gl_journal_id) VALUES (?, ?, ?, ?, ?, 'DONE', ?)" TO WS-PREP-SQL
                   MOVE WS-IDEM-SCOPE TO WS-BIND-1
                   MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
                   MOVE WS-IDEM-KEY TO WS-BIND-3
                   MOVE WS-IDEM-AMOUNT TO WS-BIND-4
                   MOVE WS-IDEM-DETAILS TO WS-BIND-5
                   MOVE WS-IDEM-JIDVAL TO WS-BIND-6
                   CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                       BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                       BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                   END-CALL
               ELSE
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
               END-IF
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   IF WS-IDEM-DIRECT = "1"
                       MOVE "ERROR|DB_ERROR" TO WS-ERR
                   ELSE
                       SET STEP-FAIL TO TRUE
                   END-IF
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       IDEM-DELETE.
      *> Dual-write refusal cleanup: drops our own PENDING legacy row (the
      *> status guard never touches DONE) and the mirror row, so the key
      *> stays usable. Mirrors IDEM-COMPENSATE without the error outcome.
           PERFORM IDEM-RESOLVE-SCOPE
           IF WS-IDEM-TABLE = SPACES
               EXIT PARAGRAPH
           END-IF
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

       IDEM-LINK.
      *> Dual-write linkage (DEP_OPEN): after the funded deposit row exists,
      *> the request row adopts it, and the mirror follows the link by
      *> moving its entity_ref. Runs inside the funding transaction; failure
      *> sets STEP-FAIL and rolls everything back.
           PERFORM IDEM-RESOLVE-SCOPE
           IF WS-IDEM-TABLE = SPACES
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF
           IF WS-IDEM-ENTITY = SPACES
               MOVE SPACES TO WS-PREP-SQL
               STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " SET " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-IDCOL) DELIMITED BY SIZE
                   " = ? WHERE idempotency_key = ? AND status = 'PENDING'" DELIMITED BY SIZE
                   INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-LINKVAL TO WS-BIND-1
               MOVE WS-IDEM-KEY TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE SPACES TO WS-PREP-SQL
               STRING "UPDATE " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-TABLE) DELIMITED BY SIZE
                   " SET " DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-IDCOL) DELIMITED BY SIZE
                   " = ? WHERE " DELIMITED BY SIZE
                   FUNCTION TRIM(WS-IDEM-ENTITY) DELIMITED BY SIZE
                   " = ? AND idempotency_key = ? AND status = 'PENDING'" DELIMITED BY SIZE
                   INTO WS-PREP-SQL END-STRING
               MOVE WS-IDEM-LINKVAL TO WS-BIND-1
               MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
               MOVE WS-IDEM-KEY TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF
           MOVE "UPDATE idempotency_request SET entity_ref = ? WHERE scope = ? AND entity_ref = ? AND idem_key = ?" TO WS-PREP-SQL
           MOVE WS-IDEM-LINKVAL TO WS-BIND-1
           MOVE WS-IDEM-SCOPE TO WS-BIND-2
           MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-3
           MOVE WS-IDEM-KEY TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.
