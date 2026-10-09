       IDENTIFICATION DIVISION.
       PROGRAM-ID. WALLET-CORE.
       AUTHOR. KerryHanson1.
       INSTALLATION. ENTERPRISE-BANKING-CORE.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       
       * ---------------------------------------------------------
       * SQLCA - SQL Communication Area (Required for ODBC)
       * ---------------------------------------------------------
       EXEC SQL INCLUDE SQLCA END-EXEC.

       * ---------------------------------------------------------
       * Database Connection & Control
       * ---------------------------------------------------------
       01  WS-DB-CONTROL.
           05  DSN-NAME            PIC X(50) VALUE "COBOL_MYSQL".
           05  DB-USER             PIC X(50) VALUE "root".
           05  DB-PASS             PIC X(50) VALUE "".
           05  WS-SQL-STATE        PIC X(5) VALUE SPACES.
           05  WS-ERR-MSG          PIC X(255) VALUE SPACES.

       * ---------------------------------------------------------
       * Financial Data Records
       * ---------------------------------------------------------
       01  WS-ACCOUNT-RECORD.
           05  WS-ACCOUNT-ID       PIC 9(10) VALUE ZERO.
           05  WS-ACCOUNT-USER     PIC 9(10) VALUE ZERO.
           05  WS-ACCOUNT-CURR     PIC 9(10) VALUE ZERO.
           05  WS-ACCOUNT-BALANCE PIC 9(15)V9999 VALUE ZERO.
           05  WS-ACCOUNT-STATUS   PIC X(10) VALUE SPACES.

       01  WS-TRANSACTION-RECORD.
           05  WS-TXN-REF          PIC X(50) VALUE SPACES.
           05  WS-TXN-AMOUNT       PIC 9(15)V9999 VALUE ZERO.
           05  WS-TXN-TYPE         PIC X(10) VALUE SPACES.
           05  WS-TXN-CURRENCY    PIC 9(10) VALUE ZERO.
           05  WS-CONVERTED-AMT    PIC 9(15)V9999 VALUE ZERO.
           05  WS-BASE-CURR-ID    PIC 9(10) VALUE ZERO.
           05  WS-TARGET-CURR-ID   PIC 9(10) VALUE ZERO.
           05  WS-EXCHANGE-RATE    PIC 9(12)V9(6) VALUE ZERO.

       * ---------------------------------------------------------
       * Exit Codes for Integration
       * ---------------------------------------------------------
       01  WS-EXIT-CODE           PIC 9(2) VALUE 0.
           88  EXIT-SUCCESS        VALUE 0.
           88  EXIT-NOT-FOUND      VALUE 1.
           88  EXIT-DB-ERROR       VALUE 2.
           88  EXIT-INSUFFICIENT    VALUE 3.
           88  EXIT-INVALID-ARG    VALUE 4.

       LINKAGE SECTION.
       01  LS-CMD-ACTION          PIC X(30).
       01  LS-PARAM1              PIC X(100).
       01  LS-PARAM2              PIC X(100).
       01  LS-PARAM3              PIC X(100).
       01  LS-OUTPUT-BUFFER      PIC X(500).

       PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-OUTPUT-BUFFER.
       
       MAIN-LOGIC.
           DISPLAY "--- WALLET CORE ENGINE STARTING ---".
           
           EVALUATE LS-CMD-ACTION
               WHEN "GET_BALANCE"
                   PERFORM GET-BALANCE-LOGIC
               WHEN "INTERNAL_TRANSFER"
                   PERFORM TRANSFER-LOGIC
               WHEN OTHER
                   MOVE 4 TO WS-EXIT-CODE
                   MOVE "ERROR|INVALID_ACTION|Action not supported in WalletCore" TO LS-OUTPUT-BUFFER
           END-EVALUATE.

           GOBACK.

       GET-BALANCE-LOGIC.
           DISPLAY "Executing GET_BALANCE...".
           
           EXEC SQL
               SELECT a.balance, a.currency_id INTO :WS-ACCOUNT-BALANCE, :WS-ACCOUNT-CURR
               FROM accounts a
               JOIN users u ON a.user_id = u.id
               WHERE u.email = :LS-PARAM1
           END-EXEC.

           IF SQLCODE = 0
               MOVE 0 TO WS-EXIT-CODE
               STRING "SUCCESS|BALANCE|" WS-ACCOUNT-BALANCE "|CURRENCY_ID:" WS-ACCOUNT-CURR
                   DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
           ELSE
               MOVE 1 TO WS-EXIT-CODE
               MOVE "ERROR|ACCOUNT_NOT_FOUND|No account associated with this email" TO LS-OUTPUT-BUFFER
           END-IF.

       TRANSFER-LOGIC.
           DISPLAY "Executing INTERNAL_TRANSFER...".
           
           * Parse Amount from LS-PARAM3
           IF LS-PARAM3 = SPACES
               MOVE 4 TO WS-EXIT-CODE
               MOVE "ERROR|INVALID_ARG|Amount is required" TO LS-OUTPUT-BUFFER
               GOBACK.
           END-IF.
           
           MOVE FUNCTION NUMVAL(LS-PARAM3) TO WS-TXN-AMOUNT.
           
           * Generate Unique TXN REF
           MOVE FUNCTION CURRENT_DATE(9) TO WS-TXN-REF.
           STRING "TXN-" WS-TXN-REF DELIMITED BY SIZE INTO WS-TXN-REF.

           EXEC SQL SET AUTOCOMMIT = 0 END-EXEC.
           
           * 1. Create Intent (Persistence)
           EXEC SQL
               INSERT INTO pending_transactions (txn_ref, from_email, to_email, amount, status)
               VALUES (:WS-TXN-REF, :LS-PARAM1, :LS-PARAM2, :WS-TXN-AMOUNT, 'PENDING')
           END-EXEC.

           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC.
               EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
               MOVE 2 TO WS-EXIT-CODE
               MOVE "ERROR|INTENT_FAILED|Could not record transaction intent" TO LS-OUTPUT-BUFFER
               GOBACK.
           END-IF.

           * 2. Fetch and Lock Source Account
           EXEC SQL
               SELECT a.account_id, a.currency_id, a.balance 
               INTO :WS-ACCOUNT-ID, :WS-ACCOUNT-CURR, :WS-ACCOUNT-BALANCE
               FROM accounts a
               JOIN users u ON a.user_id = u.id
               WHERE u.email = :LS-PARAM1
               FOR UPDATE
           END-EXEC.

           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC.
               EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
               MOVE 1 TO WS-EXIT-CODE
               MOVE "ERROR|ACCOUNT_NOT_FOUND|Source account not found or locked" TO LS-OUTPUT-BUFFER
               GOBACK.
           END-IF.

           MOVE WS-ACCOUNT-CURR TO WS-BASE-CURR-ID.

           * 3. Deduct Balance (with Check)
           EXEC SQL
               UPDATE accounts a
               SET a.balance = a.balance - :WS-TXN-AMOUNT
               WHERE a.account_id = :WS-ACCOUNT-ID
               AND a.balance >= :WS-TXN-AMOUNT
           END-EXEC.

           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC.
               EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
               MOVE 3 TO WS-EXIT-CODE
               MOVE "ERROR|INSUFFICIENT_FUNDS|Insufficient balance or account locked" TO LS-OUTPUT-BUFFER
               GOBACK.
           END-IF.

           * 4. Fetch and Lock Target Account
           EXEC SQL
               SELECT a.account_id, a.currency_id INTO :WS-ACCOUNT-ID, :WS-ACCOUNT-CURR
               FROM accounts a
               JOIN users u ON a.user_id = u.id
               WHERE u.email = :LS-PARAM2
               FOR UPDATE
           END-EXEC.

           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC.
               EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
               MOVE 1 TO WS-EXIT-CODE
               MOVE "ERROR|ACCOUNT_NOT_FOUND|Target account not found or locked" TO LS-OUTPUT-BUFFER
               GOBACK.
           END-IF.

           MOVE WS-ACCOUNT-CURR TO WS-TARGET-CURR-ID.

           * 5. Currency Conversion Logic
           IF WS-BASE-CURR-ID NOT = WS-TARGET-CURR-ID
               EXEC SQL
                   SELECT exchange_rate INTO :WS-EXCHANGE-RATE
                   FROM exchange_rates
                   WHERE base_currency_id = :WS-BASE-CURR-ID
                   AND target_currency_id = :WS-TARGET-CURR-ID
               END-EXEC.

               IF SQLCODE NOT = 0
                   EXEC SQL ROLLBACK END-EXEC.
                   EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
                   MOVE 2 TO WS-EXIT-CODE
                   MOVE "ERROR|CONVERSION_FAILED|Exchange rate not found" TO LS-OUTPUT-BUFFER
                   GOBACK.
               END-IF.

               COMPUTE WS-CONVERTED-AMT = WS-TXN-AMOUNT * WS-EXCHANGE-RATE.
           ELSE
               MOVE WS-TXN-AMOUNT TO WS-CONVERTED-AMT.
           END-IF.

           * 6. Credit Target Account
           EXEC SQL
               UPDATE accounts a
               SET a.balance = a.balance + :WS-CONVERTED-AMT
               WHERE a.account_id = :WS-ACCOUNT-ID
           END-EXEC.

           IF SQLCODE NOT = 0
               EXEC SQL ROLLBACK END-EXEC.
               EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
               MOVE 2 TO WS-EXIT-CODE
               MOVE "ERROR|DB_ERROR|Failed to credit target account" TO LS-OUTPUT-BUFFER
               GOBACK.
           END-IF.

           * 7. Ledger Entries
           EXEC SQL
               INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description)
               VALUES (:WS-TXN-REF, :WS-ACCOUNT-ID, :WS-TXN-AMOUNT, 'DEBIT', :WS-BASE-CURR-ID, 'Transfer via WalletCore')
           END-EXEC.

           EXEC SQL
               INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description)
               VALUES (:WS-TXN-REF, :WS-ACCOUNT-ID, :WS-CONVERTED-AMT, 'CREDIT', :WS-TARGET-CURR-ID, 'Transfer via WalletCore')
           END-EXEC.

           IF SQLCODE = 0
               EXEC SQL COMMIT END-EXEC.
               MOVE 0 TO WS-EXIT-CODE
               MOVE "SUCCESS|TRANSFER_OK|Amount transferred successfully" TO LS-OUTPUT-BUFFER
           ELSE
               EXEC SQL ROLLBACK END-EXEC.
               MOVE 2 TO WS-EXIT-CODE
               MOVE "ERROR|LEDGER_FAILED|Failed to write ledger" TO LS-OUTPUT-BUFFER
           END-IF.

           EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
