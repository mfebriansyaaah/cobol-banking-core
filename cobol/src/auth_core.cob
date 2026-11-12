        IDENTIFICATION DIVISION.
        PROGRAM-ID. auth_core.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        COPY "auth_password_ws.cpy".
        LINKAGE SECTION.
        01  LS-CMD-ACTION          PIC X(30).
        01  LS-PARAM1              PIC X(100).
        01  LS-PARAM2              PIC X(100).
        01  LS-PARAM3              PIC X(100).
        01  LS-PARAM4              PIC X(100).
        01  LS-PARAM5              PIC X(100).
        01  LS-PARAM6              PIC X(100).
        01  LS-OUTPUT-BUFFER      PIC X(16384).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

        COPY "common_sql.cpy".

        MAIN-LOGIC.
            PERFORM TRIM-PARAM1
            PERFORM TRIM-PARAM2
            PERFORM TRIM-PARAM3
            PERFORM TRIM-PARAM4
            PERFORM TRIM-PARAM5
            PERFORM TRIM-PARAM6
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
                WHEN LS-CMD-ACTION(1:13) = "VERIFY_REAUTH"
                    PERFORM VERIFY-REAUTH-LOGIC
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
                WHEN LS-CMD-ACTION(1:15) = "CONSUME_SESSION"
                    PERFORM CONSUME-SESSION-LOGIC
                WHEN LS-CMD-ACTION(1:11) = "CHECK_TOKEN"
                    PERFORM CHECK-TOKEN-LOGIC
                WHEN LS-CMD-ACTION(1:19) = "REVOKE_ACCESS_TOKEN"
                    PERFORM REVOKE-ACCESS-TOKEN-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "LIST_SESSIONS"
                    PERFORM LIST-SESSIONS-LOGIC
                WHEN LS-CMD-ACTION(1:19) = "REVOKE_USER_SESSION"
                    PERFORM REVOKE-USER-SESSION-LOGIC
                WHEN LS-CMD-ACTION(1:20) = "REVOKE_ALL_SESSIONS"
                    PERFORM REVOKE-ALL-SESSIONS-LOGIC
                WHEN LS-CMD-ACTION(1:20) = "REVOKE_OTHER_DEVICES"
                    PERFORM REVOKE-OTHER-DEVICES-LOGIC
                WHEN LS-CMD-ACTION(1:12) = "LOGIN_NOTICE"
                    PERFORM LOGIN-NOTICE-LOGIC
                WHEN LS-CMD-ACTION(1:16) = "STEP_UP_REQUIRED"
                    PERFORM STEP-UP-REQUIRED-LOGIC
                WHEN LS-CMD-ACTION(1:17) = "GET_TOKEN_VERSION"
                    PERFORM GET-TOKEN-VERSION-LOGIC
                WHEN LS-CMD-ACTION(1:4) = "PING"
                    PERFORM PING-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        COPY "auth_password_helpers.cpy".
        COPY "auth_password_logic.cpy".

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
            CALL "SQL_ESCAPE" USING BY REFERENCE WS-PARAM1-TRIMMED BY REFERENCE WS-P1-ESC BY VALUE 256 END-CALL
            MOVE 0 TO WS-P1-ELEN
            PERFORM VARYING WS-I FROM 256 BY -1 UNTIL WS-I < 1 OR WS-P1-ELEN > 0
                IF WS-P1-ESC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P1-ELEN
                END-IF
            END-PERFORM
            CALL "SQL_ESCAPE" USING BY REFERENCE WS-PARAM2-TRIMMED BY REFERENCE WS-P2-ESC BY VALUE 256 END-CALL
            MOVE 0 TO WS-P2-ELEN
            PERFORM VARYING WS-I FROM 256 BY -1 UNTIL WS-I < 1 OR WS-P2-ELEN > 0
                IF WS-P2-ESC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P2-ELEN
                END-IF
            END-PERFORM
            CALL "SQL_ESCAPE" USING BY REFERENCE WS-PARAM3-TRIMMED BY REFERENCE WS-P3-ESC BY VALUE 256 END-CALL
            MOVE 0 TO WS-P3-ELEN
            PERFORM VARYING WS-I FROM 256 BY -1 UNTIL WS-I < 1 OR WS-P3-ELEN > 0
                IF WS-P3-ESC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P3-ELEN
                END-IF
            END-PERFORM
            CALL "SQL_ESCAPE" USING BY REFERENCE WS-PARAM4-TRIMMED BY REFERENCE WS-P4-ESC BY VALUE 256 END-CALL
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

        TRIM-PARAM5.
            MOVE LS-PARAM5 TO WS-PARAM5-TRIMMED
            MOVE 0 TO WS-P5-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P5-LEN > 0
                IF WS-PARAM5-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P5-LEN
                END-IF
            END-PERFORM
            IF WS-P5-LEN = 0
                MOVE 1 TO WS-P5-LEN
            END-IF.

        TRIM-PARAM6.
            MOVE LS-PARAM6 TO WS-PARAM6-TRIMMED
            MOVE 0 TO WS-P6-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P6-LEN > 0
                IF WS-PARAM6-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P6-LEN
                END-IF
            END-PERFORM
            IF WS-P6-LEN = 0
                MOVE 1 TO WS-P6-LEN
            END-IF.

        GET-USER-ID.
            *> WS-USER-ID / WS-ID-LEN for the user named by param 1's email.
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ID

            MOVE WS-RESULT(1:20) TO WS-USER-ID
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

        LOGIN-LOGIC.
            *> 1) Does the account exist, and what is its status? (prepared)
            MOVE "SELECT CAST(id AS CHAR), status, CAST(failed_logins AS CHAR), CASE WHEN locked_until IS NOT NULL AND locked_until > NOW() THEN '1' ELSE '0' END, CAST(mfa_enabled AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING
                BY REFERENCE WS-PREP-SQL
                BY VALUE 1
                BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
                BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
            IF WS-RESULT = "ERROR|NO_DATA"
                *> Uniform failure: do not reveal whether the account exists,
                *> and spend the same KDF work so the timing matches a real
                *> password check.
                MOVE SPACES TO WS-PLAIN
                MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
                CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH END-CALL
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-USER-ID WS-STATUS WS-FAILS WS-LOCKED WS-MFA-ON
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
            
            *> 2) Lockout state came with the row: WS-LOCKED is "1" while the
            *>    account is blocked (failed_logins / locked_until on the user).
            
            *> 3) Password check: fetch the stored hash and verify against it
            *>    (PBKDF2, with a legacy SHA256 fallback).
            MOVE SPACES TO WS-QUERY
            STRING "SELECT password_hash FROM users WHERE email = '" 
                   WS-P1-ESC(1:WS-P1-ELEN) "' LIMIT 1" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
            CALL "SQL_EXECUTE" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:256) TO WS-STORED
            
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
            CALL "verify_password" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-STORED BY REFERENCE WS-VERIFY END-CALL
            
            IF WS-VERIFY NOT = "1"
                *> Record and arm the lockout (no-op when already locked, so
                *> a locked account keeps returning the uniform error).
                PERFORM RECORD-LOGIN-FAILURE
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> 3a) A correct password on a locked account is told so; a wrong
            *>     password (above) is not, so lockout cannot be probed.
            IF WS-LOCKED = "1"
                MOVE "ERROR|ACCOUNT_LOCKED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> 3a2) Second factor: when MFA is on, a valid TOTP code is also
            *>      required. A wrong code is throttled like a wrong password.
            IF WS-MFA-ON = "1"
                IF WS-PARAM3-TRIMMED(1:1) = SPACE
                    MOVE "STEP_UP_FAILED" TO WS-STEPUP-ACTION
                    MOVE "FAILED" TO WS-AUDIT-STATUS
                    PERFORM AUDIT-STEPUP
                    MOVE "ERROR|MFA_REQUIRED" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE "SELECT mfa_secret FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE WS-RESULT(1:64) TO WS-MFA-SECRET
                CALL "totp_verify" USING BY REFERENCE WS-MFA-SECRET BY REFERENCE WS-PARAM3-TRIMMED BY REFERENCE WS-VERIFY END-CALL
                IF WS-VERIFY NOT = "1"
                    PERFORM CHECK-BACKUP-CODE
                END-IF
                IF WS-VERIFY NOT = "1" AND WS-BACKUP-OK NOT = "1"
                    PERFORM RECORD-LOGIN-FAILURE
                    MOVE "ERROR|INVALID_MFA" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF
            
            *> 3b) A valid password clears the failure counter.
            MOVE "UPDATE users SET failed_logins = 0, locked_until = NULL WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
            *> 3c) Transparently upgrade a legacy SHA256 hash, or a PBKDF2 hash
            *>     below the current cost target, to the current scheme.
            MOVE "0" TO WS-NEEDS-REHASH
            CALL "password_needs_rehash" USING BY REFERENCE WS-STORED BY REFERENCE WS-NEEDS-REHASH END-CALL
            IF WS-NEEDS-REHASH = "1"
                MOVE SPACES TO WS-PLAIN
                MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
                CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH END-CALL
                CALL "hashlen_core" USING BY REFERENCE WS-HASH BY REFERENCE WS-HLEN END-CALL
                MOVE SPACES TO WS-QUERY
                STRING "UPDATE users SET password_hash = '" WS-HASH(1:WS-HLEN) "' WHERE email = '" 
                       WS-P1-ESC(1:WS-P1-ELEN) "'" DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
                CALL "SQL_EXECUTE" END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            END-IF
            
            *> 4) Only a VERIFIED account may log in.
            IF WS-STATUS(1:8) = "VERIFIED"
                *> 4a) Record the sign-in, so a privileged access review can
                *>     see how long an account has been dormant.
                MOVE "UPDATE users SET last_login_at = NOW() WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) SELECT id, 'AUTH_LOGIN_SUCCESS', 'USER', id, 'SUCCESS' FROM users WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "SUCCESS|LOGIN_OK" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-STATUS(1:9) = "SUSPENDED"
                    MOVE "ERROR|USER_SUSPENDED" TO LS-OUTPUT-BUFFER
                ELSE
                    IF WS-STATUS(1:6) = "CLOSED"
                        MOVE "ERROR|USER_CLOSED" TO LS-OUTPUT-BUFFER
                    ELSE
                        MOVE "ERROR|UNVERIFIED" TO LS-OUTPUT-BUFFER
                    END-IF
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        SIGNUP-LOGIC.
            SET STEP-OK TO TRUE
            *> Password complexity: at least 8 characters.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 WHERE CHAR_LENGTH('" WS-P2-ESC(1:WS-P2-ELEN) "') >= 8" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
            CALL "SQL_EXECUTE" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|WEAK_PASSWORD" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Owner-controlled deny list (signup has no history yet).
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
            MOVE 0 TO WS-PW-BLOCKED
            MOVE 0 TO WS-PW-DBERR
            PERFORM CHECK-PASSWORD-BLOCKLIST
            IF WS-PW-DBERR = 1
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-PW-BLOCKED = 1
                MOVE "ERROR|PASSWORD_BLOCKED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> Email must be unique.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 FROM users WHERE email = '" WS-P1-ESC(1:WS-P1-ELEN) "' LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
            CALL "SQL_EXECUTE" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
            IF WS-RESULT NOT = "ERROR|NO_DATA"
                *> Neutral: never reveal whether the email is already
                *> registered. Spend the same KDF work as a real signup so
                *> the timing does not leak it either.
                MOVE SPACES TO WS-PLAIN
                MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
                CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH END-CALL
                MOVE "SUCCESS|USER_CREATED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> Secure 6-digit verification code.
            CALL "generate_random_code" USING BY REFERENCE WS-CODE END-CALL
            
            *> Slow KDF hash (PBKDF2-HMAC-SHA256).
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
            CALL "hash_password_v2" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-HASH END-CALL
            CALL "hashlen_core" USING BY REFERENCE WS-HASH BY REFERENCE WS-HLEN END-CALL
            
            CALL "SQL_BEGIN" END-CALL
            
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
                BY REFERENCE WS-BIND-5
                BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                *> Housekeeping: drop expired verification logs.
                MOVE "DELETE FROM verification_logs WHERE expires_at < NOW()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES ('" 
                       WS-P1-ESC(1:WS-P1-ELEN) "', '" WS-CODE(1:6) "', 'SIGNUP', DATE_ADD(NOW(), INTERVAL 24 HOUR))" 
                       DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
                CALL "SQL_EXECUTE" END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            
            IF STEP-OK
                MOVE WS-PARAM1-TRIMMED TO WS-NOTIF-TO
                MOVE "SIGNUP" TO WS-NOTIF-PURPOSE
                MOVE WS-CODE(1:6) TO WS-NOTIF-CODE
                MOVE SPACES TO WS-NOTIF-DETAIL
                PERFORM ENQUEUE-NOTIFICATION
            END-IF.
            IF WS-NOTIF-FAIL NOT = 0
                SET STEP-FAIL TO TRUE
            END-IF.

            IF STEP-OK
                PERFORM GET-USER-ID
                MOVE SPACES TO WS-QUERY
                STRING "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (" 
                       WS-USER-ID(1:WS-ID-LEN) ", 'SIGNUP', 'USER', " WS-USER-ID(1:WS-ID-LEN) ", 'SUCCESS')" 
                       DELIMITED BY SIZE INTO WS-QUERY
                END-STRING
                CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
                CALL "SQL_EXECUTE" END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|USER_CREATED|" WS-CODE(1:6) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
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
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
            CALL "SQL_EXECUTE" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
            EXIT PARAGRAPH.

        VERIFY-LOGIC.
            *> Code must match, be unused, unexpired, for a SIGNUP.
            MOVE SPACES TO WS-QUERY
            STRING "SELECT 1 FROM verification_logs WHERE email = '" WS-P1-ESC(1:WS-P1-ELEN) 
                   "' AND code = '" WS-P2-ESC(1:WS-P2-ELEN) "' AND purpose = 'SIGNUP' AND is_used = 0 AND expires_at > NOW() LIMIT 1" 
                   DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
            CALL "SQL_EXECUTE" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
            IF WS-RESULT = "ERROR|NO_DATA"
                PERFORM AUDIT-FAILED-VERIFY
                *> Count the guess; once the cap is reached the code is burned
                *> so it can no longer be brute forced (a new one is required).
                MOVE "UPDATE verification_logs SET attempts = attempts + 1 WHERE email = ? AND purpose = 'SIGNUP' AND is_used = 0 ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "UPDATE verification_logs SET is_used = 1 WHERE email = ? AND purpose = 'SIGNUP' AND is_used = 0 AND attempts >= 5" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "ERROR|INVALID_CODE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            
            MOVE "UPDATE users SET status = 'VERIFIED' WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                MOVE "UPDATE verification_logs SET is_used = 1 WHERE email = ? AND code = ? AND purpose = 'SIGNUP'" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|EMAIL_VERIFIED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|VERIFY_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        RESEND-VERIFICATION-LOGIC.
            *> p1 = email. Neutral; resend only for an existing UNVERIFIED account.
            MOVE "SELECT status FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA" OR WS-RESULT(1:5) = "ERROR"
                MOVE "SUCCESS|CODE_SENT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "UNVERIFIED"
                MOVE "SUCCESS|CODE_SENT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            *> Per-account resend cooldown: a fresh unused code issued inside
            *> the window is reused neutrally (no new code, no new email), so
            *> the endpoint cannot flood a mailbox or the table. Zero disables.
            MOVE SPACES TO WS-CD-STR
            CALL "env_or" USING BY REFERENCE "RESEND_COOLDOWN_SECONDS" BY REFERENCE "60" BY REFERENCE WS-CD-STR END-CALL
            IF WS-CD-STR(1:1) >= "1" AND WS-CD-STR(1:1) <= "9"
                MOVE SPACES TO WS-PREP-SQL
                STRING "SELECT COUNT(*) FROM verification_logs WHERE email = ? AND purpose = 'SIGNUP' AND is_used = 0 AND created_at > DATE_SUB(NOW(), INTERVAL " WS-CD-STR DELIMITED BY SIZE " SECOND)" DELIMITED BY SIZE INTO WS-PREP-SQL
                END-STRING
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:1) >= "1" AND WS-RESULT(1:1) <= "9"
                    MOVE "SUCCESS|CODE_SENT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "DELETE FROM verification_logs WHERE email = ? AND purpose = 'SIGNUP' AND is_used = 0" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                CALL "generate_random_code" USING BY REFERENCE WS-CODE END-CALL
                MOVE "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES (?, ?, 'SIGNUP', DATE_ADD(NOW(), INTERVAL 24 HOUR))" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-CODE TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                MOVE WS-PARAM1-TRIMMED TO WS-NOTIF-TO
                MOVE "SIGNUP" TO WS-NOTIF-PURPOSE
                MOVE WS-CODE(1:6) TO WS-NOTIF-CODE
                MOVE SPACES TO WS-NOTIF-DETAIL
                PERFORM ENQUEUE-NOTIFICATION
            END-IF.
            IF WS-NOTIF-FAIL NOT = 0
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|CODE_SENT|" WS-CODE(1:6) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|RESEND_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        RECORD-LOGIN-FAILURE.
            *> Arm the lockout and record a failed login. Used for a wrong
            *> password and a wrong MFA code. Skipped when already locked.
            IF WS-LOCKED = "0"
                MOVE "UPDATE users SET locked_until = CASE WHEN failed_logins + 1 >= 3 THEN DATE_ADD(NOW(), INTERVAL 15 MINUTE) ELSE locked_until END, failed_logins = failed_logins + 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, status) VALUES (?, 'AUTH_LOGIN_FAILED', 'USER', 'FAILED')" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            END-IF.
            EXIT PARAGRAPH.

        CHECK-BACKUP-CODE.
            *> p1 = owner email, p3 = candidate 10-digit code. Burns the
            *> matched row and sets WS-BACKUP-OK. Tried only after TOTP
            *> fails, and only for login/step-up (never for enrol/disable).
            MOVE 0 TO WS-BACKUP-OK
            IF WS-P3-LEN NOT = 10
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ID
            IF WS-RESULT(1:5) = "ERROR" OR WS-RESULT = "ERROR|NO_DATA"
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-USER-ID
            MOVE 0 TO WS-ID-LEN
            PERFORM VARYING WS-I FROM 20 BY -1 UNTIL WS-I < 1 OR WS-ID-LEN > 0
                IF WS-USER-ID(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-ID-LEN
                END-IF
            END-PERFORM.
            IF WS-ID-LEN = 0
                EXIT PARAGRAPH
            END-IF.
            MOVE 0 TO WS-BACKUP-N
            PERFORM VARYING WS-BACKUP-N FROM 0 BY 1 UNTIL WS-BACKUP-N >= 8 OR WS-BACKUP-OK NOT = 0
                MOVE "SELECT CAST(id AS CHAR), code_hash FROM mfa_backup_codes WHERE user_id = ? AND used = 0 ORDER BY id LIMIT 1 OFFSET ?" TO WS-PREP-SQL
                MOVE WS-USER-ID(1:WS-ID-LEN) TO WS-BIND-1
                MOVE WS-BACKUP-N TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT NOT = "ERROR|NO_DATA" AND WS-RESULT(1:5) NOT = "ERROR"
                    UNSTRING WS-RESULT DELIMITED BY "|"
                        INTO WS-BACKUP-ID WS-HASH
                    END-UNSTRING
                    MOVE SPACES TO WS-PLAIN
                    MOVE WS-PARAM3-TRIMMED(1:WS-P3-LEN) TO WS-PLAIN
                    MOVE WS-HASH TO WS-STORED
                    CALL "verify_password" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-STORED BY REFERENCE WS-VERIFY END-CALL
                    IF WS-VERIFY = "1"
                        MOVE "UPDATE mfa_backup_codes SET used = 1 WHERE id = ? AND used = 0" TO WS-PREP-SQL
                        MOVE WS-BACKUP-ID TO WS-BIND-1
                        CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                        CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                        IF WS-RESULT = "SUCCESS|AFFECTED_1"
                            MOVE 1 TO WS-BACKUP-OK
                        END-IF
                    END-IF
                END-IF
            END-PERFORM.
            EXIT PARAGRAPH.

        VERIFY-REAUTH-LOGIC.
            *> p1 = email, p2 = password, p3 = mfaCode (opt). Re-authenticates the
            *> bearer's own account for a step-up (no tokens, no lockout change).
            MOVE "SELECT status, CAST(mfa_enabled AS CHAR), role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-STATUS WS-MFA-ON WS-ROLE
            END-UNSTRING
            IF WS-STATUS(1:8) NOT = "VERIFIED"
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Password check (PBKDF2, legacy SHA256 fallback).
            MOVE SPACES TO WS-QUERY
            STRING "SELECT password_hash FROM users WHERE email = '"
                   WS-P1-ESC(1:WS-P1-ELEN) "' LIMIT 1" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
            CALL "SQL_EXECUTE" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:256) TO WS-STORED
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
            CALL "verify_password" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-STORED BY REFERENCE WS-VERIFY END-CALL
            IF WS-VERIFY NOT = "1"
                MOVE "STEP_UP_FAILED" TO WS-STEPUP-ACTION
                MOVE "FAILED" TO WS-AUDIT-STATUS
                PERFORM AUDIT-STEPUP
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Admin accounts must have MFA enabled to step up: a SUPER_ADMIN or
            *> MANAGER without MFA cannot perform a privileged action.
            IF (WS-ROLE = "SUPER_ADMIN" OR WS-ROLE = "MANAGER") AND WS-MFA-ON NOT = "1"
                MOVE "STEP_UP_FAILED" TO WS-STEPUP-ACTION
                MOVE "FAILED" TO WS-AUDIT-STATUS
                PERFORM AUDIT-STEPUP
                MOVE "ERROR|MFA_SETUP_REQUIRED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Second factor when MFA is on.
            IF WS-MFA-ON = "1"
                IF WS-PARAM3-TRIMMED(1:1) = SPACE
                    MOVE "ERROR|MFA_REQUIRED" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE "SELECT mfa_secret FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE WS-RESULT(1:64) TO WS-MFA-SECRET
                CALL "totp_verify" USING BY REFERENCE WS-MFA-SECRET BY REFERENCE WS-PARAM3-TRIMMED BY REFERENCE WS-VERIFY END-CALL
                IF WS-VERIFY NOT = "1"
                    PERFORM CHECK-BACKUP-CODE
                END-IF
                IF WS-VERIFY NOT = "1" AND WS-BACKUP-OK NOT = "1"
                    MOVE "STEP_UP_FAILED" TO WS-STEPUP-ACTION
                    MOVE "FAILED" TO WS-AUDIT-STATUS
                    PERFORM AUDIT-STEPUP
                    MOVE "ERROR|INVALID_MFA" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            MOVE "STEP_UP_OK" TO WS-STEPUP-ACTION
            MOVE "SUCCESS" TO WS-AUDIT-STATUS
            PERFORM AUDIT-STEPUP
            MOVE "SUCCESS|REAUTH_OK" TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.

        CHECK-ROLE-LOGIC.
            *> p1 = target email, p2 = role, p3 = actor. Self or admin only.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) = WS-PARAM3-TRIMMED(1:WS-P3-LEN)
                MOVE 1 TO WS-ALLOWED
            ELSE
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
                PERFORM LOOKUP-USER-ROLE
                IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                    MOVE 1 TO WS-ALLOWED
                END-IF
            END-IF
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Does this user hold the given role?
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE

            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE WS-RESULT(1:20) TO WS-STATUS
            
            IF WS-STATUS(1:WS-P2-LEN) = WS-P2-ESC(1:WS-P2-ELEN)
                MOVE "SUCCESS|ROLE_OK" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "ERROR|ROLE_DENIED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        GUARD-LAST-ADMIN-ROLE.
            *> p1 = target email, p2 = new role. Sets WS-ALLOWED = 1 when the
            *> change still leaves an active (VERIFIED) SUPER_ADMIN, so the last
            *> administrator can never be demoted away.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM2-TRIMMED(1:WS-P2-LEN) = "SUPER_ADMIN"
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM users WHERE role = 'SUPER_ADMIN' AND status = 'VERIFIED' AND email <> ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "0" AND WS-RESULT(1:5) NOT = "ERROR"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        CHANGE-ROLE-LOGIC.
            *> Only a SUPER_ADMIN (the actor, p3) may change roles.
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE

            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM3-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> A designated operation cannot run directly: it must travel
            *> the maker-checker request path instead.
            MOVE "SELECT COUNT(*) FROM dual_control_operations WHERE operation = 'CHANGE_ROLE'" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "0"
                MOVE "ERROR|DUAL_CONTROL_REQUIRED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            *> The new role must be one of the known roles.
            MOVE "SELECT 1 WHERE ? IN ('USER','MANAGER','SUPER_ADMIN')" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL

            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_ROLE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            *> The target user must exist; capture its id for the audit row.
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ID

            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE WS-RESULT(1:20) TO WS-USER-ID
            MOVE 0 TO WS-ID-LEN
            PERFORM VARYING WS-I FROM 20 BY -1 UNTIL WS-I < 1 OR WS-ID-LEN > 0
                IF WS-USER-ID(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-ID-LEN
                END-IF
            END-PERFORM
            IF WS-ID-LEN = 0
                MOVE 1 TO WS-ID-LEN
            END-IF
            
            *> Never demote the last active SUPER_ADMIN (would lock everyone out).
            PERFORM GUARD-LAST-ADMIN-ROLE
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|LAST_ADMIN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Capture the actor's id so the audit row names who changed the role.
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ID
            MOVE WS-RESULT(1:20) TO WS-ACTOR-ID
            
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            
            MOVE "UPDATE users SET role = ? WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL

            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT t.id, a.id, 'CHANGE_ROLE', 'USER', t.id, 'SUCCESS' FROM users t, users a WHERE t.email = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL

                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|ROLE_CHANGED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|ROLE_CHANGE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        REVOKE-OTHER-DEVICES-LOGIC.
            *> p1 = email, p2 = actor, p3 = presented family. Revoke every
            *> refresh session of the account except the caller's own family,
            *> so the other devices fail on their next refresh or request.
            PERFORM ALLOW-MANAGE-SESSION
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM3-TRIMMED NOT = SPACES
                CALL "SQL_BEGIN" END-CALL
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE email = ? AND family <> ? AND revoked = 0" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    CALL "SQL_ROLLBACK" END-CALL
                    MOVE "ERROR|SESSIONS_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT t.id, a.id, 'SESSIONS_REVOKED_OTHERS', 'USER', t.id, 'SUCCESS' FROM users t JOIN users a ON t.email = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    CALL "SQL_ROLLBACK" END-CALL
                    MOVE "ERROR|SESSIONS_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|OTHER_SESSIONS_REVOKED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        LOGIN-NOTICE-LOGIC.
            *> p1 = email, p2 = user agent, p3 = IP. Records the sign-in
            *> fingerprint and enqueues a NEW_DEVICE notice the first time the
            *> account is seen from it. Notification is best-effort: the login
            *> must not fail because the notice could not be queued.
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM known_devices WHERE email = ? AND user_agent = ? AND ip = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "INSERT IGNORE INTO known_devices (email, user_agent, ip) VALUES (?, ?, ?)" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:18) = "SUCCESS|AFFECTED_1"
                    MOVE WS-PARAM1-TRIMMED TO WS-NOTIF-TO
                    MOVE "NEW_DEVICE" TO WS-NOTIF-PURPOSE
                    MOVE SPACES TO WS-NOTIF-CODE
                    MOVE WS-PARAM3-TRIMMED TO WS-NOTIF-DETAIL
                    PERFORM ENQUEUE-NOTIFICATION
                END-IF
            ELSE
                MOVE "UPDATE known_devices SET last_seen_at = NOW() WHERE email = ? AND user_agent = ? AND ip = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SUCCESS|NOTICE_RECORDED" TO LS-OUTPUT-BUFFER
            EXIT PARAGRAPH.

        STEP-UP-REQUIRED-LOGIC.
            *> p1 = email, p2 = action, p3 = amount (optional; 0 when absent).
            *> Answers whether the owner-controlled catalogue requires a fresh
            *> step-up proof for this action at this amount.
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM3-TRIMMED = SPACES
                MOVE "0" TO WS-BIND-1
            ELSE
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            END-IF.
            MOVE "SELECT CAST(CASE WHEN min_amount > 0 AND ? < min_amount THEN 0 ELSE 1 END AS CHAR) FROM step_up_policy WHERE action = ? AND enabled = 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|STEP_UP_NOT_REQUIRED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT = "1"
                MOVE "SUCCESS|STEP_UP_REQUIRED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|STEP_UP_NOT_REQUIRED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ENQUEUE-NOTIFICATION.
            *> Transactional outbox: the intent commits or rolls back with
            *> the business action that created it. Sets WS-NOTIF-FAIL on
            *> DB error; the caller maps it to its own failure output.
            MOVE 0 TO WS-NOTIF-FAIL
            MOVE "INSERT INTO notification_outbox (recipient, purpose, code, detail) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-NOTIF-TO TO WS-BIND-1
            MOVE WS-NOTIF-PURPOSE TO WS-BIND-2
            MOVE WS-NOTIF-CODE TO WS-BIND-3
            MOVE WS-NOTIF-DETAIL TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE 1 TO WS-NOTIF-FAIL
            END-IF.
            EXIT PARAGRAPH.

        STORE-SESSION-LOGIC.
            *> p1 = jti, p2 = email, p3 = lifetime in days, p4 = family (defaults to jti).
            *> Housekeeping: drop expired sessions so the table does not grow forever.
            MOVE "DELETE FROM refresh_sessions WHERE expires_at < NOW()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE "DELETE FROM revoked_access_tokens WHERE expires_at < NOW()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            IF LS-PARAM4 NOT = SPACES
                MOVE WS-PARAM4-TRIMMED TO WS-BIND-2
            ELSE
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            END-IF
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
            *> Register the family for absolute-lifetime / rotation-cap tracking.
            MOVE "INSERT IGNORE INTO refresh_families (family, email) VALUES (?, ?)" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO WS-PREP-SQL
            STRING "INSERT INTO refresh_sessions (jti, family, email, expires_at, user_agent, ip, last_seen_at) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL "
                   WS-PARAM3-TRIMMED(1:WS-P3-LEN) " DAY), ?, ?, NOW())" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM5-TRIMMED TO WS-BIND-4
            MOVE WS-PARAM6-TRIMMED TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|SESSION_STORE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|SESSION_STORED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        REVOKE-SESSION-LOGIC.
            *> p1 = jti. Logout removes the session outright, so replaying a
            *> logged-out token is a plain not-found rather than "reuse" (which
            *> would revoke the family and kill every device).
            MOVE "DELETE FROM refresh_sessions WHERE jti = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|SESSION_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|SESSION_REVOKED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ENFORCE-IDLE-TIMEOUT.
            *> p1 = refresh jti. For administrators, refuse a refresh whose
            *> previous activity is older than ADMIN_IDLE_TIMEOUT_SECONDS:
            *> revoke the family, kill every access token, and audit. A value
            *> of 0 disables the bound. Unknown/expired sessions fall through
            *> to the ordinary consume path, which reports them.
            MOVE 0 TO WS-IDLE-EXPIRED
            MOVE SPACES TO WS-CD-STR
            CALL "env_or" USING BY REFERENCE "ADMIN_IDLE_TIMEOUT_SECONDS" BY REFERENCE "1800" BY REFERENCE WS-CD-STR END-CALL
            IF WS-CD-STR(1:1) < "0" OR WS-CD-STR(1:1) > "9"
                MOVE "1800" TO WS-CD-STR
            END-IF.
            IF WS-CD-STR = "0"
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CAST(TIMESTAMPDIFF(SECOND, COALESCE(s.last_seen_at, s.created_at), NOW()) AS CHAR), u.role, s.email, s.family FROM refresh_sessions s JOIN users u ON u.email = s.email WHERE s.jti = ? AND s.revoked = 0 AND s.expires_at > NOW() LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-IDLE-AGE
            MOVE SPACES TO WS-ROLE
            MOVE SPACES TO WS-SESSION-EMAIL
            MOVE SPACES TO WS-FAMILY
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-IDLE-AGE WS-ROLE WS-SESSION-EMAIL WS-FAMILY
            END-UNSTRING
            IF WS-ROLE NOT = "SUPER_ADMIN" AND WS-ROLE NOT = "MANAGER"
                EXIT PARAGRAPH
            END-IF.
            COMPUTE WS-IDLE-SECS = FUNCTION NUMVAL(WS-IDLE-AGE) END-COMPUTE
            COMPUTE WS-IDLE-LIMIT = FUNCTION NUMVAL(WS-CD-STR) END-COMPUTE
            IF WS-IDLE-SECS > WS-IDLE-LIMIT
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE family = ?" TO WS-PREP-SQL
                MOVE WS-FAMILY TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "UPDATE users SET token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-SESSION-EMAIL TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) SELECT id, 'SESSION_IDLE_TIMEOUT', 'USER', id, 'FAILED' FROM users WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-SESSION-EMAIL TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE 1 TO WS-IDLE-EXPIRED
            END-IF.
            EXIT PARAGRAPH.

        CONSUME-SESSION-LOGIC.
            *> p1 = jti. Atomically consume the refresh session: only the first
            *> caller wins. A later call on an already-revoked jti is reuse and
            *> kills the whole family plus every access token. An administrator
            *> idle past the configured bound is refused first.
            PERFORM ENFORCE-IDLE-TIMEOUT
            IF WS-IDLE-EXPIRED = 1
                MOVE "ERROR|SESSION_EXPIRED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE refresh_sessions SET revoked = 1, last_seen_at = NOW() WHERE jti = ? AND revoked = 0 AND expires_at > NOW()" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:18) = "SUCCESS|AFFECTED_1"
                PERFORM ENFORCE-FAMILY-LIMITS
                IF WS-FAMILY-OVER-LIMIT = 1
                    MOVE "ERROR|SESSION_FAMILY_EXPIRED" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "SUCCESS|SESSION_CONSUMED" TO LS-OUTPUT-BUFFER
                END-IF
                EXIT PARAGRAPH
            END-IF
            *> Not consumed: unknown, expired, or already revoked (reuse).
            MOVE "SELECT CAST(revoked AS CHAR), family, email FROM refresh_sessions WHERE jti = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|SESSION_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-REVOKED-FLAG WS-FAMILY WS-SESSION-EMAIL
            END-UNSTRING
            IF WS-REVOKED-FLAG(1:1) NOT = "1"
                *> Still unrevoked but outside its expiry window.
                MOVE "ERROR|SESSION_EXPIRED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-REVOKED-FLAG(1:1) = "1"
                *> Reuse: revoke the family, kill every access token, audit.
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE family = ?" TO WS-PREP-SQL
                MOVE WS-FAMILY TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "UPDATE users SET token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-SESSION-EMAIL TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) SELECT id, 'SESSION_REUSED', 'USER', id, 'FAILED' FROM users WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-SESSION-EMAIL TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "ERROR|SESSION_REUSED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ENFORCE-FAMILY-LIMITS.
            *> p1 = jti. Runs after a successful consume. Ensure the family row
            *> exists, then refuse (and revoke the family) when it is older than
            *> REFRESH_ABSOLUTE_TTL_DAYS or has rotated more than
            *> REFRESH_MAX_ROTATIONS times; otherwise count this rotation.
            MOVE 0 TO WS-FAMILY-OVER-LIMIT
            MOVE "SELECT family, email FROM refresh_sessions WHERE jti = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE 1 TO WS-FAMILY-OVER-LIMIT
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-FAMILY WS-SESSION-EMAIL
            END-UNSTRING
            MOVE "INSERT IGNORE INTO refresh_families (family, email) VALUES (?, ?)" TO WS-PREP-SQL
            MOVE WS-FAMILY TO WS-BIND-1
            MOVE WS-SESSION-EMAIL TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE "SELECT CAST(TIMESTAMPDIFF(SECOND, created_at, NOW()) AS CHAR), CAST(rotations AS CHAR) FROM refresh_families WHERE family = ?" TO WS-PREP-SQL
            MOVE WS-FAMILY TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                *> Fail closed: without family state we cannot allow the rotation.
                MOVE 1 TO WS-FAMILY-OVER-LIMIT
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-AGE-STR WS-ROT-STR
            END-UNSTRING
            COMPUTE WS-AGE-SECS = FUNCTION NUMVAL(WS-AGE-STR) END-COMPUTE
            COMPUTE WS-ROT-COUNT = FUNCTION NUMVAL(WS-ROT-STR) END-COMPUTE
            MOVE SPACES TO WS-ABS-TTL-STR
            CALL "env_or" USING BY REFERENCE "REFRESH_ABSOLUTE_TTL_DAYS" BY REFERENCE "30" BY REFERENCE WS-ABS-TTL-STR END-CALL
            MOVE SPACES TO WS-MAX-ROT-STR
            CALL "env_or" USING BY REFERENCE "REFRESH_MAX_ROTATIONS" BY REFERENCE "100" BY REFERENCE WS-MAX-ROT-STR END-CALL
            COMPUTE WS-ABS-SECS = FUNCTION NUMVAL(WS-ABS-TTL-STR) * 86400 END-COMPUTE
            COMPUTE WS-MAX-ROT = FUNCTION NUMVAL(WS-MAX-ROT-STR) END-COMPUTE
            IF WS-ABS-SECS > 0 AND WS-AGE-SECS > WS-ABS-SECS
                MOVE 1 TO WS-FAMILY-OVER-LIMIT
            END-IF
            IF WS-MAX-ROT > 0 AND WS-ROT-COUNT >= WS-MAX-ROT
                MOVE 1 TO WS-FAMILY-OVER-LIMIT
            END-IF
            IF WS-FAMILY-OVER-LIMIT = 1
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE family = ?" TO WS-PREP-SQL
                MOVE WS-FAMILY TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) SELECT id, 'SESSION_FAMILY_EXPIRED', 'USER', id, 'FAILED' FROM users WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-SESSION-EMAIL TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            ELSE
                MOVE "UPDATE refresh_families SET rotations = rotations + 1 WHERE family = ?" TO WS-PREP-SQL
                MOVE WS-FAMILY TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            END-IF.
            EXIT PARAGRAPH.

        GET-TOKEN-VERSION-LOGIC.
            *> p1 = email. Returns the current access-token version.
            MOVE "SELECT CAST(token_version AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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

        REVOKE-ACCESS-TOKEN-LOGIC.
            *> p1 = jti, p2 = email, p3 = ttl seconds. Deny a single access token.
            MOVE "DELETE FROM revoked_access_tokens WHERE expires_at < NOW()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO WS-PREP-SQL
            STRING "INSERT IGNORE INTO revoked_access_tokens (jti, email, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL " 
                   WS-PARAM3-TRIMMED(1:WS-P3-LEN) " SECOND))" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|TOKEN_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|TOKEN_REVOKED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        TRIM-RESULT-LEN.
            *> Compute WS-RLEN = length of WS-RESULT without trailing spaces.
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-J FROM 16383 BY -1 UNTIL WS-J < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-J:1) NOT = SPACE
                    MOVE WS-J TO WS-RLEN
                END-IF
            END-PERFORM
            IF WS-RLEN = 0
                MOVE 1 TO WS-RLEN
            END-IF.
            EXIT PARAGRAPH.

        ALLOW-READ.
            *> Sets WS-ALLOWED when the actor (p2) owns the target (p1) or is admin.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF
            IF WS-ALLOWED NOT = 1
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-STEPUP.
            *> WS-STEPUP-ACTION / WS-AUDIT-STATUS / p1 = email. Best-effort:
            *> a failed audit row must not change the step-up decision.
            MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) SELECT id, ?, 'USER', id, ? FROM users WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-STEPUP-ACTION TO WS-BIND-1
            MOVE WS-AUDIT-STATUS TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            *> Records a refused authorization attempt for the actor named by
            *> WS-DENIED-ACTOR; unknown actors produce no row. Best-effort.
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            PERFORM RECORD-AUTHZ-DENIED
            EXIT PARAGRAPH.
        ALLOW-MANAGE-SESSION.
            *> p1 = target email, p2 = actor. Self-service is always allowed;
            *> managing another account's sessions additionally requires the
            *> actor not to be lower-ranked (a MANAGER can never force-logout a
            *> SUPER_ADMIN). Reads (LIST_SESSIONS) keep the plain ALLOW-READ.
            PERFORM ALLOW-READ
            IF WS-ALLOWED NOT = 1
                EXIT PARAGRAPH
            END-IF
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                EXIT PARAGRAPH
            ELSE
                PERFORM ALLOW-RANK-ABOVE
            END-IF.
            EXIT PARAGRAPH.

        ALLOW-RANK-ABOVE.
            *> p1 = target email, p2 = actor email. Allowed when the actor's role
            *> is not lower than the target's (USER < MANAGER < SUPER_ADMIN).
            MOVE 0 TO WS-ALLOWED
            MOVE 0 TO WS-ACTOR-RANK
            MOVE 0 TO WS-TARGET-RANK
            MOVE "SELECT CONCAT(a.role, '|', t.role) FROM users a JOIN users t ON a.email = ? AND t.email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-ACTOR-ROLE WS-TARGET-ROLE
            END-UNSTRING
            MOVE WS-ACTOR-ROLE TO WS-RANK-ROLE
            PERFORM RANK-OF-ROLE
            MOVE WS-RANK TO WS-ACTOR-RANK
            MOVE WS-TARGET-ROLE TO WS-RANK-ROLE
            PERFORM RANK-OF-ROLE
            MOVE WS-RANK TO WS-TARGET-RANK
            IF WS-ACTOR-RANK >= WS-TARGET-RANK
                MOVE 1 TO WS-ALLOWED
            END-IF
            IF WS-ALLOWED NOT = 1
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        RANK-OF-ROLE.
            *> Map WS-RANK-ROLE to WS-RANK: USER=1, MANAGER=2, SUPER_ADMIN=3.
            MOVE 1 TO WS-RANK
            IF WS-RANK-ROLE = "SUPER_ADMIN"
                MOVE 3 TO WS-RANK
            ELSE
                IF WS-RANK-ROLE = "MANAGER"
                    MOVE 2 TO WS-RANK
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        LIST-SESSIONS-LOGIC.
            *> p1 = email, p2 = actor. Self or admin. Active sessions only.
            PERFORM ALLOW-READ
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT CONCAT(jti, ':', DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s'), ':', DATE_FORMAT(expires_at, '%Y-%m-%dT%H:%i:%s'), ':', COALESCE(user_agent, '-'), ':', COALESCE(ip, '-'), ':', CASE WHEN family = ? THEN 'current' ELSE '' END) FROM refresh_sessions WHERE email = ? AND revoked = 0 AND expires_at > NOW() ORDER BY created_at DESC" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|SESSIONS|" TO LS-OUTPUT-BUFFER
            ELSE
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|SESSIONS|" WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        REVOKE-USER-SESSION-LOGIC.
            *> p1 = email, p2 = actor, p3 = session id (jti). Self, or an admin
            *> who is not lower-ranked. Only a session of the target is revoked.
            PERFORM ALLOW-MANAGE-SESSION
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE jti = ? AND email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:18) = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|SESSION_NOT_FOUND" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|SESSION_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
                ELSE
                    PERFORM AUDIT-SESSION-REVOKED
                    MOVE "SUCCESS|SESSION_REVOKED" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-SESSION-REVOKED.
            *> p1 = target email, p2 = actor, p3 = jti. Records who revoked a
            *> session and on whose account. Best-effort (errors are ignored).
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT t.id, a.id, 'REVOKE_USER_SESSION', 'SESSION', ?, 'SUCCESS' FROM users t JOIN users a ON a.email = ? AND t.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
            EXIT PARAGRAPH.

        REVOKE-ALL-SESSIONS-LOGIC.
            *> p1 = email, p2 = actor. Self, or an admin who is not lower-ranked.
            *> Kills every session: bump the access-token version and revoke all.
            PERFORM ALLOW-MANAGE-SESSION
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE users SET token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT t.id, a.id, 'SESSIONS_REVOKED', 'USER', t.id, 'SUCCESS' FROM users t JOIN users a ON t.email = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|SESSIONS_REVOKED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|SESSIONS_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        PING-LOGIC.
            *> Deep health: confirm the database answers a trivial query. An
            *> insecure production configuration is reported distinctly from
            *> an unreachable database so operators can tell them apart.
            MOVE SPACES TO WS-QUERY
            MOVE "SELECT 1" TO WS-QUERY
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
            CALL "SQL_EXECUTE" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:24) = "ERROR|DB_CONFIG_INSECURE"
                MOVE "ERROR|DB_CONFIG_INSECURE" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_DOWN" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "SUCCESS|PONG" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.
