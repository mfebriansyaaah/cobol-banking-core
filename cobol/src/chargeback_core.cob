        IDENTIFICATION DIVISION.
        PROGRAM-ID. chargeback_core.
      *> Chargeback: create, allocate, close.

        ENVIRONMENT DIVISION.
        CONFIGURATION SECTION.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
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
        01  WS-AUDIT-CHB       PIC X(20) VALUE SPACES.
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
        01  WS-NUM-COUNT            PIC 9(9) VALUE 0.
        01  WS-CARD-STATUS          PIC X(20) VALUE SPACES.
        01  WS-CARD-AMT             PIC X(30) VALUE SPACES.
        01  WS-CARD-CURR            PIC X(10) VALUE SPACES.
        01  WS-CARD-ID              PIC X(20) VALUE SPACES.
        01  WS-CASE-STATUS          PIC X(20) VALUE SPACES.
        01  WS-CASE-AMT             PIC X(30) VALUE SPACES.
        01  WS-CASE-CURR            PIC X(10) VALUE SPACES.
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
                WHEN LS-CMD-ACTION(1:10) = "CHB_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CREATE
                WHEN LS-CMD-ACTION(1:8) = "CHB_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LIST
                WHEN LS-CMD-ACTION(1:7) = "CHB_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-GET
                WHEN LS-CMD-ACTION(1:10) = "CHB_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-UPDATE
                WHEN LS-CMD-ACTION(1:8) = "CHB_CALC"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUBMIT
                WHEN LS-CMD-ACTION(1:10) = "CHB_DELETE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLOSE
                WHEN LS-CMD-ACTION(1:8) = "CHB_OPEN"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-OPEN
                WHEN LS-CMD-ACTION(1:10) = "CHB_ASSIGN"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ASSIGN
                WHEN LS-CMD-ACTION(1:12) = "CHB_EVIDENCE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-EVIDENCE
                WHEN LS-CMD-ACTION(1:13) = "CHB_REPRESENT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REPRESENT
                WHEN LS-CMD-ACTION(1:10) = "CHB_ACCEPT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACCEPT
                WHEN LS-CMD-ACTION(1:10) = "CHB_REJECT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REJECT
                WHEN LS-CMD-ACTION(1:13) = "CHB_ARBITRATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ARBITRATE
                WHEN LS-CMD-ACTION(1:9) = "CHB_CLOSE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLOSE-CB
                WHEN LS-CMD-ACTION(1:11) = "CHB_SUMMARY"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUMMARY
                WHEN LS-CMD-ACTION(1:9) = "CHB_AUDIT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AUDIT
                WHEN LS-CMD-ACTION(1:12) = "CHB_VALIDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-VALIDATE
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
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-TICK.
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
                MOVE "CHARGEBACK_CORE" TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        AUDIT.
            MOVE "INSERT INTO chargeback_audit (chargeback_id, action, actor_email, detail, old_value, new_value) VALUES (NULLIF(?, ''), ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-CHB TO WS-BIND-1
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
            MOVE SPACES TO WS-AUDIT-CHB
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

        LOAD-CLEARING.
            MOVE SPACES TO WS-ERR
            MOVE "SELECT CONCAT(type, '|', budget_amount, '|', spent_amount, '|', status, '|', COALESCE(name, ''), '|', '', '|', version) FROM chargeback WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM chargeback WHERE cb_ref = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "INSERT INTO chargeback (cb_ref, name, type, status, created_by) VALUES (?, ?, NULLIF(?, ''), 'OPEN', ?)" TO WS-PREP-SQL
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
                MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
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
                MOVE "CREATE" TO WS-AUDIT-ACTION
                MOVE WS-NEW-ID TO WS-AUDIT-CHB
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|CHB_CREATE|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
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
            MOVE "SELECT CONCAT(id, ':', cb_ref, ':', status, ':', budget_amount, ':', spent_amount, ':', COALESCE(name, '')) FROM chargeback WHERE (? = '' OR status = ?) AND (? = '' OR name = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|CHB_LIST|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|CHB_LIST|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
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
            MOVE "SELECT CONCAT(id, '|', cb_ref, '|', status, '|', budget_amount, '|', spent_amount, '|', COALESCE(name, ''), '|', COALESCE(type, ''), '|', created_by, '|', created_at) FROM chargeback WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|CHB_GET|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-SUBMIT.
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
            MOVE "UPDATE chargeback SET spent_amount = spent_amount + ?, status = 'ACTIVE', activated_at = COALESCE(activated_at, NOW()), version = version + 1 WHERE id = ? AND version = ? AND status = 'OPEN'" TO WS-PREP-SQL
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
                MOVE "allocated" TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE WS-TMP-AMT TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CHB_CALC|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-UPDATE.
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
            MOVE "UPDATE chargeback SET name = COALESCE(NULLIF(?, ''), name), type = COALESCE(NULLIF(?, ''), type), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-STATUS TO WS-AUDIT-OLD
                MOVE WS-P2-TRIMMED TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CHB_UPDATE" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CLOSE.
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
            MOVE "UPDATE chargeback SET status = 'CLOSED', closed_at = NOW(), closure_reason = NULLIF(?, ''), deleted_at = NOW(), version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
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
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE "ACTIVE" TO WS-AUDIT-OLD
                MOVE "CLOSED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CHB_DELETE" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        LOAD-CASE.
            MOVE SPACES TO WS-ERR
            MOVE SPACES TO WS-CASE-STATUS WS-CASE-AMT WS-CASE-CURR WS-TMP-VERSION
            MOVE SPACES TO WS-TMP-ID WS-TMP-STR
            MOVE "SELECT CONCAT(status, '|', amount, '|', COALESCE(currency, ''), '|', COALESCE(CAST(card_transaction_id AS CHAR), ''), '|', COALESCE(CAST(merchant_id AS CHAR), ''), '|', version) FROM chargeback_case WHERE case_id = ? LIMIT 1" TO WS-PREP-SQL
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
            UNSTRING WS-RESULT DELIMITED BY "|" INTO
                WS-CASE-STATUS WS-CASE-AMT WS-CASE-CURR WS-TMP-ID WS-TMP-STR WS-TMP-VERSION
            END-UNSTRING
            MOVE FUNCTION NUMVAL(WS-TMP-VERSION) TO WS-NUM-VERSION
            EXIT PARAGRAPH.

        LEDGER-ADD.
      *> Expects WS-P1-TRIMMED = case id, WS-TMP-AMT = amount,
      *> WS-TMP-STATUS = entry type, WS-P6-TRIMMED = actor.
            MOVE "INSERT INTO chargeback_ledger (case_id, entry_type, amount, currency, created_by) VALUES (?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-TMP-STATUS TO WS-BIND-2
            MOVE WS-TMP-AMT TO WS-BIND-3
            MOVE WS-CASE-CURR TO WS-BIND-4
            MOVE WS-P6-TRIMMED TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        EVENT-ADD.
      *> Expects WS-P1-TRIMMED = case id, WS-AUDIT-ACTION = event type,
      *> WS-AUDIT-DETAIL = detail, WS-P6-TRIMMED = actor.
            MOVE "INSERT INTO chargeback_event (case_id, event_type, actor_email, detail) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
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

        ACTION-OPEN.
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
            MOVE "SELECT 1 FROM chargeback_case WHERE case_ref = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "SELECT CONCAT(status, '|', amount, '|', currency, '|', card_id) FROM card_transaction WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE SPACES TO WS-CARD-STATUS WS-CARD-AMT WS-CARD-CURR WS-CARD-ID
            UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-CARD-STATUS WS-CARD-AMT WS-CARD-CURR WS-CARD-ID
            END-UNSTRING
            IF WS-CARD-STATUS NOT = "CAPTURED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-CARD-AMT) TO WS-NUM-TOTAL
            IF WS-NUM-AMOUNT > WS-NUM-TOTAL
                MOVE "ERROR|LIMIT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P5-TRIMMED NOT = SPACES
                MOVE "SELECT 1 FROM merchant WHERE id = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-P5-TRIMMED TO WS-BIND-1
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
            END-IF.
            MOVE "SELECT 1 FROM chargeback_case WHERE card_transaction_id = ? AND status NOT IN ('CLOSED') LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
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
            MOVE "INSERT INTO chargeback_case (case_ref, card_transaction_id, amount, currency, status, opened_by) VALUES (?, ?, ?, ?, 'OPEN', ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-CARD-CURR TO WS-BIND-4
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
                MOVE "UPDATE chargeback_case SET card_id = NULLIF(?, ''), merchant_id = NULLIF(?, ''), reason_code = NULLIF(?, ''), deadline = CURDATE() + INTERVAL 30 DAY WHERE case_ref = ?" TO WS-PREP-SQL
                MOVE WS-CARD-ID TO WS-BIND-1
                MOVE WS-P5-TRIMMED TO WS-BIND-2
                MOVE WS-P4-TRIMMED TO WS-BIND-3
                MOVE WS-P1-TRIMMED TO WS-BIND-4
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
                MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
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
                MOVE WS-P1-TRIMMED TO WS-TMP-STR
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-P1-TRIMMED
            END-IF.
            IF STEP-OK
                MOVE WS-P3-TRIMMED TO WS-TMP-AMT
                MOVE "HOLD" TO WS-TMP-STATUS
                MOVE WS-CARD-CURR TO WS-CASE-CURR
                PERFORM LEDGER-ADD
            END-IF.
            IF STEP-OK
                MOVE "OPENED" TO WS-AUDIT-ACTION
                MOVE WS-TMP-STR TO WS-AUDIT-DETAIL
                PERFORM EVENT-ADD
            END-IF.
            IF STEP-OK
                MOVE "OPEN" TO WS-AUDIT-ACTION
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-AUDIT-CHB
                MOVE WS-TMP-STR TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|CHB_OPEN|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ASSIGN.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CASE
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-CASE-STATUS = "CLOSED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE chargeback_case SET assigned_to = ? WHERE case_id = ?" TO WS-PREP-SQL
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
            MOVE "ASSIGN" TO WS-AUDIT-ACTION
            MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
            MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
            PERFORM AUDIT
            MOVE "ASSIGNED" TO WS-AUDIT-ACTION
            PERFORM EVENT-ADD
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|CHB_ASSIGN|1" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        ACTION-EVIDENCE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CASE
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-CASE-STATUS NOT = "OPEN" AND WS-CASE-STATUS NOT = "EVIDENCE_REQUIRED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO chargeback_evidence (case_id, evidence_type, document_ref, note, submitted_by) VALUES (?, ?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
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
                MOVE "UPDATE chargeback_case SET status = 'EVIDENCE_REQUIRED', version = version + 1 WHERE case_id = ?" TO WS-PREP-SQL
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
                MOVE "EVIDENCE_ADDED" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM EVENT-ADD
            END-IF.
            IF STEP-OK
                MOVE "EVIDENCE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
                MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CHB_EVIDENCE|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-REPRESENT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CASE
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-CASE-STATUS NOT = "EVIDENCE_REQUIRED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT COUNT(*) FROM chargeback_evidence WHERE case_id = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA" OR WS-RESULT = "0"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT deadline FROM chargeback_case WHERE case_id = ? AND (deadline IS NULL OR deadline >= CURDATE()) LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE chargeback_case SET status = 'REPRESENTED', version = version + 1 WHERE case_id = ? AND status = 'EVIDENCE_REQUIRED'" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "0 rows affected" OR WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "REPRESENTED" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM EVENT-ADD
            END-IF.
            IF STEP-OK
                MOVE "REPRESENT" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
                MOVE "EVIDENCE_REQUIRED" TO WS-AUDIT-OLD
                MOVE "REPRESENTED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CHB_REPRESENT|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                ELSE
                    IF WS-RESULT = "0 rows affected"
                        MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                    END-IF
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACCEPT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CASE
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-CASE-STATUS NOT = "REPRESENTED" AND WS-CASE-STATUS NOT = "OPEN"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-CASE-AMT) TO WS-NUM-AMOUNT
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE chargeback_case SET status = 'ACCEPTED', version = version + 1 WHERE case_id = ?" TO WS-PREP-SQL
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
                MOVE WS-CASE-AMT TO WS-TMP-AMT
                MOVE "DEBIT" TO WS-TMP-STATUS
                PERFORM LEDGER-ADD
            END-IF.
            IF STEP-OK AND WS-P2-TRIMMED NOT = SPACES
                MOVE "UPDATE chargeback_ledger SET gl_journal_id = ? WHERE entry_id = (SELECT MAX(entry_id) FROM chargeback_ledger WHERE case_id = ? AND entry_type = 'DEBIT')" TO WS-PREP-SQL
                MOVE WS-P2-TRIMMED TO WS-BIND-1
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
                MOVE "ACCEPTED" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM EVENT-ADD
            END-IF.
            IF STEP-OK
                MOVE "ACCEPT" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
                MOVE WS-CASE-STATUS TO WS-AUDIT-OLD
                MOVE "ACCEPTED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CHB_ACCEPT|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-REJECT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CASE
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-CASE-STATUS NOT = "REPRESENTED" AND WS-CASE-STATUS NOT = "OPEN"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-CASE-AMT) TO WS-NUM-AMOUNT
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE chargeback_case SET status = 'REJECTED', version = version + 1 WHERE case_id = ?" TO WS-PREP-SQL
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
                MOVE WS-CASE-AMT TO WS-TMP-AMT
                MOVE "RELEASE" TO WS-TMP-STATUS
                PERFORM LEDGER-ADD
            END-IF.
            IF STEP-OK
                MOVE "REJECTED" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM EVENT-ADD
            END-IF.
            IF STEP-OK
                MOVE "REJECT" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
                MOVE WS-CASE-STATUS TO WS-AUDIT-OLD
                MOVE "REJECTED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CHB_REJECT|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ARBITRATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CASE
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-CASE-STATUS NOT = "REJECTED" AND WS-CASE-STATUS NOT = "REPRESENTED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE chargeback_case SET status = 'ARBITRATION', version = version + 1 WHERE case_id = ?" TO WS-PREP-SQL
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
                MOVE "ARBITRATION" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM EVENT-ADD
            END-IF.
            IF STEP-OK
                MOVE "ARBITRATE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
                MOVE WS-CASE-STATUS TO WS-AUDIT-OLD
                MOVE "ARBITRATION" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CHB_ARBITRATE|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CLOSE-CB.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-CASE
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-CASE-STATUS = "CLOSED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-CASE-STATUS = "OPEN" OR WS-CASE-STATUS = "EVIDENCE_REQUIRED"
                OR WS-CASE-STATUS = "REPRESENTED"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE chargeback_case SET status = 'CLOSED', closed_at = NOW(), resolution = NULLIF(?, ''), version = version + 1 WHERE case_id = ?" TO WS-PREP-SQL
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
                MOVE "CLOSED" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                PERFORM EVENT-ADD
            END-IF.
            IF STEP-OK
                MOVE "CLOSE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-CHB
                MOVE WS-CASE-STATUS TO WS-AUDIT-OLD
                MOVE "CLOSED" TO WS-AUDIT-NEW
                PERFORM AUDIT
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|CHB_CLOSE|1" TO LS-OUTPUT-BUFFER
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
            MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'OPEN'), 0), '|', COALESCE(SUM(status = 'ACTIVE'), 0), '|', COALESCE(SUM(status = 'ALLOCATED'), 0), '|', COALESCE(SUM(status = 'CLOSED'), 0), '|', COALESCE(SUM(budget_amount), 0), '|', COALESCE(SUM(spent_amount), 0)) FROM chargeback" TO WS-PREP-SQL
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
            STRING "SUCCESS|CHB_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-AUDIT.
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
            MOVE "SELECT CONCAT(action, ':', actor_email, ':', COALESCE(detail, ''), ':', created_at) FROM chargeback_audit WHERE (? = '' OR chargeback_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|CHB_AUDIT|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|CHB_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-VALIDATE.
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
            STRING "SUCCESS|CHB_VALID|" DELIMITED BY SIZE FUNCTION TRIM(WS-P1-TRIMMED) DELIMITED BY SIZE
                "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.
