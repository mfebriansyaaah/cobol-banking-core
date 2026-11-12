        IDENTIFICATION DIVISION.
        PROGRAM-ID. fx_rate_core.
      *> FX reference snapshots (PR-091, Frankfurter): daily mid-rate
      *> reference only, never a settlement basis. STORE is admin/cron-only;
      *> GET serves the latest row per pair with FRESH/STALE age marking
      *> (stale above 24h; transactions must refuse STALE).

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
                WHEN LS-CMD-ACTION(1:13) = "FX_RATE_STORE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STORE
                WHEN LS-CMD-ACTION(1:11) = "FX_RATE_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-GET
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        COPY "common_validate_semi.cpy".
        COPY "common_sql.cpy".


        COPY "common_trim.cpy".

        CHECK-ISO.
            *> WS-TRIM-IN holds the candidate; WS-BAD counts violations.
            *> ISO 4217 alpha codes: exactly 3 A-Z.
            IF FUNCTION LENGTH(FUNCTION TRIM(WS-TRIM-IN)) NOT = 3
                ADD 1 TO WS-BAD
            ELSE
                PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 3
                    IF WS-TRIM-IN(WS-I:1) < "A" OR WS-TRIM-IN(WS-I:1) > "Z"
                        ADD 1 TO WS-BAD
                    END-IF
                END-PERFORM
            END-IF.
            EXIT PARAGRAPH.

        CHECK-ADMIN.
            *> p6 = actor (SUPER_ADMIN or MANAGER, mirror of loan_core).
            MOVE 0 TO WS-ALLOWED
            MOVE WS-P6-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STORE.
            *> p1 = base, p2 = quote, p3 = rate, p4 = provider,
            *> p5 = provider date (YYYY-MM-DD), p6 = actor (admin/cron).
            PERFORM CHECK-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE 0 TO WS-BAD
            MOVE WS-P1-TRIMMED TO WS-TRIM-IN
            PERFORM CHECK-ISO
            MOVE WS-P2-TRIMMED TO WS-TRIM-IN
            PERFORM CHECK-ISO
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-TRIMMED(1:3) = WS-P2-TRIMMED(1:3)
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF FUNCTION NUMVAL(WS-P3-TRIMMED) <= 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P5-LEN NOT = 10
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO fx_rate_snapshots (base, quote, rate, provider, fetched_at) VALUES (?, ?, ?, ?, CONCAT(?, ' ', CURTIME()))" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            IF WS-P4-TRIMMED = SPACES
                MOVE "frankfurter" TO WS-BIND-4
            ELSE
                MOVE WS-P4-TRIMMED TO WS-BIND-4
            END-IF.
            MOVE WS-P5-TRIMMED TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|FX_STORED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACTION-GET.
            *> p1 = base, p2 = quote. Latest snapshot with FRESH/STALE marking
            *> (stale above 24h). Reference data: no actor gate.
            IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE 0 TO WS-BAD
            MOVE WS-P1-TRIMMED TO WS-TRIM-IN
            PERFORM CHECK-ISO
            MOVE WS-P2-TRIMMED TO WS-TRIM-IN
            PERFORM CHECK-ISO
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(CAST(rate AS CHAR), '|', IF(TIMESTAMPDIFF(HOUR, fetched_at, NOW()) <= 24, 'FRESH', 'STALE')) FROM fx_rate_snapshots WHERE base = ? AND quote = ? ORDER BY fetched_at DESC LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
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
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|FX_RATE|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-RESULT) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.
