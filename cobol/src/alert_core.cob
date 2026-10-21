       IDENTIFICATION DIVISION.
       PROGRAM-ID. alert_core.
      *> Operations alerts: raise, scan, acknowledge, resolve, and history.

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
       01  WS-ALERT-ID             PIC X(20) VALUE SPACES.
       01  WS-ALERT-TYPE           PIC X(32) VALUE SPACES.
       01  WS-ALERT-SEVERITY       PIC X(10) VALUE SPACES.
       01  WS-ALERT-SOURCE         PIC X(120) VALUE SPACES.
       01  WS-ALERT-TITLE          PIC X(160) VALUE SPACES.
       01  WS-ALERT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-ALERT-STATE          PIC X(20) VALUE SPACES.
       01  WS-ALERT-OWNER          PIC X(100) VALUE SPACES.
       01  WS-EXISTING             PIC X(1) VALUE SPACES.
       01  WS-EVENT                PIC X(20) VALUE SPACES.
       01  WS-RAISED               PIC 9(5) VALUE 0.
       01  WS-UPDATED              PIC 9(5) VALUE 0.
       01  WS-RAISED-EDIT          PIC Z(4)9 VALUE 0.
       01  WS-UPDATED-EDIT         PIC Z(4)9 VALUE 0.
       01  WS-RAISED-TEXT          PIC X(5) VALUE SPACES.
       01  WS-UPDATED-TEXT         PIC X(5) VALUE SPACES.
       01  WS-ROW-RAW              PIC X(16000) VALUE SPACES.
       01  WS-ROW-RAWLEN           PIC 9(5) VALUE 0.
       01  WS-ROW-PTR              PIC 9(5) VALUE 1.
       01  WS-ROW-REC              PIC X(500) VALUE SPACES.
       01  WS-ROW-PART1            PIC X(120) VALUE SPACES.
       01  WS-ROW-PART2            PIC X(120) VALUE SPACES.
       01  WS-ROW-PART3            PIC X(120) VALUE SPACES.
       01  WS-ROW-PART4            PIC X(120) VALUE SPACES.
       01  WS-ROW-PART5            PIC X(120) VALUE SPACES.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-DATE-IN              PIC X(100) VALUE SPACES.
       01  WS-DATE-LEN             PIC 9(3) VALUE 0.
       01  WS-AT-COUNT             PIC 9(3) VALUE 0.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-ALERT          PIC X(20) VALUE SPACES.
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
               WHEN LS-CMD-ACTION(1:9) = "ALT_RAISE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RAISE
               WHEN LS-CMD-ACTION(1:8) = "ALT_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-LIST
               WHEN LS-CMD-ACTION(1:7) = "ALT_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-GET
               WHEN LS-CMD-ACTION(1:7) = "ALT_ACK"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ACK
               WHEN LS-CMD-ACTION(1:11) = "ALT_RESOLVE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RESOLVE
               WHEN LS-CMD-ACTION(1:8) = "ALT_NOTE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-NOTE
               WHEN LS-CMD-ACTION(1:15) = "ALT_SCAN_OUTBOX"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SCAN-OUTBOX
               WHEN LS-CMD-ACTION(1:17) = "ALT_SCAN_SCHEDULE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SCAN-SCHEDULE
               WHEN LS-CMD-ACTION(1:14) = "ALT_SCAN_RECON"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SCAN-RECON
               WHEN LS-CMD-ACTION(1:16) = "ALT_SCAN_DISPUTE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SCAN-DISPUTE
               WHEN LS-CMD-ACTION(1:11) = "ALT_SUMMARY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SUMMARY
               WHEN LS-CMD-ACTION(1:11) = "ALT_HISTORY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-HISTORY
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
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-SEMI
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

       VALIDATE-SEVERITY.
           IF WS-ALERT-SEVERITY NOT = "INFO" AND
              WS-ALERT-SEVERITY NOT = "WARNING" AND
              WS-ALERT-SEVERITY NOT = "CRITICAL"
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-STATE.
           IF WS-ALERT-STATE NOT = "OPEN" AND
              WS-ALERT-STATE NOT = "ACKNOWLEDGED" AND
              WS-ALERT-STATE NOT = "RESOLVED"
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-EMAIL.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-AT-COUNT
           INSPECT WS-ALERT-OWNER TALLYING WS-AT-COUNT FOR ALL "@"
           IF WS-AT-COUNT NOT = 1 OR WS-ALERT-OWNER = SPACES
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
               MOVE "ALERT_CORE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       CHECK-ALERT.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-ALERT-STATE WS-ALERT-OWNER WS-ALERT-TYPE
               WS-ALERT-SEVERITY WS-ALERT-SOURCE WS-ALERT-TITLE
           MOVE "SELECT CONCAT(alert_type, '|', severity, '|', source_key, '|', state, '|', COALESCE(owner_email, '')) FROM ops_alert WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
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
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-ALERT-TYPE
               WS-ALERT-SEVERITY WS-ALERT-SOURCE WS-ALERT-STATE
               WS-ALERT-OWNER
           END-UNSTRING.
           EXIT PARAGRAPH.

       AUDIT-ALERT.
           MOVE "INSERT INTO ops_alert_audit (action, actor_email, alert_id, detail) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-ALERT TO WS-BIND-3
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
           MOVE SPACES TO WS-AUDIT-ALERT
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT-ALERT.
           EXIT PARAGRAPH.

       EVENT-ALERT.
           MOVE "INSERT INTO ops_alert_event (alert_id, event, actor_email, note) VALUES (?, ?, ?, NULLIF(?, ''))" TO WS-PREP-SQL
           MOVE WS-ALERT-ID TO WS-BIND-1
           MOVE WS-EVENT TO WS-BIND-2
           MOVE WS-P6-TRIMMED TO WS-BIND-3
           MOVE WS-P3-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

       RAISE-ALERT.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-ALERT-ID
           MOVE "SELECT id FROM ops_alert WHERE source_key = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-ALERT-SOURCE TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "ERROR|NO_DATA" AND WS-RESULT(1:5) NOT = "ERROR"
               MOVE WS-RESULT(1:20) TO WS-ALERT-ID
               MOVE "1" TO WS-EXISTING
               MOVE "UPDATE ops_alert SET severity = ?, title = ?, detail = ?, state = 'OPEN', resolved_at = NULL, updated_at = NOW() WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-ALERT-SEVERITY TO WS-BIND-1
               MOVE WS-ALERT-TITLE TO WS-BIND-2
               MOVE WS-ALERT-DETAIL TO WS-BIND-3
               MOVE WS-ALERT-ID TO WS-BIND-4
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF.
           MOVE "0" TO WS-EXISTING
           MOVE "INSERT INTO ops_alert (alert_type, severity, source_key, title, detail, created_by) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-ALERT-TYPE TO WS-BIND-1
           MOVE WS-ALERT-SEVERITY TO WS-BIND-2
           MOVE WS-ALERT-SOURCE TO WS-BIND-3
           MOVE WS-ALERT-TITLE TO WS-BIND-4
           MOVE WS-ALERT-DETAIL TO WS-BIND-5
           MOVE WS-P6-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-ALERT-ID
           MOVE "0" TO WS-EXISTING
           MOVE "RAISED" TO WS-EVENT
           MOVE SPACES TO WS-P3-TRIMMED
           PERFORM EVENT-ALERT.
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

       ACTION-RAISE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:32) TO WS-ALERT-TYPE
           MOVE WS-P2-TRIMMED(1:10) TO WS-ALERT-SEVERITY
           PERFORM VALIDATE-SEVERITY
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P3-TRIMMED TO WS-ALERT-SOURCE
           MOVE WS-P4-TRIMMED TO WS-ALERT-TITLE
           MOVE WS-P5-TRIMMED TO WS-ALERT-DETAIL
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           PERFORM RAISE-ALERT
           IF STEP-OK
               MOVE "RAISE" TO WS-AUDIT-ACTION
               MOVE WS-ALERT-ID TO WS-AUDIT-ALERT
               MOVE WS-ALERT-SOURCE TO WS-AUDIT-DETAIL
               PERFORM AUDIT-ALERT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|ALT_RAISED|" DELIMITED BY SIZE WS-ALERT-ID
                   DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-EXISTING
                   DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
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
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:20) TO WS-ALERT-STATE
               PERFORM VALIDATE-STATE
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:10) TO WS-ALERT-SEVERITY
               PERFORM VALIDATE-SEVERITY
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM4 NOT = SPACES
               MOVE WS-P4-TRIMMED(1:WS-P4-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ops_alert WHERE (? = '' OR state = ?) AND (? = '' OR severity = ?)" TO WS-PREP-SQL
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
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(id, ':', alert_type, ':', severity, ':', state, ':', COALESCE(owner_email, ''), ':', source_key, ':', title, ':', created_at) FROM ops_alert WHERE (? = '' OR state = ?) AND (? = '' OR severity = ?) ORDER BY FIELD(severity, 'CRITICAL', 'WARNING', 'INFO'), id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               STRING "SUCCESS|ALT_ALERTS|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|ALT_ALERTS|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
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
           MOVE "SELECT CONCAT(id, '|', alert_type, '|', severity, '|', state, '|', source_key, '|', COALESCE(owner_email, ''), '|', title, '|', detail, '|', created_at, '|', COALESCE(resolved_at, '')) FROM ops_alert WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           STRING "SUCCESS|ALT_ALERT|" DELIMITED BY SIZE WS-RESULT(1:500) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-ACK.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-ALERT-OWNER
           PERFORM VALIDATE-EMAIL
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-ALERT
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-ALERT-STATE = "RESOLVED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE ops_alert SET state = 'ACKNOWLEDGED', owner_email = ?, acknowledged_at = NOW() WHERE id = ? AND state <> 'RESOLVED'" TO WS-PREP-SQL
           MOVE WS-ALERT-OWNER TO WS-BIND-1
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
               MOVE WS-P1-TRIMMED(1:20) TO WS-ALERT-ID
               MOVE "ACKNOWLEDGED" TO WS-EVENT
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM EVENT-ALERT
           END-IF.
           IF STEP-OK
               MOVE "ACK" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-ALERT
               MOVE WS-ALERT-OWNER TO WS-AUDIT-DETAIL
               PERFORM AUDIT-ALERT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|ALT_ACKNOWLEDGED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RESOLVE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-ALERT
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE ops_alert SET state = 'RESOLVED', resolved_at = NOW() WHERE id = ?" TO WS-PREP-SQL
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
               MOVE WS-P1-TRIMMED(1:20) TO WS-ALERT-ID
               MOVE "RESOLVED" TO WS-EVENT
               MOVE WS-P2-TRIMMED TO WS-P3-TRIMMED
               PERFORM EVENT-ALERT
           END-IF.
           IF STEP-OK
               MOVE "RESOLVE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-ALERT
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-ALERT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|ALT_RESOLVED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-NOTE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-ALERT
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE WS-P1-TRIMMED(1:20) TO WS-ALERT-ID
           MOVE "NOTE" TO WS-EVENT
           MOVE WS-P2-TRIMMED TO WS-P3-TRIMMED
           PERFORM EVENT-ALERT
           IF STEP-OK
               MOVE "NOTE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-ALERT
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-ALERT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|ALT_NOTED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-SCAN-OUTBOX.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           MOVE "SELECT CONCAT(id, '|', state, '|', purpose, '|', recipient, '|', COALESCE(last_error, '')) FROM notification_outbox WHERE state IN ('FAILED', 'DEAD') ORDER BY id DESC LIMIT ?" TO WS-PREP-SQL
           MOVE WS-LIMIT TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO WS-ROW-RAW
           IF WS-RESULT NOT = "ERROR|NO_DATA"
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE WS-RESULT(1:16000) TO WS-ROW-RAW
           END-IF.
           MOVE 0 TO WS-RAISED WS-UPDATED
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           PERFORM TRIM-RESULT-LEN
           MOVE WS-RLEN TO WS-ROW-RAWLEN
           MOVE 1 TO WS-ROW-PTR
           PERFORM UNTIL WS-ROW-PTR > WS-ROW-RAWLEN
               MOVE SPACES TO WS-ROW-REC
               UNSTRING WS-ROW-RAW DELIMITED BY ";" INTO WS-ROW-REC
                   WITH POINTER WS-ROW-PTR
               END-UNSTRING
               IF WS-ROW-REC = SPACES
                   EXIT PERFORM
               END-IF
               MOVE SPACES TO WS-ROW-PART1 WS-ROW-PART2 WS-ROW-PART3
                   WS-ROW-PART4 WS-ROW-PART5
               UNSTRING WS-ROW-REC DELIMITED BY "|" INTO WS-ROW-PART1
                   WS-ROW-PART2 WS-ROW-PART3 WS-ROW-PART4 WS-ROW-PART5
               END-UNSTRING
               MOVE SPACES TO WS-ALERT-SOURCE WS-ALERT-TITLE WS-ALERT-DETAIL
               STRING "OUTBOX:" DELIMITED BY SIZE WS-ROW-PART1
                   DELIMITED BY SPACE INTO WS-ALERT-SOURCE END-STRING
               MOVE "OUTBOX" TO WS-ALERT-TYPE
               IF WS-ROW-PART2 = "DEAD"
                   MOVE "CRITICAL" TO WS-ALERT-SEVERITY
               ELSE
                   MOVE "WARNING" TO WS-ALERT-SEVERITY
               END-IF
               STRING "Outbox " DELIMITED BY SIZE WS-ROW-PART2
                   DELIMITED BY SPACE INTO WS-ALERT-TITLE END-STRING
               STRING WS-ROW-PART3 DELIMITED BY SPACE " " DELIMITED BY SIZE
                   WS-ROW-PART4 DELIMITED BY SPACE " " DELIMITED BY SIZE
                   WS-ROW-PART5 DELIMITED BY SPACE INTO WS-ALERT-DETAIL END-STRING
               PERFORM RAISE-ALERT
               IF STEP-OK
                   IF WS-EXISTING = "1"
                       ADD 1 TO WS-UPDATED END-ADD
                   ELSE
                       ADD 1 TO WS-RAISED END-ADD
                   END-IF
               ELSE
                   EXIT PERFORM
               END-IF
           END-PERFORM.
           IF STEP-OK
               MOVE "SCAN_OUTBOX" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-ALERT
               MOVE SPACES TO WS-AUDIT-DETAIL
               STRING "raised:" DELIMITED BY SIZE WS-RAISED DELIMITED BY SIZE
                   " updated:" DELIMITED BY SIZE WS-UPDATED DELIMITED BY SIZE
                   INTO WS-AUDIT-DETAIL END-STRING
               PERFORM AUDIT-ALERT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE WS-RAISED TO WS-RAISED-EDIT
               MOVE WS-UPDATED TO WS-UPDATED-EDIT
               MOVE FUNCTION TRIM(WS-RAISED-EDIT) TO WS-RAISED-TEXT
               MOVE FUNCTION TRIM(WS-UPDATED-EDIT) TO WS-UPDATED-TEXT
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|ALT_SCANNED|" DELIMITED BY SIZE WS-RAISED-TEXT
                   DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-UPDATED-TEXT
                   DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-SCAN-SCHEDULE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED TO WS-DATE-IN
               PERFORM VALIDATE-DATE-FIELD
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "50" TO WS-LIMIT
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           MOVE "SELECT CONCAT(id, '|', template_code, '|', next_run_date) FROM report_schedule WHERE enabled = 1 AND next_run_date IS NOT NULL AND next_run_date <= COALESCE(NULLIF(?, ''), CURDATE()) ORDER BY next_run_date LIMIT ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-LIMIT TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO WS-ROW-RAW
           IF WS-RESULT NOT = "ERROR|NO_DATA"
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE WS-RESULT(1:16000) TO WS-ROW-RAW
           END-IF.
           MOVE 0 TO WS-RAISED WS-UPDATED
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           PERFORM TRIM-RESULT-LEN
           MOVE WS-RLEN TO WS-ROW-RAWLEN
           MOVE 1 TO WS-ROW-PTR
           PERFORM UNTIL WS-ROW-PTR > WS-ROW-RAWLEN
               MOVE SPACES TO WS-ROW-REC
               UNSTRING WS-ROW-RAW DELIMITED BY ";" INTO WS-ROW-REC
                   WITH POINTER WS-ROW-PTR
               END-UNSTRING
               IF WS-ROW-REC = SPACES
                   EXIT PERFORM
               END-IF
               MOVE SPACES TO WS-ROW-PART1 WS-ROW-PART2 WS-ROW-PART3
               UNSTRING WS-ROW-REC DELIMITED BY "|" INTO WS-ROW-PART1
                   WS-ROW-PART2 WS-ROW-PART3
               END-UNSTRING
               MOVE "SCHEDULE" TO WS-ALERT-TYPE
               MOVE "WARNING" TO WS-ALERT-SEVERITY
               MOVE SPACES TO WS-ALERT-SOURCE WS-ALERT-TITLE WS-ALERT-DETAIL
               STRING "SCHEDULE:" DELIMITED BY SIZE WS-ROW-PART1
                   DELIMITED BY SPACE INTO WS-ALERT-SOURCE END-STRING
               MOVE "Report schedule due" TO WS-ALERT-TITLE
               STRING WS-ROW-PART2 DELIMITED BY SPACE " due " DELIMITED BY SIZE
                   WS-ROW-PART3 DELIMITED BY SPACE INTO WS-ALERT-DETAIL END-STRING
               PERFORM RAISE-ALERT
               IF STEP-OK
                   IF WS-EXISTING = "1"
                       ADD 1 TO WS-UPDATED END-ADD
                   ELSE
                       ADD 1 TO WS-RAISED END-ADD
                   END-IF
               ELSE
                   EXIT PERFORM
               END-IF
           END-PERFORM.
           IF STEP-OK
               MOVE "SCAN_SCHEDULE" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-ALERT
               MOVE SPACES TO WS-AUDIT-DETAIL
               STRING "raised:" DELIMITED BY SIZE WS-RAISED DELIMITED BY SIZE
                   " updated:" DELIMITED BY SIZE WS-UPDATED DELIMITED BY SIZE
                   INTO WS-AUDIT-DETAIL END-STRING
               PERFORM AUDIT-ALERT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE WS-RAISED TO WS-RAISED-EDIT
               MOVE WS-UPDATED TO WS-UPDATED-EDIT
               MOVE FUNCTION TRIM(WS-RAISED-EDIT) TO WS-RAISED-TEXT
               MOVE FUNCTION TRIM(WS-UPDATED-EDIT) TO WS-UPDATED-TEXT
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|ALT_SCANNED|" DELIMITED BY SIZE WS-RAISED-TEXT
                   DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-UPDATED-TEXT
                   DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-SCAN-RECON.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           MOVE "SELECT CONCAT(f.finding_id, '|', f.account_id, '|', TIMESTAMPDIFF(HOUR, f.created_at, NOW()), '|', f.balance, '|', f.ledger_sum) FROM reconciliation_findings f JOIN recon_sla_policy s ON s.policy_code = 'DEFAULT' WHERE f.status IN ('OPEN', 'ACKNOWLEDGED') AND s.enabled = 1 AND TIMESTAMPDIFF(HOUR, f.created_at, NOW()) >= s.age_hours ORDER BY f.created_at LIMIT ?" TO WS-PREP-SQL
           MOVE WS-LIMIT TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO WS-ROW-RAW
           IF WS-RESULT NOT = "ERROR|NO_DATA"
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE WS-RESULT(1:16000) TO WS-ROW-RAW
           END-IF.
           MOVE 0 TO WS-RAISED WS-UPDATED
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           PERFORM TRIM-RESULT-LEN
           MOVE WS-RLEN TO WS-ROW-RAWLEN
           MOVE 1 TO WS-ROW-PTR
           PERFORM UNTIL WS-ROW-PTR > WS-ROW-RAWLEN
               MOVE SPACES TO WS-ROW-REC
               UNSTRING WS-ROW-RAW DELIMITED BY ";" INTO WS-ROW-REC
                   WITH POINTER WS-ROW-PTR
               END-UNSTRING
               IF WS-ROW-REC = SPACES
                   EXIT PERFORM
               END-IF
               MOVE SPACES TO WS-ROW-PART1 WS-ROW-PART2 WS-ROW-PART3
                   WS-ROW-PART4 WS-ROW-PART5
               UNSTRING WS-ROW-REC DELIMITED BY "|" INTO WS-ROW-PART1
                   WS-ROW-PART2 WS-ROW-PART3 WS-ROW-PART4 WS-ROW-PART5
               END-UNSTRING
               MOVE "RECON" TO WS-ALERT-TYPE
               MOVE "WARNING" TO WS-ALERT-SEVERITY
               IF FUNCTION NUMVAL(WS-ROW-PART3) > 72
                   MOVE "CRITICAL" TO WS-ALERT-SEVERITY
               END-IF
               MOVE SPACES TO WS-ALERT-SOURCE WS-ALERT-TITLE WS-ALERT-DETAIL
               STRING "RECON:" DELIMITED BY SIZE WS-ROW-PART1
                   DELIMITED BY SPACE INTO WS-ALERT-SOURCE END-STRING
               MOVE "Reconciliation finding aged" TO WS-ALERT-TITLE
               STRING "account " DELIMITED BY SIZE WS-ROW-PART2 DELIMITED BY SPACE
                   " age " DELIMITED BY SIZE WS-ROW-PART3 DELIMITED BY SPACE
                   "h variance " DELIMITED BY SIZE WS-ROW-PART4 DELIMITED BY SPACE
                   "/" DELIMITED BY SIZE WS-ROW-PART5 DELIMITED BY SPACE
                   INTO WS-ALERT-DETAIL END-STRING
               PERFORM RAISE-ALERT
               IF STEP-OK
                   IF WS-EXISTING = "1"
                       ADD 1 TO WS-UPDATED END-ADD
                   ELSE
                       ADD 1 TO WS-RAISED END-ADD
                   END-IF
               ELSE
                   EXIT PERFORM
               END-IF
           END-PERFORM.
           IF STEP-OK
               MOVE "SCAN_RECON" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-ALERT
               MOVE SPACES TO WS-AUDIT-DETAIL
               STRING "raised:" DELIMITED BY SIZE WS-RAISED DELIMITED BY SIZE
                   " updated:" DELIMITED BY SIZE WS-UPDATED DELIMITED BY SIZE
                   INTO WS-AUDIT-DETAIL END-STRING
               PERFORM AUDIT-ALERT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE WS-RAISED TO WS-RAISED-EDIT
               MOVE WS-UPDATED TO WS-UPDATED-EDIT
               MOVE FUNCTION TRIM(WS-RAISED-EDIT) TO WS-RAISED-TEXT
               MOVE FUNCTION TRIM(WS-UPDATED-EDIT) TO WS-UPDATED-TEXT
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|ALT_SCANNED|" DELIMITED BY SIZE WS-RAISED-TEXT
                   DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-UPDATED-TEXT
                   DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-SCAN-DISPUTE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED TO WS-DATE-IN
               PERFORM VALIDATE-DATE-FIELD
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "50" TO WS-LIMIT
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           MOVE "SELECT CONCAT(case_id, '|', subject, '|', due_date, '|', DATEDIFF(CURDATE(), due_date)) FROM dispute_cases WHERE state IN ('OPEN', 'ACKNOWLEDGED') AND due_date IS NOT NULL AND due_date < COALESCE(NULLIF(?, ''), CURDATE()) ORDER BY due_date LIMIT ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-LIMIT TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO WS-ROW-RAW
           IF WS-RESULT NOT = "ERROR|NO_DATA"
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE WS-RESULT(1:16000) TO WS-ROW-RAW
           END-IF.
           MOVE 0 TO WS-RAISED WS-UPDATED
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           PERFORM TRIM-RESULT-LEN
           MOVE WS-RLEN TO WS-ROW-RAWLEN
           MOVE 1 TO WS-ROW-PTR
           PERFORM UNTIL WS-ROW-PTR > WS-ROW-RAWLEN
               MOVE SPACES TO WS-ROW-REC
               UNSTRING WS-ROW-RAW DELIMITED BY ";" INTO WS-ROW-REC
                   WITH POINTER WS-ROW-PTR
               END-UNSTRING
               IF WS-ROW-REC = SPACES
                   EXIT PERFORM
               END-IF
               MOVE SPACES TO WS-ROW-PART1 WS-ROW-PART2 WS-ROW-PART3
                   WS-ROW-PART4
               UNSTRING WS-ROW-REC DELIMITED BY "|" INTO WS-ROW-PART1
                   WS-ROW-PART2 WS-ROW-PART3 WS-ROW-PART4
               END-UNSTRING
               MOVE "DISPUTE" TO WS-ALERT-TYPE
               MOVE "CRITICAL" TO WS-ALERT-SEVERITY
               MOVE SPACES TO WS-ALERT-SOURCE WS-ALERT-TITLE WS-ALERT-DETAIL
               STRING "DISPUTE:" DELIMITED BY SIZE WS-ROW-PART1
                   DELIMITED BY SPACE INTO WS-ALERT-SOURCE END-STRING
               MOVE "Dispute case overdue" TO WS-ALERT-TITLE
               STRING WS-ROW-PART2 DELIMITED BY SPACE " due " DELIMITED BY SIZE
                   WS-ROW-PART3 DELIMITED BY SPACE " (" DELIMITED BY SIZE
                   WS-ROW-PART4 DELIMITED BY SPACE "d)" DELIMITED BY SIZE
                   INTO WS-ALERT-DETAIL END-STRING
               PERFORM RAISE-ALERT
               IF STEP-OK
                   IF WS-EXISTING = "1"
                       ADD 1 TO WS-UPDATED END-ADD
                   ELSE
                       ADD 1 TO WS-RAISED END-ADD
                   END-IF
               ELSE
                   EXIT PERFORM
               END-IF
           END-PERFORM.
           IF STEP-OK
               MOVE "SCAN_DISPUTE" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-ALERT
               MOVE SPACES TO WS-AUDIT-DETAIL
               STRING "raised:" DELIMITED BY SIZE WS-RAISED DELIMITED BY SIZE
                   " updated:" DELIMITED BY SIZE WS-UPDATED DELIMITED BY SIZE
                   INTO WS-AUDIT-DETAIL END-STRING
               PERFORM AUDIT-ALERT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE WS-RAISED TO WS-RAISED-EDIT
               MOVE WS-UPDATED TO WS-UPDATED-EDIT
               MOVE FUNCTION TRIM(WS-RAISED-EDIT) TO WS-RAISED-TEXT
               MOVE FUNCTION TRIM(WS-UPDATED-EDIT) TO WS-UPDATED-TEXT
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|ALT_SCANNED|" DELIMITED BY SIZE WS-RAISED-TEXT
                   DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-UPDATED-TEXT
                   DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
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
           MOVE "SELECT CONCAT(COUNT(*), '|', SUM(state = 'OPEN'), '|', SUM(state = 'ACKNOWLEDGED'), '|', SUM(state = 'RESOLVED'), '|', SUM(severity = 'CRITICAL' AND state <> 'RESOLVED'), '|', SUM(severity = 'WARNING' AND state <> 'RESOLVED')) FROM ops_alert" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|ALT_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:200) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-HISTORY.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-ALERT
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
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ops_alert_event WHERE alert_id = ?" TO WS-PREP-SQL
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
           MOVE "SELECT CONCAT(event, ':', actor_email, ':', COALESCE(note, ''), ':', created_at) FROM ops_alert_event WHERE alert_id = ? ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               STRING "SUCCESS|ALT_HISTORY|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|ALT_HISTORY|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.
