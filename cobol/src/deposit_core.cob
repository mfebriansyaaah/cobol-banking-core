       IDENTIFICATION DIVISION.
       PROGRAM-ID. deposit_core.
      *> Term deposit lifecycle.

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
       01  WS-P7-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P1-LEN               PIC 9(3) VALUE 1.
       01  WS-P2-LEN               PIC 9(3) VALUE 1.
       01  WS-P3-LEN               PIC 9(3) VALUE 1.
       01  WS-P4-LEN               PIC 9(3) VALUE 1.
       01  WS-P5-LEN               PIC 9(3) VALUE 1.
       01  WS-P6-LEN               PIC 9(3) VALUE 1.
       01  WS-P7-LEN               PIC 9(3) VALUE 1.
       01  WS-TRIM-IN              PIC X(100) VALUE SPACES.
       01  WS-TRIM-OUT             PIC X(100) VALUE SPACES.
       01  WS-TRIM-LEN             PIC 9(3) VALUE 1.
       01  WS-I                    PIC 9(3) VALUE 1.
       01  WS-J                    PIC 9(5) VALUE 1.
       01  WS-RLEN                 PIC 9(5) VALUE 1.
       01  WS-BAD                  PIC 9(3) VALUE 0.
       01  WS-ALLOWED              PIC 9 VALUE 0.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-DEPOSIT        PIC X(20) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-TMP-STR              PIC X(100) VALUE SPACES.
       01  WS-TMP-AMT              PIC X(30) VALUE SPACES.
       01  WS-TMP-DAYS             PIC X(10) VALUE SPACES.
       01  WS-TMP-INTR             PIC X(30) VALUE SPACES.
       01  WS-PRINCIPAL-NUM        PIC 9(15)V9(4) VALUE 0.
       01  WS-BAL-NUM              PIC 9(15)V9(4) VALUE 0.
       01  WS-AMT-EDIT             PIC Z(18)9.9999 VALUE 0.
       01  WS-IDEM-EMAIL           PIC X(100) VALUE SPACES.
       01  WS-IDEM-CURR            PIC X(10) VALUE SPACES.
       01  WS-IDEM-TRM             PIC X(10) VALUE SPACES.
       01  WS-IDEM-RT              PIC X(20) VALUE SPACES.
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
       01  WS-ADOPTED              PIC X VALUE "0".
       01  WS-IDEM-STATUS          PIC X(10) VALUE SPACES.
       01  WS-IDEM-OWNED           PIC X VALUE "0".
       01  WS-IDEM-ROW             PIC X(200) VALUE SPACES.
       01  WS-IDEM-AMT             PIC X(30) VALUE SPACES.
       01  WS-IDEM-JID             PIC X(20) VALUE SPACES.
       01  WS-IDEM-STALE           PIC X VALUE SPACES.
       01  WS-CLOSE-JID            PIC X(20) VALUE SPACES.
       01  WS-RATE-NUM             PIC 9(5)V9(4) VALUE 0.
       01  WS-TERM-NUM             PIC 9(5) VALUE 0.
       01  WS-DAYS-NUM             PIC 9(5) VALUE 0.
       01  WS-INTEREST-NUM         PIC 9(15)V9(4) VALUE 0.
       01  WS-TOTAL-NUM            PIC 9(15)V9(4) VALUE 0.
       01  WS-ID-TEXT              PIC X(20) VALUE SPACES.
       01  WS-ACCRUED-TEXT         PIC X(30) VALUE SPACES.
       01  WS-POSTED-TEXT          PIC X(30) VALUE SPACES.
       01  WS-AFFECTED             PIC X(20) VALUE SPACES.
       01  WS-STATUS-TEXT          PIC X(20) VALUE SPACES.
       01  WS-COUNT-NUM            PIC 9(9) VALUE 0.
       01  WS-CALL-ACTION          PIC X(30) VALUE SPACES.
       01  WS-CALL-P1              PIC X(100) VALUE SPACES.
       01  WS-CALL-P2              PIC X(100) VALUE SPACES.
       01  WS-CALL-P3              PIC X(100) VALUE SPACES.
       01  WS-CALL-P4              PIC X(100) VALUE SPACES.
       01  WS-CALL-P5              PIC X(100) VALUE SPACES.
       01  WS-CALL-P6              PIC X(100) VALUE SPACES.
       01  WS-CALL-OUT             PIC X(16384) VALUE SPACES.
       01  WS-POST-DATE            PIC X(10) VALUE SPACES.
       01  WS-POST-CODE            PIC X(40) VALUE SPACES.
       01  WS-POST-CLEANUP         PIC X VALUE SPACE.
       01  WS-GL-DESC              PIC X(100) VALUE SPACES.
       01  WS-GL-LINES             PIC X(100) VALUE SPACES.
       01  WS-GL-JID               PIC X(20) VALUE SPACES.
       01  WS-JOUT-1               PIC X(20) VALUE SPACES.
       01  WS-JOUT-2               PIC X(20) VALUE SPACES.
       01  WS-CUST-EMAIL           PIC X(100) VALUE SPACES.
       01  WS-CUST-CURR            PIC X(10) VALUE SPACES.
       01  WS-CUST-ACC             PIC X(20) VALUE SPACES.
       01  WS-CURR-ID              PIC X(20) VALUE SPACES.
       01  WS-POOL-ACC             PIC X(20) VALUE SPACES.
       01  WS-JID                  PIC X(20) VALUE SPACES.
       01  WS-TXN-REF              PIC X(50) VALUE SPACES.
       01  WS-DESC                 PIC X(255) VALUE SPACES.
       01  F-QUOTE                 PIC X VALUE "'".
       01  F-DQUOTE                PIC X VALUE '"'.
       01  F-BSLASH                PIC X VALUE "\".
       01  F-SEMI                  PIC X VALUE ";".
       01  F-TICK                  PIC X VALUE "`".

       LINKAGE SECTION.
       01  LS-CMD-ACTION           PIC X(30).
       01  LS-PARAM1               PIC X(100).
       01  LS-PARAM2               PIC X(100).
       01  LS-PARAM3               PIC X(100).
       01  LS-PARAM4               PIC X(100).
       01  LS-PARAM5               PIC X(100).
       01  LS-PARAM6               PIC X(100).
       01  LS-PARAM7               PIC X(100).
       01  LS-OUTPUT-BUFFER        PIC X(16384).

       PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2
           LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-PARAM7
           LS-OUTPUT-BUFFER.

       MAIN-LOGIC.
           PERFORM VALIDATE-ALL
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               GOBACK
           END-IF
           EVALUATE TRUE
               WHEN LS-CMD-ACTION(1:8) = "DEP_OPEN"
                   PERFORM TRIM-ALL
                   MOVE LS-PARAM7 TO WS-TRIM-IN
                   PERFORM TRIM-VALUE
                   MOVE WS-TRIM-OUT TO WS-P7-TRIMMED
                   MOVE WS-TRIM-LEN TO WS-P7-LEN
                   PERFORM ACTION-OPEN
               WHEN LS-CMD-ACTION(1:8) = "DEP_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-LIST
               WHEN LS-CMD-ACTION(1:7) = "DEP_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-GET
               WHEN LS-CMD-ACTION(1:10) = "DEP_MATURE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-MATURE
               WHEN LS-CMD-ACTION(1:9) = "DEP_CLOSE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CLOSE
               WHEN LS-CMD-ACTION(1:11) = "DEP_SUMMARY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SUMMARY
               WHEN LS-CMD-ACTION(1:10) = "DEP_ACCRUE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ACCRUE
               WHEN LS-CMD-ACTION(1:8) = "DEP_POST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POST-INTEREST
               WHEN LS-CMD-ACTION(1:10) = "DEP_SETTLE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SETTLE
               WHEN LS-CMD-ACTION(1:13) = "DEP_STATEMENT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-STATEMENT
               WHEN LS-CMD-ACTION(1:9) = "DEP_AUDIT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-AUDIT
               WHEN LS-CMD-ACTION(1:8) = "DEP_CALC"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CALC
               WHEN LS-CMD-ACTION(1:12) = "DEP_VALIDATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALIDATE
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_validate_all.cpy".
        COPY "common_sql.cpy".


        COPY "common_trim.cpy".


        COPY "common_auth.cpy".

       AUDIT.
           MOVE "INSERT INTO deposit_audit (action, actor_email, deposit_id, detail) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-DEPOSIT TO WS-BIND-3
           MOVE WS-AUDIT-DETAIL TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

       AUDIT-DENIED.
           MOVE "AUTHZ_DENIED" TO WS-AUDIT-ACTION
           MOVE SPACES TO WS-AUDIT-DEPOSIT
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT.
           EXIT PARAGRAPH.

        COPY "common_result.cpy".

        COPY "common_idem.cpy".

       CLAIM-OPEN-REQUEST.
           *> Client-supplied idempotency for open (P7, global keyspace:
           *> OPEN mints its own deposit id, so the key stands alone).
           *> First call inserts a PENDING request row carrying the full
           *> business tuple and owns it; a repeated key replays the stored
           *> DONE deposit id, or conflicts when any tuple field differs.
           *> Migrated to common_idem.cpy (DETAILS mode): the legacy row
           *> stays the decision-maker while every transition is mirrored.
           MOVE WS-PRINCIPAL-NUM TO WS-AMT-EDIT
           MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-AMT
           PERFORM IDEM-RESET
           MOVE "DEP_OPEN" TO WS-IDEM-SCOPE
           MOVE WS-P7-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
           MOVE WS-P1-TRIMMED TO WS-IDEM-V1
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-V2
           MOVE WS-P3-TRIMMED TO WS-IDEM-V3
           MOVE WS-P4-TRIMMED TO WS-IDEM-V4
           MOVE WS-P5-TRIMMED TO WS-IDEM-V5
           MOVE "customer_email, principal, currency, term_months, interest_rate" TO WS-IDEM-DETAIL-COLS
           MOVE "deposit_id" TO WS-IDEM-IDCOL
           MOVE "ERROR|OPEN_IN_PROGRESS" TO WS-IDEM-CODE
           MOVE SPACES TO WS-IDEM-JID
           PERFORM IDEM-CLAIM
           IF WS-ERR = SPACES
               MOVE WS-IDEM-REFID TO WS-IDEM-JID
           END-IF.
           EXIT PARAGRAPH.

       DELETE-OPEN-REQUEST.
           *> Drops our own PENDING request row when the open is refused
           *> before posting, so the key stays usable instead of blocking
           *> behind a 5-minute stale window. Only the owner row is ever
           *> removed (status guard); DONE rows are never touched. The
           *> unified mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "DEP_OPEN" TO WS-IDEM-SCOPE
           MOVE WS-P7-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       ACTION-OPEN.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-PRINCIPAL-NUM
           MOVE FUNCTION NUMVAL(WS-P4-TRIMMED) TO WS-TERM-NUM
           IF WS-PRINCIPAL-NUM <= 0
               MOVE "ERROR|INVALID_PRINCIPAL" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           IF WS-TERM-NUM < 1 OR WS-TERM-NUM > 360
               MOVE "ERROR|INVALID_TERM" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE "SELECT iso_code FROM currencies WHERE iso_code = ? AND is_active = 1 LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|INVALID_CURRENCY" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P7-TRIMMED NOT = SPACES
               PERFORM CLAIM-OPEN-REQUEST
               IF WS-ERR NOT = SPACES
                   MOVE WS-ERR TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "DONE"
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING "SUCCESS|DEP_OPEN|" DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-JID) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           *> Fase 2: opening funds the deposit. Resolve the money path
           *> before writing anything: deposit currency, customer wallet,
           *> and bank-owned DEPOSIT_POOL suspense. A missing wallet or
           *> pool, or a short wallet, fails closed with no row written.
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           PERFORM LOOKUP-CURRENCY
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-CURR-ID
           MOVE "SELECT CAST(a.account_id AS CHAR) FROM accounts a JOIN users u ON u.id = a.user_id WHERE u.email = ? AND a.currency_id = ? AND a.status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-CURR-ID TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               PERFORM DELETE-OPEN-REQUEST
               MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
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
               PERFORM DELETE-OPEN-REQUEST
               MOVE "ERROR|DEPOSIT_POOL_MISSING" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-POOL-ACC
           MOVE "SELECT CAST(balance AS CHAR) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
           MOVE WS-CUST-ACC TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-RESULT) TO WS-BAL-NUM
           IF WS-BAL-NUM < WS-PRINCIPAL-NUM
               PERFORM DELETE-OPEN-REQUEST
               MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "0" TO WS-ADOPTED
           IF WS-P7-TRIMMED NOT = SPACES AND WS-IDEM-JID NOT = SPACES
               MOVE WS-IDEM-JID TO WS-ID-TEXT
               MOVE "1" TO WS-ADOPTED
           END-IF.
           IF WS-ADOPTED = "0"
           MOVE "INSERT INTO deposit_account (customer_email, principal, currency, term_months, interest_rate, created_by, status) VALUES (?, ?, ?, ?, COALESCE(NULLIF(?, ''), 0), ?, 'PENDING')" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-P5-TRIMMED TO WS-BIND-5
           MOVE WS-P6-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-ID-TEXT
               END-IF
           END-IF
           END-IF.
           IF STEP-OK AND WS-P7-TRIMMED NOT = SPACES AND WS-IDEM-JID = SPACES
               PERFORM IDEM-RESET
               MOVE "DEP_OPEN" TO WS-IDEM-SCOPE
               MOVE WS-P7-TRIMMED TO WS-IDEM-KEY
               MOVE "deposit_id" TO WS-IDEM-IDCOL
               MOVE WS-ID-TEXT TO WS-IDEM-LINKVAL
               PERFORM IDEM-LINK
           END-IF.
           IF STEP-OK
               MOVE "UPDATE deposit_account SET maturity_date = DATE_ADD(CURDATE(), INTERVAL term_months MONTH) WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-ID-TEXT TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK AND WS-ADOPTED = "0"
               MOVE "OPEN" TO WS-AUDIT-ACTION
               MOVE WS-ID-TEXT TO WS-AUDIT-DEPOSIT
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Bank-side journal for the funding (gl_core owns its own
           *> transaction on this connection): DEBIT Cash / CREDIT Deposits
           *> payable. The deposit id is fresh, so the description is new.
           MOVE "SELECT CAST(CURDATE() AS CHAR)" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:10) TO WS-POST-DATE
           MOVE SPACES TO WS-GL-DESC WS-GL-LINES WS-GL-JID
           STRING "DEP_OPEN:" DELIMITED BY SIZE FUNCTION TRIM(WS-ID-TEXT) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
           STRING "1000:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE ":0;2120:0:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
           MOVE "GL_JOURNAL_POST_ML" TO WS-CALL-ACTION
           MOVE WS-POST-DATE TO WS-CALL-P1
           MOVE WS-GL-DESC TO WS-CALL-P2
           MOVE WS-P3-TRIMMED TO WS-CALL-P3
           MOVE WS-GL-LINES TO WS-CALL-P4
           MOVE SPACES TO WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           MOVE WS-P6-TRIMMED TO WS-CALL-P6
           CALL "gl_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
               WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           END-CALL
           IF WS-CALL-OUT(1:5) = "ERROR"
               MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-JOUT-1 WS-JOUT-2 WS-GL-JID
           UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-GL-JID END-UNSTRING
           IF WS-JOUT-2 NOT = "GL_POSTED_ML" OR WS-GL-JID = SPACES
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Funding legs: customer wallet DEBIT / DEPOSIT_POOL CREDIT, in
           *> one transaction. The guarded debit is the race-safe gate: a
           *> concurrent spend leaves the deposit PENDING with no money
           *> moved (the early balance check above covers the common case
           *> before any row is written).
           MOVE SPACES TO WS-TXN-REF WS-DESC WS-JID WS-ERR
           STRING "DEP-" DELIMITED BY SIZE FUNCTION TRIM(WS-ID-TEXT) DELIMITED BY SIZE "-FUND" DELIMITED BY SIZE INTO WS-TXN-REF END-STRING
           STRING "DEP_OPEN:" DELIMITED BY SIZE FUNCTION TRIM(WS-ID-TEXT) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-DESC END-STRING
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           IF STEP-OK
           MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'TRANSFER', ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           PERFORM LAST-INSERT-ID
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           ELSE
           MOVE WS-RESULT(1:20) TO WS-JID
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ? AND balance >= ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-1
           MOVE WS-CUST-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
           MOVE "ERROR|INSUFFICIENT_FUNDS" TO WS-ERR
           SET STEP-FAIL TO TRUE
           ELSE
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-1
           MOVE WS-POOL-ACC TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-CUST-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-3
           MOVE WS-CURR-ID TO WS-BIND-4
           MOVE WS-DESC TO WS-BIND-5
           MOVE WS-P1-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-POOL-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-3
           MOVE WS-CURR-ID TO WS-BIND-4
           MOVE WS-DESC TO WS-BIND-5
           MOVE WS-P1-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO deposit_transaction (deposit_id, txn_type, amount, currency, reference) SELECT id, 'PRINCIPAL_FUNDED', ?, currency, CONCAT('FUND-', id, '-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s')) FROM deposit_account WHERE id = ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-1
           MOVE WS-ID-TEXT TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE deposit_account SET status = 'ACTIVE', fund_journal_id = ?, fund_gl_journal_id = ? WHERE id = ? AND status = 'PENDING'" TO WS-PREP-SQL
           MOVE WS-JID TO WS-BIND-1
           MOVE WS-GL-JID TO WS-BIND-2
           MOVE WS-ID-TEXT TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK AND WS-P7-TRIMMED NOT = SPACES
               PERFORM IDEM-RESET
               MOVE "DEP_OPEN" TO WS-IDEM-SCOPE
               MOVE WS-P7-TRIMMED TO WS-IDEM-KEY
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
               MOVE "fund_gl_journal_id" TO WS-IDEM-SETCOL
               MOVE WS-GL-JID TO WS-IDEM-JIDVAL
               MOVE "1" TO WS-IDEM-GUARD
               PERFORM IDEM-COMPLETE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|DEP_OPEN|" DELIMITED BY SIZE WS-ID-TEXT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INSUFFICIENT_FUNDS"
                   MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LIST.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CONCAT(id, ':', customer_email, ':', principal, ':', currency, ':', term_months, ':', status, ':', accrued_interest) FROM deposit_account WHERE (? = '' OR status = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           MOVE WS-OFFSET TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|DEPOSITS|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|DEPOSITS|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-GET.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(id, '|', customer_email, '|', principal, '|', currency, '|', term_months, '|', interest_rate, '|', status, '|', COALESCE(maturity_date, ''), '|', accrued_interest, '|', posted_interest, '|', COALESCE(last_accrual_date, '')) FROM deposit_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           PERFORM TRIM-RESULT-LEN
           STRING "SUCCESS|DEPOSIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-MATURE.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE deposit_account SET status = 'MATURED' WHERE status = 'ACTIVE' AND maturity_date IS NOT NULL AND maturity_date <= CURDATE()" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|DEP_MATURED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       CLAIM-CLOSE-REQUEST.
           *> Client-supplied idempotency for close (P5), migrated to
           *> common_idem.cpy: the legacy row stays the decision-maker while
           *> every transition is mirrored to idempotency_request.
           PERFORM IDEM-RESET
           MOVE "DEP_CLOSE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
           MOVE SPACES TO WS-IDEM-DETAILS
           MOVE "ERROR|CLOSE_IN_PROGRESS" TO WS-IDEM-CODE
           PERFORM IDEM-CLAIM.
           EXIT PARAGRAPH.

       DELETE-CLOSE-REQUEST.
           *> Drops our own PENDING request row on refusal (status guard);
           *> DONE rows are never touched. The mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "DEP_CLOSE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       ACTION-CLOSE.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(CAST(principal AS CHAR), '|', status, '|', customer_email, '|', currency, '|', COALESCE(CAST(journal_id AS CHAR), '')) FROM deposit_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-TMP-AMT
           MOVE SPACES TO WS-STATUS-TEXT WS-CUST-EMAIL WS-CUST-CURR WS-CLOSE-JID
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-AMT WS-STATUS-TEXT WS-CUST-EMAIL WS-CUST-CURR WS-CLOSE-JID END-UNSTRING
           *> The refund is the principal when funded, zero otherwise; the
           *> idempotency key (if any) is claimed on that amount.
           IF WS-STATUS-TEXT(1:7) = "PENDING"
               MOVE "0.0000" TO WS-TMP-AMT
           ELSE
               IF WS-STATUS-TEXT(1:6) = "CLOSED"
                   AND WS-CLOSE-JID = SPACES
                   MOVE "0.0000" TO WS-TMP-AMT
               END-IF
           END-IF.
           IF WS-P5-TRIMMED NOT = SPACES
               PERFORM CLAIM-CLOSE-REQUEST
               IF WS-ERR NOT = SPACES
                   MOVE WS-ERR TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "DONE"
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING "SUCCESS|DEP_CLOSED|" DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-AMT) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           *> Unfunded (PENDING) deposits close money-neutral: the funding
           *> transaction never ran, so there is nothing to refund. PENDING
           *> is the only pre-funding state, so reaching here means unfunded.
           IF WS-STATUS-TEXT(1:7) = "PENDING"
               MOVE "UPDATE deposit_account SET status = 'CLOSED' WHERE id = ? AND status = 'PENDING'" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT = "SUCCESS|AFFECTED_1"
                   IF WS-P5-TRIMMED NOT = SPACES
                       PERFORM IDEM-RESET
                       MOVE "DEP_CLOSE" TO WS-IDEM-SCOPE
                       MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
                       MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
                       MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
                       MOVE SPACES TO WS-IDEM-DETAILS
                       MOVE "1" TO WS-IDEM-DIRECT
                       PERFORM IDEM-COMPLETE
                       IF WS-ERR NOT = SPACES
                           MOVE WS-ERR TO LS-OUTPUT-BUFFER
                           EXIT PARAGRAPH
                       END-IF
                   END-IF
                   MOVE "SUCCESS|DEP_CLOSED|0.0000" TO LS-OUTPUT-BUFFER
               ELSE
                   IF WS-RESULT = "SUCCESS|AFFECTED_0"
                       MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                   ELSE
                       MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   END-IF
               END-IF
               EXIT PARAGRAPH
           END-IF.
           IF WS-STATUS-TEXT(1:6) NOT = "ACTIVE"
               AND WS-STATUS-TEXT(1:7) NOT = "MATURED"
               PERFORM DELETE-CLOSE-REQUEST
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Resolve the refund path: customer wallet in the deposit
           *> currency plus the bank-owned DEPOSIT_POOL suspense. An
           *> underfunded pool fails closed instead of printing money.
           MOVE WS-CUST-CURR TO WS-BIND-1
           PERFORM LOOKUP-CURRENCY
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
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
               PERFORM DELETE-CLOSE-REQUEST
               MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
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
               PERFORM DELETE-CLOSE-REQUEST
               MOVE "ERROR|DEPOSIT_POOL_MISSING" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-POOL-ACC
           *> Bank-side journal for the refund (gl_core owns its own
           *> transaction on this connection): DEBIT Deposits payable /
           *> CREDIT Cash. Posted interest is forfeited: only the principal
           *> comes back, so the pool round-trips exactly.
           MOVE "SELECT CAST(CURDATE() AS CHAR)" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:10) TO WS-POST-DATE
           MOVE SPACES TO WS-GL-DESC WS-GL-LINES WS-GL-JID
           STRING "DEP_CLOSE:" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
           STRING "2120:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE ":0;1000:0:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
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
               MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-JOUT-1 WS-JOUT-2 WS-GL-JID
           UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-GL-JID END-UNSTRING
           IF WS-JOUT-2 NOT = "GL_POSTED_ML" OR WS-GL-JID = SPACES
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-TXN-REF WS-DESC WS-JID WS-ERR
           STRING "DEP-" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE "-REFUND" DELIMITED BY SIZE INTO WS-TXN-REF END-STRING
           STRING "DEP_CLOSE:" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-DESC END-STRING
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           IF STEP-OK
           MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'TRANSFER', ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-CUST-EMAIL TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           PERFORM LAST-INSERT-ID
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           ELSE
           MOVE WS-RESULT(1:20) TO WS-JID
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ? AND balance >= ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-1
           MOVE WS-POOL-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
           MOVE "ERROR|INSUFFICIENT_FUNDS" TO WS-ERR
           SET STEP-FAIL TO TRUE
           ELSE
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-1
           MOVE WS-CUST-ACC TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-POOL-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-3
           MOVE WS-CURR-ID TO WS-BIND-4
           MOVE WS-DESC TO WS-BIND-5
           MOVE WS-CUST-EMAIL TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-CUST-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-3
           MOVE WS-CURR-ID TO WS-BIND-4
           MOVE WS-DESC TO WS-BIND-5
           MOVE WS-CUST-EMAIL TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO deposit_transaction (deposit_id, txn_type, amount, currency, reference) SELECT id, 'PRINCIPAL_REFUNDED', ?, currency, CONCAT('REFUND-', id, '-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s')) FROM deposit_account WHERE id = ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE deposit_account SET status = 'CLOSED', accrued_interest = 0, journal_id = ?, gl_journal_id = ? WHERE id = ? AND status IN ('ACTIVE','MATURED')" TO WS-PREP-SQL
           MOVE WS-JID TO WS-BIND-1
           MOVE WS-GL-JID TO WS-BIND-2
           MOVE WS-P1-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
               MOVE "CLOSE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-DEPOSIT
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK AND WS-P5-TRIMMED NOT = SPACES
               PERFORM IDEM-RESET
               MOVE "DEP_CLOSE" TO WS-IDEM-SCOPE
               MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
               MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
               MOVE SPACES TO WS-IDEM-DETAILS
               MOVE "gl_journal_id" TO WS-IDEM-SETCOL
               MOVE WS-GL-JID TO WS-IDEM-JIDVAL
               PERFORM IDEM-COMPLETE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|DEP_CLOSED|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   IF WS-ERR = "ERROR|INSUFFICIENT_FUNDS"
                       MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                   ELSE
                       MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   END-IF
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-SUMMARY.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'ACTIVE'), 0), '|', COALESCE(SUM(status = 'MATURED'), 0), '|', COALESCE(SUM(principal), 0), '|', COALESCE(SUM(accrued_interest), 0), '|', COALESCE(SUM(posted_interest), 0)) FROM deposit_account" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|DEP_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:200) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

      *> Accrue interest for one deposit. Interest is computed by the
      *> database (principal * rate * days / 36500) so the core never binds a
      *> float; the accrual is upserted per (deposit, day).
       ACTION-ACCRUE.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Posting resolve lives in deposit_posting_core (maint-06):
           *> the callee returns SUCCESS|POST_READY + nine fields, or
           *> ERROR|<CODE>|<CLEANUP>. CLEANUP=1 runs the DELETE-* below.
           MOVE "DEP_POST_ACCRUE" TO WS-CALL-ACTION
           MOVE WS-P1-TRIMMED TO WS-CALL-P1
           MOVE WS-P2-TRIMMED TO WS-CALL-P2
           MOVE SPACES TO WS-CALL-P3 WS-CALL-P4
           MOVE SPACES TO WS-CALL-P5
           MOVE WS-P6-TRIMMED TO WS-CALL-P6
           MOVE SPACES TO WS-CALL-OUT
           CALL "deposit_posting_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
               WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           END-CALL
           IF WS-CALL-OUT(1:5) = "ERROR"
               UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-POST-CODE WS-POST-CLEANUP END-UNSTRING
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "ERROR|" DELIMITED BY SIZE FUNCTION TRIM(WS-POST-CODE) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-JOUT-1 WS-JOUT-2
           UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-TMP-AMT WS-CUST-EMAIL WS-CURR-ID WS-CUST-ACC WS-POOL-ACC WS-GL-JID WS-TXN-REF WS-DESC WS-TMP-DAYS END-UNSTRING
           IF WS-JOUT-1 NOT = "SUCCESS" OR WS-JOUT-2 NOT = "POST_READY"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO deposit_accrual (deposit_id, accrual_date, days, principal, rate, interest, status) SELECT id, CURDATE(), ?, principal, interest_rate, ROUND(principal * interest_rate * ? / 36500, 4), 'ACCRUED' FROM deposit_account WHERE id = ? ON DUPLICATE KEY UPDATE days = VALUES(days), interest = VALUES(interest), status = 'ACCRUED'" TO WS-PREP-SQL
           MOVE WS-TMP-DAYS TO WS-BIND-1
           MOVE WS-TMP-DAYS TO WS-BIND-2
           MOVE WS-P1-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE deposit_account SET accrued_interest = (SELECT COALESCE(SUM(interest), 0) FROM deposit_accrual WHERE deposit_id = ? AND status = 'ACCRUED'), last_accrual_date = CURDATE() WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               MOVE WS-P1-TRIMMED TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "SELECT CAST(interest AS CHAR) FROM deposit_accrual WHERE deposit_id = ? AND accrual_date = CURDATE() LIMIT 1" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:30) TO WS-TMP-INTR
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "ACCRUE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-DEPOSIT
               MOVE WS-TMP-INTR TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|DEP_ACCRUE|" DELIMITED BY SIZE WS-TMP-INTR DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

      *> Post every accrual that is still ACCRUED: the amount is recorded as a
      *> deposit transaction and rolled into posted_interest.
       ACTION-POST-INTEREST.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Posting resolve lives in deposit_posting_core (maint-06):
           *> the callee returns SUCCESS|POST_READY + nine fields, or
           *> ERROR|<CODE>|<CLEANUP>. CLEANUP=1 runs the DELETE-* below.
           MOVE "DEP_POST_INTEREST" TO WS-CALL-ACTION
           MOVE WS-P1-TRIMMED TO WS-CALL-P1
           MOVE SPACES TO WS-CALL-P2
           MOVE SPACES TO WS-CALL-P3 WS-CALL-P4
           MOVE SPACES TO WS-CALL-P5
           MOVE WS-P6-TRIMMED TO WS-CALL-P6
           MOVE SPACES TO WS-CALL-OUT
           CALL "deposit_posting_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
               WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           END-CALL
           IF WS-CALL-OUT(1:5) = "ERROR"
               UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-POST-CODE WS-POST-CLEANUP END-UNSTRING
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "ERROR|" DELIMITED BY SIZE FUNCTION TRIM(WS-POST-CODE) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-JOUT-1 WS-JOUT-2
           UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-TMP-AMT WS-CUST-EMAIL WS-CURR-ID WS-CUST-ACC WS-POOL-ACC WS-GL-JID WS-TXN-REF WS-DESC WS-TMP-DAYS END-UNSTRING
           IF WS-JOUT-1 NOT = "SUCCESS" OR WS-JOUT-2 NOT = "POST_READY"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO deposit_transaction (deposit_id, txn_type, amount, currency, reference) SELECT id, 'INTEREST_POSTED', ?, currency, CONCAT('INT-', id, '-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s')) FROM deposit_account WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-TMP-AMT TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE deposit_accrual SET status = 'POSTED' WHERE deposit_id = ? AND status = 'ACCRUED'" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE deposit_account SET posted_interest = posted_interest + ?, accrued_interest = GREATEST(accrued_interest - ?, 0) WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-TMP-AMT TO WS-BIND-1
               MOVE WS-TMP-AMT TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE deposit_account SET post_gl_journal_id = ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-GL-JID TO WS-BIND-1
               MOVE WS-P1-TRIMMED TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "POST_INTEREST" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-DEPOSIT
               MOVE WS-TMP-AMT TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|DEP_POST|" DELIMITED BY SIZE WS-TMP-AMT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

      *> Settle a matured (or still active) deposit: principal + posted
      *> interest is paid out and the deposit closes.
       ACTION-SETTLE.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Posting resolve lives in deposit_posting_core (maint-06):
           *> the callee returns SUCCESS|POST_READY + nine fields, or
           *> ERROR|<CODE>|<CLEANUP>. CLEANUP=1 runs the DELETE-* below.
           MOVE "DEP_POST_SETTLE" TO WS-CALL-ACTION
           MOVE WS-P1-TRIMMED TO WS-CALL-P1
           MOVE SPACES TO WS-CALL-P2
           MOVE SPACES TO WS-CALL-P3 WS-CALL-P4
           MOVE WS-P5-TRIMMED TO WS-CALL-P5
           MOVE WS-P6-TRIMMED TO WS-CALL-P6
           MOVE SPACES TO WS-CALL-OUT
           CALL "deposit_posting_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
               WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           END-CALL
           *> CLEANUP=1 paths self-cleaned inside the callee, which
           *> owns DELETE-SETTLE-REQUEST; the flag is parsed but needs
           *> no caller action.
           IF WS-CALL-OUT(1:5) = "ERROR"
               UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-POST-CODE WS-POST-CLEANUP END-UNSTRING
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "ERROR|" DELIMITED BY SIZE FUNCTION TRIM(WS-POST-CODE) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
               EXIT PARAGRAPH
           END-IF
           IF WS-CALL-OUT(1:19) = "SUCCESS|DEP_SETTLE|"
               MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-JOUT-1 WS-JOUT-2
           UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-TMP-AMT WS-CUST-EMAIL WS-CURR-ID WS-CUST-ACC WS-POOL-ACC WS-GL-JID WS-TXN-REF WS-DESC WS-TMP-DAYS END-UNSTRING
           IF WS-JOUT-1 NOT = "SUCCESS" OR WS-JOUT-2 NOT = "POST_READY"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-JID
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           IF STEP-OK
           MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'TRANSFER', ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-CUST-EMAIL TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           PERFORM LAST-INSERT-ID
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           ELSE
           MOVE WS-RESULT(1:20) TO WS-JID
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-1
           MOVE WS-CUST-ACC TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ? AND balance >= ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-1
           MOVE WS-POOL-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
           MOVE "ERROR|INSUFFICIENT_FUNDS" TO WS-ERR
           SET STEP-FAIL TO TRUE
           ELSE
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-POOL-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-3
           MOVE WS-CURR-ID TO WS-BIND-4
           MOVE WS-DESC TO WS-BIND-5
           MOVE WS-CUST-EMAIL TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-CUST-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-3
           MOVE WS-CURR-ID TO WS-BIND-4
           MOVE WS-DESC TO WS-BIND-5
           MOVE WS-CUST-EMAIL TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE deposit_account SET status = 'CLOSED', accrued_interest = 0, journal_id = ?, gl_journal_id = ? WHERE id = ? AND status IN ('ACTIVE','MATURED')" TO WS-PREP-SQL
           MOVE WS-JID TO WS-BIND-1
           MOVE WS-GL-JID TO WS-BIND-2
           MOVE WS-P1-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
           MOVE "ERROR|INVALID_STATUS" TO WS-ERR
           SET STEP-FAIL TO TRUE
           ELSE
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO deposit_transaction (deposit_id, txn_type, amount, currency, reference) SELECT id, 'PRINCIPAL_PAYOUT', ?, currency, CONCAT('SETTLE-', id, '-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s')) FROM deposit_account WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-TMP-AMT TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE deposit_account SET status = 'CLOSED', accrued_interest = 0 WHERE id = ? AND status IN ('ACTIVE','MATURED')" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "SETTLE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-DEPOSIT
               MOVE WS-TMP-AMT TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK AND WS-P5-TRIMMED NOT = SPACES
               PERFORM IDEM-RESET
               MOVE "DEP_SETTLE" TO WS-IDEM-SCOPE
               MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
               MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
               MOVE SPACES TO WS-IDEM-DETAILS
               MOVE "gl_journal_id" TO WS-IDEM-SETCOL
               MOVE WS-GL-JID TO WS-IDEM-JIDVAL
               PERFORM IDEM-COMPLETE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|DEP_SETTLE|" DELIMITED BY SIZE WS-TMP-AMT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   IF WS-ERR = "ERROR|INSUFFICIENT_FUNDS"
                       MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                   ELSE
                       MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   END-IF
               END-IF
           END-IF.
           EXIT PARAGRAPH.

      *> Full movement history for a deposit: accrual rows (A:) and
      *> transaction rows (T:), oldest first, bounded at 200 rows.
       ACTION-STATEMENT.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT('A:', accrual_date, ':', days, ':', interest, ':', status) FROM deposit_accrual WHERE deposit_id = ? UNION ALL SELECT CONCAT('T:', txn_type, ':', amount, ':', currency, ':', reference) FROM deposit_transaction WHERE deposit_id = ? ORDER BY 1 LIMIT 200" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|DEP_STATEMENT|" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|DEP_STATEMENT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

      *> Deposit audit trail, optionally filtered by deposit id and paged.
       ACTION-AUDIT.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF WS-P2-TRIMMED NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF WS-P3-TRIMMED NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CONCAT(action, ':', actor_email, ':', COALESCE(detail, ''), ':', created_at) FROM deposit_audit WHERE (? = '' OR deposit_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           MOVE WS-OFFSET TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|DEP_AUDIT|" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|DEP_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

      *> Interest preview: principal * rate * days / 36500, plus the payout
      *> total. Read-only and DB-backed so the caller gets exact decimals.
       ACTION-CALC.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-P1-TRIMMED) TO WS-PRINCIPAL-NUM
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-RATE-NUM
           MOVE FUNCTION NUMVAL(WS-P3-TRIMMED) TO WS-DAYS-NUM
           IF WS-PRINCIPAL-NUM <= 0 OR WS-RATE-NUM <= 0 OR WS-DAYS-NUM <= 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-DAYS-NUM TO WS-TMP-DAYS
           MOVE "SELECT CAST(ROUND(p * r * d / 36500, 4) AS CHAR), CAST(p + ROUND(p * r * d / 36500, 4) AS CHAR) FROM (SELECT CAST(? AS DECIMAL(18,4)) p, CAST(? AS DECIMAL(9,4)) r, CAST(? AS DECIMAL(5,0)) d) x" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-TMP-DAYS TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|DEP_CALC|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

      *> Pre-flight validation for DEP_OPEN: checks the currency is active,
      *> the term is in range and returns a maturity/interest preview.
       ACTION-VALIDATE.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-P1-TRIMMED) TO WS-PRINCIPAL-NUM
           MOVE FUNCTION NUMVAL(WS-P3-TRIMMED) TO WS-TERM-NUM
           IF WS-PRINCIPAL-NUM <= 0
               MOVE "ERROR|INVALID_PRINCIPAL" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           IF WS-TERM-NUM < 1 OR WS-TERM-NUM > 360
               MOVE "ERROR|INVALID_TERM" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "0" TO WS-TMP-INTR
           IF WS-P4-TRIMMED NOT = SPACES
               MOVE WS-P4-TRIMMED(1:30) TO WS-TMP-INTR
           END-IF.
           MOVE WS-TERM-NUM TO WS-TMP-DAYS
           MOVE "SELECT CONCAT(CAST(ROUND(CAST(? AS DECIMAL(18,4)) * CAST(? AS DECIMAL(9,4)) * CAST(? AS DECIMAL(5,0)) * 30 / 36500, 4) AS CHAR), '|', CAST(DATE_ADD(CURDATE(), INTERVAL ? MONTH) AS CHAR)) FROM currencies WHERE iso_code = ? AND is_active = 1 LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-TMP-INTR TO WS-BIND-2
           MOVE WS-TMP-DAYS TO WS-BIND-3
           MOVE WS-TMP-DAYS TO WS-BIND-4
           MOVE WS-P2-TRIMMED TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|INVALID_CURRENCY" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|DEP_VALID|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.
