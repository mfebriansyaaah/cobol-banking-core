       IDENTIFICATION DIVISION.
       PROGRAM-ID. audit_drilldown_core.
      *> Saved audit drill-down queries over live and archived audit rows.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESULT               PIC X(16384) VALUE SPACES.
       01  WS-ROWS                 PIC X(16384) VALUE SPACES.
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
       01  WS-LOOKUP-BAD           PIC 9 VALUE 0.
       01  WS-EXISTS               PIC X VALUE SPACES.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-AT-COUNT             PIC 9(3) VALUE 0.
       01  WS-ROW-COUNT-N          PIC 9(10) VALUE 0.
       01  WS-SEMI-COUNT           PIC 9(5) VALUE 0.
       01  WS-FILTER-SPEC          PIC X(255) VALUE SPACES.
       01  WS-F-ACTION             PIC X(100) VALUE SPACES.
       01  WS-F-ENTITY             PIC X(50) VALUE SPACES.
       01  WS-F-STATUS             PIC X(20) VALUE SPACES.
       01  WS-F-FROM               PIC X(20) VALUE SPACES.
       01  WS-F-TO                 PIC X(20) VALUE SPACES.
       01  WS-SPEC-1               PIC X(100) VALUE SPACES.
       01  WS-SPEC-2               PIC X(100) VALUE SPACES.
       01  WS-SPEC-3               PIC X(100) VALUE SPACES.
       01  WS-SPEC-4               PIC X(100) VALUE SPACES.
       01  WS-SPEC-5               PIC X(100) VALUE SPACES.
       01  WS-ROW-COUNT            PIC Z(9)9 VALUE ZERO.
       01  WS-DIGEST               PIC X(64) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-QUERY          PIC X(40) VALUE SPACES.
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
               WHEN LS-CMD-ACTION(1:14) = "ADR_QUERY_SAVE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-QUERY-SAVE
               WHEN LS-CMD-ACTION(1:14) = "ADR_QUERY_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-QUERY-LIST
               WHEN LS-CMD-ACTION(1:13) = "ADR_QUERY_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-QUERY-GET
               WHEN LS-CMD-ACTION(1:16) = "ADR_QUERY_DELETE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-QUERY-DELETE
               WHEN LS-CMD-ACTION(1:12) = "ADR_RUN_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-LIST
               WHEN LS-CMD-ACTION(1:7) = "ADR_RUN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN
               WHEN LS-CMD-ACTION(1:9) = "ADR_DRILL"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-DRILL
               WHEN LS-CMD-ACTION(1:11) = "ADR_SUMMARY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SUMMARY
               WHEN LS-CMD-ACTION(1:9) = "ADR_PIVOT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-PIVOT
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

       TRIM-FIELD.
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

       VALIDATE-COUNT-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-COUNT-LEN
           PERFORM VARYING WS-I FROM 30 BY -1
               UNTIL WS-I < 1 OR WS-COUNT-LEN > 0
               IF WS-COUNT-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-COUNT-LEN
               END-IF
           END-PERFORM
           IF WS-COUNT-LEN < 1 OR WS-COUNT-LEN > 18
               MOVE 1 TO WS-BAD
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-COUNT-LEN
               IF WS-COUNT-IN(WS-I:1) IS NOT NUMERIC
                   MOVE 1 TO WS-BAD
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.

       VALIDATE-FILTER-FIELD.
           MOVE 0 TO WS-BAD
           IF WS-TRIM-IN = SPACES
               EXIT PARAGRAPH
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 100
               IF WS-TRIM-IN(WS-I:1) NOT = SPACE
                   IF WS-TRIM-IN(WS-I:1) NOT = "_"
                       IF WS-TRIM-IN(WS-I:1) IS NOT ALPHABETIC
                           IF WS-TRIM-IN(WS-I:1) IS NOT NUMERIC
                               MOVE 1 TO WS-BAD
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.

       VALIDATE-DATE-FIELD.
           MOVE 0 TO WS-BAD
           IF WS-TRIM-IN = SPACES
               EXIT PARAGRAPH
           END-IF.
           IF WS-TRIM-IN(1:1) IS NOT NUMERIC OR WS-TRIM-IN(2:1) IS NOT NUMERIC
               OR WS-TRIM-IN(3:1) IS NOT NUMERIC OR WS-TRIM-IN(4:1) IS NOT NUMERIC
               OR WS-TRIM-IN(5:1) NOT = "-" OR WS-TRIM-IN(6:1) IS NOT NUMERIC
               OR WS-TRIM-IN(7:1) IS NOT NUMERIC OR WS-TRIM-IN(8:1) NOT = "-"
               OR WS-TRIM-IN(9:1) IS NOT NUMERIC OR WS-TRIM-IN(10:1) IS NOT NUMERIC
               MOVE 1 TO WS-BAD
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
               MOVE "AUDIT_DRILLDOWN_CORE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       AUDIT.
           MOVE "INSERT INTO audit_drilldown_audit (action, actor_email, query_code, detail) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-QUERY TO WS-BIND-3
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

       AUDIT-DENIED.
           MOVE "AUTHZ_DENIED" TO WS-AUDIT-ACTION
           MOVE SPACES TO WS-AUDIT-QUERY
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

       TRIM-ROWS-LEN.
           MOVE 0 TO WS-RLEN
           PERFORM VARYING WS-J FROM 16384 BY -1
               UNTIL WS-J < 1 OR WS-RLEN > 0
               IF WS-ROWS(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-RLEN
               END-IF
           END-PERFORM
           IF WS-RLEN = 0
               MOVE 1 TO WS-RLEN
           END-IF.
           EXIT PARAGRAPH.

       PARSE-FILTER-SPEC.
           MOVE SPACES TO WS-F-ACTION WS-F-ENTITY WS-F-STATUS WS-F-FROM WS-F-TO
           MOVE SPACES TO WS-SPEC-1 WS-SPEC-2 WS-SPEC-3 WS-SPEC-4 WS-SPEC-5
           UNSTRING WS-FILTER-SPEC DELIMITED BY ","
               INTO WS-SPEC-1 WS-SPEC-2 WS-SPEC-3 WS-SPEC-4 WS-SPEC-5
           END-UNSTRING
           MOVE WS-SPEC-1 TO WS-TRIM-IN
           PERFORM TRIM-FIELD
           MOVE WS-TRIM-OUT(1:WS-TRIM-LEN) TO WS-F-ACTION
           MOVE WS-SPEC-2 TO WS-TRIM-IN
           PERFORM TRIM-FIELD
           MOVE WS-TRIM-OUT(1:WS-TRIM-LEN) TO WS-F-ENTITY
           MOVE WS-SPEC-3 TO WS-TRIM-IN
           PERFORM TRIM-FIELD
           MOVE WS-TRIM-OUT(1:WS-TRIM-LEN) TO WS-F-STATUS
           MOVE WS-SPEC-4 TO WS-TRIM-IN
           PERFORM TRIM-FIELD
           MOVE WS-TRIM-OUT(1:WS-TRIM-LEN) TO WS-F-FROM
           MOVE WS-SPEC-5 TO WS-TRIM-IN
           PERFORM TRIM-FIELD
           MOVE WS-TRIM-OUT(1:WS-TRIM-LEN) TO WS-F-TO.
           EXIT PARAGRAPH.

       BUILD-FILTER-BINDS.
           MOVE WS-F-ACTION TO WS-BIND-1
           MOVE WS-F-ENTITY TO WS-BIND-2
           MOVE WS-F-ENTITY TO WS-BIND-3
           MOVE WS-F-STATUS TO WS-BIND-4
           MOVE WS-F-FROM TO WS-BIND-5
           MOVE WS-F-TO TO WS-BIND-6.
           EXIT PARAGRAPH.

       ACTION-QUERY-SAVE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P3-TRIMMED TO WS-FILTER-SPEC
           PERFORM PARSE-FILTER-SPEC
           MOVE WS-F-ACTION TO WS-TRIM-IN
           PERFORM VALIDATE-FILTER-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-F-ENTITY TO WS-TRIM-IN
           PERFORM VALIDATE-FILTER-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-F-STATUS NOT = SPACES AND WS-F-STATUS NOT = "SUCCESS" AND WS-F-STATUS NOT = "FAILED"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-F-FROM TO WS-TRIM-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-F-TO TO WS-TRIM-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO audit_drilldown_query (query_code, name, filter_spec, saved_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE name=VALUES(name), filter_spec=VALUES(filter_spec)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P6-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "QUERY_SAVE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-QUERY
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|ADR_QUERY_SAVED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-QUERY-LIST.
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
           MOVE "SELECT CONCAT(query_code, ':', name, ':', filter_spec, ':', saved_by) FROM audit_drilldown_query ORDER BY query_code LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-LIMIT TO WS-BIND-1
           MOVE WS-OFFSET TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|ADR_QUERIES|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|ADR_QUERIES|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-QUERY-GET.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(query_code, '|', name, '|', filter_spec, '|', saved_by, '|', created_at, '|', updated_at) FROM audit_drilldown_query WHERE query_code = ? LIMIT 1" TO WS-PREP-SQL
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
           STRING "SUCCESS|ADR_QUERY|" DELIMITED BY SIZE WS-RESULT(1:400) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-QUERY-DELETE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "DELETE FROM audit_drilldown_query WHERE query_code = ?" TO WS-PREP-SQL
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
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "QUERY_DELETE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-QUERY
               MOVE SPACES TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|ADR_QUERY_DELETED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|NOT_FOUND"
                   MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       BUILD-RUN-SQL.
           MOVE SPACES TO WS-PREP-SQL
           STRING
               "SELECT CONCAT(audit_id, '|', user_id, '|', COALESCE(actor_id, 0), '|', " DELIMITED BY SIZE
               "action, '|', COALESCE(entity_type, ''), '|', COALESCE(entity_id, ''), '|', " DELIMITED BY SIZE
               "status, '|', created_at) FROM ( SELECT audit_id, user_id, actor_id, action, " DELIMITED BY SIZE
               "entity_type, entity_id, status, created_at FROM audit_trail UNION ALL " DELIMITED BY SIZE
               "SELECT audit_id, user_id, actor_id, action, entity_type, entity_id, status, " DELIMITED BY SIZE
               "created_at FROM audit_trail_archive ) a WHERE action = COALESCE(NULLIF(?, ''), action) " DELIMITED BY SIZE
               "AND (COALESCE(entity_type, '') = COALESCE(NULLIF(?, ''), COALESCE(entity_type, '')) " DELIMITED BY SIZE
               "OR COALESCE(entity_id, '') = COALESCE(NULLIF(?, ''), COALESCE(entity_id, ''))) " DELIMITED BY SIZE
               "AND status = COALESCE(NULLIF(?, ''), status) " DELIMITED BY SIZE
               "AND DATE(created_at) >= COALESCE(NULLIF(?, ''), DATE(created_at)) " DELIMITED BY SIZE
               "AND DATE(created_at) <= COALESCE(NULLIF(?, ''), DATE(created_at)) " DELIMITED BY SIZE
               "ORDER BY created_at DESC, audit_id DESC LIMIT " DELIMITED BY SIZE
               WS-LIMIT DELIMITED BY SPACE
               " OFFSET " DELIMITED BY SIZE
               WS-OFFSET DELIMITED BY SPACE
               INTO WS-PREP-SQL
           END-STRING.
           EXIT PARAGRAPH.

       COUNT-RESULT-ROWS.
           MOVE 0 TO WS-SEMI-COUNT
           MOVE 0 TO WS-ROW-COUNT-N
           PERFORM TRIM-RESULT-LEN
           IF WS-RESULT = "ERROR|NO_DATA" OR WS-RLEN < 1
               EXIT PARAGRAPH
           END-IF.
           INSPECT WS-RESULT(1:WS-RLEN) TALLYING WS-SEMI-COUNT FOR ALL ";"
           COMPUTE WS-ROW-COUNT-N = WS-SEMI-COUNT + 1 END-COMPUTE.
           EXIT PARAGRAPH.

       ACTION-RUN.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "100" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:30) TO WS-COUNT-IN
               PERFORM VALIDATE-COUNT-FIELD
               IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) < 1 OR FUNCTION NUMVAL(WS-COUNT-IN) > 500
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:30) TO WS-COUNT-IN
               PERFORM VALIDATE-COUNT-FIELD
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT filter_spec FROM audit_drilldown_query WHERE query_code = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE WS-RESULT(1:255) TO WS-FILTER-SPEC
           PERFORM PARSE-FILTER-SPEC
           MOVE WS-F-ACTION TO WS-TRIM-IN
           PERFORM VALIDATE-FILTER-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-F-ENTITY TO WS-TRIM-IN
           PERFORM VALIDATE-FILTER-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM BUILD-FILTER-BINDS
           PERFORM BUILD-RUN-SQL
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|ADR_ROWS|0" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM COUNT-RESULT-ROWS
           MOVE WS-RESULT TO WS-ROWS
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO audit_drilldown_run (query_code, row_count, digest, executed_by) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-ROW-COUNT-N TO WS-ROW-COUNT
           MOVE WS-ROW-COUNT TO WS-BIND-2
           MOVE SPACES TO WS-BIND-3
           MOVE WS-P6-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "RUN" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-QUERY
               MOVE WS-ROW-COUNT TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               PERFORM TRIM-ROWS-LEN
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|ADR_ROWS|" DELIMITED BY SIZE FUNCTION TRIM(WS-ROW-COUNT) DELIMITED BY SIZE "|" DELIMITED BY SIZE WS-ROWS(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-DRILL.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-F-ACTION
           MOVE WS-P2-TRIMMED(1:50) TO WS-F-ENTITY
           MOVE WS-P3-TRIMMED(1:20) TO WS-F-STATUS
           MOVE WS-P4-TRIMMED(1:20) TO WS-F-FROM
           MOVE WS-P5-TRIMMED(1:20) TO WS-F-TO
           MOVE WS-F-ACTION TO WS-TRIM-IN
           PERFORM VALIDATE-FILTER-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-F-ENTITY TO WS-TRIM-IN
           PERFORM VALIDATE-FILTER-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-F-STATUS NOT = SPACES AND WS-F-STATUS NOT = "SUCCESS" AND WS-F-STATUS NOT = "FAILED"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-F-FROM TO WS-TRIM-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-F-TO TO WS-TRIM-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "100" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           PERFORM BUILD-FILTER-BINDS
           PERFORM BUILD-RUN-SQL
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|ADR_ROWS|0" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM COUNT-RESULT-ROWS
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|ADR_ROWS|" DELIMITED BY SIZE FUNCTION TRIM(WS-ROW-COUNT) DELIMITED BY SIZE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-SUMMARY.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'SUCCESS'), 0), '|', COALESCE(SUM(status = 'FAILED'), 0), '|', COUNT(DISTINCT COALESCE(actor_id, 0))) FROM audit_trail WHERE (? = '' OR DATE(created_at) >= ?) AND (? = '' OR DATE(created_at) <= ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           MOVE WS-P2-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|ADR_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:200) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-PIVOT.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COALESCE(entity_type, 'NONE'), ':', COUNT(*)) FROM audit_trail WHERE (? = '' OR DATE(created_at) >= ?) AND (? = '' OR DATE(created_at) <= ?) GROUP BY COALESCE(entity_type, 'NONE') ORDER BY COUNT(*) DESC LIMIT 50" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           MOVE WS-P2-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|ADR_PIVOT|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|ADR_PIVOT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-LIST.
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
           MOVE "SELECT CONCAT(id, ':', query_code, ':', row_count, ':', executed_by, ':', executed_at) FROM audit_drilldown_run WHERE (? = '' OR query_code = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               MOVE "SUCCESS|ADR_RUNS|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|ADR_RUNS|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.
