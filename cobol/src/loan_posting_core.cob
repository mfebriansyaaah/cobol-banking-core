       IDENTIFICATION DIVISION.
       PROGRAM-ID. loan_posting_core.
      *> Loan posting resolves (maint-09, ADR-0010): the pre-transaction
      *> resolve+GL-post paragraphs relocated from loan_core. The owner
      *> keeps the action dispatch, the auth guards, and the single
      *> transaction per action; this module issues zero SQL_BEGIN/COMMIT/
      *> ROLLBACK and never CALLs back into loan_core. It runs before any
      *> loan transaction opens (gl_core posts on its own transaction,
      *> exactly as before the split). The disburse/repay idempotency
      *> helpers moved along as resolve internals.
      *>
      *> Contract (internal CALL, pre-trimmed inputs like every module seam):
      *>   LS-PARAM1 = loan id, LS-PARAM2 = amount (repay; spaces for
      *>     disburse — the principal comes from the application row),
      *>     LS-PARAM5 = idempotency key, LS-PARAM6 = actor email (GL audit
      *>     actor). LS-PARAM3/4 unused.
      *>   Success: SUCCESS|POST_READY|<9 pipe fields>
      *>     AMT|LOAN-EMAIL|CURR-ID|CUST-ACC|BOOK-ACC|GL-JID|TXN-REF|DESC|
      *>     REPAY-ID (fixed widths, empty when the action needs none).
      *>     Idempotency replay bypasses POST_READY and returns
      *>     SUCCESS|LOAN_DISBURSE / SUCCESS|LOAN_REPAY verbatim for caller
      *>     passthrough.
      *>   Error: ERROR|<CODE>|<CLEANUP 0/1>. CLEANUP=1 paths self-clean
      *>     inside the callee (it owns the DELETE-* paragraphs); the
      *>     caller reproduces the exact output mapping. GL errors pass
      *>     through verbatim with CLEANUP=0 (no cleanup ran before the
      *>     split, none runs now).

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
        01  WS-P5-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P6-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
        01  WS-TMP-AMT              PIC X(30) VALUE SPACES.
        01  WS-TMP-STATUS           PIC X(20) VALUE SPACES.
        01  WS-KYC-GUARD            PIC X(20) VALUE SPACES.
        01  WS-LOAN-AMT             PIC X(30) VALUE SPACES.
        01  WS-TMP-CURR             PIC X(10) VALUE SPACES.
        01  WS-TMP-ID               PIC X(100) VALUE SPACES.
        01  WS-NUM-AMOUNT           PIC 9(15)V9(4) VALUE 0.
        01  WS-AMT-EDIT             PIC Z(14)9.9999 VALUE 0.
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
        01  WS-CALL-ACTION          PIC X(30) VALUE SPACES.
        01  WS-CALL-P1              PIC X(100) VALUE SPACES.
        01  WS-CALL-P2              PIC X(100) VALUE SPACES.
        01  WS-CALL-P3              PIC X(100) VALUE SPACES.
        01  WS-CALL-P4              PIC X(100) VALUE SPACES.
        01  WS-CALL-P5              PIC X(100) VALUE SPACES.
        01  WS-CALL-P6              PIC X(100) VALUE SPACES.
        01  WS-CALL-OUT             PIC X(16384) VALUE SPACES.
        01  WS-POST-DATE            PIC X(10) VALUE SPACES.
        01  WS-GL-DESC              PIC X(100) VALUE SPACES.
        01  WS-GL-LINES             PIC X(100) VALUE SPACES.
        01  WS-GL-JID               PIC X(20) VALUE SPACES.
        01  WS-JOUT-1               PIC X(20) VALUE SPACES.
        01  WS-JOUT-2               PIC X(20) VALUE SPACES.
        01  WS-LOAN-CURR            PIC X(10) VALUE SPACES.
        01  WS-LOAN-EMAIL           PIC X(100) VALUE SPACES.
        01  WS-CUST-ACC             PIC X(20) VALUE SPACES.
        01  WS-CURR-ID              PIC X(20) VALUE SPACES.
        01  WS-BOOK-ACC             PIC X(20) VALUE SPACES.
        01  WS-JID                  PIC X(20) VALUE SPACES.
        01  WS-TXN-REF              PIC X(50) VALUE SPACES.
        01  WS-DESC                 PIC X(255) VALUE SPACES.
        01  WS-REPAY-ID             PIC X(20) VALUE SPACES.
       01  WS-ERR-CODE             PIC X(40) VALUE SPACES.
       01  WS-ERR-CLEAN            PIC X VALUE SPACE.
        01  WS-TRIM-IN              PIC X(100) VALUE SPACES.
        01  WS-TRIM-OUT             PIC X(100) VALUE SPACES.
        01  WS-TRIM-LEN             PIC 9(3) VALUE 1.
        01  WS-I                    PIC 9(3) VALUE 1.
        01  F-QUOTE                 PIC X VALUE "'".
        01  F-DQUOTE                PIC X VALUE '"'.
        01  F-BSLASH                PIC X VALUE "\".
        01  F-TICK                  PIC X VALUE "`".
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-P5-LEN               PIC 9(3) VALUE 1.
        01  WS-P6-LEN               PIC 9(3) VALUE 1.
        01  WS-BAD                  PIC 9(3) VALUE 0.

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
               WHEN LS-CMD-ACTION(1:18) = "LOAN_POST_DISBURSE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POST-DISBURSE
               WHEN LS-CMD-ACTION(1:15) = "LOAN_POST_REPAY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POST-REPAY
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION|0" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_validate_all.cpy".
        COPY "common_sql.cpy".
        COPY "common_trim.cpy".

        COPY "common_idem.cpy".

        ACTION-POST-DISBURSE.
            MOVE "SELECT CONCAT(COALESCE(u.kyc_status, 'UNKNOWN'), '|', CAST(a.principal AS CHAR), '|', a.currency, '|', a.customer_email) FROM loan_application a LEFT JOIN users u ON u.email = a.customer_email WHERE a.id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                IF WS-RESULT = "ERROR|NO_DATA"
                    MOVE "ERROR|NOT_FOUND" TO WS-ERR
                    MOVE "0" TO WS-ERR-CLEAN
                    PERFORM POST-FAIL
                ELSE
                    MOVE "ERROR|DB_ERROR" TO WS-ERR
                    MOVE "0" TO WS-ERR-CLEAN
                    PERFORM POST-FAIL
                END-IF
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-KYC-GUARD WS-LOAN-AMT WS-LOAN-CURR WS-LOAN-EMAIL
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-KYC-GUARD WS-LOAN-AMT WS-LOAN-CURR WS-LOAN-EMAIL
            END-UNSTRING.
            IF FUNCTION NUMVAL(WS-LOAN-AMT) > 1000000 AND WS-KYC-GUARD NOT = "APPROVED"
                MOVE "ERROR|KYC_REQUIRED" TO WS-ERR
                MOVE "0" TO WS-ERR-CLEAN
                PERFORM POST-FAIL
                EXIT PARAGRAPH
            END-IF.
            IF WS-P5-TRIMMED NOT = SPACES
                PERFORM CLAIM-DISBURSE-REQUEST
                IF WS-ERR NOT = SPACES
                    MOVE "0" TO WS-ERR-CLEAN
                    PERFORM POST-FAIL
                    EXIT PARAGRAPH
                END-IF
                IF WS-IDEM-STATUS = "DONE"
                    MOVE "SUCCESS|LOAN_DISBURSE" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            *> Resolve the payout path: customer wallet in the loan currency
            *> plus the bank-owned LOAN_BOOK suspense for that currency.
            *> Either side missing fails closed with an explicit verdict.
            MOVE WS-LOAN-CURR TO WS-BIND-1
            PERFORM LOOKUP-CURRENCY
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                MOVE "0" TO WS-ERR-CLEAN
                PERFORM POST-FAIL
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-CURR-ID
            MOVE "SELECT CAST(a.account_id AS CHAR) FROM accounts a JOIN users u ON u.id = a.user_id WHERE u.email = ? AND a.currency_id = ? AND a.status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-LOAN-EMAIL TO WS-BIND-1
            MOVE WS-CURR-ID TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                PERFORM DELETE-DISBURSE-REQUEST
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
            MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'LOAN_BOOK' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-CURR-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                PERFORM DELETE-DISBURSE-REQUEST
                MOVE "ERROR|LOAN_BOOK_MISSING" TO WS-ERR
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
            MOVE WS-RESULT(1:20) TO WS-BOOK-ACC
            *> Bank-side journal first (gl_core owns its own transaction on
            *> this connection): DEBIT Loans receivable / CREDIT Cash.
            MOVE "SELECT CAST(CURDATE() AS CHAR)" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                MOVE "0" TO WS-ERR-CLEAN
                PERFORM POST-FAIL
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:10) TO WS-POST-DATE
            MOVE SPACES TO WS-GL-DESC WS-GL-LINES
            STRING "LOAN_DISBURSE:" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-LOAN-AMT) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
            STRING "1300:" DELIMITED BY SIZE FUNCTION TRIM(WS-LOAN-AMT) DELIMITED BY SIZE ":0;1000:0:" DELIMITED BY SIZE FUNCTION TRIM(WS-LOAN-AMT) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
            MOVE SPACES TO WS-GL-JID
            MOVE "SELECT id FROM gl_journal WHERE description = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-GL-DESC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
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
                MOVE WS-LOAN-CURR TO WS-CALL-P3
                MOVE WS-GL-LINES TO WS-CALL-P4
                MOVE SPACES TO WS-CALL-P5 WS-CALL-P6
                MOVE WS-P6-TRIMMED TO WS-CALL-P6
                MOVE SPACES TO WS-CALL-OUT
                CALL "gl_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                    WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                END-CALL
                IF WS-CALL-OUT(1:5) = "ERROR"
                    MOVE SPACES TO LS-OUTPUT-BUFFER
                    STRING FUNCTION TRIM(WS-CALL-OUT) DELIMITED BY SIZE "|0" DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                    EXIT PARAGRAPH
                END-IF
                MOVE SPACES TO WS-JOUT-1 WS-JOUT-2 WS-GL-JID
                UNSTRING WS-CALL-OUT DELIMITED BY "|"
                    INTO WS-JOUT-1 WS-JOUT-2 WS-GL-JID
                END-UNSTRING
                IF WS-JOUT-2 NOT = "GL_POSTED_ML" OR WS-GL-JID = SPACES
                    MOVE "ERROR|DB_ERROR" TO WS-ERR
                    MOVE "0" TO WS-ERR-CLEAN
                    PERFORM POST-FAIL
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            MOVE SPACES TO WS-TXN-REF WS-DESC WS-JID
            STRING "LOAN-" DELIMITED BY SIZE WS-P1-TRIMMED DELIMITED BY SPACE INTO WS-TXN-REF END-STRING
            STRING "LOAN_DISBURSE:" DELIMITED BY SIZE WS-P1-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-LOAN-AMT) DELIMITED BY SIZE INTO WS-DESC END-STRING
           MOVE SPACES TO WS-TXN-REF WS-DESC
           STRING "LOAN-" DELIMITED BY SIZE WS-P1-TRIMMED DELIMITED BY SPACE INTO WS-TXN-REF END-STRING
           STRING "LOAN_DISBURSE:" DELIMITED BY SIZE WS-P1-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-LOAN-AMT) DELIMITED BY SIZE INTO WS-DESC END-STRING
           PERFORM POST-OK.
           EXIT PARAGRAPH.

        ACTION-POST-REPAY.
           *> Re-derive the validated amount: the caller-side NUMVAL
           *> does not cross the CALL; NUMVAL on the validated P2 is
           *> deterministic.
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT

            *> Repayments only land on disbursed loans; anything else is a
            *> no-op refused up front instead of a stray PENDING row.
            MOVE "SELECT CONCAT(status, '|', currency, '|', customer_email) FROM loan_application WHERE id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
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
            MOVE SPACES TO WS-TMP-STATUS WS-TMP-CURR WS-LOAN-EMAIL
            UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-STATUS WS-TMP-CURR WS-LOAN-EMAIL
            END-UNSTRING.
            IF WS-TMP-STATUS(1:9) NOT = "DISBURSED"
                PERFORM DELETE-REPAY-REQUEST
                MOVE "ERROR|INVALID_STATUS" TO WS-ERR
                MOVE "1" TO WS-ERR-CLEAN
                PERFORM POST-FAIL
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-NUM-AMOUNT TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-AMT
            IF WS-P5-TRIMMED NOT = SPACES
                PERFORM CLAIM-REPAY-REQUEST
                IF WS-ERR NOT = SPACES
                    MOVE "0" TO WS-ERR-CLEAN
                    PERFORM POST-FAIL
                    EXIT PARAGRAPH
                END-IF
                IF WS-IDEM-STATUS = "DONE"
                    MOVE "SUCCESS|LOAN_REPAY" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            MOVE WS-TMP-CURR TO WS-LOAN-CURR
            MOVE WS-LOAN-CURR TO WS-BIND-1
            PERFORM LOOKUP-CURRENCY
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                MOVE "0" TO WS-ERR-CLEAN
                PERFORM POST-FAIL
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-CURR-ID
            MOVE "SELECT CAST(a.account_id AS CHAR) FROM accounts a JOIN users u ON u.id = a.user_id WHERE u.email = ? AND a.currency_id = ? AND a.status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-LOAN-EMAIL TO WS-BIND-1
            MOVE WS-CURR-ID TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                PERFORM DELETE-REPAY-REQUEST
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
            MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'LOAN_BOOK' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-CURR-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                PERFORM DELETE-REPAY-REQUEST
                MOVE "ERROR|LOAN_BOOK_MISSING" TO WS-ERR
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
            MOVE WS-RESULT(1:20) TO WS-BOOK-ACC
            *> Book the repayment row first (autocommit): its id keys the GL
            *> journal description, so every REPAY call posts exactly one
            *> balanced journal even under concurrency. A row left PENDING by
            *> a later failure means created-but-unposted, as before.
            MOVE "INSERT INTO loan_repayment (loan_id, amount, status) VALUES (?, ?, 'PENDING')" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                MOVE "0" TO WS-ERR-CLEAN
                PERFORM POST-FAIL
                EXIT PARAGRAPH
            END-IF.
            PERFORM LAST-INSERT-ID
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                MOVE "0" TO WS-ERR-CLEAN
                PERFORM POST-FAIL
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-REPAY-ID
            *> Bank-side journal (gl_core owns its own transaction):
            *> DEBIT Cash / CREDIT Loans receivable.
            MOVE "SELECT CAST(CURDATE() AS CHAR)" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                MOVE "0" TO WS-ERR-CLEAN
                PERFORM POST-FAIL
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:10) TO WS-POST-DATE
            MOVE SPACES TO WS-GL-DESC WS-GL-LINES
            STRING "LOAN_REPAY:" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-REPAY-ID) DELIMITED BY SIZE ":" DELIMITED BY SIZE WS-P2-TRIMMED(1:WS-P2-LEN) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
            STRING "1000:" DELIMITED BY SIZE WS-P2-TRIMMED(1:WS-P2-LEN) DELIMITED BY SIZE ":0;1300:0:" DELIMITED BY SIZE WS-P2-TRIMMED(1:WS-P2-LEN) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
            MOVE "GL_JOURNAL_POST_ML" TO WS-CALL-ACTION
            MOVE WS-POST-DATE TO WS-CALL-P1
            MOVE WS-GL-DESC TO WS-CALL-P2
            MOVE WS-LOAN-CURR TO WS-CALL-P3
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
            UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-GL-JID
            END-UNSTRING
            IF WS-JOUT-2 NOT = "GL_POSTED_ML" OR WS-GL-JID = SPACES
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                MOVE "0" TO WS-ERR-CLEAN
                PERFORM POST-FAIL
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-TXN-REF WS-DESC WS-JID
            STRING "LOANRP-" DELIMITED BY SIZE FUNCTION TRIM(WS-REPAY-ID) DELIMITED BY SIZE INTO WS-TXN-REF END-STRING
            STRING "LOAN_REPAY:" DELIMITED BY SIZE WS-P1-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE WS-P2-TRIMMED(1:WS-P2-LEN) DELIMITED BY SIZE INTO WS-DESC END-STRING
           MOVE SPACES TO WS-TXN-REF WS-DESC
           STRING "LOANRP-" DELIMITED BY SIZE FUNCTION TRIM(WS-REPAY-ID) DELIMITED BY SIZE INTO WS-TXN-REF END-STRING
           STRING "LOAN_REPAY:" DELIMITED BY SIZE WS-P1-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE WS-P2-TRIMMED(1:WS-P2-LEN) DELIMITED BY SIZE INTO WS-DESC END-STRING
           PERFORM POST-OK.
           EXIT PARAGRAPH.


        CLAIM-DISBURSE-REQUEST.
           *> Client-supplied idempotency for disburse (P5), migrated to
           *> common_idem.cpy: the legacy row stays the decision-maker while
           *> every transition is mirrored to idempotency_request.
           PERFORM IDEM-RESET
           MOVE "LOAN_DISBURSE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-LOAN-AMT) TO WS-IDEM-AMOUNT
           MOVE SPACES TO WS-IDEM-DETAILS
           MOVE "ERROR|DISBURSE_IN_PROGRESS" TO WS-IDEM-CODE
           PERFORM IDEM-CLAIM.
           EXIT PARAGRAPH.

       DELETE-DISBURSE-REQUEST.
           *> Drops our own PENDING request row on refusal (status guard);
           *> DONE rows are never touched. The mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "LOAN_DISBURSE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       CLAIM-REPAY-REQUEST.
           *> Client-supplied idempotency for repay (P5), migrated to
           *> common_idem.cpy: the legacy row stays the decision-maker while
           *> every transition is mirrored to idempotency_request.
           PERFORM IDEM-RESET
           MOVE "LOAN_REPAY" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
           MOVE SPACES TO WS-IDEM-DETAILS
           MOVE "ERROR|REPAY_IN_PROGRESS" TO WS-IDEM-CODE
           PERFORM IDEM-CLAIM.
           EXIT PARAGRAPH.

       DELETE-REPAY-REQUEST.
           *> Drops our own PENDING request row on refusal (status guard);
           *> DONE rows are never touched. The mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "LOAN_REPAY" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       POST-FAIL.
           *> Shared error writer: WS-ERR carries the full "ERROR|<CODE>"
           *> (verbatim GL output included); WS-ERR-CLEAN carries "1" when
           *> the callee already ran its DELETE-* cleanup first.
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
               WS-LOAN-AMT DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-LOAN-EMAIL DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-CURR-ID DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-CUST-ACC DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-BOOK-ACC DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-GL-JID DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-TXN-REF DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-DESC DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-REPAY-ID DELIMITED BY SIZE
               INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.
