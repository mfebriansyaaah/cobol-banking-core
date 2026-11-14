       IDENTIFICATION DIVISION.
       PROGRAM-ID. loan_schedule_core.
      *> Real SQL-backed module for loan_schedule domain.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PRINCIPAL          PIC 9(12)V99 VALUE 0.
       01  WS-RATE               PIC 9(3)V9(6) VALUE 0.
       01  WS-TERM               PIC 9(4) VALUE 0.
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
       01  WS-RLEN                 PIC 9(5) VALUE 1.
       01  WS-BAD                  PIC 9(3) VALUE 0.
       01  WS-ALLOWED              PIC 9 VALUE 0.
       01  WS-SCHEDULE-ID          PIC X(20) VALUE SPACES.
       01  WS-AUDIT-LOAN           PIC X(20) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  F-QUOTE                 PIC X VALUE "'".
       01  F-DQUOTE                PIC X VALUE '"'.
       01  F-BSLASH                PIC X VALUE "\".
       01  F-TICK                  PIC X VALUE "`".
       01  F-SEMI                  PIC X VALUE ";".
       01  WS-P1                   PIC X(100) VALUE SPACES.
       01  WS-P2                   PIC X(100) VALUE SPACES.
       01  WS-P3                   PIC X(100) VALUE SPACES.
       01  WS-P4                   PIC X(100) VALUE SPACES.
       01  WS-P5                   PIC X(100) VALUE SPACES.
       01  WS-P6                   PIC X(100) VALUE SPACES.
       01  WS-I                    PIC 9(3) VALUE 1.
       01  WS-J                    PIC 9(5) VALUE 1.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-FLAG                 PIC X VALUE 'N'.
           88  FLAG-YES             VALUE 'Y'.
           88  FLAG-NO              VALUE 'N'.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.

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
           MOVE SPACES TO WS-RESULT
           MOVE LS-PARAM1 TO WS-P1
           MOVE LS-PARAM2 TO WS-P2
           MOVE LS-PARAM3 TO WS-P3
           MOVE LS-PARAM4 TO WS-P4
           MOVE LS-PARAM5 TO WS-P5
           MOVE LS-PARAM6 TO WS-P6
           PERFORM TRIM-ALL
           PERFORM VALIDATE-ALL
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               MOVE WS-RESULT TO LS-OUTPUT-BUFFER
               GOBACK
           END-IF
           EVALUATE TRUE
               WHEN LS-CMD-ACTION(1:10) = "LSC_CREATE"
                   PERFORM ACTION-LSC_CREATE
               WHEN LS-CMD-ACTION(1:7) = "LSC_GET"
                   PERFORM ACTION-LSC_GET
               WHEN LS-CMD-ACTION(1:8) = "LSC_LIST"
                   PERFORM ACTION-LSC_LIST
               WHEN LS-CMD-ACTION(1:10) = "LSC_DETAIL"
                   PERFORM ACTION-LSC_DETAIL
               WHEN LS-CMD-ACTION(1:10) = "LSC_UPDATE"
                   PERFORM ACTION-LSC_UPDATE
               WHEN LS-CMD-ACTION(1:10) = "LSC_DELETE"
                   PERFORM ACTION-LSC_DELETE
               WHEN LS-CMD-ACTION(1:10) = "LSC_SEARCH"
                   PERFORM ACTION-LSC_SEARCH
               WHEN LS-CMD-ACTION(1:11) = "LSC_HISTORY"
                   PERFORM ACTION-LSC_HISTORY
               WHEN LS-CMD-ACTION(1:12) = "LSC_VALIDATE"
                   PERFORM ACTION-LSC_VALIDATE
                   WHEN OTHER
                       MOVE "ERROR|INVALID_ACTION" TO WS-RESULT
           END-EVALUATE
           MOVE WS-RESULT TO LS-OUTPUT-BUFFER
           GOBACK.

        COPY "common_trim.cpy".
        COPY "common_sql.cpy".
        COPY "common_result.cpy".

       ACTION-LSC_CREATE.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED = SPACES OR WS-P2-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO loan_schedule (loan_id, term_months, interest_rate, start_date, status, created_by) VALUES (?, ?, ?, ?, 'DRAFT', ?)" TO WS-PREP-SQL
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
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-SCHEDULE-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "CREATE" TO WS-AUDIT-ACTION
               MOVE WS-SCHEDULE-ID TO WS-AUDIT-LOAN
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO WS-RESULT
               STRING "SUCCESS|LSC_CREATE|" DELIMITED BY SIZE WS-SCHEDULE-ID DELIMITED BY SIZE INTO WS-RESULT END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_GET.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(id, '|', loan_id, '|', term_months, '|', interest_rate, '|', start_date, '|', status, '|', version) FROM loan_schedule WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|LSC_GET|" DELIMITED BY SIZE WS-RESULT(1:200) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-LSC_LIST.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF WS-P2-TRIMMED NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF
           IF WS-P3-TRIMMED NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CONCAT(id, ':', loan_id, ':', status) FROM loan_schedule WHERE (? = '' OR loan_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               MOVE "SUCCESS|LSC_LIST|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|LSC_LIST|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           MOVE LS-OUTPUT-BUFFER TO WS-RESULT
           EXIT PARAGRAPH.

       ACTION-LSC_DETAIL.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(s.id, '|', s.loan_id, '|', s.term_months, '|', s.interest_rate, '|', s.start_date, '|', s.status, '|', (SELECT COUNT(*) FROM loan_installment i WHERE i.schedule_id = s.id)) FROM loan_schedule s WHERE s.id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|LSC_DETAIL|" DELIMITED BY SIZE WS-RESULT(1:240) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           MOVE LS-OUTPUT-BUFFER TO WS-RESULT.
           EXIT PARAGRAPH.

       ACTION-LSC_UPDATE.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE loan_schedule SET term_months = COALESCE(NULLIF(?, ''), term_months), interest_rate = COALESCE(NULLIF(?, ''), interest_rate), start_date = COALESCE(NULLIF(?, ''), start_date), version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P1-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|LSC_UPDATE|OK" TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_DELETE.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE loan_schedule SET status = 'CANCELLED', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "DELETE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE "soft delete" TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|LSC_DELETE|DELETED" TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_SEARCH.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "SELECT CONCAT(id, ':', loan_id, ':', status) FROM loan_schedule WHERE (? = '' OR CAST(loan_id AS CHAR) LIKE CONCAT('%', ?, '%')) ORDER BY id DESC LIMIT ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|LSC_SEARCH|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|LSC_SEARCH|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           MOVE LS-OUTPUT-BUFFER TO WS-RESULT
           EXIT PARAGRAPH.

       ACTION-LSC_HISTORY.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(id, '|', action, '|', actor_email, '|', COALESCE(detail, '')) FROM loan_schedule_audit WHERE schedule_id = ? ORDER BY id DESC LIMIT 50" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|LSC_HISTORY|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|LSC_HISTORY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           MOVE LS-OUTPUT-BUFFER TO WS-RESULT
           EXIT PARAGRAPH.

       ACTION-LSC_VALIDATE.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           MOVE FUNCTION NUMVAL(WS-P2) TO WS-RATE
           MOVE FUNCTION NUMVAL(WS-P3) TO WS-TERM
           IF WS-PRINCIPAL <= 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           IF WS-TERM = 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           IF WS-RATE = 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE "SUCCESS|LSC_VALIDATE|OK" TO WS-RESULT
           EXIT PARAGRAPH.

        COPY "common_validate_all.cpy".


        COPY "common_auth.cpy".

       AUDIT.
           MOVE "INSERT INTO loan_schedule_audit (schedule_id, action, actor_email, detail) VALUES (NULLIF(?, ''), ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-LOAN TO WS-BIND-1
           MOVE WS-AUDIT-ACTION TO WS-BIND-2
           MOVE WS-P6-TRIMMED TO WS-BIND-3
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
           MOVE SPACES TO WS-AUDIT-LOAN
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT.
           EXIT PARAGRAPH.

