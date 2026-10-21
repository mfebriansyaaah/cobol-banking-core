       IDENTIFICATION DIVISION.
       PROGRAM-ID. recon_ops_core.
      *> Reconciliation assignment rules, auto-assignment, and workloads.

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
       01  WS-FINDING-ID           PIC X(20) VALUE SPACES.
       01  WS-FINDING-STATUS       PIC X(20) VALUE SPACES.
       01  WS-FINDING-OWNER        PIC X(100) VALUE SPACES.
       01  WS-OWNER-EMAIL          PIC X(100) VALUE SPACES.
       01  WS-TO-OWNER             PIC X(100) VALUE SPACES.
       01  WS-RULE-CODE            PIC X(40) VALUE SPACES.
       01  WS-STATUS-FILTER        PIC X(20) VALUE SPACES.
       01  WS-MIN-AGE              PIC X(10) VALUE SPACES.
       01  WS-PRIORITY             PIC X(10) VALUE SPACES.
       01  WS-ENABLED              PIC X(1) VALUE SPACES.
       01  WS-DRY                  PIC X(1) VALUE SPACES.
       01  WS-ASSIGNED             PIC 9(5) VALUE 0.
       01  WS-SKIPPED              PIC 9(5) VALUE 0.
       01  WS-ASSIGNED-OUT         PIC Z(4)9 VALUE 0.
       01  WS-SKIPPED-OUT          PIC Z(4)9 VALUE 0.
       01  WS-ASSIGNED-TEXT        PIC X(5) VALUE SPACES.
       01  WS-SKIPPED-TEXT         PIC X(5) VALUE SPACES.
       01  WS-AGE                  PIC X(10) VALUE SPACES.
       01  WS-ROW-RAW              PIC X(16000) VALUE SPACES.
       01  WS-ROW-RAWLEN           PIC 9(5) VALUE 0.
       01  WS-ROW-PTR              PIC 9(5) VALUE 1.
       01  WS-ROW-REC              PIC X(500) VALUE SPACES.
       01  WS-ROW-PART1            PIC X(100) VALUE SPACES.
       01  WS-ROW-PART2            PIC X(100) VALUE SPACES.
       01  WS-ROW-PART3            PIC X(100) VALUE SPACES.
       01  WS-ROW-PART4            PIC X(100) VALUE SPACES.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-AT-COUNT             PIC 9(3) VALUE 0.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-FINDING        PIC X(20) VALUE SPACES.
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
               WHEN LS-CMD-ACTION(1:12) = "RCP_RULE_SET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RULE-SET
               WHEN LS-CMD-ACTION(1:13) = "RCP_RULE_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RULE-LIST
               WHEN LS-CMD-ACTION(1:12) = "RCP_RULE_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RULE-GET
               WHEN LS-CMD-ACTION(1:15) = "RCP_RULE_DELETE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RULE-DELETE
               WHEN LS-CMD-ACTION(1:16) = "RCP_RULE_PREVIEW"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RULE-PREVIEW
               WHEN LS-CMD-ACTION(1:15) = "RCP_AUTO_ASSIGN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-AUTO-ASSIGN
               WHEN LS-CMD-ACTION(1:17) = "RCP_MANUAL_ASSIGN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-MANUAL-ASSIGN
               WHEN LS-CMD-ACTION(1:12) = "RCP_UNASSIGN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-UNASSIGN
               WHEN LS-CMD-ACTION(1:20) = "RCP_ESCALATE_OVERDUE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ESCALATE-OVERDUE
               WHEN LS-CMD-ACTION(1:12) = "RCP_WORKLOAD"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-WORKLOAD
               WHEN LS-CMD-ACTION(1:11) = "RCP_HISTORY"
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

       VALIDATE-EMAIL-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-AT-COUNT
           INSPECT WS-OWNER-EMAIL TALLYING WS-AT-COUNT FOR ALL "@"
           IF WS-AT-COUNT NOT = 1 OR WS-OWNER-EMAIL = SPACES
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-STATUS-FILTER.
           IF WS-STATUS-FILTER NOT = "ANY" AND
              WS-STATUS-FILTER NOT = "OPEN" AND
              WS-STATUS-FILTER NOT = "ACKNOWLEDGED"
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
               MOVE "RECON_OPS_CORE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       CHECK-OWNER.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE "SELECT id FROM users WHERE email = ? AND status = 'VERIFIED' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-OWNER-EMAIL TO WS-BIND-1
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
           EXIT PARAGRAPH.

       CHECK-RULE.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-RULE-CODE
           MOVE "SELECT rule_code FROM recon_assignment_rule WHERE rule_code = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE WS-RESULT(1:40) TO WS-RULE-CODE.
           EXIT PARAGRAPH.

       CHECK-FINDING.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-FINDING-STATUS WS-FINDING-OWNER
           MOVE WS-P1-TRIMMED(1:20) TO WS-FINDING-ID
           MOVE "SELECT CONCAT(status, '|', COALESCE(owner_email, '')) FROM reconciliation_findings WHERE finding_id = ? LIMIT 1" TO WS-PREP-SQL
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
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-FINDING-STATUS WS-FINDING-OWNER
           END-UNSTRING.
           EXIT PARAGRAPH.

       AUDIT-RCP.
           MOVE "INSERT INTO recon_audit (action, actor_email, finding_id, detail) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-FINDING TO WS-BIND-3
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
           MOVE SPACES TO WS-AUDIT-FINDING
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT-RCP.
           EXIT PARAGRAPH.

       ADD-NOTE.
           MOVE "INSERT INTO recon_note (finding_id, actor_email, note) VALUES (?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-FINDING-ID TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

       ASSIGN-HISTORY.
           MOVE "INSERT INTO recon_assignment (finding_id, from_owner, to_owner, rule_code, assigned_by, note) VALUES (?, NULLIF(?, ''), ?, NULLIF(?, ''), ?, NULLIF(?, ''))" TO WS-PREP-SQL
           MOVE WS-FINDING-ID TO WS-BIND-1
           MOVE WS-FINDING-OWNER TO WS-BIND-2
           MOVE WS-TO-OWNER TO WS-BIND-3
           MOVE WS-RULE-CODE TO WS-BIND-4
           MOVE WS-P6-TRIMMED TO WS-BIND-5
           MOVE WS-P3-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
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

       ACTION-RULE-SET.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
              OR LS-PARAM5 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-OWNER-EMAIL
           PERFORM VALIDATE-EMAIL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P3-TRIMMED(1:20) TO WS-STATUS-FILTER
           PERFORM VALIDATE-STATUS-FILTER
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P4-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) > 8760
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-PRIORITY WS-ENABLED
           UNSTRING WS-P5-TRIMMED DELIMITED BY "," INTO WS-PRIORITY WS-ENABLED
           END-UNSTRING
           MOVE WS-PRIORITY TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) < 1
              OR FUNCTION NUMVAL(WS-COUNT-IN) > 999
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-ENABLED NOT = "0" AND WS-ENABLED NOT = "1"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-OWNER
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
           MOVE "INSERT INTO recon_assignment_rule (rule_code, owner_email, status_filter, min_age_hours, priority, created_by) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE owner_email=VALUES(owner_email), status_filter=VALUES(status_filter), min_age_hours=VALUES(min_age_hours), priority=VALUES(priority)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-STATUS-FILTER TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-PRIORITY TO WS-BIND-5
           MOVE WS-P6-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE recon_assignment_rule SET enabled = ?, updated_by = ? WHERE rule_code = ?" TO WS-PREP-SQL
               MOVE WS-ENABLED TO WS-BIND-1
               MOVE WS-P6-TRIMMED TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
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
               MOVE "RULE_SET" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-FINDING
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-RCP
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|RCP_RULE_SET" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RULE-LIST.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:20) TO WS-STATUS-FILTER
               PERFORM VALIDATE-STATUS-FILTER
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM recon_assignment_rule WHERE (? = '' OR status_filter = ?)" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
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
           MOVE "SELECT CONCAT(rule_code, ':', owner_email, ':', status_filter, ':', min_age_hours, ':', priority, ':', IF(enabled, '1', '0')) FROM recon_assignment_rule WHERE (? = '' OR status_filter = ?) ORDER BY priority, rule_code LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           MOVE WS-OFFSET TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|RCP_RULES|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RCP_RULES|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RULE-GET.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(rule_code, '|', owner_email, '|', status_filter, '|', min_age_hours, '|', priority, '|', IF(enabled, '1', '0')) FROM recon_assignment_rule WHERE rule_code = ? LIMIT 1" TO WS-PREP-SQL
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
           STRING "SUCCESS|RCP_RULE|" DELIMITED BY SIZE WS-RESULT(1:300) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-RULE-DELETE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-RULE
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
           MOVE "DELETE FROM recon_assignment_rule WHERE rule_code = ?" TO WS-PREP-SQL
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
               MOVE "RULE_DELETE" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-FINDING
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-RCP
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|RCP_RULE_DELETED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RULE-PREVIEW.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(status_filter, '|', min_age_hours) FROM recon_assignment_rule WHERE rule_code = ? LIMIT 1" TO WS-PREP-SQL
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
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-STATUS-FILTER WS-MIN-AGE
           END-UNSTRING.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM reconciliation_findings WHERE status IN ('OPEN', 'ACKNOWLEDGED') AND (owner_email IS NULL OR owner_email = '') AND TIMESTAMPDIFF(HOUR, created_at, NOW()) >= ? AND (? = 'ANY' OR status = ?)" TO WS-PREP-SQL
           MOVE WS-MIN-AGE TO WS-BIND-1
           MOVE WS-STATUS-FILTER TO WS-BIND-2
           MOVE WS-STATUS-FILTER TO WS-BIND-3
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
           MOVE "SELECT CONCAT(finding_id, ':', account_id, ':', status, ':', TIMESTAMPDIFF(HOUR, created_at, NOW()), ':', balance, ':', ledger_sum) FROM reconciliation_findings WHERE status IN ('OPEN', 'ACKNOWLEDGED') AND (owner_email IS NULL OR owner_email = '') AND TIMESTAMPDIFF(HOUR, created_at, NOW()) >= ? AND (? = 'ANY' OR status = ?) ORDER BY created_at LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-MIN-AGE TO WS-BIND-1
           MOVE WS-STATUS-FILTER TO WS-BIND-2
           MOVE WS-STATUS-FILTER TO WS-BIND-3
           MOVE WS-LIMIT TO WS-BIND-4
           MOVE WS-OFFSET TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|RCP_PREVIEW|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RCP_PREVIEW|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-AUTO-ASSIGN.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           MOVE "0" TO WS-DRY
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:1) TO WS-DRY
           END-IF.
           IF WS-DRY NOT = "0" AND WS-DRY NOT = "1"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(finding_id, '|', status, '|', TIMESTAMPDIFF(HOUR, created_at, NOW()), '|', COALESCE(owner_email, '')) FROM reconciliation_findings WHERE status IN ('OPEN', 'ACKNOWLEDGED') AND (owner_email IS NULL OR owner_email = '') ORDER BY created_at LIMIT ?" TO WS-PREP-SQL
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
           MOVE 0 TO WS-ASSIGNED WS-SKIPPED
           IF WS-DRY = "0"
               SET STEP-OK TO TRUE
               CALL "SQL_BEGIN" END-CALL
           END-IF.
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
               MOVE WS-ROW-PART1(1:20) TO WS-FINDING-ID
               MOVE WS-ROW-PART2(1:20) TO WS-FINDING-STATUS
               MOVE WS-ROW-PART3(1:10) TO WS-AGE
               MOVE WS-ROW-PART4 TO WS-FINDING-OWNER
               MOVE SPACES TO WS-RULE-CODE WS-TO-OWNER
               MOVE "SELECT CONCAT(rule_code, '|', owner_email) FROM recon_assignment_rule WHERE enabled = 1 AND (status_filter = 'ANY' OR status_filter = ?) AND min_age_hours <= ? ORDER BY priority, rule_code LIMIT 1" TO WS-PREP-SQL
               MOVE WS-FINDING-STATUS TO WS-BIND-1
               MOVE WS-AGE TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT = "ERROR|NO_DATA"
                   ADD 1 TO WS-SKIPPED END-ADD
               ELSE
                   IF WS-RESULT(1:5) = "ERROR"
                       MOVE "ERROR|DB_ERROR" TO WS-ERR
                       SET STEP-FAIL TO TRUE
                   ELSE
                       UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-RULE-CODE
                           WS-TO-OWNER
                       END-UNSTRING
                       IF WS-DRY = "0"
                           MOVE "UPDATE reconciliation_findings SET owner_email = ? WHERE finding_id = ? AND status IN ('OPEN', 'ACKNOWLEDGED')" TO WS-PREP-SQL
                           MOVE WS-TO-OWNER TO WS-BIND-1
                           MOVE WS-FINDING-ID TO WS-BIND-2
                           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                           END-CALL
                           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                           IF WS-RESULT(1:5) = "ERROR"
                               SET STEP-FAIL TO TRUE
                           ELSE
                               MOVE "auto-assigned" TO WS-P3-TRIMMED
                               PERFORM ASSIGN-HISTORY
                               PERFORM ADD-NOTE
                           END-IF
                       END-IF
                       ADD 1 TO WS-ASSIGNED END-ADD
                   END-IF
               END-IF
               IF STEP-FAIL
                   EXIT PERFORM
               END-IF
           END-PERFORM.
           IF WS-DRY = "0"
               IF STEP-OK
                   MOVE "AUTO_ASSIGN" TO WS-AUDIT-ACTION
                   MOVE SPACES TO WS-AUDIT-FINDING
                   MOVE SPACES TO WS-AUDIT-DETAIL
                   STRING "assigned:" DELIMITED BY SIZE WS-ASSIGNED DELIMITED BY SIZE
                       " skipped:" DELIMITED BY SIZE WS-SKIPPED DELIMITED BY SIZE
                       INTO WS-AUDIT-DETAIL END-STRING
                   PERFORM AUDIT-RCP
               END-IF
           END-IF.
           IF STEP-OK
               IF WS-DRY = "0"
                   CALL "SQL_COMMIT" END-CALL
               END-IF
               MOVE WS-ASSIGNED TO WS-ASSIGNED-OUT
               MOVE WS-SKIPPED TO WS-SKIPPED-OUT
               MOVE FUNCTION TRIM(WS-ASSIGNED-OUT) TO WS-ASSIGNED-TEXT
               MOVE FUNCTION TRIM(WS-SKIPPED-OUT) TO WS-SKIPPED-TEXT
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|RCP_AUTO_ASSIGN|" DELIMITED BY SIZE
                   WS-ASSIGNED-TEXT DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-SKIPPED-TEXT DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-DRY DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               IF WS-DRY = "0"
                   CALL "SQL_ROLLBACK" END-CALL
               END-IF
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-MANUAL-ASSIGN.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-OWNER-EMAIL
           PERFORM VALIDATE-EMAIL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-FINDING
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-FINDING-STATUS NOT = "OPEN" AND WS-FINDING-STATUS NOT = "ACKNOWLEDGED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-OWNER
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-TO-OWNER
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE reconciliation_findings SET owner_email = ? WHERE finding_id = ? AND status IN ('OPEN', 'ACKNOWLEDGED')" TO WS-PREP-SQL
           MOVE WS-TO-OWNER TO WS-BIND-1
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
               PERFORM ASSIGN-HISTORY
               PERFORM ADD-NOTE
           END-IF.
           IF STEP-OK
               MOVE "MANUAL_ASSIGN" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-FINDING
               MOVE WS-TO-OWNER TO WS-AUDIT-DETAIL
               PERFORM AUDIT-RCP
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|RCP_ASSIGNED|" DELIMITED BY SIZE WS-TO-OWNER DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-UNASSIGN.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-FINDING
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-FINDING-OWNER = SPACES
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE reconciliation_findings SET owner_email = NULL WHERE finding_id = ?" TO WS-PREP-SQL
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
               MOVE SPACES TO WS-TO-OWNER WS-RULE-CODE
               MOVE WS-P2-TRIMMED TO WS-P3-TRIMMED
               PERFORM ASSIGN-HISTORY
               PERFORM ADD-NOTE
           END-IF.
           IF STEP-OK
               MOVE "UNASSIGN" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-FINDING
               MOVE WS-FINDING-OWNER TO WS-AUDIT-DETAIL
               PERFORM AUDIT-RCP
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|RCP_UNASSIGNED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-ESCALATE-OVERDUE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) > 8760
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-OWNER-EMAIL
           PERFORM VALIDATE-EMAIL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-OWNER
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-LIMIT
           END-IF.
           MOVE "SELECT CONCAT(finding_id, '|', COALESCE(owner_email, '')) FROM reconciliation_findings WHERE status IN ('OPEN', 'ACKNOWLEDGED') AND TIMESTAMPDIFF(HOUR, created_at, NOW()) >= ? AND (owner_email IS NULL OR owner_email <> ?) ORDER BY created_at LIMIT ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
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
           MOVE 0 TO WS-ASSIGNED
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
               MOVE SPACES TO WS-ROW-PART1 WS-ROW-PART2
               UNSTRING WS-ROW-REC DELIMITED BY "|" INTO WS-ROW-PART1
                   WS-ROW-PART2
               END-UNSTRING
               MOVE WS-ROW-PART1(1:20) TO WS-FINDING-ID
               MOVE WS-ROW-PART2 TO WS-FINDING-OWNER
               MOVE WS-P2-TRIMMED TO WS-TO-OWNER
               MOVE "OVERDUE_ESCALATION" TO WS-RULE-CODE
               MOVE "escalated overdue finding" TO WS-P3-TRIMMED
               MOVE "UPDATE reconciliation_findings SET owner_email = ? WHERE finding_id = ?" TO WS-PREP-SQL
               MOVE WS-TO-OWNER TO WS-BIND-1
               MOVE WS-FINDING-ID TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   PERFORM ASSIGN-HISTORY
                   PERFORM ADD-NOTE
                   ADD 1 TO WS-ASSIGNED END-ADD
               END-IF
               IF STEP-FAIL
                   EXIT PERFORM
               END-IF
           END-PERFORM.
           IF STEP-OK
               MOVE "ESCALATE_OVERDUE" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-FINDING
               MOVE WS-ASSIGNED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-RCP
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE WS-ASSIGNED TO WS-ASSIGNED-OUT
               MOVE FUNCTION TRIM(WS-ASSIGNED-OUT) TO WS-ASSIGNED-TEXT
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|RCP_ESCALATED|" DELIMITED BY SIZE
                   WS-ASSIGNED-TEXT DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-WORKLOAD.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COALESCE(owner_email, 'UNASSIGNED'), ':', COUNT(*), ':', SUM(status = 'OPEN'), ':', SUM(status = 'ACKNOWLEDGED')) FROM reconciliation_findings GROUP BY owner_email ORDER BY COUNT(*) DESC" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
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
               MOVE "SUCCESS|RCP_WORKLOAD|0" TO LS-OUTPUT-BUFFER
           ELSE
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RCP_WORKLOAD|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
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
           PERFORM CHECK-FINDING
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
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM recon_assignment WHERE finding_id = ?" TO WS-PREP-SQL
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
           MOVE "SELECT CONCAT(COALESCE(from_owner, '-'), ':', to_owner, ':', COALESCE(rule_code, '-'), ':', assigned_by, ':', COALESCE(note, ''), ':', created_at) FROM recon_assignment WHERE finding_id = ? ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               STRING "SUCCESS|RCP_HISTORY|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RCP_HISTORY|" DELIMITED BY SIZE WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.
