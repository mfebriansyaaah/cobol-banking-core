       IDENTIFICATION DIVISION.
       PROGRAM-ID. loan_schedule_report_core.
      *> Real SQL-backed module for loan_schedule domain.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PRINCIPAL          PIC 9(12)V99 VALUE 0.
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
       01  WS-AUDIT-LOAN           PIC X(20) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       COPY "loan_schedule_ws_common.cpy".

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
               WHEN LS-CMD-ACTION(1:11) = "LSC_SUMMARY"
                   PERFORM ACTION-LSC_SUMMARY
               WHEN LS-CMD-ACTION(1:10) = "LSC_EXPORT"
                   PERFORM ACTION-LSC_EXPORT
               WHEN LS-CMD-ACTION(1:9) = "LSC_AUDIT"
                   PERFORM ACTION-LSC_AUDIT
                   WHEN OTHER
                       MOVE "ERROR|INVALID_ACTION" TO WS-RESULT
           END-EVALUATE
           MOVE WS-RESULT TO LS-OUTPUT-BUFFER
           GOBACK.

        COPY "common_trim.cpy".
        COPY "common_result.cpy".

       ACTION-LSC_SUMMARY.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(CASE WHEN status='ACTIVE' THEN 1 ELSE 0 END),0)) FROM loan_schedule" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|LSC_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:60) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-LSC_EXPORT.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(id, ':', loan_id, ':', status) FROM loan_schedule ORDER BY id DESC LIMIT 50" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|LSC_EXPORT|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|LSC_EXPORT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_AUDIT.
           MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED = SPACES
               MOVE "SELECT CONCAT(id, '|', action, '|', actor_email, '|', COALESCE(detail, '')) FROM loan_schedule_audit ORDER BY id DESC LIMIT 50" TO WS-PREP-SQL
           ELSE
               MOVE "SELECT CONCAT(id, '|', action, '|', actor_email, '|', COALESCE(detail, '')) FROM loan_schedule_audit WHERE schedule_id = ? ORDER BY id DESC LIMIT 50" TO WS-PREP-SQL
           END-IF
           IF WS-P1-TRIMMED NOT = SPACES
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|LSC_AUDIT|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|LSC_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
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

