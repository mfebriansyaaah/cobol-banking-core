       IDENTIFICATION DIVISION.
       PROGRAM-ID. WALLET-CORE.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-EXIT-CODE            PIC 9(2) VALUE 0.
       01  WS-QUERY                PIC X(512) VALUE SPACES.
       01  WS-RESULT               PIC X(512) VALUE SPACES.

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
               WHEN LS-CMD-ACTION = "GET_BALANCE"
                   PERFORM GET-BALANCE-LOGIC
               WHEN LS-CMD-ACTION = "TRANSFER"
                   PERFORM TRANSFER-LOGIC
               WHEN OTHER
                   MOVE 4 TO WS-EXIT-CODE
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

       GET-BALANCE-LOGIC.
           MOVE SPACES TO WS-QUERY.
           STRING "SELECT balance FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = '" 
                  LS-PARAM1 "'" DELIMITED BY SIZE INTO WS-QUERY
           END-STRING.
           
           CALL "SET_QUERY" USING BY REFERENCE WS-QUERY.
           CALL "SQL_EXECUTE".
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
           
           MOVE WS-RESULT TO LS-OUTPUT-BUFFER.
           GOBACK.

       TRANSFER-LOGIC.
           MOVE SPACES TO WS-QUERY.
           STRING "UPDATE accounts SET balance = balance - " LS-PARAM3 
                  " WHERE account_id = (SELECT id FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = '" 
                  LS-PARAM1 "')" DELIMITED BY SIZE INTO WS-QUERY
           END-STRING.
           
           CALL "SET_QUERY" USING BY REFERENCE WS-QUERY.
           CALL "SQL_EXECUTE".
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
           
           IF WS-RESULT(1:7) NOT = "SUCCESS"
               MOVE "ERROR|INSUFFICIENT_FUNDS_OR_NOT_FOUND" TO LS-OUTPUT-BUFFER
               GOBACK
           END-IF.
           
           MOVE SPACES TO WS-QUERY.
           STRING "UPDATE accounts SET balance = balance + " LS-PARAM3 
                  " WHERE account_id = (SELECT id FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = '" 
                  LS-PARAM2, "')" DELIMITED BY SIZE INTO WS-QUERY
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
