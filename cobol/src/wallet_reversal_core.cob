        IDENTIFICATION DIVISION.
        PROGRAM-ID. wallet_reversal_core.

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
        COPY "wallet_ws_common.cpy".
        01  WS-BALANCE-NUM         PIC S9(16)V9999 COMP-3.
        01  WS-PARSE-SRC           PIC X(100) VALUE SPACES.
        01  WS-PARSE-BUF           PIC X(100) VALUE SPACES.
        01  WS-PARSE-NUM           PIC S9(16)V9999 COMP-3.
        01  WS-CAP-OK              PIC X(1) VALUE "Y".
        01  WS-CAP-LEN             PIC 9(3) VALUE 0.
        01  WS-PREC-NUM            PIC S9(4) VALUE 0.
        01  WS-JV-PREC             PIC X(2)  VALUE SPACES.
        01  WS-INCOME-ACC          PIC X(20) VALUE SPACES.
        01  WS-REV-AMT             PIC X(30) VALUE SPACES.
        01  WS-REV-CAMT            PIC X(30) VALUE SPACES.
        01  WS-REV-FROM            PIC X(100) VALUE SPACES.
        01  WS-REV-CNT             PIC X(10) VALUE SPACES.
        01  WS-REV-MINFROM         PIC X(100) VALUE SPACES.
        01  WS-REV-CAMT-NUM        PIC S9(16)V9999 COMP-3.
        01  WS-REV-REASON          PIC X(100) VALUE SPACES.
        01  WS-REV-REFUND          PIC X(1)  VALUE "0".
        01  WS-REV-FEE-ACC         PIC X(20) VALUE SPACES.
        01  WS-REV-FEE-AMT         PIC X(30) VALUE SPACES.
        01  WS-REV-FEE-CUR         PIC X(20) VALUE SPACES.
        01  WS-REV-FEE-ISO         PIC X(3)  VALUE SPACES.
        01  WS-REV-FEE-PREC        PIC X(2)  VALUE SPACES.
        01  WS-REV-FEE-NUM         PIC S9(16)V9999 COMP-3.
        01  WS-REV-FX-ACC          PIC X(20) VALUE SPACES.
        01  WS-REV-FX-AMT          PIC X(30) VALUE SPACES.
        01  WS-REV-FX-DESC         PIC X(16) VALUE SPACES.
        01  WS-REV-FX-NUM          PIC S9(16)V9999 COMP-3.
        01  WS-BUSY                PIC X(1) VALUE "0".
        01  WS-DETAIL              PIC X(255) VALUE SPACES.
        01  WS-SENDER-ACC          PIC X(20) VALUE SPACES.
        01  WS-SENDER-USER         PIC X(20) VALUE SPACES.
        01  WS-SENDER-BAL          PIC X(30) VALUE SPACES.
        01  WS-SENDER-CUR          PIC X(20) VALUE SPACES.
        01  WS-TARGET-ACC          PIC X(20) VALUE SPACES.
        01  WS-TARGET-CUR          PIC X(20) VALUE SPACES.
        01  WS-TARGET-PREC         PIC X(2)  VALUE SPACES.
        01  WS-RATE-STR            PIC X(40) VALUE SPACES.
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
                WHEN LS-CMD-ACTION(1:16) = "REVERSE_TRANSFER"
                    PERFORM REVERSE-TRANSFER-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        REVERSE-TRANSFER-LOGIC.
            *> p1 = original txn_ref, p2 = actor (SUPER_ADMIN). Compensating,
            *> one-time reversal: credit the original sender, debit the target.
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Reversal reason selects the fee-refund policy (D2); a missing
            *> reason is rejected before any state is read or written.
            MOVE SPACES TO WS-REV-REASON
            MOVE "0" TO WS-REV-REFUND
            MOVE SPACES TO WS-REV-FEE-ACC
            MOVE SPACES TO WS-REV-FEE-AMT
            MOVE SPACES TO WS-REV-FEE-CUR
            MOVE SPACES TO WS-REV-FX-ACC
            MOVE SPACES TO WS-REV-FX-AMT
            MOVE SPACES TO WS-REV-FX-DESC
            IF WS-P4-LEN = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE WS-PARAM4-TRIMMED(1:WS-P4-LEN) TO WS-REV-REASON
            *> Resolve the transfer's sender. txn_ref is unique per sender, so a
            *> shared reference is refused unless the sender is given (p3).
            MOVE SPACES TO WS-REV-FROM
            IF WS-P3-LEN > 0
                MOVE WS-PARAM3-TRIMMED(1:WS-P3-LEN) TO WS-REV-FROM
            END-IF
            IF WS-REV-FROM = SPACES
                MOVE "SELECT CAST(COUNT(DISTINCT from_email) AS CHAR), MIN(from_email) FROM ledger WHERE txn_ref = ? AND type = 'DEBIT' AND from_email IS NOT NULL" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    IF WS-RESULT = "ERROR|NO_DATA"
                        MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                    ELSE
                        MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    END-IF
                    EXIT PARAGRAPH
                END-IF
                UNSTRING WS-RESULT DELIMITED BY "|"
                    INTO WS-REV-CNT WS-REV-MINFROM
                END-UNSTRING
                IF WS-REV-CNT(1:1) = "0"
                    MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                IF WS-REV-CNT NOT = "1"
                    MOVE "ERROR|AMBIGUOUS_TRANSACTION" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE WS-REV-MINFROM TO WS-REV-FROM
            END-IF
            *> Already reversed? One reversal per (ref, sender).
            MOVE "SELECT 1 FROM transfer_reversals WHERE orig_ref = ? AND from_email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                IF WS-RESULT = "ERROR|NO_DATA"
                    CONTINUE
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            ELSE
                MOVE "ERROR|ALREADY_REVERSED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> The original debit (sender side) and credit (target side), scoped
            *> to the sender so a shared reference cannot pick the wrong rows.
            MOVE "SELECT CAST(account_id AS CHAR), CAST(amount AS CHAR), CAST(currency_id AS CHAR) FROM ledger WHERE txn_ref = ? AND type = 'DEBIT' AND description = 'Transfer out' AND from_email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                IF WS-RESULT = "ERROR|NO_DATA"
                    MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-SENDER-ACC WS-REV-AMT WS-SENDER-CUR
            END-UNSTRING
            MOVE "SELECT CAST(account_id AS CHAR), CAST(amount AS CHAR), CAST(l.currency_id AS CHAR), CAST(exchange_rate AS CHAR), CAST(c.prec_val AS CHAR) FROM ledger l JOIN currencies c ON c.currency_id = l.currency_id WHERE txn_ref = ? AND type = 'CREDIT' AND description = 'Transfer in' AND from_email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                IF WS-RESULT = "ERROR|NO_DATA"
                    MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-TARGET-ACC WS-REV-CAMT WS-TARGET-CUR WS-RATE-STR
                     WS-TARGET-PREC
            END-UNSTRING
            *> The original residual leg, if the posting rounded. A gain was
            *> credited to FX_PNL, a loss debited from it; the reversal posts
            *> the mirror leg so the gain is clawed back or the loss returned.
            MOVE "SELECT CAST(account_id AS CHAR), CAST(amount AS CHAR), CAST(currency_id AS CHAR), description FROM ledger WHERE txn_ref = ? AND description IN ('FX gain', 'FX loss') AND from_email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO WS-REV-FX-DESC
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                UNSTRING WS-RESULT DELIMITED BY "|"
                    INTO WS-REV-FX-ACC WS-REV-FX-AMT WS-TARGET-CUR
                         WS-REV-FX-DESC
                END-UNSTRING
            END-IF
            *> Fee legs of the original transfer, if it carried a fee.
            MOVE "SELECT CAST(account_id AS CHAR), CAST(amount AS CHAR), CAST(currency_id AS CHAR) FROM ledger WHERE txn_ref = ? AND type = 'DEBIT' AND description = 'Fee out' AND from_email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO WS-REV-FEE-AMT
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                UNSTRING WS-RESULT DELIMITED BY "|"
                    INTO WS-REV-FEE-ACC WS-REV-FEE-AMT WS-REV-FEE-CUR
                END-UNSTRING
            END-IF
            *> Policy: the reason decides refund or retain; unknown reasons
            *> fail closed even when no fee is due.
            MOVE "SELECT CAST(refund_fee AS CHAR) FROM reversal_fee_policy WHERE reason = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-REV-REASON TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-REV-REFUND
            END-UNSTRING
            SET WS-TRANSFER-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            *> Lock both original accounts (ordered) before touching balances.
            PERFORM LOCK-ACCOUNTS
            IF WS-TRANSFER-FAIL-DB
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> The target must still hold the credited amount to claw it back.
            MOVE "SELECT CONCAT(balance) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
            MOVE WS-TARGET-ACC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:30) TO WS-SENDER-BAL
            MOVE WS-SENDER-BAL TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-BALANCE-NUM
            MOVE WS-REV-CAMT TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-REV-CAMT-NUM
            IF WS-BALANCE-NUM < WS-REV-CAMT-NUM
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> A gain clawback needs the FX account to still hold it.
            IF WS-REV-FX-DESC = "FX gain"
                MOVE "SELECT CONCAT(balance) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-REV-FX-ACC TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                    BY REFERENCE WS-BIND-5
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                UNSTRING WS-RESULT DELIMITED BY "|"
                    INTO WS-SENDER-BAL
                END-UNSTRING
                MOVE WS-SENDER-BAL TO WS-PARSE-SRC
                PERFORM PARSE-MAJOR
                MOVE WS-PARSE-NUM TO WS-BALANCE-NUM
                MOVE WS-REV-FX-AMT TO WS-PARSE-SRC
                PERFORM PARSE-MAJOR
                MOVE WS-PARSE-NUM TO WS-REV-FX-NUM
                IF WS-BALANCE-NUM < WS-REV-FX-NUM
                    CALL "SQL_ROLLBACK" END-CALL
                    MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF
            SET STEP-OK TO TRUE
            *> Open the journal header for this reversal; legs and the audit
            *> row below point at it through the connection-scoped @jid.
            IF STEP-OK
                MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'REVERSAL', ?)" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            *> One-time marker (PK on orig_ref): a duplicate means already reversed.
            MOVE "INSERT INTO transfer_reversals (orig_ref, from_email, actor_id, reason) SELECT ?, ?, id, ? FROM users WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            MOVE WS-REV-REASON TO WS-BIND-3
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-REV-AMT TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-REV-CAMT TO WS-BIND-1
                MOVE WS-TARGET-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, 'Reversal in', ?, @jid, ?)" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                MOVE WS-REV-AMT TO WS-BIND-3
                MOVE WS-SENDER-CUR TO WS-BIND-4
                MOVE WS-RATE-STR TO WS-BIND-5
                MOVE WS-REV-FROM TO WS-BIND-6
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, 'Reversal out', 1, @jid, ?)" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-TARGET-ACC TO WS-BIND-2
                MOVE WS-REV-CAMT TO WS-BIND-3
                MOVE WS-TARGET-CUR TO WS-BIND-4
                MOVE WS-REV-FROM TO WS-BIND-5
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            *> Mirror the original residual in this journal: claw back a
            *> gain with a DEBIT, return a loss with a CREDIT, so the full
            *> posting unwinds atomically and verifies balanced.
            IF STEP-OK AND WS-REV-FX-DESC = "FX gain"
                MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-REV-FX-AMT TO WS-BIND-1
                MOVE WS-REV-FX-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                    BY REFERENCE WS-BIND-5
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET STEP-FAIL TO TRUE
                END-IF
                IF STEP-OK
                    MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, 'FX reversal out', 1, @jid, ?)" TO WS-PREP-SQL
                    MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                    MOVE WS-REV-FX-ACC TO WS-BIND-2
                    MOVE WS-REV-FX-AMT TO WS-BIND-3
                    MOVE WS-TARGET-CUR TO WS-BIND-4
                    MOVE WS-REV-FROM TO WS-BIND-5
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
                    END-CALL
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                    IF WS-RESULT(1:5) = "ERROR"
                        SET STEP-FAIL TO TRUE
                    END-IF
                END-IF
            END-IF
            IF STEP-OK AND WS-REV-FX-DESC = "FX loss"
                MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-REV-FX-AMT TO WS-BIND-1
                MOVE WS-REV-FX-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                    BY REFERENCE WS-BIND-5
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET STEP-FAIL TO TRUE
                END-IF
                IF STEP-OK
                    MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, 'FX reversal in', 1, @jid, ?)" TO WS-PREP-SQL
                    MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                    MOVE WS-REV-FX-ACC TO WS-BIND-2
                    MOVE WS-REV-FX-AMT TO WS-BIND-3
                    MOVE WS-TARGET-CUR TO WS-BIND-4
                    MOVE WS-REV-FROM TO WS-BIND-5
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
                    END-CALL
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                    IF WS-RESULT(1:5) = "ERROR"
                        SET STEP-FAIL TO TRUE
                    END-IF
                END-IF
            END-IF
            IF STEP-OK
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                PERFORM LOOKUP-USER-ID
                MOVE WS-RESULT(1:256) TO WS-BIND-1
                MOVE WS-BIND-1 TO WS-BIND-2
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
                MOVE WS-REV-FROM TO WS-BIND-4
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status, journal_id) VALUES (?, ?, 'REVERSE_TRANSFER', 'LEDGER', ?, ?, 'SUCCESS', @jid)" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            *> Every leg is written against the open journal; verify the
            *> journal balances before anything becomes durable. The guard
            *> flag is shared with TRANSFER-LOGIC, so reset it first: in
            *> serve mode Working-Storage survives across requests.
            SET WS-TRANSFER-OK TO TRUE
            IF STEP-OK AND WS-REV-FX-DESC = SPACES
                MOVE WS-TARGET-PREC TO WS-JV-PREC
                PERFORM VERIFY-JOURNAL-BALANCED
            END-IF.
            IF STEP-OK AND WS-REV-FX-DESC NOT = SPACES
                PERFORM VERIFY-JOURNAL-REVERSAL-FX-BALANCED
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK AND WS-REV-REFUND = "1"
                AND WS-REV-FEE-AMT NOT = SPACES
                PERFORM POST-FEE-REFUND
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT NOT = "SUCCESS|COMMIT"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "SUCCESS|TRANSFER_REVERSED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|REVERSAL_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        PARSE-MAJOR.
            *> Canonical money parse into major units. The program compiles
            *> with DECIMAL-POINT IS COMMA, so NUMVAL reads a dot as a
            *> thousands separator ("100.01" would parse as 10001). Normalize
            *> the dot to a comma first; callers pass only validated
            *> digit/dot strings or exact decimals read back from the DB.
            MOVE WS-PARSE-SRC TO WS-PARSE-BUF
            INSPECT WS-PARSE-BUF REPLACING ALL "." BY ","
            COMPUTE WS-PARSE-NUM = FUNCTION NUMVAL(WS-PARSE-BUF) END-COMPUTE
            EXIT PARAGRAPH.

        VERIFY-JOURNAL-BALANCED.
            *> Pre-commit guard: the journal must hold exactly one DEBIT leg
            *> and one CREDIT leg whose amounts agree through the snapshotted
            *> rate — in either direction, so one paragraph serves transfers
            *> (credit = debit x rate) and reversals (debit = credit x rate).
            *> A violation rolls the whole posting back.
            MOVE "SELECT IF(COUNT(*)=2 AND SUM(type='DEBIT')=1 AND (MAX(CASE WHEN type='CREDIT' THEN amount END) = ROUND(MAX(CASE WHEN type='DEBIT' THEN amount END) * MAX(CASE WHEN type='CREDIT' THEN exchange_rate END), ?) OR MAX(CASE WHEN type='DEBIT' THEN amount END) = ROUND(MAX(CASE WHEN type='CREDIT' THEN amount END) * MAX(CASE WHEN type='CREDIT' THEN exchange_rate END), ?)),'BALANCED','UNBALANCED') FROM ledger WHERE journal_id = @jid" TO WS-PREP-SQL
            MOVE WS-JV-PREC TO WS-BIND-1
            MOVE WS-JV-PREC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "BALANCED"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        POST-FEE-REFUND.
            *> Compensating fee legs for a refund-by-reason reversal: DEBIT
            *> the fee-income account, CREDIT the original sender, verified
            *> as its own journal like any posting.
            MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'FEE_INCOME' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-REV-FEE-CUR TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-INCOME-ACC
            END-UNSTRING
            *> The income account must still hold the fee to return it.
            MOVE "SELECT CONCAT(balance) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
            MOVE WS-INCOME-ACC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-SENDER-BAL
            END-UNSTRING
            MOVE WS-SENDER-BAL TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-BALANCE-NUM
            MOVE WS-REV-FEE-AMT TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-REV-FEE-NUM
            IF WS-BALANCE-NUM < WS-REV-FEE-NUM
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'FEE', ?)" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ?" TO WS-PREP-SQL
            MOVE WS-REV-FEE-AMT TO WS-BIND-1
            MOVE WS-INCOME-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
            MOVE WS-REV-FEE-AMT TO WS-BIND-1
            MOVE WS-SENDER-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, 'Fee refund out', 1, @jid, ?)" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-INCOME-ACC TO WS-BIND-2
            MOVE WS-REV-FEE-AMT TO WS-BIND-3
            MOVE WS-REV-FEE-CUR TO WS-BIND-4
            MOVE WS-REV-FROM TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, 'Fee refund in', 1, @jid, ?)" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-SENDER-ACC TO WS-BIND-2
            MOVE WS-REV-FEE-AMT TO WS-BIND-3
            MOVE WS-REV-FEE-CUR TO WS-BIND-4
            MOVE WS-REV-FROM TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT CAST(prec_val AS CHAR), iso_code FROM currencies WHERE currency_id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-REV-FEE-CUR TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-REV-FEE-PREC WS-REV-FEE-ISO
            END-UNSTRING
            MOVE WS-REV-FEE-PREC TO WS-JV-PREC
            PERFORM VERIFY-JOURNAL-BALANCED
            IF WS-TRANSFER-FAIL-DB
                SET STEP-FAIL TO TRUE
                EXIT PARAGRAPH
            END-IF
            MOVE SPACES TO WS-DETAIL
            STRING WS-REV-FEE-AMT DELIMITED BY SPACE ":" DELIMITED BY SIZE
                   WS-REV-FEE-ISO DELIMITED BY SPACE
                   INTO WS-DETAIL
            END-STRING
            MOVE WS-REV-FROM TO WS-BIND-1
            PERFORM LOOKUP-USER-ID
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-SENDER-USER
            END-UNSTRING
            MOVE WS-SENDER-USER TO WS-BIND-1
            MOVE WS-SENDER-ACC TO WS-BIND-2
            MOVE WS-DETAIL TO WS-BIND-3
            MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status, detail, journal_id) VALUES (?, 'FEE', 'ACCOUNT', ?, 'SUCCESS', ?, @jid)" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        VERIFY-JOURNAL-REVERSAL-FX-BALANCED.
            *> Three-leg reversal journal unwinding an FX posting with a
            *> residual: the sender credit converted at the snapshotted
            *> rate equals the negated target-side net at 4dp ledger
            *> scale, exactly: E4 = ROUND(D x R, 4) = 0 - (signed legs).
            MOVE "SELECT IF(COUNT(*)=3 AND SUM(type='DEBIT')>=1 AND SUM(type='CREDIT')>=1 AND ROUND(MAX(CASE WHEN description = 'Reversal in' THEN amount END) * MAX(CASE WHEN description = 'Reversal in' THEN exchange_rate END), 4) = 0 - SUM(CASE WHEN currency_id = ? THEN CASE WHEN type = 'CREDIT' THEN amount ELSE 0 - amount END END), 'BALANCED','UNBALANCED') FROM ledger WHERE journal_id = @jid" TO WS-PREP-SQL
            MOVE WS-TARGET-CUR TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "BALANCED"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        LOCK-ACCOUNTS.
            *> Lock both account rows in ascending id order in a single read.
            *> Uses the no-fetch prepared variant: the rows are not read (which
            *> would raise MariaDB ER_CHECKREAD under contention).
            MOVE "SELECT account_id FROM accounts WHERE account_id IN (?, ?) ORDER BY account_id FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-SENDER-ACC TO WS-BIND-1
            MOVE WS-TARGET-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT hold_id FROM account_holds WHERE account_id IN (?, ?) AND state = 'PLACED' FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-SENDER-ACC TO WS-BIND-1
            MOVE WS-TARGET-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.
