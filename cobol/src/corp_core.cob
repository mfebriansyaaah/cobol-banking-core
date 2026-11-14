        IDENTIFICATION DIVISION.
        PROGRAM-ID. corp_core.
      *> Corporate registry cache (PR-097, GLEIF): LEI lookups cached for
      *> onboarding triage. Never a substitute for AHU/akta, never proof of
      *> Indonesian registration. CORP_RESOLVE upserts by LEI (admin/cron);
      *> CORP_STATUS reads the cached record.

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
        01  WS-SUCCESS-MSG          PIC X(16384) VALUE SPACES.
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
                WHEN LS-CMD-ACTION(1:12) = "CORP_RESOLVE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RESOLVE
                WHEN LS-CMD-ACTION(1:11) = "CORP_STATUS"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STATUS
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        COPY "common_validate_semi.cpy".
        COPY "common_sql.cpy".


        COPY "common_trim.cpy".
        COPY "common_txn.cpy".

        CHECK-ADMIN.
            *> p6 = actor (SUPER_ADMIN or MANAGER, mirror of loan_core).
            MOVE 0 TO WS-ALLOWED
            MOVE WS-P6-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.

        CHECK-LEI.
            *> WS-P1-TRIMMED must be a 20-char LEI (digits + caps only).
            IF WS-P1-LEN NOT = 20
                MOVE 1 TO WS-BAD
                EXIT PARAGRAPH
            END-IF.
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 20
                IF WS-P1-TRIMMED(WS-I:1) < "0" OR WS-P1-TRIMMED(WS-I:1) > "Z"
                    MOVE 1 TO WS-BAD
                ELSE
                    IF WS-P1-TRIMMED(WS-I:1) > "9" AND WS-P1-TRIMMED(WS-I:1) < "A"
                        MOVE 1 TO WS-BAD
                    END-IF
                END-IF
            END-PERFORM.
            EXIT PARAGRAPH.

        ACTION-RESOLVE.
            *> p1 = LEI, p2 = legal name, p3 = status, p4 = address,
            *> p5 = fetched date (YYYY-MM-DD), p6 = actor (admin/cron).
            *> Upserts the cached record.
            PERFORM CHECK-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES OR WS-P5-LEN NOT = 10
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE 0 TO WS-BAD
            PERFORM CHECK-LEI
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO corporate_entities (lei, legal_name, status, address, fetched_at) VALUES (?, ?, ?, ?, CONCAT(?, ' ', CURTIME())) ON DUPLICATE KEY UPDATE legal_name = VALUES(legal_name), status = VALUES(status), address = VALUES(address), fetched_at = VALUES(fetched_at)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            MOVE WS-P5-TRIMMED TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            MOVE "SUCCESS|CORP_RESOLVED" TO WS-SUCCESS-MSG
            PERFORM TXN-FINISH
            EXIT PARAGRAPH.

        ACTION-STATUS.
            *> p1 = LEI. Cached record (name|status) or NOT_FOUND.
            *> Reference data: no actor gate.
            IF LS-PARAM1 = SPACES
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE 0 TO WS-BAD
            PERFORM CHECK-LEI
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(legal_name, '|', status) FROM corporate_entities WHERE lei = ? LIMIT 1" TO WS-PREP-SQL
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
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|CORP_STATUS|" DELIMITED BY SIZE
                   FUNCTION TRIM(WS-RESULT) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER END-STRING.
            EXIT PARAGRAPH.
