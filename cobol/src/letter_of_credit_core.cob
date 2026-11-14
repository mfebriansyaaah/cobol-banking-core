        IDENTIFICATION DIVISION.
        PROGRAM-ID. letter_of_credit_core.
      *> Letter of credit: create, draw, close.

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
        01  WS-AUDIT-LOC       PIC X(20) VALUE SPACES.
        01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
        01  WS-AUDIT-OLD            PIC X(255) VALUE SPACES.
        01  WS-AUDIT-NEW            PIC X(255) VALUE SPACES.
        01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
        01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
        01  WS-TMP-AMT              PIC X(30) VALUE SPACES.
        01  WS-TMP-STATUS           PIC X(20) VALUE SPACES.
        01  WS-TMP-CURR             PIC X(10) VALUE SPACES.
        01  WS-TMP-STR              PIC X(100) VALUE SPACES.
        01  WS-TMP-ID               PIC X(100) VALUE SPACES.
        01  WS-TMP-ALLOCATED          PIC X(30) VALUE SPACES.
        01  WS-TMP-VERSION            PIC X(10) VALUE SPACES.
        01  WS-NEW-ID               PIC X(20) VALUE SPACES.
        01  WS-NUM-AMOUNT           PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-ACTIVE           PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-ALLOCATED          PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-VERSION            PIC 9(9) VALUE 0.
        01  WS-NUM-TOTAL            PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-DRAWN            PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-DELTA            PIC S9(15)V9(4) VALUE 0.
        01  WS-NUM-LIMIT            PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-USED             PIC 9(15)V9(4) VALUE 0.
        01  WS-COLON                PIC 9(3) VALUE 0.
        01  WS-TMP-DATE             PIC X(20) VALUE SPACES.
        01  WS-TMP-EXPIRY           PIC X(20) VALUE SPACES.
        01  WS-DRAW-STATUS          PIC X(20) VALUE SPACES.
        01  WS-TMP-DRAWN            PIC X(30) VALUE SPACES.
        01  WS-AMT-EDIT             PIC Z(14)9.9999 VALUE 0.
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
                WHEN LS-CMD-ACTION(1:10) = "LOC_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CREATE
                WHEN LS-CMD-ACTION(1:8) = "LOC_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LIST
                WHEN LS-CMD-ACTION(1:7) = "LOC_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-GET
                WHEN LS-CMD-ACTION(1:10) = "LOC_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-UPDATE
                WHEN LS-CMD-ACTION(1:8) = "LOC_CALC"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUBMIT
                WHEN LS-CMD-ACTION(1:10) = "LOC_DELETE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLOSE
                WHEN LS-CMD-ACTION(1:10) = "LOC_SUBMIT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUBMIT-LC
                WHEN LS-CMD-ACTION(1:11) = "LOC_APPROVE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-APPROVE-LC
                WHEN LS-CMD-ACTION(1:9) = "LOC_ISSUE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ISSUE-LC
                WHEN LS-CMD-ACTION(1:9) = "LOC_AMEND"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AMEND-LC
                WHEN LS-CMD-ACTION(1:12) = "LOC_DOCUMENT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DOCUMENT-LC
                WHEN LS-CMD-ACTION(1:8) = "LOC_DRAW"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DRAW-LC
                WHEN LS-CMD-ACTION(1:10) = "LOC_SETTLE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SETTLE-LC
                WHEN LS-CMD-ACTION(1:9) = "LOC_CLOSE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLOSE-LC
                WHEN LS-CMD-ACTION(1:11) = "LOC_SUMMARY"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUMMARY
                WHEN LS-CMD-ACTION(1:9) = "LOC_AUDIT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AUDIT
                WHEN LS-CMD-ACTION(1:12) = "LOC_VALIDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-VALIDATE
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        COPY "common_validate_all.cpy".
        COPY "common_sql.cpy".
        COPY "common_trim.cpy".
        COPY "common_result.cpy".




        COPY "common_auth.cpy".

        AUDIT.
            MOVE "INSERT INTO letter_of_credit_audit (letter_of_credit_id, action, actor_email, detail, old_value, new_value) VALUES (NULLIF(?, ''), ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-LOC TO WS-BIND-1
            MOVE WS-AUDIT-ACTION TO WS-BIND-2
            MOVE WS-P6-TRIMMED TO WS-BIND-3
            MOVE WS-AUDIT-DETAIL TO WS-BIND-4
            MOVE WS-AUDIT-OLD TO WS-BIND-5
            MOVE WS-AUDIT-NEW TO WS-BIND-6
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
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
            MOVE SPACES TO WS-AUDIT-LOC
            MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
            MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
            PERFORM AUDIT.
            EXIT PARAGRAPH.


        LOAD-CLEARING.
            MOVE SPACES TO WS-ERR
            MOVE "SELECT CONCAT(lc_type, '|', lc_amount, '|', drawn_amount, '|', status, '|', COALESCE(applicant_name, ''), '|', '', '|', version) FROM letter_of_credit WHERE id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                EXIT PARAGRAPH
            END-IF
            MOVE SPACES TO WS-TMP-AMT
            MOVE SPACES TO WS-TMP-STR
            MOVE SPACES TO WS-TMP-ALLOCATED
            MOVE SPACES TO WS-TMP-STATUS
            MOVE SPACES TO WS-TMP-CURR
            MOVE SPACES TO WS-TMP-ID
            MOVE SPACES TO WS-TMP-VERSION
            UNSTRING WS-RESULT DELIMITED BY "|" INTO
                WS-TMP-AMT WS-TMP-STR WS-TMP-ALLOCATED WS-TMP-STATUS WS-TMP-CURR WS-TMP-ID WS-TMP-VERSION
            END-UNSTRING
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-TOTAL
            MOVE FUNCTION NUMVAL(WS-TMP-STR) TO WS-NUM-ACTIVE
            MOVE FUNCTION NUMVAL(WS-TMP-ALLOCATED) TO WS-NUM-ALLOCATED
            MOVE FUNCTION NUMVAL(WS-TMP-VERSION) TO WS-NUM-VERSION
            EXIT PARAGRAPH.

        ACTION-CREATE.
            MOVE "LETTER_OF_CREDIT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            MOVE 0 TO WS-COLON
            INSPECT WS-P5-TRIMMED TALLYING WS-COLON FOR ALL ":"
            IF WS-COLON > 0
                PERFORM ACTION-DRAFT-LC
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM letter_of_credit WHERE lc_ref = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "INSERT INTO letter_of_credit (lc_ref, applicant_name, lc_type, status, created_by) VALUES (?, ?, NULLIF(?, ''), 'OPEN', ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P6-TRIMMED TO WS-BIND-4
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
                    MOVE WS-RESULT(1:20) TO WS-NEW-ID
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "CREATE" TO WS-AUDIT-ACTION
                MOVE WS-NEW-ID TO WS-AUDIT-LOC
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|LOC_CREATE|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DRAFT-LC.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P4-TRIMMED = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-TMP-CURR WS-TMP-AMT WS-TMP-DATE
            UNSTRING WS-P5-TRIMMED DELIMITED BY ":" INTO
                WS-TMP-CURR WS-TMP-AMT WS-TMP-DATE
            END-UNSTRING
            IF WS-TMP-CURR = SPACES OR WS-TMP-AMT = SPACES OR WS-TMP-DATE = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-AMOUNT
            IF WS-NUM-AMOUNT <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM letter_of_credit WHERE lc_ref = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "SELECT CONCAT(full_name, '|', credit_limit, '|', used_credit, '|', status) FROM customer WHERE customer_ref = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE SPACES TO WS-TMP-STR WS-TMP-AMT WS-TMP-ALLOCATED WS-TMP-STATUS
            UNSTRING WS-RESULT DELIMITED BY "|" INTO
                WS-TMP-STR WS-TMP-AMT WS-TMP-ALLOCATED WS-TMP-STATUS
            END-UNSTRING
            IF WS-TMP-STATUS = "CLOSED" OR WS-TMP-STATUS = "DELETED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO letter_of_credit (lc_ref, applicant_customer_ref, applicant_name, lc_type, status, created_by) VALUES (?, ?, ?, ?, 'DRAFT', ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-TMP-STR TO WS-BIND-3
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
                    MOVE WS-RESULT(1:20) TO WS-NEW-ID
                END-IF
            END-IF.
            IF STEP-OK
                MOVE WS-NUM-AMOUNT TO WS-AMT-EDIT
                MOVE "UPDATE letter_of_credit SET beneficiary_name = ?, currency = ?, lc_amount = ?, expiry_date = ? WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-P3-TRIMMED TO WS-BIND-1
                MOVE WS-TMP-CURR TO WS-BIND-2
                MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-BIND-3
                MOVE WS-TMP-DATE TO WS-BIND-4
                MOVE WS-NEW-ID TO WS-BIND-5
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
                MOVE "DRAFT" TO WS-AUDIT-ACTION
                MOVE WS-NEW-ID TO WS-AUDIT-LOC
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|LOC_CREATE|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SUBMIT-LC.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM letter_of_credit WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE WS-RESULT(1:20) TO WS-TMP-STATUS.
            IF WS-TMP-STATUS NOT = "DRAFT"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE letter_of_credit SET status = 'SUBMITTED', version = version + 1 WHERE id = ? AND status = 'DRAFT'" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "0 rows affected" OR WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SUBMIT" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
            MOVE "DRAFT" TO WS-AUDIT-OLD
            MOVE "SUBMITTED" TO WS-AUDIT-NEW
            PERFORM AUDIT
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|LOC_SUBMIT|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-APPROVE-LC.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(status, '|', applicant_customer_ref, '|', lc_amount) FROM letter_of_credit WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE SPACES TO WS-TMP-STATUS WS-TMP-STR WS-TMP-AMT
            UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-STATUS WS-TMP-STR WS-TMP-AMT
            END-UNSTRING
            IF WS-TMP-STATUS NOT = "SUBMITTED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-AMOUNT
            MOVE "SELECT CONCAT(credit_limit, '|', used_credit) FROM customer WHERE customer_ref = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-TMP-STR TO WS-BIND-1
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
            MOVE SPACES TO WS-TMP-AMT WS-TMP-ALLOCATED
            UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-AMT WS-TMP-ALLOCATED
            END-UNSTRING
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-LIMIT
            MOVE FUNCTION NUMVAL(WS-TMP-ALLOCATED) TO WS-NUM-USED
            IF WS-NUM-AMOUNT > WS-NUM-LIMIT - WS-NUM-USED
                MOVE "ERROR|LIMIT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE letter_of_credit SET status = 'APPROVED', version = version + 1 WHERE id = ? AND status = 'SUBMITTED'" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "0 rows affected" OR WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "APPROVE" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
            MOVE "SUBMITTED" TO WS-AUDIT-OLD
            MOVE "APPROVED" TO WS-AUDIT-NEW
            PERFORM AUDIT
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|LOC_APPROVE|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-ISSUE-LC.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM letter_of_credit WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE WS-RESULT(1:20) TO WS-TMP-STATUS.
            IF WS-TMP-STATUS NOT = "APPROVED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            IF WS-P2-TRIMMED = SPACES
                MOVE "UPDATE letter_of_credit SET status = 'ISSUED', issued_at = NOW(), version = version + 1 WHERE id = ? AND status = 'APPROVED'" TO WS-PREP-SQL
                MOVE WS-P1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
            ELSE
                MOVE "UPDATE letter_of_credit SET status = 'ISSUED', issued_at = NOW(), gl_journal_id = ?, version = version + 1 WHERE id = ? AND status = 'APPROVED'" TO WS-PREP-SQL
                MOVE WS-P2-TRIMMED TO WS-BIND-1
                MOVE WS-P1-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
            END-IF
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "0 rows affected" OR WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "ISSUE" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
            MOVE "APPROVED" TO WS-AUDIT-OLD
            MOVE "ISSUED" TO WS-AUDIT-NEW
            PERFORM AUDIT
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|LOC_ISSUE|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-AMEND-LC.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-DELTA
            MOVE "SELECT CONCAT(status, '|', lc_amount, '|', COALESCE(CAST(expiry_date AS CHAR), ''), '|', COALESCE(applicant_customer_ref, '')) FROM letter_of_credit WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE SPACES TO WS-TMP-STATUS WS-TMP-AMT WS-TMP-EXPIRY WS-TMP-STR
            UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-STATUS WS-TMP-AMT WS-TMP-EXPIRY WS-TMP-STR
            END-UNSTRING
            IF WS-TMP-STATUS NOT = "ISSUED" AND WS-TMP-STATUS NOT = "AMENDED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-AMOUNT
            IF WS-NUM-AMOUNT + WS-NUM-DELTA <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO lc_amendment (lc_id, amendment_no, amount_delta, new_expiry_date, new_terms, status, approved_by, approved_at, created_by) SELECT ?, COALESCE(MAX(amendment_no), 0) + 1, ?, NULLIF(?, ''), NULLIF(?, ''), 'APPROVED', NULL, NOW(), ? FROM lc_amendment WHERE lc_id = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            MOVE WS-P6-TRIMMED TO WS-BIND-5
            MOVE WS-P1-TRIMMED TO WS-BIND-6
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-TRIMMED = SPACES
                MOVE "UPDATE letter_of_credit SET lc_amount = lc_amount + ?, status = 'AMENDED', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-P2-TRIMMED TO WS-BIND-1
                MOVE WS-P1-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
            ELSE
                MOVE "UPDATE letter_of_credit SET lc_amount = lc_amount + ?, expiry_date = ?, status = 'AMENDED', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-P2-TRIMMED TO WS-BIND-1
                MOVE WS-P3-TRIMMED TO WS-BIND-2
                MOVE WS-P1-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
            END-IF
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "AMEND" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
            MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
            PERFORM AUDIT
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|LOC_AMEND|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-DOCUMENT-LC.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P4-TRIMMED NOT = "RECEIVED" AND WS-P4-TRIMMED NOT = "CHECKED"
                AND WS-P4-TRIMMED NOT = "ACCEPTED" AND WS-P4-TRIMMED NOT = "REJECTED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM letter_of_credit WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE WS-RESULT(1:20) TO WS-TMP-STATUS.
            IF WS-TMP-STATUS NOT = "ISSUED" AND WS-TMP-STATUS NOT = "AMENDED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO lc_document (lc_id, doc_type, doc_ref, status, discrepancy, created_at) VALUES (?, ?, ?, ?, NULLIF(?, ''), NOW())" TO WS-PREP-SQL
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
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "DOCUMENT" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
            MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
            PERFORM AUDIT
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|LOC_DOCUMENT|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-DRAW-LC.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P3-TRIMMED) TO WS-NUM-AMOUNT
            IF WS-NUM-AMOUNT <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(status, '|', lc_amount, '|', drawn_amount, '|', currency, '|', COALESCE(CAST(expiry_date AS CHAR), '')) FROM letter_of_credit WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE SPACES TO WS-TMP-STATUS WS-TMP-AMT WS-TMP-DRAWN WS-TMP-CURR WS-TMP-EXPIRY
            UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-STATUS WS-TMP-AMT WS-TMP-DRAWN WS-TMP-CURR WS-TMP-EXPIRY
            END-UNSTRING
            IF WS-TMP-STATUS NOT = "ISSUED" AND WS-TMP-STATUS NOT = "AMENDED"
                AND WS-TMP-STATUS NOT = "DRAWN"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-LIMIT
            MOVE FUNCTION NUMVAL(WS-TMP-DRAWN) TO WS-NUM-DRAWN
            IF WS-NUM-DRAWN + WS-NUM-AMOUNT > WS-NUM-LIMIT
                MOVE "ERROR|LIMIT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT COUNT(*) FROM lc_document WHERE lc_id = ? AND status = 'ACCEPTED'" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA" OR WS-RESULT = "0"
                MOVE "ERROR|DOCUMENT_REQUIRED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO lc_drawing (lc_id, drawing_no, amount, currency, due_date, status, created_by) VALUES (?, ?, ?, ?, NULLIF(?, ''), 'PRESENTED', ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-TMP-CURR TO WS-BIND-4
            MOVE WS-P5-TRIMMED TO WS-BIND-5
            MOVE WS-P6-TRIMMED TO WS-BIND-6
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE letter_of_credit SET drawn_amount = drawn_amount + ?, status = 'DRAWN', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
            MOVE WS-P3-TRIMMED TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "DRAW" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
            MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
            PERFORM AUDIT
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|LOC_DRAW|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-SETTLE-LC.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT
            IF WS-NUM-AMOUNT <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(d.lc_id, '|', d.amount, '|', d.status) FROM lc_drawing d WHERE d.drawing_id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE SPACES TO WS-TMP-ID WS-TMP-AMT WS-DRAW-STATUS
            UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-ID WS-TMP-AMT WS-DRAW-STATUS
            END-UNSTRING
            IF WS-DRAW-STATUS NOT = "PRESENTED" AND WS-DRAW-STATUS NOT = "ACCEPTED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-LIMIT
            IF WS-NUM-AMOUNT > WS-NUM-LIMIT
                MOVE "ERROR|LIMIT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO lc_settlement (drawing_id, payment_clearing_ref, settled_amount, gl_journal_id, settled_at, status, created_by) VALUES (?, NULLIF(?, ''), ?, NULLIF(?, ''), NOW(), 'SETTLED', ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P4-TRIMMED TO WS-BIND-2
            MOVE WS-P2-TRIMMED TO WS-BIND-3
            MOVE WS-P3-TRIMMED TO WS-BIND-4
            MOVE WS-P6-TRIMMED TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE lc_drawing SET status = 'SETTLED', accepted_at = COALESCE(accepted_at, NOW()) WHERE drawing_id = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE letter_of_credit SET status = 'SETTLED', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
            MOVE WS-TMP-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SETTLE" TO WS-AUDIT-ACTION
            MOVE WS-TMP-ID TO WS-AUDIT-LOC
            MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
            PERFORM AUDIT
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|LOC_SETTLE|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-CLOSE-LC.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT COUNT(*) FROM lc_drawing WHERE lc_id = ? AND status IN ('PRESENTED','ACCEPTED')" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "ERROR|NO_DATA" AND WS-RESULT NOT = "0"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE letter_of_credit SET status = 'CLOSED', closed_at = NOW(), close_reason = NULLIF(?, ''), version = version + 1 WHERE id = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "CLOSE" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
            MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
            PERFORM AUDIT
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|LOC_CLOSE|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-LIST.
            MOVE "LETTER_OF_CREDIT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            MOVE "50" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF WS-P3-TRIMMED NOT = SPACES
                MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-LIMIT
            END-IF.
            IF WS-P4-TRIMMED NOT = SPACES
                MOVE WS-P4-TRIMMED(1:WS-P4-LEN) TO WS-OFFSET
            END-IF.
            IF WS-P3-TRIMMED = SPACES AND WS-P2-TRIMMED NOT = SPACES
                IF WS-P2-TRIMMED(1:1) >= "0" AND WS-P2-TRIMMED(1:1) <= "9"
                    MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
                    IF WS-P3-TRIMMED NOT = SPACES
                        MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
                    END-IF
                END-IF
            END-IF
            MOVE "SELECT CONCAT(id, ':', lc_ref, ':', status, ':', lc_amount, ':', drawn_amount, ':', COALESCE(applicant_name, '')) FROM letter_of_credit WHERE (? = '' OR status = ?) AND (? = '' OR applicant_name = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
            IF WS-P1-TRIMMED = "OPEN" OR WS-P1-TRIMMED = "ACTIVE"
                OR WS-P1-TRIMMED = "ALLOCATED" OR WS-P1-TRIMMED = "CLOSED"
                OR WS-P1-TRIMMED = SPACES
                MOVE WS-P1-TRIMMED TO WS-BIND-1
                MOVE WS-P1-TRIMMED TO WS-BIND-2
            ELSE
                MOVE SPACES TO WS-BIND-1
                MOVE SPACES TO WS-BIND-2
            END-IF
            IF WS-P2-LEN = 3
                MOVE WS-P2-TRIMMED TO WS-BIND-3
                MOVE WS-P2-TRIMMED TO WS-BIND-4
            ELSE
                MOVE SPACES TO WS-BIND-3
                MOVE SPACES TO WS-BIND-4
            END-IF
            MOVE WS-LIMIT TO WS-BIND-5
            MOVE WS-OFFSET TO WS-BIND-6
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|LOC_LIST|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|LOC_LIST|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-GET.
            MOVE "LETTER_OF_CREDIT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(id, '|', lc_ref, '|', status, '|', lc_amount, '|', drawn_amount, '|', COALESCE(applicant_name, ''), '|', COALESCE(lc_type, ''), '|', created_by, '|', created_at) FROM letter_of_credit WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|LOC_GET|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-SUBMIT.
            MOVE "LETTER_OF_CREDIT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-TRIMMED IS NUMERIC AND WS-P2-TRIMMED > 0
                MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT
            ELSE
                MOVE 1 TO WS-NUM-AMOUNT
            END-IF
            IF WS-NUM-AMOUNT <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            PERFORM LOAD-CLEARING
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE WS-NUM-AMOUNT TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-AMT
            MOVE "UPDATE letter_of_credit SET drawn_amount = drawn_amount + ?, status = 'ACTIVE', issued_at = COALESCE(issued_at, NOW()), version = version + 1 WHERE id = ? AND version = ? AND status = 'OPEN'" TO WS-PREP-SQL
            MOVE WS-TMP-AMT TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT = "0 rows affected" OR WS-RESULT = "ERROR|NO_DATA"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "CALC" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
                MOVE "allocated" TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE WS-TMP-AMT TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|LOC_CALC|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-UPDATE.
            MOVE "LETTER_OF_CREDIT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CLEARING
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE letter_of_credit SET applicant_name = COALESCE(NULLIF(?, ''), applicant_name), lc_type = COALESCE(NULLIF(?, ''), lc_type), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P1-TRIMMED TO WS-BIND-3
            MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-4
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-STATUS TO WS-AUDIT-OLD
                MOVE WS-P2-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|LOC_UPDATE" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CLOSE.
            MOVE "LETTER_OF_CREDIT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CLEARING
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TMP-STATUS(1:9) = "ALLOCATED" OR WS-TMP-STATUS(1:6) = "CLOSED"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE letter_of_credit SET status = 'CLOSED', closed_at = NOW(), close_reason = NULLIF(?, ''), deleted_at = NOW(), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "DELETE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-LOC
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE "ACTIVE" TO WS-AUDIT-OLD
                MOVE "CLOSED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|LOC_DELETE" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SUMMARY.
            MOVE "LETTER_OF_CREDIT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'OPEN'), 0), '|', COALESCE(SUM(status = 'ACTIVE'), 0), '|', COALESCE(SUM(status = 'ALLOCATED'), 0), '|', COALESCE(SUM(status = 'CLOSED'), 0), '|', COALESCE(SUM(lc_amount), 0), '|', COALESCE(SUM(drawn_amount), 0)) FROM letter_of_credit" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
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
            STRING "SUCCESS|LOC_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-AUDIT.
            MOVE "LETTER_OF_CREDIT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
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
            MOVE "SELECT CONCAT(action, ':', actor_email, ':', COALESCE(detail, ''), ':', created_at) FROM letter_of_credit_audit WHERE (? = '' OR letter_of_credit_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|LOC_AUDIT|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|LOC_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-VALIDATE.
            MOVE "LETTER_OF_CREDIT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P1-TRIMMED) TO WS-NUM-AMOUNT
            IF WS-NUM-AMOUNT <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-TRIMMED = SPACES OR WS-P2-LEN NOT = 3
                MOVE "ERROR|INVALID_CURRENCY" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|LOC_VALID|" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE
                "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.
