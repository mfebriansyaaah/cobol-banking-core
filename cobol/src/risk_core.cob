        IDENTIFICATION DIVISION.
        PROGRAM-ID. risk_core.
      *> Device/geo risk signals (PR-092): login/new-device notations for
      *> step-up decisions. Signals only — never auto-blocks. Raw IPs never
      *> reach this module (middleware stores SHA-256 ip_hash); private or
      *> unresolvable addresses record UNKNOWN.

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
        01  WS-USER-ID              PIC X(20) VALUE SPACES.
        01  WS-HASH                 PIC X(64) VALUE SPACES.
        01  WS-FLAGS                PIC X(128) VALUE SPACES.
        01  WS-FLAGS-TMP            PIC X(128) VALUE SPACES.
        01  WS-FLAG-1               PIC X(40) VALUE SPACES.
        01  WS-FLAG-2               PIC X(40) VALUE SPACES.
        01  WS-FLAG-3               PIC X(40) VALUE SPACES.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
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
                WHEN LS-CMD-ACTION(1:9) = "RISK_NOTE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NOTE
                WHEN LS-CMD-ACTION(1:11) = "RISK_STATUS"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STATUS
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        COPY "common_validate_semi.cpy".
        COPY "common_sql.cpy".


        COPY "common_trim.cpy".

        CHECK-OWNER.
            *> p1 = email, p6 = actor. Owner-only notations.
            MOVE 0 TO WS-ALLOWED
            IF WS-P1-TRIMMED(1:WS-P1-LEN) = WS-P6-TRIMMED(1:WS-P6-LEN)
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

        ACTION-NOTE.
            *> ADR-0006 Option A: p1 = email, p2 = country signal, p3 = city,
            *> p4 = asn, p5 = "ip_hash:flagsSignal" (hash mandatory, flags
            *> optional), p6 = actor (owner). Adapter resolves/hashes IP;
            *> COBOL stores the notation. Signals only — never auto-blocks.
            PERFORM CHECK-OWNER
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM5 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-USER
            IF WS-LOOKUP-BAD NOT = 0
                EXIT PARAGRAPH
            END-IF.
            *> p5 carries "ip_hash:FLAG1:FLAG2..." (colon-split: pipes would
            *> corrupt framing and fail route validation). Hash is mandatory;
            *> up to three flags stored comma-separated.
            MOVE SPACES TO WS-HASH WS-FLAG-1 WS-FLAG-2 WS-FLAG-3
            UNSTRING WS-P5-TRIMMED DELIMITED BY ":"
                INTO WS-HASH WS-FLAG-1 WS-FLAG-2 WS-FLAG-3
            END-UNSTRING.
            IF WS-HASH = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE FUNCTION TRIM(WS-FLAG-1) TO WS-FLAGS
            IF WS-FLAG-2 NOT = SPACES
                MOVE SPACES TO WS-FLAGS-TMP
                STRING FUNCTION TRIM(WS-FLAGS) DELIMITED BY SIZE
                       "," DELIMITED BY SIZE
                       FUNCTION TRIM(WS-FLAG-2) DELIMITED BY SIZE
                       INTO WS-FLAGS-TMP
                END-STRING
                MOVE WS-FLAGS-TMP TO WS-FLAGS
            END-IF.
            IF WS-FLAG-3 NOT = SPACES
                MOVE SPACES TO WS-FLAGS-TMP
                STRING FUNCTION TRIM(WS-FLAGS) DELIMITED BY SIZE
                       "," DELIMITED BY SIZE
                       FUNCTION TRIM(WS-FLAG-3) DELIMITED BY SIZE
                       INTO WS-FLAGS-TMP
                END-STRING
                MOVE WS-FLAGS-TMP TO WS-FLAGS
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO risk_events (user_id, country, city, asn, ip_hash, flags) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-USER-ID TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            MOVE WS-HASH TO WS-BIND-5
            MOVE WS-FLAGS TO WS-BIND-6
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|RISK_NOTED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STATUS.
            *> p1 = email, p6 = actor (self or admin). Latest notation for
            *> step-up decisions: country|flags (or NO_EVENTS).
            MOVE 0 TO WS-ALLOWED
            IF WS-P1-TRIMMED(1:WS-P1-LEN) = WS-P6-TRIMMED(1:WS-P6-LEN)
                MOVE 1 TO WS-ALLOWED
            ELSE
                MOVE WS-P6-TRIMMED TO WS-BIND-1
                PERFORM LOOKUP-USER-ROLE
                IF WS-RESULT = "SUPER_ADMIN"
                    MOVE 1 TO WS-ALLOWED
                END-IF
            END-IF.
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(COALESCE(country, 'UNKNOWN'), '|', flags) FROM risk_events WHERE user_id = (SELECT id FROM users WHERE email = ? LIMIT 1) ORDER BY id DESC LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|RISK_STATUS|NO_EVENTS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|RISK_STATUS|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-RESULT) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.
