        IDENTIFICATION DIVISION.
        PROGRAM-ID. auth_core.

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
        01  WS-STATUS               PIC X(20) VALUE SPACES.
        01  WS-I                    PIC 9(3).

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
                WHEN LS-CMD-ACTION(1:10) = "AUTH_LOGIN"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM LOGIN-LOGIC
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

        LOGIN-LOGIC.
            *> 1) Does the account exist, and what is its status?
            MOVE SPACES TO WS-QUERY
            STRING "SELECT status FROM users WHERE email = '" 
                   WS-PARAM1-TRIMMED "' LIMIT 1" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE WS-RESULT TO WS-STATUS
            
            *> 2) Password check. Stored format is 'SHA256_' + sha256 hex
            *>    (matches hash_password in cobol/c_lib/hash_lib.c); SHA2()
            *>    reproduces it server-side.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 FROM users WHERE email = '" 
                   WS-PARAM1-TRIMMED "' AND password_hash = CONCAT('SHA256_', SHA2(RTRIM('" 
                   WS-PARAM2-TRIMMED "'), 256))" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> 3) Only a VERIFIED account may log in.
            IF WS-STATUS(1:8) = "VERIFIED"
                MOVE "SUCCESS|LOGIN_OK" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "ERROR|UNVERIFIED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.
