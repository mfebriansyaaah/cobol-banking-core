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
        01  WS-PARAM5-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM6-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-P5-LEN               PIC 9(3) VALUE 1.
        01  WS-P6-LEN               PIC 9(3) VALUE 1.
        01  WS-STATUS               PIC X(20) VALUE SPACES.
        01  WS-ROLE                 PIC X(12) VALUE SPACES.
        01  WS-USER-ID              PIC X(20) VALUE SPACES.
        01  WS-ACTOR-ID             PIC X(20) VALUE SPACES.
        01  WS-FAMILY               PIC X(50) VALUE SPACES.
        01  WS-REVOKED-FLAG         PIC X(1) VALUE "0".
        01  WS-SESSION-EMAIL        PIC X(100) VALUE SPACES.
        01  WS-FAMILY-OVER-LIMIT    PIC 9 VALUE 0.
        01  WS-LIMIT                PIC X(10) VALUE "50".
        01  WS-OFFSET               PIC X(10) VALUE "0".
        01  WS-TOTAL                PIC X(20) VALUE SPACES.
        01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
        01  WS-DENIED-TARGET        PIC X(100) VALUE SPACES.
        01  WS-ABS-TTL-STR          PIC X(20) VALUE SPACES.
        01  WS-MAX-ROT-STR          PIC X(20) VALUE SPACES.
        01  WS-CD-STR               PIC X(20) VALUE SPACES.
        01  WS-AGE-STR              PIC X(20) VALUE SPACES.
        01  WS-ROT-STR              PIC X(20) VALUE SPACES.
        01  WS-ABS-SECS             PIC 9(14) VALUE 0.
        01  WS-MAX-ROT              PIC 9(9) VALUE 0.
        01  WS-AGE-SECS             PIC 9(14) VALUE 0.
        01  WS-ROT-COUNT            PIC 9(9) VALUE 0.
        01  WS-ID-LEN               PIC 9(3) VALUE 1.
        01  WS-FAILS                PIC X(20) VALUE SPACES.
        01  WS-FAIL-COUNT           PIC 9(4) VALUE 0.
        01  WS-LOCKED               PIC X(1) VALUE "0".
        01  WS-CODE                 PIC X(7) VALUE SPACES.
        01  WS-PLAIN                PIC X(100) VALUE SPACES.
        01  WS-HASH                 PIC X(256) VALUE SPACES.
        01  WS-STORED               PIC X(256) VALUE SPACES.
        01  WS-VERIFY               PIC X(1) VALUE SPACES.
        01  WS-NEEDS-REHASH         PIC X(1) VALUE "0".
        01  WS-MFA-SECRET           PIC X(64) VALUE SPACES.
        01  WS-MFA-ON               PIC X(1) VALUE "0".
        01  WS-HLEN                 PIC 9(3) VALUE 1.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
        01  WS-I                    PIC 9(3).
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-ACTOR-RANK           PIC 9 VALUE 0.
        01  WS-TARGET-RANK          PIC 9 VALUE 0.
        01  WS-RANK                 PIC 9 VALUE 0.
        01  WS-ACTOR-ROLE           PIC X(12) VALUE SPACES.
        01  WS-TARGET-ROLE          PIC X(12) VALUE SPACES.
        01  WS-RANK-ROLE            PIC X(12) VALUE SPACES.
        01  WS-RLEN                 PIC 9(5) VALUE 0.
        01  WS-P1-ESC               PIC X(256) VALUE SPACES.
        01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
        01  WS-BIND-1               PIC X(256) VALUE SPACES.
        01  WS-BIND-2               PIC X(256) VALUE SPACES.
        01  WS-BIND-3               PIC X(256) VALUE SPACES.
        01  WS-BIND-4               PIC X(256) VALUE SPACES.
        01  WS-BIND-5               PIC X(256) VALUE SPACES.
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
        01  LS-PARAM5              PIC X(100).
        01  LS-PARAM6              PIC X(100).
        01  LS-OUTPUT-BUFFER      PIC X(16384).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

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
                WHEN LS-CMD-ACTION(1:13) = "GET_MFA_STATE"
                    PERFORM GET-MFA-STATE-LOGIC
                WHEN LS-CMD-ACTION(1:15) = "FORGOT_PASSWORD"
                    PERFORM FORGOT-PASSWORD-LOGIC
                WHEN LS-CMD-ACTION(1:14) = "RESET_PASSWORD"
                    PERFORM RESET-PASSWORD-LOGIC
                WHEN LS-CMD-ACTION(1:15) = "CHANGE_PASSWORD"
                    PERFORM CHANGE-PASSWORD-LOGIC
                WHEN LS-CMD-ACTION(1:19) = "RESEND_VERIFICATION"
                    PERFORM RESEND-VERIFICATION-LOGIC
                WHEN LS-CMD-ACTION(1:16) = "MFA_ENROLL_BEGIN"
                    PERFORM MFA-ENROLL-BEGIN-LOGIC
                WHEN LS-CMD-ACTION(1:18) = "MFA_ENROLL_CONFIRM"
                    PERFORM MFA-ENROLL-CONFIRM-LOGIC
                WHEN LS-CMD-ACTION(1:11) = "MFA_DISABLE"
                    PERFORM MFA-DISABLE-LOGIC
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
                WHEN LS-CMD-ACTION(1:13) = "ARCHIVE_AUDIT"
                    PERFORM ARCHIVE-AUDIT-LOGIC
                WHEN LS-CMD-ACTION(1:10) = "LIST_AUDIT"
                    PERFORM LIST-AUDIT-LOGIC
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
            MOVE "SELECT CAST(id AS CHAR), status, CAST(failed_logins AS CHAR), CASE WHEN locked_until IS NOT NULL AND locked_until > NOW() THEN '1' ELSE '0' END, CAST(mfa_enabled AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
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
            
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-STORED
            
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
            CALL "verify_password" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-STORED BY REFERENCE WS-VERIFY
            
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
                    MOVE "ERROR|MFA_REQUIRED" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE "SELECT mfa_secret FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE WS-RESULT TO WS-MFA-SECRET
                CALL "totp_verify" USING BY REFERENCE WS-MFA-SECRET BY REFERENCE WS-PARAM3-TRIMMED BY REFERENCE WS-VERIFY
                IF WS-VERIFY NOT = "1"
                    PERFORM RECORD-LOGIN-FAILURE
                    MOVE "ERROR|INVALID_MFA" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF
            
            *> 3b) A valid password clears the failure counter.
            MOVE "UPDATE users SET failed_logins = 0, locked_until = NULL WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            *> 3c) Transparently upgrade a legacy SHA256 hash, or a PBKDF2 hash
            *>     below the current cost target, to the current scheme.
            MOVE "0" TO WS-NEEDS-REHASH
            CALL "password_needs_rehash" USING BY REFERENCE WS-STORED BY REFERENCE WS-NEEDS-REHASH
            IF WS-NEEDS-REHASH = "1"
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
            *> Same per-account cooldown as signup resends (neutral reuse).
            MOVE SPACES TO WS-CD-STR
            CALL "env_or" USING BY REFERENCE "RESEND_COOLDOWN_SECONDS" BY REFERENCE "60" BY REFERENCE WS-CD-STR
            IF WS-CD-STR(1:1) >= "1" AND WS-CD-STR(1:1) <= "9"
                MOVE SPACES TO WS-PREP-SQL
                STRING "SELECT COUNT(*) FROM verification_logs WHERE email = ? AND purpose = 'PASSWORD_RESET' AND is_used = 0 AND created_at > DATE_SUB(NOW(), INTERVAL " WS-CD-STR DELIMITED BY SIZE " SECOND)" DELIMITED BY SIZE INTO WS-PREP-SQL
                END-STRING
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:1) >= "1" AND WS-RESULT(1:1) <= "9"
                    MOVE "SUCCESS|CODE_SENT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF
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
            MOVE "UPDATE users SET password_hash = ?, token_version = token_version + 1, failed_logins = 0, locked_until = NULL WHERE email = ?" TO WS-PREP-SQL
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
            *> Per-account resend cooldown: a fresh unused code issued inside
            *> the window is reused neutrally (no new code, no new email), so
            *> the endpoint cannot flood a mailbox or the table. Zero disables.
            MOVE SPACES TO WS-CD-STR
            CALL "env_or" USING BY REFERENCE "RESEND_COOLDOWN_SECONDS" BY REFERENCE "60" BY REFERENCE WS-CD-STR
            IF WS-CD-STR(1:1) >= "1" AND WS-CD-STR(1:1) <= "9"
                MOVE SPACES TO WS-PREP-SQL
                STRING "SELECT COUNT(*) FROM verification_logs WHERE email = ? AND purpose = 'SIGNUP' AND is_used = 0 AND created_at > DATE_SUB(NOW(), INTERVAL " WS-CD-STR DELIMITED BY SIZE " SECOND)" DELIMITED BY SIZE INTO WS-PREP-SQL
                END-STRING
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:1) >= "1" AND WS-RESULT(1:1) <= "9"
                    MOVE "SUCCESS|CODE_SENT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF
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

        RECORD-LOGIN-FAILURE.
            *> Arm the lockout and record a failed login. Used for a wrong
            *> password and a wrong MFA code. Skipped when already locked.
            IF WS-LOCKED = "0"
                MOVE "UPDATE users SET locked_until = CASE WHEN failed_logins + 1 >= 3 THEN DATE_ADD(NOW(), INTERVAL 15 MINUTE) ELSE locked_until END, failed_logins = failed_logins + 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, status) VALUES (?, 'AUTH_LOGIN_FAILED', 'USER', 'FAILED')" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            END-IF.
            EXIT PARAGRAPH.

        MFA-ENROLL-BEGIN-LOGIC.
            *> p1 = email, p2 = actor. Owner-only. Issues a pending secret.
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) NOT = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT CAST(mfa_enabled AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:1) = "1"
                MOVE "ERROR|MFA_ALREADY_ENABLED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE SPACES TO WS-MFA-SECRET
            CALL "generate_mfa_secret" USING BY REFERENCE WS-MFA-SECRET
            MOVE "UPDATE users SET mfa_secret = ? WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-MFA-SECRET TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|MFA_ENROLL_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|MFA_SECRET|" WS-MFA-SECRET(1:32) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        MFA-ENROLL-CONFIRM-LOGIC.
            *> p1 = email, p2 = code, p3 = actor. Owner-only; turns MFA on.
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) NOT = WS-PARAM3-TRIMMED(1:WS-P3-LEN)
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT mfa_secret FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE WS-RESULT TO WS-MFA-SECRET
            CALL "totp_verify" USING BY REFERENCE WS-MFA-SECRET BY REFERENCE WS-PARAM2-TRIMMED BY REFERENCE WS-VERIFY
            IF WS-VERIFY NOT = "1"
                MOVE "ERROR|INVALID_MFA" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE users SET mfa_enabled = 1 WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|MFA_ENROLL_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|MFA_ENABLED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        MFA-DISABLE-LOGIC.
            *> p1 = email, p2 = code, p3 = actor. Owner-only; turns MFA off.
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) NOT = WS-PARAM3-TRIMMED(1:WS-P3-LEN)
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT mfa_secret FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT = SPACES OR WS-RESULT(1:4) = "NULL"
                MOVE "ERROR|MFA_NOT_ENABLED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE WS-RESULT TO WS-MFA-SECRET
            CALL "totp_verify" USING BY REFERENCE WS-MFA-SECRET BY REFERENCE WS-PARAM2-TRIMMED BY REFERENCE WS-VERIFY
            IF WS-VERIFY NOT = "1"
                MOVE "ERROR|INVALID_MFA" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "UPDATE users SET mfa_enabled = 0, mfa_secret = NULL WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|MFA_DISABLE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|MFA_DISABLED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        GET-MFA-STATE-LOGIC.
            *> p1 = email. Returns the role and MFA flag so the gateway can decide
            *> whether an admin still needs to enrol MFA (limited "enroll" token).
            MOVE "SELECT CONCAT(role, '|', CAST(mfa_enabled AS CHAR)) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
            ELSE
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|" WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        VERIFY-REAUTH-LOGIC.
            *> p1 = email, p2 = password, p3 = mfaCode (opt). Re-authenticates the
            *> bearer's own account for a step-up (no tokens, no lockout change).
            MOVE "SELECT status, CAST(mfa_enabled AS CHAR), role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY
            CALL "SQL_EXECUTE"
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-STORED
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-PLAIN
            CALL "verify_password" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-STORED BY REFERENCE WS-VERIFY
            IF WS-VERIFY NOT = "1"
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Admin accounts must have MFA enabled to step up: a SUPER_ADMIN or
            *> MANAGER without MFA cannot perform a privileged action.
            IF (WS-ROLE = "SUPER_ADMIN" OR WS-ROLE = "MANAGER") AND WS-MFA-ON NOT = "1"
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
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE WS-RESULT TO WS-MFA-SECRET
                CALL "totp_verify" USING BY REFERENCE WS-MFA-SECRET BY REFERENCE WS-PARAM3-TRIMMED BY REFERENCE WS-VERIFY
                IF WS-VERIFY NOT = "1"
                    MOVE "ERROR|INVALID_MFA" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            MOVE "SUCCESS|REAUTH_OK" TO LS-OUTPUT-BUFFER.
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

        GUARD-LAST-ADMIN-ROLE.
            *> p1 = target email, p2 = new role. Sets WS-ALLOWED = 1 when the
            *> change still leaves an active (VERIFIED) SUPER_ADMIN, so the last
            *> administrator can never be demoted away.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM2-TRIMMED(1:WS-P2-LEN) = "SUPER_ADMIN"
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM users WHERE role = 'SUPER_ADMIN' AND status = 'VERIFIED' AND email <> ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "0" AND WS-RESULT(1:5) NOT = "ERROR"
                MOVE 1 TO WS-ALLOWED
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
            
            *> Never demote the last active SUPER_ADMIN (would lock everyone out).
            PERFORM GUARD-LAST-ADMIN-ROLE
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|LAST_ADMIN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Capture the actor's id so the audit row names who changed the role.
            MOVE "SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-ACTOR-ID
            
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
                MOVE WS-ACTOR-ID TO WS-BIND-1
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
            MOVE "DELETE FROM revoked_access_tokens WHERE expires_at < NOW()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE SPACES TO WS-PREP-SQL
            STRING "INSERT INTO refresh_sessions (jti, family, email, expires_at, user_agent, ip) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL "
                   WS-PARAM3-TRIMMED(1:WS-P3-LEN) " DAY), ?, ?)" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM5-TRIMMED TO WS-BIND-4
            MOVE WS-PARAM6-TRIMMED TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|SESSION_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|SESSION_REVOKED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        CONSUME-SESSION-LOGIC.
            *> p1 = jti. Atomically consume the refresh session: only the first
            *> caller wins. A later call on an already-revoked jti is reuse and
            *> kills the whole family plus every access token.
            MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE jti = ? AND revoked = 0 AND expires_at > NOW()" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "UPDATE users SET token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-SESSION-EMAIL TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) SELECT id, 'SESSION_REUSED', 'USER', id, 'FAILED' FROM users WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-SESSION-EMAIL TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE "SELECT CAST(TIMESTAMPDIFF(SECOND, created_at, NOW()) AS CHAR), CAST(rotations AS CHAR) FROM refresh_families WHERE family = ?" TO WS-PREP-SQL
            MOVE WS-FAMILY TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                *> Fail closed: without family state we cannot allow the rotation.
                MOVE 1 TO WS-FAMILY-OVER-LIMIT
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-AGE-STR WS-ROT-STR
            END-UNSTRING
            COMPUTE WS-AGE-SECS = FUNCTION NUMVAL(WS-AGE-STR)
            COMPUTE WS-ROT-COUNT = FUNCTION NUMVAL(WS-ROT-STR)
            MOVE SPACES TO WS-ABS-TTL-STR
            CALL "env_or" USING BY REFERENCE "REFRESH_ABSOLUTE_TTL_DAYS" BY REFERENCE "30" BY REFERENCE WS-ABS-TTL-STR
            MOVE SPACES TO WS-MAX-ROT-STR
            CALL "env_or" USING BY REFERENCE "REFRESH_MAX_ROTATIONS" BY REFERENCE "100" BY REFERENCE WS-MAX-ROT-STR
            COMPUTE WS-ABS-SECS = FUNCTION NUMVAL(WS-ABS-TTL-STR) * 86400
            COMPUTE WS-MAX-ROT = FUNCTION NUMVAL(WS-MAX-ROT-STR)
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) SELECT id, 'SESSION_FAMILY_EXPIRED', 'USER', id, 'FAILED' FROM users WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-SESSION-EMAIL TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            ELSE
                MOVE "UPDATE refresh_families SET rotations = rotations + 1 WHERE family = ?" TO WS-PREP-SQL
                MOVE WS-FAMILY TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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

        TRIM-RESULT-LEN.
            *> Compute WS-RLEN = length of WS-RESULT without trailing spaces.
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-I FROM 16384 BY -1 UNTIL WS-I < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-RLEN
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
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF
            IF WS-ALLOWED NOT = 1
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            *> Records a refused authorization attempt for the actor named by
            *> WS-DENIED-ACTOR; unknown actors produce no row. Best-effort.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'USER', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
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
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
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
            CALL "SQL_BEGIN"
            MOVE "UPDATE users SET token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT t.id, a.id, 'SESSIONS_REVOKED', 'USER', t.id, 'SUCCESS' FROM users t JOIN users a ON t.email = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|SESSIONS_REVOKED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|SESSIONS_REVOKE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        LIST-AUDIT-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = action filter, p3 = email filter,
            *> p4 = limit, p5 = offset. Read-only view of the audit trail.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "50" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM4 NOT = SPACES
                MOVE WS-PARAM4-TRIMMED(1:WS-P4-LEN) TO WS-LIMIT
            END-IF
            IF LS-PARAM5 NOT = SPACES
                MOVE WS-PARAM5-TRIMMED(1:WS-P5-LEN) TO WS-OFFSET
            END-IF
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM audit_trail a JOIN users uo ON a.user_id = uo.id WHERE a.action = COALESCE(NULLIF(?, ''), a.action) AND uo.email = COALESCE(NULLIF(?, ''), uo.email)" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-TOTAL
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CONCAT(a.audit_id, ':', DATE_FORMAT(a.created_at, '%Y-%m-%dT%H:%i:%s'), ':', a.action, ':', uo.email, ':', COALESCE(ua.email, ''), ':', COALESCE(a.entity_type, ''), ':', COALESCE(a.entity_id, ''), ':', a.status, ':', "
                   "REPLACE(REPLACE(COALESCE(a.detail, ''), '|', '/'), ';', ',')) FROM audit_trail a JOIN users uo ON a.user_id = uo.id LEFT JOIN users ua ON a.actor_id = ua.id WHERE a.action = COALESCE(NULLIF(?, ''), a.action) AND uo.email = COALESCE(NULLIF(?, ''), uo.email) ORDER BY a.audit_id DESC LIMIT ? OFFSET ?"
                   DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-LIMIT TO WS-BIND-3
            MOVE WS-OFFSET TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|AUDIT|" WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|AUDIT|" WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ARCHIVE-AUDIT-LOGIC.
            *> p1 = retention days, p2 = actor (SUPER_ADMIN). Move older audit
            *> rows to the immutable archive, keeping the live table bounded.
            *> Retention must be a positive number of days: days=0 would move the
            *> entire live trail in one call, so it is refused here (the gateway
            *> pattern already restricts it to digits).
            IF WS-PARAM1-TRIMMED(1:1) < "1" OR WS-PARAM1-TRIMMED(1:1) > "9"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
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
            STRING "INSERT IGNORE INTO audit_trail_archive (audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, created_at) SELECT audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, created_at FROM audit_trail WHERE created_at < DATE_SUB(NOW(), INTERVAL " 
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
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT a.id, a.id, 'ARCHIVE_AUDIT', 'AUDIT', ?, 'SUCCESS' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
