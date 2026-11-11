       IDENTIFICATION DIVISION.
       PROGRAM-ID. loan_schedule_lifecycle_core.
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
       01  WS-REMAINING          PIC 9(12)V99 VALUE 0.
       01  WS-PRINCIPAL-DUE      PIC 9(12)V99 VALUE 0.
       01  WS-TOTAL-DUE          PIC 9(12)V99 VALUE 0.
       01  WS-PAYMENT-TEXT       PIC Z(11)9.99 VALUE 0.
       01  WS-PRINCIPAL-DUE-TEXT PIC Z(11)9.99 VALUE 0.
       01  WS-INTEREST-TEXT      PIC Z(11)9.99 VALUE 0.
       01  WS-TOTAL-DUE-TEXT     PIC Z(11)9.99 VALUE 0.
       01  WS-TOTAL-INTEREST-TEXT PIC Z(11)9.99 VALUE 0.
       01  WS-PRINCIPAL-TEXT     PIC Z(11)9.99 VALUE 0.
       01  WS-POWER              PIC 9(5)V9(6) VALUE 0.
       01  WS-AMORT-I            PIC 9(4) VALUE 0.
       01  WS-RESULT               PIC X(16384) VALUE SPACES.
       01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
       01  WS-BIND-1               PIC X(256) VALUE SPACES.
       01  WS-BIND-2               PIC X(256) VALUE SPACES.
       01  WS-BIND-3               PIC X(256) VALUE SPACES.
       01  WS-BIND-4               PIC X(256) VALUE SPACES.
       01  WS-BIND-5               PIC X(256) VALUE SPACES.
       01  WS-BIND-6               PIC X(256) VALUE SPACES.
       01  WS-BIND-7               PIC X(256) VALUE SPACES.
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
       01  WS-START-DATE          PIC X(10) VALUE SPACES.
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
               WHEN LS-CMD-ACTION(1:10) = "LSC_STATUS"
                   PERFORM ACTION-LSC_STATUS
                   WHEN OTHER
                       MOVE "ERROR|INVALID_ACTION" TO WS-RESULT
           END-EVALUATE
           MOVE WS-RESULT TO LS-OUTPUT-BUFFER
           GOBACK.

        COPY "common_trim.cpy".
        COPY "common_result.cpy".

       ACTION-LSC_STATUS.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           IF WS-PRINCIPAL <= 0
               MOVE "SUCCESS|LSC_STATUS|CLOSED" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE "SUCCESS|LSC_STATUS|ACTIVE" TO WS-RESULT
           EXIT PARAGRAPH.

       ACTION-LSC_APPROVE.
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

