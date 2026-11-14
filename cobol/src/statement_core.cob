       IDENTIFICATION DIVISION.
       PROGRAM-ID. statement_core.
      *> Statement archive and delivery (Sprint 1 slice 5).

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
       01  WS-RUN-ID               PIC X(20) VALUE SPACES.
       01  WS-RUN-STATUS           PIC X(20) VALUE SPACES.
       01  WS-RUN-FROM             PIC X(10) VALUE SPACES.
       01  WS-RUN-TO               PIC X(10) VALUE SPACES.
       01  WS-RUN-CURRENCY         PIC X(3) VALUE SPACES.
       01  WS-RUN-ACCOUNTS         PIC X(20) VALUE SPACES.
       01  WS-RUN-GENERATED        PIC X(20) VALUE SPACES.
       01  WS-RUN-FAILED           PIC X(20) VALUE SPACES.
       01  WS-RUN-ERROR            PIC X(40) VALUE SPACES.
       01  WS-ARCH-ID              PIC X(20) VALUE SPACES.
       01  WS-ARCH-EMAIL           PIC X(100) VALUE SPACES.
       01  WS-ARCH-CURRENCY        PIC X(3) VALUE SPACES.
       01  WS-ARCH-OPEN            PIC X(30) VALUE SPACES.
       01  WS-ARCH-CLOSE           PIC X(30) VALUE SPACES.
       01  WS-ARCH-DEBIT           PIC X(30) VALUE SPACES.
       01  WS-ARCH-CREDIT          PIC X(30) VALUE SPACES.
       01  WS-ARCH-ROWS            PIC X(20) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-RUN            PIC X(20) VALUE SPACES.
       01  WS-AUDIT-ACCOUNT        PIC X(100) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-PART                 PIC X(16384) VALUE SPACES.
       01  WS-PART-LEN             PIC 9(5) VALUE 0.
       01  WS-OUT-POS              PIC 9(5) VALUE 1.
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
               WHEN LS-CMD-ACTION(1:14) = "STMT_RUN_START"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-START
               WHEN LS-CMD-ACTION(1:17) = "STMT_RUN_GENERATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-GENERATE
               WHEN LS-CMD-ACTION(1:15) = "STMT_RUN_STATUS"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-STATUS
               WHEN LS-CMD-ACTION(1:13) = "STMT_RUN_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-LIST
               WHEN LS-CMD-ACTION(1:16) = "STMT_ARCHIVE_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ARCHIVE-GET
               WHEN LS-CMD-ACTION(1:19) = "STMT_ARCHIVE_EXPORT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ARCHIVE-EXPORT
               WHEN LS-CMD-ACTION(1:13) = "STMT_RUN_FAIL"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-FAIL
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_validate_semi.cpy".
        COPY "common_sql.cpy".


        COPY "common_trim.cpy".


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

       AUDIT-STATEMENT.
           MOVE "INSERT INTO statement_audit (action, actor_email, run_id, account_email, detail) VALUES (?, ?, NULLIF(?, ''), NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-RUN TO WS-BIND-3
           MOVE WS-AUDIT-ACCOUNT TO WS-BIND-4
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
           MOVE SPACES TO WS-AUDIT-RUN WS-AUDIT-ACCOUNT
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT-STATEMENT.
           EXIT PARAGRAPH.

       CHECK-RUN.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-RUN-STATUS WS-RUN-FROM WS-RUN-TO
               WS-RUN-CURRENCY WS-RUN-ACCOUNTS WS-RUN-GENERATED
               WS-RUN-FAILED WS-RUN-ERROR
           MOVE "SELECT CONCAT(status, '|', period_start, '|', period_end, '|', currency_code, '|', account_count, '|', generated_count, '|', failed_count, '|', COALESCE(error_code, '')) FROM statement_run WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           UNSTRING WS-RESULT DELIMITED BY "|" INTO
               WS-RUN-STATUS WS-RUN-FROM WS-RUN-TO WS-RUN-CURRENCY
               WS-RUN-ACCOUNTS WS-RUN-GENERATED WS-RUN-FAILED WS-RUN-ERROR
           END-UNSTRING.
           EXIT PARAGRAPH.

        COPY "common_result.cpy".

       TRIM-PART.
           MOVE 0 TO WS-PART-LEN
           PERFORM VARYING WS-J FROM 16384 BY -1
               UNTIL WS-J < 1 OR WS-PART-LEN > 0
               IF WS-PART(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-PART-LEN
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.

       ACTION-RUN-START.
           MOVE "STATEMENT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED > WS-P2-TRIMMED
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-LEN NOT = 3 OR WS-P3-TRIMMED(1:3) IS NOT ALPHABETIC
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO statement_run (period_start, period_end, currency_code, status, created_by) VALUES (?, ?, ?, 'RUNNING', ?)" TO WS-PREP-SQL
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
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-RUN-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "RUN_START" TO WS-AUDIT-ACTION
               MOVE WS-RUN-ID TO WS-AUDIT-RUN
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-STATEMENT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|STMT_RUN_STARTED|" DELIMITED BY SIZE
                      WS-RUN-ID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-GENERATE.
           MOVE "STATEMENT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-RUN
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RUN-STATUS NOT = "RUNNING"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO statement_archive (run_id, account_email, currency_code, opening_balance, closing_balance, total_debit, total_credit, row_count) SELECT ?, u.email, c.iso_code, 0, 0, 0, 0, 0 FROM users u JOIN accounts a ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE c.iso_code = ? AND EXISTS (SELECT 1 FROM ledger l WHERE l.account_id = a.account_id AND l.created_at >= ? AND l.created_at < DATE_ADD(?, INTERVAL 1 DAY))" TO WS-PREP-SQL
           MOVE WS-RUN-ID TO WS-BIND-1
           MOVE WS-RUN-CURRENCY TO WS-BIND-2
           MOVE WS-RUN-FROM TO WS-BIND-3
           MOVE WS-RUN-TO TO WS-BIND-4
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
               MOVE "UPDATE statement_archive sa SET opening_balance = (SELECT COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END), 0) FROM ledger l JOIN accounts a ON a.account_id = l.account_id JOIN users u ON u.id = a.user_id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = sa.account_email AND c.iso_code = sa.currency_code AND l.created_at < ?) WHERE sa.run_id = ?" TO WS-PREP-SQL
               MOVE WS-RUN-FROM TO WS-BIND-1
               MOVE WS-RUN-ID TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
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
               MOVE "UPDATE statement_archive sa SET total_debit = (SELECT COALESCE(SUM(CASE WHEN l.type = 'DEBIT' THEN l.amount ELSE 0 END), 0) FROM ledger l JOIN accounts a ON a.account_id = l.account_id JOIN users u ON u.id = a.user_id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = sa.account_email AND c.iso_code = sa.currency_code AND l.created_at >= ? AND l.created_at < DATE_ADD(?, INTERVAL 1 DAY)) WHERE sa.run_id = ?" TO WS-PREP-SQL
               MOVE WS-RUN-FROM TO WS-BIND-1
               MOVE WS-RUN-TO TO WS-BIND-2
               MOVE WS-RUN-ID TO WS-BIND-3
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
               MOVE "UPDATE statement_archive sa SET total_credit = (SELECT COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE 0 END), 0) FROM ledger l JOIN accounts a ON a.account_id = l.account_id JOIN users u ON u.id = a.user_id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = sa.account_email AND c.iso_code = sa.currency_code AND l.created_at >= ? AND l.created_at < DATE_ADD(?, INTERVAL 1 DAY)) WHERE sa.run_id = ?" TO WS-PREP-SQL
               MOVE WS-RUN-FROM TO WS-BIND-1
               MOVE WS-RUN-TO TO WS-BIND-2
               MOVE WS-RUN-ID TO WS-BIND-3
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
               MOVE "UPDATE statement_archive sa SET row_count = (SELECT COUNT(*) FROM ledger l JOIN accounts a ON a.account_id = l.account_id JOIN users u ON u.id = a.user_id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = sa.account_email AND c.iso_code = sa.currency_code AND l.created_at >= ? AND l.created_at < DATE_ADD(?, INTERVAL 1 DAY)) WHERE sa.run_id = ?" TO WS-PREP-SQL
               MOVE WS-RUN-FROM TO WS-BIND-1
               MOVE WS-RUN-TO TO WS-BIND-2
               MOVE WS-RUN-ID TO WS-BIND-3
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
               MOVE "UPDATE statement_archive SET closing_balance = opening_balance + total_credit - total_debit WHERE run_id = ?" TO WS-PREP-SQL
               MOVE WS-RUN-ID TO WS-BIND-1
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
               MOVE SPACES TO WS-PREP-SQL
               STRING "INSERT INTO statement_archive_line (archive_id, line_no, posting_date, txn_ref, source, " DELIMITED BY SIZE
                      "debit_amount, credit_amount, balance_after, description) " DELIMITED BY SIZE
                      "SELECT sa.id, ROW_NUMBER() OVER (PARTITION BY sa.id ORDER BY l.created_at, l.ledger_id), " DELIMITED BY SIZE
                      "DATE(l.created_at), l.txn_ref, COALESCE(j.source, 'TRANSFER'), " DELIMITED BY SIZE
                      "CASE WHEN l.type = 'DEBIT' THEN l.amount ELSE 0 END, " DELIMITED BY SIZE
                      "CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE 0 END, " DELIMITED BY SIZE
                      "sa.opening_balance + SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END) " DELIMITED BY SIZE
                      "OVER (PARTITION BY sa.id ORDER BY l.created_at, l.ledger_id), " DELIMITED BY SIZE
                      "COALESCE(l.description, '') FROM statement_archive sa " DELIMITED BY SIZE
                      "JOIN users u ON u.email = sa.account_email " DELIMITED BY SIZE
                      "JOIN accounts a ON a.user_id = u.id " DELIMITED BY SIZE
                      "JOIN currencies c ON c.currency_id = a.currency_id AND c.iso_code = sa.currency_code " DELIMITED BY SIZE
                      "JOIN ledger l ON l.account_id = a.account_id " DELIMITED BY SIZE
                      "LEFT JOIN journal_entries j ON j.journal_id = l.journal_id " DELIMITED BY SIZE
                      "WHERE sa.run_id = ? AND l.created_at >= ? " DELIMITED BY SIZE
                      "AND l.created_at < DATE_ADD(?, INTERVAL 1 DAY)" DELIMITED BY SIZE
                      INTO WS-PREP-SQL
               END-STRING
               MOVE WS-RUN-ID TO WS-BIND-1
               MOVE WS-RUN-FROM TO WS-BIND-2
               MOVE WS-RUN-TO TO WS-BIND-3
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
               MOVE "UPDATE statement_run SET status = 'COMPLETED', account_count = (SELECT COUNT(*) FROM statement_archive WHERE run_id = ?), generated_count = (SELECT COUNT(*) FROM statement_archive WHERE run_id = ?), finished_at = NOW(), version = version + 1 WHERE id = ? AND status = 'RUNNING'" TO WS-PREP-SQL
               MOVE WS-RUN-ID TO WS-BIND-1
               MOVE WS-RUN-ID TO WS-BIND-2
               MOVE WS-RUN-ID TO WS-BIND-3
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
               MOVE "RUN_GENERATE" TO WS-AUDIT-ACTION
               MOVE WS-RUN-ID TO WS-AUDIT-RUN
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-RUN-CURRENCY TO WS-AUDIT-DETAIL
               PERFORM AUDIT-STATEMENT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|STMT_RUN_COMPLETED|" DELIMITED BY SIZE
                      WS-RUN-ID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-STATUS.
           MOVE "STATEMENT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM2 = SPACES
               MOVE "0" TO WS-P2-TRIMMED
           END-IF.
           IF WS-P2-TRIMMED NOT = "0" AND WS-P2-TRIMMED NOT = "1"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-RUN
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           MOVE 1 TO WS-OUT-POS
           STRING "SUCCESS|STMT_RUN|" DELIMITED BY SIZE
                  WS-P1-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-FROM DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-TO DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-CURRENCY DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-STATUS DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-ACCOUNTS DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-GENERATED DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-FAILED DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-ERROR DELIMITED BY SPACE
                  INTO LS-OUTPUT-BUFFER WITH POINTER WS-OUT-POS
           END-STRING
           IF WS-P2-TRIMMED = "1"
               MOVE "SELECT CONCAT(account_email, ':', currency_code, ':', opening_balance, ':', closing_balance, ':', total_debit, ':', total_credit, ':', row_count) FROM statement_archive WHERE run_id = ? ORDER BY account_email" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE SPACES TO WS-PART
               MOVE 0 TO WS-PART-LEN
               IF WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE WS-RESULT TO WS-PART
                   PERFORM TRIM-PART
               END-IF
               STRING "|" DELIMITED BY SIZE
                      WS-PART(1:WS-PART-LEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER WITH POINTER WS-OUT-POS
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-LIST.
           MOVE "STATEMENT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
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
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM statement_run WHERE (? = '' OR status = ?) AND (? = '' OR currency_code = ?)" TO WS-PREP-SQL
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
           MOVE "SELECT CONCAT(id, ':', period_start, ':', period_end, ':', currency_code, ':', status, ':', account_count, ':', generated_count, ':', failed_count) FROM statement_run WHERE (? = '' OR status = ?) AND (? = '' OR currency_code = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
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
               STRING "SUCCESS|STMT_RUNS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|STMT_RUNS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-ARCHIVE-GET.
           MOVE "STATEMENT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM3 = SPACES
               MOVE "0" TO WS-P3-TRIMMED
           END-IF.
           MOVE "SELECT CONCAT(id, '|', account_email, '|', currency_code, '|', opening_balance, '|', closing_balance, '|', total_debit, '|', total_credit, '|', row_count) FROM statement_archive WHERE run_id = ? AND account_email = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
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
           UNSTRING WS-RESULT DELIMITED BY "|" INTO
               WS-ARCH-ID WS-ARCH-EMAIL WS-ARCH-CURRENCY
               WS-ARCH-OPEN WS-ARCH-CLOSE WS-ARCH-DEBIT WS-ARCH-CREDIT WS-ARCH-ROWS
           END-UNSTRING
           MOVE SPACES TO LS-OUTPUT-BUFFER
           MOVE 1 TO WS-OUT-POS
           STRING "SUCCESS|STMT_ARCHIVE|" DELIMITED BY SIZE
                  WS-ARCH-ID DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-ARCH-EMAIL DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-ARCH-CURRENCY DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-ARCH-OPEN DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-ARCH-CLOSE DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-ARCH-DEBIT DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-ARCH-CREDIT DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-ARCH-ROWS DELIMITED BY SPACE
                  INTO LS-OUTPUT-BUFFER WITH POINTER WS-OUT-POS
           END-STRING
           IF WS-P3-TRIMMED = "1"
               MOVE "SELECT CONCAT(line_no, ':', posting_date, ':', txn_ref, ':', source, ':', debit_amount, ':', credit_amount, ':', balance_after, ':', COALESCE(description, '')) FROM statement_archive_line WHERE archive_id = ? ORDER BY line_no" TO WS-PREP-SQL
               MOVE WS-ARCH-ID TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE SPACES TO WS-PART
               MOVE 0 TO WS-PART-LEN
               IF WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE WS-RESULT TO WS-PART
                   PERFORM TRIM-PART
               END-IF
               STRING "|" DELIMITED BY SIZE
                      WS-PART(1:WS-PART-LEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER WITH POINTER WS-OUT-POS
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-ARCHIVE-EXPORT.
           MOVE "STATEMENT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED NOT = "CSV" AND WS-P3-TRIMMED NOT = "FIXED"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(id, '|', row_count) FROM statement_archive WHERE run_id = ? AND account_email = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
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
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-ARCH-ID WS-ARCH-ROWS
           END-UNSTRING
           MOVE "SELECT CONCAT(line_no, ':', posting_date, ':', txn_ref, ':', source, ':', debit_amount, ':', credit_amount, ':', balance_after) FROM statement_archive_line WHERE archive_id = ? ORDER BY line_no" TO WS-PREP-SQL
           MOVE WS-ARCH-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-PART
           MOVE 0 TO WS-PART-LEN
           IF WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE WS-RESULT TO WS-PART
               PERFORM TRIM-PART
           END-IF
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|STMT_EXPORT|" DELIMITED BY SIZE
                  WS-P3-TRIMMED DELIMITED BY SPACE "|" DELIMITED BY SIZE
                  WS-PART(1:WS-PART-LEN) DELIMITED BY SIZE
                  INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.

       ACTION-RUN-FAIL.
           MOVE "STATEMENT_CORE" TO WS-DENIED-TARGET
           PERFORM ADMIN-GUARD
           IF WS-ALLOWED NOT = 1
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-RUN
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RUN-STATUS NOT = "RUNNING"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE statement_run SET status = 'FAILED', error_code = ?, error_detail = ?, finished_at = NOW(), version = version + 1 WHERE id = ? AND status = 'RUNNING'" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P1-TRIMMED TO WS-BIND-3
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
               MOVE "RUN_FAIL" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RUN
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-STATEMENT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|STMT_RUN_FAILED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.
