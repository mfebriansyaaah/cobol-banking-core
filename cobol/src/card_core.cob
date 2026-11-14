       IDENTIFICATION DIVISION.
       PROGRAM-ID. card_core.
      *> Card management lifecycle.

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
       01  WS-AUDIT-CARD           PIC X(20) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-TMP-AMT              PIC X(30) VALUE SPACES.
       01  WS-TMP-STATUS           PIC X(20) VALUE SPACES.
       01  WS-TMP-CURR             PIC X(10) VALUE SPACES.
       01  WS-TMP-STR              PIC X(100) VALUE SPACES.
       01  WS-TMP-TYPE             PIC X(20) VALUE SPACES.
       01  WS-TMP-TEXT             PIC X(100) VALUE SPACES.
       01  WS-NUM-AMOUNT           PIC 9(15)V9(4) VALUE 0.
       01  WS-NUM-LIMIT            PIC 9(15)V9(4) VALUE 0.
       01  WS-NUM-AVAIL            PIC 9(15)V9(4) VALUE 0.
       01  WS-NUM-BALANCE          PIC 9(15)V9(4) VALUE 0.
       01  WS-AMT-EDIT             PIC Z(18)9.9999 VALUE 0.
       01  WS-NEW-ID               PIC X(20) VALUE SPACES.
       01  WS-IDEM-STATUS          PIC X(10) VALUE SPACES.
       01  WS-IDEM-OWNED           PIC X VALUE "0".
       01  WS-IDEM-ROW             PIC X(200) VALUE SPACES.
       01  WS-IDEM-AMT             PIC X(30) VALUE SPACES.
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
       01  WS-POST-CODE            PIC X(40) VALUE SPACES.
       01  WS-POST-CLEANUP         PIC X VALUE SPACE.
       01  WS-GL-JID               PIC X(20) VALUE SPACES.
       01  WS-JOUT-1               PIC X(20) VALUE SPACES.
       01  WS-JOUT-2               PIC X(20) VALUE SPACES.
       01  WS-CUST-EMAIL           PIC X(100) VALUE SPACES.
       01  WS-CUST-CURR            PIC X(10) VALUE SPACES.
       01  WS-CUST-ACC             PIC X(20) VALUE SPACES.
       01  WS-CURR-ID              PIC X(20) VALUE SPACES.
       01  WS-RCV-ACC              PIC X(20) VALUE SPACES.
       01  WS-PAY-ACC              PIC X(20) VALUE SPACES.
       01  WS-JID                  PIC X(20) VALUE SPACES.
       01  WS-TXN-REF              PIC X(50) VALUE SPACES.
       01  WS-DESC                 PIC X(255) VALUE SPACES.
       01  F-QUOTE                 PIC X VALUE "'".
       01  F-DQUOTE                PIC X VALUE '"'.
       01  F-BSLASH                PIC X VALUE "\".
       01  F-TICK                  PIC X VALUE "`".

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
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               GOBACK
           END-IF
           EVALUATE TRUE
               WHEN LS-CMD-ACTION(1:10) = "CARD_ISSUE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ISSUE
               WHEN LS-CMD-ACTION(1:10) = "CARD_BLOCK"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BLOCK
               WHEN LS-CMD-ACTION(1:12) = "CARD_UNBLOCK"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-UNBLOCK
               WHEN LS-CMD-ACTION(1:10) = "CARD_CLOSE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CLOSE
               WHEN LS-CMD-ACTION(1:9) = "CARD_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-LIST
               WHEN LS-CMD-ACTION(1:8) = "CARD_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-GET
               WHEN LS-CMD-ACTION(1:12) = "CARD_SUMMARY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SUMMARY
               WHEN LS-CMD-ACTION(1:14) = "CARD_AUTHORIZE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-AUTHORIZE
               WHEN LS-CMD-ACTION(1:12) = "CARD_CAPTURE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CAPTURE
               WHEN LS-CMD-ACTION(1:10) = "CARD_REPAY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-REPAY
               WHEN LS-CMD-ACTION(1:12) = "CARD_REVERSE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-REVERSE
               WHEN LS-CMD-ACTION(1:14) = "CARD_STATEMENT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-STATEMENT
               WHEN LS-CMD-ACTION(1:14) = "CARD_LIMIT_SET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-LIMIT-SET
               WHEN LS-CMD-ACTION(1:12) = "CARD_REPLACE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-REPLACE
               WHEN LS-CMD-ACTION(1:10) = "CARD_AUDIT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-AUDIT
               WHEN LS-CMD-ACTION(1:13) = "CARD_VALIDATE"
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
           MOVE "INSERT INTO card_audit (action, actor_email, card_id, detail) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-CARD TO WS-BIND-3
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
           MOVE SPACES TO WS-AUDIT-CARD
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT.
           EXIT PARAGRAPH.

        COPY "common_result.cpy".

        COPY "common_idem.cpy".

       CLAIM-CAPTURE-REQUEST.
           *> Client-supplied idempotency for capture (P5), migrated to
           *> common_idem.cpy: the legacy row stays the decision-maker while
           *> every transition is mirrored to idempotency_request.
           PERFORM IDEM-RESET
           MOVE "CARD_CAPTURE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
           MOVE SPACES TO WS-IDEM-DETAILS
           MOVE "ERROR|CAPTURE_IN_PROGRESS" TO WS-IDEM-CODE
           PERFORM IDEM-CLAIM.
           EXIT PARAGRAPH.

       DELETE-CAPTURE-REQUEST.
           *> Drops our own PENDING request row on refusal (status guard);
           *> DONE rows are never touched. The mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "CARD_CAPTURE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       CLAIM-REPAY-REQUEST.
           *> Client-supplied idempotency for repay (P5), migrated to
           *> common_idem.cpy: the legacy row stays the decision-maker while
           *> every transition is mirrored to idempotency_request.
           PERFORM IDEM-RESET
           MOVE "CARD_REPAY" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-IDEM-AMOUNT
           MOVE SPACES TO WS-IDEM-DETAILS
           MOVE "ERROR|REPAY_IN_PROGRESS" TO WS-IDEM-CODE
           PERFORM IDEM-CLAIM.
           EXIT PARAGRAPH.

       DELETE-REPAY-REQUEST.
           *> Drops our own PENDING request row on refusal (status guard);
           *> DONE rows are never touched. The mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "CARD_REPAY" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       CLAIM-REVERSE-REQUEST.
           *> Client-supplied idempotency for reverse (P5), migrated to
           *> common_idem.cpy: the legacy row stays the decision-maker while
           *> every transition is mirrored to idempotency_request.
           PERFORM IDEM-RESET
           MOVE "CARD_REVERSE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
           MOVE SPACES TO WS-IDEM-DETAILS
           MOVE "ERROR|REVERSE_IN_PROGRESS" TO WS-IDEM-CODE
           PERFORM IDEM-CLAIM.
           EXIT PARAGRAPH.

       DELETE-REVERSE-REQUEST.
           *> Drops our own PENDING request row on refusal (status guard);
           *> DONE rows are never touched. The mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "CARD_REVERSE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       ACTION-ISSUE.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED NOT = "DEBIT" AND WS-P3-TRIMMED NOT = "CREDIT" AND WS-P3-TRIMMED NOT = "PREPAID"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE 0 TO WS-NUM-LIMIT
           IF WS-P4-TRIMMED NOT = SPACES
               MOVE FUNCTION NUMVAL(WS-P4-TRIMMED) TO WS-NUM-LIMIT
           END-IF
           IF WS-P3-TRIMMED = "CREDIT" AND WS-NUM-LIMIT = 0
               MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT status FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
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
           MOVE WS-RESULT(1:20) TO WS-TMP-STATUS
           IF WS-TMP-STATUS(1:8) NOT = "VERIFIED"
               MOVE "ERROR|UNVERIFIED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT iso_code FROM currencies WHERE iso_code = ? AND is_active = 1 LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P5-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
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
           MOVE "SELECT 1 FROM card_account WHERE card_ref = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) NOT = "ERROR"
               MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO card_account (card_ref, customer_email, card_type, limit_amount, currency, created_by) VALUES (?, ?, ?, COALESCE(NULLIF(?, ''), 0), ?, ?)" TO WS-PREP-SQL
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
           END-IF.
           IF STEP-OK
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-NEW-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE card_account SET masked_pan = CONCAT('**** **** **** ', LPAD(CAST(id AS CHAR), 4, '0')), expiry_date = DATE_ADD(CURDATE(), INTERVAL 3 YEAR), available_limit = limit_amount WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-NEW-ID TO WS-BIND-1
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
               MOVE "ISSUE" TO WS-AUDIT-ACTION
               MOVE WS-NEW-ID TO WS-AUDIT-CARD
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|CARD_ISSUE|" DELIMITED BY SIZE WS-NEW-ID DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BLOCK.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE card_account SET status = 'BLOCKED' WHERE id = ? AND status = 'ACTIVE'" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|CARD_BLOCKED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-UNBLOCK.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE card_account SET status = 'ACTIVE' WHERE id = ? AND status = 'BLOCKED'" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|CARD_UNBLOCKED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-CLOSE.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Fail closed when money is still owed: closing with an
           *> outstanding balance would strand the debt, since CARD_REPAY
           *> refuses CLOSED cards. Settle first, then close.
           MOVE "SELECT CAST(balance AS CHAR) FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-RESULT) TO WS-NUM-BALANCE
           IF WS-NUM-BALANCE > 0
               MOVE "ERROR|OUTSTANDING_BALANCE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE card_account SET status = 'CLOSED' WHERE id = ? AND status IN ('ACTIVE','BLOCKED')" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|CARD_CLOSED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LIST.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
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
           MOVE "SELECT CONCAT(id, ':', card_ref, ':', customer_email, ':', card_type, ':', status, ':', limit_amount, ':', available_limit, ':', balance, ':', COALESCE(masked_pan, '')) FROM card_account WHERE (? = '' OR status = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               MOVE "SUCCESS|CARDS|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|CARDS|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-GET.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(id, '|', card_ref, '|', customer_email, '|', card_type, '|', status, '|', limit_amount, '|', currency, '|', COALESCE(masked_pan, ''), '|', COALESCE(expiry_date, ''), '|', available_limit, '|', balance, '|', COALESCE(replaced_by, '')) FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|CARD|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-SUMMARY.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'ACTIVE'), 0), '|', COALESCE(SUM(status = 'BLOCKED'), 0), '|', COALESCE(SUM(status = 'CLOSED'), 0), '|', COALESCE(SUM(limit_amount), 0), '|', COALESCE(SUM(balance), 0), '|', COALESCE(SUM(available_limit), 0)) FROM card_account" TO WS-PREP-SQL
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
           STRING "SUCCESS|CARD_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:200) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

      *> Authorize a purchase against the available limit. The amount is
      *> held immediately (available_limit decreases) and released when the
      *> authorization is reversed.
       ACTION-AUTHORIZE.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT
           IF WS-NUM-AMOUNT <= 0
               MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(status, '|', available_limit, '|', currency) FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE SPACES TO WS-TMP-STATUS
           MOVE SPACES TO WS-TMP-AMT
           MOVE SPACES TO WS-TMP-CURR
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-STATUS WS-TMP-AMT WS-TMP-CURR END-UNSTRING
           IF WS-TMP-STATUS(1:6) NOT = "ACTIVE"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P4-TRIMMED NOT = SPACES
               IF WS-P4-TRIMMED(1:3) NOT = WS-TMP-CURR(1:3)
                   MOVE "ERROR|CURRENCY_MISMATCH" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-AVAIL
           IF WS-NUM-AVAIL < WS-NUM-AMOUNT
               MOVE "ERROR|LIMIT_EXCEEDED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           *> Take the hold first: the guarded debit serializes concurrent
           *> authorizes on the account row. Inserting the auth row first would
           *> S-lock the parent via fk_card_txn and then X-lock it here, a
           *> classic S-then-X upgrade deadlock under race.
           IF STEP-OK
               MOVE "UPDATE card_account SET available_limit = available_limit - ? WHERE id = ? AND available_limit >= ?" TO WS-PREP-SQL
               MOVE WS-P2-TRIMMED TO WS-BIND-1
               MOVE WS-P1-TRIMMED TO WS-BIND-2
               MOVE WS-P2-TRIMMED TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT = "SUCCESS|AFFECTED_0"
                   MOVE "ERROR|LIMIT_EXCEEDED" TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
                   END-IF
               END-IF
           END-IF.
           MOVE "INSERT INTO card_transaction (card_id, auth_ref, txn_type, amount, currency, merchant, status) VALUES (?, CONCAT('AUTH-', ?, '-', UUID_SHORT()), 'AUTHORIZATION', ?, ?, ?, 'AUTHORIZED')" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           MOVE WS-TMP-CURR(1:3) TO WS-BIND-4
           MOVE WS-P3-TRIMMED TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "SELECT auth_ref FROM card_transaction WHERE card_id = ? ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:64) TO WS-TMP-STR
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "AUTHORIZE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CARD
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|CARD_AUTHORIZE|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE "|" DELIMITED BY SIZE WS-P2-TRIMMED DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|LIMIT_EXCEEDED"
                   MOVE "ERROR|LIMIT_EXCEEDED" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

      *> Capture a previously authorized transaction: the hold becomes a
      *> posted balance movement.
       ACTION-CAPTURE.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(status, '|', amount, '|', currency) FROM card_transaction WHERE card_id = ? AND auth_ref = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
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
           MOVE SPACES TO WS-TMP-STATUS
           MOVE SPACES TO WS-TMP-AMT
           MOVE SPACES TO WS-TMP-CURR
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-STATUS WS-TMP-AMT WS-TMP-CURR END-UNSTRING
           IF WS-P5-TRIMMED NOT = SPACES
               PERFORM CLAIM-CAPTURE-REQUEST
               IF WS-ERR NOT = SPACES
                   MOVE WS-ERR TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "DONE"
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING "SUCCESS|CARD_CAPTURE|" DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-AMT) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF WS-TMP-STATUS(1:10) NOT = "AUTHORIZED"
               PERFORM DELETE-CAPTURE-REQUEST
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Posting resolve lives in card_posting_core (maint-05): the
           *> callee returns SUCCESS|POST_READY + nine fields, or
           *> ERROR|<CODE>|<CLEANUP>. CLEANUP=1 runs the DELETE-* below.
           MOVE "CARD_POST_CAPTURE" TO WS-CALL-ACTION
           MOVE WS-P1-TRIMMED TO WS-CALL-P1
           MOVE WS-P2-TRIMMED TO WS-CALL-P2
           MOVE WS-TMP-CURR TO WS-CALL-P3
           MOVE WS-TMP-AMT TO WS-CALL-P4
           MOVE SPACES TO WS-CALL-P5
           MOVE WS-P6-TRIMMED TO WS-CALL-P6
           MOVE SPACES TO WS-CALL-OUT
           CALL "card_posting_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
               WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           END-CALL
           IF WS-CALL-OUT(1:5) = "ERROR"
               UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-POST-CODE WS-POST-CLEANUP END-UNSTRING
               IF WS-POST-CLEANUP = "1"
                   PERFORM DELETE-CAPTURE-REQUEST
               END-IF
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "ERROR|" DELIMITED BY SIZE FUNCTION TRIM(WS-POST-CODE) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-JOUT-1 WS-JOUT-2
           UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-CURR-ID WS-RCV-ACC WS-PAY-ACC WS-CUST-EMAIL WS-CUST-ACC WS-TMP-STR WS-GL-JID WS-TXN-REF WS-DESC END-UNSTRING
           IF WS-JOUT-1 NOT = "SUCCESS" OR WS-JOUT-2 NOT = "POST_READY"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-JID WS-ERR
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
               MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
               MOVE WS-TXN-REF TO WS-BIND-1
               MOVE WS-RCV-ACC TO WS-BIND-2
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
               MOVE WS-PAY-ACC TO WS-BIND-2
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
               MOVE "UPDATE card_transaction SET status = 'CAPTURED', journal_id = ?, gl_journal_id = ? WHERE card_id = ? AND auth_ref = ? AND status = 'AUTHORIZED'" TO WS-PREP-SQL
               MOVE WS-JID TO WS-BIND-1
               MOVE WS-GL-JID TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               MOVE WS-P2-TRIMMED TO WS-BIND-4
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK AND WS-P5-TRIMMED NOT = SPACES
               PERFORM IDEM-RESET
               MOVE "CARD_CAPTURE" TO WS-IDEM-SCOPE
               MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
               MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
               MOVE SPACES TO WS-IDEM-DETAILS
               MOVE "gl_journal_id" TO WS-IDEM-SETCOL
               MOVE WS-GL-JID TO WS-IDEM-JIDVAL
               PERFORM IDEM-COMPLETE
           END-IF.

           IF STEP-OK
               MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ? AND balance >= ?" TO WS-PREP-SQL
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-1
               MOVE WS-RCV-ACC TO WS-BIND-2
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
               MOVE WS-PAY-ACC TO WS-BIND-2
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
               MOVE "UPDATE card_account SET balance = balance + ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-TMP-AMT TO WS-BIND-1
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
               MOVE "CAPTURE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CARD
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|CARD_CAPTURE|" DELIMITED BY SIZE WS-TMP-AMT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INSUFFICIENT_FUNDS"
                   MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

      *> Pay down the outstanding card balance. The released credit also
      *> returns to the available limit, capped at the card limit.
       ACTION-REPAY.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT
           IF WS-NUM-AMOUNT <= 0
               MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-NUM-AMOUNT TO WS-AMT-EDIT
           MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-P2-TRIMMED
           MOVE "SELECT status FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE WS-RESULT(1:20) TO WS-TMP-STATUS
           IF WS-P5-TRIMMED NOT = SPACES
               PERFORM CLAIM-REPAY-REQUEST
               IF WS-ERR NOT = SPACES
                   MOVE WS-ERR TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "DONE"
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING "SUCCESS|CARD_REPAY|" DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-AMT) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF WS-TMP-STATUS(1:6) = "CLOSED"
               PERFORM DELETE-REPAY-REQUEST
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Posting resolve lives in card_posting_core (maint-05): the
           *> callee returns SUCCESS|POST_READY + nine fields, or
           *> ERROR|<CODE>|<CLEANUP>. CLEANUP=1 runs the DELETE-* below.
           MOVE "CARD_POST_REPAY" TO WS-CALL-ACTION
           MOVE WS-P1-TRIMMED TO WS-CALL-P1
           MOVE WS-P2-TRIMMED TO WS-CALL-P2
           MOVE SPACES TO WS-CALL-P3 WS-CALL-P4
           MOVE SPACES TO WS-CALL-P5
           MOVE WS-P6-TRIMMED TO WS-CALL-P6
           MOVE SPACES TO WS-CALL-OUT
           CALL "card_posting_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
               WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           END-CALL
           IF WS-CALL-OUT(1:5) = "ERROR"
               UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-POST-CODE WS-POST-CLEANUP END-UNSTRING
               IF WS-POST-CLEANUP = "1"
                   PERFORM DELETE-REPAY-REQUEST
               END-IF
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "ERROR|" DELIMITED BY SIZE FUNCTION TRIM(WS-POST-CODE) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-JOUT-1 WS-JOUT-2
           UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-CURR-ID WS-RCV-ACC WS-PAY-ACC WS-CUST-EMAIL WS-CUST-ACC WS-TMP-STR WS-GL-JID WS-TXN-REF WS-DESC END-UNSTRING
           IF WS-JOUT-1 NOT = "SUCCESS" OR WS-JOUT-2 NOT = "POST_READY"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-JID WS-ERR
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
               MOVE WS-P2-TRIMMED TO WS-BIND-1
               MOVE WS-CUST-ACC TO WS-BIND-2
               MOVE WS-P2-TRIMMED TO WS-BIND-3
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
               MOVE "UPDATE card_account SET balance = balance - ?, available_limit = LEAST(limit_amount, available_limit + ?) WHERE id = ? AND balance >= ?" TO WS-PREP-SQL
               MOVE WS-P2-TRIMMED TO WS-BIND-1
               MOVE WS-P2-TRIMMED TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               MOVE WS-P2-TRIMMED TO WS-BIND-4
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT = "SUCCESS|AFFECTED_0"
                   MOVE "ERROR|OVERPAID" TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
                   END-IF
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
               MOVE WS-P2-TRIMMED TO WS-BIND-1
               MOVE WS-RCV-ACC TO WS-BIND-2
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
               MOVE WS-P2-TRIMMED TO WS-BIND-3
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
               MOVE WS-RCV-ACC TO WS-BIND-2
               MOVE WS-P2-TRIMMED TO WS-BIND-3
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
               MOVE "INSERT INTO card_transaction (card_id, auth_ref, txn_type, amount, currency, status, journal_id, gl_journal_id) SELECT id, CONCAT('REPAY-', id, '-', UUID_SHORT()), 'REPAYMENT', ?, currency, 'CAPTURED', @jid, ? FROM card_account WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-P2-TRIMMED TO WS-BIND-1
               MOVE WS-GL-JID TO WS-BIND-2
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
           IF STEP-OK AND WS-P5-TRIMMED NOT = SPACES
               PERFORM IDEM-RESET
               MOVE "CARD_REPAY" TO WS-IDEM-SCOPE
               MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
               MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
               MOVE SPACES TO WS-IDEM-DETAILS
               MOVE "gl_journal_id" TO WS-IDEM-SETCOL
               MOVE WS-GL-JID TO WS-IDEM-JIDVAL
               PERFORM IDEM-COMPLETE
           END-IF.
           IF STEP-OK
               MOVE "REPAY" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CARD
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|CARD_REPAY|" DELIMITED BY SIZE WS-P2-TRIMMED DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|OVERPAID"
                   MOVE "ERROR|OVERPAID" TO LS-OUTPUT-BUFFER
               ELSE
                   IF WS-ERR = "ERROR|INSUFFICIENT_FUNDS"
                       MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                   ELSE
                       MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   END-IF
               END-IF
           END-IF.
           EXIT PARAGRAPH.

      *> Reverse an authorization (release the hold) or a captured
      *> transaction (credit the balance back). Captured repayments are
      *> final and cannot be reversed through this path.
       ACTION-REVERSE.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(status, '|', amount, '|', txn_type, '|', currency) FROM card_transaction WHERE card_id = ? AND auth_ref = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
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
           MOVE SPACES TO WS-TMP-STATUS
           MOVE SPACES TO WS-TMP-AMT
           MOVE SPACES TO WS-TMP-TYPE
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-STATUS WS-TMP-AMT WS-TMP-TYPE WS-CUST-CURR END-UNSTRING
           IF WS-P5-TRIMMED NOT = SPACES
               PERFORM CLAIM-REVERSE-REQUEST
               IF WS-ERR NOT = SPACES
                   MOVE WS-ERR TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "DONE"
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING "SUCCESS|CARD_REVERSE|" DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-AMT) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF WS-TMP-STATUS(1:10) NOT = "AUTHORIZED"
               AND WS-TMP-STATUS(1:8) NOT = "CAPTURED"
               PERFORM DELETE-REVERSE-REQUEST
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-TMP-STATUS(1:8) = "CAPTURED"
               AND WS-TMP-TYPE(1:13) NOT = "AUTHORIZATION"
               PERFORM DELETE-REVERSE-REQUEST
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
    IF WS-TMP-STATUS(1:8) = "CAPTURED"
        AND WS-TMP-TYPE(1:13) = "AUTHORIZATION"
               *> Posting resolve lives in card_posting_core (maint-05): the
               *> callee returns SUCCESS|POST_READY + nine fields, or
               *> ERROR|<CODE>|<CLEANUP>. CLEANUP=1 runs the DELETE-* below.
               MOVE "CARD_POST_REVERSE" TO WS-CALL-ACTION
               MOVE WS-P1-TRIMMED TO WS-CALL-P1
               MOVE WS-P2-TRIMMED TO WS-CALL-P2
               MOVE WS-CUST-CURR TO WS-CALL-P3
               MOVE WS-TMP-AMT TO WS-CALL-P4
               MOVE SPACES TO WS-CALL-P5
               MOVE WS-P6-TRIMMED TO WS-CALL-P6
               MOVE SPACES TO WS-CALL-OUT
               CALL "card_posting_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                   WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
               END-CALL
               IF WS-CALL-OUT(1:5) = "ERROR"
                   UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-POST-CODE WS-POST-CLEANUP END-UNSTRING
                   IF WS-POST-CLEANUP = "1"
                       PERFORM DELETE-REVERSE-REQUEST
                   END-IF
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING "ERROR|" DELIMITED BY SIZE FUNCTION TRIM(WS-POST-CODE) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
               MOVE SPACES TO WS-JOUT-1 WS-JOUT-2
               UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-CURR-ID WS-RCV-ACC WS-PAY-ACC WS-CUST-EMAIL WS-CUST-ACC WS-TMP-STR WS-GL-JID WS-TXN-REF WS-DESC END-UNSTRING
               IF WS-JOUT-1 NOT = "SUCCESS" OR WS-JOUT-2 NOT = "POST_READY"
                   PERFORM DELETE-REVERSE-REQUEST
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
                   MOVE SPACES TO WS-JID
               END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE card_transaction SET status = 'REVERSED' WHERE card_id = ? AND auth_ref = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK AND WS-TMP-STATUS(1:8) = "CAPTURED" AND WS-TMP-TYPE(1:13) = "AUTHORIZATION"
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
           IF STEP-OK AND WS-TMP-STATUS(1:8) = "CAPTURED" AND WS-TMP-TYPE(1:13) = "AUTHORIZATION"
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-JID
               END-IF
           END-IF.
           IF STEP-OK AND WS-TMP-STATUS(1:8) = "CAPTURED" AND WS-TMP-TYPE(1:13) = "AUTHORIZATION"
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
           IF STEP-OK AND WS-TMP-STATUS(1:8) = "CAPTURED" AND WS-TMP-TYPE(1:13) = "AUTHORIZATION"
               MOVE "UPDATE card_transaction SET journal_id = ?, gl_journal_id = ? WHERE card_id = ? AND auth_ref = ?" TO WS-PREP-SQL
               MOVE WS-JID TO WS-BIND-1
               MOVE WS-GL-JID TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               MOVE WS-P2-TRIMMED TO WS-BIND-4
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK AND WS-P5-TRIMMED NOT = SPACES
               PERFORM IDEM-RESET
               MOVE "CARD_REVERSE" TO WS-IDEM-SCOPE
               MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
               MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
               MOVE SPACES TO WS-IDEM-DETAILS
               MOVE "gl_journal_id" TO WS-IDEM-SETCOL
               MOVE WS-GL-JID TO WS-IDEM-JIDVAL
               MOVE "1" TO WS-IDEM-JIDNULL
               PERFORM IDEM-COMPLETE
           END-IF.
           IF STEP-OK AND WS-TMP-STATUS(1:8) = "CAPTURED" AND WS-TMP-TYPE(1:13) = "AUTHORIZATION"
               MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ?" TO WS-PREP-SQL
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-1
               MOVE WS-PAY-ACC TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK AND WS-TMP-STATUS(1:8) = "CAPTURED" AND WS-TMP-TYPE(1:13) = "AUTHORIZATION"
               MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-BIND-1
               MOVE WS-RCV-ACC TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK AND WS-TMP-STATUS(1:8) = "CAPTURED" AND WS-TMP-TYPE(1:13) = "AUTHORIZATION"
               MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
               MOVE WS-TXN-REF TO WS-BIND-1
               MOVE WS-PAY-ACC TO WS-BIND-2
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
           IF STEP-OK AND WS-TMP-STATUS(1:8) = "CAPTURED" AND WS-TMP-TYPE(1:13) = "AUTHORIZATION"
               MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
               MOVE WS-TXN-REF TO WS-BIND-1
               MOVE WS-RCV-ACC TO WS-BIND-2
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
           IF STEP-OK AND WS-TMP-STATUS(1:10) = "AUTHORIZED"
               MOVE "UPDATE card_account SET available_limit = LEAST(limit_amount, available_limit + ?) WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-TMP-AMT TO WS-BIND-1
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
           IF STEP-OK AND WS-TMP-STATUS(1:8) = "CAPTURED"
               MOVE "UPDATE card_account SET balance = GREATEST(balance - ?, 0), available_limit = LEAST(limit_amount, available_limit + ?) WHERE id = ?" TO WS-PREP-SQL
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
               MOVE "REVERSE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CARD
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|CARD_REVERSE|" DELIMITED BY SIZE WS-TMP-AMT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

      *> Card statement: balances plus the bounded transaction history.
       ACTION-STATEMENT.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
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
           MOVE "SELECT CONCAT(balance, '|', limit_amount, '|', available_limit, '|', currency) FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           PERFORM TRIM-RESULT-LEN
           MOVE WS-RESULT(1:100) TO WS-TMP-TEXT
           MOVE "SELECT CONCAT(auth_ref, ':', txn_type, ':', amount, ':', currency, ':', status, ':', COALESCE(merchant, ''), ':', created_at) FROM card_transaction WHERE card_id = ? ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-LIMIT TO WS-BIND-2
           MOVE WS-OFFSET TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|CARD_STATEMENT|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-TEXT) DELIMITED BY SIZE "|" DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|CARD_STATEMENT|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-TEXT) DELIMITED BY SIZE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

      *> Change the card limit. The new limit cannot sit below the
      *> outstanding balance.
       ACTION-LIMIT-SET.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-LIMIT.
           MOVE "SELECT CONCAT(status, '|', balance) FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE SPACES TO WS-TMP-STATUS
           MOVE SPACES TO WS-TMP-AMT
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-STATUS WS-TMP-AMT END-UNSTRING
           IF WS-TMP-STATUS(1:6) = "CLOSED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-BALANCE
           IF WS-NUM-LIMIT < WS-NUM-BALANCE
               MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE card_account SET limit_amount = ?, available_limit = GREATEST(? - balance, 0) WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
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
               MOVE "LIMIT_SET" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CARD
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|CARD_LIMIT|" DELIMITED BY SIZE WS-P2-TRIMMED DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

      *> Replace a card: issue a new card row copying type/limit/balance and
      *> close the old one, keeping the replacement link.
       ACTION-REPLACE.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT 1 FROM card_account WHERE card_ref = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) NOT = "ERROR"
               MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT status FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE WS-RESULT(1:20) TO WS-TMP-STATUS
           IF WS-TMP-STATUS(1:6) = "CLOSED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO card_account (card_ref, customer_email, card_type, limit_amount, currency, created_by, available_limit, balance) SELECT ?, customer_email, card_type, limit_amount, currency, ?, available_limit, balance FROM card_account WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
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
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-NEW-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE card_account SET masked_pan = CONCAT('**** **** **** ', LPAD(CAST(id AS CHAR), 4, '0')), expiry_date = DATE_ADD(CURDATE(), INTERVAL 3 YEAR) WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-NEW-ID TO WS-BIND-1
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
               MOVE "UPDATE card_account SET status = 'CLOSED', replaced_by = ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-NEW-ID TO WS-BIND-1
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
               MOVE "REPLACE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CARD
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|CARD_REPLACE|" DELIMITED BY SIZE WS-NEW-ID DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

      *> Card audit trail, optionally filtered by card id and paged.
       ACTION-AUDIT.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
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
           MOVE "SELECT CONCAT(action, ':', actor_email, ':', COALESCE(detail, ''), ':', created_at) FROM card_audit WHERE (? = '' OR card_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               MOVE "SUCCESS|CARD_AUDIT|" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|CARD_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

      *> Pre-flight validation for CARD_ISSUE: verifies the customer is
      *> verified and the currency is active, and previews the expiry date.
       ACTION-VALIDATE.
           MOVE "CARD_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM4 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-TRIMMED NOT = "DEBIT" AND WS-P2-TRIMMED NOT = "CREDIT" AND WS-P2-TRIMMED NOT = "PREPAID"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT status FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE WS-RESULT(1:20) TO WS-TMP-STATUS
           IF WS-TMP-STATUS(1:8) NOT = "VERIFIED"
               MOVE "ERROR|UNVERIFIED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(DATE_ADD(CURDATE(), INTERVAL 3 YEAR) AS CHAR) FROM currencies WHERE iso_code = ? AND is_active = 1 LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P4-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
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
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|CARD_VALID|" DELIMITED BY SIZE WS-RESULT(1:20) DELIMITED BY SIZE "|" DELIMITED BY SIZE WS-P3-TRIMMED DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.
