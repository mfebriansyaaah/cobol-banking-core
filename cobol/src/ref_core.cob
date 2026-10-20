        IDENTIFICATION DIVISION.
        PROGRAM-ID. ref_core.

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
        01  WS-RLEN                 PIC 9(5) VALUE 1.
        01  WS-I                    PIC 9(3) VALUE 1.
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-ERR                  PIC X(40) VALUE SPACES.
        01  WS-TOTAL                PIC X(20) VALUE SPACES.
        01  WS-LIMIT                PIC X(10) VALUE SPACES.
        01  WS-OFFSET               PIC X(10) VALUE SPACES.
        01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
        01  WS-DENIED-TARGET        PIC X(100) VALUE SPACES.
        01  WS-AUDIT-ENTITY         PIC X(64) VALUE SPACES.
        01  WS-AUDIT-KEY            PIC X(100) VALUE SPACES.
        01  WS-AUDIT-ACTION         PIC X(20) VALUE SPACES.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
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

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

        MAIN-LOGIC.
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:12) = "REF_CUR_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CUR_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CUR_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CUR_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CUR_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CTR_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CTR_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CTR_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CTR_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CTR_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_HOL_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_HOL_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_HOL_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_HOL_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_HOL_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CHN_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CHN_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CHN_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CHN_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CHN_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_BRN_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_BRN_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_BRN_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_BRN_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_BRN_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CCT_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CCT_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CCT_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CCT_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CCT_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_DTP_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_DTP_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_DTP_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_DTP_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_DTP_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_NTP_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_NTP_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_NTP_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_NTP_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_NTP_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_STS_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_STS_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_STS_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_STS_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_STS_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_RTS_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_RTS_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_RTS_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_RTS_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_RTS_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_PRD_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_PRD_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_PRD_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_PRD_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_PRD_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-DEACT
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        VALIDATE-ALL.
            MOVE 0 TO WS-BAD
            MOVE LS-PARAM1 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM2 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM3 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM4 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM5 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM6 TO WS-CHECK
            PERFORM VALIDATE-INPUT.
            EXIT PARAGRAPH.

        VALIDATE-INPUT.
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-QUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-DQUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-BSLASH
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-SEMI
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-TICK.
            EXIT PARAGRAPH.

        TRIM-ALL.
            PERFORM TRIM-P1
            PERFORM TRIM-P2
            PERFORM TRIM-P3
            PERFORM TRIM-P4
            PERFORM TRIM-P5
            PERFORM TRIM-P6.
            EXIT PARAGRAPH.

        TRIM-P1.
            MOVE LS-PARAM1 TO WS-P1-TRIMMED
            MOVE 0 TO WS-P1-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P1-LEN > 0
                IF WS-P1-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P1-LEN
                END-IF
            END-PERFORM
            IF WS-P1-LEN = 0
                MOVE 1 TO WS-P1-LEN
            END-IF.

        TRIM-P2.
            MOVE LS-PARAM2 TO WS-P2-TRIMMED
            MOVE 0 TO WS-P2-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P2-LEN > 0
                IF WS-P2-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P2-LEN
                END-IF
            END-PERFORM
            IF WS-P2-LEN = 0
                MOVE 1 TO WS-P2-LEN
            END-IF.

        TRIM-P3.
            MOVE LS-PARAM3 TO WS-P3-TRIMMED
            MOVE 0 TO WS-P3-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P3-LEN > 0
                IF WS-P3-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P3-LEN
                END-IF
            END-PERFORM
            IF WS-P3-LEN = 0
                MOVE 1 TO WS-P3-LEN
            END-IF.

        TRIM-P4.
            MOVE LS-PARAM4 TO WS-P4-TRIMMED
            MOVE 0 TO WS-P4-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P4-LEN > 0
                IF WS-P4-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P4-LEN
                END-IF
            END-PERFORM
            IF WS-P4-LEN = 0
                MOVE 1 TO WS-P4-LEN
            END-IF.

        TRIM-P5.
            MOVE LS-PARAM5 TO WS-P5-TRIMMED
            MOVE 0 TO WS-P5-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P5-LEN > 0
                IF WS-P5-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P5-LEN
                END-IF
            END-PERFORM
            IF WS-P5-LEN = 0
                MOVE 1 TO WS-P5-LEN
            END-IF.

        TRIM-P6.
            MOVE LS-PARAM6 TO WS-P6-TRIMMED
            MOVE 0 TO WS-P6-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P6-LEN > 0
                IF WS-P6-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P6-LEN
                END-IF
            END-PERFORM
            IF WS-P6-LEN = 0
                MOVE 1 TO WS-P6-LEN
            END-IF.

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
            END-IF.
            IF WS-ALLOWED NOT = 1
                MOVE WS-P6-TRIMMED TO WS-DENIED-ACTOR
                MOVE "REFERENCE" TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'REFERENCE', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
            EXIT PARAGRAPH.

        AUDIT-REF.
            MOVE "INSERT INTO reference_audit (entity, entity_key, action, actor_email) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-ENTITY TO WS-BIND-1
            MOVE WS-AUDIT-KEY TO WS-BIND-2
            MOVE WS-AUDIT-ACTION TO WS-BIND-3
            MOVE WS-P6-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        TRIM-RESULT-LEN.
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-I FROM 16384 BY -1 UNTIL WS-I < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-RLEN
                END-IF
            END-PERFORM
            IF WS-RLEN = 0
                MOVE 1 TO WS-RLEN
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CUR-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 3
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 5
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CUR-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM currencies" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(iso_code, ':', symbol, ':', prec_val, ':', is_active) FROM currencies ORDER BY iso_code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CUR-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 3
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(iso_code, ':', symbol, ':', prec_val, ':', is_active) FROM currencies WHERE iso_code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CUR-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CUR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO currencies (iso_code, symbol, prec_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "currencies" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CUR-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CUR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE currencies SET symbol = ?, prec_val = ?, is_active = ? WHERE iso_code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "currencies" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CUR-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 3
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE currencies SET is_active = FALSE WHERE iso_code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "currencies" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CTR-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 2
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CTR-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_country" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_country ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CTR-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 2
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_country WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CTR-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CTR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_country (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_country" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CTR-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CTR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_country SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_country" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CTR-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 2
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_country SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_country" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-HOL-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 10
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HOL-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_holiday" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_holiday ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HOL-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 10
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_holiday WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-HOL-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-HOL-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_holiday (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_holiday" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HOL-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-HOL-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_holiday SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_holiday" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HOL-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 10
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_holiday SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_holiday" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CHN-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 4
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHN-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_channel" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_channel ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHN-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_channel WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CHN-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CHN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_channel (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_channel" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHN-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CHN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_channel SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_channel" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHN-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_channel SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_channel" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-BRN-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-BRN-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_branch" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_branch ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-BRN-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_branch WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-BRN-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-BRN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_branch (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_branch" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-BRN-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-BRN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_branch SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_branch" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-BRN-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_branch SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_branch" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CCT-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CCT-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_cost_center" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_cost_center ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CCT-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_cost_center WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CCT-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CCT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_cost_center (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_cost_center" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CCT-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CCT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_cost_center SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_cost_center" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CCT-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_cost_center SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_cost_center" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-DTP-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTP-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_document_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_document_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTP-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_document_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-DTP-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-DTP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_document_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_document_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTP-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-DTP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_document_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_document_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTP-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_document_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_document_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-NTP-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NTP-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_notification_template" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_notification_template ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NTP-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_notification_template WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-NTP-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-NTP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_notification_template (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_notification_template" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NTP-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-NTP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_notification_template SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_notification_template" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NTP-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_notification_template SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_notification_template" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-STS-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 4
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STS-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_status_code" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_status_code ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STS-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_status_code WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-STS-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-STS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_status_code (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_status_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STS-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-STS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_status_code SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_status_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STS-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_status_code SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_status_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-RTS-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RTS-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_rate_source" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_rate_source ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RTS-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_rate_source WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-RTS-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RTS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_rate_source (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_rate_source" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RTS-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RTS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_rate_source SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_rate_source" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RTS-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_rate_source SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_rate_source" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-PRD-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRD-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_product_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_product_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRD-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_product_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
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
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-PRD-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PRD-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_product_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
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
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_product_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRD-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PRD-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_product_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_product_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRD-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_product_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_product_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.
