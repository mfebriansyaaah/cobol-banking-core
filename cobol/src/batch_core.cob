       IDENTIFICATION DIVISION.
       PROGRAM-ID. batch_core.
      *> Batch/EOD foundation (Phase 1, Sprint 1 slice 2).
      *> Job definitions, ordered steps, runs, checkpoints, control totals,
      *> retry, and audit. All state transitions are enforced in COBOL.

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
       01  WS-ALLOWED              PIC 9 VALUE 0.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-TOTAL                PIC X(100) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-FOUND                PIC 9 VALUE 0.
       01  WS-JOB-FOUND            PIC 9 VALUE 0.
       01  WS-RUN-FOUND            PIC 9 VALUE 0.
       01  WS-STEP-FOUND           PIC 9 VALUE 0.
       01  WS-LOOKUP-BAD           PIC 9 VALUE 0.
       01  WS-BALANCE-BAD          PIC 9 VALUE 0.
       01  WS-JOB-ID               PIC X(20) VALUE SPACES.
       01  WS-JOB-TYPE             PIC X(20) VALUE SPACES.
       01  WS-JOB-ENABLED          PIC X(1) VALUE SPACES.
       01  WS-RUN-ID               PIC X(20) VALUE SPACES.
       01  WS-RUN-STATUS           PIC X(20) VALUE SPACES.
       01  WS-RUN-JOB-ID           PIC X(20) VALUE SPACES.
       01  WS-RUN-JOB-CODE         PIC X(40) VALUE SPACES.
       01  WS-RUN-LOCKED-BY        PIC X(100) VALUE SPACES.
       01  WS-RUN-ATTEMPT          PIC X(10) VALUE SPACES.
       01  WS-RUN-CHECK-KEY        PIC X(100) VALUE SPACES.
       01  WS-RUN-CHECK-VAL        PIC X(100) VALUE SPACES.
       01  WS-RUN-DATE             PIC X(10) VALUE SPACES.
       01  WS-RUN-VERSION          PIC X(10) VALUE SPACES.
       01  WS-STEP-ID              PIC X(20) VALUE SPACES.
       01  WS-STEP-STATUS          PIC X(20) VALUE SPACES.
       01  WS-STEP-ATTEMPT         PIC X(10) VALUE SPACES.
       01  WS-STEP-CODE            PIC X(40) VALUE SPACES.
       01  WS-NEW-ATTEMPT          PIC 9(10) VALUE 0.
       01  WS-NEW-ATTEMPT-ED       PIC Z(9)9 VALUE 0.
       01  WS-STEP-ATTEMPT-N       PIC 9(10) VALUE 0.
       01  WS-DATE-IN              PIC X(100) VALUE SPACES.
       01  WS-DATE-LEN             PIC 9(3) VALUE 0.
       01  WS-TIME-IN              PIC X(5) VALUE SPACES.
       01  WS-TIME-LEN             PIC 9(3) VALUE 0.
       01  WS-HH                   PIC 99 VALUE 0.
       01  WS-MM                   PIC 99 VALUE 0.
       01  WS-CODE-IN              PIC X(100) VALUE SPACES.
       01  WS-CODE-LEN             PIC 9(3) VALUE 0.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-DEC-IN               PIC X(30) VALUE SPACES.
       01  WS-DEC-LEN              PIC 9(3) VALUE 0.
       01  WS-DOT-COUNT            PIC 9(3) VALUE 0.
       01  WS-SCHED-TIME           PIC X(5) VALUE SPACES.
       01  WS-MAX-RETRIES          PIC X(10) VALUE SPACES.
       01  WS-TIMEOUT              PIC X(10) VALUE SPACES.
       01  WS-REQUIRED             PIC X(1) VALUE SPACES.
       01  WS-COUNT1               PIC X(20) VALUE SPACES.
       01  WS-COUNT2               PIC X(20) VALUE SPACES.
       01  WS-COUNT3               PIC X(20) VALUE SPACES.
       01  WS-DEBIT                PIC X(30) VALUE SPACES.
       01  WS-CREDIT               PIC X(30) VALUE SPACES.
       01  WS-DATE-COMPACT         PIC X(8) VALUE SPACES.
       01  WS-TODAY                PIC X(8) VALUE SPACES.
       01  WS-START-JOB-CODE       PIC X(40) VALUE SPACES.
       01  WS-START-DATE           PIC X(10) VALUE SPACES.
       01  WS-EOD-FLAG             PIC 9 VALUE 0.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-RUN            PIC X(20) VALUE SPACES.
       01  WS-AUDIT-JOB            PIC X(40) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-PART                 PIC X(16384) VALUE SPACES.
       01  WS-PART-LEN             PIC 9(5) VALUE 0.
       01  WS-PART2                PIC X(16384) VALUE SPACES.
       01  WS-PART2-LEN            PIC 9(5) VALUE 0.
       01  WS-PART3                PIC X(16384) VALUE SPACES.
       01  WS-PART3-LEN            PIC 9(5) VALUE 0.
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
               WHEN LS-CMD-ACTION(1:16) = "BATCH_JOB_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-JOB-CREATE
               WHEN LS-CMD-ACTION(1:14) = "BATCH_JOB_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-JOB-LIST
               WHEN LS-CMD-ACTION(1:16) = "BATCH_JOB_UPDATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-JOB-UPDATE
               WHEN LS-CMD-ACTION(1:17) = "BATCH_STEP_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-JOB-STEP-CREATE
               WHEN LS-CMD-ACTION(1:15) = "BATCH_STEP_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-JOB-STEP-LIST
               WHEN LS-CMD-ACTION(1:15) = "BATCH_RUN_START"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-START
               WHEN LS-CMD-ACTION(1:15) = "BATCH_EOD_START"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-EOD-START
               WHEN LS-CMD-ACTION(1:16) = "BATCH_RUN_STATUS"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-STATUS
               WHEN LS-CMD-ACTION(1:14) = "BATCH_RUN_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-LIST
               WHEN LS-CMD-ACTION(1:20) = "BATCH_RUN_CHECKPOINT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-CHECKPOINT
               WHEN LS-CMD-ACTION(1:18) = "BATCH_RUN_COMPLETE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-COMPLETE
               WHEN LS-CMD-ACTION(1:14) = "BATCH_RUN_FAIL"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-FAIL
               WHEN LS-CMD-ACTION(1:15) = "BATCH_RUN_RETRY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-RETRY
               WHEN LS-CMD-ACTION(1:14) = "BATCH_RUN_STEP"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RUN-STEP
               WHEN LS-CMD-ACTION(1:19) = "BATCH_CONTROL_TOTAL"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CONTROL-TOTAL
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

       TRIM-ALL.
           MOVE LS-PARAM1 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P1-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P1-LEN
           MOVE LS-PARAM2 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P2-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P2-LEN
           MOVE LS-PARAM3 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P3-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P3-LEN
           MOVE LS-PARAM4 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P4-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P4-LEN
           MOVE LS-PARAM5 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P5-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P5-LEN
           MOVE LS-PARAM6 TO WS-TRIM-IN
           PERFORM TRIM-VALUE
           MOVE WS-TRIM-OUT TO WS-P6-TRIMMED
           MOVE WS-TRIM-LEN TO WS-P6-LEN.
           EXIT PARAGRAPH.

       TRIM-VALUE.
           MOVE WS-TRIM-IN TO WS-TRIM-OUT
           MOVE 0 TO WS-TRIM-LEN
           PERFORM VARYING WS-I FROM 100 BY -1
               UNTIL WS-I < 1 OR WS-TRIM-LEN > 0
               IF WS-TRIM-OUT(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-TRIM-LEN
               END-IF
           END-PERFORM
           IF WS-TRIM-LEN = 0
               MOVE 1 TO WS-TRIM-LEN
           END-IF.
           EXIT PARAGRAPH.

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
           IF WS-TIME-IN(1:2) IS NOT NUMERIC
              OR WS-TIME-IN(4:2) IS NOT NUMERIC
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

       VALIDATE-COUNT-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-COUNT-LEN
           PERFORM VARYING WS-I FROM 30 BY -1
               UNTIL WS-I < 1 OR WS-COUNT-LEN > 0
               IF WS-COUNT-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-COUNT-LEN
               END-IF
           END-PERFORM
           IF WS-COUNT-LEN < 1 OR WS-COUNT-LEN > 18
               MOVE 1 TO WS-BAD
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-COUNT-LEN
               IF WS-COUNT-IN(WS-I:1) IS NOT NUMERIC
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

       CHECK-BALANCE.
           MOVE 0 TO WS-BALANCE-BAD
           MOVE "SELECT IF(CAST(? AS DECIMAL(30,10)) = CAST(? AS DECIMAL(30,10)), 'BALANCED', 'UNBALANCED')" TO WS-PREP-SQL
           MOVE WS-DEBIT TO WS-BIND-1
           MOVE WS-CREDIT TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "BALANCED"
               MOVE 0 TO WS-BALANCE-BAD
           ELSE
               IF WS-RESULT = "UNBALANCED"
                   MOVE 1 TO WS-BALANCE-BAD
               ELSE
                   MOVE 2 TO WS-BALANCE-BAD
               END-IF
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
               MOVE "BATCH_CORE" TO WS-DENIED-TARGET
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       AUDIT-BATCH.
           MOVE "INSERT INTO batch_audit (action, actor_email, run_id, job_code, detail) VALUES (?, ?, NULLIF(?, ''), NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-RUN TO WS-BIND-3
           MOVE WS-AUDIT-JOB TO WS-BIND-4
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
           MOVE SPACES TO WS-AUDIT-RUN
           MOVE SPACES TO WS-AUDIT-JOB
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT-BATCH.
           EXIT PARAGRAPH.

       CHECK-JOB.
           MOVE 0 TO WS-JOB-FOUND
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-JOB-ID WS-JOB-TYPE WS-JOB-ENABLED
           MOVE "SELECT CONCAT(id, '|', job_type, '|', IF(enabled, '1', '0')) FROM batch_job WHERE job_code = ? LIMIT 1" TO WS-PREP-SQL
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
               WS-JOB-ID WS-JOB-TYPE WS-JOB-ENABLED
           END-UNSTRING
           MOVE 1 TO WS-JOB-FOUND.
           EXIT PARAGRAPH.

       CHECK-RUN.
           MOVE 0 TO WS-RUN-FOUND
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-RUN-STATUS WS-RUN-JOB-ID WS-RUN-LOCKED-BY
               WS-RUN-ATTEMPT WS-RUN-CHECK-KEY WS-RUN-CHECK-VAL
               WS-RUN-DATE WS-RUN-JOB-CODE
           MOVE "SELECT CONCAT(r.status, '|', r.job_id, '|', r.locked_by, '|', r.attempt, '|', COALESCE(r.checkpoint_key, ''), '|', COALESCE(r.checkpoint_value, ''), '|', r.business_date, '|', j.job_code) FROM batch_run r JOIN batch_job j ON j.id = r.job_id WHERE r.id = ? LIMIT 1" TO WS-PREP-SQL
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
               WS-RUN-STATUS WS-RUN-JOB-ID WS-RUN-LOCKED-BY
               WS-RUN-ATTEMPT WS-RUN-CHECK-KEY WS-RUN-CHECK-VAL
               WS-RUN-DATE WS-RUN-JOB-CODE
           END-UNSTRING
           MOVE 1 TO WS-RUN-FOUND.
           EXIT PARAGRAPH.

       CHECK-RUN-STEP.
           MOVE 0 TO WS-STEP-FOUND
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-STEP-ID WS-STEP-STATUS WS-STEP-ATTEMPT
               WS-STEP-CODE
           MOVE "SELECT CONCAT(id, '|', status, '|', attempt, '|', step_code) FROM batch_run_step WHERE run_id = ? AND step_no = ? LIMIT 1" TO WS-PREP-SQL
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
               WS-STEP-ID WS-STEP-STATUS WS-STEP-ATTEMPT WS-STEP-CODE
           END-UNSTRING
           MOVE 1 TO WS-STEP-FOUND.
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

       TRIM-PART2.
           MOVE 0 TO WS-PART2-LEN
           PERFORM VARYING WS-J FROM 16384 BY -1
               UNTIL WS-J < 1 OR WS-PART2-LEN > 0
               IF WS-PART2(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-PART2-LEN
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.

       TRIM-PART3.
           MOVE 0 TO WS-PART3-LEN
           PERFORM VARYING WS-J FROM 16384 BY -1
               UNTIL WS-J < 1 OR WS-PART3-LEN > 0
               IF WS-PART3(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-PART3-LEN
               END-IF
           END-PERFORM.
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

       ACTION-JOB-CREATE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED NOT = "EOD"
              AND WS-P3-TRIMMED NOT = "INTRADAY"
              AND WS-P3-TRIMMED NOT = "REPORT"
              AND WS-P3-TRIMMED NOT = "CLEANUP"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P4-TRIMMED NOT = "MANUAL"
              AND WS-P4-TRIMMED NOT = "DAILY"
              AND WS-P4-TRIMMED NOT = "WEEKLY"
              AND WS-P4-TRIMMED NOT = "MONTHLY"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM5 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-SCHED-TIME WS-MAX-RETRIES WS-TIMEOUT
           UNSTRING WS-P5-TRIMMED DELIMITED BY ","
               INTO WS-SCHED-TIME WS-MAX-RETRIES WS-TIMEOUT
           END-UNSTRING
           MOVE WS-SCHED-TIME TO WS-TIME-IN
           PERFORM VALIDATE-TIME-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-MAX-RETRIES TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) > 20
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-TIMEOUT TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) > 86400
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT 1 FROM batch_job WHERE job_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "1"
               MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO batch_job (job_code, name, job_type, frequency, schedule_time, enabled, created_by) VALUES (?, ?, ?, ?, ?, TRUE, ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-SCHED-TIME TO WS-BIND-5
           MOVE WS-P6-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
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
                   MOVE WS-RESULT(1:20) TO WS-JOB-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE batch_job SET max_retries = ?, timeout_seconds = ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-MAX-RETRIES TO WS-BIND-1
               MOVE WS-TIMEOUT TO WS-BIND-2
               MOVE WS-JOB-ID TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
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
               MOVE "JOB_CREATE" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-RUN
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-JOB
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|BATCH_JOB_CREATED|" DELIMITED BY SIZE
                      WS-JOB-ID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|DUPLICATE"
                   MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-JOB-LIST.
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
           IF LS-PARAM4 NOT = SPACES
               IF WS-P4-TRIMMED NOT = "0" AND WS-P4-TRIMMED NOT = "1"
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM batch_job WHERE (? = '' OR job_type = ?) AND (? = '' OR enabled = ?)" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(id, ':', job_code, ':', name, ':', job_type, ':', frequency, ':', IF(enabled, '1', '0'), ':', COALESCE(DATE_FORMAT(schedule_time, '%H:%i'), ''), ':', max_retries, ':', timeout_seconds) FROM batch_job WHERE (? = '' OR job_type = ?) AND (? = '' OR enabled = ?) ORDER BY job_code LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-LIMIT TO WS-BIND-5
           MOVE WS-OFFSET TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|BATCH_JOBS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|BATCH_JOBS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-JOB-UPDATE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-TRIMMED NOT = "0" AND WS-P2-TRIMMED NOT = "1"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED NOT = "MANUAL"
              AND WS-P3-TRIMMED NOT = "DAILY"
              AND WS-P3-TRIMMED NOT = "WEEKLY"
              AND WS-P3-TRIMMED NOT = "MONTHLY"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P4-TRIMMED(1:5) TO WS-TIME-IN
           PERFORM VALIDATE-TIME-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P5-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) > 20
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-JOB
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE batch_job SET enabled = ?, frequency = ?, schedule_time = ?, max_retries = ? WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P5-TRIMMED TO WS-BIND-4
           MOVE WS-JOB-ID TO WS-BIND-5
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
               MOVE "JOB_UPDATE" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-RUN
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-JOB
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|BATCH_JOB_UPDATED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-JOB-STEP-CREATE.
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
           MOVE WS-P1-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) < 1
              OR FUNCTION NUMVAL(WS-COUNT-IN) > 99
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P3-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM5 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-MAX-RETRIES WS-REQUIRED
           UNSTRING WS-P5-TRIMMED DELIMITED BY ","
               INTO WS-MAX-RETRIES WS-REQUIRED
           END-UNSTRING
           MOVE WS-MAX-RETRIES TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) > 20
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-REQUIRED NOT = "0" AND WS-REQUIRED NOT = "1"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-JOB
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT 1 FROM batch_job_step WHERE job_id = ? AND (step_no = ? OR step_code = ?) LIMIT 1" TO WS-PREP-SQL
           MOVE WS-JOB-ID TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "1"
               MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO batch_job_step (job_id, step_no, step_code, step_name, max_retries, is_required) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-JOB-ID TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-MAX-RETRIES TO WS-BIND-5
           MOVE WS-REQUIRED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
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
                   MOVE WS-RESULT(1:20) TO WS-STEP-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "STEP_CREATE" TO WS-AUDIT-ACTION
               MOVE SPACES TO WS-AUDIT-RUN
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-JOB
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|BATCH_STEP_CREATED|" DELIMITED BY SIZE
                      WS-STEP-ID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-JOB-STEP-LIST.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           PERFORM CHECK-JOB
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM batch_job_step WHERE job_id = ?" TO WS-PREP-SQL
           MOVE WS-JOB-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(step_no, ':', step_code, ':', step_name, ':', max_retries, ':', IF(is_required, '1', '0')) FROM batch_job_step WHERE job_id = ? ORDER BY step_no LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-JOB-ID TO WS-BIND-1
           MOVE WS-LIMIT TO WS-BIND-2
           MOVE WS-OFFSET TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|BATCH_STEPS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|BATCH_STEPS|" DELIMITED BY SIZE
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
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:40) TO WS-START-JOB-CODE
           MOVE WS-P2-TRIMMED(1:10) TO WS-START-DATE
           MOVE 0 TO WS-EOD-FLAG
           PERFORM START-RUN.
           EXIT PARAGRAPH.

       ACTION-EOD-START.
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
           MOVE WS-P1-TRIMMED(1:4) TO WS-DATE-COMPACT(1:4)
           MOVE WS-P1-TRIMMED(6:2) TO WS-DATE-COMPACT(5:2)
           MOVE WS-P1-TRIMMED(9:2) TO WS-DATE-COMPACT(7:2)
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-TODAY
           IF WS-DATE-COMPACT > WS-TODAY
               MOVE "ERROR|FUTURE_DATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED(1:40) TO WS-START-JOB-CODE
           MOVE WS-P1-TRIMMED(1:10) TO WS-START-DATE
           MOVE 1 TO WS-EOD-FLAG
           PERFORM START-RUN.
           EXIT PARAGRAPH.

       START-RUN.
           MOVE WS-START-JOB-CODE TO WS-P1-TRIMMED
           PERFORM CHECK-JOB
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-JOB-ENABLED NOT = "1"
               MOVE "ERROR|JOB_DISABLED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-EOD-FLAG = 1 AND WS-JOB-TYPE NOT = "EOD"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM batch_run WHERE job_id = ? AND business_date = ? AND status IN ('RUNNING', 'PAUSED')" TO WS-PREP-SQL
           MOVE WS-JOB-ID TO WS-BIND-1
           MOVE WS-START-DATE TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) NOT = "ERROR" AND FUNCTION NUMVAL(WS-RESULT) > 0
               MOVE "ERROR|RUN_ACTIVE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM batch_job_step WHERE job_id = ?" TO WS-PREP-SQL
           MOVE WS-JOB-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF FUNCTION NUMVAL(WS-RESULT) = 0
               MOVE "ERROR|NO_STEPS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COALESCE(MAX(attempt), 0) + 1 AS CHAR) FROM batch_run WHERE job_id = ? AND business_date = ?" TO WS-PREP-SQL
           MOVE WS-JOB-ID TO WS-BIND-1
           MOVE WS-START-DATE TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:10) TO WS-RUN-ATTEMPT
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO batch_run (job_id, business_date, status, attempt, locked_by, created_by) VALUES (?, ?, 'RUNNING', ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-JOB-ID TO WS-BIND-1
           MOVE WS-START-DATE TO WS-BIND-2
           MOVE WS-RUN-ATTEMPT TO WS-BIND-3
           MOVE WS-P6-TRIMMED TO WS-BIND-4
           MOVE WS-P6-TRIMMED TO WS-BIND-5
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
               MOVE "INSERT INTO batch_run_step (run_id, step_no, step_code, status, attempt) SELECT ?, step_no, step_code, 'PENDING', 0 FROM batch_job_step WHERE job_id = ? ORDER BY step_no" TO WS-PREP-SQL
               MOVE WS-RUN-ID TO WS-BIND-1
               MOVE WS-JOB-ID TO WS-BIND-2
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
               MOVE "RUN_START" TO WS-AUDIT-ACTION
               MOVE WS-RUN-ID TO WS-AUDIT-RUN
               MOVE WS-START-JOB-CODE TO WS-AUDIT-JOB
               MOVE WS-START-DATE TO WS-AUDIT-DETAIL
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|BATCH_RUN_STARTED|" DELIMITED BY SIZE
                      WS-RUN-ID DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RUN-ATTEMPT DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
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
           MOVE WS-P1-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(r.id, ':', j.job_code, ':', r.business_date, ':', r.status, ':', r.attempt, ':', r.processed_count, ':', r.success_count, ':', r.failed_count, ':', r.control_debit, ':', r.control_credit, ':', COALESCE(r.checkpoint_key, ''), ':', COALESCE(r.checkpoint_value, ''), ':', r.version, ':', COALESCE(r.error_code, '')) FROM batch_run r JOIN batch_job j ON j.id = r.job_id WHERE r.id = ? LIMIT 1" TO WS-PREP-SQL
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
           MOVE WS-RESULT TO WS-PART
           PERFORM TRIM-PART
           MOVE SPACES TO WS-PART2
           MOVE 0 TO WS-PART2-LEN
           MOVE SPACES TO WS-PART3
           MOVE 0 TO WS-PART3-LEN
           IF WS-P2-TRIMMED = "1"
               MOVE "SELECT CONCAT(step_no, ':', step_code, ':', status, ':', attempt, ':', processed_count, ':', success_count, ':', failed_count, ':', control_debit, ':', control_credit) FROM batch_run_step WHERE run_id = ? ORDER BY step_no" TO WS-PREP-SQL
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
               IF WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE WS-RESULT TO WS-PART2
                   PERFORM TRIM-PART2
               END-IF
               MOVE "SELECT CONCAT(total_code, ':', expected_amount, ':', actual_amount, ':', variance, ':', status) FROM batch_control_total WHERE run_id = ? ORDER BY total_code" TO WS-PREP-SQL
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
               IF WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE WS-RESULT TO WS-PART3
                   PERFORM TRIM-PART3
               END-IF
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|BATCH_RUN|" DELIMITED BY SIZE
                  WS-PART(1:WS-PART-LEN) DELIMITED BY SIZE "|" DELIMITED BY SIZE
                  WS-PART2(1:WS-PART2-LEN) DELIMITED BY SIZE "|" DELIMITED BY SIZE
                  WS-PART3(1:WS-PART3-LEN) DELIMITED BY SIZE
                  INTO LS-OUTPUT-BUFFER
           END-STRING.
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
               IF WS-P3-TRIMMED NOT = "RUNNING"
                  AND WS-P3-TRIMMED NOT = "PAUSED"
                  AND WS-P3-TRIMMED NOT = "COMPLETED"
                  AND WS-P3-TRIMMED NOT = "FAILED"
                  AND WS-P3-TRIMMED NOT = "CANCELLED"
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF LS-PARAM4 NOT = SPACES
               MOVE WS-P4-TRIMMED TO WS-CODE-IN
               PERFORM VALIDATE-CODE-FIELD
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF LS-PARAM5 NOT = SPACES
               MOVE WS-P5-TRIMMED TO WS-DATE-IN
               PERFORM VALIDATE-DATE-FIELD
               IF WS-BAD > 0
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM batch_run r JOIN batch_job j ON j.id = r.job_id WHERE r.status = COALESCE(NULLIF(?, ''), r.status) AND j.job_code = COALESCE(NULLIF(?, ''), j.job_code) AND r.business_date = COALESCE(NULLIF(?, ''), r.business_date)" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P4-TRIMMED TO WS-BIND-2
           MOVE WS-P5-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(r.id, ':', j.job_code, ':', r.business_date, ':', r.status, ':', r.attempt, ':', r.processed_count, ':', r.success_count, ':', r.failed_count, ':', r.control_debit, ':', r.control_credit) FROM batch_run r JOIN batch_job j ON j.id = r.job_id WHERE r.status = COALESCE(NULLIF(?, ''), r.status) AND j.job_code = COALESCE(NULLIF(?, ''), j.job_code) AND r.business_date = COALESCE(NULLIF(?, ''), r.business_date) ORDER BY r.id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P4-TRIMMED TO WS-BIND-2
           MOVE WS-P5-TRIMMED TO WS-BIND-3
           MOVE WS-LIMIT TO WS-BIND-4
           MOVE WS-OFFSET TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|BATCH_RUNS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|BATCH_RUNS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-CHECKPOINT.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM4 = SPACES OR LS-PARAM5 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P4-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-DEBIT WS-CREDIT
           UNSTRING WS-P5-TRIMMED DELIMITED BY ","
               INTO WS-DEBIT WS-CREDIT
           END-UNSTRING
           MOVE WS-DEBIT TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-CREDIT TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BALANCE
           IF WS-BALANCE-BAD = 1
               MOVE "ERROR|UNBALANCED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-BALANCE-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
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
           IF WS-RUN-LOCKED-BY NOT = WS-P6-TRIMMED
               MOVE "ERROR|RUN_LOCKED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE batch_run SET checkpoint_key = ?, checkpoint_value = ?, processed_count = ?, control_debit = ?, control_credit = ?, version = version + 1 WHERE id = ? AND status = 'RUNNING'" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-DEBIT TO WS-BIND-4
           MOVE WS-CREDIT TO WS-BIND-5
           MOVE WS-P1-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
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
               MOVE "SELECT version FROM batch_run WHERE id = ? LIMIT 1" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:10) TO WS-RUN-VERSION
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "RUN_CHECKPOINT" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RUN
               MOVE WS-RUN-JOB-CODE TO WS-AUDIT-JOB
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|BATCH_CHECKPOINT|" DELIMITED BY SIZE
                      WS-RUN-VERSION DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-COMPLETE.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-COUNT1 WS-COUNT2 WS-COUNT3
           UNSTRING WS-P2-TRIMMED DELIMITED BY ","
               INTO WS-COUNT1 WS-COUNT2 WS-COUNT3
           END-UNSTRING
           MOVE WS-COUNT1 TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-COUNT2 TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-COUNT3 TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-DEBIT WS-CREDIT
           UNSTRING WS-P3-TRIMMED DELIMITED BY ","
               INTO WS-DEBIT WS-CREDIT
           END-UNSTRING
           MOVE WS-DEBIT TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-CREDIT TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BALANCE
           IF WS-BALANCE-BAD = 1
               MOVE "ERROR|UNBALANCED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-BALANCE-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
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
           IF WS-RUN-LOCKED-BY NOT = WS-P6-TRIMMED
               MOVE "ERROR|RUN_LOCKED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM batch_run_step rs JOIN batch_job_step js ON js.job_id = (SELECT job_id FROM batch_run WHERE id = ?) AND js.step_no = rs.step_no WHERE rs.run_id = ? AND js.is_required = TRUE AND rs.status <> 'COMPLETED'" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF FUNCTION NUMVAL(WS-RESULT) > 0
               MOVE "ERROR|STEPS_INCOMPLETE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM batch_control_total WHERE run_id = ? AND status = 'VARIANCE'" TO WS-PREP-SQL
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
               MOVE "ERROR|CONTROL_VARIANCE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE batch_run SET status = 'COMPLETED', processed_count = ?, success_count = ?, failed_count = ?, control_debit = ?, control_credit = ?, finished_at = NOW(), version = version + 1 WHERE id = ? AND status = 'RUNNING'" TO WS-PREP-SQL
           MOVE WS-COUNT1 TO WS-BIND-1
           MOVE WS-COUNT2 TO WS-BIND-2
           MOVE WS-COUNT3 TO WS-BIND-3
           MOVE WS-DEBIT TO WS-BIND-4
           MOVE WS-CREDIT TO WS-BIND-5
           MOVE WS-P1-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
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
               MOVE "RUN_COMPLETE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RUN
               MOVE WS-RUN-JOB-CODE TO WS-AUDIT-JOB
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|BATCH_RUN_COMPLETED" TO LS-OUTPUT-BUFFER
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
           MOVE WS-P1-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
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
           IF WS-RUN-LOCKED-BY NOT = WS-P6-TRIMMED
               MOVE "ERROR|RUN_LOCKED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE batch_run SET status = 'FAILED', error_code = ?, error_detail = ?, finished_at = NOW(), version = version + 1 WHERE id = ? AND status = 'RUNNING'" TO WS-PREP-SQL
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
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RUN
               MOVE WS-RUN-JOB-CODE TO WS-AUDIT-JOB
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|BATCH_RUN_FAILED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_STATUS"
                   MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-RETRY.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
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
           IF WS-RUN-STATUS NOT = "FAILED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT IF(enabled, '1', '0') FROM batch_job WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-RUN-JOB-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "0"
               MOVE "ERROR|JOB_DISABLED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           COMPUTE WS-NEW-ATTEMPT = FUNCTION NUMVAL(WS-RUN-ATTEMPT) + 1 END-COMPUTE
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO batch_run (job_id, business_date, status, attempt, checkpoint_key, checkpoint_value, locked_by, created_by) SELECT job_id, business_date, 'RUNNING', attempt + 1, checkpoint_key, checkpoint_value, ?, ? FROM batch_run WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P6-TRIMMED TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-P1-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|NOT_FOUND" TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
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
               MOVE "INSERT INTO batch_run_step (run_id, step_no, step_code, status, attempt) SELECT ?, step_no, step_code, 'PENDING', 0 FROM batch_job_step WHERE job_id = (SELECT job_id FROM batch_run WHERE id = ?) ORDER BY step_no" TO WS-PREP-SQL
               MOVE WS-RUN-ID TO WS-BIND-1
               MOVE WS-P1-TRIMMED TO WS-BIND-2
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
               MOVE "RUN_RETRY" TO WS-AUDIT-ACTION
               MOVE WS-RUN-ID TO WS-AUDIT-RUN
               MOVE WS-RUN-JOB-CODE TO WS-AUDIT-JOB
               MOVE WS-RUN-ATTEMPT TO WS-AUDIT-DETAIL
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               MOVE WS-NEW-ATTEMPT TO WS-NEW-ATTEMPT-ED
               STRING "SUCCESS|BATCH_RUN_RETRIED|" DELIMITED BY SIZE
                      WS-RUN-ID DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      FUNCTION TRIM(WS-NEW-ATTEMPT-ED) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|NOT_FOUND"
                   MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RUN-STEP.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
              OR LS-PARAM5 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 OR FUNCTION NUMVAL(WS-COUNT-IN) < 1
              OR FUNCTION NUMVAL(WS-COUNT-IN) > 99
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED NOT = "PENDING"
              AND WS-P3-TRIMMED NOT = "RUNNING"
              AND WS-P3-TRIMMED NOT = "COMPLETED"
              AND WS-P3-TRIMMED NOT = "FAILED"
              AND WS-P3-TRIMMED NOT = "SKIPPED"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-COUNT1 WS-COUNT2 WS-COUNT3
           UNSTRING WS-P4-TRIMMED DELIMITED BY ","
               INTO WS-COUNT1 WS-COUNT2 WS-COUNT3
           END-UNSTRING
           MOVE WS-COUNT1 TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-COUNT2 TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-COUNT3 TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-DEBIT WS-CREDIT
           UNSTRING WS-P5-TRIMMED DELIMITED BY ","
               INTO WS-DEBIT WS-CREDIT
           END-UNSTRING
           MOVE WS-DEBIT TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-CREDIT TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BALANCE
           IF WS-BALANCE-BAD = 1
               MOVE "ERROR|UNBALANCED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-BALANCE-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
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
           IF WS-RUN-LOCKED-BY NOT = WS-P6-TRIMMED
               MOVE "ERROR|RUN_LOCKED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-RUN-STEP
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-STEP-STATUS = "PENDING"
               IF WS-P3-TRIMMED NOT = "RUNNING"
                  AND WS-P3-TRIMMED NOT = "SKIPPED"
                  AND WS-P3-TRIMMED NOT = "FAILED"
                   MOVE "ERROR|INVALID_TRANSITION" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           ELSE
               IF WS-STEP-STATUS = "RUNNING"
                   IF WS-P3-TRIMMED NOT = "COMPLETED"
                      AND WS-P3-TRIMMED NOT = "FAILED"
                       MOVE "ERROR|INVALID_TRANSITION" TO LS-OUTPUT-BUFFER
                       EXIT PARAGRAPH
                   END-IF
               ELSE
                   MOVE "ERROR|INVALID_TRANSITION" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           COMPUTE WS-STEP-ATTEMPT-N = FUNCTION NUMVAL(WS-STEP-ATTEMPT) END-COMPUTE
           IF WS-P3-TRIMMED = "RUNNING"
               ADD 1 TO WS-STEP-ATTEMPT-N END-ADD
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE batch_run_step SET status = ?, attempt = ? WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-STEP-ATTEMPT-N TO WS-BIND-2
           MOVE WS-STEP-ID TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE batch_run_step SET started_at = NOW() WHERE id = ? AND status = 'RUNNING' AND started_at IS NULL" TO WS-PREP-SQL
               MOVE WS-STEP-ID TO WS-BIND-1
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
               MOVE "UPDATE batch_run_step SET finished_at = NOW() WHERE id = ? AND status IN ('COMPLETED', 'FAILED', 'SKIPPED') AND finished_at IS NULL" TO WS-PREP-SQL
               MOVE WS-STEP-ID TO WS-BIND-1
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
               MOVE "UPDATE batch_run_step SET processed_count = ?, success_count = ?, failed_count = ?, control_debit = ?, control_credit = ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-COUNT1 TO WS-BIND-1
               MOVE WS-COUNT2 TO WS-BIND-2
               MOVE WS-COUNT3 TO WS-BIND-3
               MOVE WS-DEBIT TO WS-BIND-4
               MOVE WS-CREDIT TO WS-BIND-5
               MOVE WS-STEP-ID TO WS-BIND-6
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
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
               MOVE "STEP_UPDATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RUN
               MOVE WS-RUN-JOB-CODE TO WS-AUDIT-JOB
               MOVE SPACES TO WS-AUDIT-DETAIL
               STRING WS-P2-TRIMMED DELIMITED BY SPACE ":"
                      WS-P3-TRIMMED DELIMITED BY SPACE
                      INTO WS-AUDIT-DETAIL
               END-STRING
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|BATCH_STEP_UPDATED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-CONTROL-TOTAL.
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
           MOVE WS-P1-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P3-TRIMMED(1:30) TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P4-TRIMMED(1:30) TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
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
           IF WS-RUN-LOCKED-BY NOT = WS-P6-TRIMMED
               MOVE "ERROR|RUN_LOCKED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO batch_control_total (run_id, total_code, expected_amount, actual_amount, variance, status) VALUES (?, ?, ?, ?, 0, 'MATCH') ON DUPLICATE KEY UPDATE expected_amount = VALUES(expected_amount), actual_amount = VALUES(actual_amount)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE batch_control_total SET variance = ABS(expected_amount - actual_amount), status = IF(expected_amount = actual_amount, 'MATCH', 'VARIANCE') WHERE run_id = ? AND total_code = ?" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               MOVE WS-P2-TRIMMED TO WS-BIND-2
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
               MOVE "SELECT status FROM batch_control_total WHERE run_id = ? AND total_code = ? LIMIT 1" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               MOVE WS-P2-TRIMMED TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-TOTAL
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "CONTROL_TOTAL" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:20) TO WS-AUDIT-RUN
               MOVE WS-RUN-JOB-CODE TO WS-AUDIT-JOB
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-BATCH
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|BATCH_CONTROL|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.
