>>SOURCE FORMAT IS FREE
        IDENTIFICATION DIVISION.
        PROGRAM-ID. report_schedule_core IS INITIAL.
      *> Report Schedule: create, allocate, close.

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
        01  WS-AUDIT-RPS       PIC X(20) VALUE SPACES.
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

            MOVE SPACES TO LS-OUTPUT-BUFFER
            MOVE SPACES TO WS-ERR
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:10) = "RPS_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CREATE
                WHEN LS-CMD-ACTION(1:8) = "RPS_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LIST
                WHEN LS-CMD-ACTION(1:7) = "RPS_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-GET
                WHEN LS-CMD-ACTION(1:10) = "RPS_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-UPDATE
                WHEN LS-CMD-ACTION(1:10) = "RPS_ENABLE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ENABLE
                WHEN LS-CMD-ACTION(1:11) = "RPS_DISABLE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DISABLE
                WHEN LS-CMD-ACTION(1:11) = "RPS_RUN_NOW"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RUN-NOW
                WHEN LS-CMD-ACTION(1:11) = "RPS_SUMMARY"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUMMARY
                WHEN LS-CMD-ACTION(1:9) = "RPS_AUDIT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AUDIT
                WHEN LS-CMD-ACTION(1:12) = "RPS_VALIDATE"
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
        COPY "sql_exec_6.cpy".

        AUDIT.
            MOVE "INSERT INTO rpt_schedule_config_audit (rpt_schedule_config_id, action, actor_email, detail, old_value, new_value) VALUES (NULLIF(?, ''), ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-RPS TO WS-BIND-1
            MOVE WS-AUDIT-ACTION TO WS-BIND-2
            MOVE WS-P6-TRIMMED TO WS-BIND-3
            MOVE WS-AUDIT-DETAIL TO WS-BIND-4
            MOVE WS-AUDIT-OLD TO WS-BIND-5
            MOVE WS-AUDIT-NEW TO WS-BIND-6
            PERFORM SQL-EXEC-6
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            MOVE "AUTHZ_DENIED" TO WS-AUDIT-ACTION
            MOVE SPACES TO WS-AUDIT-RPS
            MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
            MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
            PERFORM AUDIT.
            EXIT PARAGRAPH.


        LOAD-CLEARING.
            MOVE SPACES TO WS-ERR
            MOVE "SELECT CONCAT(schedule_type, '|', max_instances, '|', run_count, '|', status, '|', COALESCE(schedule_name, ''), '|', '', '|', version) FROM rpt_schedule_config WHERE id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            PERFORM SQL-EXEC-1
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
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P4-TRIMMED NOT = SPACES
                PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-P4-LEN
                    IF WS-P4-TRIMMED(WS-I:1) < "0" OR WS-P4-TRIMMED(WS-I:1) > "9"
                        MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                        EXIT PARAGRAPH
                    END-IF
                END-PERFORM
                MOVE FUNCTION NUMVAL(WS-P4-TRIMMED) TO WS-NUM-AMOUNT
                IF WS-NUM-AMOUNT <= 0
                    MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            MOVE "SELECT 1 FROM rpt_schedule_config WHERE schedule_ref = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            PERFORM SQL-EXEC-1
            IF WS-RESULT(1:5) NOT = "ERROR"
                MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            PERFORM TXN-BEGIN
            IF STEP-FAIL
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                EXIT PARAGRAPH
            END-IF
            MOVE "INSERT INTO rpt_schedule_config (schedule_ref, schedule_name, schedule_type, max_instances, status, created_by) VALUES (?, ?, NULLIF(?, ''), COALESCE(NULLIF(?, ''), 0), 'OPEN', ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            MOVE WS-P6-TRIMMED TO WS-BIND-5
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
                MOVE "CREATE" TO WS-AUDIT-ACTION
                MOVE WS-NEW-ID TO WS-AUDIT-RPS
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
                MOVE SPACES TO WS-SUCCESS-MSG
                STRING "SUCCESS|RPS_CREATE|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-SUCCESS-MSG ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-LIST.
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
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
            MOVE "SELECT CONCAT(id, ':', schedule_ref, ':', status, ':', max_instances, ':', run_count, ':', COALESCE(schedule_name, '')) FROM rpt_schedule_config WHERE (? = '' OR status = ?) AND (? = '' OR schedule_name = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|RPS_LIST|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|RPS_LIST|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-GET.
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(id, '|', schedule_ref, '|', status, '|', max_instances, '|', run_count, '|', COALESCE(schedule_name, ''), '|', COALESCE(schedule_type, ''), '|', created_by, '|', created_at) FROM rpt_schedule_config WHERE id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            PERFORM SQL-EXEC-1
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
            STRING "SUCCESS|RPS_GET|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING.
            EXIT PARAGRAPH.

        ACTION-ENABLE.
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
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
            IF WS-TMP-STATUS = "ACTIVE" OR WS-TMP-STATUS = "CLOSED" OR WS-TMP-STATUS = "DELETED"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            PERFORM TXN-BEGIN
            IF STEP-FAIL
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE rpt_schedule_config SET status = 'ACTIVE', activated_at = NOW(), version = version + 1 WHERE id = ? AND version = ? AND (status = 'OPEN' OR status = 'INACTIVE')" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-2
            PERFORM SQL-EXEC-2
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT = "SUCCESS|AFFECTED_0" OR WS-RESULT = "ERROR|NO_DATA"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "ENABLE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RPS
                MOVE SPACES TO WS-AUDIT-DETAIL
                MOVE WS-TMP-STATUS TO WS-AUDIT-OLD
                MOVE "ACTIVE" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            MOVE SPACES TO WS-SUCCESS-MSG
            STRING "SUCCESS|RPS_ENABLE|" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE INTO WS-SUCCESS-MSG ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-DISABLE.
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CLEARING
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TMP-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            PERFORM TXN-BEGIN
            IF STEP-FAIL
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE rpt_schedule_config SET status = 'INACTIVE', deactivated_at = NOW(), deactivate_reason = ?, version = version + 1 WHERE id = ? AND version = ? AND status = 'ACTIVE'" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-3
            PERFORM SQL-EXEC-3
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT = "SUCCESS|AFFECTED_0" OR WS-RESULT = "ERROR|NO_DATA"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "DISABLE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RPS
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE "ACTIVE" TO WS-AUDIT-OLD
                MOVE "INACTIVE" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            MOVE SPACES TO WS-SUCCESS-MSG
            STRING "SUCCESS|RPS_DISABLE|" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE INTO WS-SUCCESS-MSG ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-RUN-NOW.
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
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
            IF WS-TMP-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-TMP-STR) TO WS-NUM-ACTIVE
            MOVE FUNCTION NUMVAL(WS-TMP-ALLOCATED) TO WS-NUM-ALLOCATED
            IF WS-NUM-ALLOCATED >= WS-NUM-ACTIVE
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            PERFORM TXN-BEGIN
            IF STEP-FAIL
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE rpt_schedule_config SET run_count = run_count + 1, version = version + 1 WHERE id = ? AND version = ? AND status = 'ACTIVE'" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-2
            PERFORM SQL-EXEC-2
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT = "SUCCESS|AFFECTED_0" OR WS-RESULT = "ERROR|NO_DATA"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "RUN_NOW" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RPS
                MOVE "manual run" TO WS-AUDIT-DETAIL
                MOVE "ACTIVE" TO WS-AUDIT-OLD
                MOVE "ACTIVE" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            MOVE SPACES TO WS-SUCCESS-MSG
            STRING "SUCCESS|RPS_RUN_NOW|" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE INTO WS-SUCCESS-MSG ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-UPDATE.
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
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
            PERFORM TXN-BEGIN
            IF STEP-FAIL
                MOVE "ERROR|DB_ERROR" TO WS-ERR
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE rpt_schedule_config SET schedule_name = COALESCE(NULLIF(?, ''), schedule_name), schedule_type = COALESCE(NULLIF(?, ''), schedule_type), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P1-TRIMMED TO WS-BIND-3
            MOVE FUNCTION TRIM(WS-TMP-VERSION) TO WS-BIND-4
            PERFORM SQL-EXEC-4
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RPS
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-STATUS TO WS-AUDIT-OLD
                MOVE WS-P2-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            MOVE "SUCCESS|RPS_UPDATE" TO WS-SUCCESS-MSG
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-SUMMARY.
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
            PERFORM ADMIN-GUARD
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'OPEN'), 0), '|', COALESCE(SUM(status = 'ACTIVE'), 0), '|', COALESCE(SUM(status = 'ALLOCATED'), 0), '|', COALESCE(SUM(status = 'CLOSED'), 0), '|', COALESCE(SUM(max_instances), 0), '|', COALESCE(SUM(run_count), 0)) FROM rpt_schedule_config" TO WS-PREP-SQL
            PERFORM SQL-EXEC-0
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|RPS_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING.
            EXIT PARAGRAPH.

        ACTION-AUDIT.
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
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
            MOVE "SELECT CONCAT(action, ':', actor_email, ':', COALESCE(detail, ''), ':', created_at) FROM rpt_schedule_config_audit WHERE (? = '' OR rpt_schedule_config_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            MOVE WS-LIMIT TO WS-BIND-3
            MOVE WS-OFFSET TO WS-BIND-4
            PERFORM SQL-EXEC-4
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|RPS_AUDIT|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|RPS_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-VALIDATE.
            MOVE "REPORT_SCHEDULE_CORE" TO WS-DENIED-TARGET
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
            STRING "SUCCESS|RPS_VALID|" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE
                "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING.
            EXIT PARAGRAPH.
       END PROGRAM report_schedule_core.
