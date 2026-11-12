        IDENTIFICATION DIVISION.
        PROGRAM-ID. loyalty_core.
      *> Loyalty: program/member/ledger/redemption + GL link.

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
        01  WS-AUDIT-MEM            PIC X(20) VALUE SPACES.
        01  WS-AUDIT-PROG           PIC X(20) VALUE SPACES.
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
        01  WS-MEM-VERSION            PIC X(10) VALUE SPACES.
        01  WS-PROG-VERSION           PIC X(10) VALUE SPACES.
        01  WS-NEW-ID               PIC X(20) VALUE SPACES.
        01  WS-PROG-ID              PIC X(20) VALUE SPACES.
        01  WS-MEM-STATUS           PIC X(20) VALUE SPACES.
        01  WS-PROG-STATUS          PIC X(20) VALUE SPACES.
        01  WS-MEM-PROGID           PIC X(20) VALUE SPACES.
        01  WS-SRC-TYPE             PIC X(20) VALUE SPACES.
        01  WS-SRC-REF              PIC X(50) VALUE SPACES.
        01  WS-NUM-AMOUNT           PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-POINTS           PIC S9(15)V9(4) VALUE 0.
        01  WS-NUM-BAL              PIC 9(15)V9(4) VALUE 0.
        01  WS-NUM-EARN             PIC 9(5)V9(4) VALUE 0.
        01  WS-NUM-BURN             PIC 9(5)V9(4) VALUE 0.
        01  WS-NUM-VERSION          PIC 9(9) VALUE 0.
        01  WS-NUM-TOTAL            PIC 9(15)V9(4) VALUE 0.
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
                WHEN LS-CMD-ACTION(1:10) = "LOY_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CREATE
                WHEN LS-CMD-ACTION(1:8) = "LOY_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LIST
                WHEN LS-CMD-ACTION(1:7) = "LOY_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-GET
                WHEN LS-CMD-ACTION(1:12) = "LOY_ACTIVATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACTIVATE
                WHEN LS-CMD-ACTION(1:10) = "LOY_ENROLL"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ENROLL
                WHEN LS-CMD-ACTION(1:8) = "LOY_EARN"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-EARN
                WHEN LS-CMD-ACTION(1:10) = "LOY_REDEEM"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REDEEM
                WHEN LS-CMD-ACTION(1:10) = "LOY_EXPIRE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-EXPIRE
                WHEN LS-CMD-ACTION(1:10) = "LOY_ADJUST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ADJUST
                WHEN LS-CMD-ACTION(1:11) = "LOY_SUMMARY"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUMMARY
                WHEN LS-CMD-ACTION(1:9) = "LOY_AUDIT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AUDIT
                WHEN LS-CMD-ACTION(1:12) = "LOY_VALIDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-VALIDATE
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        COPY "common_validate_all.cpy".
        COPY "common_sql.cpy".


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

        COPY "common_auth.cpy".

        AUDIT.
            MOVE "INSERT INTO loyalty_audit (member_id, action, actor_email, detail, old_value, new_value) VALUES (NULLIF(?, ''), ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-MEM TO WS-BIND-1
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
            END-IF
            IF STEP-OK
                IF WS-AUDIT-PROG NOT = SPACES
                    MOVE "UPDATE loyalty_audit SET program_id = ? WHERE id = LAST_INSERT_ID()" TO WS-PREP-SQL
                    MOVE WS-AUDIT-PROG TO WS-BIND-1
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                    END-CALL
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                    IF WS-RESULT(1:5) = "ERROR"
                        SET STEP-FAIL TO TRUE
                    END-IF
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            MOVE "AUTHZ_DENIED" TO WS-AUDIT-ACTION
            MOVE SPACES TO WS-AUDIT-MEM
            MOVE SPACES TO WS-AUDIT-PROG
            MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
            MOVE SPACES TO WS-AUDIT-OLD
            MOVE WS-DENIED-ACTOR TO WS-AUDIT-NEW
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

        LOAD-PROGRAM.
            MOVE SPACES TO WS-ERR
            MOVE SPACES TO WS-PROG-STATUS
            MOVE 0 TO WS-NUM-EARN WS-NUM-BURN WS-NUM-VERSION
            MOVE "SELECT CONCAT(status, '|', earn_rate, '|', burn_rate, '|', COALESCE(currency, ''), '|', version) FROM loyalty_program WHERE id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PROG-ID TO WS-BIND-1
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
                WS-PROG-STATUS WS-TMP-AMT WS-TMP-STR WS-TMP-CURR WS-PROG-VERSION
            END-UNSTRING
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-EARN
            MOVE FUNCTION NUMVAL(WS-TMP-STR) TO WS-NUM-BURN
            MOVE FUNCTION NUMVAL(WS-PROG-VERSION) TO WS-NUM-VERSION
            EXIT PARAGRAPH.

        LOAD-MEMBER.
            MOVE SPACES TO WS-ERR
            MOVE SPACES TO WS-MEM-STATUS WS-MEM-PROGID
            MOVE 0 TO WS-NUM-BAL WS-NUM-VERSION
            MOVE "SELECT CONCAT(status, '|', points_balance, '|', program_id, '|', version) FROM loyalty_member WHERE member_id = ? LIMIT 1" TO WS-PREP-SQL
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
                WS-MEM-STATUS WS-TMP-AMT WS-TMP-ID WS-MEM-VERSION
            END-UNSTRING
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-BAL
            MOVE WS-TMP-ID TO WS-MEM-PROGID
            MOVE FUNCTION NUMVAL(WS-MEM-VERSION) TO WS-NUM-VERSION
            EXIT PARAGRAPH.

        ACTION-CREATE.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES OR LS-PARAM5 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-TMP-AMT WS-TMP-STR WS-TMP-CURR
            UNSTRING WS-P3-TRIMMED DELIMITED BY ":" INTO
                WS-TMP-AMT WS-TMP-STR WS-TMP-CURR
            END-UNSTRING
            MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-POINTS
            IF WS-NUM-POINTS < 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-NUM-POINTS TO WS-NUM-EARN
            MOVE FUNCTION NUMVAL(WS-TMP-STR) TO WS-NUM-POINTS
            IF WS-NUM-POINTS < 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-NUM-POINTS TO WS-NUM-BURN
            IF WS-NUM-EARN < 0 OR WS-NUM-BURN < 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-TMP-ALLOCATED WS-TMP-ID
            UNSTRING WS-P4-TRIMMED DELIMITED BY ":" INTO
                WS-TMP-ALLOCATED WS-TMP-ID
            END-UNSTRING
            MOVE "SELECT 1 FROM loyalty_program WHERE program_code = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "INSERT INTO loyalty_program (loyalty_ref, program_code, name, type, status, created_by) VALUES (?, ?, ?, ?, 'DRAFT', ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P1-TRIMMED TO WS-BIND-2
            MOVE WS-P2-TRIMMED TO WS-BIND-3
            MOVE WS-P5-TRIMMED TO WS-BIND-4
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
                MOVE "UPDATE loyalty_program SET earn_rate = ?, burn_rate = ?, currency = NULLIF(?, '') WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-TMP-AMT TO WS-BIND-1
                MOVE WS-TMP-STR TO WS-BIND-2
                MOVE WS-TMP-CURR TO WS-BIND-3
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-BIND-4
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
                MOVE "UPDATE loyalty_program SET start_date = NULLIF(?, ''), end_date = NULLIF(?, '') WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-TMP-ALLOCATED TO WS-BIND-1
                MOVE WS-TMP-ID TO WS-BIND-2
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-BIND-3
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
                MOVE "CREATE" TO WS-AUDIT-ACTION
                MOVE SPACES TO WS-AUDIT-MEM
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-AUDIT-PROG
                MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE "DRAFT" TO WS-AUDIT-NEW
                PERFORM AUDIT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|LOY_CREATE|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACTIVATE.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-P1-TRIMMED TO WS-PROG-ID
            PERFORM LOAD-PROGRAM
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PROG-STATUS NOT = "DRAFT"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE loyalty_program SET status = 'ACTIVE', version = version + 1 WHERE id = ? AND version = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE FUNCTION TRIM(WS-PROG-VERSION) TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ACTIVATE" TO WS-AUDIT-ACTION
                MOVE SPACES TO WS-AUDIT-MEM
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-PROG
                MOVE "DRAFT" TO WS-AUDIT-OLD
                MOVE "ACTIVE" TO WS-AUDIT-NEW
                MOVE "activate" TO WS-AUDIT-DETAIL
                PERFORM AUDIT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|LOY_ACTIVATE|1" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ENROLL.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-P1-TRIMMED TO WS-PROG-ID
            PERFORM LOAD-PROGRAM
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PROG-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM customer WHERE customer_ref = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE "SELECT 1 FROM loyalty_member WHERE program_id = ? AND customer_ref = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) NOT = "ERROR"
                MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-TRIMMED = SPACES
                MOVE "STANDARD" TO WS-TMP-STR
            ELSE
                MOVE WS-P3-TRIMMED TO WS-TMP-STR
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO loyalty_member (program_id, customer_ref, tier, status) VALUES (?, ?, ?, 'ACTIVE')" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-TMP-STR TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
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
                MOVE "ENROLL" TO WS-AUDIT-ACTION
                MOVE FUNCTION TRIM(WS-NEW-ID) TO WS-AUDIT-MEM
                MOVE WS-P1-TRIMMED TO WS-AUDIT-PROG
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE SPACES TO WS-AUDIT-OLD
                MOVE "ACTIVE" TO WS-AUDIT-NEW
                PERFORM AUDIT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|LOY_ENROLL|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-EARN.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-TRIMMED NOT = "CARD_TXN" AND WS-P2-TRIMMED NOT = "PAYMENT" AND WS-P2-TRIMMED NOT = "CAMPAIGN"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-MEMBER
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-MEM-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-TMP-AMT TO WS-AUDIT-OLD
            MOVE WS-MEM-PROGID TO WS-PROG-ID
            PERFORM LOAD-PROGRAM
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PROG-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P4-TRIMMED) TO WS-NUM-POINTS
            IF WS-NUM-POINTS <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-NUM-POINTS TO WS-NUM-AMOUNT
            MOVE "SELECT 1 FROM loyalty_points_ledger WHERE member_id = ? AND source_type = ? AND source_ref = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) NOT = "ERROR"
                MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            COMPUTE WS-NUM-POINTS = WS-NUM-AMOUNT * WS-NUM-EARN END-COMPUTE
            IF WS-NUM-POINTS <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-NUM-POINTS TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-STR
            COMPUTE WS-NUM-BAL = WS-NUM-BAL + WS-NUM-POINTS END-COMPUTE
            MOVE WS-NUM-BAL TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-ALLOCATED
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO loyalty_points_ledger (member_id, source_type, source_ref, points_delta, balance_after, created_by) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-TMP-STR TO WS-BIND-4
            MOVE WS-TMP-ALLOCATED TO WS-BIND-5
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
                IF WS-P5-TRIMMED NOT = SPACES
                    MOVE "UPDATE loyalty_points_ledger SET expires_at = ? WHERE member_id = ? AND source_type = ? AND source_ref = ?" TO WS-PREP-SQL
                    MOVE WS-P5-TRIMMED TO WS-BIND-1
                    MOVE WS-P1-TRIMMED TO WS-BIND-2
                    MOVE WS-P2-TRIMMED TO WS-BIND-3
                    MOVE WS-P3-TRIMMED TO WS-BIND-4
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
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
                MOVE "UPDATE loyalty_member SET points_balance = ?, version = version + 1 WHERE member_id = ? AND version = ?" TO WS-PREP-SQL
                MOVE WS-TMP-ALLOCATED TO WS-BIND-1
                MOVE WS-P1-TRIMMED TO WS-BIND-2
                MOVE FUNCTION TRIM(WS-MEM-VERSION) TO WS-BIND-3
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
                MOVE "EARN" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-MEM
                MOVE WS-MEM-PROGID TO WS-AUDIT-PROG
                MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-ALLOCATED TO WS-AUDIT-NEW
                PERFORM AUDIT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|LOY_EARN|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-REDEEM.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-MEMBER
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-MEM-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-TMP-AMT TO WS-AUDIT-OLD
            MOVE WS-MEM-PROGID TO WS-PROG-ID
            PERFORM LOAD-PROGRAM
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PROG-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-POINTS
            IF WS-NUM-POINTS <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-NUM-POINTS > WS-NUM-BAL
                MOVE "ERROR|LIMIT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            COMPUTE WS-NUM-BAL = WS-NUM-BAL - WS-NUM-POINTS END-COMPUTE
            MOVE WS-NUM-BAL TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-ALLOCATED
            COMPUTE WS-NUM-TOTAL = 0 - WS-NUM-POINTS END-COMPUTE
            MOVE WS-NUM-TOTAL TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-STR
            MOVE SPACES TO WS-TMP-ID
            STRING "-" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE
                INTO WS-TMP-ID END-STRING
            MOVE FUNCTION TRIM(WS-TMP-ID) TO WS-TMP-STR
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO loyalty_redemption (member_id, points, reward_code, status, gl_journal_id) VALUES (?, ?, ?, 'APPROVED', NULLIF(?, ''))" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
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
                MOVE SPACES TO WS-SRC-REF
                STRING "RDM-" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    INTO WS-SRC-REF END-STRING
                MOVE "REDEMPTION" TO WS-SRC-TYPE
                MOVE "INSERT INTO loyalty_points_ledger (member_id, source_type, source_ref, points_delta, balance_after, created_by) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
                MOVE WS-P1-TRIMMED TO WS-BIND-1
                MOVE WS-SRC-TYPE TO WS-BIND-2
                MOVE FUNCTION TRIM(WS-SRC-REF) TO WS-BIND-3
                MOVE WS-TMP-STR TO WS-BIND-4
                MOVE WS-TMP-ALLOCATED TO WS-BIND-5
                MOVE WS-P6-TRIMMED TO WS-BIND-6
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "UPDATE loyalty_member SET points_balance = ?, version = version + 1 WHERE member_id = ? AND version = ?" TO WS-PREP-SQL
                MOVE WS-TMP-ALLOCATED TO WS-BIND-1
                MOVE WS-P1-TRIMMED TO WS-BIND-2
                MOVE FUNCTION TRIM(WS-MEM-VERSION) TO WS-BIND-3
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
                MOVE "REDEEM" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-MEM
                MOVE WS-MEM-PROGID TO WS-AUDIT-PROG
                MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-ALLOCATED TO WS-AUDIT-NEW
                PERFORM AUDIT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|LOY_REDEEM|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-EXPIRE.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-MEMBER
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-MEM-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT COALESCE(SUM(points_delta), 0) FROM loyalty_points_ledger WHERE member_id = ? AND reversed_at IS NULL AND source_type IN ('CARD_TXN', 'PAYMENT', 'CAMPAIGN') AND expires_at IS NOT NULL AND expires_at <= ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-RESULT) TO WS-NUM-POINTS
            IF WS-NUM-POINTS <= 0
                MOVE "SUCCESS|LOY_EXPIRE|0" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-NUM-POINTS > WS-NUM-BAL
                MOVE "ERROR|LIMIT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-TMP-AMT TO WS-AUDIT-OLD
            COMPUTE WS-NUM-BAL = WS-NUM-BAL - WS-NUM-POINTS END-COMPUTE
            MOVE WS-NUM-BAL TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-ALLOCATED
            COMPUTE WS-NUM-TOTAL = 0 - WS-NUM-POINTS END-COMPUTE
            MOVE WS-NUM-TOTAL TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-STR
            MOVE SPACES TO WS-TMP-ID
            STRING "-" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE
                INTO WS-TMP-ID END-STRING
            MOVE FUNCTION TRIM(WS-TMP-ID) TO WS-TMP-STR
            MOVE SPACES TO WS-SRC-REF
            STRING "EXP-" DELIMITED BY SIZE WS-P2-TRIMMED DELIMITED BY SIZE
                INTO WS-SRC-REF END-STRING
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE loyalty_points_ledger SET reversed_at = NOW() WHERE member_id = ? AND reversed_at IS NULL AND source_type IN ('CARD_TXN', 'PAYMENT', 'CAMPAIGN') AND expires_at IS NOT NULL AND expires_at <= ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "EXPIRY" TO WS-SRC-TYPE
                MOVE "INSERT INTO loyalty_points_ledger (member_id, source_type, source_ref, points_delta, balance_after, created_by) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
                MOVE WS-P1-TRIMMED TO WS-BIND-1
                MOVE WS-SRC-TYPE TO WS-BIND-2
                MOVE FUNCTION TRIM(WS-SRC-REF) TO WS-BIND-3
                MOVE WS-TMP-STR TO WS-BIND-4
                MOVE WS-TMP-ALLOCATED TO WS-BIND-5
                MOVE WS-P6-TRIMMED TO WS-BIND-6
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "UPDATE loyalty_member SET points_balance = ?, version = version + 1 WHERE member_id = ? AND version = ?" TO WS-PREP-SQL
                MOVE WS-TMP-ALLOCATED TO WS-BIND-1
                MOVE WS-P1-TRIMMED TO WS-BIND-2
                MOVE FUNCTION TRIM(WS-MEM-VERSION) TO WS-BIND-3
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
                MOVE "EXPIRE" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-MEM
                MOVE WS-MEM-PROGID TO WS-AUDIT-PROG
                MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-ALLOCATED TO WS-AUDIT-NEW
                PERFORM AUDIT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                MOVE WS-NUM-POINTS TO WS-AMT-EDIT
                MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-STR
                STRING "SUCCESS|LOY_EXPIRE|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ADJUST.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-MEMBER
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-MEM-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-POINTS
            IF WS-NUM-POINTS = 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-NUM-POINTS < 0
                COMPUTE WS-NUM-TOTAL = 0 - WS-NUM-POINTS END-COMPUTE
                IF WS-NUM-TOTAL > WS-NUM-BAL
                    MOVE "ERROR|LIMIT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                COMPUTE WS-NUM-BAL = WS-NUM-BAL - WS-NUM-TOTAL END-COMPUTE
            ELSE
                COMPUTE WS-NUM-BAL = WS-NUM-BAL + WS-NUM-POINTS END-COMPUTE
            END-IF.
            MOVE WS-TMP-AMT TO WS-AUDIT-OLD
            MOVE WS-NUM-BAL TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-ALLOCATED
            IF WS-NUM-POINTS < 0
                COMPUTE WS-NUM-TOTAL = 0 - WS-NUM-POINTS END-COMPUTE
                MOVE WS-NUM-TOTAL TO WS-AMT-EDIT
                MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-STR
                MOVE SPACES TO WS-TMP-ID
                STRING "-" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE
                    INTO WS-TMP-ID END-STRING
                MOVE FUNCTION TRIM(WS-TMP-ID) TO WS-TMP-STR
            ELSE
                MOVE WS-NUM-POINTS TO WS-AMT-EDIT
                MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-STR
            END-IF.
            MOVE "SELECT DATE_FORMAT(NOW(6), 'ADJ-%Y%m%d%H%i%S%f')" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:50) TO WS-SRC-REF
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "ADJUSTMENT" TO WS-SRC-TYPE
            MOVE "INSERT INTO loyalty_points_ledger (member_id, source_type, source_ref, points_delta, balance_after, created_by) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-SRC-TYPE TO WS-BIND-2
            MOVE FUNCTION TRIM(WS-SRC-REF) TO WS-BIND-3
            MOVE WS-TMP-STR TO WS-BIND-4
            MOVE WS-TMP-ALLOCATED TO WS-BIND-5
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
                MOVE "UPDATE loyalty_member SET points_balance = ?, version = version + 1 WHERE member_id = ? AND version = ?" TO WS-PREP-SQL
                MOVE WS-TMP-ALLOCATED TO WS-BIND-1
                MOVE WS-P1-TRIMMED TO WS-BIND-2
                MOVE FUNCTION TRIM(WS-MEM-VERSION) TO WS-BIND-3
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
                MOVE "ADJUST" TO WS-AUDIT-ACTION
                MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-MEM
                MOVE WS-MEM-PROGID TO WS-AUDIT-PROG
                MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
                MOVE WS-TMP-ALLOCATED TO WS-AUDIT-NEW
                PERFORM AUDIT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|LOY_ADJUST|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-ALLOCATED) DELIMITED BY SIZE
                    INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF LS-OUTPUT-BUFFER = SPACES
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LIST.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
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
            MOVE "SELECT CONCAT(id, ':', program_code, ':', status, ':', earn_rate, ':', COALESCE(name, '')) FROM loyalty_program WHERE (? = '' OR status = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|LOY_LIST|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|LOY_LIST|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-GET.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(member_id, '|', program_id, '|', customer_ref, '|', tier, '|', points_balance, '|', status) FROM loyalty_member WHERE member_id = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|LOY_GET|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-SUMMARY.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT((SELECT COUNT(*) FROM loyalty_program), '|', (SELECT COUNT(*) FROM loyalty_member), '|', COALESCE((SELECT SUM(points_balance) FROM loyalty_member), 0), '|', (SELECT COUNT(*) FROM loyalty_redemption))" TO WS-PREP-SQL
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
            STRING "SUCCESS|LOY_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-AUDIT.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
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
            MOVE "SELECT CONCAT(action, ':', actor_email, ':', COALESCE(detail, ''), ':', created_at) FROM loyalty_audit WHERE (? = '' OR member_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|LOY_AUDIT|0" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|LOY_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-VALIDATE.
            MOVE "LOYALTY_CORE" TO WS-DENIED-TARGET
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-P1-TRIMMED TO WS-PROG-ID
            PERFORM LOAD-PROGRAM
            IF WS-ERR NOT = SPACES
                MOVE WS-ERR TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PROG-STATUS NOT = "ACTIVE"
                MOVE "ERROR|INVALID_STATE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-POINTS
            IF WS-NUM-POINTS <= 0
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-NUM-POINTS TO WS-NUM-AMOUNT
            COMPUTE WS-NUM-POINTS = WS-NUM-AMOUNT * WS-NUM-EARN END-COMPUTE
            MOVE WS-NUM-POINTS TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-STR
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|LOY_VALID|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE
                INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.
