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
        01  WS-I                   PIC 9(3).
        01  WS-TRANSFER-STATE      PIC X(5) VALUE 'OK  '.
            88  WS-TRANSFER-OK       VALUE 'OK'.
            88  WS-TRANSFER-FAIL-SENDER VALUE 'SNDR'.
            88  WS-TRANSFER-FAIL-TARGET VALUE 'TGRT'.
            88  WS-TRANSFER-FAIL-INSUF VALUE 'INSUF'.
        01  WS-BALANCE-NUM         PIC S9(13)V99 COMP-3.
        01  WS-AMOUNT-NUM          PIC S9(13)V99 COMP-3.
        01  WS-NOW                 PIC X(21) VALUE SPACES.
        01  WS-TXN-REF             PIC X(17) VALUE SPACES.
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
                    PERFORM TRANSFER-LOGIC
                WHEN LS-CMD-ACTION(1:9) = "RECONCILE"
                    PERFORM RECONCILE-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        TRIM-PARAM1.
            MOVE LS-PARAM1 TO WS-PARAM1-TRIMMED.
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1
                IF WS-PARAM1-TRIMMED(WS-I:1) = SPACE
                    MOVE SPACE TO WS-PARAM1-TRIMMED(WS-I:1)
                END-IF
            END-PERFORM.

        TRIM-PARAM2.
            MOVE LS-PARAM2 TO WS-PARAM2-TRIMMED.
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1
                IF WS-PARAM2-TRIMMED(WS-I:1) = SPACE
                    MOVE SPACE TO WS-PARAM2-TRIMMED(WS-I:1)
                END-IF
            END-PERFORM.

        TRIM-PARAM3.
            MOVE LS-PARAM3 TO WS-PARAM3-TRIMMED.
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1
                IF WS-PARAM3-TRIMMED(WS-I:1) = SPACE
                    MOVE SPACE TO WS-PARAM3-TRIMMED(WS-I:1)
                END-IF
            END-PERFORM.

        GET-BALANCE-LOGIC.
            MOVE SPACES TO WS-QUERY.
            STRING "SELECT CONCAT(ROUND(a.balance, 2)) FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = '" 
                   WS-PARAM1-TRIMMED "'" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING.
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY.
            CALL "SQL_EXECUTE".
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE WS-RESULT TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        RECONCILE-LOGIC.
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

        TRANSFER-LOGIC.
            SET WS-TRANSFER-OK TO TRUE.
            MOVE FUNCTION CURRENT-DATE TO WS-NOW
            MOVE SPACES TO WS-TXN-REF
            STRING "TXN" WS-NOW(1:14) DELIMITED BY SIZE INTO WS-TXN-REF
            END-STRING
            
            *> Lock the sender account row and read its id, user, balance and currency.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT CAST(a.account_id AS CHAR), CAST(a.user_id AS CHAR), CONCAT(ROUND(a.balance,2)), CAST(a.currency_id AS CHAR) " 
                   "FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = '" 
                   WS-PARAM1-TRIMMED "' FOR UPDATE" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SQL_BEGIN"
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-SENDER TO TRUE
            ELSE
                UNSTRING WS-RESULT DELIMITED BY "|"
                    INTO WS-SENDER-ACC WS-SENDER-USER WS-SENDER-BAL WS-SENDER-CUR
                END-UNSTRING
            END-IF
            
            *> Resolve the target account (no lock needed on the credit side).
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-QUERY
                STRING "SELECT CAST(a.account_id AS CHAR), CAST(a.currency_id AS CHAR) " 
                       "FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = '" 
                       WS-PARAM2-TRIMMED "'" DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-TARGET TO TRUE
                ELSE
                    UNSTRING WS-RESULT DELIMITED BY "|"
                        INTO WS-TARGET-ACC WS-TARGET-CUR
                    END-UNSTRING
                END-IF
            END-IF
            
            *> Sufficiency check against the locked balance.
            IF WS-TRANSFER-OK
                COMPUTE WS-BALANCE-NUM = FUNCTION NUMVAL(WS-SENDER-BAL)
                COMPUTE WS-AMOUNT-NUM = FUNCTION NUMVAL(WS-PARAM3-TRIMMED)
                IF WS-BALANCE-NUM < WS-AMOUNT-NUM
                    SET WS-TRANSFER-FAIL-INSUF TO TRUE
                END-IF
            END-IF
            
            *> Debit sender.
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-QUERY
                STRING "UPDATE accounts SET balance = balance - " WS-PARAM3-TRIMMED 
                       " WHERE account_id = " WS-SENDER-ACC DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET WS-TRANSFER-FAIL-SENDER TO TRUE
                END-IF
            END-IF
            
            *> Credit target.
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-QUERY
                STRING "UPDATE accounts SET balance = balance + " WS-PARAM3-TRIMMED 
                       " WHERE account_id = " WS-TARGET-ACC DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET WS-TRANSFER-FAIL-TARGET TO TRUE
                END-IF
            END-IF
            
            *> Immutable ledger entries: one DEBIT, one CREDIT, same txn_ref.
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description) VALUES ('" 
                       WS-TXN-REF "', " WS-SENDER-ACC ", " WS-PARAM3-TRIMMED ", 'DEBIT', " WS-SENDER-CUR ", 'Transfer out')" 
                       DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-SENDER TO TRUE
                END-IF
            END-IF
            
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description) VALUES ('" 
                       WS-TXN-REF "', " WS-TARGET-ACC ", " WS-PARAM3-TRIMMED ", 'CREDIT', " WS-TARGET-CUR ", 'Transfer in')" 
                       DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-TARGET TO TRUE
                END-IF
            END-IF
            
            *> Audit the movement inside the same transaction.
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (" 
                       WS-SENDER-USER ", 'TRANSFER', 'ACCOUNT', " WS-SENDER-ACC ", 'SUCCESS')" 
                       DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-SENDER TO TRUE
                END-IF
            END-IF
            
            *> Commit or roll back the whole movement.
            IF WS-TRANSFER-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|TRANSFER_OK" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                IF WS-TRANSFER-FAIL-SENDER
                    MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    IF WS-TRANSFER-FAIL-TARGET
                        MOVE "ERROR|TARGET_NOT_FOUND" TO LS-OUTPUT-BUFFER
                    ELSE
                        MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                    END-IF
                END-IF
            END-IF.
            EXIT PARAGRAPH.
