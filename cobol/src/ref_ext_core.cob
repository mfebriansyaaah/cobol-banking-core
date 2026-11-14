       IDENTIFICATION DIVISION.
       PROGRAM-ID. ref_ext_core.
      *> Reference data expansion: translations, hierarchy, as-of, clone, export.

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
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-TOTAL                PIC X(100) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-LOOKUP-BAD           PIC 9 VALUE 0.
       01  WS-VALUE-ID             PIC X(20) VALUE SPACES.
       01  WS-PARENT-ID            PIC X(20) VALUE SPACES.
       01  WS-CHILD-ID             PIC X(20) VALUE SPACES.
       01  WS-CODE-IN              PIC X(100) VALUE SPACES.
       01  WS-CODE-LEN             PIC 9(3) VALUE 0.
       01  WS-DATE-IN              PIC X(100) VALUE SPACES.
       01  WS-DATE-LEN             PIC 9(3) VALUE 0.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-TYPE           PIC X(40) VALUE SPACES.
       01  WS-AUDIT-CODE           PIC X(64) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-PART                 PIC X(16384) VALUE SPACES.
       01  WS-SUCCESS-MSG          PIC X(16384) VALUE SPACES.
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
               WHEN LS-CMD-ACTION(1:18) = "RX_TRANSLATION_SET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-TRANSLATION-SET
               WHEN LS-CMD-ACTION(1:19) = "RX_TRANSLATION_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-TRANSLATION-LIST
               WHEN LS-CMD-ACTION(1:16) = "RX_HIERARCHY_ADD"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-HIERARCHY-ADD
               WHEN LS-CMD-ACTION(1:17) = "RX_HIERARCHY_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-HIERARCHY-LIST
               WHEN LS-CMD-ACTION(1:19) = "RX_HIERARCHY_REMOVE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-HIERARCHY-REMOVE
               WHEN LS-CMD-ACTION(1:17) = "RX_VALUE_GET_ASOF"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALUE-ASOF
               WHEN LS-CMD-ACTION(1:14) = "RX_VALUE_CLONE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALUE-CLONE
               WHEN LS-CMD-ACTION(1:9) = "RX_EXPORT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-EXPORT
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_validate_semi.cpy".
        COPY "common_sql.cpy".


        COPY "common_trim.cpy".


       VALIDATE-CODE-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-CODE-LEN
           PERFORM VARYING WS-I FROM 100 BY -1
               UNTIL WS-I < 1 OR WS-CODE-LEN > 0
               IF WS-CODE-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-CODE-LEN
               END-IF
           END-PERFORM
           IF WS-CODE-LEN < 1 OR WS-CODE-LEN > 64
               MOVE 1 TO WS-BAD
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-CODE-LEN
               IF WS-CODE-IN(WS-I:1) IS NOT ALPHABETIC
                  AND WS-CODE-IN(WS-I:1) IS NOT NUMERIC
                  AND WS-CODE-IN(WS-I:1) NOT = "_"
                  AND WS-CODE-IN(WS-I:1) NOT = "-"
                   MOVE 1 TO WS-BAD
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.


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

        COPY "common_auth.cpy".

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

       AUDIT-DENIED.
           MOVE "AUTHZ_DENIED" TO WS-AUDIT-ACTION
           MOVE SPACES TO WS-AUDIT-TYPE WS-AUDIT-CODE
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT-REF.
           EXIT PARAGRAPH.

       CHECK-VALUE.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-VALUE-ID
           MOVE "SELECT CAST(id AS CHAR) FROM ref_value WHERE type_code = ? AND code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
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
           MOVE WS-RESULT(1:20) TO WS-VALUE-ID.
           EXIT PARAGRAPH.

       CHECK-VALUE-PAIR.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-PARENT-ID WS-CHILD-ID
           MOVE "SELECT CAST(p.id AS CHAR), CAST(c.id AS CHAR) FROM ref_value p JOIN ref_value c ON c.type_code = p.type_code WHERE p.type_code = ? AND p.code = ? AND c.code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
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
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-PARENT-ID WS-CHILD-ID
           END-UNSTRING.
           EXIT PARAGRAPH.

        COPY "common_result.cpy".
        COPY "common_txn.cpy".

       ACTION-TRANSLATION-SET.
           MOVE "REF_EXT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-VALUE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO ref_translation (ref_value_id, locale, label) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label)" TO WS-PREP-SQL
           MOVE WS-VALUE-ID TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
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
               MOVE "TRANSLATION_SET" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-TYPE
               MOVE WS-P2-TRIMMED(1:64) TO WS-AUDIT-CODE
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-REF
           END-IF.
           MOVE "SUCCESS|RX_TRANSLATION_SET" TO WS-SUCCESS-MSG
           PERFORM TXN-FINISH
           EXIT PARAGRAPH.

       ACTION-TRANSLATION-LIST.
           MOVE "REF_EXT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-VALUE
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
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM4 NOT = SPACES
               MOVE WS-P4-TRIMMED(1:WS-P4-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_translation WHERE ref_value_id = ?" TO WS-PREP-SQL
           MOVE WS-VALUE-ID TO WS-BIND-1
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
           MOVE "SELECT CONCAT(locale, ':', label) FROM ref_translation WHERE ref_value_id = ? ORDER BY locale LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-VALUE-ID TO WS-BIND-1
           MOVE WS-LIMIT TO WS-BIND-2
           MOVE WS-OFFSET TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|RX_TRANSLATIONS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RX_TRANSLATIONS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-HIERARCHY-ADD.
           MOVE "REF_EXT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-TRIMMED = WS-P3-TRIMMED
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-VALUE-PAIR
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT IGNORE INTO ref_hierarchy (parent_value_id, child_value_id) VALUES (?, ?)" TO WS-PREP-SQL
           MOVE WS-PARENT-ID TO WS-BIND-1
           MOVE WS-CHILD-ID TO WS-BIND-2
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
               MOVE "HIERARCHY_ADD" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-TYPE
               MOVE WS-P2-TRIMMED(1:64) TO WS-AUDIT-CODE
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-REF
           END-IF.
           MOVE "SUCCESS|RX_HIERARCHY_ADDED" TO WS-SUCCESS-MSG
           PERFORM TXN-FINISH
           EXIT PARAGRAPH.

       ACTION-HIERARCHY-LIST.
           MOVE "REF_EXT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM4 NOT = SPACES
               MOVE WS-P4-TRIMMED(1:WS-P4-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_hierarchy h JOIN ref_value p ON p.id=h.parent_value_id JOIN ref_value c ON c.id=h.child_value_id WHERE p.type_code = ? AND (? = '' OR p.code = ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(p.code, ':', c.code) FROM ref_hierarchy h JOIN ref_value p ON p.id=h.parent_value_id JOIN ref_value c ON c.id=h.child_value_id WHERE p.type_code = ? AND (? = '' OR p.code = ?) ORDER BY p.code, c.code LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           MOVE WS-LIMIT TO WS-BIND-4
           MOVE WS-OFFSET TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|RX_HIERARCHY|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RX_HIERARCHY|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-HIERARCHY-REMOVE.
           MOVE "REF_EXT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-VALUE-PAIR
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "DELETE FROM ref_hierarchy WHERE parent_value_id = ? AND child_value_id = ?" TO WS-PREP-SQL
           MOVE WS-PARENT-ID TO WS-BIND-1
           MOVE WS-CHILD-ID TO WS-BIND-2
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
               MOVE "HIERARCHY_REMOVE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-TYPE
               MOVE WS-P2-TRIMMED(1:64) TO WS-AUDIT-CODE
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-REF
           END-IF.
           MOVE "SUCCESS|RX_HIERARCHY_REMOVED" TO WS-SUCCESS-MSG
           PERFORM TXN-FINISH
           EXIT PARAGRAPH.

       ACTION-VALUE-ASOF.
           MOVE "REF_EXT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P3-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(v.label, '|', COALESCE(v.attributes, ''), '|', v.status, '|', v.effective_from, '|', COALESCE(v.effective_to, '')) FROM ref_value_version v JOIN ref_value r ON r.id = v.ref_value_id WHERE r.type_code = ? AND r.code = ? AND v.effective_from <= ? AND (v.effective_to IS NULL OR v.effective_to >= ?) AND v.status IN ('ACTIVE','RETIRED') ORDER BY v.version_no DESC LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P3-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
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
           STRING "SUCCESS|RX_ASOF|" DELIMITED BY SIZE
                  WS-P1-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-P2-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RESULT(1:200) DELIMITED BY SIZE
                  INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.

       ACTION-VALUE-CLONE.
           MOVE "REF_EXT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-VALUE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(id AS CHAR) FROM ref_value WHERE type_code = ? AND code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO ref_value (type_code, code) VALUES (?, ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
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
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-CHILD-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSERT INTO ref_value_version (ref_value_id, version_no, label, attributes, status, effective_from) SELECT ?, 1, ?, COALESCE(attributes, ''), 'DRAFT', CURDATE() FROM ref_value_version WHERE ref_value_id = ? ORDER BY version_no DESC LIMIT 1" TO WS-PREP-SQL
               MOVE WS-CHILD-ID TO WS-BIND-1
               MOVE WS-P4-TRIMMED TO WS-BIND-2
               MOVE WS-VALUE-ID TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
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
               MOVE "VALUE_CLONE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-TYPE
               MOVE WS-P3-TRIMMED(1:64) TO WS-AUDIT-CODE
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-REF
           END-IF.
           MOVE "SUCCESS|RX_VALUE_CLONED" TO WS-SUCCESS-MSG
           PERFORM TXN-FINISH
           EXIT PARAGRAPH.

       ACTION-EXPORT.
           MOVE "REF_EXT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-TRIMMED NOT = "CSV" AND WS-P2-TRIMMED NOT = "JSON"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(r.code, ':', COALESCE((SELECT v.label FROM ref_value_version v WHERE v.ref_value_id = r.id AND v.status = 'ACTIVE' ORDER BY v.version_no DESC LIMIT 1), ''), ':', COALESCE((SELECT v.status FROM ref_value_version v WHERE v.ref_value_id = r.id ORDER BY v.version_no DESC LIMIT 1), 'NONE')) FROM ref_value r WHERE r.type_code = ? ORDER BY r.code" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|RX_EXPORT|" DELIMITED BY SIZE
                      WS-P2-TRIMMED DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RX_EXPORT|" DELIMITED BY SIZE
                      WS-P2-TRIMMED DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.
