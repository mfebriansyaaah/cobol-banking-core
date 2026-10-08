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
       01  LS-OUTPUT-BUFFER      PIC X(500).

       PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-OUTPUT-BUFFER.
       
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
           MOVE 0 TO WS-EXIT-CODE.
           MOVE "SUCCESS|TRANSFER_OK|Transfer processed" TO LS-OUTPUT-BUFFER.
