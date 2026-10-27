       IDENTIFICATION DIVISION.
       PROGRAM-ID. loan_schedule_core.
      *> Real SQL-backed module for loan_schedule domain.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-VAR-01           PIC X(100) VALUE SPACES.
       01  WS-VAR-02           PIC X(100) VALUE SPACES.
       01  WS-VAR-03           PIC X(100) VALUE SPACES.
       01  WS-VAR-04           PIC X(100) VALUE SPACES.
       01  WS-VAR-05           PIC X(100) VALUE SPACES.
       01  WS-VAR-06           PIC X(100) VALUE SPACES.
       01  WS-VAR-07           PIC X(100) VALUE SPACES.
       01  WS-VAR-08           PIC X(100) VALUE SPACES.
       01  WS-VAR-09           PIC X(100) VALUE SPACES.
       01  WS-VAR-10           PIC X(100) VALUE SPACES.
       01  WS-VAR-11           PIC X(100) VALUE SPACES.
       01  WS-VAR-12           PIC X(100) VALUE SPACES.
       01  WS-VAR-13           PIC X(100) VALUE SPACES.
       01  WS-VAR-14           PIC X(100) VALUE SPACES.
       01  WS-VAR-15           PIC X(100) VALUE SPACES.
       01  WS-VAR-16           PIC X(100) VALUE SPACES.
       01  WS-VAR-17           PIC X(100) VALUE SPACES.
       01  WS-VAR-18           PIC X(100) VALUE SPACES.
       01  WS-VAR-19           PIC X(100) VALUE SPACES.
       01  WS-VAR-20           PIC X(100) VALUE SPACES.
       01  WS-VAR-21           PIC X(100) VALUE SPACES.
       01  WS-VAR-22           PIC X(100) VALUE SPACES.
       01  WS-VAR-23           PIC X(100) VALUE SPACES.
       01  WS-VAR-24           PIC X(100) VALUE SPACES.
       01  WS-VAR-25           PIC X(100) VALUE SPACES.
       01  WS-VAR-26           PIC X(100) VALUE SPACES.
       01  WS-VAR-27           PIC X(100) VALUE SPACES.
       01  WS-VAR-28           PIC X(100) VALUE SPACES.
       01  WS-VAR-29           PIC X(100) VALUE SPACES.
       01  WS-VAR-30           PIC X(100) VALUE SPACES.
       01  WS-VAR-31           PIC X(100) VALUE SPACES.
       01  WS-VAR-32           PIC X(100) VALUE SPACES.
       01  WS-VAR-33           PIC X(100) VALUE SPACES.
       01  WS-VAR-34           PIC X(100) VALUE SPACES.
       01  WS-VAR-35           PIC X(100) VALUE SPACES.
       01  WS-VAR-36           PIC X(100) VALUE SPACES.
       01  WS-VAR-37           PIC X(100) VALUE SPACES.
       01  WS-VAR-38           PIC X(100) VALUE SPACES.
       01  WS-VAR-39           PIC X(100) VALUE SPACES.
       01  WS-VAR-40           PIC X(100) VALUE SPACES.
       01  WS-PRINCIPAL          PIC 9(12)V99 VALUE 0.
       01  WS-RATE               PIC 9(3)V9(6) VALUE 0.
       01  WS-TERM               PIC 9(4) VALUE 0.
       01  WS-MONTHLY-RATE       PIC 9(3)V9(6) VALUE 0.
       01  WS-PAYMENT            PIC 9(12)V99 VALUE 0.
       01  WS-TOTAL-INTEREST     PIC 9(12)V99 VALUE 0.
       01  WS-PAYMENT-TEXT      PIC Z(12).ZZ VALUE 0.
       01  WS-POWER              PIC 9(5)V9(6) VALUE 0.
       01  WS-AMORT-I            PIC 9(4) VALUE 0.
       01  WS-RESULT               PIC X(16384) VALUE SPACES.
       01  WS-PREP-SQL             PIC X(2048) VALUE SPACES.
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
       01  WS-LOAN-ID              PIC X(20) VALUE SPACES.
       01  WS-SCHEDULE-ID          PIC X(20) VALUE SPACES.
       01  WS-TMP-TERM            PIC X(10) VALUE SPACES.
       01  WS-TMP-RATE            PIC X(10) VALUE SPACES.
       01  WS-LOAN-PRINCIPAL      PIC 9(12)V99 VALUE 0.
       01  WS-DAYS                PIC 9(4) VALUE 0.
       01  WS-INTEREST            PIC 9(12)V99 VALUE 0.
       01  WS-INSTALLMENT-COUNT   PIC 9(4) VALUE 0.
       01  WS-PAYMENT-STR         PIC X(20) VALUE SPACES.
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
       01  WS-K                    PIC 9(5) VALUE 1.
       01  WS-L                    PIC 9(5) VALUE 1.
       01  WS-M                    PIC 9(5) VALUE 1.
       01  WS-N                    PIC 9(5) VALUE 1.
       01  WS-O                    PIC 9(5) VALUE 1.
       01  WS-P                    PIC 9(5) VALUE 1.
       01  WS-Q                    PIC 9(5) VALUE 1.
       01  WS-R                    PIC 9(5) VALUE 1.
       01  WS-S                    PIC 9(5) VALUE 1.
       01  WS-T                    PIC 9(5) VALUE 1.
       01  WS-U                    PIC 9(5) VALUE 1.
       01  WS-V                    PIC 9(5) VALUE 1.
       01  WS-W                    PIC 9(5) VALUE 1.
       01  WS-X                    PIC 9(5) VALUE 1.
       01  WS-Y                    PIC 9(5) VALUE 1.
       01  WS-Z                    PIC 9(5) VALUE 1.
       01  WS-STATUS               PIC X(20) VALUE SPACES.
       01  WS-CODE                 PIC X(20) VALUE SPACES.
       01  WS-MESSAGE              PIC X(100) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-ACTOR                PIC X(100) VALUE SPACES.
       01  WS-TARGET               PIC X(100) VALUE SPACES.
       01  WS-AMOUNT               PIC X(20) VALUE SPACES.
       01  WS-CURRENCY             PIC X(3) VALUE SPACES.
       01  WS-DATE-VALUE           PIC X(10) VALUE SPACES.
       01  WS-ID-VALUE             PIC X(20) VALUE SPACES.
       01  WS-LIMIT-VALUE          PIC X(10) VALUE SPACES.
       01  WS-OFFSET-VALUE         PIC X(10) VALUE SPACES.
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
               WHEN LS-CMD-ACTION(1:8) = "LSC_CALC"
                   PERFORM ACTION-LSC_CALC
               WHEN LS-CMD-ACTION(1:13) = "LSC_SCHEDULED"
                   PERFORM ACTION-LSC_SCHEDULED
               WHEN LS-CMD-ACTION(1:12) = "LSC_FORECAST"
                   PERFORM ACTION-LSC_FORECAST
               WHEN LS-CMD-ACTION(1:12) = "LSC_OVERRIDE"
                   PERFORM ACTION-LSC_OVERRIDE
               WHEN LS-CMD-ACTION(1:12) = "LSC_VALIDATE"
                   PERFORM ACTION-LSC_VALIDATE
               WHEN LS-CMD-ACTION(1:10) = "LSC_ADJUST"
                   PERFORM ACTION-LSC_ADJUST
               WHEN LS-CMD-ACTION(1:10) = "LSC_STATUS"
                   PERFORM ACTION-LSC_STATUS
               WHEN LS-CMD-ACTION(1:11) = "LSC_APPROVE"
                   PERFORM ACTION-LSC_APPROVE
               WHEN LS-CMD-ACTION(1:10) = "LSC_REJECT"
                   PERFORM ACTION-LSC_REJECT
               WHEN LS-CMD-ACTION(1:9) = "LSC_CLOSE"
                   PERFORM ACTION-LSC_CLOSE
               WHEN LS-CMD-ACTION(1:10) = "LSC_REOPEN"
                   PERFORM ACTION-LSC_REOPEN
               WHEN LS-CMD-ACTION(1:10) = "LSC_CANCEL"
                   PERFORM ACTION-LSC_CANCEL
               WHEN LS-CMD-ACTION(1:8) = "LSC_HOLD"
                   PERFORM ACTION-LSC_HOLD
               WHEN LS-CMD-ACTION(1:11) = "LSC_RELEASE"
                   PERFORM ACTION-LSC_RELEASE
               WHEN LS-CMD-ACTION(1:8) = "LSC_POST"
                   PERFORM ACTION-LSC_POST
               WHEN LS-CMD-ACTION(1:10) = "LSC_ACCRUE"
                   PERFORM ACTION-LSC_ACCRUE
               WHEN LS-CMD-ACTION(1:10) = "LSC_SETTLE"
                   PERFORM ACTION-LSC_SETTLE
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

       ACTION-LSC_CREATE.
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
               MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
           EXIT PARAGRAPH.

       ACTION-LSC_DETAIL.
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
           STRING "SUCCESS|LSC_DETAIL|" DELIMITED BY SIZE WS-RESULT(1:240) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-LSC_UPDATE.
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
           EXIT PARAGRAPH.

       ACTION-LSC_HISTORY.
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
           EXIT PARAGRAPH.

       ACTION-LSC_CALC.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           MOVE FUNCTION NUMVAL(WS-P2) TO WS-RATE
           MOVE FUNCTION NUMVAL(WS-P3) TO WS-TERM
           IF WS-TERM = 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           IF WS-RATE = 0
               COMPUTE WS-PAYMENT = WS-PRINCIPAL / WS-TERM END-COMPUTE
           ELSE
               COMPUTE WS-MONTHLY-RATE = WS-RATE / 1200 END-COMPUTE
               MOVE 1 TO WS-POWER
               PERFORM VARYING WS-AMORT-I FROM 1 BY 1 UNTIL WS-AMORT-I > WS-TERM
                   COMPUTE WS-POWER = WS-POWER * (1 + WS-MONTHLY-RATE) END-COMPUTE
               END-PERFORM
               COMPUTE WS-MONTHLY-RATE = WS-RATE / 1200 END-COMPUTE
               MOVE 1 TO WS-POWER
               PERFORM VARYING WS-AMORT-I FROM 1 BY 1 UNTIL WS-AMORT-I > WS-TERM
                   COMPUTE WS-POWER = WS-POWER * (1 + WS-MONTHLY-RATE) END-COMPUTE
               END-PERFORM
               COMPUTE WS-PAYMENT = WS-PRINCIPAL * WS-MONTHLY-RATE * WS-POWER / (WS-POWER - 1) END-COMPUTE
           END-IF
           MOVE WS-PAYMENT TO WS-PAYMENT-TEXT
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_CALC|" DELIMITED BY SIZE
                  WS-PAYMENT DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING
           EXIT PARAGRAPH.

       ACTION-LSC_SCHEDULED.
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
           MOVE "SELECT CONCAT(term_months, '|', interest_rate, '|', loan_id) FROM loan_schedule WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               PERFORM ACTION-LSC_CALC
               IF WS-RESULT(1:5) = "ERROR"
                   EXIT PARAGRAPH
               END-IF
               COMPUTE WS-TOTAL-INTEREST = WS-PAYMENT * WS-TERM - WS-PRINCIPAL END-COMPUTE
               MOVE SPACES TO WS-RESULT
               STRING "SUCCESS|LSC_SCHEDULED|" DELIMITED BY SIZE
                      WS-PAYMENT DELIMITED BY SIZE "|" DELIMITED BY SIZE
                      WS-TOTAL-INTEREST DELIMITED BY SIZE
                      INTO WS-RESULT
               END-STRING
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-TMP-TERM
           MOVE SPACES TO WS-TMP-RATE
           MOVE SPACES TO WS-LOAN-ID
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-TERM WS-TMP-RATE WS-LOAN-ID END-UNSTRING
           MOVE FUNCTION NUMVAL(WS-TMP-TERM) TO WS-TERM
           MOVE FUNCTION NUMVAL(WS-TMP-RATE) TO WS-RATE
           IF WS-TERM = 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE "SELECT principal FROM loan_application WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-LOAN-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE FUNCTION NUMVAL(WS-RESULT) TO WS-LOAN-PRINCIPAL
           MOVE WS-LOAN-PRINCIPAL TO WS-PRINCIPAL
           IF WS-RATE = 0
               COMPUTE WS-PAYMENT = WS-PRINCIPAL / WS-TERM END-COMPUTE
           ELSE
               COMPUTE WS-MONTHLY-RATE = WS-RATE / 1200 END-COMPUTE
               MOVE 1 TO WS-POWER
               PERFORM VARYING WS-AMORT-I FROM 1 BY 1 UNTIL WS-AMORT-I > WS-TERM
                   COMPUTE WS-POWER = WS-POWER * (1 + WS-MONTHLY-RATE) END-COMPUTE
               END-PERFORM
               COMPUTE WS-PAYMENT = WS-PRINCIPAL * WS-MONTHLY-RATE * WS-POWER / (WS-POWER - 1) END-COMPUTE
           END-IF
           COMPUTE WS-TOTAL-INTEREST = WS-PAYMENT * WS-TERM - WS-PRINCIPAL END-COMPUTE
           CALL "SQL_BEGIN" END-CALL
           MOVE "DELETE FROM loan_installment WHERE schedule_id = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               MOVE WS-TERM TO WS-BIND-1
               MOVE WS-P1-TRIMMED TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               MOVE SPACES TO WS-PAYMENT-STR
               STRING WS-PAYMENT DELIMITED BY SIZE INTO WS-PAYMENT-STR END-STRING
               MOVE WS-PAYMENT-STR TO WS-BIND-4
               MOVE SPACES TO WS-PAYMENT-STR
               STRING WS-PAYMENT DELIMITED BY SIZE INTO WS-PAYMENT-STR END-STRING
               MOVE WS-PAYMENT-STR TO WS-BIND-5
               STRING "INSERT INTO loan_installment (schedule_id, seq, due_date, principal_due, interest_due, total_due) "
                      "WITH RECURSIVE cte (n) AS (SELECT 1 UNION ALL SELECT n+1 FROM cte WHERE n < ?) "
                      "SELECT ?, n, DATE_ADD((SELECT start_date FROM loan_schedule WHERE id = ?), INTERVAL n MONTH), ?, 0, ? "
                      "FROM cte" DELIMITED BY SIZE INTO WS-PREP-SQL
               END-STRING
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF
           IF STEP-OK
               MOVE "UPDATE loan_schedule SET status = 'ACTIVE' WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF
           IF STEP-OK
               MOVE "SCHEDULED" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO WS-RESULT
               STRING "SUCCESS|LSC_SCHEDULED|" DELIMITED BY SIZE
                      WS-P1-TRIMMED DELIMITED BY SIZE "|" DELIMITED BY SIZE
                      WS-PAYMENT DELIMITED BY SIZE "|" DELIMITED BY SIZE
                      WS-TOTAL-INTEREST DELIMITED BY SIZE
                      INTO WS-RESULT
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_FORECAST.
           PERFORM ACTION-LSC_CALC
           IF WS-RESULT(1:5) = "ERROR"
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-TOTAL-INTEREST = WS-PAYMENT * WS-TERM - WS-PRINCIPAL END-COMPUTE
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_FORECAST|" DELIMITED BY SIZE
                  WS-PAYMENT DELIMITED BY SIZE "|" DELIMITED BY SIZE
                  WS-TOTAL-INTEREST DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING
           EXIT PARAGRAPH.

       ACTION-LSC_OVERRIDE.
           MOVE WS-P4 TO WS-P2
           PERFORM ACTION-LSC_CALC
           IF WS-RESULT(1:5) = "ERROR"
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_OVERRIDE|" DELIMITED BY SIZE
                  WS-PAYMENT DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING
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

       ACTION-LSC_ADJUST.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           MOVE FUNCTION NUMVAL(WS-P2) TO WS-TOTAL-INTEREST
           COMPUTE WS-PRINCIPAL = WS-PRINCIPAL + WS-TOTAL-INTEREST END-COMPUTE
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_ADJUST|" DELIMITED BY SIZE
                  WS-PRINCIPAL DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING
           EXIT PARAGRAPH.

       ACTION-LSC_STATUS.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           IF WS-PRINCIPAL <= 0
               MOVE "SUCCESS|LSC_STATUS|CLOSED" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE "SUCCESS|LSC_STATUS|ACTIVE" TO WS-RESULT
           EXIT PARAGRAPH.

       ACTION-LSC_APPROVE.
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
           MOVE "UPDATE loan_schedule SET status = 'ACTIVE', version = version + 1 WHERE id = ? AND status IN ('DRAFT','ON_HOLD')" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               MOVE "APPROVE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|LSC_APPROVE|OK" TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_REJECT.
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
           END-IF
           IF STEP-OK
               MOVE "REJECT" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|LSC_REJECT|OK" TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_CLOSE.
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
           MOVE "UPDATE loan_schedule SET status = 'CLOSED', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               MOVE "CLOSE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|LSC_CLOSE|OK" TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_REOPEN.
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
           MOVE "UPDATE loan_schedule SET status = 'ACTIVE', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               MOVE "REOPEN" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|LSC_REOPEN|OK" TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_CANCEL.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           IF WS-PRINCIPAL <= 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE "SUCCESS|LSC_CANCEL|CANCELLED" TO WS-RESULT
           EXIT PARAGRAPH.

       ACTION-LSC_HOLD.
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
           MOVE "UPDATE loan_schedule SET status = 'ON_HOLD', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               MOVE "HOLD" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|LSC_HOLD|OK" TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_RELEASE.
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
           MOVE "UPDATE loan_schedule SET status = 'ACTIVE', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               MOVE "RELEASE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|LSC_RELEASE|OK" TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_POST.
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
           MOVE "UPDATE loan_installment SET status = 'PAID', paid_amount = ?, paid_at = NOW() WHERE schedule_id = ? AND seq = ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               MOVE "POST" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|LSC_POST|OK" TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_ACCRUE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE 30 TO WS-DAYS
           IF WS-P2-TRIMMED NOT = SPACES
               MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-DAYS
               IF WS-DAYS = 0
                   MOVE 30 TO WS-DAYS
               END-IF
           END-IF
           MOVE "SELECT loan_id FROM loan_schedule WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE FUNCTION NUMVAL(WS-P1) TO WS-LOAN-PRINCIPAL
               MOVE FUNCTION NUMVAL(WS-P2) TO WS-RATE
               IF WS-DAYS = 30 AND WS-P3-TRIMMED NOT = SPACES
                   MOVE FUNCTION NUMVAL(WS-P3-TRIMMED) TO WS-DAYS
                   IF WS-DAYS = 0
                       MOVE 30 TO WS-DAYS
                   END-IF
               END-IF
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO WS-RESULT
                   EXIT PARAGRAPH
               END-IF
               MOVE "SELECT CONCAT(a.principal, '|', s.interest_rate) FROM loan_application a JOIN loan_schedule s ON s.loan_id = a.id WHERE s.id = ? LIMIT 1" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO WS-RESULT
                   EXIT PARAGRAPH
               END-IF
               MOVE SPACES TO WS-TMP-TERM
               MOVE SPACES TO WS-TMP-RATE
               UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-TERM WS-TMP-RATE END-UNSTRING
               MOVE FUNCTION NUMVAL(WS-TMP-TERM) TO WS-LOAN-PRINCIPAL
               MOVE FUNCTION NUMVAL(WS-TMP-RATE) TO WS-RATE
           END-IF
           IF WS-LOAN-PRINCIPAL <= 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-INTEREST = WS-LOAN-PRINCIPAL * WS-RATE * WS-DAYS / 36500 END-COMPUTE
           COMPUTE WS-PAYMENT = WS-LOAN-PRINCIPAL + WS-INTEREST END-COMPUTE
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_ACCRUE|" DELIMITED BY SIZE
                  WS-PAYMENT DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING.
           EXIT PARAGRAPH.

       ACTION-LSC_SETTLE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT loan_id FROM loan_schedule WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE FUNCTION NUMVAL(WS-P1) TO WS-LOAN-PRINCIPAL
               MOVE FUNCTION NUMVAL(WS-P2) TO WS-RATE
               COMPUTE WS-INTEREST = WS-LOAN-PRINCIPAL * WS-RATE * 30 / 36500 END-COMPUTE
               COMPUTE WS-PAYMENT = WS-LOAN-PRINCIPAL + WS-INTEREST END-COMPUTE
               MOVE SPACES TO WS-RESULT
               STRING "SUCCESS|LSC_SETTLE|" DELIMITED BY SIZE WS-PAYMENT DELIMITED BY SIZE INTO WS-RESULT END-STRING
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(a.principal, '|', s.interest_rate) FROM loan_application a JOIN loan_schedule s ON s.loan_id = a.id WHERE s.id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-TMP-TERM
           MOVE SPACES TO WS-TMP-RATE
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-TERM WS-TMP-RATE END-UNSTRING
           MOVE FUNCTION NUMVAL(WS-TMP-TERM) TO WS-LOAN-PRINCIPAL
           MOVE FUNCTION NUMVAL(WS-TMP-RATE) TO WS-RATE
           COMPUTE WS-INTEREST = WS-LOAN-PRINCIPAL * WS-RATE * 30 / 36500 END-COMPUTE
           COMPUTE WS-PAYMENT = WS-LOAN-PRINCIPAL + WS-INTEREST END-COMPUTE
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE loan_schedule SET status = 'CLOSED', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               MOVE "SETTLE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOAN
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO WS-RESULT
               STRING "SUCCESS|LSC_SETTLE|" DELIMITED BY SIZE WS-PAYMENT DELIMITED BY SIZE INTO WS-RESULT END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LSC_SUMMARY.
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

       TRIM-ALL.
           MOVE LS-PARAM1 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P1-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P1-LEN
           MOVE LS-PARAM2 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P2-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P2-LEN
           MOVE LS-PARAM3 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P3-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P3-LEN
           MOVE LS-PARAM4 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P4-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P4-LEN
           MOVE LS-PARAM5 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P5-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P5-LEN
           MOVE LS-PARAM6 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P6-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P6-LEN.
           EXIT PARAGRAPH.

       TRIM-VALUE.
           MOVE WS-TRIM-IN TO WS-TRIM-OUT
           MOVE 0 TO WS-TRIM-LEN
           PERFORM VARYING WS-I FROM 100 BY -1
               UNTIL WS-I < 1 OR WS-TRIM-LEN > 0
               IF WS-TRIM-OUT(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-TRIM-LEN
               END-IF
           END-PERFORM
           IF WS-TRIM-LEN = 0
               MOVE 1 TO WS-TRIM-LEN
           END-IF.
           EXIT PARAGRAPH.

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
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-TICK.
           EXIT PARAGRAPH.

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
               MOVE "LOAN_SCHEDULE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

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

       TRIM-RESULT-LEN.
           MOVE 0 TO WS-RLEN
           PERFORM VARYING WS-J FROM 16384 BY -1
               UNTIL WS-J < 1 OR WS-RLEN > 0
               IF WS-RESULT(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-RLEN
               END-IF
           END-PERFORM
           IF WS-RLEN = 0
               MOVE 1 TO WS-RLEN
           END-IF.
           EXIT PARAGRAPH.

       AUDIT-ACTION.
           MOVE LS-CMD-ACTION TO WS-AUDIT-ACTION
           EXIT PARAGRAPH.

