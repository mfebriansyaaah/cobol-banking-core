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

        LINKAGE SECTION.
       01  LS-CMD-ACTION          PIC X(30).
       01  LS-PARAM1              PIC X(100).
       01  LS-PARAM2              PIC X(100).
       01  LS-PARAM3              PIC X(100).
       01  LS-PARAM4              PIC X(100).
       01  LS-OUTPUT-BUFFER      PIC X(500).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-OUTPUT-BUFFER.
        
        MAIN-LOGIC.
            DISPLAY "DEBUG_WALLET: action=[" FUNCTION TRIM(LS-CMD-ACTION) "]".
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
            GOBACK.

        TRIM-PARAM2.
            MOVE LS-PARAM2 TO WS-PARAM2-TRIMMED.
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1
                IF WS-PARAM2-TRIMMED(WS-I:1) = SPACE
                    MOVE SPACE TO WS-PARAM2-TRIMMED(WS-I:1)
                END-IF
            END-PERFORM.
            GOBACK.

        TRIM-PARAM3.
            MOVE LS-PARAM3 TO WS-PARAM3-TRIMMED.
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1
                IF WS-PARAM3-TRIMMED(WS-I:1) = SPACE
                    MOVE SPACE TO WS-PARAM3-TRIMMED(WS-I:1)
                END-IF
            END-PERFORM.
            GOBACK.

        GET-BALANCE-LOGIC.
            DISPLAY "DEBUG: Entering GET-BALANCE-LOGIC"
            MOVE SPACES TO WS-QUERY.
            STRING "SELECT CAST(a.balance AS CHAR) FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = '" 
                   WS-PARAM1-TRIMMED "'" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING.
            DISPLAY "DEBUG: Query built: " WS-QUERY
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY.
            CALL "SQL_EXECUTE".
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
            DISPLAY "DEBUG: SQL Result received: " WS-RESULT
            
            MOVE WS-RESULT TO LS-OUTPUT-BUFFER.
            DISPLAY "DEBUG: Result moved to LS-OUTPUT-BUFFER"
            GOBACK.

        TRANSFER-LOGIC.
            MOVE SPACES TO WS-QUERY.
            STRING "UPDATE accounts SET balance = balance - " WS-PARAM3-TRIMMED 
                   " WHERE account_id = (SELECT id FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = '" 
                   WS-PARAM1-TRIMMED "')" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING.
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY.
            CALL "SQL_EXECUTE".
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
            
            IF WS-RESULT(1:7) NOT = "SUCCESS"
                MOVE "ERROR|INSUFFICIENT_FUNDS_OR_NOT_FOUND" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF.
            
            MOVE SPACES TO WS-QUERY.
            STRING "UPDATE accounts SET balance = balance + " WS-PARAM3-TRIMMED 
                   " WHERE account_id = (SELECT id FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = '" 
                   WS-PARAM2-TRIMMED "')" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING.
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY.
            CALL "SQL_EXECUTE".
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
            
            IF WS-RESULT(1:7) NOT = "SUCCESS"
                MOVE "ERROR|TARGET_NOT_FOUND" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF.
            
            MOVE "SUCCESS|TRANSFER_OK" TO LS-OUTPUT-BUFFER.
            GOBACK.
