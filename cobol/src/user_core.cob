        IDENTIFICATION DIVISION.
        PROGRAM-ID. user_core.

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
                WHEN LS-CMD-ACTION(1:8) = "GET_USER"
                    PERFORM ACTION-GET-USER
                WHEN LS-CMD-ACTION(1:10) = "LIST_USERS"
                    PERFORM ACTION-LIST-USERS
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        ACTION-GET-USER.
            MOVE SPACES TO WS-QUERY.
            STRING "SELECT id, email FROM users WHERE email = '" 
                   FUNCTION TRIM(LS-PARAM1) "' LIMIT 1"
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING.
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY.
            CALL "SQL_EXECUTE".
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
            
            MOVE WS-RESULT TO LS-OUTPUT-BUFFER.
            GOBACK.
        ACTION-LIST-USERS.
            MOVE SPACES TO WS-QUERY.
            STRING "SELECT 1, 'LIST_DONE' WHERE status = 'OK'" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING.
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY.
            CALL "SQL_EXECUTE".
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
            
            MOVE "SUCCESS|LIST_DONE" TO LS-OUTPUT-BUFFER.
            GOBACK.
