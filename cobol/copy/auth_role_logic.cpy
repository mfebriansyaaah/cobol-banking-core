      *> Auth role / step-up logic (maint-15C): extracted verbatim from
      *> auth_core.cob. These paragraphs share auth_core's working storage
      *> (LS-OUTPUT-BUFFER, WS-ALLOWED, audit helpers) and its transaction
      *> ownership, so they stay in the same compiled module via COPY.

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
