       IDENTIFICATION DIVISION.
       PROGRAM-ID. retention_job_core.
      *> Retention policies and execution runs. The AUDIT data class archives
      *> expired audit rows but never touches a subject under an active legal
      *> hold; re-running is idempotent.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESULT               PIC X(16384) VALUE SPACES.
       01  WS-PREP-SQL             PIC X(2048) VALUE SPACES.
       01  WS-QUERY                PIC X(2048) VALUE SPACES.
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
       01  WS-Q1                   PIC X(100) VALUE SPACES.
       01  WS-Q2                   PIC X(100) VALUE SPACES.
       01  WS-Q1-LEN               PIC 9(3) VALUE 1.
       01  WS-ARCH-COUNT           PIC X(20) VALUE SPACES.
       01  WS-DEL-COUNT            PIC X(20) VALUE SPACES.
       01  WS-SKIP-COUNT           PIC X(20) VALUE SPACES.
       01  WS-RUN-DETAIL           PIC X(255) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-RUN            PIC X(20) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
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
               WHEN LS-CMD-ACTION(1:14) = "RTJ_POLICY_SET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POLICY-SET
               WHEN LS-CMD-ACTION(1:15) = "RTJ_POLICY_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POLICY-LIST
               WHEN LS-CMD-ACTION(1:14) = "RTJ_POLICY_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-POLICY-GET
               WHEN LS-CMD-ACTION(1:12) = "RTJ_RUN_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-LIST
               WHEN LS-CMD-ACTION(1:11) = "RTJ_RUN_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-GET
               WHEN LS-CMD-ACTION(1:7) = "RTJ_RUN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN
               WHEN LS-CMD-ACTION(1:11) = "RTJ_SUMMARY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SUMMARY
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

       VALIDATE-DAYS.
           MOVE WS-P2-TRIMMED TO WS-Q1
           MOVE 0 TO WS-Q1-LEN
           PERFORM VARYING WS-I FROM 100 BY -1
               UNTIL WS-I < 1 OR WS-Q1-LEN > 0
               IF WS-Q1(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-Q1-LEN
               END-IF
           END-PERFORM
           IF WS-Q1-LEN < 1 OR WS-Q1-LEN > 4
               MOVE 1 TO WS-BAD
               EXIT PARAGRAPH
           END-IF
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-Q1-LEN
               IF WS-Q1(WS-I:1) IS NOT NUMERIC
                   MOVE 1 TO WS-BAD
               END-IF
           END-PERFORM.
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
               MOVE "RETENTION_JOB_CORE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       AUDIT.
           MOVE "INSERT INTO retention_job_audit (action, actor_email, run_id, detail) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-RUN TO WS-BIND-3
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
           MOVE SPACES TO WS-AUDIT-RUN
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

       ACTION-POLICY-SET.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED NOT = "AUDIT" AND WS-P1-TRIMMED NOT = "ACCOUNT"
               AND WS-P1-TRIMMED NOT = "USER" AND WS-P1-TRIMMED NOT = "EXPORT"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE 0 TO WS-BAD
           PERFORM VALIDATE-DAYS
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-Q1) < 1
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           IF FUNCTION NUMVAL(WS-Q1) > 3650
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM3 NOT = SPACES AND LS-PARAM3 NOT = "0" AND LS-PARAM3 NOT = "1"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO retention_job_policy (data_class, retention_days, enabled, created_by) VALUES (?, ?, COALESCE(NULLIF(?, ''), '1'), ?) ON DUPLICATE KEY UPDATE retention_days = VALUES(retention_days), enabled = VALUES(enabled)" TO WS-PREP-SQL
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
               MOVE "POLICY_SET" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-RUN
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|RTJ_POLICY_SAVED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-POLICY-LIST.
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
           MOVE "SELECT CONCAT(data_class, ':', retention_days, ':', IF(enabled, '1', '0')) FROM retention_job_policy ORDER BY data_class LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-LIMIT TO WS-BIND-1
           MOVE WS-OFFSET TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|RTJ_POLICIES|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RTJ_POLICIES|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-POLICY-GET.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(data_class, ':', retention_days, ':', IF(enabled, '1', '0'), ':', created_by) FROM retention_job_policy WHERE data_class = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE SPACES TO LS-OUTPUT-BUFFER
           PERFORM TRIM-RESULT-LEN
           STRING "SUCCESS|RTJ_POLICY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
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
           MOVE "SELECT CONCAT(retention_days, '|', IF(enabled, '1', '0')) FROM retention_job_policy WHERE data_class = ? LIMIT 1" TO WS-PREP-SQL
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
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-Q1 WS-Q2
           END-UNSTRING
           IF WS-Q2 = "0"
               MOVE "ERROR|POLICY_DISABLED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-Q1 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-LEN TO WS-Q1-LEN
           MOVE "0" TO WS-ARCH-COUNT
           MOVE "0" TO WS-DEL-COUNT
           MOVE "0" TO WS-SKIP-COUNT
           MOVE SPACES TO WS-RUN-DETAIL
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           IF WS-P1-TRIMMED = "AUDIT"
               PERFORM RUN-COUNT-ARCHIVE
               PERFORM RUN-COUNT-SKIP
               PERFORM RUN-ARCHIVE-AUDIT
               PERFORM RUN-DELETE-AUDIT
               MOVE WS-ARCH-COUNT TO WS-DEL-COUNT
           ELSE
               MOVE "NO_ELIGIBLE" TO WS-RUN-DETAIL
           END-IF
           IF STEP-OK
               PERFORM RUN-INSERT
           END-IF
           IF STEP-OK
               MOVE "RETENTION_RUN" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-RUN
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|RTJ_RUN_COMPLETED|" DELIMITED BY SIZE
                   WS-ARCH-COUNT DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-SKIP-COUNT DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       RUN-COUNT-ARCHIVE.
           MOVE SPACES TO WS-QUERY
           STRING "SELECT CAST(COUNT(*) AS CHAR) FROM audit_trail a JOIN users u ON a.user_id = u.id WHERE a.created_at < DATE_SUB(NOW(), INTERVAL " DELIMITED BY SIZE
               WS-Q1(1:WS-Q1-LEN) DELIMITED BY SIZE
               " DAY) AND NOT EXISTS (SELECT 1 FROM legal_hold lh WHERE lh.subject_email = u.email AND lh.status = 'ACTIVE')" DELIMITED BY SIZE
               INTO WS-QUERY END-STRING
           CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
           CALL "SQL_EXECUTE" END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           ELSE
               MOVE WS-RESULT(1:20) TO WS-ARCH-COUNT
           END-IF.
           EXIT PARAGRAPH.

       RUN-COUNT-SKIP.
           MOVE SPACES TO WS-QUERY
           STRING "SELECT CAST(COUNT(*) AS CHAR) FROM audit_trail a JOIN users u ON a.user_id = u.id WHERE a.created_at < DATE_SUB(NOW(), INTERVAL " DELIMITED BY SIZE
               WS-Q1(1:WS-Q1-LEN) DELIMITED BY SIZE
               " DAY) AND EXISTS (SELECT 1 FROM legal_hold lh WHERE lh.subject_email = u.email AND lh.status = 'ACTIVE')" DELIMITED BY SIZE
               INTO WS-QUERY END-STRING
           CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
           CALL "SQL_EXECUTE" END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           ELSE
               MOVE WS-RESULT(1:20) TO WS-SKIP-COUNT
           END-IF.
           EXIT PARAGRAPH.

       RUN-ARCHIVE-AUDIT.
           MOVE SPACES TO WS-QUERY
           STRING "INSERT IGNORE INTO audit_trail_archive (audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, journal_id, created_at) SELECT a.audit_id, a.user_id, a.actor_id, a.action, a.entity_type, a.entity_id, a.detail, a.status, a.journal_id, a.created_at FROM audit_trail a JOIN users u ON a.user_id = u.id WHERE a.created_at < DATE_SUB(NOW(), INTERVAL " DELIMITED BY SIZE
               WS-Q1(1:WS-Q1-LEN) DELIMITED BY SIZE
               " DAY) AND NOT EXISTS (SELECT 1 FROM legal_hold lh WHERE lh.subject_email = u.email AND lh.status = 'ACTIVE')" DELIMITED BY SIZE
               INTO WS-QUERY END-STRING
           CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
           CALL "SQL_EXECUTE" END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

       RUN-DELETE-AUDIT.
           MOVE SPACES TO WS-QUERY
           STRING "DELETE FROM audit_trail WHERE created_at < DATE_SUB(NOW(), INTERVAL " DELIMITED BY SIZE
               WS-Q1(1:WS-Q1-LEN) DELIMITED BY SIZE
               " DAY) AND user_id NOT IN (SELECT id FROM users WHERE email IN (SELECT subject_email FROM legal_hold WHERE status = 'ACTIVE'))" DELIMITED BY SIZE
               INTO WS-QUERY END-STRING
           CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
           CALL "SQL_EXECUTE" END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

       RUN-INSERT.
           MOVE SPACES TO WS-PREP-SQL
           STRING "INSERT INTO retention_job_run (data_class, status, cutoff_at, archived_count, deleted_count, skipped_count, detail, executed_by, finished_at) VALUES (?, 'COMPLETED', DATE_SUB(NOW(), INTERVAL " DELIMITED BY SIZE
               WS-Q1(1:WS-Q1-LEN) DELIMITED BY SIZE
               " DAY), ?, ?, ?, NULLIF(?, ''), ?, NOW())" DELIMITED BY SIZE
               INTO WS-PREP-SQL END-STRING
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-ARCH-COUNT TO WS-BIND-2
           MOVE WS-DEL-COUNT TO WS-BIND-3
           MOVE WS-SKIP-COUNT TO WS-BIND-4
           MOVE WS-RUN-DETAIL TO WS-BIND-5
           MOVE WS-P6-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
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
           MOVE "SELECT CONCAT(id, ':', data_class, ':', status, ':', archived_count, ':', deleted_count, ':', skipped_count) FROM retention_job_run WHERE (? = '' OR status = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               MOVE "SUCCESS|RTJ_RUNS|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|RTJ_RUNS|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-GET.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(id, ':', data_class, ':', status, ':', archived_count, ':', deleted_count, ':', skipped_count, ':', COALESCE(detail, ''), ':', executed_by) FROM retention_job_run WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE SPACES TO LS-OUTPUT-BUFFER
           PERFORM TRIM-RESULT-LEN
           STRING "SUCCESS|RTJ_RUN|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-SUMMARY.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'COMPLETED'), 0), '|', COALESCE(SUM(status = 'FAILED'), 0), '|', COALESCE(SUM(archived_count), 0), '|', COALESCE(SUM(skipped_count), 0)) FROM retention_job_run" TO WS-PREP-SQL
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
           STRING "SUCCESS|RTJ_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:200) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.
