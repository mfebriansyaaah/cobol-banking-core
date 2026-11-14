        IDENTIFICATION DIVISION.
        PROGRAM-ID. wallet_recon_core.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.

       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01  WS-EXIT-CODE            PIC 9(2) VALUE 0.
        01  WS-RESULT               PIC X(16384) VALUE SPACES.
        01  WS-PARAM1-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM2-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM3-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM4-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM5-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM6-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-P5-LEN               PIC 9(3) VALUE 1.
        01  WS-P6-LEN               PIC 9(3) VALUE 1.
        01  WS-I                   PIC 9(3).
        01  WS-J                    PIC 9(5) VALUE 0.
        01  WS-TRIM-IDX             PIC 9     VALUE 0.
        01  WS-TRIM-SRC             PIC X(100) VALUE SPACES.
        01  WS-TRIM-CNT             PIC 9(3)  VALUE 0.
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-AMT-DOTS            PIC 9(2) VALUE 0.
        01  WS-AMT-DIGITS          PIC 9(2) VALUE 0.
        01  WS-AMT-FRAC            PIC 9(2) VALUE 0.
        01  WS-AMT-SEEN-DOT        PIC X(1) VALUE "0".
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
        01  WS-DENIED-TARGET        PIC X(100) VALUE SPACES.
        01  WS-PERM-REQ             PIC X(30) VALUE SPACES.
        01  WS-PERM-ACTOR           PIC X(100) VALUE SPACES.
        COPY "wallet_ws_common.cpy".
        01  WS-CAP-SRC             PIC X(20) VALUE SPACES.
        01  WS-CAP-OK              PIC X(1) VALUE "Y".
        01  WS-CAP-LEN             PIC 9(3) VALUE 0.
        01  WS-PREC-NUM            PIC S9(4) VALUE 0.
        01  WS-RUN-ID              PIC X(20) VALUE SPACES.
        01  WS-RUN-TRIGGER         PIC X(10) VALUE SPACES.
        01  WS-RUN-COUNT           PIC X(10) VALUE SPACES.
        01  WS-RLIMIT              PIC X(10) VALUE "50".
        01  WS-ROFFSET             PIC X(10) VALUE "0".
        01  WS-RTOTAL              PIC X(20) VALUE SPACES.
        01  WS-RLEN                PIC 9(5)  VALUE 0.
        01  WS-BUSY                PIC X(1) VALUE "0".
        01  WS-FX-HAS              PIC X(1)  VALUE "0".

        LINKAGE SECTION.
       01  LS-CMD-ACTION          PIC X(30).
       01  LS-PARAM1              PIC X(100).
       01  LS-PARAM2              PIC X(100).
       01  LS-PARAM3              PIC X(100).
       01  LS-PARAM4              PIC X(100).
       01  LS-PARAM5              PIC X(100).
       01  LS-PARAM6              PIC X(100).
       01  LS-OUTPUT-BUFFER      PIC X(16384).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.
        
        COPY "common_sql.cpy".
        COPY "wallet_entry.cpy".
        COPY "wallet_audit.cpy".
        COPY "wallet_caps.cpy".

        MAIN-LOGIC.
            *> Initialize critical WORKING-STORAGE (for --serve mode):
            MOVE "OK  " TO WS-TRANSFER-STATE
            SET WS-TRANSFER-OK TO TRUE
            MOVE "Y" TO WS-CAP-OK
            MOVE "0" TO WS-BUSY
            MOVE 0 TO WS-PREC-NUM
            MOVE 0 TO WS-ALLOWED
            MOVE "1" TO WS-STEP
            SET STEP-OK TO TRUE
            MOVE "0" TO WS-FX-HAS
            MOVE 0 TO WS-BAD
            MOVE 0 TO WS-P1-LEN
            MOVE 0 TO WS-P2-LEN
            MOVE 0 TO WS-P3-LEN
            MOVE 0 TO WS-P4-LEN
            MOVE 0 TO WS-P5-LEN
            MOVE 0 TO WS-P6-LEN
            MOVE 0 TO WS-CAP-LEN
            MOVE 0 TO WS-AMT-DOTS
            MOVE 0 TO WS-AMT-DIGITS
            MOVE 0 TO WS-AMT-FRAC
            MOVE "0" TO WS-AMT-SEEN-DOT
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            PERFORM TRIM-ALL
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:9) = "RECONCILE"
                    PERFORM RECONCILE-LOGIC
                WHEN LS-CMD-ACTION(1:18) = "RUN_RECONCILIATION"
                    PERFORM RUN-RECONCILIATION-LOGIC
                WHEN LS-CMD-ACTION(1:20) = "LIST_RECONCILIATIONS"
                    PERFORM LIST-RECONCILIATIONS-LOGIC
                WHEN LS-CMD-ACTION(1:15) = "LIST_EXCEPTIONS"
                    PERFORM LIST-EXCEPTIONS-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "ACK_EXCEPTION"
                    PERFORM ACK-EXCEPTION-LOGIC
                WHEN LS-CMD-ACTION(1:17) = "RESOLVE_EXCEPTION"
                    PERFORM RESOLVE-EXCEPTION-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        ALLOW-PERMISSION.
            *> WS-PERM-REQ names the permission WS-PERM-ACTOR must hold. A
            *> refused attempt is audited; the caller then reports FORBIDDEN.
            MOVE 0 TO WS-ALLOWED
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM role_permissions rp JOIN users u ON u.role = rp.role WHERE u.email = ? AND BINARY rp.permission = ?" TO WS-PREP-SQL
            MOVE WS-PERM-ACTOR TO WS-BIND-1
            MOVE WS-PERM-REQ TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "0"
                MOVE 1 TO WS-ALLOWED
            END-IF
            IF WS-ALLOWED NOT = 1
                MOVE WS-PERM-ACTOR TO WS-DENIED-ACTOR
                MOVE WS-PERM-ACTOR TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        RECONCILE-LOGIC.
            *> The actor (p1) must hold RECONCILE_READ.
            MOVE "RECONCILE_READ" TO WS-PERM-REQ
            MOVE WS-PARAM1-TRIMMED TO WS-PERM-ACTOR
            PERFORM ALLOW-PERMISSION
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF

            *> Any account whose stored balance differs from its ledger sum.
            *> Display rounds to each currency's own precision.
            MOVE "SELECT CAST(a.account_id AS CHAR), CONCAT(REPLACE(FORMAT(a.balance,c.prec_val), ',', '')), CONCAT(REPLACE(FORMAT(COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0),c.prec_val), ',', '')) FROM accounts a LEFT JOIN ledger l ON l.account_id = a.account_id JOIN currencies c ON c.currency_id = a.currency_id GROUP BY a.account_id, a.balance, c.prec_val HAVING a.balance <> COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0)" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|RECONCILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "ERROR|MISMATCH|" WS-RESULT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        RUN-RECONCILIATION-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = trigger (MANUAL/SCHEDULED).
            *> Computes the balance-vs-ledger outcome first, then inserts one
            *> immutable run row plus one OPEN finding per mismatch. A crash
            *> before COMMIT leaves no partial run behind.
            MOVE "MANUAL" TO WS-RUN-TRIGGER
            IF WS-P2-LEN > 0
                MOVE WS-PARAM2-TRIMMED(1:10) TO WS-RUN-TRIGGER
            END-IF.
            IF WS-RUN-TRIGGER NOT = "MANUAL" AND WS-RUN-TRIGGER NOT = "SCHEDULED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            *> The actor (p1) must hold RECONCILE_RUN.
            MOVE "RECONCILE_RUN" TO WS-PERM-REQ
            MOVE WS-PARAM1-TRIMMED TO WS-PERM-ACTOR
            PERFORM ALLOW-PERMISSION
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM (SELECT a.account_id FROM accounts a LEFT JOIN ledger l ON l.account_id = a.account_id GROUP BY a.account_id, a.balance HAVING a.balance <> COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0)) t" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:10) TO WS-RUN-COUNT
            IF WS-RUN-COUNT = "0"
                MOVE "INSERT INTO reconciliation_runs (trigger_src, actor_email, status, mismatch_count) VALUES (?, ?, 'CLEAN', 0)" TO WS-PREP-SQL
            ELSE
                MOVE "INSERT INTO reconciliation_runs (trigger_src, actor_email, status, mismatch_count) VALUES (?, ?, 'MISMATCH', ?)" TO WS-PREP-SQL
            END-IF.
            MOVE WS-RUN-TRIGGER TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            MOVE WS-RUN-COUNT TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LAST-INSERT-ID
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-RUN-ID
            IF WS-RUN-COUNT NOT = "0"
                MOVE "INSERT INTO reconciliation_findings (run_id, account_id, balance, ledger_sum) SELECT ?, a.account_id, a.balance, COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0) FROM accounts a LEFT JOIN ledger l ON l.account_id = a.account_id GROUP BY a.account_id, a.balance HAVING a.balance <> COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0)" TO WS-PREP-SQL
                MOVE WS-RUN-ID TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    CALL "SQL_ROLLBACK" END-CALL
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|RUN_RECORDED|" WS-RUN-ID DELIMITED BY SPACE
                   "|" DELIMITED BY SIZE WS-RUN-COUNT DELIMITED BY SPACE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        TRIM-RUN-RESULT-LEN.
            *> Compute WS-RLEN = length of WS-RESULT without trailing spaces.
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-J FROM 16383 BY -1 UNTIL WS-J < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-J:1) NOT = SPACE
                    MOVE WS-J TO WS-RLEN
                END-IF
            END-PERFORM
            IF WS-RLEN = 0
                MOVE 1 TO WS-RLEN
            END-IF.
            EXIT PARAGRAPH.

        LIST-RECONCILIATIONS-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = limit, p3 = offset. Read-only
            *> view of recorded runs, newest first.
            *> The actor (p1) must hold RECONCILE_READ.
            MOVE "RECONCILE_READ" TO WS-PERM-REQ
            MOVE WS-PARAM1-TRIMMED TO WS-PERM-ACTOR
            PERFORM ALLOW-PERMISSION
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "50" TO WS-RLIMIT
            MOVE "0" TO WS-ROFFSET
            IF WS-P2-LEN > 0
                MOVE WS-PARAM2-TRIMMED(1:10) TO WS-RLIMIT
            END-IF.
            IF WS-P3-LEN > 0
                MOVE WS-PARAM3-TRIMMED(1:10) TO WS-ROFFSET
            END-IF.
            MOVE WS-RLIMIT TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-ROFFSET TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM reconciliation_runs" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-RTOTAL
            MOVE "SELECT CONCAT(run_id, ':', trigger_src, ':', actor_email, ':', status, ':', mismatch_count, ':', DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s')) FROM reconciliation_runs ORDER BY run_id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-RLIMIT TO WS-BIND-1
            MOVE WS-ROFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|RUNS|" WS-RTOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RUN-RESULT-LEN
                STRING "SUCCESS|RUNS|" WS-RTOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        LIST-EXCEPTIONS-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = status filter, p3 = limit,
            *> p4 = offset. Read-only view of exception findings.
            *> The actor (p1) must hold RECONCILE_READ.
            MOVE "RECONCILE_READ" TO WS-PERM-REQ
            MOVE WS-PARAM1-TRIMMED TO WS-PERM-ACTOR
            PERFORM ALLOW-PERMISSION
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-LEN > 0 AND WS-PARAM2-TRIMMED NOT = "OPEN" AND WS-PARAM2-TRIMMED NOT = "ACKNOWLEDGED" AND WS-PARAM2-TRIMMED NOT = "RESOLVED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "50" TO WS-RLIMIT
            MOVE "0" TO WS-ROFFSET
            IF WS-P3-LEN > 0
                MOVE WS-PARAM3-TRIMMED(1:10) TO WS-RLIMIT
            END-IF.
            IF WS-P4-LEN > 0
                MOVE WS-PARAM4-TRIMMED(1:10) TO WS-ROFFSET
            END-IF.
            MOVE WS-RLIMIT TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-ROFFSET TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM reconciliation_findings WHERE status = COALESCE(NULLIF(?, ''), status)" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-RTOTAL
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CONCAT(finding_id, ':', run_id, ':', account_id, ':', balance, ':', ledger_sum, ':', status, ':', COALESCE(owner_email, ''), ':', REPLACE(REPLACE(COALESCE(resolution_note, ''), '|', '/'), ';', ','), ':', DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s')) FROM reconciliation_findings WHERE status = COALESCE(NULLIF(?, ''), status) ORDER BY finding_id DESC LIMIT ? OFFSET ?"
                   DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-RLIMIT TO WS-BIND-2
            MOVE WS-ROFFSET TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|EXCEPTIONS|" WS-RTOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RUN-RESULT-LEN
                STRING "SUCCESS|EXCEPTIONS|" WS-RTOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACK-EXCEPTION-LOGIC.
            *> p1 = finding_id, p2 = actor (SUPER_ADMIN). Claims ownership:
            *> OPEN becomes ACKNOWLEDGED with the actor as owner.
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM1-TRIMMED(1:20) TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "SELECT finding_id FROM reconciliation_findings WHERE finding_id = ? FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM reconciliation_findings WHERE finding_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "OPEN"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE reconciliation_findings SET status = 'ACKNOWLEDGED', owner_email = ? WHERE finding_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT a.id, a.id, 'RECONCILE_ACK', 'ACCOUNT', ?, 'SUCCESS' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|EXCEPTION_ACKNOWLEDGED" TO LS-OUTPUT-BUFFER
            EXIT PARAGRAPH.

        RESOLVE-EXCEPTION-LOGIC.
            *> p1 = finding_id, p2 = actor (SUPER_ADMIN), p3 = note (opt).
            *> Closes an ACKNOWLEDGED finding; the run link is kept.
            SET WS-TRANSFER-OK TO TRUE
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM1-TRIMMED(1:20) TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-LEN > 0
                PERFORM VALIDATE-RESOLVE-NOTE
            END-IF.
            IF WS-TRANSFER-FAIL-AMOUNT
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "SELECT finding_id FROM reconciliation_findings WHERE finding_id = ? FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM reconciliation_findings WHERE finding_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "ACKNOWLEDGED"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-LEN = 0
                MOVE "UPDATE reconciliation_findings SET status = 'RESOLVED', resolution_note = NULL, resolved_at = NOW() WHERE finding_id = ?" TO WS-PREP-SQL
            ELSE
                MOVE "UPDATE reconciliation_findings SET status = 'RESOLVED', resolution_note = ?, resolved_at = NOW() WHERE finding_id = ?" TO WS-PREP-SQL
            END-IF.
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            IF WS-P3-LEN = 0
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            ELSE
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            END-IF.
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'RECONCILE_RESOLVE', 'ACCOUNT', ?, ?, 'SUCCESS' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            MOVE "SUCCESS|EXCEPTION_RESOLVED" TO LS-OUTPUT-BUFFER
            EXIT PARAGRAPH.

        VALIDATE-RESOLVE-NOTE.
            *> Notes use the safe alphabet (letters, digits, space, -/_/.).
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-P3-LEN
                EVALUATE TRUE
                    WHEN WS-PARAM3-TRIMMED(WS-I:1) >= "a" AND WS-PARAM3-TRIMMED(WS-I:1) <= "z"
                        CONTINUE
                    WHEN WS-PARAM3-TRIMMED(WS-I:1) >= "A" AND WS-PARAM3-TRIMMED(WS-I:1) <= "Z"
                        CONTINUE
                    WHEN WS-PARAM3-TRIMMED(WS-I:1) >= "0" AND WS-PARAM3-TRIMMED(WS-I:1) <= "9"
                        CONTINUE
                    WHEN WS-PARAM3-TRIMMED(WS-I:1) = " " OR WS-PARAM3-TRIMMED(WS-I:1) = "-" OR WS-PARAM3-TRIMMED(WS-I:1) = "_" OR WS-PARAM3-TRIMMED(WS-I:1) = "."
                        CONTINUE
                    WHEN OTHER
                        SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                END-EVALUATE
            END-PERFORM.
            EXIT PARAGRAPH.
