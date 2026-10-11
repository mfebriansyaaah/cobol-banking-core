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
        01  WS-USER-ID              PIC X(20) VALUE SPACES.
        01  WS-ID-LEN               PIC 9(3) VALUE 1.
        01  WS-FAILS                PIC X(20) VALUE SPACES.
        01  WS-FAIL-COUNT           PIC 9(4) VALUE 0.
        01  WS-CODE                 PIC X(7) VALUE SPACES.
        01  WS-PLAIN                PIC X(100) VALUE SPACES.
        01  WS-HASH                 PIC X(256) VALUE SPACES.
        01  WS-STORED               PIC X(256) VALUE SPACES.
        01  WS-VERIFY               PIC X(1) VALUE SPACES.
        01  WS-HLEN                 PIC 9(3) VALUE 1.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
        01  WS-I                    PIC 9(3).
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-P1-ESC               PIC X(256) VALUE SPACES.
        01  WS-PREP-SQL             PIC X(256) VALUE SPACES.
        01  WS-P2-ESC               PIC X(256) VALUE SPACES.
        01  WS-P3-ESC               PIC X(256) VALUE SPACES.
        01  WS-P4-ESC               PIC X(256) VALUE SPACES.
        01  WS-P1-ELEN              PIC 9(3) VALUE 1.
        01  WS-P2-ELEN              PIC 9(3) VALUE 1.
        01  WS-P3-ELEN              PIC 9(3) VALUE 1.
        01  WS-P4-ELEN              PIC 9(3) VALUE 1.
        01  F-NL                    PIC X VALUE X"0A".
        01  F-CR                    PIC X VALUE X"0D".

        LINKAGE SECTION.
        01  LS-CMD-ACTION          PIC X(30).
        01  LS-PARAM1              PIC X(100).
        01  LS-PARAM2              PIC X(100).
        01  LS-PARAM3              PIC X(100).
        01  LS-PARAM4              PIC X(100).
        01  LS-OUTPUT-BUFFER      PIC X(500).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-OUTPUT-BUFFER.

        MAIN-LOGIC.
            PERFORM TRIM-PARAM1
            PERFORM TRIM-PARAM2
            PERFORM TRIM-PARAM3
            PERFORM TRIM-PARAM4
            PERFORM ESCAPE-PARAMS
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:10) = "AUTH_LOGIN"
                    PERFORM LOGIN-LOGIC
                WHEN LS-CMD-ACTION(1:14) = "REQUEST_SIGNUP"
                    PERFORM SIGNUP-LOGIC
                WHEN LS-CMD-ACTION(1:12) = "VERIFY_EMAIL"
                    PERFORM VERIFY-LOGIC
                WHEN LS-CMD-ACTION(1:10) = "CHECK_ROLE"
                    PERFORM CHECK-ROLE-LOGIC
                WHEN LS-CMD-ACTION(1:11) = "CHANGE_ROLE"
                    PERFORM CHANGE-ROLE-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "STORE_SESSION"
                    PERFORM STORE-SESSION-LOGIC
                WHEN LS-CMD-ACTION(1:14) = "REVOKE_SESSION"
                    PERFORM REVOKE-SESSION-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "CHECK_SESSION"
                    PERFORM CHECK-SESSION-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        VALIDATE-ALL.
            *> Only protocol-breaking characters are rejected here; SQL values
            *> are escaped via ESCAPE-PARAMS.
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
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-NL
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-CR.
            EXIT PARAGRAPH.

        ESCAPE-PARAMS.
            CALL "SQL_ESCAPE" USING BY REFERENCE WS-PARAM1-TRIMMED BY REFERENCE WS-P1-ESC BY VALUE 256
            MOVE 0 TO WS-P1-ELEN
            PERFORM VARYING WS-I FROM 256 BY -1 UNTIL WS-I < 1 OR WS-P1-ELEN > 0
                IF WS-P1-ESC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P1-ELEN
                END-IF
            END-PERFORM
            CALL "SQL_ESCAPE" USING BY REFERENCE WS-PARAM2-TRIMMED BY REFERENCE WS-P2-ESC BY VALUE 256
            MOVE 0 TO WS-P2-ELEN
            PERFORM VARYING WS-I FROM 256 BY -1 UNTIL WS-I < 1 OR WS-P2-ELEN > 0
                IF WS-P2-ESC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P2-ELEN
                END-IF
            END-PERFORM
            CALL "SQL_ESCAPE" USING BY REFERENCE WS-PARAM3-TRIMMED BY REFERENCE WS-P3-ESC BY VALUE 256
            MOVE 0 TO WS-P3-ELEN
            PERFORM VARYING WS-I FROM 256 BY -1 UNTIL WS-I < 1 OR WS-P3-ELEN > 0
                IF WS-P3-ESC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P3-ELEN
                END-IF
            END-PERFORM
            CALL "SQL_ESCAPE" USING BY REFERENCE WS-PARAM4-TRIMMED BY REFERENCE WS-P4-ESC BY VALUE 256
            MOVE 0 TO WS-P4-ELEN
            PERFORM VARYING WS-I FROM 256 BY -1 UNTIL WS-I < 1 OR WS-P4-ELEN > 0
                IF WS-P4-ESC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P4-ELEN
                END-IF
            END-PERFORM
            IF WS-P1-ELEN = 0
                MOVE 1 TO WS-P1-ELEN
            END-IF
            IF WS-P2-ELEN = 0
                MOVE 1 TO WS-P2-ELEN
            END-IF
            IF WS-P3-ELEN = 0
                MOVE 1 TO WS-P3-ELEN
            END-IF
            IF WS-P4-ELEN = 0
                MOVE 1 TO WS-P4-ELEN
            END-IF.
            EXIT PARAGRAPH.

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

        GET-USER-ID.
            *> WS-USER-ID / WS-ID-LEN for the user named by param 1's email.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT CAST(id AS CHAR) FROM users WHERE email = '" WS-P1-ESC(1:WS-P1-ELEN) "' LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-USER-ID
            MOVE 0 TO WS-ID-LEN
            PERFORM VARYING WS-I FROM 20 BY -1 UNTIL WS-I < 1 OR WS-ID-LEN > 0
                IF WS-USER-ID(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-ID-LEN
                END-IF
            END-PERFORM
            IF WS-ID-LEN = 0
                MOVE 1 TO WS-ID-LEN
            END-IF.
            EXIT PARAGRAPH.

        COMPUTE-HASH-LEN.            *> Length up to the NUL that the C hash function writes.
            MOVE 1 TO WS-HLEN
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 256 OR WS-HLEN > 1
                IF WS-HASH(WS-I:1) = LOW-VALUE
                    COMPUTE WS-HLEN = WS-I - 1
                END-IF
            END-PERFORM
            IF WS-HLEN < 1
                MOVE 1 TO WS-HLEN
            END-IF.

        LOGIN-LOGIC.
            *> 1) Does the account exist, and what is its status?
            MOVE SPACES TO WS-QUERY
            STRING "SELECT CAST(id AS CHAR), status FROM users WHERE email = '" 
                   WS-P1-ESC(1:WS-P1-ELEN) "' LIMIT 1" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-USER-ID WS-STATUS
            END-UNSTRING
            MOVE 0 TO WS-ID-LEN
            PERFORM VARYING WS-I FROM 20 BY -1 UNTIL WS-I < 1 OR WS-ID-LEN > 0
                IF WS-USER-ID(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-ID-LEN
                END-IF
            END-PERFORM
            IF WS-ID-LEN = 0
                MOVE 1 TO WS-ID-LEN
            END-IF
            
            *> 2) Lockout: 3 failed attempts within 15 minutes blocks login.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT CAST(COUNT(*) AS CHAR) FROM audit_trail WHERE user_id = " 
                   WS-USER-ID(1:WS-ID-LEN) " AND action = 'AUTH_LOGIN_FAILED' AND created_at > DATE_SUB(NOW(), INTERVAL 15 MINUTE)" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-FAILS
            COMPUTE WS-FAIL-COUNT = FUNCTION NUMVAL(WS-FAILS)
            
            IF WS-FAIL-COUNT >= 3
                MOVE "ERROR|ACCOUNT_LOCKED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> 3) Password check: fetch the stored hash and verify against it
            *>    (PBKDF2, with a legacy SHA256 fallback).
            MOVE SPACES TO WS-QUERY
            STRING "SELECT password_hash FROM users WHERE email = '" 
                   WS-P1-ESC(1:WS-P1-ELEN) "' LIMIT 1" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-STORED
            
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
            CALL "verify_password" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-STORED BY REFERENCE WS-VERIFY
            
            IF WS-VERIFY NOT = "1"
                *> Record the failed attempt for lockout counting.
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO audit_trail (user_id, action, entity_type, status) VALUES (" 
                       WS-USER-ID(1:WS-ID-LEN) ", 'AUTH_LOGIN_FAILED', 'USER', 'FAILED')" 
                       DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> 3b) Transparently upgrade a legacy SHA256 hash to PBKDF2.
            IF WS-STORED(1:7) = "SHA256_"
                MOVE SPACES TO WS-PLAIN
                MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
                CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH
                PERFORM COMPUTE-HASH-LEN
                MOVE SPACES TO WS-QUERY
                STRING "UPDATE users SET password_hash = '" WS-HASH(1:WS-HLEN) "' WHERE email = '" 
                       WS-P1-ESC(1:WS-P1-ELEN) "'" DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            END-IF
            
            *> 4) Only a VERIFIED account may log in.
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
            STRING "SELECT 1 WHERE CHAR_LENGTH('" WS-P2-ESC(1:WS-P2-ELEN) "') >= 8" 
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
            STRING "SELECT 1 FROM users WHERE email = '" WS-P1-ESC(1:WS-P1-ELEN) "' LIMIT 1" 
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
            
            *> Slow KDF hash (PBKDF2-HMAC-SHA256).
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
            CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH
            PERFORM COMPUTE-HASH-LEN
            
            CALL "SQL_BEGIN"
            
            *> Prepared insert: values are bound, not concatenated.
            MOVE "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES (?, ?, ?, ?, 'UNVERIFIED', 'USER')" 
                 TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING
                BY REFERENCE WS-PREP-SQL
                BY VALUE 4
                BY REFERENCE WS-PARAM1-TRIMMED
                BY REFERENCE WS-HASH
                BY REFERENCE WS-PARAM3-TRIMMED
                BY REFERENCE WS-PARAM4-TRIMMED
                BY REFERENCE WS-PARAM4-TRIMMED
                BY REFERENCE WS-PARAM4-TRIMMED
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES ('" 
                       WS-P1-ESC(1:WS-P1-ELEN) "', '" WS-CODE(1:6) "', 'SIGNUP', DATE_ADD(NOW(), INTERVAL 24 HOUR))" 
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
                PERFORM GET-USER-ID
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (" 
                       WS-USER-ID(1:WS-ID-LEN) ", 'SIGNUP', 'USER', " WS-USER-ID(1:WS-ID-LEN) ", 'SUCCESS')" 
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
            STRING "SELECT 1 FROM verification_logs WHERE email = '" WS-P1-ESC(1:WS-P1-ELEN) 
                   "' AND code = '" WS-P2-ESC(1:WS-P2-ELEN) "' AND purpose = 'SIGNUP' AND is_used = 0 AND expires_at > NOW() LIMIT 1" 
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
            STRING "UPDATE users SET status = 'VERIFIED' WHERE email = '" WS-P1-ESC(1:WS-P1-ELEN) "'" 
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
                STRING "UPDATE verification_logs SET is_used = 1 WHERE email = '" WS-P1-ESC(1:WS-P1-ELEN) 
                       "' AND code = '" WS-P2-ESC(1:WS-P2-ELEN) "' AND purpose = 'SIGNUP'" 
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
                PERFORM GET-USER-ID
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (" 
                       WS-USER-ID(1:WS-ID-LEN) ", 'VERIFY_EMAIL', 'USER', " WS-USER-ID(1:WS-ID-LEN) ", 'SUCCESS')" 
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
            STRING "SELECT role FROM users WHERE email = '" WS-P1-ESC(1:WS-P1-ELEN) "' LIMIT 1" 
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
            
            IF WS-STATUS(1:WS-P2-LEN) = WS-P2-ESC(1:WS-P2-ELEN)
                MOVE "SUCCESS|ROLE_OK" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "ERROR|ROLE_DENIED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        CHANGE-ROLE-LOGIC.
            *> Only a SUPER_ADMIN (the actor, p3) may change roles.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT role FROM users WHERE email = '" WS-P3-ESC(1:WS-P3-ELEN) "' LIMIT 1" 
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
            STRING "SELECT 1 WHERE '" WS-P2-ESC(1:WS-P2-ELEN) "' IN ('USER','MANAGER','SUPER_ADMIN')" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_ROLE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> The target user must exist; capture its id for the audit row.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT CAST(id AS CHAR) FROM users WHERE email = '" WS-P1-ESC(1:WS-P1-ELEN) "' LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE WS-RESULT TO WS-USER-ID
            MOVE 0 TO WS-ID-LEN
            PERFORM VARYING WS-I FROM 20 BY -1 UNTIL WS-I < 1 OR WS-ID-LEN > 0
                IF WS-USER-ID(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-ID-LEN
                END-IF
            END-PERFORM
            IF WS-ID-LEN = 0
                MOVE 1 TO WS-ID-LEN
            END-IF
            
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN"
            
            MOVE SPACES TO WS-QUERY
            STRING "UPDATE users SET role = '" WS-P2-ESC(1:WS-P2-ELEN) "' WHERE email = '" 
                   WS-P1-ESC(1:WS-P1-ELEN) "'" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (" 
                       WS-USER-ID(1:WS-ID-LEN) ", 'CHANGE_ROLE', 'USER', " WS-USER-ID(1:WS-ID-LEN) ", 'SUCCESS')" 
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
                MOVE "SUCCESS|ROLE_CHANGED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|ROLE_CHANGE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        STORE-SESSION-LOGIC.
            *> p1 = jti, p2 = email, p3 = lifetime in days.
            MOVE SPACES TO WS-QUERY
            STRING "INSERT INTO refresh_sessions (jti, email, expires_at) VALUES ('" 
                   WS-P1-ESC(1:WS-P1-ELEN) "', '" WS-P2-ESC(1:WS-P2-ELEN) "', DATE_ADD(NOW(), INTERVAL " 
                   WS-P3-ESC(1:WS-P3-ELEN) " DAY))" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|SESSION_STORE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|SESSION_STORED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        REVOKE-SESSION-LOGIC.
            *> p1 = jti.
            MOVE SPACES TO WS-QUERY
            STRING "UPDATE refresh_sessions SET revoked = 1 WHERE jti = '" WS-P1-ESC(1:WS-P1-ELEN) "'" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|SESSION_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|SESSION_REVOKED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        CHECK-SESSION-LOGIC.
            *> p1 = jti. Valid only if present, unrevoked and unexpired.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 FROM refresh_sessions WHERE jti = '" WS-P1-ESC(1:WS-P1-ELEN) 
                   "' AND revoked = 0 AND expires_at > NOW() LIMIT 1" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|SESSION_REVOKED" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|SESSION_CHECK_FAILED" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "SUCCESS|SESSION_VALID" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.
