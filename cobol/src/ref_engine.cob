       IDENTIFICATION DIVISION.
       PROGRAM-ID. ref_engine.
      *> Generic reference-data engine (Phase 1).
      *> Actions: RFE_TYPE_LIST, RFE_TYPE_CREATE, RFE_VALUE_LIST,
      *> RFE_VALUE_CREATE, RFE_VALUE_GET, RFE_VALUE_APPROVE,
      *> RFE_VALUE_RETIRE, RFE_VALUE_HIST.
      *> All business decisions and state transitions stay in COBOL.

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
       01  WS-I                    PIC 9(3) VALUE 1.
       01  WS-J                    PIC 9(5) VALUE 1.
       01  WS-RLEN                 PIC 9(5) VALUE 1.
       01  WS-BAD                  PIC 9(3) VALUE 0.
       01  WS-ALLOWED              PIC 9 VALUE 0.
       01  WS-CHECK                PIC X(100) VALUE SPACES.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-TOTAL                PIC X(20) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-STATUS               PIC X(10) VALUE SPACES.
       01  WS-AUDIT-TYPE           PIC X(32) VALUE SPACES.
       01  WS-AUDIT-CODE           PIC X(64) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(32) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(100) VALUE SPACES.
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

       PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2
           LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

       MAIN-LOGIC.
           PERFORM VALIDATE-ALL
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               GOBACK
           END-IF
           EVALUATE TRUE
               WHEN LS-CMD-ACTION(1:13) = "RFE_TYPE_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-TYPE-LIST
               WHEN LS-CMD-ACTION(1:15) = "RFE_TYPE_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-TYPE-CREATE
               WHEN LS-CMD-ACTION(1:14) = "RFE_VALUE_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALUE-LIST
               WHEN LS-CMD-ACTION(1:16) = "RFE_VALUE_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALUE-CREATE
               WHEN LS-CMD-ACTION(1:13) = "RFE_VALUE_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALUE-GET
               WHEN LS-CMD-ACTION(1:17) = "RFE_VALUE_APPROVE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALUE-APPROVE
               WHEN LS-CMD-ACTION(1:16) = "RFE_VALUE_RETIRE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALUE-RETIRE
               WHEN LS-CMD-ACTION(1:15) = "RFE_VALUE_HIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALUE-HIST
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
           EXIT PARAGRAPH.

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
           EXIT PARAGRAPH.

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
           EXIT PARAGRAPH.

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
           EXIT PARAGRAPH.

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
           EXIT PARAGRAPH.

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
           EXIT PARAGRAPH.

       ALLOW-ADMIN.
           *> Phase 1 gate: read/write reference data is limited to
           *> SUPER_ADMIN and MANAGER. The role split is refined in Phase 2.
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
               MOVE "REF_ENGINE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       AUDIT-DENIED.
           MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'REF_ENGINE', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
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
           MOVE "INSERT INTO ref_engine_audit (type_code, value_code, action, actor_email, detail) VALUES (?, ?, ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-TYPE TO WS-BIND-1
           MOVE WS-AUDIT-CODE TO WS-BIND-2
           MOVE WS-AUDIT-ACTION TO WS-BIND-3
           MOVE WS-P6-TRIMMED TO WS-BIND-4
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

       TRIM-RESULT-LEN.
           MOVE 0 TO WS-RLEN
           PERFORM VARYING WS-J FROM 16384 BY -1 UNTIL WS-J < 1 OR WS-RLEN > 0
               IF WS-RESULT(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-RLEN
               END-IF
           END-PERFORM
           IF WS-RLEN = 0
               MOVE 1 TO WS-RLEN
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-TYPE-INPUT.
           MOVE 0 TO WS-BAD
           IF WS-P1-LEN < 2 OR WS-P1-LEN > 32
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-VALUE-INPUT.
           MOVE 0 TO WS-BAD
           IF WS-P1-LEN < 2 OR WS-P1-LEN > 32
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-P3-LEN < 1 OR WS-P3-LEN > 128
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       ACTION-TYPE-LIST.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_type" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(type_code, ':', label, ':', is_active) FROM ref_type ORDER BY type_code LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-LIMIT TO WS-BIND-1
           MOVE WS-OFFSET TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|RFE_TYPES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RFE_TYPES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-TYPE-CREATE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM VALIDATE-TYPE-INPUT
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO ref_type (type_code, label, description, is_active) VALUES (?, ?, ?, TRUE)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE WS-P1-TRIMMED(1:32) TO WS-AUDIT-TYPE
               MOVE SPACES TO WS-AUDIT-CODE
               MOVE "TYPE_CREATE" TO WS-AUDIT-ACTION
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-REF
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|RFE_TYPE_CREATED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                   MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VALUE-LIST.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-LEN < 2 OR WS-P1-LEN > 32
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
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
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_value WHERE type_code = ?" TO WS-PREP-SQL
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
           MOVE "SELECT CONCAT(v.code, ':', vv.label, ':', vv.version_no, ':', vv.status, ':', DATE_FORMAT(vv.effective_from, '%Y-%m-%d'), ':', COALESCE(DATE_FORMAT(vv.effective_to, '%Y-%m-%d'), '')) FROM ref_value v JOIN ref_value_version vv ON vv.ref_value_id = v.id WHERE v.type_code = ? AND vv.version_no = (SELECT MAX(version_no) FROM ref_value_version WHERE ref_value_id = v.id) ORDER BY v.code LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               STRING "SUCCESS|RFE_VALUES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RFE_VALUES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VALUE-GET.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-LEN < 2 OR WS-P1-LEN > 32
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(v.code, ':', vv.label, ':', vv.version_no, ':', vv.status, ':', DATE_FORMAT(vv.effective_from, '%Y-%m-%d'), ':', COALESCE(DATE_FORMAT(vv.effective_to, '%Y-%m-%d'), '')) FROM ref_value v JOIN ref_value_version vv ON vv.ref_value_id = v.id WHERE v.type_code = ? AND v.code = ? ORDER BY vv.version_no DESC LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
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
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|RFE_VALUE|" DELIMITED BY SIZE
                  WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                  INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.

       ACTION-VALUE-CREATE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM VALIDATE-VALUE-INPUT
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT 1 FROM ref_type WHERE type_code = ? AND is_active = TRUE LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|TYPE_NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO ref_value (type_code, code) VALUES (?, ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "INSERT INTO ref_value_version (ref_value_id, version_no, label, attributes, status, effective_from) SELECT id, 1, ?, ?, 'DRAFT', CURDATE() FROM ref_value WHERE type_code = ? AND code = ?" TO WS-PREP-SQL
               MOVE WS-P3-TRIMMED TO WS-BIND-1
               MOVE WS-P4-TRIMMED TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               MOVE WS-P2-TRIMMED TO WS-BIND-4
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE WS-P1-TRIMMED(1:32) TO WS-AUDIT-TYPE
               MOVE WS-P2-TRIMMED(1:64) TO WS-AUDIT-CODE
               MOVE "CREATE" TO WS-AUDIT-ACTION
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-REF
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|RFE_VALUE_CREATED|1" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                   MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VALUE-APPROVE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-LEN < 2 OR WS-P1-LEN > 32
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-LEN < 1 OR WS-P3-LEN > 6
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT vv.status FROM ref_value v JOIN ref_value_version vv ON vv.ref_value_id = v.id WHERE v.type_code = ? AND v.code = ? AND vv.version_no = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
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
           MOVE WS-RESULT(1:10) TO WS-STATUS
           IF WS-STATUS NOT = "DRAFT"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE ref_value_version vv JOIN ref_value v ON v.id = vv.ref_value_id SET vv.status = 'RETIRED', vv.effective_to = CURDATE() WHERE v.type_code = ? AND v.code = ? AND vv.status = 'ACTIVE' AND vv.version_no <> ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE ref_value_version vv JOIN ref_value v ON v.id = vv.ref_value_id SET vv.status = 'ACTIVE', vv.effective_from = CURDATE(), vv.effective_to = NULL, vv.approved_by = ?, vv.approved_at = NOW() WHERE v.type_code = ? AND v.code = ? AND vv.version_no = ?" TO WS-PREP-SQL
               MOVE WS-P6-TRIMMED TO WS-BIND-1
               MOVE WS-P1-TRIMMED TO WS-BIND-2
               MOVE WS-P2-TRIMMED TO WS-BIND-3
               MOVE WS-P3-TRIMMED TO WS-BIND-4
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT = "SUCCESS|AFFECTED_0"
                   MOVE "ERROR|NOT_FOUND" TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE WS-P1-TRIMMED(1:32) TO WS-AUDIT-TYPE
               MOVE WS-P2-TRIMMED(1:64) TO WS-AUDIT-CODE
               MOVE "APPROVE" TO WS-AUDIT-ACTION
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-REF
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|RFE_VALUE_APPROVED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|NOT_FOUND"
                   MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VALUE-RETIRE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-LEN < 2 OR WS-P1-LEN > 32
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE ref_value_version vv JOIN ref_value v ON v.id = vv.ref_value_id SET vv.status = 'RETIRED', vv.effective_to = CURDATE() WHERE v.type_code = ? AND v.code = ? AND vv.status = 'ACTIVE'" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE WS-P1-TRIMMED(1:32) TO WS-AUDIT-TYPE
               MOVE WS-P2-TRIMMED(1:64) TO WS-AUDIT-CODE
               MOVE "RETIRE" TO WS-AUDIT-ACTION
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-REF
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|RFE_VALUE_RETIRED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VALUE-HIST.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-LEN < 2 OR WS-P1-LEN > 32
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_value v JOIN ref_value_version vv ON vv.ref_value_id = v.id WHERE v.type_code = ? AND v.code = ?" TO WS-PREP-SQL
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
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(vv.version_no, ':', vv.status, ':', vv.label, ':', DATE_FORMAT(vv.effective_from, '%Y-%m-%d'), ':', COALESCE(DATE_FORMAT(vv.effective_to, '%Y-%m-%d'), ''), ':', COALESCE(vv.approved_by, '')) FROM ref_value v JOIN ref_value_version vv ON vv.ref_value_id = v.id WHERE v.type_code = ? AND v.code = ? ORDER BY vv.version_no DESC" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|RFE_HISTORY|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RFE_HISTORY|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.
