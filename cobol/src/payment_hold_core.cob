       IDENTIFICATION DIVISION.
       PROGRAM-ID. payment_hold_core.
      *> Payment hold reserve/capture/release/expire lifecycle.

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
       01  WS-LOOKUP-BAD           PIC 9 VALUE 0.
       01  WS-EXISTS               PIC X VALUE SPACES.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-AT-COUNT             PIC 9(3) VALUE 0.
       01  WS-HOLD-ID              PIC X(20) VALUE SPACES.
       01  WS-ACCOUNT-ID           PIC X(20) VALUE SPACES.
       01  WS-AMOUNT               PIC X(20) VALUE SPACES.
       01  WS-CURRENCY             PIC X(10) VALUE SPACES.
       01  WS-STATUS               PIC X(20) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
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
               WHEN LS-CMD-ACTION(1:12) = "PHL_RESERVE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RESERVE
               WHEN LS-CMD-ACTION(1:12) = "PHL_CAPTURE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CAPTURE
               WHEN LS-CMD-ACTION(1:12) = "PHL_RELEASE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RELEASE
               WHEN LS-CMD-ACTION(1:8) = "PHL_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-LIST
               WHEN LS-CMD-ACTION(1:7) = "PHL_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-GET
               WHEN LS-CMD-ACTION(1:11) = "PHL_EXPIRE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-EXPIRE
               WHEN LS-CMD-ACTION(1:12) = "PHL_SUMMARY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SUMMARY
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

       VALIDATE-ALL.
           MOVE 0 TO WS-BAD
           MOVE LS-PARAM1 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM2 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM3 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM4 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM5 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM6 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT.
           EXIT PARAGRAPH.

       VALIDATE-INPUT.
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-QUOTE
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-DQUOTE
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-BSLASH
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-SEMI
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-TICK.
           EXIT PARAGRAPH.

        COPY "common_trim.cpy".
        COPY "common_validate.cpy".



       ALLOW-ADMIN.
           MOVE 0 TO WS-ALLOWED
           MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P6-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
               MOVE 1 TO WS-ALLOWED
           END-IF
           IF WS-ALLOWED NOT = 1
               MOVE WS-P6-TRIMMED TO WS-DENIED-ACTOR
               MOVE "PAYMENT_HOLD_CORE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       AUDIT.
           MOVE "INSERT INTO payment_hold_audit (action, actor_email, hold_id, detail) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-HOLD-ID TO WS-BIND-3
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
           MOVE SPACES TO WS-HOLD-ID
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT.
           EXIT PARAGRAPH.

        COPY "common_result.cpy".

       ACTION-RESERVE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT account_id FROM accounts WHERE account_id = ? LIMIT 1" TO WS-PREP-SQL
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
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO payment_hold (account_id, amount, currency, expires_at, created_by) VALUES (?, ?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-P6-TRIMMED TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|PHL_RESERVED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE WS-RESULT TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-CAPTURE.
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
           MOVE "UPDATE payment_hold SET status = 'CAPTURED', captured_at = NOW() WHERE id = ? AND status = 'ACTIVE'" TO WS-PREP-SQL
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
               MOVE "SUCCESS|PHL_CAPTURED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RELEASE.
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
           MOVE "UPDATE payment_hold SET status = 'RELEASED', released_at = NOW() WHERE id = ? AND status = 'ACTIVE'" TO WS-PREP-SQL
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
               MOVE "SUCCESS|PHL_RELEASED" TO LS-OUTPUT-BUFFER
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
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM4 NOT = SPACES
               MOVE WS-P4-TRIMMED(1:WS-P4-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CONCAT(id, ':', account_id, ':', amount, ':', currency, ':', status, ':', COALESCE(expires_at, '')) FROM payment_hold WHERE (? = '' OR account_id = ?) AND (? = '' OR status = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           MOVE WS-P2-TRIMMED TO WS-BIND-4
           MOVE WS-LIMIT TO WS-BIND-5
           MOVE WS-OFFSET TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|PHL_HOLDS|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|PHL_HOLDS|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-GET.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(id, '|', account_id, '|', amount, '|', currency, '|', status, '|', COALESCE(expires_at, ''), '|', COALESCE(captured_at, ''), '|', COALESCE(released_at, ''), '|', created_by) FROM payment_hold WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           STRING "SUCCESS|PHL_HOLD|" DELIMITED BY SIZE WS-RESULT(1:400) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-EXPIRE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE payment_hold SET status = 'EXPIRED' WHERE status = 'ACTIVE' AND expires_at IS NOT NULL AND expires_at < NOW()" TO WS-PREP-SQL
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
               MOVE "SUCCESS|PHL_EXPIRED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-SUMMARY.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'ACTIVE'), 0), '|', COALESCE(SUM(status = 'CAPTURED'), 0), '|', COALESCE(SUM(status = 'RELEASED'), 0), '|', COALESCE(SUM(status = 'EXPIRED'), 0)) FROM payment_hold" TO WS-PREP-SQL
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
           STRING "SUCCESS|PHL_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:200) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.
