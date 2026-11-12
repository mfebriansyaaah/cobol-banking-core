        IDENTIFICATION DIVISION.
        PROGRAM-ID. auth_ops_core.

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
                WHEN LS-CMD-ACTION(1:13) = "ARCHIVE_AUDIT"
                    PERFORM ARCHIVE-AUDIT-LOGIC
                WHEN LS-CMD-ACTION(1:10) = "LIST_AUDIT"
                    PERFORM LIST-AUDIT-LOGIC
                WHEN LS-CMD-ACTION(1:12) = "OUTBOX_CLAIM"
                    PERFORM OUTBOX-CLAIM-LOGIC
                WHEN LS-CMD-ACTION(1:11) = "OUTBOX_MARK"
                    PERFORM OUTBOX-MARK-LOGIC
                WHEN LS-CMD-ACTION(1:12) = "LIST_OUTBOX"
                    PERFORM LIST-OUTBOX-LOGIC
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

        VALIDATE-DIGITS.
            *> WS-CHECK (WS-CHECK-LEN chars) must be all digits.
            MOVE 0 TO WS-DIGITS-BAD
            IF WS-CHECK-LEN = 0
                MOVE 1 TO WS-DIGITS-BAD
            END-IF
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-CHECK-LEN
                IF WS-CHECK(WS-I:1) < "0" OR WS-CHECK(WS-I:1) > "9"
                    MOVE 1 TO WS-DIGITS-BAD
                END-IF
            END-PERFORM.
            EXIT PARAGRAPH.

        OUTBOX-CLAIM-LOGIC.
            *> p1 = max rows, p2 = worker id. Reaps stale SENDING claims,
            *> then claims due rows (PENDING or retry-due FAILED within the
            *> attempt budget) for this worker. Local-only infrastructure
            *> call: not exposed over HTTP, so no role gate applies.
            MOVE WS-PARAM1-TRIMMED TO WS-CHECK
            MOVE WS-P1-LEN TO WS-CHECK-LEN
            PERFORM VALIDATE-DIGITS
            IF WS-DIGITS-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM2-TRIMMED = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-CD-STR
            CALL "env_or" USING BY REFERENCE "OUTBOX_MAX_ATTEMPTS" BY REFERENCE "5" BY REFERENCE WS-CD-STR END-CALL
            COMPUTE WS-OUTBOX-MAX = FUNCTION NUMVAL(WS-CD-STR) END-COMPUTE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE notification_outbox SET state = 'PENDING', claimed_by = NULL, claimed_at = NULL WHERE state = 'SENDING' AND claimed_at < DATE_SUB(NOW(), INTERVAL 30 MINUTE)" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-PREP-SQL
            STRING "UPDATE notification_outbox SET state = 'SENDING', attempts = attempts + 1, claimed_by = ?, claimed_at = NOW() WHERE id IN (SELECT id FROM (SELECT id FROM notification_outbox WHERE state IN ('PENDING','FAILED') AND (next_attempt_at IS NULL OR next_attempt_at <= NOW()) AND attempts < ? ORDER BY created_at LIMIT ?) t)" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-OUTBOX-MAX TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(id, ':', recipient, ':', purpose, ':', code, ':', detail) FROM notification_outbox WHERE claimed_by = ? AND state = 'SENDING' ORDER BY id" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|CLAIMED" TO LS-OUTPUT-BUFFER
            ELSE
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|CLAIMED|" WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        OUTBOX-MARK-LOGIC.
            *> p1 = id, p2 = SENT|FAILED, p3 = error, p4 = worker. Records the
            *> delivery outcome; failures past the attempt budget go to the
            *> dead-letter state for operator review. Local-only call.
            MOVE WS-PARAM1-TRIMMED TO WS-CHECK
            MOVE WS-P1-LEN TO WS-CHECK-LEN
            PERFORM VALIDATE-DIGITS
            IF WS-DIGITS-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM2-TRIMMED NOT = "SENT" AND WS-PARAM2-TRIMMED NOT = "FAILED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM4-TRIMMED = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT state, claimed_by FROM notification_outbox WHERE id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-REQ-STATUS WS-REQ-MAKER
            END-UNSTRING
            MOVE 0 TO WS-REQ-MLEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-REQ-MLEN > 0
                IF WS-REQ-MAKER(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-REQ-MLEN
                END-IF
            END-PERFORM
            IF WS-REQ-STATUS NOT = "SENDING"
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P4-LEN NOT = WS-REQ-MLEN
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM4-TRIMMED(1:WS-P4-LEN) NOT = WS-REQ-MAKER(1:WS-REQ-MLEN)
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-CD-STR
            CALL "env_or" USING BY REFERENCE "OUTBOX_MAX_ATTEMPTS" BY REFERENCE "5" BY REFERENCE WS-CD-STR END-CALL
            COMPUTE WS-OUTBOX-MAX = FUNCTION NUMVAL(WS-CD-STR) END-COMPUTE
            IF WS-PARAM2-TRIMMED = "SENT"
                MOVE "UPDATE notification_outbox SET state = 'SENT', sent_at = NOW(), claimed_by = NULL, claimed_at = NULL WHERE id = ? AND state = 'SENDING'" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE "SUCCESS|MARKED|SENT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE notification_outbox SET state = 'DEAD', last_error = LEFT(?, 200), claimed_by = NULL, claimed_at = NULL WHERE id = ? AND state = 'SENDING' AND claimed_by = ? AND attempts >= ?" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM4-TRIMMED TO WS-BIND-3
            MOVE WS-OUTBOX-MAX TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT = "SUCCESS|AFFECTED_1"
                MOVE "SUCCESS|MARKED|DEAD" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE notification_outbox SET state = 'FAILED', next_attempt_at = NOW() + INTERVAL (1 << LEAST(attempts, 5)) MINUTE, last_error = LEFT(?, 200), claimed_by = NULL, claimed_at = NULL WHERE id = ? AND state = 'SENDING' AND claimed_by = ?" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM4-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR" OR WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|MARKED|" "FAILED" DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        LIST-OUTBOX-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = status filter, p3 = limit,
            *> p4 = offset. Read-only view; rows never carry codes.
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM2-TRIMMED NOT = SPACES AND WS-PARAM2-TRIMMED NOT = "PENDING" AND WS-PARAM2-TRIMMED NOT = "SENDING" AND WS-PARAM2-TRIMMED NOT = "SENT" AND WS-PARAM2-TRIMMED NOT = "FAILED" AND WS-PARAM2-TRIMMED NOT = "DEAD"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "50" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF WS-PARAM3-TRIMMED NOT = SPACES
                MOVE WS-PARAM3-TRIMMED(1:10) TO WS-LIMIT
            END-IF.
            IF WS-PARAM4-TRIMMED NOT = SPACES
                MOVE WS-PARAM4-TRIMMED(1:10) TO WS-OFFSET
            END-IF.
            MOVE WS-LIMIT TO WS-CHECK
            MOVE 0 TO WS-CHECK-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-CHECK-LEN > 0
                IF WS-CHECK(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-CHECK-LEN
                END-IF
            END-PERFORM
            PERFORM VALIDATE-DIGITS
            IF WS-DIGITS-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-OFFSET TO WS-CHECK
            MOVE 0 TO WS-CHECK-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-CHECK-LEN > 0
                IF WS-CHECK(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-CHECK-LEN
                END-IF
            END-PERFORM
            PERFORM VALIDATE-DIGITS
            IF WS-DIGITS-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM notification_outbox WHERE state = COALESCE(NULLIF(?, ''), state)" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CONCAT(id, ':', recipient, ':', purpose, ':', state, ':', attempts, ':', DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s')) FROM notification_outbox WHERE state = COALESCE(NULLIF(?, ''), state) ORDER BY id DESC LIMIT ? OFFSET ?"
                   DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-LIMIT TO WS-BIND-2
            MOVE WS-OFFSET TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|OUTBOX|" WS-TOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|OUTBOX|" WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
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

        ALLOW-PERMISSION.
            *> WS-PERM-REQ names the permission WS-PERM-ACTOR must hold. A
            *> refused attempt is audited; the caller then reports FORBIDDEN.
            MOVE 0 TO WS-ALLOWED
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM role_permissions rp JOIN users u ON u.role = rp.role WHERE u.email = ? AND BINARY rp.permission = ?" TO WS-PREP-SQL
            MOVE WS-PERM-ACTOR TO WS-BIND-1
            MOVE WS-PERM-REQ TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "0"
                MOVE 1 TO WS-ALLOWED
            END-IF
            IF WS-ALLOWED NOT = 1
                MOVE WS-PERM-ACTOR TO WS-DENIED-ACTOR
                MOVE WS-PERM-ACTOR TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            *> Records a refused authorization attempt for the actor named by
            *> WS-DENIED-ACTOR; unknown actors produce no row. Best-effort.
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            PERFORM RECORD-AUTHZ-DENIED
            EXIT PARAGRAPH.
        LIST-AUDIT-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = action filter, p3 = email filter,
            *> p4 = limit, p5 = offset. Read-only view of the audit trail.
            MOVE "AUDIT_READ" TO WS-PERM-REQ
            MOVE WS-PARAM1-TRIMMED TO WS-PERM-ACTOR
            PERFORM ALLOW-PERMISSION
            IF WS-ALLOWED NOT = 1
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
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CONCAT(a.audit_id, ':', DATE_FORMAT(a.created_at, '%Y-%m-%dT%H:%i:%s'), ':', a.action, ':', uo.email, ':', COALESCE(ua.email, ''), ':', COALESCE(a.entity_type, ''), ':', COALESCE(a.entity_id, ''), ':', a.status, ':', "
                   "REPLACE(REPLACE(COALESCE(a.detail, ''), '|', '/'), ';', ',')) FROM audit_trail a JOIN users uo ON a.user_id = uo.id LEFT JOIN users ua ON a.actor_id = ua.id WHERE a.action = COALESCE(NULLIF(?, ''), a.action) AND uo.email = COALESCE(NULLIF(?, ''), uo.email) ORDER BY a.audit_id DESC LIMIT ? OFFSET ?"
                   DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-LIMIT TO WS-BIND-3
            MOVE WS-OFFSET TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
            MOVE "AUDIT_ARCHIVE" TO WS-PERM-REQ
            MOVE WS-PARAM2-TRIMMED TO WS-PERM-ACTOR
            PERFORM ALLOW-PERMISSION
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE SPACES TO WS-QUERY
            STRING "INSERT IGNORE INTO audit_trail_archive (audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, journal_id, created_at) SELECT audit_id, user_id, actor_id, action, entity_type, entity_id, detail, status, journal_id, created_at FROM audit_trail WHERE created_at < DATE_SUB(NOW(), INTERVAL " 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) " DAY)" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
            CALL "SQL_EXECUTE" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|AUDIT_ARCHIVE_FAILED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-QUERY
            STRING "DELETE FROM audit_trail WHERE created_at < DATE_SUB(NOW(), INTERVAL " 
                   WS-PARAM1-TRIMMED(1:WS-P1-LEN) " DAY)" DELIMITED BY SIZE INTO WS-QUERY
            END-STRING
            CALL "SET_QUERY" USING BY REFERENCE WS-QUERY END-CALL
            CALL "SQL_EXECUTE" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|AUDIT_ARCHIVE_FAILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT a.id, a.id, 'ARCHIVE_AUDIT', 'AUDIT', ?, 'SUCCESS' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|ARCHIVED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.
