       IDENTIFICATION DIVISION.
       PROGRAM-ID. deposit_posting_core.
      *> Deposit posting resolves (maint-06, ADR-0010): the pre-transaction
      *> resolve+GL-post paragraphs relocated from deposit_core. The owner
      *> keeps the action dispatch, the auth guards, and the single
      *> transaction per action; this module issues zero SQL_BEGIN/COMMIT/
      *> ROLLBACK and never CALLs back into deposit_core. It runs before any
      *> deposit transaction opens (gl_core posts on its own transaction,
      *> exactly as before the split). The settle idempotency helpers moved
      *> along as resolve internals: only ACTION-POST-SETTLE uses them.
      *>
      *> Contract (internal CALL, pre-trimmed inputs like every module seam):
      *>   LS-PARAM1 = deposit id, LS-PARAM2 = days (accrue; spaces = 30),
      *>     LS-PARAM5 = idempotency key (settle), LS-PARAM6 = actor email
      *>     (GL audit actor). LS-PARAM3/4 unused.
      *>   Success: SUCCESS|POST_READY|<9 pipe fields>
      *>     TMP-AMT|CUST-EMAIL|CURR-ID|CUST-ACC|POOL-ACC|GL-JID|TXN-REF|
      *>     DESC|TMP-DAYS (fixed widths, empty when the action needs none).
      *>     Settle idempotency replay bypasses POST_READY and returns
      *>     SUCCESS|DEP_SETTLE|<amount> verbatim for caller passthrough.
      *>   Error: ERROR|<CODE>|<CLEANUP 0/1>. The caller runs the DELETE-*
      *>     cleanup on CLEANUP=1 and reproduces the exact output mapping.
      *>     GL errors pass through verbatim with CLEANUP=0 (no cleanup ran
      *>     before the split, none runs now).

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESULT               PIC X(16384) VALUE SPACES.
       01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
       01  WS-BIND-1               PIC X(256) VALUE SPACES.
       01  WS-BIND-2               PIC X(256) VALUE SPACES.
       01  WS-BIND-3               PIC X(256) VALUE SPACES.
       01  WS-BIND-4               PIC X(256) VALUE SPACES.
       01  WS-BIND-5               PIC X(256) VALUE SPACES.
       01  WS-BIND-6               PIC X(256) VALUE SPACES.
       01  WS-P1-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P2-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P3-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P4-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P5-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P6-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P1-LEN               PIC 9(3) VALUE 1.
       01  WS-P2-LEN               PIC 9(3) VALUE 1.
       01  WS-P3-LEN               PIC 9(3) VALUE 1.
       01  WS-P4-LEN               PIC 9(3) VALUE 1.
       01  WS-P5-LEN               PIC 9(3) VALUE 1.
       01  WS-P6-LEN               PIC 9(3) VALUE 1.
       01  WS-TRIM-IN              PIC X(100) VALUE SPACES.
       01  WS-TRIM-OUT             PIC X(100) VALUE SPACES.
       01  WS-TRIM-LEN             PIC 9(3) VALUE 1.
       01  WS-I                    PIC 9(3) VALUE 1.
       01  WS-BAD                  PIC 9(3) VALUE 0.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-DAYS-NUM             PIC 9(5) VALUE 0.
       01  WS-STATUS-TEXT          PIC X(20) VALUE SPACES.
       01  WS-COUNT-NUM            PIC 9(9) VALUE 0.
       01  WS-TMP-AMT              PIC X(30) VALUE SPACES.
       01  WS-TMP-STR              PIC X(100) VALUE SPACES.
       01  WS-TMP-DAYS             PIC X(10) VALUE SPACES.
       01  WS-CUST-EMAIL           PIC X(100) VALUE SPACES.
       01  WS-CUST-CURR            PIC X(10) VALUE SPACES.
       01  WS-CUST-ACC             PIC X(20) VALUE SPACES.
       01  WS-POOL-ACC             PIC X(20) VALUE SPACES.
       01  WS-CURR-ID              PIC X(20) VALUE SPACES.
       01  WS-POST-DATE            PIC X(10) VALUE SPACES.
       01  WS-GL-DESC              PIC X(100) VALUE SPACES.
       01  WS-GL-LINES             PIC X(100) VALUE SPACES.
       01  WS-GL-JID               PIC X(20) VALUE SPACES.
       01  WS-JOUT-1               PIC X(20) VALUE SPACES.
       01  WS-JOUT-2               PIC X(20) VALUE SPACES.
       01  WS-CALL-ACTION          PIC X(30) VALUE SPACES.
       01  WS-CALL-P1              PIC X(100) VALUE SPACES.
       01  WS-CALL-P2              PIC X(100) VALUE SPACES.
       01  WS-CALL-P3              PIC X(100) VALUE SPACES.
       01  WS-CALL-P4              PIC X(100) VALUE SPACES.
       01  WS-CALL-P5              PIC X(100) VALUE SPACES.
       01  WS-CALL-P6              PIC X(100) VALUE SPACES.
       01  WS-CALL-OUT             PIC X(16384) VALUE SPACES.
       01  WS-TXN-REF              PIC X(50) VALUE SPACES.
       01  WS-DESC                 PIC X(255) VALUE SPACES.
       01  WS-IDEM-STATUS          PIC X(10) VALUE SPACES.
       01  WS-IDEM-OWNED           PIC X VALUE "0".
       01  WS-IDEM-ROW             PIC X(200) VALUE SPACES.
       01  WS-IDEM-AMT             PIC X(30) VALUE SPACES.
       01  WS-IDEM-JID             PIC X(20) VALUE SPACES.
       01  WS-IDEM-STALE           PIC X VALUE SPACES.
       01  WS-IDEM-SCOPE           PIC X(32) VALUE SPACES.
       01  WS-IDEM-ENTITY-VAL      PIC X(64) VALUE SPACES.
       01  WS-IDEM-KEY             PIC X(64) VALUE SPACES.
       01  WS-IDEM-AMOUNT          PIC X(30) VALUE SPACES.
       01  WS-IDEM-DETAILS         PIC X(500) VALUE SPACES.
       01  WS-IDEM-AMTCOL          PIC X(30) VALUE SPACES.
       01  WS-IDEM-TABLE           PIC X(40) VALUE SPACES.
       01  WS-IDEM-ENTITY          PIC X(30) VALUE SPACES.
       01  WS-IDEM-CODE            PIC X(40) VALUE SPACES.
       01  WS-IDEM-V1              PIC X(100) VALUE SPACES.
       01  WS-IDEM-V2              PIC X(100) VALUE SPACES.
       01  WS-IDEM-V3              PIC X(100) VALUE SPACES.
       01  WS-IDEM-V4              PIC X(100) VALUE SPACES.
       01  WS-IDEM-V5              PIC X(100) VALUE SPACES.
       01  WS-IDEM-DETAIL-COLS     PIC X(200) VALUE SPACES.
       01  WS-IDEM-MATCH           PIC X VALUE SPACES.
       01  WS-IDEM-REFID           PIC X(20) VALUE SPACES.
       01  WS-IDEM-IDCOL           PIC X(30) VALUE SPACES.
       01  WS-IDEM-SETCOL          PIC X(30) VALUE SPACES.
       01  WS-IDEM-JIDVAL          PIC X(20) VALUE SPACES.
       01  WS-IDEM-JIDNULL         PIC X VALUE SPACES.
       01  WS-IDEM-GUARD           PIC X VALUE SPACES.
       01  WS-IDEM-DIRECT          PIC X VALUE SPACES.
       01  WS-IDEM-LINKVAL         PIC X(20) VALUE SPACES.
       01  F-QUOTE                 PIC X VALUE "'".
       01  F-DQUOTE                PIC X VALUE '"'.
       01  F-BSLASH                PIC X VALUE "\".
       01  F-TICK                  PIC X VALUE "`".
       01  WS-ERR-CODE             PIC X(40) VALUE SPACES.
       01  WS-ERR-CLEAN            PIC X VALUE SPACE.

       LINKAGE SECTION.
       01  LS-CMD-ACTION           PIC X(30).
       01  LS-PARAM1               PIC X(100).
       01  LS-PARAM2               PIC X(100).
       01  LS-PARAM3               PIC X(100).
       01  LS-PARAM4               PIC X(100).
       01  LS-PARAM5               PIC X(100).
       01  LS-PARAM6               PIC X(100).
       01  LS-OUTPUT-BUFFER        PIC X(16384).

       PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2
           LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

       MAIN-LOGIC.
           PERFORM VALIDATE-ALL
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT|0" TO LS-OUTPUT-BUFFER
               GOBACK
           END-IF
           EVALUATE TRUE
               WHEN LS-CMD-ACTION(1:15) = "DEP_POST_ACCRUE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POST-ACCRUE
               WHEN LS-CMD-ACTION(1:17) = "DEP_POST_INTEREST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POST-INTEREST
               WHEN LS-CMD-ACTION(1:15) = "DEP_POST_SETTLE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POST-SETTLE
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION|0" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_validate_all.cpy".
        COPY "common_sql.cpy".
        COPY "common_trim.cpy".

        COPY "common_idem.cpy".

       ACTION-POST-ACCRUE.
           MOVE 30 TO WS-DAYS-NUM
           IF WS-P2-TRIMMED NOT = SPACES
               MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-DAYS-NUM
               IF WS-DAYS-NUM = 0
                   MOVE 30 TO WS-DAYS-NUM
               END-IF
           END-IF.
           MOVE "SELECT status FROM deposit_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-STATUS-TEXT
           IF WS-STATUS-TEXT(1:6) NOT = "ACTIVE"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-DAYS-NUM TO WS-TMP-DAYS
           PERFORM POST-OK.
           EXIT PARAGRAPH.

       ACTION-POST-INTEREST.
           *> Accrual accounting: recognizing posted interest also
           *> books the expense (gl_core owns its own transaction
           *> on this connection): DEBIT Deposit interest expense /
           *> CREDIT Deposits payable.

           MOVE "SELECT CONCAT(CAST(COALESCE(SUM(interest), 0) AS CHAR), '|', COUNT(*)) FROM deposit_accrual WHERE deposit_id = ? AND status = 'ACCRUED'" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-TMP-AMT
           MOVE SPACES TO WS-TMP-STR
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-AMT WS-TMP-STR END-UNSTRING
           MOVE FUNCTION NUMVAL(WS-TMP-STR) TO WS-COUNT-NUM
           IF WS-COUNT-NUM = 0
               MOVE "ERROR|NOTHING_TO_POST" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           *> Accrual accounting: recognizing posted interest also books the
           *> expense (gl_core owns its own transaction on this connection):
           *> DEBIT Deposit interest expense / CREDIT Deposits payable. The
           *> description carries the batch amount, so a retry of a
           *> posted-but-unlinked batch re-links the existing journal.
           MOVE "SELECT currency FROM deposit_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:10) TO WS-CUST-CURR
           MOVE "SELECT CAST(CURDATE() AS CHAR)" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:10) TO WS-POST-DATE
           MOVE SPACES TO WS-GL-DESC WS-GL-LINES WS-GL-JID
           STRING "DEP_POST:" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
           STRING "5010:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE ":0;2120:0:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
           MOVE "SELECT id FROM gl_journal WHERE description = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-GL-DESC TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               IF WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
                   MOVE "0" TO WS-ERR-CLEAN
                   PERFORM POST-FAIL
                   EXIT PARAGRAPH
               END-IF
           ELSE
               MOVE WS-RESULT(1:20) TO WS-GL-JID
           END-IF.
           IF WS-GL-JID = SPACES
               MOVE "GL_JOURNAL_POST_ML" TO WS-CALL-ACTION
               MOVE WS-POST-DATE TO WS-CALL-P1
               MOVE WS-GL-DESC TO WS-CALL-P2
               MOVE WS-CUST-CURR TO WS-CALL-P3
               MOVE WS-GL-LINES TO WS-CALL-P4
               MOVE SPACES TO WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
               MOVE WS-P6-TRIMMED TO WS-CALL-P6
               CALL "gl_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                   WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
               END-CALL
               IF WS-CALL-OUT(1:5) = "ERROR"
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING FUNCTION TRIM(WS-CALL-OUT) DELIMITED BY SIZE "|0" DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
               MOVE SPACES TO WS-JOUT-1 WS-JOUT-2 WS-GL-JID
               UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-GL-JID END-UNSTRING
               IF WS-JOUT-2 NOT = "GL_POSTED_ML" OR WS-GL-JID = SPACES
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
                   MOVE "0" TO WS-ERR-CLEAN
                   PERFORM POST-FAIL
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           PERFORM POST-OK.
           EXIT PARAGRAPH.

       ACTION-POST-SETTLE.

           MOVE "SELECT CONCAT(CAST(principal + posted_interest AS CHAR), '|', status, '|', customer_email, '|', currency) FROM deposit_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-TMP-AMT
           MOVE SPACES TO WS-STATUS-TEXT WS-CUST-EMAIL WS-CUST-CURR
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-AMT WS-STATUS-TEXT WS-CUST-EMAIL WS-CUST-CURR END-UNSTRING
           IF WS-P5-TRIMMED NOT = SPACES
               PERFORM CLAIM-SETTLE-REQUEST
               IF WS-ERR NOT = SPACES
                   MOVE "0" TO WS-ERR-CLEAN
                   PERFORM POST-FAIL
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "DONE"
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING "SUCCESS|DEP_SETTLE|" DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-AMT) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF WS-STATUS-TEXT(1:6) NOT = "ACTIVE"
               AND WS-STATUS-TEXT(1:7) NOT = "MATURED"
               PERFORM DELETE-SETTLE-REQUEST
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           *> Resolve the payout path: customer wallet in the deposit
           *> currency plus the bank-owned DEPOSIT_POOL suspense. The pool
           *> is treasury-capitalized; an underfunded pool fails closed
           *> instead of printing money.
           MOVE WS-CUST-CURR TO WS-BIND-1
           PERFORM LOOKUP-CURRENCY
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-CURR-ID
           MOVE "SELECT CAST(a.account_id AS CHAR) FROM accounts a JOIN users u ON u.id = a.user_id WHERE u.email = ? AND a.currency_id = ? AND a.status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-CUST-EMAIL TO WS-BIND-1
           MOVE WS-CURR-ID TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               PERFORM DELETE-SETTLE-REQUEST
               MOVE "ERROR|ACCOUNT_NOT_FOUND" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-CUST-ACC
           MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'DEPOSIT_POOL' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-CURR-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               PERFORM DELETE-SETTLE-REQUEST
               MOVE "ERROR|DEPOSIT_POOL_MISSING" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-POOL-ACC
           *> Bank-side journal first (gl_core owns its own transaction on
           *> this connection): DEBIT Deposits payable / CREDIT Cash.
           MOVE "SELECT CAST(CURDATE() AS CHAR)" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:10) TO WS-POST-DATE
           MOVE SPACES TO WS-GL-DESC WS-GL-LINES
           STRING "DEP_SETTLE:" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
           STRING "2120:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE ":0;1000:0:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
           MOVE SPACES TO WS-GL-JID
           MOVE "SELECT id FROM gl_journal WHERE description = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-GL-DESC TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               IF WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
                   MOVE "0" TO WS-ERR-CLEAN
                   PERFORM POST-FAIL
                   EXIT PARAGRAPH
               END-IF
           ELSE
               MOVE WS-RESULT(1:20) TO WS-GL-JID
           END-IF.
           IF WS-GL-JID = SPACES
               MOVE "GL_JOURNAL_POST_ML" TO WS-CALL-ACTION
               MOVE WS-POST-DATE TO WS-CALL-P1
               MOVE WS-GL-DESC TO WS-CALL-P2
               MOVE WS-CUST-CURR TO WS-CALL-P3
               MOVE WS-GL-LINES TO WS-CALL-P4
               MOVE SPACES TO WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
               MOVE WS-P6-TRIMMED TO WS-CALL-P6
               CALL "gl_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                   WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
               END-CALL
               IF WS-CALL-OUT(1:5) = "ERROR"
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING FUNCTION TRIM(WS-CALL-OUT) DELIMITED BY SIZE "|0" DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
               MOVE SPACES TO WS-JOUT-1 WS-JOUT-2 WS-GL-JID
               UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-GL-JID END-UNSTRING
               IF WS-JOUT-2 NOT = "GL_POSTED_ML" OR WS-GL-JID = SPACES
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
                   MOVE "0" TO WS-ERR-CLEAN
                   PERFORM POST-FAIL
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE SPACES TO WS-TXN-REF WS-DESC
           STRING "DEP-" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE INTO WS-TXN-REF END-STRING
           STRING "DEP_SETTLE:" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-DESC END-STRING
           PERFORM POST-OK.
           EXIT PARAGRAPH.


       CLAIM-SETTLE-REQUEST.
           *> Client-supplied idempotency for settle (P5), migrated to
           *> common_idem.cpy: the legacy row stays the decision-maker while
           *> every transition is mirrored to idempotency_request.
           PERFORM IDEM-RESET
           MOVE "DEP_SETTLE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
           MOVE SPACES TO WS-IDEM-DETAILS
           MOVE "ERROR|SETTLE_IN_PROGRESS" TO WS-IDEM-CODE
           PERFORM IDEM-CLAIM.
           EXIT PARAGRAPH.

       DELETE-SETTLE-REQUEST.
           *> Drops our own PENDING request row on refusal (status guard);
           *> DONE rows are never touched. The mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "DEP_SETTLE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       POST-FAIL.
           *> Shared error writer: WS-ERR carries the full "ERROR|<CODE>"
           *> (verbatim GL output included); WS-ERR-CLEAN carries "1" when
           *> the caller must run its DELETE-* cleanup first.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING FUNCTION TRIM(WS-ERR) DELIMITED BY SIZE "|"
               DELIMITED BY SIZE WS-ERR-CLEAN DELIMITED BY SIZE
               INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.

       POST-OK.
           *> Shared success writer: the nine fixed-width resolve outputs
           *> the caller UNSTRINGs back into its own working storage.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|POST_READY|" DELIMITED BY SIZE
               WS-TMP-AMT DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-CUST-EMAIL DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-CURR-ID DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-CUST-ACC DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-POOL-ACC DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-GL-JID DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-TXN-REF DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-DESC DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-TMP-DAYS DELIMITED BY SIZE
               INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.
