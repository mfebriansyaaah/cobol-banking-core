        IDENTIFICATION DIVISION.
        PROGRAM-ID. auth_core.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        COPY "auth_password_ws.cpy".
        01  WS-CALL-ACTION          PIC X(30) VALUE SPACES.
        01  WS-CALL-P1              PIC X(100) VALUE SPACES.
        01  WS-CALL-P2              PIC X(100) VALUE SPACES.
        01  WS-CALL-P3              PIC X(100) VALUE SPACES.
        01  WS-CALL-P4              PIC X(100) VALUE SPACES.
        01  WS-CALL-P5              PIC X(100) VALUE SPACES.
        01  WS-CALL-P6              PIC X(100) VALUE SPACES.
        01  WS-CALL-OUT             PIC X(16384) VALUE SPACES.
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
                    MOVE "STORE_SESSION" TO WS-CALL-ACTION
                    MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
                    MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
                    MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
                    MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
                    MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
                    MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
                    MOVE SPACES TO WS-CALL-OUT
                    CALL "auth_session_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                        WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                    END-CALL
                    MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                WHEN LS-CMD-ACTION(1:14) = "REVOKE_SESSION"
                    MOVE "REVOKE_SESSION" TO WS-CALL-ACTION
                    MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
                    MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
                    MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
                    MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
                    MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
                    MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
                    MOVE SPACES TO WS-CALL-OUT
                    CALL "auth_session_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                        WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                    END-CALL
                    MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                WHEN LS-CMD-ACTION(1:15) = "CONSUME_SESSION"
                    MOVE "CONSUME_SESSION" TO WS-CALL-ACTION
                    MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
                    MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
                    MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
                    MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
                    MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
                    MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
                    MOVE SPACES TO WS-CALL-OUT
                    CALL "auth_session_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                        WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                    END-CALL
                    MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                WHEN LS-CMD-ACTION(1:11) = "CHECK_TOKEN"
                    MOVE "CHECK_TOKEN" TO WS-CALL-ACTION
                    MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
                    MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
                    MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
                    MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
                    MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
                    MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
                    MOVE SPACES TO WS-CALL-OUT
                    CALL "auth_session_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                        WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                    END-CALL
                    MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                WHEN LS-CMD-ACTION(1:19) = "REVOKE_ACCESS_TOKEN"
                    MOVE "REVOKE_ACCESS_TOKEN" TO WS-CALL-ACTION
                    MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
                    MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
                    MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
                    MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
                    MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
                    MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
                    MOVE SPACES TO WS-CALL-OUT
                    CALL "auth_session_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                        WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                    END-CALL
                    MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                WHEN LS-CMD-ACTION(1:13) = "LIST_SESSIONS"
                    PERFORM ALLOW-READ
                    IF WS-ALLOWED NOT = 1
                        MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                    ELSE
                        MOVE "LIST_SESSIONS" TO WS-CALL-ACTION
                        MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
                        MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
                        MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
                        MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
                        MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
                        MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
                        MOVE SPACES TO WS-CALL-OUT
                        CALL "auth_session_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                            WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                        END-CALL
                        MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                    END-IF
                WHEN LS-CMD-ACTION(1:19) = "REVOKE_USER_SESSION"
                    PERFORM ALLOW-MANAGE-SESSION
                    IF WS-ALLOWED NOT = 1
                        MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                    ELSE
                        MOVE "REVOKE_USER_SESSION" TO WS-CALL-ACTION
                        MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
                        MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
                        MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
                        MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
                        MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
                        MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
                        MOVE SPACES TO WS-CALL-OUT
                        CALL "auth_session_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                            WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                        END-CALL
                        MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                    END-IF
                WHEN LS-CMD-ACTION(1:20) = "REVOKE_ALL_SESSIONS"
                    PERFORM ALLOW-MANAGE-SESSION
                    IF WS-ALLOWED NOT = 1
                        MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                    ELSE
                        CALL "SQL_BEGIN" END-CALL
                        MOVE "REVOKE_ALL_SESSIONS" TO WS-CALL-ACTION
                        MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
                        MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
                        MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
                        MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
                        MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
                        MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
                        MOVE SPACES TO WS-CALL-OUT
                        CALL "auth_session_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                            WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                        END-CALL
                        MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                        IF WS-CALL-OUT(1:5) = "ERROR"
                            CALL "SQL_ROLLBACK" END-CALL
                        ELSE
                            CALL "SQL_COMMIT" END-CALL
                        END-IF
                        MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                    END-IF
                WHEN LS-CMD-ACTION(1:20) = "REVOKE_OTHER_DEVICES"
                    PERFORM REVOKE-OTHER-DEVICES-LOGIC
                WHEN LS-CMD-ACTION(1:12) = "LOGIN_NOTICE"
                    PERFORM LOGIN-NOTICE-LOGIC
                WHEN LS-CMD-ACTION(1:16) = "STEP_UP_REQUIRED"
                    PERFORM STEP-UP-REQUIRED-LOGIC
                WHEN LS-CMD-ACTION(1:17) = "GET_TOKEN_VERSION"
                    MOVE "GET_TOKEN_VERSION" TO WS-CALL-ACTION
                    MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
                    MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
                    MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
                    MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
                    MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
                    MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
                    MOVE SPACES TO WS-CALL-OUT
                    CALL "auth_session_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                        WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
                    END-CALL
                    MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
                WHEN LS-CMD-ACTION(1:4) = "PING"
                    PERFORM PING-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        COPY "auth_password_helpers.cpy".
        COPY "auth_password_logic.cpy".
        COPY "auth_entry.cpy".
        COPY "common_outbox.cpy".
        COPY "common_result.cpy".
        COPY "auth_last_admin.cpy".
        COPY "auth_role_logic.cpy".

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
            *>    (PBKDF2, with a legacy SHA256 fallback). Prepared: the email
            *>    travels as a bind, never concatenated.
            MOVE "SELECT password_hash FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
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
                MOVE "UPDATE users SET password_hash = ? WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-HASH TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
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
            *> Password complexity: at least 8 characters, measured on the
            *> raw password (the old dynamic check measured the escaped form,
            *> so a quote/backslash counted extra; prepared binds have no
            *> escapes to count).
            MOVE "SELECT 1 WHERE CHAR_LENGTH(?) >= 8" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
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
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
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
                MOVE "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES (?, ?, 'SIGNUP', DATE_ADD(NOW(), INTERVAL 24 HOUR))" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-CODE TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
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
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (?, 'SIGNUP', 'USER', ?, 'SUCCESS')" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                MOVE WS-USER-ID TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
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
            MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (?, 'VERIFY_EMAIL', 'USER', ?, 'FAILED')" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            MOVE WS-USER-ID TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
            EXIT PARAGRAPH.

        VERIFY-LOGIC.
            *> Code must match, be unused, unexpired, for a SIGNUP.
            MOVE "SELECT 1 FROM verification_logs WHERE email = ? AND code = ? AND purpose = 'SIGNUP' AND is_used = 0 AND expires_at > NOW() LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
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

        PING-LOGIC.
            *> Deep health: confirm the database answers a trivial query. An
            *> insecure production configuration is reported distinctly from
            *> an unreachable database so operators can tell them apart.
            *> Prepared like every other statement; no parameters to bind.
            MOVE "SELECT 1" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
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
