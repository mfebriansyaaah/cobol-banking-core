       IDENTIFICATION DIVISION.
       PROGRAM-ID. card_posting_core.
      *> Card posting resolves (maint-05, ADR-0010): the resolve+GL-post
      *> paragraphs relocated from card_core. The owner keeps the action
      *> dispatch, the idempotency claims, and the single transaction; this
      *> module issues zero SQL_BEGIN/COMMIT/ROLLBACK and never CALLs back
      *> into card_core. It runs before any card transaction opens (gl_core
      *> posts on its own transaction, exactly as before the split).
      *>
      *> Contract (internal CALL, pre-trimmed inputs like every module seam):
      *>   LS-PARAM1 = card id, LS-PARAM2 = auth ref (capture/reverse) or
      *>     amount (repay), LS-PARAM3 = currency (capture: txn currency;
      *>     reverse: card currency), LS-PARAM4 = amount (capture: txn
      *>     amount; reverse: card amount), LS-PARAM5 = unused, LS-PARAM6 =
      *>     actor email (GL audit actor).
      *>   Success: SUCCESS|POST_READY|<9 pipe fields>
      *>     CURR-ID|RCV-ACC|PAY-ACC|CUST-EMAIL|CUST-ACC|TMP-STR|GL-JID|
      *>     TXN-REF|DESC (fixed widths, empty when the action needs none).
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
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-CURR-ID              PIC X(20) VALUE SPACES.
       01  WS-RCV-ACC              PIC X(20) VALUE SPACES.
       01  WS-PAY-ACC              PIC X(20) VALUE SPACES.
       01  WS-CUST-EMAIL           PIC X(100) VALUE SPACES.
       01  WS-CUST-ACC             PIC X(20) VALUE SPACES.
       01  WS-CUST-CURR            PIC X(10) VALUE SPACES.
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
       01  WS-TMP-AMT              PIC X(30) VALUE SPACES.
       01  WS-TMP-CURR             PIC X(10) VALUE SPACES.
       01  WS-TMP-STR              PIC X(100) VALUE SPACES.
       01  WS-NUM-AMOUNT           PIC 9(15)V9(4) VALUE 0.
       01  WS-NUM-BALANCE          PIC 9(15)V9(4) VALUE 0.
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
               WHEN LS-CMD-ACTION(1:17) = "CARD_POST_CAPTURE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POST-CAPTURE
               WHEN LS-CMD-ACTION(1:15) = "CARD_POST_REPAY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POST-REPAY
               WHEN LS-CMD-ACTION(1:17) = "CARD_POST_REVERSE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POST-REVERSE
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION|0" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_validate_all.cpy".
        COPY "common_sql.cpy".
        COPY "common_trim.cpy".

       ACTION-POST-CAPTURE.
           *> P3/P4 carry the txn currency + amount the caller resolved
           *> from the card_transaction row.
           MOVE WS-P3-TRIMMED TO WS-TMP-CURR
           MOVE WS-P4-TRIMMED TO WS-TMP-AMT
           *> Resolve the capture path: bank-owned CARD_RECEIVABLE plus
           *> MERCHANT_PAYABLE suspense for the card currency, plus the
           *> cardholder for leg attribution. Missing books fail closed.
           MOVE WS-TMP-CURR TO WS-BIND-1
           PERFORM LOOKUP-CURRENCY
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-CURR-ID
           MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'CARD_RECEIVABLE' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-CURR-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|CARD_RECEIVABLE_MISSING" TO WS-ERR
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
           MOVE WS-RESULT(1:20) TO WS-RCV-ACC
           MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'MERCHANT_PAYABLE' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-CURR-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|MERCHANT_PAYABLE_MISSING" TO WS-ERR
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
           MOVE WS-RESULT(1:20) TO WS-PAY-ACC
           MOVE "SELECT customer_email FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE WS-RESULT(1:100) TO WS-CUST-EMAIL
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
           STRING "CARD_CAPTURE:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
           STRING "1310:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE ":0;2130:0:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
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
               MOVE WS-TMP-CURR TO WS-CALL-P3
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
           STRING "CARDCAP-" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-TXN-REF END-STRING
           STRING "CARD_CAPTURE:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-DESC END-STRING
           PERFORM POST-OK.
           EXIT PARAGRAPH.

       ACTION-POST-REPAY.
           *> Amount re-derived from the validated P2 (the caller
           *> normalized it before the CALL; NUMVAL is deterministic).
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT

           *> Resolve the repayment path: card balance guard, customer
           *> wallet, and the bank-owned CARD_RECEIVABLE book. Overpaying
           *> past the outstanding balance fails closed with OVERPAID;
           *> a missing wallet fails closed with no write.
           MOVE "SELECT CONCAT(CAST(balance AS CHAR), '|', customer_email, '|', currency) FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE SPACES TO WS-TMP-AMT WS-CUST-EMAIL WS-CUST-CURR
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-AMT WS-CUST-EMAIL WS-CUST-CURR END-UNSTRING
           MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-BALANCE
           IF WS-NUM-AMOUNT > WS-NUM-BALANCE
               MOVE "ERROR|OVERPAID" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
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
           MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'CARD_RECEIVABLE' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-CURR-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|CARD_RECEIVABLE_MISSING" TO WS-ERR
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
           MOVE WS-RESULT(1:20) TO WS-RCV-ACC
           MOVE "SELECT CAST(balance AS CHAR) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
           MOVE WS-CUST-ACC TO WS-BIND-1
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
           MOVE FUNCTION NUMVAL(WS-RESULT) TO WS-NUM-BALANCE
           IF WS-NUM-AMOUNT > WS-NUM-BALANCE
               MOVE "ERROR|INSUFFICIENT_FUNDS" TO WS-ERR
               MOVE "0" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           *> Bank-side journal first (gl_core owns its own transaction on
           *> this connection): DEBIT Cash / CREDIT Cards receivable. The
           *> UUID makes every repayment its own journal.
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
           MOVE "SELECT UUID_SHORT()" TO WS-PREP-SQL
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
           MOVE WS-RESULT(1:30) TO WS-TMP-STR
           MOVE SPACES TO WS-GL-DESC WS-GL-LINES
           STRING "CARD_REPAY:" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
           STRING "1000:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE ":0;1310:0:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
           MOVE SPACES TO WS-GL-JID
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
           MOVE SPACES TO WS-TXN-REF WS-DESC
           STRING "CARDRP-" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE INTO WS-TXN-REF END-STRING
           STRING "CARD_REPAY:" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE INTO WS-DESC END-STRING
           PERFORM POST-OK.
           EXIT PARAGRAPH.


       ACTION-POST-REVERSE.
           *> P3/P4 carry the card currency + amount the
           *> caller resolved from the transaction row.
           MOVE WS-P3-TRIMMED TO WS-CUST-CURR
           MOVE WS-P4-TRIMMED TO WS-TMP-AMT
           *> Resolve the reversal path and post the refund journal for a
           *> captured authorization: DEBIT Merchants payable / CREDIT
           *> Cards receivable. Runs before any transaction opens.
           MOVE SPACES TO WS-ERR
           MOVE WS-CUST-CURR TO WS-BIND-1
           PERFORM LOOKUP-CURRENCY
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-CURR-ID
           MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'CARD_RECEIVABLE' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-CURR-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|CARD_RECEIVABLE_MISSING" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-RCV-ACC
           MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'MERCHANT_PAYABLE' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-CURR-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|MERCHANT_PAYABLE_MISSING" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-PAY-ACC
           MOVE "SELECT customer_email FROM card_account WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:100) TO WS-CUST-EMAIL
           MOVE "SELECT CAST(CURDATE() AS CHAR)" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               MOVE "1" TO WS-ERR-CLEAN
               PERFORM POST-FAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:10) TO WS-POST-DATE
           MOVE SPACES TO WS-GL-DESC WS-GL-LINES
           STRING "CARD_REV_CAP:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
           STRING "2130:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE ":0;1310:0:" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
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
                   MOVE "1" TO WS-ERR-CLEAN
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
                   MOVE WS-CALL-OUT TO WS-ERR
                   MOVE "1" TO WS-ERR-CLEAN
                   PERFORM POST-FAIL
                   EXIT PARAGRAPH
               END-IF
               MOVE SPACES TO WS-JOUT-1 WS-JOUT-2 WS-GL-JID
               UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-GL-JID END-UNSTRING
               IF WS-JOUT-2 NOT = "GL_POSTED_ML" OR WS-GL-JID = SPACES
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
                   MOVE "1" TO WS-ERR-CLEAN
                   PERFORM POST-FAIL
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE SPACES TO WS-TXN-REF WS-DESC
           STRING "CARDRC-" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-TXN-REF END-STRING
           STRING "CARD_REV_CAP:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-DESC END-STRING
           PERFORM POST-OK.
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
               WS-CURR-ID DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-RCV-ACC DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-PAY-ACC DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-CUST-EMAIL DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-CUST-ACC DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-TMP-STR DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-GL-JID DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-TXN-REF DELIMITED BY SIZE "|" DELIMITED BY SIZE
               WS-DESC DELIMITED BY SIZE
               INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.
