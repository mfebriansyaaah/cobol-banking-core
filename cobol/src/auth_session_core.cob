       IDENTIFICATION DIVISION.
       PROGRAM-ID. auth_session_core.
      *> Auth session/token engine (maint-08, ADR-0010): the session and
      *> token paragraphs relocated from auth_core. The owner keeps MAIN-
      *> LOGIC, the auth guards (ALLOW-READ / ALLOW-MANAGE-SESSION run
      *> before the CALL), and the single transaction for
      *> REVOKE_ALL_SESSIONS, which this module joins (zero SQL_BEGIN/
      *> COMMIT/ROLLBACK of its own). Entry trim/validate mirrors the
      *> owner's TRIM-PARAMn / VALIDATE-ALL statement-for-statement under
      *> entry-scoped names. Compiled with DECIMAL-POINT IS COMMA like the
      *> owner (COMPUTE NUMVAL amount logic depends on it).
      *>
      *> Contract (internal CALL, pre-trimmed inputs like every module seam):
      *>   The caller passes the original action name through; the callee
      *>   dispatches the same literals it used in auth_core. Guards are
      *>   pre-checked by the caller (internal trust). The callee writes the
      *>   final outcome to LS-OUTPUT-BUFFER; the caller moves it verbatim
      *>   (REVOKE_ALL_SESSIONS commits or rolls back first).

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "auth_password_ws.cpy".

       LINKAGE SECTION.
       01  LS-CMD-ACTION           PIC X(30).
       01  LS-PARAM1               PIC X(100).
       01  LS-PARAM2               PIC X(100).
       01  LS-PARAM3               PIC X(100).
       01  LS-PARAM4               PIC X(100).
       01  LS-PARAM5               PIC X(100).
       01  LS-PARAM6               PIC X(100).
       01  LS-OUTPUT-BUFFER        PIC X(16384).

       PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2
           LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

       MAIN-LOGIC.
           PERFORM TRIM-PARAM1
           PERFORM TRIM-PARAM2
           PERFORM TRIM-PARAM3
           PERFORM TRIM-PARAM4
           PERFORM TRIM-PARAM5
           PERFORM TRIM-PARAM6
           PERFORM VALIDATE-ALL
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               GOBACK
           END-IF
           EVALUATE TRUE
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
               WHEN LS-CMD-ACTION(1:17) = "GET_TOKEN_VERSION"
                   PERFORM GET-TOKEN-VERSION-LOGIC
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "auth_entry.cpy".
        COPY "common_result.cpy".
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
        LIST-SESSIONS-LOGIC.
            *> p1 = email, p2 = actor. Self or admin. Active sessions only.
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
            SET STEP-OK TO TRUE
            *> (Transaction opened by the caller: ADR-0010 JOIN.)
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
            *> (Transaction committed by the caller.)
                MOVE "SUCCESS|SESSIONS_REVOKED" TO LS-OUTPUT-BUFFER
            ELSE
            *> (Transaction rolled back by the caller.)
                MOVE "ERROR|SESSIONS_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.
