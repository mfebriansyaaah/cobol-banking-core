        IDENTIFICATION DIVISION.
        PROGRAM-ID. wallet_core.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01  WS-EXIT-CODE            PIC 9(2) VALUE 0.
        01  WS-QUERY                PIC X(512) VALUE SPACES.
        01  WS-RESULT               PIC X(512) VALUE SPACES.
        01  WS-PARAM1-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM2-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM3-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM4-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-I                   PIC 9(3).
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-PREP-SQL             PIC X(256) VALUE SPACES.
        01  WS-BIND-1               PIC X(256) VALUE SPACES.
        01  WS-BIND-2               PIC X(256) VALUE SPACES.
        01  WS-BIND-3               PIC X(256) VALUE SPACES.
        01  WS-BIND-4               PIC X(256) VALUE SPACES.
        01  F-QUOTE                 PIC X VALUE "'".
        01  F-DQUOTE                PIC X VALUE '"'.
        01  F-BSLASH                PIC X VALUE "\".
        01  F-SEMI                  PIC X VALUE ";".
        01  F-TICK                  PIC X VALUE "`".
        01  WS-TRANSFER-STATE      PIC X(5) VALUE 'OK  '.
            88  WS-TRANSFER-OK       VALUE 'OK'.
            88  WS-TRANSFER-FAIL-SENDER VALUE 'SNDR'.
            88  WS-TRANSFER-FAIL-TARGET VALUE 'TGRT'.
            88  WS-TRANSFER-FAIL-INSUF VALUE 'INSUF'.
            88  WS-TRANSFER-FAIL-IDEMP VALUE 'IDEM'.
            88  WS-TRANSFER-FAIL-AMOUNT VALUE 'AMNT'.
            88  WS-TRANSFER-FAIL-CURR VALUE 'CURR'.
            88  WS-TRANSFER-FAIL-DB VALUE 'DBER'.
        01  WS-BALANCE-NUM         PIC S9(13)V99 COMP-3.
        01  WS-AMOUNT-NUM          PIC S9(13)V99 COMP-3.
        01  WS-NOW                 PIC X(21) VALUE SPACES.
        01  WS-TXN-REF             PIC X(17) VALUE SPACES.
        01  WS-REF                 PIC X(50) VALUE SPACES.
        01  WS-REFLEN              PIC 9(3) VALUE 1.
        01  WS-SENDER-ACC          PIC X(20) VALUE SPACES.
        01  WS-SENDER-USER         PIC X(20) VALUE SPACES.
        01  WS-SENDER-BAL          PIC X(30) VALUE SPACES.
        01  WS-SENDER-CUR          PIC X(20) VALUE SPACES.
        01  WS-TARGET-ACC          PIC X(20) VALUE SPACES.
        01  WS-TARGET-CUR          PIC X(20) VALUE SPACES.

        LINKAGE SECTION.
       01  LS-CMD-ACTION          PIC X(30).
       01  LS-PARAM1              PIC X(100).
       01  LS-PARAM2              PIC X(100).
       01  LS-PARAM3              PIC X(100).
       01  LS-PARAM4              PIC X(100).
       01  LS-OUTPUT-BUFFER      PIC X(500).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-OUTPUT-BUFFER.
        
        MAIN-LOGIC.
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:13) = "CHECK_BALANCE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM GET-BALANCE-LOGIC
                WHEN LS-CMD-ACTION(1:8) = "TRANSFER"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM TRANSFER-LOGIC
                WHEN LS-CMD-ACTION(1:9) = "RECONCILE"
                    PERFORM TRIM-PARAM1
                    PERFORM RECONCILE-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        VALIDATE-ALL.
            *> No SQL metacharacters may reach a query string.
            MOVE 0 TO WS-BAD
            MOVE LS-PARAM1 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM2 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM3 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM4 TO WS-CHECK
            PERFORM VALIDATE-INPUT.
            EXIT PARAGRAPH.

        VALIDATE-INPUT.
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-QUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-DQUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-BSLASH
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-SEMI
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-TICK.
            EXIT PARAGRAPH.

        TRIM-PARAM1.
            MOVE LS-PARAM1 TO WS-PARAM1-TRIMMED.
            MOVE 0 TO WS-P1-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P1-LEN > 0
                IF WS-PARAM1-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P1-LEN
                END-IF
            END-PERFORM.

        TRIM-PARAM2.
            MOVE LS-PARAM2 TO WS-PARAM2-TRIMMED.
            MOVE 0 TO WS-P2-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P2-LEN > 0
                IF WS-PARAM2-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P2-LEN
                END-IF
            END-PERFORM.

        TRIM-PARAM3.
            MOVE LS-PARAM3 TO WS-PARAM3-TRIMMED.
            MOVE 0 TO WS-P3-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P3-LEN > 0
                IF WS-PARAM3-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P3-LEN
                END-IF
            END-PERFORM.

        TRIM-PARAM4.
            MOVE LS-PARAM4 TO WS-PARAM4-TRIMMED.
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1
                IF WS-PARAM4-TRIMMED(WS-I:1) = SPACE
                    MOVE SPACE TO WS-PARAM4-TRIMMED(WS-I:1)
                END-IF
            END-PERFORM.
            MOVE 0 TO WS-P4-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P4-LEN > 0
                IF WS-PARAM4-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P4-LEN
                END-IF
            END-PERFORM.

        ALLOW-READ.
            *> Sets WS-ALLOWED when the actor (p2) owns the target (p1) or is an admin.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        GET-BALANCE-LOGIC.
            PERFORM ALLOW-READ
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(ROUND(a.balance, 2)) FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE WS-RESULT TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        RECONCILE-LOGIC.
            *> Only a SUPER_ADMIN (the actor, p1) may run the diagnostic.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF

            *> Any account whose stored balance differs from its ledger sum.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT CAST(a.account_id AS CHAR), CONCAT(ROUND(a.balance,2)), CONCAT(ROUND(COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0),2)) " 
                   "FROM accounts a LEFT JOIN ledger l ON l.account_id = a.account_id " 
                   "GROUP BY a.account_id, a.balance " 
                   "HAVING a.balance <> COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0)" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|RECONCILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "ERROR|MISMATCH|" WS-RESULT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        TRANSFER-LOGIC.
            SET WS-TRANSFER-OK TO TRUE
            *> The idempotency key (param 4) doubles as the transaction reference.
            IF LS-PARAM4 NOT = SPACES
                MOVE WS-PARAM4-TRIMMED(1:WS-P4-LEN) TO WS-REF
                MOVE WS-P4-LEN TO WS-REFLEN
            ELSE
                MOVE FUNCTION CURRENT-DATE TO WS-NOW
                MOVE SPACES TO WS-TXN-REF
                STRING "TXN" WS-NOW(1:14) DELIMITED BY SIZE INTO WS-TXN-REF
                END-STRING
                MOVE WS-TXN-REF TO WS-REF
                MOVE 17 TO WS-REFLEN
            END-IF
            
            CALL "SQL_BEGIN"
            
            *> Replay: a persisted reference means the transfer already committed.
            IF LS-PARAM4 NOT = SPACES
                MOVE "SELECT 1 FROM pending_transactions WHERE txn_ref = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT NOT = "ERROR|NO_DATA"
                    CALL "SQL_COMMIT"
                    MOVE "SUCCESS|TRANSFER_OK" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF

                *> Record the intent; a duplicate key means another attempt is running.
                MOVE "INSERT INTO pending_transactions (txn_ref, from_email, to_email, amount, status) VALUES (?, ?, ?, ?, 'PENDING')" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-4
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-IDEMP TO TRUE
                END-IF
            END-IF

            *> Resolve the sender account (no lock yet).
            MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.user_id AS CHAR), CAST(a.currency_id AS CHAR) FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                SET WS-TRANSFER-FAIL-SENDER TO TRUE
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                ELSE
                    UNSTRING WS-RESULT DELIMITED BY "|"
                        INTO WS-SENDER-ACC WS-SENDER-USER WS-SENDER-CUR
                    END-UNSTRING
                END-IF
            END-IF
            
            *> Resolve the target account (no lock yet).
            IF WS-TRANSFER-OK
                MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.currency_id AS CHAR) FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT = "ERROR|NO_DATA"
                    SET WS-TRANSFER-FAIL-TARGET TO TRUE
                ELSE
                    IF WS-RESULT(1:5) = "ERROR"
                        SET WS-TRANSFER-FAIL-DB TO TRUE
                    ELSE
                        UNSTRING WS-RESULT DELIMITED BY "|"
                            INTO WS-TARGET-ACC WS-TARGET-CUR
                        END-UNSTRING
                    END-IF
                END-IF
            END-IF
            
            *> Lock both account rows in one statement, ordered by id, so two
            *> opposing transfers cannot deadlock (and MariaDB does not hit the
            *> two-statement ER_CHECKREAD).
            IF WS-TRANSFER-OK
                PERFORM LOCK-ACCOUNTS
            END-IF
            
            *> Read the sender balance now that its row is locked.
            IF WS-TRANSFER-OK
                MOVE "SELECT CONCAT(ROUND(balance,2)) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-SENDER-ACC TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT = "ERROR|NO_DATA"
                    SET WS-TRANSFER-FAIL-SENDER TO TRUE
                ELSE
                    IF WS-RESULT(1:5) = "ERROR"
                        SET WS-TRANSFER-FAIL-DB TO TRUE
                    ELSE
                        MOVE WS-RESULT TO WS-SENDER-BAL
                    END-IF
                END-IF
            END-IF
            
            *> Provider only moves money within one currency (no FX here).
            IF WS-TRANSFER-OK
                IF WS-SENDER-CUR NOT = WS-TARGET-CUR
                    SET WS-TRANSFER-FAIL-CURR TO TRUE
                END-IF
            END-IF
            
            *> Amount must be positive, and the sender must be able to cover it.
            IF WS-TRANSFER-OK
                COMPUTE WS-AMOUNT-NUM = FUNCTION NUMVAL(WS-PARAM3-TRIMMED)
                IF WS-AMOUNT-NUM <= 0
                    SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                END-IF
            END-IF
            
            IF WS-TRANSFER-OK
                COMPUTE WS-BALANCE-NUM = FUNCTION NUMVAL(WS-SENDER-BAL)
                IF WS-BALANCE-NUM < WS-AMOUNT-NUM
                    SET WS-TRANSFER-FAIL-INSUF TO TRUE
                END-IF
            END-IF
            
            *> Debit sender.
            IF WS-TRANSFER-OK
                MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Credit target.
            IF WS-TRANSFER-OK
                MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
                MOVE WS-TARGET-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Immutable ledger entries: one DEBIT, one CREDIT, same txn_ref.
            IF WS-TRANSFER-OK
                MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description) VALUES (?, ?, ?, 'DEBIT', ?, 'Transfer out')" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-3
                MOVE WS-SENDER-CUR TO WS-BIND-4
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            IF WS-TRANSFER-OK
                MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description) VALUES (?, ?, ?, 'CREDIT', ?, 'Transfer in')" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-TARGET-ACC TO WS-BIND-2
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-3
                MOVE WS-TARGET-CUR TO WS-BIND-4
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Audit the movement inside the same transaction.
            IF WS-TRANSFER-OK
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (?, 'TRANSFER', 'ACCOUNT', ?, 'SUCCESS')" TO WS-PREP-SQL
                MOVE WS-SENDER-USER TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Mark the intent committed (the reference only persists on success).
            IF WS-TRANSFER-OK AND LS-PARAM4 NOT = SPACES
                MOVE "UPDATE pending_transactions SET status = 'COMMITTED' WHERE txn_ref = ?" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Commit or roll back the whole movement.
            IF WS-TRANSFER-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|TRANSFER_OK" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                IF WS-TRANSFER-FAIL-DB
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                ELSE
                    IF WS-TRANSFER-FAIL-IDEMP
                        MOVE "ERROR|TRANSFER_IN_PROGRESS" TO LS-OUTPUT-BUFFER
                    ELSE
                        IF WS-TRANSFER-FAIL-AMOUNT
                            MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                        ELSE
                            IF WS-TRANSFER-FAIL-CURR
                                MOVE "ERROR|CURRENCY_MISMATCH" TO LS-OUTPUT-BUFFER
                            ELSE
                                IF WS-TRANSFER-FAIL-SENDER
                                    MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                                ELSE
                                    IF WS-TRANSFER-FAIL-TARGET
                                        MOVE "ERROR|TARGET_NOT_FOUND" TO LS-OUTPUT-BUFFER
                                    ELSE
                                        MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                                    END-IF
                                END-IF
                            END-IF
                        END-IF
                    END-IF
                END-IF
            END-IF.
            EXIT PARAGRAPH.
