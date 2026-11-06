        IDENTIFICATION DIVISION.
        PROGRAM-ID. auth_review_core.

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
                WHEN LS-CMD-ACTION(1:18) = "OPEN_ACCESS_REVIEW"
                    PERFORM OPEN-ACCESS-REVIEW-LOGIC
                WHEN LS-CMD-ACTION(1:19) = "LIST_ACCESS_REVIEWS"
                    PERFORM LIST-ACCESS-REVIEWS-LOGIC
                WHEN LS-CMD-ACTION(1:17) = "GET_ACCESS_REVIEW"
                    PERFORM GET-ACCESS-REVIEW-LOGIC
                WHEN LS-CMD-ACTION(1:18) = "DECIDE_ACCESS_ITEM"
                    PERFORM DECIDE-ACCESS-ITEM-LOGIC
                WHEN LS-CMD-ACTION(1:19) = "CLOSE_ACCESS_REVIEW"
                    PERFORM CLOSE-ACCESS-REVIEW-LOGIC
                WHEN LS-CMD-ACTION(1:16) = "CHECK_PERMISSION"
                    PERFORM CHECK-PERMISSION-LOGIC
                WHEN LS-CMD-ACTION(1:16) = "LIST_PERMISSIONS"
                    PERFORM LIST-PERMISSIONS-LOGIC
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
            MOVE "SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL

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

        OPEN-ACCESS-REVIEW-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = period start, p3 = period end.
            *> Opening a review snapshots every privileged account so a
            *> reviewer can re-attest it. Only one review may be open at a
            *> time, so there is exactly one live attestation to act on.
            PERFORM ALLOW-SUPER-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM2-TRIMMED TO WS-CHECK
            MOVE WS-P2-LEN TO WS-DATE-LEN
            MOVE 0 TO WS-BAD
            PERFORM VALIDATE-DATE
            IF WS-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM3-TRIMMED TO WS-CHECK
            MOVE WS-P3-LEN TO WS-DATE-LEN
            MOVE 0 TO WS-BAD
            PERFORM VALIDATE-DATE
            IF WS-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM2-TRIMMED(1:10) > WS-PARAM3-TRIMMED(1:10)
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT COUNT(*) FROM access_reviews WHERE state = 'OPEN'" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "0"
                MOVE "ERROR|REVIEW_ALREADY_OPEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO access_reviews (period_start, period_end, state, opened_by) VALUES (?, ?, 'OPEN', ?)" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-AR-ID
            *> Snapshot the privileged accounts as they are right now: role,
            *> status, MFA state, and last sign-in. The item is evidence of
            *> this moment, so it does not follow later role changes.
            MOVE "INSERT INTO access_review_items (review_id, email, role, account_status, mfa_enabled, last_login_at) SELECT ?, u.email, u.role, u.status, u.mfa_enabled, u.last_login_at FROM users u WHERE u.role IN ('MANAGER','SUPER_ADMIN')" TO WS-PREP-SQL
            MOVE WS-AR-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM access_review_items WHERE review_id = ?" TO WS-PREP-SQL
            MOVE WS-AR-ID TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-AR-COUNT
            MOVE SPACES TO WS-AR-DETAIL
            STRING "period=" DELIMITED BY SPACE WS-PARAM2-TRIMMED(1:10) DELIMITED BY SPACE ".." DELIMITED BY SPACE WS-PARAM3-TRIMMED(1:10) DELIMITED BY SPACE ";items=" DELIMITED BY SPACE WS-AR-COUNT DELIMITED BY SPACE INTO WS-AR-DETAIL
            END-STRING
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'ACCESS_REVIEW_OPENED', 'ACCESS_REVIEW', ?, ?, 'SUCCESS' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE WS-AR-ID TO WS-BIND-1
            MOVE WS-AR-DETAIL TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REVIEW_OPENED|" DELIMITED BY SPACE WS-AR-ID DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-AR-COUNT DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
            END-STRING
            EXIT PARAGRAPH.

        LIST-ACCESS-REVIEWS-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = state filter, p3 = limit,
            *> p4 = offset. Paged reviews, newest first.
            PERFORM ALLOW-SUPER-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM2-TRIMMED NOT = SPACES AND WS-PARAM2-TRIMMED NOT = "OPEN" AND WS-PARAM2-TRIMMED NOT = "CLOSED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "50" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF WS-PARAM3-TRIMMED NOT = SPACES
                MOVE WS-PARAM3-TRIMMED TO WS-CHECK
                MOVE WS-P3-LEN TO WS-CHECK-LEN
                PERFORM VALIDATE-DIGITS
                IF WS-DIGITS-BAD NOT = 0 OR WS-P3-LEN > 6
                    MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE WS-PARAM3-TRIMMED(1:10) TO WS-LIMIT
            END-IF.
            IF WS-PARAM4-TRIMMED NOT = SPACES
                MOVE WS-PARAM4-TRIMMED TO WS-CHECK
                MOVE WS-P4-LEN TO WS-CHECK-LEN
                PERFORM VALIDATE-DIGITS
                IF WS-DIGITS-BAD NOT = 0 OR WS-P4-LEN > 6
                    MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE WS-PARAM4-TRIMMED(1:10) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM access_reviews WHERE state = COALESCE(NULLIF(?, ''), state)" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CONCAT(r.review_id, ':', r.period_start, ':', r.period_end, ':', r.state, ':', r.opened_by, ':', (SELECT COUNT(*) FROM access_review_items i WHERE i.review_id = r.review_id), ':', COALESCE(r.closed_by, ''), ':', COALESCE(DATE_FORMAT(r.closed_at, '%Y-%m-%d'), '')) FROM access_reviews r WHERE r.state = COALESCE(NULLIF(?, ''), r.state) ORDER BY r.review_id DESC LIMIT ? OFFSET ?" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-LIMIT TO WS-BIND-2
            MOVE WS-OFFSET TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|REVIEWS|" DELIMITED BY SPACE WS-TOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|REVIEWS|" DELIMITED BY SPACE WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        GET-ACCESS-REVIEW-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = review id. The review and its
            *> items as they stand right now. Item rows are separated by ';'
            *> and their fields by ':', so no value may carry either.
            PERFORM ALLOW-SUPER-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM2-TRIMMED TO WS-CHECK
            MOVE WS-P2-LEN TO WS-CHECK-LEN
            PERFORM VALIDATE-DIGITS
            IF WS-DIGITS-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT review_id, period_start, period_end, state, opened_by, COALESCE(closed_by, ''), COALESCE(DATE_FORMAT(closed_at, '%Y-%m-%d'), '') FROM access_reviews WHERE review_id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
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
            MOVE SPACES TO WS-AR-ID
            MOVE SPACES TO WS-AR-DATE1
            MOVE SPACES TO WS-AR-DATE2
            MOVE SPACES TO WS-AR-STATE
            MOVE SPACES TO WS-AR-OPENBY
            MOVE SPACES TO WS-AR-CLOSEDBY
            MOVE SPACES TO WS-AR-CLOSEDAT
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-AR-ID WS-AR-DATE1 WS-AR-DATE2 WS-AR-STATE WS-AR-OPENBY WS-AR-CLOSEDBY WS-AR-CLOSEDAT
            END-UNSTRING
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CONCAT(item_id, ':', email, ':', role, ':', account_status, ':', CAST(mfa_enabled AS CHAR), ':', decision, ':', COALESCE(reviewer_email, ''), ':', COALESCE(DATE_FORMAT(last_login_at, '%Y-%m-%d'), ''), ':', COALESCE(note, '')) FROM access_review_items WHERE review_id = ? ORDER BY item_id" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO WS-AR-ITEMS
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE 1 TO WS-RLEN
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE WS-RESULT(1:WS-RLEN) TO WS-AR-ITEMS
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REVIEW|" DELIMITED BY SPACE WS-AR-ID DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-AR-DATE1 DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-AR-DATE2 DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-AR-STATE DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-AR-OPENBY DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-AR-CLOSEDBY DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-AR-CLOSEDAT DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-AR-ITEMS(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
            END-STRING
            EXIT PARAGRAPH.

        DECIDE-ACCESS-ITEM-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = item id, p3 = decision
            *> (ATTESTED|REVOKED), p4 = note (optional). The reviewer is
            *> never the subject of the item.
            PERFORM ALLOW-SUPER-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM2-TRIMMED TO WS-CHECK
            MOVE WS-P2-LEN TO WS-CHECK-LEN
            PERFORM VALIDATE-DIGITS
            IF WS-DIGITS-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-PARAM3-TRIMMED NOT = "ATTESTED" AND WS-PARAM3-TRIMMED NOT = "REVOKED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(i.email, ':', i.decision, ':', r.state) FROM access_review_items i JOIN access_reviews r ON r.review_id = i.review_id WHERE i.item_id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
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
            MOVE SPACES TO WS-AR-EMAIL
            MOVE SPACES TO WS-AR-DECISION
            MOVE SPACES TO WS-AR-STATE
            UNSTRING WS-RESULT DELIMITED BY ":"
                INTO WS-AR-EMAIL WS-AR-DECISION WS-AR-STATE
            END-UNSTRING
            MOVE 0 TO WS-AR-ELEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-AR-ELEN > 0
                IF WS-AR-EMAIL(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-AR-ELEN
                END-IF
            END-PERFORM
            IF WS-AR-STATE NOT = "OPEN"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-AR-DECISION NOT = "PENDING"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            *> The reviewer is never the subject: a privileged account may not
            *> attest its own access.
            IF WS-AR-ELEN = WS-P1-LEN AND WS-AR-EMAIL(1:WS-AR-ELEN) = WS-PARAM1-TRIMMED(1:WS-P1-LEN)
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-AR-EMAIL TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            *> The note travels in a row whose fields are separated by ':' and
            *> whose rows are separated by ';', so neither may appear in it.
            MOVE WS-PARAM4-TRIMMED TO WS-AR-NOTE
            INSPECT WS-AR-NOTE REPLACING ALL ":" BY "_" ALL ";" BY "_"
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE access_review_items SET decision = ?, reviewer_email = ?, note = ?, decided_at = NOW() WHERE item_id = ? AND decision = 'PENDING'" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            MOVE WS-AR-NOTE TO WS-BIND-3
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-AR-DETAIL
            STRING "decision=" DELIMITED BY SPACE WS-PARAM3-TRIMMED DELIMITED BY SPACE ";subject=" DELIMITED BY SPACE WS-AR-EMAIL DELIMITED BY SPACE INTO WS-AR-DETAIL
            END-STRING
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'ACCESS_REVIEW_DECIDED', 'ACCESS_REVIEW', ?, ?, 'SUCCESS' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-AR-DETAIL TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|ITEM_DECIDED|" DELIMITED BY SPACE WS-PARAM2-TRIMMED DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-PARAM3-TRIMMED DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
            END-STRING
            EXIT PARAGRAPH.

        CLOSE-ACCESS-REVIEW-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = review id. Every item must be
            *> decided, and a revoked subject must have actually lost the
            *> privileged access; the removal itself is performed through the
            *> existing privileged actions.
            PERFORM ALLOW-SUPER-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM2-TRIMMED TO WS-CHECK
            MOVE WS-P2-LEN TO WS-CHECK-LEN
            PERFORM VALIDATE-DIGITS
            IF WS-DIGITS-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT state FROM access_reviews WHERE review_id = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
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
            IF WS-RESULT NOT = "OPEN"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM access_review_items WHERE review_id = ? AND decision = 'PENDING'" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "0"
                MOVE "ERROR|REVIEW_INCOMPLETE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            *> A REVOKED decision is a decision to remove the access, not the
            *> removal itself: the review cannot close while the subject
            *> still holds a privileged role in a verified state.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM access_review_items i JOIN users u ON u.email = i.email WHERE i.review_id = ? AND i.decision = 'REVOKED' AND u.role IN ('MANAGER','SUPER_ADMIN') AND u.status = 'VERIFIED'" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT NOT = "0"
                MOVE "ERROR|REVOCATION_PENDING" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE access_reviews SET state = 'CLOSED', closed_by = ?, closed_at = NOW() WHERE review_id = ? AND state = 'OPEN'" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-AR-DETAIL
            STRING "closed_by=" DELIMITED BY SPACE WS-PARAM1-TRIMMED DELIMITED BY SPACE INTO WS-AR-DETAIL
            END-STRING
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'ACCESS_REVIEW_CLOSED', 'ACCESS_REVIEW', ?, ?, 'SUCCESS' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-AR-DETAIL TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REVIEW_CLOSED|" DELIMITED BY SPACE WS-PARAM2-TRIMMED DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
            END-STRING
            EXIT PARAGRAPH.

        CHECK-PERMISSION-LOGIC.
            *> p1 = email, p2 = permission. Answers whether the account
            *> holds the permission. The gateway renders the answer and the
            *> ALLOW-PERMISSION helper enforces it in the migrated gates.
            *> Unknown permissions are refused; unknown accounts are refused.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT 1 FROM permissions WHERE BINARY name = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM role_permissions rp JOIN users u ON u.role = rp.role WHERE u.email = ? AND BINARY rp.permission = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT NOT = "0"
                MOVE "SUCCESS|PERMISSION_OK" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "ERROR|PERMISSION_DENIED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        LIST-PERMISSIONS-LOGIC.
            *> p1 = email. Lists every permission the account holds, for the
            *> login and profile responses. Permission names carry no row or
            *> field separators, so the rows read back unambiguous.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT permission FROM role_permissions rp JOIN users u ON u.role = rp.role WHERE u.email = ? ORDER BY permission" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|PERMISSIONS" DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                STRING "SUCCESS|PERMISSIONS|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
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

        ALLOW-SUPER-ADMIN.
            *> The actor (p1) must hold SUPER_ADMIN. A refused attempt is
            *> audited; the caller then reports FORBIDDEN.
            MOVE 0 TO WS-ALLOWED
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUPER_ADMIN"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            IF WS-ALLOWED NOT = 1
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-DATE.
            *> WS-CHECK holds a candidate YYYY-MM-DD and WS-DATE-LEN its
            *> length. Sets WS-BAD when the shape is wrong.
            IF WS-DATE-LEN NOT = 10
                MOVE 1 TO WS-BAD
            ELSE
                IF WS-CHECK(5:1) NOT = "-" OR WS-CHECK(8:1) NOT = "-"
                    MOVE 1 TO WS-BAD
                ELSE
                    IF WS-CHECK(1:4) IS NOT NUMERIC
                       OR WS-CHECK(6:2) IS NOT NUMERIC
                       OR WS-CHECK(9:2) IS NOT NUMERIC
                       OR WS-CHECK(6:2) < "01" OR WS-CHECK(6:2) > "12"
                       OR WS-CHECK(9:2) < "01" OR WS-CHECK(9:2) > "31"
                        MOVE 1 TO WS-BAD
                    END-IF
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            *> Records a refused authorization attempt for the actor named by
            *> WS-DENIED-ACTOR; unknown actors produce no row. Best-effort.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'USER', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
            EXIT PARAGRAPH.