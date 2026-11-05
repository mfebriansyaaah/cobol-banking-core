       IDENTIFICATION DIVISION.
       PROGRAM-ID. eod_jobs_core.
      *> EOD job execution: hold expiry, dormancy, reconciliation, statements.

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
       01  WS-DATE-IN              PIC X(100) VALUE SPACES.
       01  WS-DATE-LEN             PIC 9(3) VALUE 0.
       01  WS-JOB-ID               PIC X(20) VALUE SPACES.
       01  WS-JOB-CODE             PIC X(20) VALUE SPACES.
       01  WS-JOB-STATUS           PIC X(20) VALUE SPACES.
       01  WS-JOB-PROCESSED        PIC X(20) VALUE SPACES.
       01  WS-JOB-DETAIL           PIC X(255) VALUE SPACES.
       01  WS-JOB-ERROR            PIC X(40) VALUE SPACES.
       01  WS-RUN-ID               PIC X(20) VALUE SPACES.
       01  WS-CODE-IN              PIC X(100) VALUE SPACES.
       01  WS-CODE-LEN             PIC 9(3) VALUE 0.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-RET-DAYS             PIC X(10) VALUE SPACES.
       01  WS-RET-SQL              PIC X(1024) VALUE SPACES.
       01  WS-CALL-ACTION          PIC X(30) VALUE SPACES.
       01  WS-CALL-P1              PIC X(100) VALUE SPACES.
       01  WS-CALL-P2              PIC X(100) VALUE SPACES.
       01  WS-CALL-P3              PIC X(100) VALUE SPACES.
       01  WS-CALL-P4              PIC X(100) VALUE SPACES.
       01  WS-CALL-P5              PIC X(100) VALUE SPACES.
       01  WS-CALL-P6              PIC X(100) VALUE SPACES.
       01  WS-CALL-OUT             PIC X(16384) VALUE SPACES.
       01  WS-CALL-KIND            PIC X(20) VALUE SPACES.
       01  WS-CALL-CODE            PIC X(40) VALUE SPACES.
       01  WS-CALL-VALUE           PIC X(100) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-DATE           PIC X(10) VALUE SPACES.
       01  WS-AUDIT-RUN            PIC X(20) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-PART                 PIC X(16384) VALUE SPACES.
       01  WS-PART-LEN             PIC 9(5) VALUE 0.
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
               WHEN LS-CMD-ACTION(1:19) = "EODJOB_HOLD_EXPIRY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-HOLD-EXPIRY
               WHEN LS-CMD-ACTION(1:20) = "EODJOB_DORMANT_MARK"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-DORMANT-MARK
               WHEN LS-CMD-ACTION(1:20) = "EODJOB_DORM_SUSPEND"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-DORMANT-SUSPEND
               WHEN LS-CMD-ACTION(1:13) = "EODJOB_RECON"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RECON
               WHEN LS-CMD-ACTION(1:17) = "EODJOB_STATEMENT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-STATEMENT
               WHEN LS-CMD-ACTION(1:12) = "EODJOB_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-JOB-LIST
               WHEN LS-CMD-ACTION(1:20) = "EODJOB_PENDING_PURGE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-PENDING-PURGE
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

        COPY "common_trim.cpy".
        COPY "common_validate.cpy".


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
               MOVE "EOD_JOBS_CORE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       AUDIT-EOD.
           MOVE "INSERT INTO eod_audit (action, actor_email, business_date, run_id, detail) VALUES (?, ?, NULLIF(?, ''), NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-DATE TO WS-BIND-3
           MOVE WS-AUDIT-RUN TO WS-BIND-4
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
           MOVE SPACES TO WS-AUDIT-DATE WS-AUDIT-RUN
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT-EOD.
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

       START-JOB.
           MOVE SPACES TO WS-ERR
           SET STEP-OK TO TRUE
           MOVE "INSERT INTO eod_job_run (business_date, job_code, status, actor_email) VALUES (?, ?, 'RUNNING', ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-JOB-CODE TO WS-BIND-2
           MOVE WS-P6-TRIMMED TO WS-BIND-3
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
               MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-JOB-ID
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       FINISH-JOB.
           IF STEP-OK
               MOVE "UPDATE eod_job_run SET status = 'COMPLETED', processed_count = ?, detail = ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-JOB-PROCESSED TO WS-BIND-1
               MOVE WS-JOB-DETAIL TO WS-BIND-2
               MOVE WS-JOB-ID TO WS-BIND-3
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
               CALL "SQL_COMMIT" END-CALL
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
           END-IF.
           EXIT PARAGRAPH.

       ACTION-HOLD-EXPIRY.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "HOLD_EXPIRY" TO WS-JOB-CODE
           MOVE "SELECT 1 FROM eod_job_run WHERE business_date = ? AND job_code = 'HOLD_EXPIRY' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "1"
               MOVE "ERROR|JOB_ALREADY_RUN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM START-JOB
           IF STEP-OK
               MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM account_holds WHERE state = 'PLACED' AND expires_at IS NOT NULL AND expires_at <= NOW()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-JOB-PROCESSED
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.user_id, NULL, 'HOLD_EXPIRED', 'HOLD', CAST(h.hold_id AS CHAR), 'EOD', 'SUCCESS' FROM account_holds h JOIN accounts a ON a.account_id = h.account_id WHERE h.state = 'PLACED' AND h.expires_at IS NOT NULL AND h.expires_at <= NOW()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
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
               MOVE "UPDATE account_holds SET state = 'EXPIRED' WHERE state = 'PLACED' AND expires_at IS NOT NULL AND expires_at <= NOW()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
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
               MOVE "HOLD_EXPIRY" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:10) TO WS-AUDIT-DATE
               MOVE WS-JOB-ID TO WS-AUDIT-RUN
               MOVE WS-JOB-PROCESSED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           PERFORM FINISH-JOB
           IF STEP-OK
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|EOD_HOLD_EXPIRED|" DELIMITED BY SIZE
                      WS-JOB-PROCESSED DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-PENDING-PURGE.
           *> Archive and prune pending_transactions older than the retention
           *> window. Runs as a bounded EOD job, never inside a money
           *> transaction, so it cannot extend a transfer's lock/undo scope.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "PENDING_PURGE" TO WS-JOB-CODE
           MOVE "SELECT 1 FROM eod_job_run WHERE business_date = ? AND job_code = 'PENDING_PURGE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "1"
               MOVE "ERROR|JOB_ALREADY_RUN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Retention window: PENDING_RETENTION_DAYS env, default 30.
           MOVE SPACES TO WS-RET-DAYS
           CALL "env_or" USING BY REFERENCE "PENDING_RETENTION_DAYS"
               BY REFERENCE "30" BY REFERENCE WS-RET-DAYS
           END-CALL
           MOVE WS-RET-DAYS TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_RETENTION" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM START-JOB
           IF STEP-OK
               MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM pending_transactions WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)" TO WS-PREP-SQL
               MOVE WS-RET-DAYS TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-JOB-PROCESSED
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSERT IGNORE INTO pending_transactions_archive (id, txn_ref, from_email, to_email, amount, status, created_at, updated_at) SELECT id, txn_ref, from_email, to_email, amount, status, created_at, updated_at FROM pending_transactions WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)" TO WS-PREP-SQL
               MOVE WS-RET-DAYS TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
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
               MOVE "DELETE FROM pending_transactions WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)" TO WS-PREP-SQL
               MOVE WS-RET-DAYS TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
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
               MOVE "PENDING_PURGE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:10) TO WS-AUDIT-DATE
               MOVE WS-JOB-ID TO WS-AUDIT-RUN
               MOVE WS-JOB-PROCESSED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           PERFORM FINISH-JOB
           IF STEP-OK
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|EOD_PENDING_PURGED|" DELIMITED BY SIZE
                      WS-JOB-PROCESSED DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-DORMANT-MARK.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "DORMANT_MARK" TO WS-JOB-CODE
           PERFORM START-JOB
           IF STEP-OK
               MOVE "MARK_DORMANT" TO WS-CALL-ACTION
               MOVE WS-P6-TRIMMED TO WS-CALL-P1
               MOVE SPACES TO WS-CALL-P2 WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6
               CALL "user_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                   WS-CALL-P3 WS-CALL-P4 WS-CALL-OUT
               END-CALL
               IF WS-CALL-OUT(1:5) = "ERROR"
                   MOVE WS-CALL-OUT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE "0" TO WS-JOB-PROCESSED
                   UNSTRING WS-CALL-OUT DELIMITED BY "|"
                       INTO WS-CALL-KIND WS-CALL-CODE WS-CALL-VALUE
                   END-UNSTRING
                   MOVE WS-CALL-VALUE(1:20) TO WS-JOB-PROCESSED
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "DORMANT_MARK" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:10) TO WS-AUDIT-DATE
               MOVE WS-JOB-ID TO WS-AUDIT-RUN
               MOVE WS-JOB-PROCESSED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           PERFORM FINISH-JOB
           IF STEP-OK
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|EOD_DORMANT_MARKED|" DELIMITED BY SIZE
                      WS-JOB-PROCESSED DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-DORMANT-SUSPEND.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "DORMANT_SUSPEND" TO WS-JOB-CODE
           PERFORM START-JOB
           IF STEP-OK
               MOVE "SUSPEND_DORMANT" TO WS-CALL-ACTION
               MOVE WS-P6-TRIMMED TO WS-CALL-P1
               MOVE SPACES TO WS-CALL-P2 WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6
               CALL "user_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                   WS-CALL-P3 WS-CALL-P4 WS-CALL-OUT
               END-CALL
               IF WS-CALL-OUT(1:5) = "ERROR"
                   MOVE WS-CALL-OUT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE "0" TO WS-JOB-PROCESSED
                   UNSTRING WS-CALL-OUT DELIMITED BY "|"
                       INTO WS-CALL-KIND WS-CALL-CODE WS-CALL-VALUE
                   END-UNSTRING
                   MOVE WS-CALL-VALUE(1:20) TO WS-JOB-PROCESSED
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "DORMANT_SUSPEND" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:10) TO WS-AUDIT-DATE
               MOVE WS-JOB-ID TO WS-AUDIT-RUN
               MOVE WS-JOB-PROCESSED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           PERFORM FINISH-JOB
           IF STEP-OK
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|EOD_DORMANT_SUSPENDED|" DELIMITED BY SIZE
                      WS-JOB-PROCESSED DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RECON.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "RECON" TO WS-JOB-CODE
           PERFORM START-JOB
           IF STEP-OK
               MOVE "RUN_RECONCILIATION" TO WS-CALL-ACTION
               MOVE WS-P6-TRIMMED TO WS-CALL-P1
               MOVE "SCHEDULED" TO WS-CALL-P2
               MOVE SPACES TO WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6
               CALL "wallet_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                   WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
               END-CALL
               IF WS-CALL-OUT(1:5) = "ERROR"
                   MOVE WS-CALL-OUT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-CALL-OUT(1:255) TO WS-JOB-DETAIL
                   MOVE "0" TO WS-JOB-PROCESSED
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "RECON" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:10) TO WS-AUDIT-DATE
               MOVE WS-JOB-ID TO WS-AUDIT-RUN
               MOVE WS-JOB-DETAIL TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           PERFORM FINISH-JOB
           IF STEP-OK
               MOVE "SUCCESS|EOD_RECON_RUN" TO LS-OUTPUT-BUFFER
           ELSE
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-STATEMENT.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "STATEMENT" TO WS-JOB-CODE
           PERFORM START-JOB
           IF STEP-OK
               MOVE "STMT_RUN_START" TO WS-CALL-ACTION
               MOVE WS-P1-TRIMMED TO WS-CALL-P1
               MOVE WS-P2-TRIMMED TO WS-CALL-P2
               MOVE WS-P3-TRIMMED TO WS-CALL-P3
               MOVE SPACES TO WS-CALL-P4 WS-CALL-P5
               MOVE WS-P6-TRIMMED TO WS-CALL-P6
               CALL "statement_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                   WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
               END-CALL
               IF WS-CALL-OUT(1:5) = "ERROR"
                   MOVE WS-CALL-OUT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   UNSTRING WS-CALL-OUT DELIMITED BY "|"
                       INTO WS-CALL-KIND WS-CALL-CODE WS-CALL-VALUE
                   END-UNSTRING
                   MOVE WS-CALL-VALUE(1:20) TO WS-RUN-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "STMT_RUN_GENERATE" TO WS-CALL-ACTION
               MOVE WS-RUN-ID TO WS-CALL-P1
               MOVE SPACES TO WS-CALL-P2 WS-CALL-P3 WS-CALL-P4 WS-CALL-P5
               MOVE WS-P6-TRIMMED TO WS-CALL-P6
               CALL "statement_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                   WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
               END-CALL
               IF WS-CALL-OUT(1:5) = "ERROR"
                   MOVE WS-CALL-OUT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RUN-ID TO WS-JOB-DETAIL
                   MOVE "0" TO WS-JOB-PROCESSED
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "STATEMENT" TO WS-AUDIT-ACTION
               MOVE WS-P2-TRIMMED(1:10) TO WS-AUDIT-DATE
               MOVE WS-JOB-ID TO WS-AUDIT-RUN
               MOVE WS-RUN-ID TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           PERFORM FINISH-JOB
           IF STEP-OK
               MOVE "SUCCESS|EOD_STATEMENT_RUN" TO LS-OUTPUT-BUFFER
           ELSE
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-JOB-LIST.
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
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM eod_job_run WHERE (? = '' OR status = ?) AND (? = '' OR business_date = ?)" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
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
           MOVE "SELECT CONCAT(id, ':', business_date, ':', job_code, ':', status, ':', processed_count, ':', COALESCE(error_code, '')) FROM eod_job_run WHERE (? = '' OR status = ?) AND (? = '' OR business_date = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-LIMIT TO WS-BIND-5
           MOVE WS-OFFSET TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|EOD_JOBS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|EOD_JOBS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.
