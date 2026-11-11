       IDENTIFICATION DIVISION.
       PROGRAM-ID. payment_instruction_core.
      *> Standing payment instructions and one-at-a-time execution.

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
       01  WS-TOTAL                PIC X(100) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-LOOKUP-BAD           PIC 9 VALUE 0.
       01  WS-CODE                 PIC X(40) VALUE SPACES.
       01  WS-FROM                 PIC X(100) VALUE SPACES.
       01  WS-TO                   PIC X(100) VALUE SPACES.
       01  WS-AMOUNT               PIC X(30) VALUE SPACES.
       01  WS-AMOUNT-NODOT         PIC X(30) VALUE SPACES.
       01  WS-DOT-COUNT            PIC 9(3) VALUE 0.
       01  WS-CURRENCY             PIC X(3) VALUE SPACES.
       01  WS-TARGET-CURRENCY      PIC X(3) VALUE SPACES.
       01  WS-FREQUENCY            PIC X(10) VALUE SPACES.
       01  WS-NEXT-DATE            PIC X(10) VALUE SPACES.
       01  WS-END-DATE             PIC X(10) VALUE SPACES.
       01  WS-STATUS               PIC X(20) VALUE SPACES.
       01  WS-SPEC-FIRST           PIC X(30) VALUE SPACES.
       01  WS-SPEC-SECOND          PIC X(30) VALUE SPACES.
       01  WS-SPEC-THIRD           PIC X(30) VALUE SPACES.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-DATE-IN              PIC X(100) VALUE SPACES.
       01  WS-DATE-LEN             PIC 9(3) VALUE 0.
       01  WS-AT-COUNT             PIC 9(3) VALUE 0.
       01  WS-IDEMPOTENCY          PIC X(50) VALUE SPACES.
       01  WS-CALL-ACTION          PIC X(30) VALUE SPACES.
       01  WS-CALL-P1              PIC X(100) VALUE SPACES.
       01  WS-CALL-P2              PIC X(100) VALUE SPACES.
       01  WS-CALL-P3              PIC X(100) VALUE SPACES.
       01  WS-CALL-P4              PIC X(100) VALUE SPACES.
       01  WS-CALL-P5              PIC X(100) VALUE SPACES.
       01  WS-CALL-P6              PIC X(100) VALUE SPACES.
       01  WS-CALL-OUT             PIC X(16384) VALUE SPACES.
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
               WHEN LS-CMD-ACTION(1:10) = "PIC_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CREATE
               WHEN LS-CMD-ACTION(1:8) = "PIC_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-LIST
               WHEN LS-CMD-ACTION(1:7) = "PIC_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-GET
               WHEN LS-CMD-ACTION(1:9) = "PIC_PAUSE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-PAUSE
               WHEN LS-CMD-ACTION(1:10) = "PIC_RESUME"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RESUME
               WHEN LS-CMD-ACTION(1:10) = "PIC_CANCEL"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CANCEL
               WHEN LS-CMD-ACTION(1:7) = "PIC_DUE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-DUE
               WHEN LS-CMD-ACTION(1:11) = "PIC_EXECUTE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-EXECUTE
               WHEN LS-CMD-ACTION(1:11) = "PIC_HISTORY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-HISTORY
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_validate_semi.cpy".
        COPY "common_validate.cpy".


        COPY "common_trim.cpy".



       VALIDATE-DATE-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-DATE-LEN
           PERFORM VARYING WS-I FROM 100 BY -1
               UNTIL WS-I < 1 OR WS-DATE-LEN > 0
               IF WS-DATE-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-DATE-LEN
               END-IF
           END-PERFORM
           IF WS-DATE-LEN NOT = 10
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-DATE-IN(5:1) NOT = "-" OR WS-DATE-IN(8:1) NOT = "-"
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-DATE-IN(1:4) IS NOT NUMERIC
              OR WS-DATE-IN(6:2) IS NOT NUMERIC
              OR WS-DATE-IN(9:2) IS NOT NUMERIC
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-EMAIL.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-AT-COUNT
           INSPECT WS-FROM TALLYING WS-AT-COUNT FOR ALL "@"
           IF WS-AT-COUNT NOT = 1 OR WS-FROM = SPACES
               MOVE 1 TO WS-BAD
           END-IF.
           MOVE 0 TO WS-AT-COUNT
           INSPECT WS-TO TALLYING WS-AT-COUNT FOR ALL "@"
           IF WS-AT-COUNT NOT = 1 OR WS-TO = SPACES
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

        COPY "common_auth.cpy".

       CHECK-INSTRUCTION.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-FROM WS-TO WS-AMOUNT WS-CURRENCY
               WS-FREQUENCY WS-NEXT-DATE WS-END-DATE WS-STATUS
           MOVE "SELECT CONCAT(from_email, '|', to_email, '|', TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM CAST(amount AS CHAR))), '|', currency_code, '|', frequency, '|', next_run_date, '|', COALESCE(end_date, ''), '|', status) FROM payment_instruction WHERE instruction_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE 1 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE 2 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-FROM WS-TO
               WS-AMOUNT WS-CURRENCY WS-FREQUENCY WS-NEXT-DATE
               WS-END-DATE WS-STATUS
           END-UNSTRING.
           EXIT PARAGRAPH.

       AUDIT.
           MOVE "INSERT INTO payment_audit (action, actor_email, user_email, currency_code, detail) VALUES (?, ?, NULLIF(?, ''), NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-FROM TO WS-BIND-3
           MOVE WS-CURRENCY TO WS-BIND-4
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

       AUDIT-DENIED.
           MOVE "AUTHZ_DENIED" TO WS-AUDIT-ACTION
           MOVE SPACES TO WS-FROM WS-CURRENCY
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT.
           EXIT PARAGRAPH.

        COPY "common_result.cpy".

       ACTION-CREATE.
           MOVE "PAYMENT_INSTRUCTION" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
              OR LS-PARAM5 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-FROM
           MOVE WS-P3-TRIMMED TO WS-TO
           PERFORM VALIDATE-EMAIL
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-AMOUNT WS-CURRENCY
           UNSTRING WS-P4-TRIMMED DELIMITED BY "," INTO WS-AMOUNT WS-CURRENCY
           END-UNSTRING
           MOVE WS-AMOUNT TO WS-AMOUNT-NODOT
           MOVE 0 TO WS-DOT-COUNT
           INSPECT WS-AMOUNT TALLYING WS-DOT-COUNT FOR ALL "."
           IF WS-DOT-COUNT > 1
               MOVE 1 TO WS-BAD
           END-IF
           INSPECT WS-AMOUNT-NODOT REPLACING ALL "." BY "0"
           MOVE WS-AMOUNT-NODOT TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) <= 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-CURRENCY(1:1) IS NOT ALPHABETIC OR
              WS-CURRENCY(2:1) IS NOT ALPHABETIC OR
              WS-CURRENCY(3:1) IS NOT ALPHABETIC
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-FREQUENCY WS-NEXT-DATE WS-END-DATE
           UNSTRING WS-P5-TRIMMED DELIMITED BY "," INTO WS-FREQUENCY
               WS-NEXT-DATE WS-END-DATE
           END-UNSTRING
           IF WS-FREQUENCY NOT = "ONCE" AND WS-FREQUENCY NOT = "DAILY"
              AND WS-FREQUENCY NOT = "WEEKLY" AND WS-FREQUENCY NOT = "MONTHLY"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-NEXT-DATE TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-END-DATE NOT = SPACES
               MOVE WS-END-DATE TO WS-DATE-IN
               PERFORM VALIDATE-DATE-FIELD
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               IF WS-END-DATE < WS-NEXT-DATE
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "SELECT 1 FROM payment_instruction WHERE instruction_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT 1 FROM users WHERE email = ? AND status = 'VERIFIED' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-FROM TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-TO TO WS-BIND-1
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
           MOVE "INSERT INTO payment_instruction (instruction_code, from_email, to_email, amount, currency_code, frequency) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-FROM TO WS-BIND-2
           MOVE WS-TO TO WS-BIND-3
           MOVE WS-AMOUNT TO WS-BIND-4
           MOVE WS-CURRENCY TO WS-BIND-5
           MOVE WS-FREQUENCY TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE payment_instruction SET frequency = ?, next_run_date = ?, end_date = NULLIF(?, ''), created_by = ? WHERE instruction_code = ?" TO WS-PREP-SQL
               MOVE WS-FREQUENCY TO WS-BIND-1
               MOVE WS-NEXT-DATE TO WS-BIND-2
               MOVE WS-END-DATE TO WS-BIND-3
               MOVE WS-P6-TRIMMED TO WS-BIND-4
               MOVE WS-P1-TRIMMED TO WS-BIND-5
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSTRUCTION_CREATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|PIC_CREATED|" DELIMITED BY SIZE WS-P1-TRIMMED DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-LIST.
           MOVE "PAYMENT_INSTRUCTION" TO WS-DENIED-TARGET
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
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM payment_instruction WHERE (? = '' OR status = ?) AND (? = '' OR from_email = ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(instruction_code, ':', from_email, ':', to_email, ':', amount, ':', currency_code, ':', frequency, ':', next_run_date, ':', status) FROM payment_instruction WHERE (? = '' OR status = ?) AND (? = '' OR from_email = ?) ORDER BY next_run_date, id LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-LIMIT TO WS-BIND-5
           MOVE WS-OFFSET TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|PIC_INSTRUCTIONS|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|PIC_INSTRUCTIONS|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-GET.
           MOVE "PAYMENT_INSTRUCTION" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(instruction_code, '|', from_email, '|', to_email, '|', CAST(amount AS DECIMAL(30,2)), '|', currency_code, '|', frequency, '|', next_run_date, '|', COALESCE(end_date, ''), '|', status, '|', COALESCE(last_txn_ref, '')) FROM payment_instruction WHERE instruction_code = ? LIMIT 1" TO WS-PREP-SQL
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
           STRING "SUCCESS|PIC_INSTRUCTION|" DELIMITED BY SIZE WS-RESULT(1:400) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-PAUSE.
           MOVE "PAYMENT_INSTRUCTION" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-INSTRUCTION
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-STATUS NOT = "ACTIVE"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE payment_instruction SET status = 'PAUSED' WHERE instruction_code = ? AND status = 'ACTIVE'" TO WS-PREP-SQL
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
               MOVE "INSTRUCTION_PAUSE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|PIC_PAUSED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RESUME.
           MOVE "PAYMENT_INSTRUCTION" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-INSTRUCTION
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-STATUS NOT = "PAUSED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE payment_instruction SET status = 'ACTIVE', next_run_date = GREATEST(next_run_date, CURDATE()) WHERE instruction_code = ? AND status = 'PAUSED'" TO WS-PREP-SQL
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
               MOVE "INSTRUCTION_RESUME" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|PIC_RESUMED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-CANCEL.
           MOVE "PAYMENT_INSTRUCTION" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-INSTRUCTION
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-STATUS = "CANCELLED" OR WS-STATUS = "COMPLETED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE payment_instruction SET status = 'CANCELLED' WHERE instruction_code = ?" TO WS-PREP-SQL
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
               MOVE "INSTRUCTION_CANCEL" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|PIC_CANCELLED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-DUE.
           MOVE "PAYMENT_INSTRUCTION" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED TO WS-DATE-IN
               PERFORM VALIDATE-DATE-FIELD
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "50" TO WS-LIMIT
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           MOVE "SELECT CONCAT(instruction_code, ':', from_email, ':', to_email, ':', CAST(amount AS DECIMAL(30,2)), ':', currency_code, ':', next_run_date) FROM payment_instruction WHERE status = 'ACTIVE' AND next_run_date <= COALESCE(NULLIF(?, ''), CURDATE()) ORDER BY next_run_date, id LIMIT ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-LIMIT TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|PIC_DUE|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|PIC_DUE|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-EXECUTE.
           MOVE "PAYMENT_INSTRUCTION" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-INSTRUCTION
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-STATUS NOT = "ACTIVE"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-IDEMPOTENCY
           STRING "PI-" DELIMITED BY SIZE WS-P1-TRIMMED(1:30) DELIMITED BY SPACE
               "-" DELIMITED BY SIZE WS-NEXT-DATE DELIMITED BY SPACE
               INTO WS-IDEMPOTENCY END-STRING
           MOVE "TRANSFER" TO WS-CALL-ACTION
           MOVE WS-FROM TO WS-CALL-P1
           MOVE WS-TO TO WS-CALL-P2
           MOVE WS-AMOUNT TO WS-CALL-P3
           MOVE WS-IDEMPOTENCY TO WS-CALL-P4
           MOVE WS-CURRENCY TO WS-CALL-P5
           MOVE WS-CURRENCY TO WS-CALL-P6
           MOVE SPACES TO WS-CALL-OUT
           CALL "wallet_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
               WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           END-CALL
           IF WS-CALL-OUT(1:5) = "ERROR"
               SET STEP-OK TO TRUE
               CALL "SQL_BEGIN" END-CALL
               MOVE "INSERT INTO payment_instruction_run (instruction_id, status, error_detail, created_by) SELECT id, 'FAILED', ?, ? FROM payment_instruction WHERE instruction_code = ?" TO WS-PREP-SQL
               MOVE WS-CALL-OUT(1:255) TO WS-BIND-1
               MOVE WS-P6-TRIMMED TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
               IF STEP-OK
                   MOVE "INSTRUCTION_RUN_FAILED" TO WS-AUDIT-ACTION
                   MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                   PERFORM AUDIT
               END-IF
               IF STEP-OK
                   CALL "SQL_COMMIT" END-CALL
               ELSE
                   CALL "SQL_ROLLBACK" END-CALL
               END-IF
               MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE payment_instruction SET next_run_date = CASE frequency WHEN 'DAILY' THEN DATE_ADD(next_run_date, INTERVAL 1 DAY) WHEN 'WEEKLY' THEN DATE_ADD(next_run_date, INTERVAL 7 DAY) ELSE DATE_ADD(next_run_date, INTERVAL 1 MONTH) END, last_run_at = NOW(), last_txn_ref = ? WHERE instruction_code = ? AND frequency <> 'ONCE'" TO WS-PREP-SQL
           MOVE WS-IDEMPOTENCY TO WS-BIND-1
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
               MOVE "UPDATE payment_instruction SET status = 'COMPLETED', last_run_at = NOW(), last_txn_ref = ? WHERE instruction_code = ? AND frequency = 'ONCE'" TO WS-PREP-SQL
               MOVE WS-IDEMPOTENCY TO WS-BIND-1
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
               MOVE "UPDATE payment_instruction SET status = 'COMPLETED' WHERE instruction_code = ? AND status = 'ACTIVE' AND end_date IS NOT NULL AND next_run_date > end_date" TO WS-PREP-SQL
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
               MOVE "INSERT INTO payment_instruction_run (instruction_id, status, txn_ref, created_by) SELECT id, 'COMPLETED', ?, ? FROM payment_instruction WHERE instruction_code = ?" TO WS-PREP-SQL
               MOVE WS-IDEMPOTENCY TO WS-BIND-1
               MOVE WS-P6-TRIMMED TO WS-BIND-2
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
               MOVE "INSTRUCTION_RUN" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|PIC_EXECUTED|" DELIMITED BY SIZE WS-P1-TRIMMED
                   DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-IDEMPOTENCY
                   DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-HISTORY.
           MOVE "PAYMENT_INSTRUCTION" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-INSTRUCTION
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
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
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM payment_instruction_run WHERE instruction_id = (SELECT id FROM payment_instruction WHERE instruction_code = ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(id, ':', status, ':', COALESCE(txn_ref, ''), ':', COALESCE(error_detail, ''), ':', run_at) FROM payment_instruction_run WHERE instruction_id = (SELECT id FROM payment_instruction WHERE instruction_code = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               STRING "SUCCESS|PIC_HISTORY|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|PIC_HISTORY|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.
