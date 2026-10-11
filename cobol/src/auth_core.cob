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
        01  WS-PARAM3-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM4-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-STATUS               PIC X(20) VALUE SPACES.
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
                WHEN LS-CMD-ACTION(1:10) = "AUTH_LOGIN"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM LOGIN-LOGIC
                WHEN LS-CMD-ACTION(1:14) = "REQUEST_SIGNUP"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM SIGNUP-LOGIC
                WHEN LS-CMD-ACTION(1:12) = "VERIFY_EMAIL"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM VERIFY-LOGIC
                WHEN LS-CMD-ACTION(1:10) = "CHECK_ROLE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM CHECK-ROLE-LOGIC
                WHEN LS-CMD-ACTION(1:11) = "CHANGE_ROLE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM CHANGE-ROLE-LOGIC
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

        LOGIN-LOGIC.
            *> 1) Does the account exist, and what is its status?
            MOVE SPACES TO WS-QUERY
            STRING "SELECT status FROM users WHERE email = '" 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) "' LIMIT 1" DELIMITED BY SIZE INTO WS-QUERY
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
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) "' AND password_hash = CONCAT('SHA256_', SHA2('" 
                   WS-PARAM2-TRIMMED(1:WS-P2-LEN) "', 256))" DELIMITED BY SIZE INTO WS-QUERY
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

        SIGNUP-LOGIC.
            SET STEP-OK TO TRUE
            *> Password complexity: at least 8 characters.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 WHERE CHAR_LENGTH('" WS-PARAM2-TRIMMED(1:WS-P2-LEN) "') >= 8" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|WEAK_PASSWORD" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> Email must be unique.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 FROM users WHERE email = '" WS-PARAM1-TRIMMED(1:WS-P1-LEN) "' LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "ERROR|EMAIL_EXISTS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> Secure 6-digit verification code.
            CALL "generate_random_code" USING BY REFERENCE WS-CODE
            
            CALL "SQL_BEGIN"
            
            MOVE SPACES TO WS-QUERY
            STRING "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('" 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) "', CONCAT('SHA256_', SHA2('" WS-PARAM2-TRIMMED(1:WS-P2-LEN) "', 256)), '" 
                   WS-PARAM3-TRIMMED(1:WS-P3-LEN) "', '" WS-PARAM4-TRIMMED(1:WS-P4-LEN) "', 'UNVERIFIED', 'USER')" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES ('" 
                       WS-PARAM1-TRIMMED(1:WS-P1-LEN) "', '" WS-CODE(1:6) "', 'SIGNUP', DATE_ADD(NOW(), INTERVAL 24 HOUR))" 
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
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|USER_CREATED|" WS-CODE(1:6) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|SIGNUP_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        VERIFY-LOGIC.
            *> Code must match, be unused, unexpired, for a SIGNUP.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 FROM verification_logs WHERE email = '" WS-PARAM1-TRIMMED(1:WS-P1-LEN) 
                   "' AND code = '" WS-PARAM2-TRIMMED(1:WS-P2-LEN) "' AND purpose = 'SIGNUP' AND is_used = 0 AND expires_at > NOW() LIMIT 1" 
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
            STRING "UPDATE users SET status = 'VERIFIED' WHERE email = '" WS-PARAM1-TRIMMED(1:WS-P1-LEN) "'" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                MOVE SPACES TO WS-QUERY
                STRING "UPDATE verification_logs SET is_used = 1 WHERE email = '" WS-PARAM1-TRIMMED(1:WS-P1-LEN) 
                       "' AND code = '" WS-PARAM2-TRIMMED(1:WS-P2-LEN) "' AND purpose = 'SIGNUP'" 
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
                MOVE "SUCCESS|EMAIL_VERIFIED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|VERIFY_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        CHECK-ROLE-LOGIC.
            *> Does this user hold the given role?
            MOVE SPACES TO WS-QUERY
            STRING "SELECT role FROM users WHERE email = '" WS-PARAM1-TRIMMED(1:WS-P1-LEN) "' LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE WS-RESULT TO WS-STATUS
            
            IF WS-STATUS(1:WS-P2-LEN) = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE "SUCCESS|ROLE_OK" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "ERROR|ROLE_DENIED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        CHANGE-ROLE-LOGIC.
            *> Only a SUPER_ADMIN (the actor, p3) may change roles.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT role FROM users WHERE email = '" WS-PARAM3-TRIMMED(1:WS-P3-LEN) "' LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> The new role must be one of the known roles.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 WHERE '" WS-PARAM2-TRIMMED(1:WS-P2-LEN) "' IN ('USER','MANAGER','SUPER_ADMIN')" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_ROLE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> The target user must exist.
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
            
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN"
            
            MOVE SPACES TO WS-QUERY
            STRING "UPDATE users SET role = '" WS-PARAM2-TRIMMED(1:WS-P2-LEN) "' WHERE email = '" 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) "'" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|ROLE_CHANGED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|ROLE_CHANGE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.
