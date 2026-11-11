        IDENTIFICATION DIVISION.
        PROGRAM-ID. identity_core.
      *> KYC identity verification records (PR-085): NIK results, OCR
      *> outcomes, gated APPLY transitions, status reads, and separate
      *> admin review decisions. Never auto-approves; OCR low-confidence
      *> lands in manual_reviews. Owner-only except review decisions
      *> (SUPER_ADMIN) and reads (self or admin).

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
        01  WS-ERR                  PIC X(40) VALUE SPACES.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
        01  WS-USER-ID              PIC X(20) VALUE SPACES.
        01  WS-KYC                  PIC X(20) VALUE SPACES.
        01  WS-HAS-NIK              PIC X(1) VALUE '0'.
        01  WS-HAS-PHONE            PIC X(1) VALUE '0'.
        01  WS-HAS-SCREENING        PIC X(1) VALUE '0'.
        01  WS-EMAIL-OK             PIC X(1) VALUE '0'.
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
                WHEN LS-CMD-ACTION(1:16) = "IDV_NIK_VALIDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NIK-VALIDATE
                WHEN LS-CMD-ACTION(1:18) = "IDV_KTP_OCR_RESULT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-OCR-RESULT
                WHEN LS-CMD-ACTION(1:9) = "IDV_APPLY"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-APPLY
                WHEN LS-CMD-ACTION(1:10) = "IDV_STATUS"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STATUS
                WHEN LS-CMD-ACTION(1:18) = "IDV_REVIEW_DECIDE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REVIEW-DECIDE
                WHEN LS-CMD-ACTION(1:15) = "IDV_REVIEW_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-REVIEW-LIST
                WHEN LS-CMD-ACTION(1:10) = "SCR_SCREEN"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SCR-SCREEN
                WHEN LS-CMD-ACTION(1:10) = "SCR_STATUS"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SCR-STATUS
                WHEN LS-CMD-ACTION(1:14) = "ACCOUNT_FREEZE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACCT-FREEZE
                WHEN LS-CMD-ACTION(1:16) = "ACCOUNT_UNFREEZE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACCT-UNFREEZE
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        VALIDATE-ALL.
            MOVE 0 TO WS-BAD
            MOVE LS-PARAM1 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM2 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM3 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM4 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM5 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM6 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT.
            EXIT PARAGRAPH.

        VALIDATE-INPUT.
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-QUOTE
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-DQUOTE
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-BSLASH
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-SEMI
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-TICK.
            EXIT PARAGRAPH.

        COPY "common_trim.cpy".

        CHECK-OWNER.
            *> p1 = email, p6 = actor. Owner-only (actor rides P6 so
            *> four data params fit in P2-P5).
            MOVE 0 TO WS-ALLOWED
            IF WS-P1-TRIMMED(1:WS-P1-LEN) = WS-P6-TRIMMED(1:WS-P6-LEN)
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        CHECK-ADMIN.
            *> p6 = actor (SUPER_ADMIN only).
            MOVE 0 TO WS-ALLOWED
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P6-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUPER_ADMIN"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        LOAD-USER.
            MOVE 0 TO WS-LOOKUP-BAD
            MOVE "SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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

        ACTION-NIK-VALIDATE.
            *> ADR-0006 Option A: p2 = nik_hash (HMAC), p3 = nik_last4,
            *> p4 = nikStructuralValid signal (VALID|INVALID) from adapters.
            *> COBOL decides: stores the verification and sets NIK_VALID.
            *> Raw NIK never reaches this module (privacy: hash + last4 only).
            PERFORM CHECK-OWNER
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P4-TRIMMED NOT = "VALID" AND WS-P4-TRIMMED NOT = "INVALID"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO identity_verifications (user_id, provider, method, status, result_code) VALUES (?, 'local', 'NIK_STRUCTURAL', ?, ?)" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            IF WS-P4-TRIMMED = "VALID"
                MOVE "VALID" TO WS-BIND-2
            ELSE
                MOVE "INVALID" TO WS-BIND-2
            END-IF.
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "UPDATE users SET nik_hash = ?, nik_last4 = ?, kyc_status = CASE WHEN ? = 'VALID' THEN 'NIK_VALID' ELSE kyc_status END WHERE id = ?" TO WS-PREP-SQL
                MOVE WS-P2-TRIMMED TO WS-BIND-1
                MOVE WS-P3-TRIMMED TO WS-BIND-2
                MOVE WS-P4-TRIMMED TO WS-BIND-3
                MOVE WS-USER-ID TO WS-BIND-4
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
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
                MOVE "SUCCESS|NIK_RECORDED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-OCR-RESULT.
            *> p1 = email, p2 = verdict (MANUAL_REVIEW|REJECTED),
            *> p3 = reason, p6 = actor (owner). APPROVED is never accepted
            *> here (that decision belongs to IDV_REVIEW_DECIDE); low
            *> confidence lands in manual_reviews OPEN.
            PERFORM CHECK-OWNER
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-TRIMMED NOT = "MANUAL_REVIEW" AND WS-P2-TRIMMED NOT = "REJECTED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO identity_verifications (user_id, provider, method, status, result_code) VALUES (?, 'local', 'KTP_OCR', ?, ?)" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            IF WS-P2-TRIMMED = "MANUAL_REVIEW"
                MOVE "MANUAL_REVIEW" TO WS-BIND-2
            ELSE
                MOVE "INVALID" TO WS-BIND-2
            END-IF.
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK AND WS-P2-TRIMMED = "MANUAL_REVIEW"
                MOVE "INSERT INTO manual_reviews (user_id, kind, status, reason) VALUES (?, 'KYC', 'OPEN', ?)" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                MOVE WS-P3-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK AND WS-P2-TRIMMED = "MANUAL_REVIEW"
                MOVE "UPDATE users SET kyc_status = 'MANUAL_REVIEW' WHERE id = ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|OCR_RECORDED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-APPLY.
            *> p1 = email, p6 = actor (owner). Idempotent transition to
            *> APPROVED when NIK valid + phone verified + email verified;
            *> otherwise PENDING with the missing piece named.
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
            MOVE "SELECT kyc_status, status FROM users WHERE id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-KYC WS-ERR
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-KYC WS-ERR
            END-UNSTRING.
            IF WS-KYC = "APPROVED"
                MOVE "SUCCESS|KYC_APPROVED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "N" TO WS-HAS-NIK
            MOVE "SELECT CAST(1 AS CHAR) FROM identity_verifications WHERE user_id = ? AND method = 'NIK_STRUCTURAL' AND status = 'VALID' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "ERROR|NO_DATA" AND WS-RESULT(1:5) NOT = "ERROR"
                MOVE "Y" TO WS-HAS-NIK
            END-IF.
            MOVE "N" TO WS-HAS-PHONE
            MOVE "SELECT CAST(1 AS CHAR) FROM phone_links WHERE user_id = ? AND verified_at IS NOT NULL AND revoked_at IS NULL LIMIT 1" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "ERROR|NO_DATA" AND WS-RESULT(1:5) NOT = "ERROR"
                MOVE "Y" TO WS-HAS-PHONE
            END-IF.
            MOVE "N" TO WS-EMAIL-OK
            MOVE "SELECT status FROM users WHERE id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "VERIFIED"
                MOVE "Y" TO WS-EMAIL-OK
            END-IF.
            IF WS-HAS-NIK = "N"
                MOVE "SUCCESS|KYC_PENDING|NIK" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-HAS-PHONE = "N"
                MOVE "SUCCESS|KYC_PENDING|PHONE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-EMAIL-OK = "N"
                MOVE "SUCCESS|KYC_PENDING|EMAIL" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            *> Sanctions gate (PR-090): the latest screening verdict must be
            *> CLEAR or a reviewed FALSE_POSITIVE; anything else (including no
            *> check at all) names SCREENING as the missing piece.
            MOVE "N" TO WS-HAS-SCREENING
            MOVE "SELECT result FROM screening_checks WHERE user_id = ? ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "CLEAR" OR WS-RESULT = "FALSE_POSITIVE"
                MOVE "Y" TO WS-HAS-SCREENING
            END-IF.
            IF WS-HAS-SCREENING = "N"
                MOVE "SUCCESS|KYC_PENDING|SCREENING" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE users SET kyc_status = 'APPROVED', kyc_verified_at = NOW() WHERE id = ?" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|KYC_APPROVED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STATUS.
            *> p1 = email, p6 = actor (self or admin). Reads KYC posture.
            MOVE "SELECT kyc_status FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE 0 TO WS-ALLOWED
            IF WS-P1-TRIMMED(1:WS-P1-LEN) = WS-P6-TRIMMED(1:WS-P6-LEN)
                MOVE 1 TO WS-ALLOWED
            ELSE
                MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-P6-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT = "SUPER_ADMIN"
                    MOVE 1 TO WS-ALLOWED
                END-IF
            END-IF.
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT kyc_status FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|KYC_STATUS|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-RESULT) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-REVIEW-DECIDE.
            *> p1 = review id, p2 = decision (APPROVED|REJECTED), p3 = reason,
            *> p6 = actor (SUPER_ADMIN). Closes the review; APPROVED on a KYC
            *> review flips kyc_status (still gated by APPLY afterwards).
            PERFORM CHECK-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-TRIMMED NOT = "APPROVED" AND WS-P2-TRIMMED NOT = "REJECTED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(user_id, '|', kind, '|', status) FROM manual_reviews WHERE id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
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
            MOVE SPACES TO WS-USER-ID WS-KYC WS-ERR
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-USER-ID WS-KYC WS-ERR
            END-UNSTRING.
            IF WS-ERR NOT = "OPEN"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-TRIMMED = "APPROVED" AND WS-KYC = "KYC"
                MOVE "SELECT result FROM screening_checks WHERE user_id = ? ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT NOT = "CLEAR" AND WS-RESULT NOT = "FALSE_POSITIVE"
                    MOVE "ERROR|SANCTION_CHECK_REQUIRED" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE manual_reviews SET status = ?, reviewer_email = ?, reason = COALESCE(NULLIF(?, ''), reason), reviewed_at = NOW() WHERE id = ? AND status = 'OPEN'" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P6-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK AND WS-KYC = "SCREENING" AND WS-P2-TRIMMED = "REJECTED"
                MOVE "UPDATE accounts SET status = 'FROZEN' WHERE user_id = ? AND status = 'ACTIVE' AND account_type IN ('SAVINGS','CHECKING','INVESTMENT')" TO WS-PREP-SQL
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
            IF STEP-OK AND WS-P2-TRIMMED = "APPROVED" AND WS-KYC = "KYC"
                MOVE "UPDATE users SET kyc_status = 'APPROVED', kyc_verified_at = NOW() WHERE id = ?" TO WS-PREP-SQL
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
                MOVE "SUCCESS|REVIEW_DECIDED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-REVIEW-LIST.
            *> p2 = kind filter (empty = all kinds), p6 = actor (SUPER_ADMIN).
            *> Lists OPEN manual reviews as id:user_id:kind:status rows joined
            *> by ';' (empty when the queue is clear). Read-only.
            PERFORM CHECK-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM2 = SPACES
                MOVE "SELECT GROUP_CONCAT(CONCAT(id, ':', user_id, ':', kind, ':', status) ORDER BY id SEPARATOR ';') FROM manual_reviews WHERE status = ?" TO WS-PREP-SQL
                MOVE "OPEN" TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
            ELSE
                MOVE "SELECT GROUP_CONCAT(CONCAT(id, ':', user_id, ':', kind, ':', status) ORDER BY id SEPARATOR ';') FROM manual_reviews WHERE status = ? AND kind = ?" TO WS-PREP-SQL
                MOVE "OPEN" TO WS-BIND-1
                MOVE WS-P2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
            END-IF.
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                IF WS-RESULT = "ERROR|NO_DATA"
                    MOVE "SUCCESS|REVIEWS|" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT = SPACES
                MOVE "SUCCESS|REVIEWS|" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REVIEWS|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-RESULT) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

        ACTION-SCR-SCREEN.
            *> ADR-0006 Option A: p2 = query_hash, p3 = providerResultSignal
            *> (CLEAR|POTENTIAL_MATCH|MANUAL_REVIEW), p4 = provider,
            *> p5 = provider_ref, p6 = actor. The adapter classifies provider
            *> output; COBOL decides: records owner-side, opens SCREENING
            *> review for non-CLEAR, reviewer verdicts need SUPER_ADMIN.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-TRIMMED NOT = "CLEAR"
               AND WS-P3-TRIMMED NOT = "POTENTIAL_MATCH"
               AND WS-P3-TRIMMED NOT = "CONFIRMED_MATCH"
               AND WS-P3-TRIMMED NOT = "FALSE_POSITIVE"
               AND WS-P3-TRIMMED NOT = "MANUAL_REVIEW"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-TRIMMED = "FALSE_POSITIVE"
               OR WS-P3-TRIMMED = "CONFIRMED_MATCH"
                PERFORM CHECK-ADMIN
                IF WS-ALLOWED NOT = 1
                    MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            ELSE
                PERFORM CHECK-OWNER
                IF WS-ALLOWED NOT = 1
                    MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO screening_checks (user_id, provider, query_hash, result, provider_ref, reviewed_by) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            IF WS-P4-TRIMMED = SPACES
                MOVE "opensanctions" TO WS-BIND-2
            ELSE
                MOVE WS-P4-TRIMMED TO WS-BIND-2
            END-IF.
            MOVE WS-P2-TRIMMED TO WS-BIND-3
            MOVE WS-P3-TRIMMED TO WS-BIND-4
            MOVE WS-P5-TRIMMED TO WS-BIND-5
            MOVE WS-P6-TRIMMED TO WS-BIND-6
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK AND WS-P3-TRIMMED NOT = "CLEAR"
               AND WS-P3-TRIMMED NOT = "FALSE_POSITIVE"
                MOVE "INSERT INTO manual_reviews (user_id, kind, status, reason) VALUES (?, 'SCREENING', 'OPEN', ?)" TO WS-PREP-SQL
                MOVE WS-USER-ID TO WS-BIND-1
                MOVE WS-P3-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
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
                MOVE "SUCCESS|SCREEN_RECORDED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SCR-STATUS.
            *> p1 = email, p6 = actor (self or admin). Auth first (a stranger
            *> learns nothing), then the latest screening verdict; never
            *> screened reads UNSCREENED.
            MOVE 0 TO WS-ALLOWED
            IF WS-P1-TRIMMED(1:WS-P1-LEN) = WS-P6-TRIMMED(1:WS-P6-LEN)
                MOVE 1 TO WS-ALLOWED
            ELSE
                MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-P6-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT = "SUPER_ADMIN"
                    MOVE 1 TO WS-ALLOWED
                END-IF
            END-IF.
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT result FROM screening_checks WHERE user_id = (SELECT id FROM users WHERE email = ? LIMIT 1) ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|SCREEN_STATUS|UNSCREENED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|SCREEN_STATUS|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-RESULT) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.

       ACTION-ACCT-FREEZE.
           *> Sanctions enforcement arm (SUPER_ADMIN only). Freezes a
           *> customer's wallet accounts: only ACTIVE customer wallets
           *> flip, bank-owned suspense books are never touched. The
           *> wallet transfer/deposit/loan paths all refuse non-ACTIVE
           *> accounts, so this closes the sanction-to-freeze chain.
           *> Atomic guard: AFFECTED_0 means nothing was freezable.
           PERFORM CHECK-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT id FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
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
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE accounts SET status = 'FROZEN' WHERE user_id = (SELECT id FROM users WHERE email = ? LIMIT 1) AND status = 'ACTIVE' AND account_type IN ('SAVINGS','CHECKING','INVESTMENT')" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               SET STEP-FAIL TO TRUE
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT s.id, a.id, 'ACCOUNT_FROZEN', 'ACCOUNT', CAST(s.id AS CHAR), NULLIF(?, ''), 'SUCCESS' FROM users s JOIN users a ON a.email = ? WHERE s.email = ?" TO WS-PREP-SQL
               MOVE WS-P2-TRIMMED TO WS-BIND-1
               MOVE WS-P6-TRIMMED TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
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
               MOVE "SUCCESS|ACCOUNT_FROZEN" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-ACCT-UNFREEZE.
           *> Releases a freeze (SUPER_ADMIN only, e.g. false positive
           *> cleared). Only FROZEN customer wallets flip back to ACTIVE.
           PERFORM CHECK-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT id FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
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
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE accounts SET status = 'ACTIVE' WHERE user_id = (SELECT id FROM users WHERE email = ? LIMIT 1) AND status = 'FROZEN' AND account_type IN ('SAVINGS','CHECKING','INVESTMENT')" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               SET STEP-FAIL TO TRUE
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT s.id, a.id, 'ACCOUNT_UNFROZEN', 'ACCOUNT', CAST(s.id AS CHAR), NULLIF(?, ''), 'SUCCESS' FROM users s JOIN users a ON a.email = ? WHERE s.email = ?" TO WS-PREP-SQL
               MOVE WS-P2-TRIMMED TO WS-BIND-1
               MOVE WS-P6-TRIMMED TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
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
               MOVE "SUCCESS|ACCOUNT_UNFROZEN" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.
