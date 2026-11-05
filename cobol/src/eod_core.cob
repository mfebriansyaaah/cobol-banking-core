       IDENTIFICATION DIVISION.
       PROGRAM-ID. eod_core.
      *> EOD calendar, run, phase, and close control (Sprint 1 slice 4).

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

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
       01  WS-J                    PIC 9(5) VALUE 1.
       01  WS-RLEN                 PIC 9(5) VALUE 1.
       01  WS-BAD                  PIC 9(3) VALUE 0.
       01  WS-BAD-SAVE             PIC 9 VALUE 0.
       01  WS-ALLOWED              PIC 9 VALUE 0.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-TOTAL                PIC X(100) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-LOOKUP-BAD           PIC 9 VALUE 0.
       01  WS-DATE-IN              PIC X(100) VALUE SPACES.
       01  WS-DATE-LEN             PIC 9(3) VALUE 0.
       01  WS-TIME-IN              PIC X(5) VALUE SPACES.
       01  WS-TIME-LEN             PIC 9(3) VALUE 0.
       01  WS-HH                   PIC 99 VALUE 0.
       01  WS-MM                   PIC 99 VALUE 0.
       01  WS-CAL-STATUS           PIC X(10) VALUE SPACES.
       01  WS-CAL-CUTOFF           PIC X(8) VALUE SPACES.
       01  WS-CAL-CLOSED-BY        PIC X(100) VALUE SPACES.
       01  WS-RUN-ID               PIC X(20) VALUE SPACES.
       01  WS-RUN-STATUS           PIC X(20) VALUE SPACES.
       01  WS-RUN-DATE             PIC X(10) VALUE SPACES.
       01  WS-RUN-PHASES           PIC X(10) VALUE SPACES.
       01  WS-RUN-DONE             PIC X(10) VALUE SPACES.
       01  WS-RUN-DEBIT            PIC X(30) VALUE SPACES.
       01  WS-RUN-CREDIT           PIC X(30) VALUE SPACES.
       01  WS-RUN-ERROR            PIC X(40) VALUE SPACES.
       01  WS-PHASE-ID             PIC X(20) VALUE SPACES.
       01  WS-PHASE-NO             PIC X(10) VALUE SPACES.
       01  WS-PHASE-CODE           PIC X(20) VALUE SPACES.
       01  WS-PHASE-STATUS         PIC X(20) VALUE SPACES.
       01  WS-PHASE-PROCESSED      PIC X(20) VALUE SPACES.
       01  WS-PHASE-DEBIT          PIC X(30) VALUE SPACES.
       01  WS-PHASE-CREDIT         PIC X(30) VALUE SPACES.
       01  WS-PHASE-ERROR          PIC X(40) VALUE SPACES.
       01  WS-CODE-IN              PIC X(100) VALUE SPACES.
       01  WS-CODE-LEN             PIC 9(3) VALUE 0.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-DEC-IN               PIC X(30) VALUE SPACES.
       01  WS-DEC-LEN              PIC 9(3) VALUE 0.
       01  WS-DOT-COUNT            PIC 9(3) VALUE 0.
       01  WS-COUNT1               PIC X(20) VALUE SPACES.
       01  WS-COUNT2               PIC X(20) VALUE SPACES.
       01  WS-COUNT3               PIC X(20) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-DATE           PIC X(10) VALUE SPACES.
       01  WS-AUDIT-RUN            PIC X(20) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-PART                 PIC X(16384) VALUE SPACES.
       01  WS-PART-LEN             PIC 9(5) VALUE 0.
       01  WS-OUT-POS              PIC 9(5) VALUE 1.
       01  F-QUOTE                 PIC X VALUE "'".
       01  F-DQUOTE                PIC X VALUE '"'.
       01  F-BSLASH                PIC X VALUE "\".
       01  F-SEMI                  PIC X VALUE ";".
       01  F-TICK                  PIC X VALUE "`".

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
           PERFORM VALIDATE-ALL
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               GOBACK
           END-IF
           EVALUATE TRUE
               WHEN LS-CMD-ACTION(1:12) = "EOD_CAL_OPEN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CAL-OPEN
               WHEN LS-CMD-ACTION(1:12) = "EOD_CAL_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CAL-LIST
               WHEN LS-CMD-ACTION(1:13) = "EOD_RUN_START"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-START
               WHEN LS-CMD-ACTION(1:13) = "EOD_PHASE_SET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-PHASE-SET
               WHEN LS-CMD-ACTION(1:14) = "EOD_RUN_STATUS"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-STATUS
               WHEN LS-CMD-ACTION(1:13) = "EOD_RUN_CLOSE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-CLOSE
               WHEN LS-CMD-ACTION(1:12) = "EOD_RUN_FAIL"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-FAIL
               WHEN LS-CMD-ACTION(1:12) = "EOD_RUN_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-LIST
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
        COPY "common_validate.cpy".


       VALIDATE-DATE-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-DATE-LEN
           PERFORM VARYING WS-I FROM 100 BY -1
               UNTIL WS-I < 1 OR WS-DATE-LEN > 0
               IF WS-DATE-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-DATE-LEN
               END-IF
           END-PERFORM
           IF WS-DATE-LEN NOT = 10
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-DATE-IN(5:1) NOT = "-" OR WS-DATE-IN(8:1) NOT = "-"
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-DATE-IN(1:4) IS NOT NUMERIC
              OR WS-DATE-IN(6:2) IS NOT NUMERIC
              OR WS-DATE-IN(9:2) IS NOT NUMERIC
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-TIME-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-TIME-LEN
           PERFORM VARYING WS-I FROM 5 BY -1
               UNTIL WS-I < 1 OR WS-TIME-LEN > 0
               IF WS-TIME-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-TIME-LEN
               END-IF
           END-PERFORM
           IF WS-TIME-LEN NOT = 5
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-TIME-IN(3:1) NOT = ":"
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-TIME-IN(1:2) IS NOT NUMERIC OR WS-TIME-IN(4:2) IS NOT NUMERIC
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-BAD = 0
               MOVE FUNCTION NUMVAL(WS-TIME-IN(1:2)) TO WS-HH
               MOVE FUNCTION NUMVAL(WS-TIME-IN(4:2)) TO WS-MM
               IF WS-HH > 23 OR WS-MM > 59
                   MOVE 1 TO WS-BAD
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-CODE-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-CODE-LEN
           PERFORM VARYING WS-I FROM 100 BY -1
               UNTIL WS-I < 1 OR WS-CODE-LEN > 0
               IF WS-CODE-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-CODE-LEN
               END-IF
           END-PERFORM
           IF WS-CODE-LEN < 1 OR WS-CODE-LEN > 40
               MOVE 1 TO WS-BAD
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-CODE-LEN
               IF WS-CODE-IN(WS-I:1) IS NOT ALPHABETIC
                  AND WS-CODE-IN(WS-I:1) IS NOT NUMERIC
                  AND WS-CODE-IN(WS-I:1) NOT = "_"
                  AND WS-CODE-IN(WS-I:1) NOT = "-"
                   MOVE 1 TO WS-BAD
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.


       VALIDATE-DECIMAL-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-DOT-COUNT
           MOVE 0 TO WS-DEC-LEN
           PERFORM VARYING WS-I FROM 30 BY -1
               UNTIL WS-I < 1 OR WS-DEC-LEN > 0
               IF WS-DEC-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-DEC-LEN
               END-IF
           END-PERFORM
           IF WS-DEC-LEN < 1 OR WS-DEC-LEN > 20
               MOVE 1 TO WS-BAD
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-DEC-LEN
               IF WS-DEC-IN(WS-I:1) = "."
                   ADD 1 TO WS-DOT-COUNT END-ADD
               ELSE
                   IF WS-DEC-IN(WS-I:1) IS NOT NUMERIC
                       MOVE 1 TO WS-BAD
                   END-IF
               END-IF
           END-PERFORM.
           IF WS-DOT-COUNT > 1
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       ALLOW-ADMIN.
           MOVE 0 TO WS-ALLOWED
           MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P6-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
               MOVE 1 TO WS-ALLOWED
           END-IF
           IF WS-ALLOWED NOT = 1
               MOVE WS-P6-TRIMMED TO WS-DENIED-ACTOR
               MOVE "EOD_CORE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       AUDIT-EOD.
           MOVE "INSERT INTO eod_audit (action, actor_email, business_date, run_id, detail) VALUES (?, ?, NULLIF(?, ''), NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-DATE TO WS-BIND-3
           MOVE WS-AUDIT-RUN TO WS-BIND-4
           MOVE WS-AUDIT-DETAIL TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

       AUDIT-DENIED.
           MOVE "AUTHZ_DENIED" TO WS-AUDIT-ACTION
           MOVE SPACES TO WS-AUDIT-DATE WS-AUDIT-RUN
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT-EOD.
           EXIT PARAGRAPH.

       CHECK-CALENDAR.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-CAL-STATUS WS-CAL-CUTOFF WS-CAL-CLOSED-BY
           MOVE "SELECT CONCAT(status, '|', cutoff_time, '|', COALESCE(closed_by, '')) FROM eod_calendar WHERE business_date = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE 1 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE 2 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-CAL-STATUS WS-CAL-CUTOFF WS-CAL-CLOSED-BY
           END-UNSTRING.
           EXIT PARAGRAPH.

       CHECK-RUN.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-RUN-STATUS WS-RUN-DATE WS-RUN-PHASES
               WS-RUN-DONE WS-RUN-DEBIT WS-RUN-CREDIT WS-RUN-ERROR
           MOVE "SELECT CONCAT(status, '|', business_date, '|', phase_count, '|', completed_phases, '|', control_debit, '|', control_credit, '|', COALESCE(error_code, '')) FROM eod_run WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE 1 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE 2 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           UNSTRING WS-RESULT DELIMITED BY "|" INTO
               WS-RUN-STATUS WS-RUN-DATE WS-RUN-PHASES WS-RUN-DONE
               WS-RUN-DEBIT WS-RUN-CREDIT WS-RUN-ERROR
           END-UNSTRING.
           EXIT PARAGRAPH.

       CHECK-PHASE.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-PHASE-ID WS-PHASE-NO WS-PHASE-STATUS
               WS-PHASE-PROCESSED WS-PHASE-DEBIT WS-PHASE-CREDIT WS-PHASE-ERROR
           MOVE "SELECT CONCAT(id, '|', phase_no, '|', status, '|', processed_count, '|', control_debit, '|', control_credit, '|', COALESCE(error_code, '')) FROM eod_phase WHERE run_id = ? AND phase_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE 1 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE 2 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           UNSTRING WS-RESULT DELIMITED BY "|" INTO
               WS-PHASE-ID WS-PHASE-NO WS-PHASE-STATUS
               WS-PHASE-PROCESSED WS-PHASE-DEBIT WS-PHASE-CREDIT WS-PHASE-ERROR
           END-UNSTRING.
           EXIT PARAGRAPH.

       TRIM-RESULT-LEN.
           MOVE 0 TO WS-RLEN
           PERFORM VARYING WS-J FROM 16384 BY -1
               UNTIL WS-J < 1 OR WS-RLEN > 0
               IF WS-RESULT(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-RLEN
               END-IF
           END-PERFORM
           IF WS-RLEN = 0
               MOVE 1 TO WS-RLEN
           END-IF.
           EXIT PARAGRAPH.

       ACTION-CAL-OPEN.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED(1:5) TO WS-TIME-IN
           PERFORM VALIDATE-TIME-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-CALENDAR
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 0 AND WS-CAL-STATUS = "CLOSED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           IF WS-LOOKUP-BAD = 1
               MOVE "INSERT INTO eod_calendar (business_date, status, cutoff_time, opened_by) VALUES (?, 'OPEN', ?, ?)" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               MOVE WS-P2-TRIMMED TO WS-BIND-2
               MOVE WS-P6-TRIMMED TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE "UPDATE eod_calendar SET cutoff_time = ?, opened_by = ?, version = version + 1 WHERE business_date = ? AND status = 'OPEN'" TO WS-PREP-SQL
               MOVE WS-P2-TRIMMED TO WS-BIND-1
               MOVE WS-P6-TRIMMED TO WS-BIND-2
               MOVE WS-P1-TRIMMED TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "CALENDAR_OPEN" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:10) TO WS-AUDIT-DATE
               MOVE SPACES TO WS-AUDIT-RUN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|EOD_CALENDAR_OPEN" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-CAL-LIST.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM eod_calendar WHERE (? = '' OR status = ?)" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(business_date, ':', status, ':', cutoff_time, ':', COALESCE(closed_by, '')) FROM eod_calendar WHERE (? = '' OR status = ?) ORDER BY business_date DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           MOVE WS-OFFSET TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|EOD_CALENDARS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|EOD_CALENDARS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-START.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-CALENDAR
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|CALENDAR_NOT_OPEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-CAL-STATUS NOT = "OPEN"
               MOVE "ERROR|CALENDAR_NOT_OPEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM eod_run WHERE business_date = ? AND status = 'RUNNING'" TO WS-PREP-SQL
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
           IF FUNCTION NUMVAL(WS-RESULT) > 0
               MOVE "ERROR|RUN_ACTIVE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO eod_run (business_date, status, phase_count, created_by) VALUES (?, 'RUNNING', 5, ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-RUN-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSERT INTO eod_phase (run_id, phase_no, phase_code, status) VALUES (?, 1, 'FEE', 'PENDING'), (?, 2, 'HOLD', 'PENDING'), (?, 3, 'DORMANT', 'PENDING'), (?, 4, 'STATEMENT', 'PENDING'), (?, 5, 'RECON', 'PENDING')" TO WS-PREP-SQL
               MOVE WS-RUN-ID TO WS-BIND-1
               MOVE WS-RUN-ID TO WS-BIND-2
               MOVE WS-RUN-ID TO WS-BIND-3
               MOVE WS-RUN-ID TO WS-BIND-4
               MOVE WS-RUN-ID TO WS-BIND-5
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "RUN_START" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:10) TO WS-AUDIT-DATE
               MOVE WS-RUN-ID TO WS-AUDIT-RUN
               MOVE "EOD" TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|EOD_RUN_STARTED|" DELIMITED BY SIZE
                      WS-RUN-ID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-PHASE-SET.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED NOT = "PENDING" AND WS-P3-TRIMMED NOT = "RUNNING"
              AND WS-P3-TRIMMED NOT = "COMPLETED" AND WS-P3-TRIMMED NOT = "FAILED"
              AND WS-P3-TRIMMED NOT = "SKIPPED"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-RUN
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RUN-STATUS NOT = "RUNNING"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-PHASE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-PHASE-STATUS = "PENDING"
               IF WS-P3-TRIMMED NOT = "RUNNING" AND WS-P3-TRIMMED NOT = "SKIPPED"
                  AND WS-P3-TRIMMED NOT = "FAILED"
                   MOVE "ERROR|INVALID_TRANSITION" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           ELSE
               IF WS-PHASE-STATUS = "RUNNING"
                   IF WS-P3-TRIMMED NOT = "COMPLETED" AND WS-P3-TRIMMED NOT = "FAILED"
                       MOVE "ERROR|INVALID_TRANSITION" TO LS-OUTPUT-BUFFER
                       EXIT PARAGRAPH
                   END-IF
               ELSE
                   MOVE "ERROR|INVALID_TRANSITION" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE SPACES TO WS-COUNT1 WS-COUNT2 WS-COUNT3
           UNSTRING WS-P4-TRIMMED DELIMITED BY ","
               INTO WS-COUNT1 WS-COUNT2 WS-COUNT3
           END-UNSTRING
           MOVE WS-COUNT1 TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           MOVE WS-COUNT2 TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           MOVE WS-COUNT3 TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT IF(CAST(? AS DECIMAL(30,10)) = CAST(? AS DECIMAL(30,10)), 'OK', 'BAD')" TO WS-PREP-SQL
           MOVE WS-COUNT2 TO WS-BIND-1
           MOVE WS-COUNT3 TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "OK"
               MOVE "ERROR|UNBALANCED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE eod_phase SET status = ?, processed_count = ?, control_debit = ?, control_credit = ? WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-COUNT1 TO WS-BIND-2
           MOVE WS-COUNT2 TO WS-BIND-3
           MOVE WS-COUNT3 TO WS-BIND-4
           MOVE WS-PHASE-ID TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE eod_phase SET started_at = NOW() WHERE id = ? AND status = 'RUNNING' AND started_at IS NULL" TO WS-PREP-SQL
               MOVE WS-PHASE-ID TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE eod_phase SET finished_at = NOW() WHERE id = ? AND status IN ('COMPLETED', 'FAILED', 'SKIPPED') AND finished_at IS NULL" TO WS-PREP-SQL
               MOVE WS-PHASE-ID TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "PHASE_SET" TO WS-AUDIT-ACTION
               MOVE WS-RUN-DATE TO WS-AUDIT-DATE
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RUN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|EOD_PHASE_SET" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-STATUS.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM2 = SPACES
               MOVE "0" TO WS-P2-TRIMMED
           END-IF.
           IF WS-P2-TRIMMED NOT = "0" AND WS-P2-TRIMMED NOT = "1"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-RUN
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           MOVE 1 TO WS-OUT-POS
           STRING "SUCCESS|EOD_RUN|" DELIMITED BY SIZE
                  WS-P1-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-DATE DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-STATUS DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-PHASES DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-DONE DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-DEBIT DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-CREDIT DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-RUN-ERROR DELIMITED BY SPACE
                  INTO LS-OUTPUT-BUFFER WITH POINTER WS-OUT-POS
           END-STRING
           IF WS-P2-TRIMMED = "1"
               MOVE "SELECT CONCAT(phase_no, ':', phase_code, ':', status, ':', processed_count, ':', control_debit, ':', control_credit, ':', COALESCE(error_code, '')) FROM eod_phase WHERE run_id = ? ORDER BY phase_no" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE SPACES TO WS-PART
               MOVE 0 TO WS-PART-LEN
               IF WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE WS-RESULT TO WS-PART
                   PERFORM TRIM-PART
               END-IF
               STRING "|" DELIMITED BY SIZE
                      WS-PART(1:WS-PART-LEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER WITH POINTER WS-OUT-POS
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       TRIM-PART.
           MOVE 0 TO WS-PART-LEN
           PERFORM VARYING WS-J FROM 16384 BY -1
               UNTIL WS-J < 1 OR WS-PART-LEN > 0
               IF WS-PART(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-PART-LEN
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.

       ACTION-RUN-CLOSE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-RUN
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RUN-STATUS NOT = "RUNNING"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM eod_phase WHERE run_id = ? AND status NOT IN ('COMPLETED', 'SKIPPED')" TO WS-PREP-SQL
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
           IF FUNCTION NUMVAL(WS-RESULT) > 0
               MOVE "ERROR|PHASES_INCOMPLETE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT IF(COALESCE(SUM(control_debit), 0) = COALESCE(SUM(control_credit), 0), 'OK', 'BAD') FROM eod_phase WHERE run_id = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "OK"
               MOVE "ERROR|UNBALANCED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE eod_run SET status = 'COMPLETED', completed_phases = (SELECT COUNT(*) FROM eod_phase WHERE run_id = ? AND status IN ('COMPLETED','SKIPPED')), control_debit = (SELECT COALESCE(SUM(control_debit),0) FROM eod_phase WHERE run_id = ?), control_credit = (SELECT COALESCE(SUM(control_credit),0) FROM eod_phase WHERE run_id = ?), finished_at = NOW(), version = version + 1 WHERE id = ? AND status = 'RUNNING'" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P1-TRIMMED TO WS-BIND-3
           MOVE WS-P1-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE eod_calendar SET status = 'CLOSED', closed_by = ?, closed_at = NOW(), version = version + 1 WHERE business_date = ? AND status = 'OPEN'" TO WS-PREP-SQL
               MOVE WS-P6-TRIMMED TO WS-BIND-1
               MOVE WS-RUN-DATE TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "RUN_CLOSE" TO WS-AUDIT-ACTION
               MOVE WS-RUN-DATE TO WS-AUDIT-DATE
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RUN
               MOVE "closed" TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|EOD_RUN_CLOSED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-FAIL.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-RUN
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RUN-STATUS NOT = "RUNNING"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE eod_run SET status = 'FAILED', error_code = ?, error_detail = ?, finished_at = NOW(), version = version + 1 WHERE id = ? AND status = 'RUNNING'" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P1-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "RUN_FAIL" TO WS-AUDIT-ACTION
               MOVE WS-RUN-DATE TO WS-AUDIT-DATE
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RUN
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-EOD
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|EOD_RUN_FAILED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-LIST.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               IF WS-P3-TRIMMED NOT = "RUNNING" AND WS-P3-TRIMMED NOT = "COMPLETED"
                  AND WS-P3-TRIMMED NOT = "FAILED"
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF LS-PARAM4 NOT = SPACES
               MOVE WS-P4-TRIMMED TO WS-DATE-IN
               PERFORM VALIDATE-DATE-FIELD
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM eod_run WHERE status = COALESCE(NULLIF(?, ''), status) AND business_date = COALESCE(NULLIF(?, ''), business_date)" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P4-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(id, ':', business_date, ':', status, ':', phase_count, ':', completed_phases, ':', control_debit, ':', control_credit, ':', COALESCE(error_code, '')) FROM eod_run WHERE status = COALESCE(NULLIF(?, ''), status) AND business_date = COALESCE(NULLIF(?, ''), business_date) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P4-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           MOVE WS-OFFSET TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|EOD_RUNS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|EOD_RUNS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.
