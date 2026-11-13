      *> Deposit open/mature lifecycle (maint-15B1): extracted verbatim from
      *> deposit_core.cob. Included by deposit_core (same compiled module), so
      *> the actions keep their single transaction, working storage, and audit
      *> helpers. ACTION-CLOSE follows in 15B2.

       CLAIM-OPEN-REQUEST.
           *> Client-supplied idempotency for open (P7, global keyspace:
           *> OPEN mints its own deposit id, so the key stands alone).
           *> First call inserts a PENDING request row carrying the full
           *> business tuple and owns it; a repeated key replays the stored
           *> DONE deposit id, or conflicts when any tuple field differs.
           *> Migrated to common_idem.cpy (DETAILS mode): the legacy row
           *> stays the decision-maker while every transition is mirrored.
           MOVE WS-PRINCIPAL-NUM TO WS-AMT-EDIT
           MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-TMP-AMT
           PERFORM IDEM-RESET
           MOVE "DEP_OPEN" TO WS-IDEM-SCOPE
           MOVE WS-P7-TRIMMED TO WS-IDEM-KEY
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
           MOVE WS-P1-TRIMMED TO WS-IDEM-V1
           MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-V2
           MOVE WS-P3-TRIMMED TO WS-IDEM-V3
           MOVE WS-P4-TRIMMED TO WS-IDEM-V4
           MOVE WS-P5-TRIMMED TO WS-IDEM-V5
           MOVE "customer_email, principal, currency, term_months, interest_rate" TO WS-IDEM-DETAIL-COLS
           MOVE "deposit_id" TO WS-IDEM-IDCOL
           MOVE "ERROR|OPEN_IN_PROGRESS" TO WS-IDEM-CODE
           MOVE SPACES TO WS-IDEM-JID
           PERFORM IDEM-CLAIM
           IF WS-ERR = SPACES
               MOVE WS-IDEM-REFID TO WS-IDEM-JID
           END-IF.
           EXIT PARAGRAPH.

       DELETE-OPEN-REQUEST.
           *> Drops our own PENDING request row when the open is refused
           *> before posting, so the key stays usable instead of blocking
           *> behind a 5-minute stale window. Only the owner row is ever
           *> removed (status guard); DONE rows are never touched. The
           *> unified mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "DEP_OPEN" TO WS-IDEM-SCOPE
           MOVE WS-P7-TRIMMED TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       ACTION-OPEN.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-PRINCIPAL-NUM
           MOVE FUNCTION NUMVAL(WS-P4-TRIMMED) TO WS-TERM-NUM
           IF WS-PRINCIPAL-NUM <= 0
               MOVE "ERROR|INVALID_PRINCIPAL" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           IF WS-TERM-NUM < 1 OR WS-TERM-NUM > 360
               MOVE "ERROR|INVALID_TERM" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE "SELECT iso_code FROM currencies WHERE iso_code = ? AND is_active = 1 LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|INVALID_CURRENCY" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P7-TRIMMED NOT = SPACES
               PERFORM CLAIM-OPEN-REQUEST
               IF WS-ERR NOT = SPACES
                   MOVE WS-ERR TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               IF WS-IDEM-STATUS = "DONE"
                   MOVE SPACES TO LS-OUTPUT-BUFFER
                   STRING "SUCCESS|DEP_OPEN|" DELIMITED BY SIZE FUNCTION TRIM(WS-IDEM-JID) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           *> Fase 2: opening funds the deposit. Resolve the money path
           *> before writing anything: deposit currency, customer wallet,
           *> and bank-owned DEPOSIT_POOL suspense. A missing wallet or
           *> pool, or a short wallet, fails closed with no row written.
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           PERFORM LOOKUP-CURRENCY
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-CURR-ID
           MOVE "SELECT CAST(a.account_id AS CHAR) FROM accounts a JOIN users u ON u.id = a.user_id WHERE u.email = ? AND a.currency_id = ? AND a.status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-CURR-ID TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               PERFORM DELETE-OPEN-REQUEST
               MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-CUST-ACC
           MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'DEPOSIT_POOL' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
           MOVE WS-CURR-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               PERFORM DELETE-OPEN-REQUEST
               MOVE "ERROR|DEPOSIT_POOL_MISSING" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:20) TO WS-POOL-ACC
           MOVE "SELECT CAST(balance AS CHAR) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
           MOVE WS-CUST-ACC TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION NUMVAL(WS-RESULT) TO WS-BAL-NUM
           IF WS-BAL-NUM < WS-PRINCIPAL-NUM
               PERFORM DELETE-OPEN-REQUEST
               MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "0" TO WS-ADOPTED
           IF WS-P7-TRIMMED NOT = SPACES AND WS-IDEM-JID NOT = SPACES
               MOVE WS-IDEM-JID TO WS-ID-TEXT
               MOVE "1" TO WS-ADOPTED
           END-IF.
           IF WS-ADOPTED = "0"
           MOVE "INSERT INTO deposit_account (customer_email, principal, currency, term_months, interest_rate, created_by, status) VALUES (?, ?, ?, ?, COALESCE(NULLIF(?, ''), 0), ?, 'PENDING')" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-P5-TRIMMED TO WS-BIND-5
           MOVE WS-P6-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF
           IF STEP-OK
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-ID-TEXT
               END-IF
           END-IF
           END-IF.
           IF STEP-OK AND WS-P7-TRIMMED NOT = SPACES AND WS-IDEM-JID = SPACES
               PERFORM IDEM-RESET
               MOVE "DEP_OPEN" TO WS-IDEM-SCOPE
               MOVE WS-P7-TRIMMED TO WS-IDEM-KEY
               MOVE "deposit_id" TO WS-IDEM-IDCOL
               MOVE WS-ID-TEXT TO WS-IDEM-LINKVAL
               PERFORM IDEM-LINK
           END-IF.
           IF STEP-OK
               MOVE "UPDATE deposit_account SET maturity_date = DATE_ADD(CURDATE(), INTERVAL term_months MONTH) WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-ID-TEXT TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK AND WS-ADOPTED = "0"
               MOVE "OPEN" TO WS-AUDIT-ACTION
               MOVE WS-ID-TEXT TO WS-AUDIT-DEPOSIT
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Bank-side journal for the funding (gl_core owns its own
           *> transaction on this connection): DEBIT Cash / CREDIT Deposits
           *> payable. The deposit id is fresh, so the description is new.
           MOVE "SELECT CAST(CURDATE() AS CHAR)" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:10) TO WS-POST-DATE
           MOVE SPACES TO WS-GL-DESC WS-GL-LINES WS-GL-JID
           STRING "DEP_OPEN:" DELIMITED BY SIZE FUNCTION TRIM(WS-ID-TEXT) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-GL-DESC END-STRING
           STRING "1000:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE ":0;2120:0:" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-GL-LINES END-STRING
           MOVE "GL_JOURNAL_POST_ML" TO WS-CALL-ACTION
           MOVE WS-POST-DATE TO WS-CALL-P1
           MOVE WS-GL-DESC TO WS-CALL-P2
           MOVE WS-P3-TRIMMED TO WS-CALL-P3
           MOVE WS-GL-LINES TO WS-CALL-P4
           MOVE SPACES TO WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           MOVE WS-P6-TRIMMED TO WS-CALL-P6
           CALL "gl_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
               WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
           END-CALL
           IF WS-CALL-OUT(1:5) = "ERROR"
               MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-JOUT-1 WS-JOUT-2 WS-GL-JID
           UNSTRING WS-CALL-OUT DELIMITED BY "|" INTO WS-JOUT-1 WS-JOUT-2 WS-GL-JID END-UNSTRING
           IF WS-JOUT-2 NOT = "GL_POSTED_ML" OR WS-GL-JID = SPACES
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           *> Funding legs: customer wallet DEBIT / DEPOSIT_POOL CREDIT, in
           *> one transaction. The guarded debit is the race-safe gate: a
           *> concurrent spend leaves the deposit PENDING with no money
           *> moved (the early balance check above covers the common case
           *> before any row is written).
           MOVE SPACES TO WS-TXN-REF WS-DESC WS-JID WS-ERR
           STRING "DEP-" DELIMITED BY SIZE FUNCTION TRIM(WS-ID-TEXT) DELIMITED BY SIZE "-FUND" DELIMITED BY SIZE INTO WS-TXN-REF END-STRING
           STRING "DEP_OPEN:" DELIMITED BY SIZE FUNCTION TRIM(WS-ID-TEXT) DELIMITED BY SIZE ":" DELIMITED BY SIZE FUNCTION TRIM(WS-P2-TRIMMED) DELIMITED BY SIZE INTO WS-DESC END-STRING
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           IF STEP-OK
           MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'TRANSFER', ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-P1-TRIMMED TO WS-BIND-2
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
           PERFORM LAST-INSERT-ID
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           ELSE
           MOVE WS-RESULT(1:20) TO WS-JID
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ? AND balance >= ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-1
           MOVE WS-CUST-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
           MOVE "ERROR|INSUFFICIENT_FUNDS" TO WS-ERR
           SET STEP-FAIL TO TRUE
           ELSE
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-1
           MOVE WS-POOL-ACC TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-CUST-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-3
           MOVE WS-CURR-ID TO WS-BIND-4
           MOVE WS-DESC TO WS-BIND-5
           MOVE WS-P1-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, ?, 1, @jid, ?)" TO WS-PREP-SQL
           MOVE WS-TXN-REF TO WS-BIND-1
           MOVE WS-POOL-ACC TO WS-BIND-2
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-3
           MOVE WS-CURR-ID TO WS-BIND-4
           MOVE WS-DESC TO WS-BIND-5
           MOVE WS-P1-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK
           MOVE "INSERT INTO deposit_transaction (deposit_id, txn_type, amount, currency, reference) SELECT id, 'PRINCIPAL_FUNDED', ?, currency, CONCAT('FUND-', id, '-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s')) FROM deposit_account WHERE id = ?" TO WS-PREP-SQL
           MOVE FUNCTION TRIM(WS-P2-TRIMMED) TO WS-BIND-1
           MOVE WS-ID-TEXT TO WS-BIND-2
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
           MOVE "UPDATE deposit_account SET status = 'ACTIVE', fund_journal_id = ?, fund_gl_journal_id = ? WHERE id = ? AND status = 'PENDING'" TO WS-PREP-SQL
           MOVE WS-JID TO WS-BIND-1
           MOVE WS-GL-JID TO WS-BIND-2
           MOVE WS-ID-TEXT TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
           SET STEP-FAIL TO TRUE
           END-IF
           END-IF.
           IF STEP-OK AND WS-P7-TRIMMED NOT = SPACES
               PERFORM IDEM-RESET
               MOVE "DEP_OPEN" TO WS-IDEM-SCOPE
               MOVE WS-P7-TRIMMED TO WS-IDEM-KEY
               MOVE FUNCTION TRIM(WS-TMP-AMT) TO WS-IDEM-AMOUNT
               MOVE "fund_gl_journal_id" TO WS-IDEM-SETCOL
               MOVE WS-GL-JID TO WS-IDEM-JIDVAL
               MOVE "1" TO WS-IDEM-GUARD
               PERFORM IDEM-COMPLETE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|DEP_OPEN|" DELIMITED BY SIZE WS-ID-TEXT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               IF WS-ERR = "ERROR|INSUFFICIENT_FUNDS"
                   MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
           END-IF.
           EXIT PARAGRAPH.

       ACTION-MATURE.
           MOVE "DEPOSIT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE deposit_account SET status = 'MATURED' WHERE status = 'ACTIVE' AND maturity_date IS NOT NULL AND maturity_date <= CURDATE()" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|DEP_MATURED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.
