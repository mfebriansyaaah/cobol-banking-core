        IDENTIFICATION DIVISION.
        PROGRAM-ID. user_core.

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
        01  WS-EMAIL                PIC X(100) VALUE SPACES.
        01  WS-NAME                 PIC X(100) VALUE SPACES.
        01  WS-BAL                  PIC X(30) VALUE SPACES.
        01  WS-ACCOUNTS             PIC X(300) VALUE SPACES.
        01  WS-STATUS               PIC X(10) VALUE SPACES.
        01  WS-ROLE                 PIC X(12) VALUE SPACES.
        01  WS-DOB                  PIC X(10) VALUE SPACES.
        01  WS-CREATED              PIC X(19) VALUE SPACES.
        01  WS-TOTAL                PIC X(20) VALUE SPACES.
        01  WS-LIMIT                PIC X(10) VALUE SPACES.
        01  WS-OFFSET               PIC X(10) VALUE SPACES.
        01  WS-ELEN                 PIC 9(3) VALUE 1.
        01  WS-NLEN                 PIC 9(3) VALUE 1.
        01  WS-BLEN                 PIC 9(3) VALUE 1.
        01  WS-ALEN                 PIC 9(3) VALUE 1.
        01  WS-RLEN                 PIC 9(5) VALUE 1.
        01  WS-CODE                 PIC X(7) VALUE SPACES.
        01  WS-PLAIN                PIC X(100) VALUE SPACES.
        01  WS-STORED               PIC X(256) VALUE SPACES.
        01  WS-VERIFY               PIC X(1) VALUE SPACES.
        01  WS-USER-ID              PIC X(20) VALUE SPACES.
        01  WS-ID-LEN               PIC 9(3) VALUE 1.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
        01  WS-I                    PIC 9(5).
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-AT-COUNT             PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-ACTOR-RANK           PIC 9 VALUE 0.
        01  WS-TARGET-RANK          PIC 9 VALUE 0.
        01  WS-RANK                 PIC 9 VALUE 0.
        01  WS-ACTOR-ROLE           PIC X(12) VALUE SPACES.
        01  WS-TARGET-ROLE          PIC X(12) VALUE SPACES.
        01  WS-LAST-ADMIN           PIC 9 VALUE 0.
        01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
        01  WS-BIND-1               PIC X(256) VALUE SPACES.
        01  WS-BIND-2               PIC X(256) VALUE SPACES.
        01  WS-BIND-3               PIC X(256) VALUE SPACES.
        01  WS-BIND-4               PIC X(256) VALUE SPACES.
        01  F-QUOTE                 PIC X VALUE "'".
        01  F-DQUOTE                PIC X VALUE '"'.
        01  F-BSLASH                PIC X VALUE "\".
        01  F-SEMI                  PIC X VALUE ";".
        01  F-TICK                  PIC X VALUE "`".

        LINKAGE SECTION.
        01  LS-CMD-ACTION          PIC X(30).
        01  LS-PARAM1              PIC X(100).
        01  LS-PARAM2              PIC X(100).
        01  LS-PARAM3              PIC X(100).
        01  LS-PARAM4              PIC X(100).
        01  LS-OUTPUT-BUFFER      PIC X(16384).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-OUTPUT-BUFFER.

        MAIN-LOGIC.
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:8) = "GET_USER"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM ACTION-GET-USER
                WHEN LS-CMD-ACTION(1:10) = "LIST_USERS"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM ACTION-LIST-USERS
                WHEN LS-CMD-ACTION(1:13) = "GET_DASHBOARD"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM ACTION-DASHBOARD
                WHEN LS-CMD-ACTION(1:16) = "REQ_EMAIL_CHANGE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM ACTION-REQ-EMAIL-CHANGE
                WHEN LS-CMD-ACTION(1:20) = "CONFIRM_EMAIL_CHANGE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM ACTION-CONFIRM-EMAIL-CHANGE
                WHEN LS-CMD-ACTION(1:14) = "UPDATE_PROFILE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM ACTION-UPDATE-PROFILE
                WHEN LS-CMD-ACTION(1:18) = "DEACTIVATE_ACCOUNT"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM ACTION-DEACTIVATE-ACCOUNT
                WHEN LS-CMD-ACTION(1:15) = "SET_USER_STATUS"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM ACTION-SET-USER-STATUS
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        VALIDATE-ALL.
            *> No SQL metacharacters may reach a query string.
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
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-QUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-DQUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-BSLASH
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-SEMI
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-TICK.
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

        VALIDATE-EMAIL.
            *> WS-CHECK holds a candidate email; sets WS-BAD when malformed.
            MOVE 0 TO WS-AT-COUNT
            INSPECT WS-CHECK TALLYING WS-AT-COUNT FOR ALL "@"
            IF WS-AT-COUNT NOT = 1
                MOVE 1 TO WS-BAD
            END-IF
            IF WS-CHECK(1:1) = SPACE
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-DOB.
            *> WS-CHECK holds a candidate YYYY-MM-DD; sets WS-BAD when malformed.
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
            END-IF.
            EXIT PARAGRAPH.

        TRIM-OUTPUT-VALUES.
            MOVE 0 TO WS-ELEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-ELEN > 0
                IF WS-EMAIL(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-ELEN
                END-IF
            END-PERFORM
            MOVE 0 TO WS-NLEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-NLEN > 0
                IF WS-NAME(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-NLEN
                END-IF
            END-PERFORM
            MOVE 0 TO WS-BLEN
            PERFORM VARYING WS-I FROM 30 BY -1 UNTIL WS-I < 1 OR WS-BLEN > 0
                IF WS-BAL(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-BLEN
                END-IF
            END-PERFORM
            MOVE 0 TO WS-ALEN
            PERFORM VARYING WS-I FROM 300 BY -1 UNTIL WS-I < 1 OR WS-ALEN > 0
                IF WS-ACCOUNTS(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-ALEN
                END-IF
            END-PERFORM
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-I FROM 16384 BY -1 UNTIL WS-I < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-RLEN
                END-IF
            END-PERFORM
            IF WS-ELEN = 0
                MOVE 1 TO WS-ELEN
            END-IF
            IF WS-NLEN = 0
                MOVE 1 TO WS-NLEN
            END-IF
            IF WS-BLEN = 0
                MOVE 1 TO WS-BLEN
            END-IF
            IF WS-ALEN = 0
                MOVE 1 TO WS-ALEN
            END-IF
            IF WS-RLEN = 0
                MOVE 1 TO WS-RLEN
            END-IF.

        ALLOW-READ.
            *> Sets WS-ALLOWED when the actor (p2) owns the target (p1) or is an admin.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        ALLOW-ADMIN.
            *> Sets WS-ALLOWED when the actor (p3) is a SUPER_ADMIN or MANAGER.
            MOVE 0 TO WS-ALLOWED
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        ALLOW-RANK-ABOVE.
            *> p1 = target email, p3 = actor email. Allowed when the actor's role
            *> is not lower than the target's (USER < MANAGER < SUPER_ADMIN), so a
            *> lower-ranked admin (e.g. MANAGER) can never suspend/close/verify a
            *> higher-ranked account (e.g. SUPER_ADMIN). Equal ranks are allowed.
            MOVE 0 TO WS-ALLOWED
            MOVE 0 TO WS-ACTOR-RANK
            MOVE 0 TO WS-TARGET-RANK
            MOVE "SELECT CONCAT(a.role, '|', t.role) FROM users a JOIN users t ON a.email = ? AND t.email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-ACTOR-ROLE WS-TARGET-ROLE
            END-UNSTRING
            MOVE WS-ACTOR-ROLE TO WS-ROLE
            PERFORM RANK-OF-ROLE
            MOVE WS-RANK TO WS-ACTOR-RANK
            MOVE WS-TARGET-ROLE TO WS-ROLE
            PERFORM RANK-OF-ROLE
            MOVE WS-RANK TO WS-TARGET-RANK
            IF WS-ACTOR-RANK >= WS-TARGET-RANK
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        RANK-OF-ROLE.
            *> Map WS-ROLE to WS-RANK: USER=1, MANAGER=2, SUPER_ADMIN=3.
            MOVE 1 TO WS-RANK
            IF WS-ROLE = "SUPER_ADMIN"
                MOVE 3 TO WS-RANK
            ELSE
                IF WS-ROLE = "MANAGER"
                    MOVE 2 TO WS-RANK
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        LAST-ACTIVE-SUPER.
            *> p1 = email. Sets WS-LAST-ADMIN = 1 when the account is a
            *> SUPER_ADMIN and no other active (VERIFIED) SUPER_ADMIN exists,
            *> so it must not be closed or deactivated.
            MOVE 0 TO WS-LAST-ADMIN
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM users WHERE role = 'SUPER_ADMIN' AND status = 'VERIFIED' AND email <> ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "0"
                MOVE 1 TO WS-LAST-ADMIN
            END-IF.
            EXIT PARAGRAPH.

        ACTION-GET-USER.
            PERFORM ALLOW-READ
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> The user's public record: id, email, name, status, role, created.
            MOVE "SELECT CAST(id AS CHAR), email, full_name, status, role, DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s') FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-USER-ID WS-EMAIL WS-NAME WS-STATUS WS-ROLE WS-CREATED
            END-UNSTRING
            PERFORM TRIM-OUTPUT-VALUES
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|USER|" DELIMITED BY SIZE
                   WS-USER-ID DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-EMAIL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-NAME(1:WS-NLEN) DELIMITED BY SIZE "|" DELIMITED BY SIZE
                   WS-STATUS DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-ROLE DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-CREATED DELIMITED BY SPACE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-LIST-USERS.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Paged list via the multi-row bridge call (one row per user),
            *> with a total and an optional role filter (p4).
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-PARAM1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-PARAM2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF
            *> Total matching rows (role filter bound twice: empty disables it).
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM users WHERE (? = '' OR role = ?)" TO WS-PREP-SQL
            MOVE WS-PARAM4-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM4-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-TOTAL
            *> The page itself.
            MOVE "SELECT CONCAT(id, ':', email, ':', full_name, ':', role, ':', status) FROM users WHERE (? = '' OR role = ?) ORDER BY id LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-PARAM4-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM4-TRIMMED TO WS-BIND-2
            MOVE WS-LIMIT TO WS-BIND-3
            MOVE WS-OFFSET TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|LIST_DONE|" WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-OUTPUT-VALUES
                STRING "SUCCESS|LIST_DONE|" WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DASHBOARD.
            PERFORM ALLOW-READ
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> The user's profile plus all their accounts, as iso:balance pairs.
            *> LEFT JOIN so a user with no accounts still has a profile row.
            MOVE "SELECT u.email, u.full_name, u.status, u.role, u.dob, DATE_FORMAT(u.created_at, '%Y-%m-%dT%H:%i:%s'), COALESCE(GROUP_CONCAT(CONCAT(c.iso_code, ':', ROUND(a.balance,2)) ORDER BY a.account_id SEPARATOR ';'), '') FROM users u LEFT JOIN accounts a ON a.user_id = u.id LEFT JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ? GROUP BY u.id" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-EMAIL WS-NAME WS-STATUS WS-ROLE WS-DOB WS-CREATED WS-ACCOUNTS
            END-UNSTRING
            
            PERFORM TRIM-OUTPUT-VALUES
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|DASHBOARD|" DELIMITED BY SIZE
                   WS-EMAIL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-NAME(1:WS-NLEN) DELIMITED BY SIZE "|" DELIMITED BY SIZE
                   WS-STATUS DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-ROLE DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-DOB DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-CREATED DELIMITED BY SPACE "|" DELIMITED BY SIZE
                   WS-ACCOUNTS DELIMITED BY SPACE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-REQ-EMAIL-CHANGE.
            MOVE 0 TO WS-BAD
            MOVE WS-PARAM1-TRIMMED TO WS-CHECK
            PERFORM VALIDATE-EMAIL
            MOVE WS-PARAM2-TRIMMED TO WS-CHECK
            PERFORM VALIDATE-EMAIL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Only the owner may change their own email (actor p3 = current p1).
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) NOT = WS-PARAM3-TRIMMED(1:WS-P3-LEN)
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> The current user must exist.
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF

            *> Re-authenticate: the current password (p4) must match before
            *> a change is requested. An email change is a high-risk action.
            MOVE "SELECT password_hash FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-STORED
            MOVE SPACES TO WS-PLAIN
            MOVE WS-PARAM4-TRIMMED(1:WS-P4-LEN) TO WS-PLAIN
            CALL "verify_password" USING BY REFERENCE WS-PLAIN BY REFERENCE WS-STORED BY REFERENCE WS-VERIFY
            IF WS-VERIFY NOT = "1"
                MOVE "ERROR|INVALID_CREDENTIALS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF

            *> Neutral: never reveal whether the new address is already
            *> registered. If it is taken, report the same success with no code
            *> (nothing is delivered), so the action cannot enumerate emails.
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "SUCCESS|CODE_SENT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF

            *> Drop any earlier unused code so only one is active at a time
            *> (a fresh request invalidates the previous code).
            MOVE "DELETE FROM verification_logs WHERE email = ? AND purpose = 'EMAIL_CHANGE' AND is_used = 0" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            CALL "generate_random_code" USING BY REFERENCE WS-CODE

            *> Store the code against the target email.
            MOVE "INSERT INTO verification_logs (email, code, purpose, expires_at) VALUES (?, ?, 'EMAIL_CHANGE', DATE_ADD(NOW(), INTERVAL 24 HOUR))" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-CODE TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|EMAIL_CHANGE_FAILED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|CODE_SENT|" WS-CODE(1:6) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CONFIRM-EMAIL-CHANGE.
            MOVE 0 TO WS-BAD
            MOVE WS-PARAM1-TRIMMED TO WS-CHECK
            PERFORM VALIDATE-EMAIL
            MOVE WS-PARAM2-TRIMMED TO WS-CHECK
            PERFORM VALIDATE-EMAIL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Only the owner may confirm their own email change (actor p4 = current p1).
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) NOT = WS-PARAM4-TRIMMED(1:WS-P4-LEN)
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> p1 = current email, p2 = new email, p3 = code.
            MOVE "SELECT 1 FROM verification_logs WHERE email = ? AND code = ? AND purpose = 'EMAIL_CHANGE' AND is_used = 0 AND expires_at > NOW() LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT = "ERROR|NO_DATA"
                *> Cap email-change-code guessing: burn the code after 5 failures.
                MOVE "UPDATE verification_logs SET attempts = attempts + 1 WHERE email = ? AND purpose = 'EMAIL_CHANGE' AND is_used = 0 ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "UPDATE verification_logs SET is_used = 1 WHERE email = ? AND purpose = 'EMAIL_CHANGE' AND is_used = 0 AND attempts >= 5" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE "ERROR|INVALID_CODE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF

            *> The new address must still be free — a race (someone took it after
            *> the request) is reported, not surfaced as an opaque failure.
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "ERROR|EMAIL_EXISTS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF

            *> Current user id, for the audit row.
            MOVE "SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
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
            
            MOVE "UPDATE users SET email = ?, token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF

            IF STEP-OK
                *> Force a clean re-login: bumping the version kills every old
                *> access token, and all refresh sessions are revoked (their
                *> email cascaded to the new one with the users update).
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF

            IF STEP-OK
                MOVE "UPDATE verification_logs SET is_used = 1 WHERE email = ? AND code = ? AND purpose = 'EMAIL_CHANGE'" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF

            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (?, 'EMAIL_CHANGE', 'USER', ?, 'SUCCESS')" TO WS-PREP-SQL
                MOVE WS-USER-ID(1:WS-ID-LEN) TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|EMAIL_CHANGED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|EMAIL_CHANGE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-UPDATE-PROFILE.
            MOVE 0 TO WS-BAD
            MOVE WS-PARAM1-TRIMMED TO WS-CHECK
            PERFORM VALIDATE-EMAIL
            IF WS-PARAM4-TRIMMED(1:1) NOT = SPACE
                MOVE WS-PARAM4-TRIMMED TO WS-CHECK
                PERFORM VALIDATE-DOB
            END-IF
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> p1 = email, p2 = full name, p3 = actor (owner), p4 = dob (opt).
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) NOT = WS-PARAM3-TRIMMED(1:WS-P3-LEN)
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-PARAM2-TRIMMED(1:1) = SPACE
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> The user must exist.
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN"
            IF WS-PARAM4-TRIMMED(1:1) NOT = SPACE
                MOVE "UPDATE users SET full_name = ?, dob = ? WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM4-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            ELSE
                MOVE "UPDATE users SET full_name = ? WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            END-IF
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
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
                END-IF
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) VALUES (?, 'UPDATE_PROFILE', 'USER', ?, 'SUCCESS')" TO WS-PREP-SQL
                MOVE WS-USER-ID(1:WS-ID-LEN) TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|PROFILE_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|PROFILE_UPDATE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DEACTIVATE-ACCOUNT.
            MOVE 0 TO WS-BAD
            MOVE WS-PARAM1-TRIMMED TO WS-CHECK
            PERFORM VALIDATE-EMAIL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> p1 = email, p2 = actor (owner). Soft-close the account.
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) NOT = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> An owner may not close the account of the last active SUPER_ADMIN.
            PERFORM LAST-ACTIVE-SUPER
            IF WS-LAST-ADMIN = 1
                MOVE "ERROR|LAST_ADMIN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN"
            MOVE "UPDATE users SET status = 'CLOSED', token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status) SELECT id, 'DEACTIVATE_ACCOUNT', 'USER', id, 'SUCCESS' FROM users WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|ACCOUNT_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DEACTIVATE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SET-USER-STATUS.
            MOVE 0 TO WS-BAD
            MOVE WS-PARAM1-TRIMMED TO WS-CHECK
            PERFORM VALIDATE-EMAIL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> p1 = target email, p2 = new status, p3 = actor (admin).
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT 1 WHERE ? IN ('UNVERIFIED','VERIFIED','SUSPENDED','CLOSED')" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Role hierarchy: the actor must not be lower-ranked than the target.
            PERFORM ALLOW-RANK-ABOVE
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Never deactivate the last active SUPER_ADMIN.
            IF WS-PARAM2-TRIMMED(1:WS-P2-LEN) NOT = "VERIFIED"
                PERFORM LAST-ACTIVE-SUPER
                IF WS-LAST-ADMIN = 1
                    MOVE "ERROR|LAST_ADMIN" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN"
            MOVE "UPDATE users SET status = ?, token_version = token_version + 1 WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "UPDATE refresh_sessions SET revoked = 1 WHERE email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT t.id, a.id, 'SET_USER_STATUS', 'USER', t.id, 'SUCCESS' FROM users t JOIN users a ON t.email = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
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
                MOVE "SUCCESS|STATUS_CHANGED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|STATUS_CHANGE_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.
