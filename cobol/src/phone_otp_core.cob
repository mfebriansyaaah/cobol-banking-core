        IDENTIFICATION DIVISION.
        PROGRAM-ID. phone_otp_core.
      *> Phone OTP binding + challenges (PR-082b/085): link tokens (10-min
      *> TTL), hashed-code challenges with purpose/status machine, resend
      *> with rate limit, 5-attempt burn. Owner-only throughout. Codes are
      *> hashed at rest (SHA-256); the ISSUE response carries the code for
      *> the server to send via provider — the HTTP mapper strips it, and
      *> tests read the hash row. Delivery itself lives in middleware.

        ENVIRONMENT DIVISION.
        CONFIGURATION SECTION.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01  WS-RESULT               PIC X(16384) VALUE SPACES.
        01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
        01  WS-BIND-1               PIC X(256) VALUE SPACES.
        01  WS-BIND-2               PIC X(256) VALUE SPACES.
        01  WS-BIND-3               PIC X(256) VALUE SPACES.
        01  WS-BIND-4               PIC X(256) VALUE SPACES.
        01  WS-BIND-5               PIC X(256) VALUE SPACES.
        01  WS-BIND-6               PIC X(256) VALUE SPACES.
        01  WS-P1-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P2-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P3-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P4-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P5-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P6-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-P5-LEN               PIC 9(3) VALUE 1.
        01  WS-P6-LEN               PIC 9(3) VALUE 1.
        01  WS-TRIM-IN              PIC X(100) VALUE SPACES.
        01  WS-TRIM-OUT             PIC X(100) VALUE SPACES.
        01  WS-TRIM-LEN             PIC 9(3) VALUE 1.
        01  WS-I                    PIC 9(3) VALUE 1.
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-LOOKUP-BAD           PIC 9 VALUE 0.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
        01  WS-CODE                 PIC X(32) VALUE SPACES.
        01  WS-CODE2                PIC X(32) VALUE SPACES.
        01  WS-TOKEN                PIC X(64) VALUE SPACES.
        01  WS-USER-ID              PIC X(20) VALUE SPACES.
        01  WS-HASH-SRC             PIC X(200) VALUE SPACES.
        01  WS-HASH-OUT             PIC X(64) VALUE SPACES.
        01  WS-NEW-ID               PIC X(20) VALUE SPACES.
        01  F-QUOTE                 PIC X VALUE "'".
        01  F-DQUOTE                PIC X VALUE '"'.
        01  F-BSLASH                PIC X VALUE "\".
        01  F-TICK                  PIC X VALUE "`".
        01  F-SEMI                  PIC X VALUE ";".

        LINKAGE SECTION.
        01  LS-CMD-ACTION        PIC X(30).
        01  LS-PARAM1            PIC X(100).
        01  LS-PARAM2            PIC X(100).
        01  LS-PARAM3            PIC X(100).
        01  LS-PARAM4            PIC X(100).
        01  LS-PARAM5            PIC X(100).
        01  LS-PARAM6            PIC X(100).
        01  LS-OUTPUT-BUFFER     PIC X(16384).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2
            LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

        MAIN-LOGIC.
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:14) = "OTP_LINK_BEGIN"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LINK-BEGIN
                WHEN LS-CMD-ACTION(1:16) = "OTP_LINK_CONFIRM"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LINK-CONFIRM
                WHEN LS-CMD-ACTION(1:9) = "OTP_ISSUE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ISSUE
                WHEN LS-CMD-ACTION(1:10) = "OTP_VERIFY"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-VERIFY
                WHEN LS-CMD-ACTION(1:10) = "OTP_RESEND"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RESEND
                WHEN LS-CMD-ACTION(1:8) = "OTP_CHAT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHAT
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        COPY "common_validate_semi.cpy".
        COPY "common_sql.cpy".


        COPY "common_trim.cpy".

        CHECK-OWNER.
            *> p1 = email, p4 = actor. Owner-only.
            MOVE 0 TO WS-ALLOWED
            IF WS-P1-TRIMMED(1:WS-P1-LEN) = WS-P4-TRIMMED(1:WS-P4-LEN)
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        LOAD-USER.
            MOVE 0 TO WS-LOOKUP-BAD
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ID
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE 1 TO WS-LOOKUP-BAD
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE 2 TO WS-LOOKUP-BAD
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-USER-ID
            EXIT PARAGRAPH.

        HASH-CODE.
            *> WS-CODE holds plaintext; WS-HASH-OUT receives lowercase hex.
            *> Digits are case-neutral so the lowering helper is safe here.
            *> Only the 6 code chars hash: sprintf leaves a NUL after them
            *> that must not enter the digest (VERIFY pads with spaces).
            MOVE SPACES TO WS-HASH-SRC WS-HASH-OUT
            MOVE WS-CODE(1:6) TO WS-HASH-SRC
            CALL "sha256_hex_lower" USING BY REFERENCE WS-HASH-SRC BY REFERENCE WS-HASH-OUT BY VALUE 64 END-CALL
            EXIT PARAGRAPH.

        ACTION-LINK-BEGIN.
            *> p1 = email, p2 = phone_hash, p4 = actor (owner). Issues a
            *> single-use link token (10-minute TTL); re-link refreshes.
            PERFORM CHECK-OWNER
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            CALL "generate_random_code" USING BY REFERENCE WS-CODE END-CALL
            CALL "generate_random_code" USING BY REFERENCE WS-CODE2 END-CALL
            MOVE SPACES TO WS-TOKEN
            STRING WS-CODE(1:6) WS-CODE2(1:6) DELIMITED BY SIZE INTO WS-TOKEN
            END-STRING
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO phone_links (user_id, phone_hash, linked_at, link_token, token_expires_at, verified_at) VALUES (?, ?, NOW(), ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE), NULL) ON DUPLICATE KEY UPDATE phone_hash = VALUES(phone_hash), link_token = VALUES(link_token), token_expires_at = VALUES(token_expires_at), verified_at = NULL, revoked_at = NULL" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-TOKEN TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|LINK_BEGIN|" DELIMITED BY SIZE
                       FUNCTION TRIM(WS-TOKEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LINK-CONFIRM.
            *> p1 = email, p2 = token, p3 = chat_id, p4 = actor (owner).
            *> Binds the chat; tokens are single-use and expire in 10 min.
            PERFORM CHECK-OWNER
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CAST(id AS CHAR) FROM phone_links WHERE user_id = ? AND link_token = ? AND token_expires_at > NOW() LIMIT 1" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_CODE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE phone_links SET chat_id = ?, verified_at = NOW(), link_token = NULL, token_expires_at = NULL WHERE user_id = ?" TO WS-PREP-SQL
            MOVE WS-P3-TRIMMED TO WS-BIND-1
            MOVE WS-USER-ID TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|LINK_CONFIRMED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ISSUE-CORE.
            *> Shared by ISSUE and RESEND: WS-USER-ID set, WS-P2 holds the
            *> channel, WS-P3 the purpose. Inserts a PENDING challenge and
            *> returns its id in WS-NEW-ID with the plaintext in WS-CODE.
            CALL "generate_random_code" USING BY REFERENCE WS-CODE END-CALL
            PERFORM HASH-CODE
            MOVE SPACES TO WS-HASH-SRC
            MOVE WS-P1-TRIMMED TO WS-HASH-SRC
            CALL "sha256_hex_lower" USING BY REFERENCE WS-HASH-SRC BY REFERENCE WS-TOKEN BY VALUE 64 END-CALL
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO otp_challenges (user_id, channel, destination_hash, code_hash, purpose, status, expires_at) VALUES (?, ?, ?, ?, ?, 'PENDING', DATE_ADD(NOW(), INTERVAL 10 MINUTE))" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-TOKEN TO WS-BIND-3
            MOVE WS-HASH-OUT TO WS-BIND-4
            MOVE WS-P3-TRIMMED TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                PERFORM LAST-INSERT-ID
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                ELSE
                    MOVE WS-RESULT(1:20) TO WS-NEW-ID
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ISSUE.
            *> p1 = email, p2 = channel (EMAIL|PHONE), p3 = purpose,
            *> p4 = actor (owner). At most 3 live challenges per purpose
            *> per 10 minutes; the id+code go back for provider delivery
            *> (the HTTP mapper strips the code).
            PERFORM CHECK-OWNER
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-TRIMMED NOT = "EMAIL" AND WS-P2-TRIMMED NOT = "PHONE"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT COUNT(*) FROM otp_challenges WHERE user_id = ? AND purpose = ? AND status = 'PENDING' AND created_at > DATE_SUB(NOW(), INTERVAL 10 MINUTE)" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "ERROR|NO_DATA" AND FUNCTION NUMVAL(WS-RESULT) >= 3
                MOVE "ERROR|RATE_LIMITED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM ISSUE-CORE
            IF STEP-FAIL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|OTP_ISSUED|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                   "|" DELIMITED BY SIZE
                   WS-CODE(1:6) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-RESEND.
            *> p1 = email, p3 = purpose, p4 = actor (owner). Expires live
            *> challenges, then issues fresh under the same rate limit.
            PERFORM CHECK-OWNER
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT COUNT(*) FROM otp_challenges WHERE user_id = ? AND purpose = ? AND status = 'PENDING' AND created_at > DATE_SUB(NOW(), INTERVAL 10 MINUTE)" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "ERROR|NO_DATA" AND FUNCTION NUMVAL(WS-RESULT) >= 3
                MOVE "ERROR|RATE_LIMITED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE otp_challenges SET status = 'EXPIRED' WHERE user_id = ? AND purpose = ? AND status = 'PENDING'" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT channel FROM otp_challenges WHERE user_id = ? ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "PHONE" TO WS-P2-TRIMMED
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE WS-RESULT(1:20) TO WS-P2-TRIMMED
            END-IF.
            PERFORM ISSUE-CORE
            IF STEP-FAIL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|OTP_ISSUED|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                   "|" DELIMITED BY SIZE
                   WS-CODE(1:6) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-VERIFY.
            *> p1 = email, p2 = code, p3 = purpose, p4 = actor (owner).
            *> Compares hashes; 5 failures lock the challenge. Success marks
            *> it VERIFIED and stamps phone verification for PHONE purposes.
            PERFORM CHECK-OWNER
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-CODE
            MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-CODE
            PERFORM HASH-CODE
            MOVE "SELECT CAST(id AS CHAR), CAST(attempts AS CHAR) FROM otp_challenges WHERE user_id = ? AND purpose = ? AND status = 'PENDING' AND expires_at > NOW() ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_CODE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-TOKEN WS-NEW-ID
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-TOKEN WS-NEW-ID
            END-UNSTRING.
            IF WS-TOKEN = SPACES
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CAST(1 AS CHAR) FROM otp_challenges WHERE id = ? AND code_hash = ? AND status = 'PENDING' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-TOKEN TO WS-BIND-1
            MOVE WS-HASH-OUT TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "UPDATE otp_challenges SET attempts = attempts + 1, status = CASE WHEN attempts + 1 >= 5 THEN 'LOCKED' ELSE status END WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-TOKEN TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                MOVE "ERROR|INVALID_CODE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE otp_challenges SET status = 'VERIFIED' WHERE id = ?" TO WS-PREP-SQL
            MOVE WS-TOKEN TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK AND WS-P3-TRIMMED(1:5) = "PHONE"
                MOVE "UPDATE phone_links SET verified_at = NOW() WHERE user_id = ?" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK AND WS-P3-TRIMMED(1:5) = "PHONE"
                MOVE "UPDATE users SET phone_verified_at = NOW() WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|OTP_VERIFIED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHAT.
            *> p1 = email, p4 = actor (owner). Read-only lookup of the
            *> verified telegram chat_id and stored phone hash for OTP
            *> delivery. Both are consumed server-side by the gateway and
            *> never travel via HTTP request parameters.
            PERFORM CHECK-OWNER
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(chat_id, ':', phone_hash) FROM phone_links WHERE user_id = ? AND verified_at IS NOT NULL AND revoked_at IS NULL LIMIT 1" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-TOKEN WS-HASH-OUT
            UNSTRING WS-RESULT DELIMITED BY ":"
                INTO WS-TOKEN WS-HASH-OUT
            END-UNSTRING.
            IF WS-TOKEN = SPACES OR WS-HASH-OUT = SPACES
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|CHAT|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-TOKEN) DELIMITED BY SIZE
                   "|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-HASH-OUT) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.
