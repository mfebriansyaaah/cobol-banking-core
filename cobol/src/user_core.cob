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
        01  WS-PARAM1-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM2-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM3-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM4-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-EMAIL                PIC X(100) VALUE SPACES.
        01  WS-NAME                 PIC X(100) VALUE SPACES.
        01  WS-BAL                  PIC X(30) VALUE SPACES.
        01  WS-ELEN                 PIC 9(3) VALUE 1.
        01  WS-NLEN                 PIC 9(3) VALUE 1.
        01  WS-BLEN                 PIC 9(3) VALUE 1.
        01  WS-RLEN                 PIC 9(3) VALUE 1.
        01  WS-CODE                 PIC X(7) VALUE SPACES.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
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
                WHEN LS-CMD-ACTION(1:8) = "GET_USER"
                    PERFORM TRIM-PARAM1
                    PERFORM ACTION-GET-USER
                WHEN LS-CMD-ACTION(1:10) = "LIST_USERS"
                    PERFORM ACTION-LIST-USERS
                WHEN LS-CMD-ACTION(1:13) = "GET_DASHBOARD"
                    PERFORM TRIM-PARAM1
                    PERFORM ACTION-DASHBOARD
                WHEN LS-CMD-ACTION(1:16) = "REQ_EMAIL_CHANGE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM ACTION-REQ-EMAIL-CHANGE
                WHEN LS-CMD-ACTION(1:20) = "CONFIRM_EMAIL_CHANGE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM ACTION-CONFIRM-EMAIL-CHANGE
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        TRIM-PARAM1.
            MOVE LS-PARAM1 TO WS-PARAM1-TRIMMED
            MOVE 0 TO WS-P1-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P1-LEN > 0
                IF WS-PARAM1-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P1-LEN
                END-IF
            END-PERFORM
            IF WS-P1-LEN = 0
                MOVE 1 TO WS-P1-LEN
            END-IF.

        TRIM-PARAM2.
            MOVE LS-PARAM2 TO WS-PARAM2-TRIMMED
            MOVE 0 TO WS-P2-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P2-LEN > 0
                IF WS-PARAM2-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P2-LEN
                END-IF
            END-PERFORM
            IF WS-P2-LEN = 0
                MOVE 1 TO WS-P2-LEN
            END-IF.

        TRIM-PARAM3.
            MOVE LS-PARAM3 TO WS-PARAM3-TRIMMED
            MOVE 0 TO WS-P3-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P3-LEN > 0
                IF WS-PARAM3-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P3-LEN
                END-IF
            END-PERFORM
            IF WS-P3-LEN = 0
                MOVE 1 TO WS-P3-LEN
            END-IF.

        TRIM-PARAM4.
            MOVE LS-PARAM4 TO WS-PARAM4-TRIMMED
            MOVE 0 TO WS-P4-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P4-LEN > 0
                IF WS-PARAM4-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P4-LEN
                END-IF
            END-PERFORM
            IF WS-P4-LEN = 0
                MOVE 1 TO WS-P4-LEN
            END-IF.

        TRIM-OUTPUT-VALUES.
            MOVE 0 TO WS-ELEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-ELEN > 0
                IF WS-EMAIL(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-ELEN
                END-IF
            END-PERFORM
            MOVE 0 TO WS-NLEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-NLEN > 0
                IF WS-NAME(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-NLEN
                END-IF
            END-PERFORM
            MOVE 0 TO WS-BLEN
            PERFORM VARYING WS-I FROM 30 BY -1 UNTIL WS-I < 1 OR WS-BLEN > 0
                IF WS-BAL(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-BLEN
                END-IF
            END-PERFORM
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-I FROM 512 BY -1 UNTIL WS-I < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-RLEN
                END-IF
            END-PERFORM
            IF WS-ELEN = 0
                MOVE 1 TO WS-ELEN
            END-IF
            IF WS-NLEN = 0
                MOVE 1 TO WS-NLEN
            END-IF
            IF WS-BLEN = 0
                MOVE 1 TO WS-BLEN
            END-IF
            IF WS-RLEN = 0
                MOVE 1 TO WS-RLEN
            END-IF.

        ACTION-GET-USER.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT id, email FROM users WHERE email = '" 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) "' LIMIT 1"
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE WS-RESULT TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LIST-USERS.
            *> Single-line list via GROUP_CONCAT (bridge returns one row).
            MOVE SPACES TO WS-QUERY
            STRING "SELECT SUBSTRING(GROUP_CONCAT(CONCAT(id, ':', email) ORDER BY id SEPARATOR ';'), 1, 400) FROM users" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            PERFORM TRIM-OUTPUT-VALUES
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|LIST_DONE|" WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-DASHBOARD.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT u.email, u.full_name, CONCAT(ROUND(a.balance,2)) " 
                   "FROM users u JOIN accounts a ON a.user_id = u.id WHERE u.email = '" 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) "' LIMIT 1"
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-EMAIL WS-NAME WS-BAL
            END-UNSTRING
            
            PERFORM TRIM-OUTPUT-VALUES
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|DASHBOARD|" WS-BAL(1:WS-BLEN) "|" WS-EMAIL(1:WS-ELEN) "|" WS-NAME(1:WS-NLEN) 
                   DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-REQ-EMAIL-CHANGE.
            *> The current user must exist.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 FROM users WHERE email = '" WS-PARAM1-TRIMMED(1:WS-P1-LEN) "' LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> The new email must not already belong to someone.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 FROM users WHERE email = '" WS-PARAM2-TRIMMED(1:WS-P2-LEN) "' LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "ERROR|EMAIL_EXISTS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            CALL "generate_random_code" USING BY REFERENCE WS-CODE
            
            *> Store the code against the target email.
            MOVE SPACES TO WS-QUERY
            STRING "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES ('" 
                   WS-PARAM2-TRIMMED(1:WS-P2-LEN) "', '" WS-CODE(1:6) "', 'EMAIL_CHANGE', DATE_ADD(NOW(), INTERVAL 24 HOUR))" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|EMAIL_CHANGE_FAILED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|CODE_SENT|" WS-CODE(1:6) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CONFIRM-EMAIL-CHANGE.
            *> p1 = current email, p2 = new email, p3 = code.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 FROM verification_logs WHERE email = '" WS-PARAM2-TRIMMED(1:WS-P2-LEN) 
                   "' AND code = '" WS-PARAM3-TRIMMED(1:WS-P3-LEN) "' AND purpose = 'EMAIL_CHANGE' AND is_used = 0 AND expires_at > NOW() LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_CODE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN"
            
            MOVE SPACES TO WS-QUERY
            STRING "UPDATE users SET email = '" WS-PARAM2-TRIMMED(1:WS-P2-LEN) "' WHERE email = '" 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) "'" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                MOVE SPACES TO WS-QUERY
                STRING "UPDATE verification_logs SET is_used = 1 WHERE email = '" WS-PARAM2-TRIMMED(1:WS-P2-LEN) 
                       "' AND code = '" WS-PARAM3-TRIMMED(1:WS-P3-LEN) "' AND purpose = 'EMAIL_CHANGE'" 
                       DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|EMAIL_CHANGED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|EMAIL_CHANGE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.
