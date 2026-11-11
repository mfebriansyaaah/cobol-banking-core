       IDENTIFICATION DIVISION.
       PROGRAM-ID. gl_core.
      *> General-ledger core (Phase 1).
      *> Actions: GL_ACCOUNT_LIST, GL_ACCOUNT_CREATE, GL_JOURNAL_POST,
      *> GL_TRIAL_BALANCE.
      *> Business rules and state transitions remain in COBOL.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

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
       01  WS-I                    PIC 9(3) VALUE 1.
       01  WS-J                    PIC 9(5) VALUE 1.
       01  WS-RLEN                 PIC 9(5) VALUE 1.
       01  WS-BAD                  PIC 9(3) VALUE 0.
       01  WS-ALLOWED              PIC 9 VALUE 0.
       01  WS-CHECK                PIC X(100) VALUE SPACES.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-TOTAL                PIC X(100) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-COUNT                PIC X(10) VALUE SPACES.
       01  WS-PERIOD               PIC X(7) VALUE SPACES.
       01  WS-PERIOD-STATUS        PIC X(10) VALUE SPACES.
       01  WS-PERIOD-BAD           PIC 9 VALUE 0.
       01  WS-LINES                PIC X(100) VALUE SPACES.
       01  WS-LINE                 PIC X(100) VALUE SPACES.
       01  WS-ACC                  PIC X(20) VALUE SPACES.
       01  WS-DR                   PIC X(30) VALUE SPACES.
       01  WS-CR                   PIC X(30) VALUE SPACES.
       01  WS-LINE-NO              PIC 9(2) VALUE 1.
       01  WS-LINE-PTR             PIC 9(3) VALUE 1.
       01  WS-BALANCE              PIC X(20) VALUE SPACES.
       01  WS-Z                    PIC 9(3) VALUE 1.
       01  WS-DR-ZERO              PIC 9 VALUE 1.
       01  WS-CR-ZERO              PIC 9 VALUE 1.
       01  WS-CURRENCY             PIC X(3) VALUE SPACES.
       01  WS-AMOUNT               PIC X(30) VALUE SPACES.
       01  WS-AMT-LEN              PIC 9(3) VALUE 1.
       01  WS-DOT-COUNT            PIC 9(3) VALUE 0.
       01  WS-NONZERO              PIC 9 VALUE 0.
       01  WS-DATE-SAVE            PIC X(10) VALUE SPACES.
       01  WS-JOURNAL-ID           PIC X(20) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(32) VALUE SPACES.
       01  WS-AUDIT-JOURNAL        PIC X(20) VALUE SPACES.
       01  WS-AUDIT-ACCOUNT        PIC X(20) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(100) VALUE SPACES.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.
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
               WHEN LS-CMD-ACTION(1:15) = "GL_ACCOUNT_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ACCOUNT-LIST
               WHEN LS-CMD-ACTION(1:17) = "GL_ACCOUNT_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ACCOUNT-CREATE
               WHEN LS-CMD-ACTION(1:18) = "GL_JOURNAL_POST_ML"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-JOURNAL-POST-ML
               WHEN LS-CMD-ACTION(1:15) = "GL_JOURNAL_POST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-JOURNAL-POST
               WHEN LS-CMD-ACTION(1:16) = "GL_TRIAL_BALANCE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-TRIAL-BALANCE
               WHEN LS-CMD-ACTION(1:14) = "GL_PERIOD_OPEN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-PERIOD-OPEN
               WHEN LS-CMD-ACTION(1:15) = "GL_PERIOD_CLOSE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-PERIOD-CLOSE
               WHEN LS-CMD-ACTION(1:14) = "GL_PERIOD_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-PERIOD-LIST
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

       VALIDATE-ALL.
           MOVE 0 TO WS-BAD
           MOVE LS-PARAM1 TO WS-CHECK
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM2 TO WS-CHECK
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM3 TO WS-CHECK
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM4 TO WS-CHECK
           EVALUATE TRUE
               WHEN LS-CMD-ACTION(1:18) = "GL_JOURNAL_POST_ML"
                   PERFORM VALIDATE-LINES
               WHEN OTHER
                   PERFORM VALIDATE-INPUT
           END-EVALUATE.
           MOVE LS-PARAM5 TO WS-CHECK
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM6 TO WS-CHECK
           PERFORM VALIDATE-INPUT.
           EXIT PARAGRAPH.

       VALIDATE-INPUT.
           INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-QUOTE
           INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-DQUOTE
           INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-BSLASH
           INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-SEMI
           INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-TICK.
           EXIT PARAGRAPH.

       VALIDATE-LINES.
           INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-QUOTE
           INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-DQUOTE
           INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-BSLASH
           INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-TICK.
           EXIT PARAGRAPH.

       TRIM-ALL.
           PERFORM TRIM-P1
           PERFORM TRIM-P2
           PERFORM TRIM-P3
           PERFORM TRIM-P4
           PERFORM TRIM-P5
           PERFORM TRIM-P6.
           EXIT PARAGRAPH.

       TRIM-P1.
           MOVE LS-PARAM1 TO WS-P1-TRIMMED
           MOVE 0 TO WS-P1-LEN
           PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P1-LEN > 0
               IF WS-P1-TRIMMED(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-P1-LEN
               END-IF
           END-PERFORM
           IF WS-P1-LEN = 0
               MOVE 1 TO WS-P1-LEN
           END-IF.
           EXIT PARAGRAPH.

       TRIM-P2.
           MOVE LS-PARAM2 TO WS-P2-TRIMMED
           MOVE 0 TO WS-P2-LEN
           PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P2-LEN > 0
               IF WS-P2-TRIMMED(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-P2-LEN
               END-IF
           END-PERFORM
           IF WS-P2-LEN = 0
               MOVE 1 TO WS-P2-LEN
           END-IF.
           EXIT PARAGRAPH.

       TRIM-P3.
           MOVE LS-PARAM3 TO WS-P3-TRIMMED
           MOVE 0 TO WS-P3-LEN
           PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P3-LEN > 0
               IF WS-P3-TRIMMED(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-P3-LEN
               END-IF
           END-PERFORM
           IF WS-P3-LEN = 0
               MOVE 1 TO WS-P3-LEN
           END-IF.
           EXIT PARAGRAPH.

       TRIM-P4.
           MOVE LS-PARAM4 TO WS-P4-TRIMMED
           MOVE 0 TO WS-P4-LEN
           PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P4-LEN > 0
               IF WS-P4-TRIMMED(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-P4-LEN
               END-IF
           END-PERFORM
           IF WS-P4-LEN = 0
               MOVE 1 TO WS-P4-LEN
           END-IF.
           EXIT PARAGRAPH.

       TRIM-P5.
           MOVE LS-PARAM5 TO WS-P5-TRIMMED
           MOVE 0 TO WS-P5-LEN
           PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P5-LEN > 0
               IF WS-P5-TRIMMED(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-P5-LEN
               END-IF
           END-PERFORM
           IF WS-P5-LEN = 0
               MOVE 1 TO WS-P5-LEN
           END-IF.
           EXIT PARAGRAPH.

       TRIM-P6.
           MOVE LS-PARAM6 TO WS-P6-TRIMMED
           MOVE 0 TO WS-P6-LEN
           PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P6-LEN > 0
               IF WS-P6-TRIMMED(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-P6-LEN
               END-IF
           END-PERFORM
           IF WS-P6-LEN = 0
               MOVE 1 TO WS-P6-LEN
           END-IF.
           EXIT PARAGRAPH.

        COPY "common_auth.cpy".

       AUDIT-DENIED.
           MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'GL_CORE', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
           MOVE LS-CMD-ACTION TO WS-BIND-1
           MOVE WS-DENIED-TARGET TO WS-BIND-2
           MOVE WS-DENIED-ACTOR TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
           EXIT PARAGRAPH.

       AUDIT-GL.
           MOVE "INSERT INTO gl_audit (action, journal_id, account_code, actor_email, detail) VALUES (?, NULLIF(?, ''), NULLIF(?, ''), ?, ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-AUDIT-JOURNAL TO WS-BIND-2
           MOVE WS-AUDIT-ACCOUNT TO WS-BIND-3
           MOVE WS-P6-TRIMMED TO WS-BIND-4
           MOVE WS-AUDIT-DETAIL TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

        COPY "common_result.cpy".

       VALIDATE-DATE.
           MOVE 0 TO WS-BAD
           IF WS-P1-LEN NOT = 10
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-P1-TRIMMED(5:1) NOT = "-" OR WS-P1-TRIMMED(8:1) NOT = "-"
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-P1-TRIMMED(1:4) IS NOT NUMERIC
              OR WS-P1-TRIMMED(6:2) IS NOT NUMERIC
              OR WS-P1-TRIMMED(9:2) IS NOT NUMERIC
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-RANGE.
           MOVE LS-PARAM1 TO WS-P1-TRIMMED
           MOVE 10 TO WS-P1-LEN
           PERFORM VALIDATE-DATE
           IF WS-BAD > 0
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:10) TO WS-DATE-SAVE
           MOVE LS-PARAM2 TO WS-P1-TRIMMED
           MOVE 10 TO WS-P1-LEN
           PERFORM VALIDATE-DATE
           MOVE WS-DATE-SAVE TO WS-P1-TRIMMED.
           EXIT PARAGRAPH.

       VALIDATE-AMOUNT.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-DOT-COUNT
           MOVE 0 TO WS-NONZERO
           MOVE 0 TO WS-AMT-LEN
           PERFORM VARYING WS-I FROM 30 BY -1 UNTIL WS-I < 1 OR WS-AMT-LEN > 0
               IF WS-AMOUNT(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-AMT-LEN
               END-IF
           END-PERFORM
           IF WS-AMT-LEN = 0
               MOVE 1 TO WS-BAD
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-AMT-LEN
               IF WS-AMOUNT(WS-I:1) = "."
                   ADD 1 TO WS-DOT-COUNT END-ADD
               ELSE
                   IF WS-AMOUNT(WS-I:1) IS NOT NUMERIC
                       MOVE 1 TO WS-BAD
                   ELSE
                       IF WS-AMOUNT(WS-I:1) NOT = "0"
                           MOVE 1 TO WS-NONZERO
                       END-IF
                   END-IF
               END-IF
           END-PERFORM.
           IF WS-DOT-COUNT > 1
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-NONZERO = 0
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       ACTION-ACCOUNT-LIST.
           MOVE "GL_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM gl_account" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(account_code, ':', name, ':', account_type, ':', normal_side, ':', is_active) FROM gl_account ORDER BY account_code LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-LIMIT TO WS-BIND-1
           MOVE WS-OFFSET TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|GL_ACCOUNTS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|GL_ACCOUNTS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-ACCOUNT-CREATE.
           MOVE "GL_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-LEN < 1 OR WS-P1-LEN > 20
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-LEN < 1 OR WS-P2-LEN > 100
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED(1:WS-P3-LEN) NOT = "ASSET"
              AND WS-P3-TRIMMED(1:WS-P3-LEN) NOT = "LIABILITY"
              AND WS-P3-TRIMMED(1:WS-P3-LEN) NOT = "EQUITY"
              AND WS-P3-TRIMMED(1:WS-P3-LEN) NOT = "REVENUE"
              AND WS-P3-TRIMMED(1:WS-P3-LEN) NOT = "EXPENSE"
               MOVE "ERROR|INVALID_TYPE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P4-TRIMMED(1:WS-P4-LEN) NOT = "DEBIT"
              AND WS-P4-TRIMMED(1:WS-P4-LEN) NOT = "CREDIT"
               MOVE "ERROR|INVALID_SIDE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM5 NOT = SPACES
               MOVE "SELECT 1 FROM gl_account WHERE account_code = ? AND is_active = TRUE LIMIT 1" TO WS-PREP-SQL
               MOVE WS-P5-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT = "ERROR|NO_DATA"
                   MOVE "ERROR|PARENT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO gl_account (account_code, name, account_type, normal_side, parent_code, is_active) VALUES (?, ?, ?, ?, NULLIF(?, ''), TRUE)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-P5-TRIMMED TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "ACCOUNT_CREATE" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-JOURNAL
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-ACCOUNT
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-GL
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|GL_ACCOUNT_CREATED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                   MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-JOURNAL-POST.
           MOVE "GL_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE LS-PARAM1 TO WS-P1-TRIMMED
           MOVE 10 TO WS-P1-LEN
           PERFORM VALIDATE-DATE
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_DATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-PERIOD
           IF WS-PERIOD-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-PERIOD-BAD = 1
               MOVE "ERROR|PERIOD_NOT_OPEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-PERIOD-STATUS NOT = "OPEN"
               MOVE "ERROR|PERIOD_CLOSED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-LEN < 1 OR WS-P2-LEN > 100
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-LEN < 1 OR WS-P3-LEN > 20
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P4-LEN < 1 OR WS-P4-LEN > 20
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED(1:WS-P3-LEN) = WS-P4-TRIMMED(1:WS-P4-LEN)
               MOVE "ERROR|SAME_ACCOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           UNSTRING WS-P5-TRIMMED DELIMITED BY ":" INTO WS-CURRENCY WS-AMOUNT
           END-UNSTRING
           IF WS-CURRENCY IS NOT ALPHABETIC
               MOVE "ERROR|INVALID_CURRENCY" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM VALIDATE-AMOUNT
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM gl_account WHERE account_code IN (?, ?) AND is_active = TRUE" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P4-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:10) TO WS-COUNT
           IF WS-COUNT NOT = "2"
               MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO gl_journal (posting_date, description, currency_code, status, source, created_by) VALUES (?, ?, ?, 'POSTED', 'MANUAL', ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-CURRENCY TO WS-BIND-3
           MOVE WS-P6-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-JOURNAL-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSERT INTO gl_journal_line (journal_id, gl_account_code, debit_amount, credit_amount, memo) VALUES (?, ?, ?, 0, ?)" TO WS-PREP-SQL
               MOVE WS-JOURNAL-ID TO WS-BIND-1
               MOVE WS-P3-TRIMMED TO WS-BIND-2
               MOVE WS-AMOUNT TO WS-BIND-3
               MOVE WS-P2-TRIMMED TO WS-BIND-4
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSERT INTO gl_journal_line (journal_id, gl_account_code, debit_amount, credit_amount, memo) VALUES (?, ?, 0, ?, ?)" TO WS-PREP-SQL
               MOVE WS-JOURNAL-ID TO WS-BIND-1
               MOVE WS-P4-TRIMMED TO WS-BIND-2
               MOVE WS-AMOUNT TO WS-BIND-3
               MOVE WS-P2-TRIMMED TO WS-BIND-4
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "JOURNAL_POST" TO WS-AUDIT-ACTION
               MOVE WS-JOURNAL-ID TO WS-AUDIT-JOURNAL
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-GL
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|GL_POSTED|" DELIMITED BY SIZE
                      WS-JOURNAL-ID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       CHECK-PERIOD.
           MOVE 0 TO WS-PERIOD-BAD
           MOVE SPACES TO WS-PERIOD-STATUS
           MOVE WS-P1-TRIMMED(1:7) TO WS-PERIOD
           MOVE "SELECT status FROM gl_period WHERE period_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-PERIOD TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE 1 TO WS-PERIOD-BAD
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE 2 TO WS-PERIOD-BAD
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:10) TO WS-PERIOD-STATUS.
           EXIT PARAGRAPH.

       VALIDATE-PERIOD.
           MOVE 0 TO WS-BAD
           IF WS-P1-LEN NOT = 7
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-P1-TRIMMED(5:1) NOT = "-"
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-P1-TRIMMED(1:4) IS NOT NUMERIC
              OR WS-P1-TRIMMED(6:2) IS NOT NUMERIC
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       ACTION-PERIOD-OPEN.
           MOVE "GL_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM VALIDATE-PERIOD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_PERIOD" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT IGNORE INTO gl_period (period_code,status) VALUES (?, 'OPEN')" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "SELECT status FROM gl_period WHERE period_code = ? LIMIT 1" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT = "ERROR|NO_DATA"
                   MOVE "ERROR|NOT_FOUND" TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   IF WS-RESULT(1:5) = "ERROR"
                       MOVE WS-RESULT(1:40) TO WS-ERR
                       SET STEP-FAIL TO TRUE
                   ELSE
                       MOVE WS-RESULT(1:10) TO WS-PERIOD-STATUS
                   END-IF
               END-IF
           END-IF.
           IF STEP-OK
               IF WS-PERIOD-STATUS = "CLOSED"
                   MOVE "ERROR|PERIOD_CLOSED" TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "PERIOD_OPEN" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-JOURNAL
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-GL
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|GL_PERIOD_OPEN" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|PERIOD_CLOSED"
                   MOVE "ERROR|PERIOD_CLOSED" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-PERIOD-CLOSE.
           MOVE "GL_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM VALIDATE-PERIOD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_PERIOD" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE gl_period SET status = 'CLOSED', closed_by = ?, closed_at = NOW() WHERE period_code = ? AND status = 'OPEN'" TO WS-PREP-SQL
           MOVE WS-P6-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "PERIOD_CLOSE" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-JOURNAL
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-GL
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|GL_PERIOD_CLOSED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-PERIOD-LIST.
           MOVE "GL_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM gl_period" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(period_code, ':', status, ':', COALESCE(closed_by, '')) FROM gl_period ORDER BY period_code DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-LIMIT TO WS-BIND-1
           MOVE WS-OFFSET TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|GL_PERIODS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|GL_PERIODS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-JOURNAL-POST-ML.
           MOVE "GL_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE LS-PARAM1 TO WS-P1-TRIMMED
           MOVE 10 TO WS-P1-LEN
           PERFORM VALIDATE-DATE
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_DATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-PERIOD
           IF WS-PERIOD-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-PERIOD-BAD = 1
               MOVE "ERROR|PERIOD_NOT_OPEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-PERIOD-STATUS NOT = "OPEN"
               MOVE "ERROR|PERIOD_CLOSED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-LEN < 1 OR WS-P2-LEN > 100
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-LEN NOT = 3 OR WS-P3-TRIMMED(1:3) IS NOT ALPHABETIC
               MOVE "ERROR|INVALID_CURRENCY" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P4-LEN < 1 OR WS-P4-LEN > 100
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P4-TRIMMED TO WS-LINES
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO gl_journal (posting_date, description, currency_code, status, source, created_by) VALUES (?, ?, ?, 'POSTED', 'MANUAL_ML', ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P6-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-JOURNAL-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE 1 TO WS-LINE-NO
               MOVE 1 TO WS-LINE-PTR
               PERFORM UNTIL WS-LINE-NO > 10 OR WS-LINE-PTR > WS-P4-LEN
                   OR STEP-FAIL
                   MOVE SPACES TO WS-LINE
                   UNSTRING WS-LINES DELIMITED BY ";" INTO WS-LINE
                       WITH POINTER WS-LINE-PTR
                   END-UNSTRING
                   IF WS-LINE = SPACES
                       EXIT PERFORM
                   END-IF
                   PERFORM PROCESS-ML-LINE
                   ADD 1 TO WS-LINE-NO END-ADD
               END-PERFORM
           END-IF.
           IF STEP-OK
               MOVE "SELECT IF(COUNT(*)=0,'EMPTY',IF(SUM(debit_amount)=SUM(credit_amount) AND SUM(debit_amount)>0,'BALANCED','UNBALANCED')) FROM gl_journal_line WHERE journal_id = ?" TO WS-PREP-SQL
               MOVE WS-JOURNAL-ID TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-BALANCE
                   IF WS-BALANCE NOT = "BALANCED"
                       MOVE "ERROR|UNBALANCED" TO WS-ERR
                       SET STEP-FAIL TO TRUE
                   END-IF
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "JOURNAL_POST_ML" TO WS-AUDIT-ACTION
               MOVE WS-JOURNAL-ID TO WS-AUDIT-JOURNAL
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-GL
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|GL_POSTED_ML|" DELIMITED BY SIZE
                      WS-JOURNAL-ID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|UNBALANCED"
                   MOVE "ERROR|UNBALANCED" TO LS-OUTPUT-BUFFER
               ELSE
                   IF WS-ERR = "ERROR|ACCOUNT_NOT_FOUND"
                       MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                   ELSE
                       IF WS-ERR = "ERROR|INVALID_INPUT"
                           MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                       ELSE
                           MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                       END-IF
                   END-IF
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       PROCESS-ML-LINE.
           MOVE SPACES TO WS-ACC WS-DR WS-CR
           UNSTRING WS-LINE DELIMITED BY ":" INTO WS-ACC WS-DR WS-CR
           END-UNSTRING
           IF WS-ACC = SPACES
               MOVE "ERROR|INVALID_INPUT" TO WS-ERR
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF
           MOVE 1 TO WS-DR-ZERO WS-CR-ZERO
           PERFORM VARYING WS-Z FROM 1 BY 1 UNTIL WS-Z > 30
               IF WS-DR(WS-Z:1) IS NUMERIC AND WS-DR(WS-Z:1) NOT = "0"
                   MOVE 0 TO WS-DR-ZERO
               END-IF
               IF WS-CR(WS-Z:1) IS NUMERIC AND WS-CR(WS-Z:1) NOT = "0"
                   MOVE 0 TO WS-CR-ZERO
               END-IF
           END-PERFORM
           IF WS-DR-ZERO = WS-CR-ZERO
               MOVE "ERROR|INVALID_INPUT" TO WS-ERR
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF
           MOVE "SELECT 1 FROM gl_account WHERE account_code = ? AND is_active = TRUE LIMIT 1" TO WS-PREP-SQL
           MOVE WS-ACC TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|ACCOUNT_NOT_FOUND" TO WS-ERR
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF
           MOVE "INSERT INTO gl_journal_line (journal_id, gl_account_code, debit_amount, credit_amount, memo) VALUES (?, ?, ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-JOURNAL-ID TO WS-BIND-1
           MOVE WS-ACC TO WS-BIND-2
           MOVE WS-DR TO WS-BIND-3
           MOVE WS-CR TO WS-BIND-4
           MOVE WS-P2-TRIMMED TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

       ACTION-TRIAL-BALANCE.
           MOVE "GL_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM VALIDATE-RANGE
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_DATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-LEN NOT = 3 OR WS-P3-TRIMMED(1:3) IS NOT ALPHABETIC
               MOVE "ERROR|INVALID_CURRENCY" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-PREP-SQL
           STRING "SELECT CONCAT(CAST(COALESCE(SUM(l.debit_amount),0) AS CHAR), ':', " DELIMITED BY SIZE
                  "CAST(COALESCE(SUM(l.credit_amount),0) AS CHAR), ':', " DELIMITED BY SIZE
                  "IF(COALESCE(SUM(l.debit_amount),0)=COALESCE(SUM(l.credit_amount),0),'BALANCED','UNBALANCED')) " DELIMITED BY SIZE
                  "FROM gl_journal_line l JOIN gl_journal j ON j.id = l.journal_id " DELIMITED BY SIZE
                  "WHERE j.status = 'POSTED' AND j.currency_code = ? " DELIMITED BY SIZE
                  "AND j.posting_date BETWEEN ? AND ?" DELIMITED BY SIZE
                  INTO WS-PREP-SQL
           END-STRING
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:80) TO WS-TOTAL
           MOVE SPACES TO WS-PREP-SQL
           STRING "SELECT CONCAT(a.account_code, ':', a.name, ':', a.account_type, ':', " DELIMITED BY SIZE
                  "CAST(COALESCE(t.debit,0) AS CHAR), ':', CAST(COALESCE(t.credit,0) AS CHAR)) " DELIMITED BY SIZE
                  "FROM gl_account a LEFT JOIN (SELECT l.gl_account_code, " DELIMITED BY SIZE
                  "SUM(l.debit_amount) debit, SUM(l.credit_amount) credit " DELIMITED BY SIZE
                  "FROM gl_journal_line l JOIN gl_journal j ON j.id = l.journal_id " DELIMITED BY SIZE
                  "WHERE j.status = 'POSTED' AND j.currency_code = ? " DELIMITED BY SIZE
                  "AND j.posting_date BETWEEN ? AND ? GROUP BY l.gl_account_code) t " DELIMITED BY SIZE
                  "ON t.gl_account_code = a.account_code ORDER BY a.account_code" DELIMITED BY SIZE
                  INTO WS-PREP-SQL
           END-STRING
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|GL_TRIAL|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|GL_TRIAL|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.
