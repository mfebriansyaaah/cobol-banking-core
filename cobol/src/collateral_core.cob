        IDENTIFICATION DIVISION.
        PROGRAM-ID. collateral_core.
      *> Collateral: create, appraise, release.

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
        01  WS-AUDIT-CLT       PIC X(20) VALUE SPACES.
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
        01  WS-NUM-AMOUNT           PIC S9(15)V9(4) VALUE 0.
        01  WS-NUM-ACTIVE           PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-ALLOCATED          PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-VERSION            PIC 9(9) VALUE 0.
        01  WS-NUM-TOTAL            PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-HAIRCUT          PIC S9(3)V9(2) VALUE 0.
        01  WS-NUM-LIMIT            PIC 9(15)V9(4) VALUE 0.
        01  WS-LOAN-STATUS          PIC X(20) VALUE SPACES.
        01  WS-PLEDGE-ID            PIC X(20) VALUE SPACES.
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
                WHEN LS-CMD-ACTION(1:10) = "CLT_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CREATE
                WHEN LS-CMD-ACTION(1:8) = "CLT_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LIST
                WHEN LS-CMD-ACTION(1:7) = "CLT_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-GET
                WHEN LS-CMD-ACTION(1:10) = "CLT_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-UPDATE
                WHEN LS-CMD-ACTION(1:8) = "CLT_CALC"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUBMIT
                WHEN LS-CMD-ACTION(1:10) = "CLT_DELETE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLOSE
                WHEN LS-CMD-ACTION(1:11) = "CLT_SUMMARY"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUMMARY
                WHEN LS-CMD-ACTION(1:9) = "CLT_AUDIT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AUDIT
                WHEN LS-CMD-ACTION(1:12) = "CLT_REGISTER"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REGISTER
                WHEN LS-CMD-ACTION(1:12) = "CLT_APPRAISE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-APPRAISE
                WHEN LS-CMD-ACTION(1:11) = "CLT_REVALUE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REVALUE
                WHEN LS-CMD-ACTION(1:10) = "CLT_PLEDGE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PLEDGE
                WHEN LS-CMD-ACTION(1:12) = "CLT_ALLOCATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ALLOCATE
                WHEN LS-CMD-ACTION(1:11) = "CLT_RELEASE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RELEASE
                WHEN LS-CMD-ACTION(1:13) = "CLT_REPOSSESS"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REPOSSESS
                WHEN LS-CMD-ACTION(1:11) = "CLT_DISPOSE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DISPOSE
                WHEN LS-CMD-ACTION(1:12) = "CLT_VALIDATE"
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
            MOVE "INSERT INTO collateral_audit (collateral_id, action, actor_email, detail, old_value, new_value) VALUES (NULLIF(?, ''), ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-CLT TO WS-BIND-1
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
            MOVE SPACES TO WS-AUDIT-CLT
            MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
            MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
            PERFORM AUDIT.
            EXIT PARAGRAPH.


        LOAD-CLEARING.
            MOVE SPACES TO WS-ERR
            MOVE "SELECT CONCAT(asset_type, '|', assessed_value, '|', appraised_value, '|', status, '|', COALESCE(asset_name, ''), '|', '', '|', version) FROM collateral WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM collateral WHERE collateral_ref = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "INSERT INTO collateral (collateral_ref, asset_name, asset_type, status, created_by) VALUES (?, ?, NULLIF(?, ''), 'OPEN', ?)" TO WS-PREP-SQL
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
                MOVE WS-NEW-ID TO WS-AUDIT-CLT
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|CLT_CREATE|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LIST.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
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
            MOVE "SELECT CONCAT(id, ':', collateral_ref, ':', status, ':', assessed_value, ':', appraised_value, ':', COALESCE(asset_name, '')) FROM collateral WHERE (? = '' OR status = ?) AND (? = '' OR asset_name = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|CLT_LIST|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|CLT_LIST|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-GET.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(id, '|', collateral_ref, '|', status, '|', assessed_value, '|', appraised_value, '|', COALESCE(asset_name, ''), '|', COALESCE(asset_type, ''), '|', created_by, '|', created_at) FROM collateral WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|CLT_GET|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-SUBMIT.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
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
            MOVE "UPDATE collateral SET appraised_value = appraised_value + ?, status = 'ACTIVE', appraised_at = COALESCE(appraised_at, NOW()), version = version + 1 WHERE id = ? AND version = ? AND status = 'OPEN'" TO WS-PREP-SQL
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE "allocated" TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE WS-TMP-AMT TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CLT_CALC|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-UPDATE.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
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
            MOVE "UPDATE collateral SET asset_name = COALESCE(NULLIF(?, ''), asset_name), asset_type = COALESCE(NULLIF(?, ''), asset_type), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-STATUS TO WS-AUDIT-OLD
                MOVE WS-P2-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CLT_UPDATE" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CLOSE.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
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
            MOVE "UPDATE collateral SET status = 'RELEASED', released_at = NOW(), release_reason = NULLIF(?, ''), deleted_at = NOW(), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE "ACTIVE" TO WS-AUDIT-OLD
                MOVE "RELEASED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CLT_DELETE" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-REGISTER.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P4-TRIMMED = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P4-TRIMMED) TO WS-NUM-AMOUNT
            IF WS-NUM-AMOUNT <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM collateral WHERE collateral_ref = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "INSERT INTO collateral (collateral_ref, customer_ref, asset_name, asset_type, assessed_value, status, created_by) VALUES (?, NULLIF(?, ''), ?, ?, ?, 'REGISTERED', ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P5-TRIMMED TO WS-BIND-2
            MOVE WS-P2-TRIMMED TO WS-BIND-3
            MOVE WS-P3-TRIMMED TO WS-BIND-4
            MOVE WS-P4-TRIMMED TO WS-BIND-5
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
                MOVE "REGISTER" TO WS-AUDIT-ACTION
                MOVE WS-NEW-ID TO WS-AUDIT-CLT
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE WS-P4-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|CLT_REGISTER|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-APPRAISE.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
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
            PERFORM LOAD-CLEARING
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TMP-STATUS NOT = "REGISTERED" AND WS-TMP-STATUS NOT = "OPEN"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO collateral_valuation (collateral_id, valuation_type, value_amount, currency, method, valuer, note, created_by) VALUES (?, 'APPRAISAL', ?, 'IDR', ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P3-TRIMMED TO WS-BIND-4
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
                MOVE "UPDATE collateral SET appraised_value = ?, latest_valuation_id = ?, status = 'APPRAISED', appraised_at = NOW(), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
                MOVE WS-P2-TRIMMED TO WS-BIND-1
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-BIND-2
                MOVE WS-P1-TRIMMED TO WS-BIND-3
                MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-4
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF WS-RESULT = "0 rows affected" OR WS-RESULT = "ERROR|NO_DATA"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "APPRAISE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE WS-TMP-ALLOCATED TO WS-AUDIT-OLD
                MOVE WS-P2-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CLT_APPRAISE|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-REVALUE.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
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
            PERFORM LOAD-CLEARING
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TMP-STATUS NOT = "APPRAISED" AND WS-TMP-STATUS NOT = "PLEDGED"
                AND WS-TMP-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO collateral_valuation (collateral_id, valuation_type, value_amount, currency, method, valuer, note, created_by) VALUES (?, 'REVALUATION', ?, 'IDR', ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P3-TRIMMED TO WS-BIND-4
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
                MOVE "UPDATE collateral SET appraised_value = ?, latest_valuation_id = ?, version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
                MOVE WS-P2-TRIMMED TO WS-BIND-1
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-BIND-2
                MOVE WS-P1-TRIMMED TO WS-BIND-3
                MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-4
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "REVALUE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE WS-TMP-ALLOCATED TO WS-AUDIT-OLD
                MOVE WS-P2-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CLT_REVALUE|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PLEDGE.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P3-TRIMMED) TO WS-NUM-AMOUNT
            IF WS-NUM-AMOUNT <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P4-TRIMMED NOT = SPACES
                MOVE FUNCTION NUMVAL(WS-P4-TRIMMED) TO WS-NUM-HAIRCUT
                IF WS-NUM-HAIRCUT < 0 OR WS-NUM-HAIRCUT > 100
                    MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            ELSE
                MOVE 0 TO WS-NUM-HAIRCUT
            END-IF.
            PERFORM LOAD-CLEARING
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TMP-STATUS NOT = "APPRAISED" AND WS-TMP-STATUS NOT = "PLEDGED"
                AND WS-TMP-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM loan_application WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE WS-RESULT(1:20) TO WS-LOAN-STATUS.
            COMPUTE WS-NUM-LIMIT = WS-NUM-ALLOCATED * (100 - WS-NUM-HAIRCUT) / 100 END-COMPUTE
            MOVE "SELECT COALESCE(SUM(pledge_amount), 0) FROM collateral_pledge WHERE collateral_id = ? AND status = 'PLEDGED'" TO WS-PREP-SQL
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
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE 0 TO WS-NUM-TOTAL
            ELSE
                MOVE FUNCTION NUMVAL(WS-RESULT) TO WS-NUM-TOTAL
            END-IF.
            IF WS-NUM-AMOUNT + WS-NUM-TOTAL > WS-NUM-LIMIT
                MOVE "ERROR|LIMIT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO collateral_pledge (collateral_id, loan_id, pledge_amount, haircut_pct, status, created_by) VALUES (?, ?, ?, ?, 'PLEDGED', ?)" TO WS-PREP-SQL
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
                    MOVE WS-RESULT(1:20) TO WS-PLEDGE-ID
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "UPDATE collateral SET status = 'PLEDGED', version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
                MOVE WS-P1-TRIMMED TO WS-BIND-1
                MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-2
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
                MOVE "PLEDGE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE WS-P3-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|CLT_PLEDGE|" DELIMITED BY SIZE FUNCTION TRIM(WS-PLEDGE-ID) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ALLOCATE.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P3-TRIMMED) TO WS-NUM-AMOUNT
            IF WS-NUM-AMOUNT <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(pledge_amount, '|', status) FROM collateral_pledge WHERE pledge_id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE SPACES TO WS-TMP-AMT
            MOVE SPACES TO WS-TMP-STATUS
            UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-AMT WS-TMP-STATUS END-UNSTRING
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-LIMIT
            IF WS-TMP-STATUS NOT = "PLEDGED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT COALESCE(SUM(allocated_amount), 0) FROM collateral_allocation WHERE pledge_id = ?" TO WS-PREP-SQL
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
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE 0 TO WS-NUM-TOTAL
            ELSE
                MOVE FUNCTION NUMVAL(WS-RESULT) TO WS-NUM-TOTAL
            END-IF.
            IF WS-NUM-AMOUNT + WS-NUM-TOTAL > WS-NUM-LIMIT
                MOVE "ERROR|LIMIT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO collateral_allocation (pledge_id, loan_id, allocated_amount) VALUES (?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ALLOCATE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE WS-P3-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CLT_ALLOCATE|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RELEASE.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
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
            IF WS-TMP-STATUS NOT = "PLEDGED" AND WS-TMP-STATUS NOT = "APPRAISED"
                AND WS-TMP-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM collateral_pledge p JOIN loan_application l ON l.id = p.loan_id WHERE p.collateral_id = ? AND p.status = 'PLEDGED' AND l.status NOT IN ('CLOSED', 'CANCELLED') LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) NOT = "ERROR"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "ERROR|NO_DATA" AND WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE collateral_pledge SET status = 'RELEASED', released_at = NOW(), release_reason = ? WHERE collateral_id = ? AND status = 'PLEDGED'" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
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
                MOVE "UPDATE collateral SET status = 'RELEASED', released_at = NOW(), release_reason = ?, version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
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
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "RELEASE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-STATUS TO WS-AUDIT-OLD
                MOVE "RELEASED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CLT_RELEASE|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-REPOSSESS.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
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
            IF WS-TMP-STATUS NOT = "PLEDGED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE collateral SET status = 'REPOSSESSED', version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                IF WS-P4-TRIMMED NOT = SPACES
                    MOVE "UPDATE collateral SET gl_journal_id = ? WHERE id = ?" TO WS-PREP-SQL
                    MOVE WS-P4-TRIMMED TO WS-BIND-1
                    MOVE WS-P1-TRIMMED TO WS-BIND-2
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                    END-CALL
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                    IF WS-RESULT(1:5) = "ERROR"
                        SET STEP-FAIL TO TRUE
                    END-IF
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "REPOSSESS" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-STATUS TO WS-AUDIT-OLD
                MOVE "REPOSSESSED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CLT_REPOSSESS|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DISPOSE.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
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
            IF WS-TMP-STATUS NOT = "REPOSSESSED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            IF WS-P2-TRIMMED NOT = SPACES
                MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT
                IF WS-NUM-AMOUNT < 0
                    MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            MOVE "UPDATE collateral SET status = 'DISPOSED', released_at = NOW(), release_reason = ?, version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
            MOVE WS-P3-TRIMMED TO WS-BIND-1
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
                IF WS-P4-TRIMMED NOT = SPACES
                    MOVE "UPDATE collateral SET gl_journal_id = ? WHERE id = ?" TO WS-PREP-SQL
                    MOVE WS-P4-TRIMMED TO WS-BIND-1
                    MOVE WS-P1-TRIMMED TO WS-BIND-2
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                    END-CALL
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                    IF WS-RESULT(1:5) = "ERROR"
                        SET STEP-FAIL TO TRUE
                    END-IF
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "DISPOSE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CLT
                MOVE WS-TMP-STATUS TO WS-AUDIT-OLD
                MOVE "DISPOSED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CLT_DISPOSE|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SUMMARY.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'OPEN'), 0), '|', COALESCE(SUM(status = 'ACTIVE'), 0), '|', COALESCE(SUM(status = 'ALLOCATED'), 0), '|', COALESCE(SUM(status = 'CLOSED'), 0), '|', COALESCE(SUM(assessed_value), 0), '|', COALESCE(SUM(appraised_value), 0)) FROM collateral" TO WS-PREP-SQL
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
            STRING "SUCCESS|CLT_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-AUDIT.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
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
            MOVE "SELECT CONCAT(action, ':', actor_email, ':', COALESCE(detail, ''), ':', created_at) FROM collateral_audit WHERE (? = '' OR collateral_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|CLT_AUDIT|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|CLT_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-VALIDATE.
            MOVE "COLLATERAL_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
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
            STRING "SUCCESS|CLT_VALID|" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE
                "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.
