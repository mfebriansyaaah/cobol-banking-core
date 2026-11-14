        IDENTIFICATION DIVISION.
        PROGRAM-ID. tax_management_core.
      *> Tax management: create, collect, deactivate.

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
        01  WS-AUDIT-TXM       PIC X(20) VALUE SPACES.
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
        01  WS-NUM-RATE             PIC S9(5)V9(4) VALUE 0.
        01  WS-NUM-FIXED            PIC S9(15)V9(4) VALUE 0.
        01  WS-NUM-THRESH           PIC S9(15)V9(4) VALUE 0.
        01  WS-NUM-MAX              PIC S9(15)V9(4) VALUE 0.
        01  WS-NUM-BASE             PIC S9(15)V9(4) VALUE 0.
        01  WS-NUM-TAX              PIC S9(15)V9(4) VALUE 0.
        01  WS-RULE-CURR            PIC X(10) VALUE SPACES.
        01  WS-RULE-GL              PIC X(20) VALUE SPACES.
        01  WS-RULE-FROM            PIC X(20) VALUE SPACES.
        01  WS-RULE-TO              PIC X(20) VALUE SPACES.
        01  WS-ENTRY-STATUS         PIC X(20) VALUE SPACES.
        01  WS-BIND-7               PIC X(256) VALUE SPACES.
        01  WS-AMT-EDIT             PIC Z(14)9.9999 VALUE 0.
        01  WS-SUCCESS-MSG          PIC X(16384) VALUE SPACES.
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
                WHEN LS-CMD-ACTION(1:10) = "TXM_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CREATE
                WHEN LS-CMD-ACTION(1:8) = "TXM_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LIST
                WHEN LS-CMD-ACTION(1:7) = "TXM_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-GET
                WHEN LS-CMD-ACTION(1:10) = "TXM_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-UPDATE
                WHEN LS-CMD-ACTION(1:8) = "TXM_CALC"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUBMIT
                WHEN LS-CMD-ACTION(1:10) = "TXM_DELETE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLOSE
                WHEN LS-CMD-ACTION(1:15) = "TXM_RULE_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RULE-CREATE
                WHEN LS-CMD-ACTION(1:15) = "TXM_RULE_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RULE-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "TXM_RULE_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RULE-LIST
                WHEN LS-CMD-ACTION(1:12) = "TXM_RULE_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RULE-GET
                WHEN LS-CMD-ACTION(1:8) = "TXM_POST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-POST
                WHEN LS-CMD-ACTION(1:11) = "TXM_REVERSE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REVERSE
                WHEN LS-CMD-ACTION(1:10) = "TXM_REPORT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REPORT
                WHEN LS-CMD-ACTION(1:11) = "TXM_SUMMARY"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUMMARY
                WHEN LS-CMD-ACTION(1:9) = "TXM_AUDIT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AUDIT
                WHEN LS-CMD-ACTION(1:12) = "TXM_VALIDATE"
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
        COPY "common_txn.cpy".

        AUDIT.
            MOVE "INSERT INTO tax_management_audit (tax_management_id, action, actor_email, detail, old_value, new_value) VALUES (NULLIF(?, ''), ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-TXM TO WS-BIND-1
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
            MOVE SPACES TO WS-AUDIT-TXM
            MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
            MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
            PERFORM AUDIT.
            EXIT PARAGRAPH.


        LOAD-CLEARING.
            MOVE SPACES TO WS-ERR
            MOVE "SELECT CONCAT(tax_type, '|', max_tax, '|', collected_tax, '|', status, '|', COALESCE(tax_name, ''), '|', '', '|', version) FROM tax_management WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM tax_management WHERE tax_ref = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "INSERT INTO tax_management (tax_ref, tax_name, tax_type, status, created_by) VALUES (?, ?, NULLIF(?, ''), 'OPEN', ?)" TO WS-PREP-SQL
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
                MOVE WS-NEW-ID TO WS-AUDIT-TXM
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
                MOVE SPACES TO WS-SUCCESS-MSG
                STRING "SUCCESS|TXM_CREATE|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-SUCCESS-MSG END-STRING
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-LIST.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
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
            MOVE "SELECT CONCAT(id, ':', tax_ref, ':', status, ':', max_tax, ':', collected_tax, ':', COALESCE(tax_name, '')) FROM tax_management WHERE (? = '' OR status = ?) AND (? = '' OR tax_name = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|TXM_LIST|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|TXM_LIST|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-GET.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(id, '|', tax_ref, '|', status, '|', max_tax, '|', collected_tax, '|', COALESCE(tax_name, ''), '|', COALESCE(tax_type, ''), '|', created_by, '|', created_at) FROM tax_management WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|TXM_GET|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-SUBMIT.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-TRIMMED NOT = SPACES
                PERFORM ACTION-CALC-TAX
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
            MOVE "UPDATE tax_management SET collected_tax = collected_tax + ?, status = 'ACTIVE', activated_at = COALESCE(activated_at, NOW()), version = version + 1 WHERE id = ? AND version = ? AND status = 'OPEN'" TO WS-PREP-SQL
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-TXM
                MOVE "allocated" TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE WS-TMP-AMT TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            MOVE "SUCCESS|TXM_CALC|1" TO WS-SUCCESS-MSG
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-UPDATE.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
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
            MOVE "UPDATE tax_management SET tax_name = COALESCE(NULLIF(?, ''), tax_name), tax_type = COALESCE(NULLIF(?, ''), tax_type), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-TXM
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-STATUS TO WS-AUDIT-OLD
                MOVE WS-P2-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            MOVE "SUCCESS|TXM_UPDATE" TO WS-SUCCESS-MSG
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-CLOSE.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
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
            MOVE "UPDATE tax_management SET status = 'INACTIVE', deactivated_at = NOW(), deactivate_reason = NULLIF(?, ''), deleted_at = NOW(), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-TXM
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE "ACTIVE" TO WS-AUDIT-OLD
                MOVE "INACTIVE" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            MOVE "SUCCESS|TXM_DELETE" TO WS-SUCCESS-MSG
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-RULE-CREATE.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-TMP-AMT WS-TMP-STR WS-TMP-ALLOCATED WS-TMP-ID
            UNSTRING WS-P4-TRIMMED DELIMITED BY ":" INTO
                WS-TMP-AMT WS-TMP-STR WS-TMP-ALLOCATED WS-TMP-ID
            END-UNSTRING
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-RATE
            MOVE FUNCTION NUMVAL(WS-TMP-STR) TO WS-NUM-FIXED
            MOVE FUNCTION NUMVAL(WS-TMP-ALLOCATED) TO WS-NUM-THRESH
            MOVE FUNCTION NUMVAL(WS-TMP-ID) TO WS-NUM-MAX
            IF WS-NUM-RATE < 0 OR WS-NUM-RATE > 100
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-NUM-FIXED < 0 OR WS-NUM-THRESH < 0 OR WS-NUM-MAX < 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM tax_management WHERE tax_ref = ? OR rule_code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) NOT = "ERROR"
                MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-RULE-CURR WS-RULE-GL WS-RULE-FROM WS-RULE-TO
            UNSTRING WS-P5-TRIMMED DELIMITED BY ":" INTO
                WS-RULE-CURR WS-RULE-GL WS-RULE-FROM WS-RULE-TO
            END-UNSTRING
            IF WS-RULE-CURR = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO tax_management (tax_ref, rule_code, tax_name, tax_type, status, created_by) VALUES (?, ?, ?, ?, 'OPEN', ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            MOVE WS-P2-TRIMMED TO WS-BIND-3
            MOVE WS-P3-TRIMMED TO WS-BIND-4
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
                MOVE "UPDATE tax_management SET max_tax = ?, rate_pct = ?, fixed_amount = ?, threshold_amount = ? WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-TMP-ID TO WS-BIND-1
                MOVE WS-TMP-AMT TO WS-BIND-2
                MOVE WS-TMP-STR TO WS-BIND-3
                MOVE WS-TMP-ALLOCATED TO WS-BIND-4
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-BIND-5
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
                MOVE "UPDATE tax_management SET currency = ?, gl_account_code = NULLIF(?, ''), effective_from = NULLIF(?, ''), effective_to = NULLIF(?, '') WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-RULE-CURR TO WS-BIND-1
                MOVE WS-RULE-GL TO WS-BIND-2
                MOVE WS-RULE-FROM TO WS-BIND-3
                MOVE WS-RULE-TO TO WS-BIND-4
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-BIND-5
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-FAIL
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF STEP-OK
                MOVE "RULE_CREATE" TO WS-AUDIT-ACTION
                MOVE WS-NEW-ID TO WS-AUDIT-TXM
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|TXM_RULE_CREATE|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-RULE-UPDATE.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT version FROM tax_management WHERE id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE WS-RESULT(1:10) TO WS-TMP-VERSION.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            IF WS-P2-TRIMMED NOT = SPACES
                MOVE SPACES TO WS-TMP-AMT WS-TMP-STR WS-TMP-ALLOCATED WS-TMP-ID
                UNSTRING WS-P2-TRIMMED DELIMITED BY ":" INTO
                    WS-TMP-AMT WS-TMP-STR WS-TMP-ALLOCATED WS-TMP-ID
                END-UNSTRING
                MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-RATE
                MOVE FUNCTION NUMVAL(WS-TMP-STR) TO WS-NUM-FIXED
                MOVE FUNCTION NUMVAL(WS-TMP-ALLOCATED) TO WS-NUM-THRESH
                MOVE FUNCTION NUMVAL(WS-TMP-ID) TO WS-NUM-MAX
                IF WS-NUM-RATE < 0 OR WS-NUM-RATE > 100
                    MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                    CALL "SQL_ROLLBACK" END-CALL
                    EXIT PARAGRAPH
                END-IF
                IF WS-NUM-FIXED < 0 OR WS-NUM-THRESH < 0 OR WS-NUM-MAX < 0
                    MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                    CALL "SQL_ROLLBACK" END-CALL
                    EXIT PARAGRAPH
                END-IF
                MOVE "UPDATE tax_management SET max_tax = ?, rate_pct = ?, fixed_amount = ?, threshold_amount = ?, version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
                MOVE WS-TMP-ID TO WS-BIND-1
                MOVE WS-TMP-AMT TO WS-BIND-2
                MOVE WS-TMP-STR TO WS-BIND-3
                MOVE WS-TMP-ALLOCATED TO WS-BIND-4
                MOVE WS-P1-TRIMMED TO WS-BIND-5
                MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-6
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK AND WS-P3-TRIMMED NOT = SPACES
                MOVE SPACES TO WS-RULE-CURR WS-RULE-GL WS-RULE-FROM WS-RULE-TO
                UNSTRING WS-P3-TRIMMED DELIMITED BY ":" INTO
                    WS-RULE-CURR WS-RULE-GL WS-RULE-FROM WS-RULE-TO
                END-UNSTRING
                MOVE "UPDATE tax_management SET currency = ?, gl_account_code = NULLIF(?, ''), effective_from = NULLIF(?, ''), effective_to = NULLIF(?, ''), version = version + 1 WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-RULE-CURR TO WS-BIND-1
                MOVE WS-RULE-GL TO WS-BIND-2
                MOVE WS-RULE-FROM TO WS-BIND-3
                MOVE WS-RULE-TO TO WS-BIND-4
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
            IF STEP-OK AND WS-P4-TRIMMED = "TRUE"
                MOVE "UPDATE tax_management SET enabled = TRUE, version = version + 1 WHERE id = ?" TO WS-PREP-SQL
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
            IF STEP-OK AND WS-P4-TRIMMED = "FALSE"
                MOVE "UPDATE tax_management SET enabled = FALSE, version = version + 1 WHERE id = ?" TO WS-PREP-SQL
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
                MOVE "RULE_UPDATE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-TXM
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|TXM_RULE_UPDATE|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RULE-LIST.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
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
            MOVE "SELECT CONCAT(id, ':', tax_ref, ':', status, ':', rate_pct, ':', COALESCE(tax_name, '')) FROM tax_management WHERE (? = '' OR status = ?) AND (? = '' OR tax_type = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|TXM_RULE_LIST|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|TXM_RULE_LIST|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RULE-GET.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(id, '|', tax_ref, '|', status, '|', rate_pct, '|', fixed_amount, '|', threshold_amount, '|', max_tax, '|', currency, '|', COALESCE(gl_account_code, ''), '|', COALESCE(CAST(effective_from AS CHAR), ''), '|', COALESCE(CAST(effective_to AS CHAR), ''), '|', IF(enabled, '1', '0')) FROM tax_management WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|TXM_RULE_GET|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-CALC-TAX.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P4-TRIMMED = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P4-TRIMMED) TO WS-NUM-BASE
            IF WS-NUM-BASE < 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P5-TRIMMED = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM tax_withholding_entry WHERE source_type = ? AND source_ref = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) NOT = "ERROR"
                MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(rate_pct, '|', fixed_amount, '|', threshold_amount, '|', max_tax, '|', currency, '|', COALESCE(gl_account_code, ''), '|', COALESCE(CAST(effective_from AS CHAR), ''), '|', COALESCE(CAST(effective_to AS CHAR), ''), '|', IF(enabled, '1', '0'), '|', status) FROM tax_management WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE SPACES TO WS-TMP-AMT WS-TMP-STR WS-TMP-ALLOCATED WS-TMP-ID
            MOVE SPACES TO WS-RULE-CURR WS-RULE-GL WS-RULE-FROM WS-RULE-TO
            MOVE SPACES TO WS-TMP-STATUS WS-TMP-CURR
            UNSTRING WS-RESULT DELIMITED BY "|" INTO
                WS-TMP-AMT WS-TMP-STR WS-TMP-ALLOCATED WS-TMP-ID WS-RULE-CURR WS-RULE-GL WS-RULE-FROM WS-RULE-TO WS-TMP-CURR WS-TMP-STATUS
            END-UNSTRING
            IF WS-TMP-CURR NOT = "1"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TMP-STATUS = "INACTIVE" OR WS-TMP-STATUS = "DELETED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RULE-FROM NOT = SPACES AND WS-P5-TRIMMED < WS-RULE-FROM
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RULE-TO NOT = SPACES AND WS-P5-TRIMMED > WS-RULE-TO
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-RATE
            MOVE FUNCTION NUMVAL(WS-TMP-STR) TO WS-NUM-FIXED
            MOVE FUNCTION NUMVAL(WS-TMP-ALLOCATED) TO WS-NUM-THRESH
            MOVE FUNCTION NUMVAL(WS-TMP-ID) TO WS-NUM-MAX
            IF WS-NUM-BASE < WS-NUM-THRESH
                MOVE 0 TO WS-NUM-TAX
            ELSE
                COMPUTE WS-NUM-TAX = WS-NUM-BASE * WS-NUM-RATE / 100 + WS-NUM-FIXED END-COMPUTE
            END-IF.
            IF WS-NUM-MAX > 0 AND WS-NUM-TAX > WS-NUM-MAX
                MOVE WS-NUM-MAX TO WS-NUM-TAX
            END-IF.
            MOVE WS-NUM-TAX TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-ALLOCATED
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO tax_withholding_entry (source_type, source_ref, base_amount, tax_amount, currency, rule_id, status, created_by) VALUES (?, ?, ?, ?, ?, ?, 'CALCULATED', ?)" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-TMP-ALLOCATED TO WS-BIND-4
            MOVE WS-P5-TRIMMED TO WS-BIND-5
            MOVE WS-P1-TRIMMED TO WS-BIND-6
            MOVE WS-P6-TRIMMED TO WS-BIND-7
            CALL "SQL_PREPARE_EXEC7" USING BY REFERENCE WS-PREP-SQL BY VALUE 7
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                BY REFERENCE WS-BIND-7 END-CALL
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
                MOVE "CALC" TO WS-AUDIT-ACTION
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-AUDIT-TXM
                MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE WS-TMP-ALLOCATED TO WS-AUDIT-NEW
                PERFORM AUDIT-TAX
            END-IF.
                MOVE SPACES TO WS-SUCCESS-MSG
                STRING "SUCCESS|TXM_CALC|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    "|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-ALLOCATED) DELIMITED BY SIZE
                    INTO WS-SUCCESS-MSG END-STRING
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-POST.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM tax_withholding_entry WHERE entry_id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE WS-RESULT(1:20) TO WS-ENTRY-STATUS.
            IF WS-ENTRY-STATUS NOT = "CALCULATED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            IF WS-P2-TRIMMED = SPACES
                MOVE "UPDATE tax_withholding_entry SET status = 'POSTED' WHERE entry_id = ? AND status = 'CALCULATED'" TO WS-PREP-SQL
                MOVE WS-P1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
            ELSE
                MOVE "UPDATE tax_withholding_entry SET status = 'POSTED', gl_journal_id = ? WHERE entry_id = ? AND status = 'CALCULATED'" TO WS-PREP-SQL
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
            MOVE "POST" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-TXM
            MOVE "CALCULATED" TO WS-AUDIT-OLD
            MOVE "POSTED" TO WS-AUDIT-NEW
            PERFORM AUDIT-TAX-ENTRY
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|TXM_POST|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-REVERSE.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM tax_withholding_entry WHERE entry_id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE WS-RESULT(1:20) TO WS-ENTRY-STATUS.
            IF WS-ENTRY-STATUS NOT = "POSTED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE tax_withholding_entry SET status = 'REVERSED', reversed_at = NOW(), reversal_reason = NULLIF(?, '') WHERE entry_id = ? AND status = 'POSTED'" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "0 rows affected" OR WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "REVERSE" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-TXM
            MOVE "POSTED" TO WS-AUDIT-OLD
            MOVE "REVERSED" TO WS-AUDIT-NEW
            PERFORM AUDIT-TAX-ENTRY
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|TXM_REVERSE|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        AUDIT-TAX.
            MOVE "INSERT INTO tax_audit (rule_id, action, actor_email, detail, old_value, new_value) VALUES (NULLIF(?, ''), ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-TXM TO WS-BIND-1
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

        AUDIT-TAX-ENTRY.
            MOVE "INSERT INTO tax_audit (entry_id, action, actor_email, detail, old_value, new_value) VALUES (NULLIF(?, ''), ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
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

        ACTION-REPORT.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(e.base_amount), 0), '|', COALESCE(SUM(e.tax_amount), 0)) FROM tax_withholding_entry e JOIN tax_management t ON t.id = e.rule_id WHERE DATE_FORMAT(e.created_at, '%Y-%m') = ? AND t.tax_type = ? AND e.currency = ? AND e.status = 'POSTED'" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "0|0|0" TO WS-RESULT
            END-IF.
            MOVE SPACES TO WS-TMP-AMT WS-TMP-STR WS-TMP-ALLOCATED
            UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-AMT WS-TMP-STR WS-TMP-ALLOCATED
            END-UNSTRING
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO tax_report_run (period, tax_type, total_base, total_tax, currency, status, created_by) VALUES (?, ?, ?, ?, ?, 'DRAFT', ?) ON DUPLICATE KEY UPDATE total_base = VALUES(total_base), total_tax = VALUES(total_tax), status = 'DRAFT'" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-TMP-STR TO WS-BIND-3
            MOVE WS-TMP-ALLOCATED TO WS-BIND-4
            MOVE WS-P3-TRIMMED TO WS-BIND-5
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
                MOVE "SELECT run_id FROM tax_report_run WHERE period = ? AND tax_type = ? AND currency = ? LIMIT 1" TO WS-PREP-SQL
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
                ELSE
                    MOVE WS-RESULT(1:20) TO WS-NEW-ID
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "REPORT" TO WS-AUDIT-ACTION
                MOVE WS-NEW-ID TO WS-AUDIT-TXM
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
                MOVE SPACES TO WS-SUCCESS-MSG
                STRING "SUCCESS|TXM_REPORT|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    "|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE
                    "|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-ALLOCATED) DELIMITED BY SIZE
                    INTO WS-SUCCESS-MSG END-STRING
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-SUMMARY.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'OPEN'), 0), '|', COALESCE(SUM(status = 'ACTIVE'), 0), '|', COALESCE(SUM(status = 'ALLOCATED'), 0), '|', COALESCE(SUM(status = 'CLOSED'), 0), '|', COALESCE(SUM(max_tax), 0), '|', COALESCE(SUM(collected_tax), 0)) FROM tax_management" TO WS-PREP-SQL
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
            STRING "SUCCESS|TXM_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-AUDIT.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
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
            MOVE "SELECT CONCAT(action, ':', actor_email, ':', COALESCE(detail, ''), ':', created_at) FROM tax_management_audit WHERE (? = '' OR tax_management_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|TXM_AUDIT|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|TXM_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-VALIDATE.
            MOVE "TAX_MANAGEMENT_CORE" TO WS-DENIED-TARGET
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
            STRING "SUCCESS|TXM_VALID|" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE
                "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.
