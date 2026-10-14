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
        01  WS-RESULT               PIC X(16384) VALUE SPACES.
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
        01  WS-FAMILY               PIC X(50) VALUE SPACES.
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
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-P1-ESC               PIC X(256) VALUE SPACES.
        01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
        01  WS-BIND-1               PIC X(256) VALUE SPACES.
        01  WS-BIND-2               PIC X(256) VALUE SPACES.
        01  WS-BIND-3               PIC X(256) VALUE SPACES.
        01  WS-BIND-4               PIC X(256) VALUE SPACES.
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
        01  LS-OUTPUT-BUFFER      PIC X(16384).

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
                WHEN LS-CMD-ACTION(1:15) = "FORGOT_PASSWORD"
                    PERFORM FORGOT-PASSWORD-LOGIC
                WHEN LS-CMD-ACTION(1:14) = "RESET_PASSWORD"
                    PERFORM RESET-PASSWORD-LOGIC
                WHEN LS-CMD-ACTION(1:15) = "CHANGE_PASSWORD"
                    PERFORM CHANGE-PASSWORD-LOGIC
                WHEN LS-CMD-ACTION(1:19) = "RESEND_VERIFICATION"
                    PERFORM RESEND-VERIFICATION-LOGIC
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
                WHEN LS-CMD-ACTION(1:11) = "CHECK_TOKEN"
                    PERFORM CHECK-TOKEN-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "REVOKE_TOKENS"
                    PERFORM REVOKE-TOKENS-LOGIC
                WHEN LS-CMD-ACTION(1:19) = "REVOKE_ACCESS_TOKEN"
                    PERFORM REVOKE-ACCESS-TOKEN-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "ARCHIVE_AUDIT"
                    PERFORM ARCHIVE-AUDIT-LOGIC
                WHEN LS-CMD-ACTION(1:17) = "GET_TOKEN_VERSION"
                    PERFORM GET-TOKEN-VERSION-LOGIC
                WHEN LS-CMD-ACTION(1:4) = "PING"
                    PERFORM PING-LOGIC
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
            MOVE "SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
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
            *> 1) Does the account exist, and what is its status? (prepared)
            MOVE "SELECT CAST(id AS CHAR), status FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING
                BY REFERENCE WS-PREP-SQL
                BY VALUE 1
                BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                *> Uniform failure: do not reveal whether the account exists,
                *> and spend the same KDF work so the timing matches a real
                *> password check.
                MOVE SPACES TO WS-PLAIN
                MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
                CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
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
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, status) VALUES (?, 'AUTH_LOGIN_FAILED', 'USER', 'FAILED')" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
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
                *> Neutral: never reveal whether the email is already
                *> registered. Spend the same KDF work as a real signup so
                *> the timing does not leak it either.
                MOVE SPACES TO WS-PLAIN
                MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
                CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH
                MOVE "SUCCESS|USER_CREATED" TO LS-OUTPUT-BUFFER
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
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-HASH TO WS-BIND-2
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-3
            MOVE WS-PARAM4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING
                BY REFERENCE WS-PREP-SQL
                BY VALUE 4
                BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-4
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                *> Housekeeping: drop expired verification logs.
                MOVE "DELETE FROM verification_logs WHERE expires_at < NOW()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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

        AUDIT-FAILED-VERIFY.
            *> Best-effort: record a failed attempt when the email belongs to a user.
            PERFORM GET-USER-ID
            IF WS-RESULT(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-QUERY
            STRING "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (" 
                   WS-USER-ID(1:WS-ID-LEN) ", 'VERIFY_EMAIL', 'USER', " WS-USER-ID(1:WS-ID-LEN) ", 'FAILED')" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
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
                PERFORM AUDIT-FAILED-VERIFY
                *> Count the guess; once the cap is reached the code is burned
                *> so it can no longer be brute forced (a new one is required).
                MOVE "UPDATE verification_logs SET attempts = attempts + 1 WHERE email = ? AND purpose = 'SIGNUP' AND is_used = 0 ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "UPDATE verification_logs SET is_used = 1 WHERE email = ? AND purpose = 'SIGNUP' AND is_used = 0 AND attempts >= 5" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "ERROR|INVALID_CODE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN"
            
            MOVE "UPDATE users SET status = 'VERIFIED' WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                MOVE "UPDATE verification_logs SET is_used = 1 WHERE email = ? AND code = ? AND purpose = 'SIGNUP'" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            
            IF STEP-OK
                PERFORM GET-USER-ID
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (?, 'VERIFY_EMAIL', 'USER', ?, 'SUCCESS')" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                MOVE WS-USER-ID TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
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

        FORGOT-PASSWORD-LOGIC.
            *> p1 = email. Neutral: send a code only when the account exists.
            PERFORM GET-USER-ID
            IF WS-RESULT = "ERROR|NO_DATA" OR WS-RESULT(1:5) = "ERROR"
                MOVE "SUCCESS|CODE_SENT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "DELETE FROM verification_logs WHERE email = ? AND purpose = 'PASSWORD_RESET' AND is_used = 0" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            CALL "generate_random_code" USING BY REFERENCE WS-CODE
            MOVE "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES (?, ?, 'PASSWORD_RESET', DATE_ADD(NOW(), INTERVAL 1 HOUR))" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-CODE TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|RESET_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|CODE_SENT|" WS-CODE(1:6) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        RESET-PASSWORD-LOGIC.
            *> p1 = email, p2 = code, p3 = new password. Transactional.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 WHERE CHAR_LENGTH('" WS-P3-ESC(1:WS-P3-ELEN) "') >= 8" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|WEAK_PASSWORD" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM verification_logs WHERE email = ? AND code = ? AND purpose = 'PASSWORD_RESET' AND is_used = 0 AND expires_at > NOW() LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                *> Cap reset-code guessing: burn the code after 5 failures.
                MOVE "UPDATE verification_logs SET attempts = attempts + 1 WHERE email = ? AND purpose = 'PASSWORD_RESET' AND is_used = 0 ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "UPDATE verification_logs SET is_used = 1 WHERE email = ? AND purpose = 'PASSWORD_RESET' AND is_used = 0 AND attempts >= 5" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "ERROR|INVALID_CODE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM3-TRIMMED(1:WS-P3-LEN) TO WS-PLAIN
            CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH
            PERFORM COMPUTE-HASH-LEN
            PERFORM GET-USER-ID
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN"
            MOVE "UPDATE users SET password_hash = ?, token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-HASH TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "UPDATE verification_logs SET is_used = 1 WHERE email = ? AND code = ? AND purpose = 'PASSWORD_RESET'" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (?, 'PASSWORD_RESET', 'USER', ?, 'SUCCESS')" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|PASSWORD_RESET" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|RESET_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        CHANGE-PASSWORD-LOGIC.
            *> p1 = email, p2 = current password, p3 = new, p4 = actor (self).
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) NOT = WS-PARAM4-TRIMMED(1:WS-P4-LEN)
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT password_hash FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-STORED
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
            CALL "verify_password" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-STORED BY REFERENCE WS-VERIFY
            IF WS-VERIFY NOT = "1"
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 WHERE CHAR_LENGTH('" WS-P3-ESC(1:WS-P3-ELEN) "') >= 8" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|WEAK_PASSWORD" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM3-TRIMMED(1:WS-P3-LEN) TO WS-PLAIN
            CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH
            PERFORM COMPUTE-HASH-LEN
            PERFORM GET-USER-ID
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN"
            MOVE "UPDATE users SET password_hash = ?, token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-HASH TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (?, 'CHANGE_PASSWORD', 'USER', ?, 'SUCCESS')" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|PASSWORD_CHANGED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|PASSWORD_CHANGE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        RESEND-VERIFICATION-LOGIC.
            *> p1 = email. Neutral; resend only for an existing UNVERIFIED account.
            MOVE "SELECT status FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA" OR WS-RESULT(1:5) = "ERROR"
                MOVE "SUCCESS|CODE_SENT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "UNVERIFIED"
                MOVE "SUCCESS|CODE_SENT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "DELETE FROM verification_logs WHERE email = ? AND purpose = 'SIGNUP' AND is_used = 0" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            CALL "generate_random_code" USING BY REFERENCE WS-CODE
            MOVE "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES (?, ?, 'SIGNUP', DATE_ADD(NOW(), INTERVAL 24 HOUR))" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-CODE TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|RESEND_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|CODE_SENT|" WS-CODE(1:6) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        CHECK-ROLE-LOGIC.
            *> p1 = target email, p2 = role, p3 = actor. Self or admin only.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) = WS-PARAM3-TRIMMED(1:WS-P3-LEN)
                MOVE 1 TO WS-ALLOWED
            ELSE
                MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                    MOVE 1 TO WS-ALLOWED
                END-IF
            END-IF
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Does this user hold the given role?
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
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
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> The new role must be one of the known roles.
            MOVE "SELECT 1 WHERE ? IN ('USER','MANAGER','SUPER_ADMIN')" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_ROLE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> The target user must exist; capture its id for the audit row.
            MOVE "SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
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
            
            MOVE "UPDATE users SET role = ? WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (?, 'CHANGE_ROLE', 'USER', ?, 'SUCCESS')" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                MOVE WS-USER-ID TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
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
            *> p1 = jti, p2 = email, p3 = lifetime in days, p4 = family (defaults to jti).
            *> Housekeeping: drop expired sessions so the table does not grow forever.
            MOVE "DELETE FROM refresh_sessions WHERE expires_at < NOW()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE SPACES TO WS-PREP-SQL
            STRING "INSERT INTO refresh_sessions (jti, family, email, expires_at) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL "
                   WS-PARAM3-TRIMMED(1:WS-P3-LEN) " DAY))" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            IF LS-PARAM4 NOT = SPACES
                MOVE WS-PARAM4-TRIMMED TO WS-BIND-2
            ELSE
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            END-IF
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|SESSION_STORE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|SESSION_STORED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        REVOKE-SESSION-LOGIC.
            *> p1 = jti.
            MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE jti = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|SESSION_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|SESSION_REVOKED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        CHECK-SESSION-LOGIC.
            *> p1 = jti. VALID only if present, unrevoked and unexpired.
            *> A present-but-revoked token means reuse (likely theft): revoke
            *> every session in its family and report SESSION_REUSED.
            MOVE "SELECT revoked FROM refresh_sessions WHERE jti = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|SESSION_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|SESSION_CHECK_FAILED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:1) = "1"
                MOVE "SELECT family FROM refresh_sessions WHERE jti = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE WS-RESULT TO WS-FAMILY
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE family = ?" TO WS-PREP-SQL
                MOVE WS-FAMILY TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "ERROR|SESSION_REUSED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT 1 FROM refresh_sessions WHERE jti = ? AND revoked = 0 AND expires_at > NOW() LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|SESSION_EXPIRED" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|SESSION_CHECK_FAILED" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "SUCCESS|SESSION_VALID" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        GET-TOKEN-VERSION-LOGIC.
            *> p1 = email. Returns the current access-token version.
            MOVE "SELECT CAST(token_version AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|TOKEN_CHECK_FAILED" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE SPACES TO LS-OUTPUT-BUFFER
                    STRING "SUCCESS|" WS-RESULT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                    END-STRING
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        CHECK-TOKEN-LOGIC.
            *> p1 = email, p2 = version, p3 = jti (optional per-token denylist).
            MOVE "SELECT CAST(token_version AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|TOKEN_CHECK_FAILED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:WS-P2-LEN) NOT = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE "ERROR|TOKEN_REVOKED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE 1 TO WS-ALLOWED
            IF LS-PARAM3 NOT = SPACES
                MOVE "SELECT 1 FROM revoked_access_tokens WHERE jti = ? AND expires_at > NOW() LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT NOT = "ERROR|NO_DATA"
                    MOVE 0 TO WS-ALLOWED
                END-IF
            END-IF.
            IF WS-ALLOWED = 1
                MOVE "SUCCESS|TOKEN_VALID" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "ERROR|TOKEN_REVOKED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        REVOKE-TOKENS-LOGIC.
            *> p1 = email. Bump the version so every issued access token dies.
            MOVE "UPDATE users SET token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|TOKEN_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|TOKENS_REVOKED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        REVOKE-ACCESS-TOKEN-LOGIC.
            *> p1 = jti, p2 = email, p3 = ttl seconds. Deny a single access token.
            MOVE "DELETE FROM revoked_access_tokens WHERE expires_at < NOW()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE SPACES TO WS-PREP-SQL
            STRING "INSERT IGNORE INTO revoked_access_tokens (jti, email, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL " 
                   WS-PARAM3-TRIMMED(1:WS-P3-LEN) " SECOND))" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|TOKEN_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|TOKEN_REVOKED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ARCHIVE-AUDIT-LOGIC.
            *> p1 = retention days, p2 = actor (SUPER_ADMIN). Move older audit
            *> rows to the immutable archive, keeping the live table bounded.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN"
            MOVE SPACES TO WS-QUERY
            STRING "INSERT IGNORE INTO audit_trail_archive (audit_id, user_id, action, entity_type, entity_id, status, created_at) SELECT audit_id, user_id, action, entity_type, entity_id, status, created_at FROM audit_trail WHERE created_at < DATE_SUB(NOW(), INTERVAL " 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) " DAY)" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|AUDIT_ARCHIVE_FAILED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-QUERY
            STRING "DELETE FROM audit_trail WHERE created_at < DATE_SUB(NOW(), INTERVAL " 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) " DAY)" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|AUDIT_ARCHIVE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|ARCHIVED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        PING-LOGIC.
            *> Deep health: confirm the database answers a trivial query.
            MOVE SPACES TO WS-QUERY
            MOVE "SELECT 1" TO WS-QUERY
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_DOWN" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|PONG" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.
