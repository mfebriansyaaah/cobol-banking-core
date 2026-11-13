       IDENTIFICATION DIVISION.
       PROGRAM-ID. collection_core.
      *> Collections: delinquency cases, contact history, promises, recovery.

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
       01  WS-J                    PIC 9(5) VALUE 1.
       01  WS-RLEN                 PIC 9(5) VALUE 1.
       01  WS-BAD                  PIC 9(3) VALUE 0.
       01  WS-ALLOWED              PIC 9 VALUE 0.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-IDEM-STATUS          PIC X(10) VALUE SPACES.
       01  WS-IDEM-OWNED           PIC X VALUE "0".
       01  WS-IDEM-ROW             PIC X(200) VALUE SPACES.
       01  WS-IDEM-AMT             PIC X(30) VALUE SPACES.
       01  WS-IDEM-STALE           PIC X VALUE SPACES.
       01  WS-IDEM-SCOPE           PIC X(32) VALUE SPACES.
       01  WS-IDEM-ENTITY-VAL      PIC X(64) VALUE SPACES.
       01  WS-IDEM-KEY             PIC X(64) VALUE SPACES.
       01  WS-IDEM-AMOUNT          PIC X(30) VALUE SPACES.
       01  WS-IDEM-DETAILS         PIC X(500) VALUE SPACES.
       01  WS-IDEM-CODE            PIC X(40) VALUE SPACES.
       01  WS-IDEM-TABLE           PIC X(40) VALUE SPACES.
       01  WS-IDEM-ENTITY          PIC X(30) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-CASE           PIC X(100) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-TMP-AMT              PIC X(30) VALUE SPACES.
       01  WS-TMP-STATUS           PIC X(20) VALUE SPACES.
       01  WS-TMP-CURR             PIC X(10) VALUE SPACES.
       01  WS-TMP-STR              PIC X(100) VALUE SPACES.
       01  WS-TMP-TEXT             PIC X(100) VALUE SPACES.
       01  WS-NUM-AMOUNT           PIC 9(15)V9(4) VALUE 0.
       01  WS-PAY-AMT              PIC Z(18)9.9999 VALUE 0.
       01  WS-NUM-LIMIT            PIC 9(15)V9(4) VALUE 0.
       01  WS-NUM-AVAIL            PIC 9(15)V9(4) VALUE 0.
       01  WS-NUM-BALANCE          PIC 9(15)V9(4) VALUE 0.
       01  WS-NEW-ID               PIC X(20) VALUE SPACES.
       01  WS-NUM-OVERDUE          PIC 9(15)V9(4) VALUE 0.
       01  WS-NUM-RECOVERED        PIC 9(15)V9(4) VALUE 0.
       01  WS-NUM-INT              PIC 9(9) VALUE 0.
       01  WS-TMP-DATE             PIC X(30) VALUE SPACES.
       01  WS-TMP-EMAIL            PIC X(100) VALUE SPACES.
       01  WS-TMP-NOTE             PIC X(255) VALUE SPACES.
       01  WS-TMP-CHANNEL          PIC X(20) VALUE SPACES.
       01  WS-TMP-LEVEL            PIC X(10) VALUE SPACES.
       01  WS-TMP-PRIORITY         PIC X(100) VALUE SPACES.
       01  WS-ACT-TYPE             PIC X(20) VALUE SPACES.
       01  WS-ACT-CHANNEL          PIC X(100) VALUE SPACES.
       01  WS-ACT-NOTE             PIC X(255) VALUE SPACES.
       01  WS-ACT-AMOUNT           PIC X(100) VALUE SPACES.
       01  WS-TMP-ASSIGNED         PIC X(100) VALUE SPACES.
       01  WS-TMP-ID               PIC X(100) VALUE SPACES.
       01  WS-AGE-WHERE            PIC X(120) VALUE SPACES.
       01  WS-AGE-1                PIC X(100) VALUE SPACES.
       01  WS-AGE-2                PIC X(100) VALUE SPACES.
       01  WS-AGE-3                PIC X(100) VALUE SPACES.
       01  WS-AGE-4                PIC X(100) VALUE SPACES.
       01  WS-AGE-5                PIC X(100) VALUE SPACES.
       01  WS-AGE-OK               PIC X VALUE 'N'.
           88  AGE-OK              VALUE 'Y'.
       01  WS-NUM-PROMISE          PIC 9(15)V9(4) VALUE 0.
       01  WS-NUM-OUT              PIC 9(15)V9(4) VALUE 0.
       01  WS-LOAN-OK              PIC X VALUE 'N'.
           88  LOAN-FOUND          VALUE 'Y'.
       01  WS-OVERDUE-OK           PIC X VALUE 'N'.
           88  OVERDUE-READY       VALUE 'Y'.
       01  WS-CASE-OK              PIC X VALUE 'N'.
           88  CASE-FOUND          VALUE 'Y'.
       01  F-QUOTE                 PIC X VALUE "'".
       01  F-DQUOTE                PIC X VALUE '"'.
       01  F-BSLASH                PIC X VALUE "\".
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
               WHEN LS-CMD-ACTION(1:8) = "COL_OPEN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-OPEN
               WHEN LS-CMD-ACTION(1:8) = "COL_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-LIST
               WHEN LS-CMD-ACTION(1:7) = "COL_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-GET
               WHEN LS-CMD-ACTION(1:10) = "COL_ASSIGN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ASSIGN
               WHEN LS-CMD-ACTION(1:11) = "COL_CONTACT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CONTACT
               WHEN LS-CMD-ACTION(1:11) = "COL_PROMISE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-PROMISE
               WHEN LS-CMD-ACTION(1:7) = "COL_PAY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-PAY
               WHEN LS-CMD-ACTION(1:12) = "COL_ESCALATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-ESCALATE
               WHEN LS-CMD-ACTION(1:9) = "COL_CLOSE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-CLOSE
               WHEN LS-CMD-ACTION(1:10) = "COL_REOPEN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-REOPEN
               WHEN LS-CMD-ACTION(1:11) = "COL_SUMMARY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-SUMMARY
               WHEN LS-CMD-ACTION(1:9) = "COL_AGING"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-AGING
               WHEN LS-CMD-ACTION(1:11) = "COL_HISTORY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-HISTORY
               WHEN LS-CMD-ACTION(1:9) = "COL_AUDIT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-AUDIT
               WHEN LS-CMD-ACTION(1:12) = "COL_VALIDATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VALIDATE
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_validate_all.cpy".
        COPY "common_sql.cpy".



        COPY "common_trim.cpy".

        COPY "common_auth.cpy".

       AUDIT.
           MOVE "INSERT INTO collection_audit (action, actor_email, case_id, detail) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-CASE TO WS-BIND-3
           MOVE WS-AUDIT-DETAIL TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
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
           MOVE SPACES TO WS-AUDIT-CASE
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT.
           EXIT PARAGRAPH.

        COPY "common_result.cpy".

        COPY "common_idem.cpy".


      *> Load the loan facts a case is built from. Sets WS-ERR on failure.
       CHECK-LOAN.
           MOVE 'N' TO WS-LOAN-OK
           MOVE SPACES TO WS-ERR
           MOVE "SELECT CONCAT(customer_email, '|', currency, '|', status) FROM loan_application WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO WS-ERR
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-TMP-EMAIL
           MOVE SPACES TO WS-TMP-CURR
           MOVE SPACES TO WS-TMP-STATUS
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-EMAIL WS-TMP-CURR WS-TMP-STATUS END-UNSTRING
           IF WS-TMP-STATUS(1:9) NOT = "DISBURSED"
               MOVE "ERROR|INVALID_STATUS" TO WS-ERR
               EXIT PARAGRAPH
           END-IF
           MOVE 'Y' TO WS-LOAN-OK.
           EXIT PARAGRAPH.

      *> Compute the overdue amount for a loan (P2) or a single installment
      *> (P3). Aggregates every due, unpaid installment when P3 is blank.
       CALC-OVERDUE.
           MOVE 'N' TO WS-OVERDUE-OK
           MOVE SPACES TO WS-ERR
           MOVE SPACES TO WS-TMP-DATE
           IF WS-P3-TRIMMED = SPACES
               MOVE "SELECT CONCAT(COALESCE(SUM(i.total_due - i.paid_amount), 0), '|', COALESCE(CAST(MIN(i.due_date) AS CHAR), '')) FROM loan_installment i JOIN loan_schedule s ON s.id = i.schedule_id WHERE s.loan_id = ? AND i.status IN ('PENDING','DUE','PARTIAL') AND i.due_date < CURDATE()" TO WS-PREP-SQL
               MOVE WS-P2-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           ELSE
               MOVE "SELECT CONCAT(i.total_due - i.paid_amount, '|', CAST(i.due_date AS CHAR)) FROM loan_installment i JOIN loan_schedule s ON s.id = i.schedule_id WHERE i.id = ? AND s.loan_id = ? AND i.status IN ('PENDING','DUE','PARTIAL') LIMIT 1" TO WS-PREP-SQL
               MOVE WS-P3-TRIMMED TO WS-BIND-1
               MOVE WS-P2-TRIMMED TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
           END-IF
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO WS-ERR
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-TMP-AMT
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-TMP-AMT WS-TMP-DATE END-UNSTRING
           MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-OVERDUE
           IF WS-NUM-OVERDUE <= 0
               MOVE "ERROR|NO_OVERDUE" TO WS-ERR
               EXIT PARAGRAPH
           END-IF
           MOVE 'Y' TO WS-OVERDUE-OK.
           EXIT PARAGRAPH.

      *> Load one case by id (P1) into the WS-TMP-* fields.
       LOAD-CASE.
           MOVE 'N' TO WS-CASE-OK
           MOVE SPACES TO WS-ERR
           MOVE "SELECT CONCAT(id, '|', customer_email, '|', currency, '|', overdue_amount, '|', recovered_amount, '|', status, '|', COALESCE(assigned_to, ''), '|', COALESCE(promise_date, ''), '|', promise_amount, '|', escalation_level) FROM collection_case WHERE id = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|NOT_FOUND" TO WS-ERR
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO WS-ERR
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-TMP-ID
           MOVE SPACES TO WS-TMP-EMAIL
           MOVE SPACES TO WS-TMP-CURR
           MOVE SPACES TO WS-TMP-AMT
           MOVE SPACES TO WS-TMP-STR
           MOVE SPACES TO WS-TMP-STATUS
           MOVE SPACES TO WS-TMP-ASSIGNED
           MOVE SPACES TO WS-TMP-DATE
           MOVE SPACES TO WS-TMP-NOTE
           MOVE SPACES TO WS-TMP-LEVEL
           UNSTRING WS-RESULT DELIMITED BY "|" INTO
               WS-TMP-ID WS-TMP-EMAIL WS-TMP-CURR WS-TMP-AMT WS-TMP-STR
               WS-TMP-STATUS WS-TMP-ASSIGNED WS-TMP-DATE WS-TMP-NOTE WS-TMP-LEVEL
           END-UNSTRING
           MOVE FUNCTION NUMVAL(WS-TMP-AMT) TO WS-NUM-OVERDUE
           MOVE FUNCTION NUMVAL(WS-TMP-STR) TO WS-NUM-RECOVERED
           MOVE FUNCTION NUMVAL(WS-TMP-NOTE) TO WS-NUM-PROMISE
           MOVE 'Y' TO WS-CASE-OK.
           EXIT PARAGRAPH.

      *> Append one row to the case activity feed. Caller sets WS-ACT-*.
       ADD-ACTIVITY.
           MOVE "INSERT INTO collection_activity (case_id, activity_type, channel, note, amount, actor_email) VALUES (?, ?, NULLIF(?, ''), NULLIF(?, ''), ?, ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-ACT-TYPE TO WS-BIND-2
           MOVE WS-ACT-CHANNEL TO WS-BIND-3
           MOVE WS-ACT-NOTE TO WS-BIND-4
           MOVE WS-ACT-AMOUNT TO WS-BIND-5
           MOVE WS-P6-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

       CLAIM-PAY-REQUEST.
      *> Client-supplied idempotency for COL_PAY (P5), mirroring the
      *> loan/card request tables. First call with a key inserts a PENDING
      *> request row and owns it; a repeated key replays the stored DONE
      *> outcome (or conflicts on a different amount) instead of
      *> recording another payment; a key whose owner is still working
      *> is refused (PAY_IN_PROGRESS) so two owners never double-count.
      *> A PENDING row older than 5 minutes is taken over (owner
      *> crashed). WS-ERR on refusal. Dual-write via common_idem.cpy:
      *> every transition is mirrored to idempotency_request while the
      *> legacy row stays the decision-maker.
           MOVE "COL_PAY" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-PAY-AMT) TO WS-IDEM-AMOUNT
           MOVE SPACES TO WS-IDEM-DETAILS
           MOVE "ERROR|PAY_IN_PROGRESS" TO WS-IDEM-CODE
           PERFORM IDEM-CLAIM.
           EXIT PARAGRAPH.

       DELETE-PAY-REQUEST.
      *> Drops our own PENDING request row when the action is refused
      *> before recording, so the key stays usable instead of blocking
      *> behind a 5-minute stale window. Only the owner row is ever
      *> removed (status guard); DONE rows are never touched. The
      *> unified mirror row goes with it.
           MOVE "COL_PAY" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       ACTION-OPEN.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-TMP-ID
           MOVE "NORMAL" TO WS-TMP-PRIORITY
           IF WS-P4-TRIMMED NOT = SPACES
               IF WS-P4-TRIMMED NOT = "LOW" AND WS-P4-TRIMMED NOT = "NORMAL"
                   AND WS-P4-TRIMMED NOT = "HIGH" AND WS-P4-TRIMMED NOT = "CRITICAL"
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE WS-P4-TRIMMED TO WS-TMP-PRIORITY
           END-IF.
           PERFORM CHECK-LOAN
           IF NOT LOAN-FOUND
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CALC-OVERDUE
           IF NOT OVERDUE-READY
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT 1 FROM collection_case WHERE case_ref = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) NOT = "ERROR"
               MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO collection_case (case_ref, loan_id, installment_id, customer_email, currency, opened_by) VALUES (?, ?, NULLIF(?, ''), ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-TMP-EMAIL TO WS-BIND-4
           MOVE WS-TMP-CURR TO WS-BIND-5
           MOVE WS-P6-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
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
               MOVE "UPDATE collection_case SET overdue_amount = ?, oldest_due_date = NULLIF(?, ''), priority = ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-TMP-AMT TO WS-BIND-1
               MOVE WS-TMP-DATE TO WS-BIND-2
               MOVE WS-TMP-PRIORITY TO WS-BIND-3
               MOVE WS-NEW-ID TO WS-BIND-4
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
               MOVE WS-NEW-ID TO WS-P1-TRIMMED
               MOVE "STATUS" TO WS-ACT-TYPE
               MOVE SPACES TO WS-ACT-CHANNEL
               MOVE "Case opened" TO WS-ACT-NOTE
               MOVE "0" TO WS-ACT-AMOUNT
               PERFORM ADD-ACTIVITY
           END-IF.
           IF STEP-OK
               MOVE "OPEN" TO WS-AUDIT-ACTION
               MOVE WS-NEW-ID TO WS-AUDIT-CASE
               MOVE WS-TMP-ID TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|COL_OPEN|" DELIMITED BY SIZE FUNCTION TRIM(WS-NEW-ID) DELIMITED BY SIZE
                   "|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VALIDATE.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
      *> VALIDATE takes (loan, installment, ...) while CHECK-LOAN and
      *> CALC-OVERDUE expect the OPEN layout (ref, loan, installment, ...).
           MOVE WS-P2-TRIMMED TO WS-P3-TRIMMED
           MOVE WS-P2-LEN TO WS-P3-LEN
           MOVE WS-P1-TRIMMED TO WS-P2-TRIMMED
           MOVE WS-P1-LEN TO WS-P2-LEN
           PERFORM CHECK-LOAN
           IF NOT LOAN-FOUND
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CALC-OVERDUE
           IF NOT OVERDUE-READY
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|COL_VALID|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE
               "|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-CURR) DELIMITED BY SIZE
               "|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-DATE) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-LIST.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P1-TRIMMED NOT = SPACES
               IF WS-P1-TRIMMED NOT = "OPEN" AND WS-P1-TRIMMED NOT = "PROMISE"
                   AND WS-P1-TRIMMED NOT = "ESCALATED" AND WS-P1-TRIMMED NOT = "CLOSED"
                   AND WS-P1-TRIMMED NOT = "CANCELLED"
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF WS-P2-TRIMMED NOT = SPACES
               IF WS-P2-TRIMMED NOT = "LOW" AND WS-P2-TRIMMED NOT = "NORMAL"
                   AND WS-P2-TRIMMED NOT = "HIGH" AND WS-P2-TRIMMED NOT = "CRITICAL"
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF WS-P3-TRIMMED NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-LIMIT
           END-IF.
           IF WS-P4-TRIMMED NOT = SPACES
               MOVE WS-P4-TRIMMED(1:WS-P4-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CONCAT(id, ':', case_ref, ':', customer_email, ':', status, ':', priority, ':', overdue_amount, ':', recovered_amount, ':', COALESCE(assigned_to, '')) FROM collection_case WHERE (? = '' OR status = ?) AND (? = '' OR priority = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           MOVE WS-P2-TRIMMED TO WS-BIND-4
           MOVE WS-LIMIT TO WS-BIND-5
           MOVE WS-OFFSET TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|COL_LIST|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|COL_LIST|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-GET.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(id, '|', case_ref, '|', loan_id, '|', COALESCE(installment_id, ''), '|', customer_email, '|', currency, '|', overdue_amount, '|', recovered_amount, '|', priority, '|', status, '|', COALESCE(assigned_to, ''), '|', COALESCE(promise_date, ''), '|', promise_amount, '|', escalation_level, '|', COALESCE(resolution, ''), '|', COALESCE(CAST(oldest_due_date AS CHAR), '')) FROM collection_case WHERE id = ? LIMIT 1" TO WS-PREP-SQL
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
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|COL_GET|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-ASSIGN.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR WS-P2-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM LOAD-CASE
           IF NOT CASE-FOUND
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-TMP-STATUS(1:6) = "CLOSED" OR WS-TMP-STATUS(1:9) = "CANCELLED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT status FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
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
           IF WS-RESULT(1:8) NOT = "VERIFIED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE collection_case SET assigned_to = ? WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "ASSIGNMENT" TO WS-ACT-TYPE
               MOVE SPACES TO WS-ACT-CHANNEL
               MOVE SPACES TO WS-ACT-NOTE
               STRING "Assigned to " DELIMITED BY SIZE WS-P2-TRIMMED DELIMITED BY SIZE INTO WS-ACT-NOTE END-STRING
               MOVE "0" TO WS-ACT-AMOUNT
               PERFORM ADD-ACTIVITY
           END-IF.
           IF STEP-OK
               MOVE "ASSIGN" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-CASE
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|COL_ASSIGNED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-CONTACT.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR WS-P2-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-TRIMMED NOT = "CALL" AND WS-P2-TRIMMED NOT = "EMAIL"
               AND WS-P2-TRIMMED NOT = "SMS" AND WS-P2-TRIMMED NOT = "LETTER"
               AND WS-P2-TRIMMED NOT = "IN_PERSON"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM LOAD-CASE
           IF NOT CASE-FOUND
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-TMP-STATUS(1:6) = "CLOSED" OR WS-TMP-STATUS(1:9) = "CANCELLED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "CONTACT" TO WS-ACT-TYPE
           MOVE WS-P2-TRIMMED TO WS-ACT-CHANNEL
           MOVE WS-P3-TRIMMED TO WS-ACT-NOTE
           MOVE "0" TO WS-ACT-AMOUNT
           PERFORM ADD-ACTIVITY
           IF STEP-OK
               MOVE "CONTACT" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-CASE
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|COL_CONTACT" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-PROMISE.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR WS-P2-TRIMMED = SPACES OR WS-P3-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-P3-TRIMMED) TO WS-NUM-AMOUNT
           IF WS-NUM-AMOUNT <= 0
               MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM LOAD-CASE
           IF NOT CASE-FOUND
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-TMP-STATUS(1:6) = "CLOSED" OR WS-TMP-STATUS(1:9) = "CANCELLED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           COMPUTE WS-NUM-OUT = WS-NUM-OVERDUE - WS-NUM-RECOVERED END-COMPUTE
           IF WS-NUM-AMOUNT > WS-NUM-OUT
               MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT (? >= CURDATE())" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR" OR WS-RESULT(1:1) = "0"
               MOVE "ERROR|INVALID_DATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE collection_case SET promise_date = ?, promise_amount = ?, status = 'PROMISE' WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P1-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "PROMISE" TO WS-ACT-TYPE
               MOVE SPACES TO WS-ACT-CHANNEL
               MOVE SPACES TO WS-ACT-NOTE
               STRING "Promise for " DELIMITED BY SIZE WS-P2-TRIMMED DELIMITED BY SIZE INTO WS-ACT-NOTE END-STRING
               MOVE WS-P3-TRIMMED TO WS-ACT-AMOUNT
               PERFORM ADD-ACTIVITY
           END-IF.
           IF STEP-OK
               MOVE "PROMISE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-CASE
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|COL_PROMISE|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE
                   "|" DELIMITED BY SIZE FUNCTION TRIM(WS-P3-TRIMMED) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-PAY.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR WS-P2-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT
           IF WS-NUM-AMOUNT <= 0
               MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-NUM-AMOUNT TO WS-PAY-AMT
           PERFORM LOAD-CASE
           IF NOT CASE-FOUND
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P5-TRIMMED NOT = SPACES
               PERFORM CLAIM-PAY-REQUEST
               IF WS-ERR NOT = SPACES
                   MOVE WS-ERR TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "DONE"
                   MOVE "SELECT GREATEST(overdue_amount - recovered_amount, 0) FROM collection_case WHERE id = ?" TO WS-PREP-SQL
                   MOVE WS-P1-TRIMMED TO WS-BIND-1
                   CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                       BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                       BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                   END-CALL
                   CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                   IF WS-RESULT(1:5) = "ERROR"
                       MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                       EXIT PARAGRAPH
                   END-IF
                   PERFORM TRIM-RESULT-LEN
                   MOVE WS-RESULT(1:WS-RLEN) TO WS-TMP-STR
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING "SUCCESS|COL_PAY|" DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-AMT) DELIMITED BY SIZE
                       "|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF WS-TMP-STATUS(1:6) = "CLOSED" OR WS-TMP-STATUS(1:9) = "CANCELLED"
               PERFORM DELETE-PAY-REQUEST
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           COMPUTE WS-NUM-OUT = WS-NUM-OVERDUE - WS-NUM-RECOVERED END-COMPUTE
           IF WS-NUM-AMOUNT > WS-NUM-OUT
               MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           *> Guarded credit: concurrent pays serialize on the account row;
           *> the loser sees AFFECTED_0 instead of over-recovering past the
           *> overdue amount.
           MOVE "UPDATE collection_case SET recovered_amount = recovered_amount + ?, status = CASE WHEN recovered_amount + ? >= overdue_amount THEN 'CLOSED' ELSE 'OPEN' END, closed_at = CASE WHEN recovered_amount + ? >= overdue_amount THEN NOW() ELSE closed_at END, resolution = CASE WHEN recovered_amount + ? >= overdue_amount THEN 'PAID_IN_FULL' ELSE resolution END WHERE id = ? AND recovered_amount + ? <= overdue_amount" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           MOVE WS-P2-TRIMMED TO WS-BIND-4
           MOVE WS-P1-TRIMMED TO WS-BIND-5
           MOVE WS-P2-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_AMOUNT" TO WS-ERR
               SET STEP-FAIL TO TRUE
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK AND WS-P5-TRIMMED NOT = SPACES
               MOVE "COL_PAY" TO WS-IDEM-SCOPE
               MOVE WS-P1-TRIMMED TO WS-IDEM-ENTITY-VAL
               MOVE WS-P5-TRIMMED TO WS-IDEM-KEY
               MOVE FUNCTION TRIM(WS-PAY-AMT) TO WS-IDEM-AMOUNT
               MOVE SPACES TO WS-IDEM-DETAILS
               PERFORM IDEM-COMPLETE
           END-IF.
           IF STEP-OK
               MOVE "PAYMENT" TO WS-ACT-TYPE
               MOVE SPACES TO WS-ACT-CHANNEL
               MOVE "Recovery payment" TO WS-ACT-NOTE
               MOVE WS-P2-TRIMMED TO WS-ACT-AMOUNT
               PERFORM ADD-ACTIVITY
           END-IF.
           IF STEP-OK
               MOVE "PAY" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-CASE
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               MOVE "SELECT GREATEST(overdue_amount - recovered_amount, 0) FROM collection_case WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   PERFORM TRIM-RESULT-LEN
                   MOVE WS-RESULT(1:WS-RLEN) TO WS-TMP-STR
               END-IF
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|COL_PAY|" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE
                   "|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INVALID_AMOUNT"
                   MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-ESCALATE.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM LOAD-CASE
           IF NOT CASE-FOUND
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-TMP-STATUS(1:6) = "CLOSED" OR WS-TMP-STATUS(1:9) = "CANCELLED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE collection_case SET escalation_level = LEAST(escalation_level + 1, 5), status = 'ESCALATED' WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "ESCALATION" TO WS-ACT-TYPE
               MOVE SPACES TO WS-ACT-CHANNEL
               MOVE WS-P2-TRIMMED TO WS-ACT-NOTE
               MOVE "0" TO WS-ACT-AMOUNT
               PERFORM ADD-ACTIVITY
           END-IF.
           IF STEP-OK
               MOVE "ESCALATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-CASE
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               MOVE "SELECT escalation_level FROM collection_case WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-P1-TRIMMED TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   PERFORM TRIM-RESULT-LEN
                   MOVE WS-RESULT(1:WS-RLEN) TO WS-TMP-LEVEL
               END-IF
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|COL_ESCALATE|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-LEVEL) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-CLOSE.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR WS-P2-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM LOAD-CASE
           IF NOT CASE-FOUND
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-TMP-STATUS(1:6) = "CLOSED" OR WS-TMP-STATUS(1:9) = "CANCELLED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE collection_case SET status = 'CLOSED', resolution = ?, closed_at = NOW() WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "STATUS" TO WS-ACT-TYPE
               MOVE SPACES TO WS-ACT-CHANNEL
               MOVE WS-P2-TRIMMED TO WS-ACT-NOTE
               MOVE "0" TO WS-ACT-AMOUNT
               PERFORM ADD-ACTIVITY
           END-IF.
           IF STEP-OK
               MOVE "CLOSE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-CASE
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|COL_CLOSE" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-REOPEN.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR WS-P2-TRIMMED = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM LOAD-CASE
           IF NOT CASE-FOUND
               MOVE WS-ERR TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-TMP-STATUS(1:6) NOT = "CLOSED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE collection_case SET status = 'OPEN', resolution = NULL, closed_at = NULL WHERE id = ? AND status = 'CLOSED'" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "STATUS" TO WS-ACT-TYPE
               MOVE SPACES TO WS-ACT-CHANNEL
               MOVE WS-P2-TRIMMED TO WS-ACT-NOTE
               MOVE "0" TO WS-ACT-AMOUNT
               PERFORM ADD-ACTIVITY
           END-IF.
           IF STEP-OK
               MOVE "REOPEN" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED TO WS-AUDIT-CASE
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|COL_REOPEN" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-SUMMARY.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COUNT(*), '|', COALESCE(SUM(status = 'OPEN'), 0), '|', COALESCE(SUM(status = 'PROMISE'), 0), '|', COALESCE(SUM(status = 'ESCALATED'), 0), '|', COALESCE(SUM(status = 'CLOSED'), 0), '|', COALESCE(SUM(overdue_amount), 0), '|', COALESCE(SUM(recovered_amount), 0), '|', COALESCE(SUM(assigned_to IS NOT NULL AND status NOT IN ('CLOSED','CANCELLED')), 0)) FROM collection_case" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM TRIM-RESULT-LEN
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|COL_SUMMARY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       AGING-BUCKET.
           MOVE 'N' TO WS-AGE-OK
           MOVE SPACES TO WS-PREP-SQL
           STRING "SELECT CONCAT(COUNT(*), ':', COALESCE(SUM(overdue_amount), 0)) FROM collection_case WHERE status NOT IN ('CLOSED','CANCELLED') AND " DELIMITED BY SIZE WS-AGE-WHERE DELIMITED BY SIZE INTO WS-PREP-SQL END-STRING
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "0:0" TO WS-TMP-STR
           ELSE
               PERFORM TRIM-RESULT-LEN
               MOVE WS-RESULT(1:WS-RLEN) TO WS-TMP-STR
           END-IF
           MOVE 'Y' TO WS-AGE-OK.
           EXIT PARAGRAPH.

       ACTION-AGING.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "(oldest_due_date IS NULL OR oldest_due_date >= CURDATE())" TO WS-AGE-WHERE
           PERFORM AGING-BUCKET
           MOVE WS-TMP-STR TO WS-AGE-1
           MOVE "DATEDIFF(CURDATE(), oldest_due_date) BETWEEN 1 AND 30" TO WS-AGE-WHERE
           PERFORM AGING-BUCKET
           MOVE WS-TMP-STR TO WS-AGE-2
           MOVE "DATEDIFF(CURDATE(), oldest_due_date) BETWEEN 31 AND 60" TO WS-AGE-WHERE
           PERFORM AGING-BUCKET
           MOVE WS-TMP-STR TO WS-AGE-3
           MOVE "DATEDIFF(CURDATE(), oldest_due_date) BETWEEN 61 AND 90" TO WS-AGE-WHERE
           PERFORM AGING-BUCKET
           MOVE WS-TMP-STR TO WS-AGE-4
           MOVE "DATEDIFF(CURDATE(), oldest_due_date) > 90" TO WS-AGE-WHERE
           PERFORM AGING-BUCKET
           MOVE WS-TMP-STR TO WS-AGE-5
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|COL_AGING|" DELIMITED BY SIZE FUNCTION TRIM(WS-AGE-1) DELIMITED BY SIZE
               ";" DELIMITED BY SIZE FUNCTION TRIM(WS-AGE-2) DELIMITED BY SIZE
               ";" DELIMITED BY SIZE FUNCTION TRIM(WS-AGE-3) DELIMITED BY SIZE
               ";" DELIMITED BY SIZE FUNCTION TRIM(WS-AGE-4) DELIMITED BY SIZE
               ";" DELIMITED BY SIZE FUNCTION TRIM(WS-AGE-5) DELIMITED BY SIZE
               INTO LS-OUTPUT-BUFFER END-STRING.
           EXIT PARAGRAPH.

       ACTION-HISTORY.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF WS-P2-TRIMMED NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF WS-P3-TRIMMED NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CONCAT(activity_type, ':', COALESCE(channel, ''), ':', COALESCE(note, ''), ':', amount, ':', actor_email, ':', created_at) FROM collection_activity WHERE case_id = ? ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-LIMIT TO WS-BIND-2
           MOVE WS-OFFSET TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|COL_HISTORY|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|COL_HISTORY|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-AUDIT.
           MOVE "COLLECTION_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF WS-P2-TRIMMED NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF WS-P3-TRIMMED NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CONCAT(action, ':', actor_email, ':', COALESCE(detail, ''), ':', created_at) FROM collection_audit WHERE (? = '' OR case_id = ?) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           MOVE WS-OFFSET TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "SUCCESS|COL_AUDIT|0" TO LS-OUTPUT-BUFFER
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|COL_AUDIT|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           END-IF.
           EXIT PARAGRAPH.
