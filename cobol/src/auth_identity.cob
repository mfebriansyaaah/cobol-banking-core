        IDENTIFICATION DIVISION.
        PROGRAM-ID. AUTH_IDENTITY.
        AUTHOR. COBOL BACKEND TEAM.
        DATE-WRITTEN. 2026-10-04.
        
        ENVIRONMENT DIVISION.
        CONFIGURATION SECTION.
        SOURCE-COMPUTER. X86-64.
        OBJECT-COMPUTER. X86-64.
        
        DATA DIVISION.
        WORKING-STORAGE SECTION.
        * ---------------------------------------------------------
        * SQLCA - SQL Communication Area (Required for ODBC)
        * ---------------------------------------------------------
        EXEC SQL INCLUDE SQLCA END-EXEC.
        
        * ---------------------------------------------------------
        * Connection Variables
        * ---------------------------------------------------------
        01  DB-CONFIG.
            05  DSN-NAME      PIC X(30) VALUE "COBOL_MYSQL".
            05  DB-USER       PIC X(30) VALUE "cobol_user".
            05  DB-PASS       PIC X(30) VALUE "cobol_pass".
        
        * ---------------------------------------------------------
        * Command Line Arguments Parsing
        * ---------------------------------------------------------
        01  CMD-INPUT.
            05  CMD-ACTION    PIC X(20) VALUE SPACES.
            05  CMD-PARAM1    PIC X(100) VALUE SPACES.
            05  CMD-PARAM2    PIC X(100) VALUE SPACES.
            05  CMD-PARAM3    PIC X(100) VALUE SPACES.
            05  CMD-PARAM4    PIC X(100) VALUE SPACES.
        
        * ---------------------------------------------------------
        * General Purpose Variables
        * ---------------------------------------------------------
        01  WS-EXIT-CODE      PIC 9(2) VALUE 0.
            88  EXIT-SUCCESS         VALUE 0.
            88  EXIT-NOT-FOUND       VALUE 1.
            88  EXIT-DB-ERROR        VALUE 2.
            88  EXIT-INVALID-ACTION  VALUE 3.
            88  EXIT-INVALID-ARG    VALUE 4.
            88  EXIT-UNAUTHORIZED    VALUE 5.
            88  EXIT-INSUFFICIENT_FUNDS VALUE 6.
            88  EXIT-LIMIT_EXCEEDED    VALUE 7.
        
        01  WS-OUTPUT-MSG     PIC X(500) VALUE SPACES.
        01  WS-SQL-STATE      PIC X(5) VALUE SPACES.
        01  WS-USER-ROLE      PIC X(20) VALUE SPACES.
        
        * ---------------------------------------------------------
        * Hashing & Random Variables
        * ---------------------------------------------------------
        01  WS-RAW-PASSWORD   PIC X(100) VALUE SPACES.
        01  WS-HASHED-PASS    PIC X(100) VALUE SPACES.
        01  WS-RANDOM-CODE    PIC X(6) VALUE SPACES.
        
        * ---------------------------------------------------------
        * Ledger & Transaction Variables
        * ---------------------------------------------------------
        01  WS-ACCOUNT-ID      PIC 9(10) COMP-5.
        01  WS-CURRENCY-ID    PIC 9(10) COMP-5.
        01  WS-BALANCE        PIC S9(12)V9(4) COMP-3.
        01  WS-TXN-AMOUNT     PIC S9(12)V9(4) COMP-3.
        01  WS-TXN-REF        PIC X(50) VALUE SPACES.
        01  WS-TXN-DESC       PIC X(255) VALUE SPACES.
        01  WS-BASE-CURR-ID    PIC 9(10) COMP-5.
        01  WS-TARGET-CURR-ID    PIC 9(10) COMP-5.
        01  WS-EXCHANGE-RATE      PIC S9(12)V9(6) COMP-3.
        01  WS-LIMIT-DAILY-MAX    PIC S9(12)V9(4) COMP-3.
        01  WS-LIMIT-SINGLE-MAX    PIC S9(12)V9(4) COMP-3.
        01  WS-DAILY-VOLUME        PIC S9(12)V9(4) COMP-3.
        01  WS-USER-ID-INTERNAL    PIC 9(10) COMP-5.
        01  WS-TXN-COUNT-RECENT    PIC 9(10) COMP-5.
        01  WS-AUDIT-ACTION           PIC X(100) VALUE SPACES.
        01  WS-AUDIT-DETAILS         PIC X(255) VALUE SPACES.
        01  WS-AUDIT-SEVERITY         PIC X(10) VALUE "INFO".
        01  WS-NOTIF-MESSAGE            PIC X(255) VALUE SPACES.
        01  WS-NOTIF-TYPE               PIC X(10) VALUE "INFO".
        01  WS-KYC-LEVEL                  PIC X(10) VALUE "BASIC".
        01  WS-LOYALTY-SCORE               PIC 9(10) COMP-5 VALUE 0.
        01  WS-ANNUAL-RATE            PIC S9(3)V9(4) COMP-3.
        01  WS-INTEREST-AMOUNT        PIC S9(12)V9(4) COMP-3.
        01  WS-DAILY-INTEREST         PIC S9(12)V9(6) COMP-3.
        01  WS-REWARD-POINTS            PIC 9(10) COMP-5.
        01  WS-POINTS-EARNED            PIC 9(10) COMP-5.
        
        LINKAGE SECTION.
        01  LS-ARG-COUNT      PIC 9(4) COMP-5.
        01  LS-ARG-VALUE     PIC X(100) OCCURS 10 TIMES.
        
        PROCEDURE DIVISION USING LS-ARG-COUNT LS-ARG-VALUE.
        MAIN-LOGIC.
            PERFORM INITIALIZE-PROGRAM.
            PERFORM PARSE-ARGUMENTS.
            
            IF CMD-ACTION = "TEST_CONN"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    DISPLAY "SUCCESS|DB_CONNECTED|Connection established successfully"
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "TEST_HASH"
                MOVE CMD-PARAM1 TO WS-RAW-PASSWORD
                CALL "hash_password" USING BY REFERENCE WS-RAW-PASSWORD 
                                           BY REFERENCE WS-HASHED-PASS
                DISPLAY "SUCCESS|HASHED|" WS-HASHED-PASS
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "REQUEST_SIGNUP"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-SIGNUP
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "VERIFY_EMAIL"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-VERIFICATION
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "CHECK_ROLE"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-CHECK-ROLE
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "CHANGE_ROLE"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-CHANGE-ROLE
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.

            IF CMD-ACTION = "CHECK_BALANCE"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-CHECK-BALANCE
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "DETECT_FRAUD"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-DETECT-FRAUD
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "CHECK_LIMITS"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-CHECK-LIMITS
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "CALC_INTEREST"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-CALCULATE-TIER
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.

            IF CMD-ACTION = "ACCRUE_INTEREST"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-ACCRUE-INTEREST
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "PAY_INTEREST"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-INTEREST-PAYOUT
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.

            IF CMD-ACTION = "SEND_NOTIF"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-SEND-NOTIF
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.

            IF CMD-ACTION = "GET_NOTIFS"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-GET-NOTIFS
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            IF CMD-ACTION = "CHECK_KYC"
                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-CHECK-KYC
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.

            IF CMD-ACTION = "TRANSFER"





                PERFORM CONNECT-DATABASE
                IF EXIT-SUCCESS
                    PERFORM PROCESS-TRANSFER
                ELSE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
                STOP RUN WS-EXIT-CODE
            END-IF.
            
            EVALUATE TRUE
                WHEN CMD-ACTION = "AUTH_LOGIN"
                    DISPLAY "SKELETON|LOGIN_NOT_IMPLEMENTED"
                WHEN OTHER
                    MOVE 3 TO WS-EXIT-CODE
                    DISPLAY "ERROR|INVALID_ACTION|" CMD-ACTION
            END-EVALUATE.
            
            STOP RUN WS-EXIT-CODE.
            
        INITIALIZE-PROGRAM.
            MOVE 0 TO WS-EXIT-CODE.
            MOVE SPACES TO CMD-ACTION, CMD-PARAM1, CMD-PARAM2, 
                           CMD-PARAM3, CMD-PARAM4.
            
        PARSE-ARGUMENTS.
            IF LS-ARG-COUNT >= 2
                MOVE LS-ARG-VALUE(2) TO CMD-ACTION
            ELSE
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_ACTION|Action is required"
                STOP RUN WS-EXIT-CODE.
            
            IF LS-ARG-COUNT >= 3
                MOVE LS-ARG-VALUE(3) TO CMD-PARAM1.
            IF LS-ARG-COUNT >= 4
                MOVE LS-ARG-VALUE(4) TO CMD-PARAM2.
            IF LS-ARG-COUNT >= 5
                MOVE LS-ARG-VALUE(5) TO CMD-PARAM3.
            IF LS-ARG-COUNT >= 6
                MOVE LS-ARG-VALUE(6) TO CMD-PARAM4.
            
        CONNECT-DATABASE.
            EXEC SQL
                CONNECT TO :DSN-NAME USER :DB-USER USING :DB-PASS
            END-EXEC.
            IF SQLCODE = 0
                MOVE 0 TO WS-EXIT-CODE
            ELSE
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR.
            
        CAPTURE-SQL-ERROR.
            MOVE SQLSTATE TO WS-SQL-STATE.
            IF SQLCODE NOT = 0
                STRING "SQLSTATE: " WS-SQL-STATE " | SQLCODE: " SQLCODE
                       " | MSG: " SQLERRMC
                       DELIMITED BY SIZE INTO WS-OUTPUT-MSG
            ELSE
                MOVE "No SQL Error detected" TO WS-OUTPUT-MSG.
            
            DISPLAY "ERROR|DB_ERROR|" WS-OUTPUT-MSG.

            MOVE "DB_ERROR" TO WS-AUDIT-ACTION.
            MOVE WS-OUTPUT-MSG TO WS-AUDIT-DETAILS.
            MOVE "WARNING" TO WS-AUDIT-SEVERITY.
            PERFORM LOG-AUDIT-EVENT.
            
        PROCESS-SIGNUP.
            IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email and Password are required"
                EXIT PROGRAM.

            IF FUNCTION LENGTH(CMD-PARAM2) < 8
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|WEAK_PASSWORD|Password must be at least 8 characters"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT id FROM users WHERE email = :CMD-PARAM1
            END-EXEC.
            
            IF SQLCODE = 0
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|USER_EXISTS|Email already registered"
                EXIT PROGRAM.
            END-IF.

            MOVE CMD-PARAM2 TO WS-RAW-PASSWORD
            CALL "hash_password" USING BY REFERENCE WS-RAW-PASSWORD 
                                       BY REFERENCE WS-HASHED-PASS.

            CALL "generate_random_code" USING BY REFERENCE WS-RANDOM-CODE.

            EXEC SQL SET AUTOCOMMIT = 0 END-EXEC.`n`n            * --- INTEGRATED SECURITY GUARD ---`n            MOVE CMD-PARAM1 TO CMD-PARAM1.`n            MOVE CMD-PARAM3 TO CMD-PARAM2.`n            PERFORM PROCESS-CHECK-LIMITS.`n            IF WS-EXIT-CODE NOT = 0`n                EXEC SQL ROLLBACK END-EXEC.`n                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.`n                DISPLAY `"ERROR|TRANSFER_BLOCKED|Limit Check Failed`"`n                EXIT PROGRAM.`n            END-IF.`n`n            MOVE CMD-PARAM1 TO CMD-PARAM1.`n            PERFORM PROCESS-DETECT-FRAUD.`n            IF WS-EXIT-CODE NOT = 0`n                EXEC SQL ROLLBACK END-EXEC.`n                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.`n                DISPLAY `"ERROR|TRANSFER_BLOCKED|Fraud Detected`"`n                EXIT PROGRAM.`n            END-IF.`n`n            EXEC SQL
                INSERT INTO users (email, password_hash, full_name, dob, status, verification_code)
                VALUES (:CMD-PARAM1, :WS-HASHED-PASS, :CMD-PARAM3, :CMD-PARAM4, 'UNVERIFIED', :WS-RANDOM-CODE)
            END-EXEC.

            IF SQLCODE = 0
                EXEC SQL
                    INSERT INTO accounts (user_id, currency_id, balance, account_type)
                    VALUES ((SELECT id FROM users WHERE email = :CMD-PARAM1), 1, 0.0000, 'SAVINGS')
                END-EXEC.
                
                IF SQLCODE = 0
                    EXEC SQL COMMIT END-EXEC.
                    MOVE 0 TO WS-EXIT-CODE
                    STRING "SUCCESS|USER_CREATED|Code: " WS-RANDOM-CODE
                        DELIMITED BY SIZE INTO WS-OUTPUT-MSG
                    DISPLAY WS-OUTPUT-MSG
                ELSE
                    EXEC SQL ROLLBACK END-EXEC.
                    MOVE 2 TO WS-EXIT-CODE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
            ELSE
                EXEC SQL ROLLBACK END-EXEC.
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR.
            END-IF.
            
            EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
            
        PROCESS-VERIFICATION.
            IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email and Code are required"
                EXIT PROGRAM.

            EXEC SQL
                SELECT id FROM users 
                WHERE email = :CMD-PARAM1 AND verification_code = :CMD-PARAM2
            END-EXEC.
            
            IF SQLCODE = 0
                EXEC SQL
                    UPDATE users SET status = 'VERIFIED' WHERE email = :CMD-PARAM1
                END-EXEC.
                
                IF SQLCODE = 0
                    MOVE 0 TO WS-EXIT-CODE
                    DISPLAY "SUCCESS|EMAIL_VERIFIED|Account is now active"
                ELSE
                    MOVE 2 TO WS-EXIT-CODE
                    PERFORM CAPTURE-SQL-ERROR
                END-IF
            ELSE
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|INVALID_CODE|Verification code is incorrect or email not found"
            END-IF.
            
        PROCESS-CHECK-ROLE.
            IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email and Required Role are required"
                EXIT PROGRAM.
            
            EXEC SQL
                SELECT r.role_name INTO :WS-USER-ROLE
                FROM role_assignments ra
                JOIN roles r ON ra.role_id = r.role_id
                JOIN users u ON ra.user_id = u.id
                WHERE u.email = :CMD-PARAM1
            END-EXEC.
            
            IF SQLCODE = 0
                IF FUNCTION TRIM(WS-USER-ROLE) = FUNCTION TRIM(CMD-PARAM2)
                    MOVE 0 TO WS-EXIT-CODE
                    DISPLAY "SUCCESS|ROLE_VERIFIED|User has the required role: " FUNCTION TRIM(WS-USER-ROLE)
                ELSE
                    MOVE 5 TO WS-EXIT-CODE
                    DISPLAY "ERROR|UNAUTHORIZED|Required " FUNCTION TRIM(CMD-PARAM2) 
                          ", but got " FUNCTION TRIM(WS-USER-ROLE)
                END-IF
            ELSE
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|USER_NOT_FOUND|User not found or has no role assigned"
            END-IF.

        PROCESS-CHANGE-ROLE.
            IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES OR CMD-PARAM3 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Admin, Target and New Role are required"
                EXIT PROGRAM.

            PERFORM CHECK-SUPERADMIN-ACCESS.

            IF FUNCTION TRIM(CMD-PARAM3) NOT = "USER" AND
               FUNCTION TRIM(CMD-PARAM3) NOT = "MANAGER" AND
               FUNCTION TRIM(CMD-PARAM3) NOT = "SUPER_ADMIN"
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|INVALID_ROLE|Role must be USER, MANAGER, or SUPER_ADMIN"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                DELETE FROM role_assignments 
                WHERE user_id = (SELECT id FROM users WHERE email = :CMD-PARAM2)
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                INSERT INTO role_assignments (user_id, role_id)
                VALUES (
                    (SELECT id FROM users WHERE email = :CMD-PARAM2),
                    (SELECT role_id FROM roles WHERE role_name = :CMD-PARAM3)
                )
            END-EXEC.

            IF SQLCODE = 0
                MOVE 0 TO WS-EXIT-CODE
                DISPLAY "SUCCESS|ROLE_CHANGED|User " CMD-PARAM2 " is now " CMD-PARAM3
            ELSE
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR.

        PROCESS-CHECK-BALANCE.
            IF CMD-PARAM1 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email is required"
                EXIT PROGRAM.

            EXEC SQL
                SELECT a.balance, a.currency_id INTO :WS-BALANCE, :WS-CURRENCY-ID
                FROM accounts a
                JOIN users u ON a.user_id = u.id
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE = 0
                MOVE 0 TO WS-EXIT-CODE
                STRING "SUCCESS|BALANCE|" WS-BALANCE "|CURRENCY_ID:" WS-CURRENCY-ID
                    DELIMITED BY SIZE INTO WS-OUTPUT-MSG
                DISPLAY WS-OUTPUT-MSG
            ELSE
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|ACCOUNT_NOT_FOUND|No account associated with this email"
            END-IF.

        PROCESS-TRANSFER.
            IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES OR CMD-PARAM3 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|From, To, and Amount are required"
                EXIT PROGRAM.

            MOVE CMD-PARAM3 TO WS-TXN-AMOUNT.

            EXEC SQL SET AUTOCOMMIT = 0 END-EXEC.`n`n            * --- INTEGRATED SECURITY GUARD ---`n            MOVE CMD-PARAM1 TO CMD-PARAM1.`n            MOVE CMD-PARAM3 TO CMD-PARAM2.`n            PERFORM PROCESS-CHECK-LIMITS.`n            IF WS-EXIT-CODE NOT = 0`n                EXEC SQL ROLLBACK END-EXEC.`n                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.`n                DISPLAY `"ERROR|TRANSFER_BLOCKED|Limit Check Failed`"`n                EXIT PROGRAM.`n            END-IF.`n`n            MOVE CMD-PARAM1 TO CMD-PARAM1.`n            PERFORM PROCESS-DETECT-FRAUD.`n            IF WS-EXIT-CODE NOT = 0`n                EXEC SQL ROLLBACK END-EXEC.`n                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.`n                DISPLAY `"ERROR|TRANSFER_BLOCKED|Fraud Detected`"`n                EXIT PROGRAM.`n            END-IF.`n`n            EXEC SQL
                SELECT a.account_id, a.currency_id, a.balance INTO :WS-ACCOUNT-ID, :WS-CURRENCY-ID, :WS-BALANCE
                FROM accounts a
                JOIN users u ON a.user_id = u.id
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE NOT = 0
                EXEC SQL ROLLBACK END-EXEC.
                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|ACCOUNT_NOT_FOUND|Source account not found"
                EXIT PROGRAM.
            END-IF.
            
            MOVE WS-CURRENCY-ID TO WS-BASE-CURR-ID.

            EXEC SQL
                UPDATE accounts a
                SET a.balance = a.balance - :WS-TXN-AMOUNT
                WHERE a.account_id = :WS-ACCOUNT-ID
                AND a.balance >= :WS-TXN-AMOUNT
            END-EXEC.

            IF SQLCODE NOT = 0
                EXEC SQL ROLLBACK END-EXEC.
                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
                MOVE 6 TO WS-EXIT-CODE
                DISPLAY "ERROR|INSUFFICIENT_FUNDS|Insufficient balance or locked account"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT a.account_id, a.currency_id INTO :WS-ACCOUNT-ID, :WS-CURRENCY-ID
                FROM accounts a
                JOIN users u ON a.user_id = u.id
                WHERE u.email = :CMD-PARAM2
            END-EXEC.

            IF SQLCODE NOT = 0
                EXEC SQL ROLLBACK END-EXEC.
                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|ACCOUNT_NOT_FOUND|Target account not found"
                EXIT PROGRAM.
            END-IF.
            
            MOVE WS-CURRENCY-ID TO WS-TARGET-CURR-ID.

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
                    DISPLAY "ERROR|CONVERSION_FAILED|Exchange rate not found"
                    EXIT PROGRAM.
                END-IF.
                
                COMPUTE WS-CONVERTED-AMOUNT = WS-TXN-AMOUNT * WS-EXCHANGE-RATE.
            ELSE
                MOVE WS-TXN-AMOUNT TO WS-CONVERTED-AMOUNT.
            END-IF.

            EXEC SQL
                UPDATE accounts a
                SET a.balance = a.balance + :WS-CONVERTED-AMOUNT
                WHERE a.account_id = :WS-ACCOUNT-ID
            END-EXEC.

            IF SQLCODE NOT = 0
                EXEC SQL ROLLBACK END-EXEC.
                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description)
                VALUES ('TXN-S', :WS-ACCOUNT-ID, :WS-TXN-AMOUNT, 'DEBIT', :WS-BASE-CURR-ID, 'Transfer to ' :CMD-PARAM2)
            END-EXEC.

            EXEC SQL
                INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description)
                VALUES ('TXN-S', :WS-ACCOUNT-ID, :WS-TXN-AMOUNT, 'CREDIT', :WS-TARGET-CURR-ID, 'Transfer from ' :CMD-PARAM1)
            END-EXEC.

            IF SQLCODE = 0
                EXEC SQL COMMIT END-EXEC.
                MOVE 0 TO WS-EXIT-CODE
                STRING "SUCCESS|TRANSFER_OK|Amount transferred successfully"
                       DELIMITED BY SIZE INTO WS-OUTPUT-MSG.
                DISPLAY WS-OUTPUT-MSG.

                * --- INTEGRATED REWARD GRANT ---
                MOVE CMD-PARAM1 TO CMD-PARAM1.
                MOVE CMD-PARAM3 TO CMD-PARAM2.
                PERFORM PROCESS-ADD-REWARDS.
            ELSE
                EXEC SQL ROLLBACK END-EXEC.
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR.
            END-IF.

            EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.

        CHECK-MANAGER-ACCESS.
            MOVE "MANAGER" TO CMD-PARAM2.
            PERFORM PROCESS-CHECK-ROLE.
            IF WS-EXIT-CODE NOT = 0
                MOVE 5 TO WS-EXIT-CODE
                DISPLAY "ERROR|UNAUTHORIZED|Manager access required"
                STOP RUN WS-EXIT-CODE
            END-IF.

        CHECK-SUPERADMIN-ACCESS.
            MOVE "SUPER_ADMIN" TO CMD-PARAM2.
            PERFORM PROCESS-CHECK-ROLE.
            IF WS-EXIT-CODE NOT = 0
                MOVE 5 TO WS-EXIT-CODE
                DISPLAY "ERROR|UNAUTHORIZED|Super Admin access required"
                STOP RUN WS-EXIT-CODE
            END-IF.

        LOG-AUDIT-EVENT.
            EXEC SQL
                INSERT INTO audit_trail (user_id, action, details, severity)
                VALUES (:WS-USER-ID-INTERNAL, :WS-AUDIT-ACTION, :WS-AUDIT-DETAILS, :WS-AUDIT-SEVERITY)
            END-EXEC.
            IF SQLCODE NOT = 0
                DISPLAY "SYSTEM_WARNING|AUDIT_LOG_FAILED|" SQLCODE.

        PROCESS-SEND-NOTIF.
            IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email and Message are required"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT u.id INTO :WS-USER-ID-INTERNAL
                FROM users u
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|USER_NOT_FOUND|User not found"
                EXIT PROGRAM.
            END-IF.

            MOVE CMD-PARAM2 TO WS-NOTIF-MESSAGE.
            MOVE CMD-PARAM3 TO WS-NOTIF-TYPE.
            IF WS-NOTIF-TYPE = SPACES
                MOVE "INFO" TO WS-NOTIF-TYPE.
            END-IF.

            EXEC SQL
                INSERT INTO notifications (user_id, type, message)
                VALUES (:WS-USER-ID-INTERNAL, :WS-NOTIF-TYPE, :WS-NOTIF-MESSAGE)
            END-EXEC.

            IF SQLCODE = 0
                MOVE 0 TO WS-EXIT-CODE
                DISPLAY "SUCCESS|NOTIF_SENT|Notification queued for " CMD-PARAM1
            ELSE
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR.
            END-IF.

        PROCESS-GET-NOTIFS.
            IF CMD-PARAM1 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email is required"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT n.message, n.type
                FROM notifications n
                JOIN users u ON n.user_id = u.id
                WHERE u.email = :CMD-PARAM1 AND n.is_read = FALSE
                ORDER BY n.created_at DESC
            END-EXEC.

            IF SQLCODE = 0
                MOVE 0 TO WS-EXIT-CODE
                DISPLAY "SUCCESS|NOTIFS_FETCHED|Fetching unread notifications..."
                * Note: In a real CLI implementation, we would loop through the cursor.
                * For this demo, we confirm that notifications exist.
            ELSE
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|NO_NOTIFS|No unread notifications found"
            END-IF.

        PROCESS-CHECK-KYC.
            IF CMD-PARAM1 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email is required"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT p.kyc_level INTO :WS-KYC-LEVEL
                FROM user_profiles p
                JOIN users u ON p.user_id = u.id
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE = 0
                MOVE 0 TO WS-EXIT-CODE
                STRING "SUCCESS|KYC_LEVEL|" WS-KYC-LEVEL
                       DELIMITED BY SIZE INTO WS-OUTPUT-MSG.
                DISPLAY WS-OUTPUT-MSG.
            ELSE
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|PROFILE_NOT_FOUND|KYC profile not found for user"
            END-IF.

        PROCESS-CHECK-LIMITS.
            IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email and Amount are required"
                EXIT PROGRAM.
            END-IF.

            MOVE CMD-PARAM2 TO WS-TXN-AMOUNT.

            EXEC SQL
                SELECT u.id INTO :WS-USER-ID-INTERNAL
                FROM users u
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|USER_NOT_FOUND|User not found"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT cl.daily_max, cl.single_max INTO :WS-LIMIT-DAILY-MAX, :WS-LIMIT-SINGLE-MAX
                FROM compliance_limits cl
                JOIN role_assignments ra ON cl.role_id = ra.role_id
                WHERE ra.user_id = :WS-USER-ID-INTERNAL
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR
                EXIT PROGRAM.
            END-IF.

            IF WS-TXN-AMOUNT > WS-LIMIT-SINGLE-MAX
                MOVE 7 TO WS-EXIT-CODE
                STRING "ERROR|LIMIT_EXCEEDED|Single txn exceeds max: " WS-LIMIT-SINGLE-MAX
                    DELIMITED BY SIZE INTO WS-OUTPUT-MSG
                DISPLAY WS-OUTPUT-MSG
                
                MOVE "LIMIT_EXCEEDED" TO WS-AUDIT-ACTION.
                MOVE WS-OUTPUT-MSG TO WS-AUDIT-DETAILS.
                MOVE "WARNING" TO WS-AUDIT-SEVERITY.
                PERFORM LOG-AUDIT-EVENT.
                
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT SUM(ABS(amount)) INTO :WS-DAILY-VOLUME
                FROM ledger l
                JOIN accounts a ON l.account_id = a.account_id
                WHERE a.user_id = :WS-USER-ID-INTERNAL
                AND l.created_at >= CURRENT_DATE
                AND l.type = 'DEBIT'
            END-EXEC.

            IF WS-DAILY-VOLUME + WS-TXN-AMOUNT > WS-LIMIT-DAILY-MAX
                MOVE 7 TO WS-EXIT-CODE
                STRING "ERROR|LIMIT_EXCEEDED|Daily volume exceeds max: " WS-LIMIT-DAILY-MAX
                    DELIMITED BY SIZE INTO WS-OUTPUT-MSG
                DISPLAY WS-OUTPUT-MSG
                
                MOVE "LIMIT_EXCEEDED" TO WS-AUDIT-ACTION.
                MOVE WS-OUTPUT-MSG TO WS-AUDIT-DETAILS.
                MOVE "WARNING" TO WS-AUDIT-SEVERITY.
                PERFORM LOG-AUDIT-EVENT.
                
                EXIT PROGRAM.
            END-IF.

            MOVE 0 TO WS-EXIT-CODE
            DISPLAY "SUCCESS|LIMITS_OK|Transaction within limits"

        PROCESS-DETECT-FRAUD.
            IF CMD-PARAM1 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email is required"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT u.id INTO :WS-USER-ID-INTERNAL
                FROM users u
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|USER_NOT_FOUND|User not found"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT COUNT(*) INTO :WS-TXN-COUNT-RECENT
                FROM ledger l
                JOIN accounts a ON l.account_id = a.account_id
                WHERE a.user_id = :WS-USER-ID-INTERNAL
                AND l.created_at >= (NOW() - INTERVAL 1 MINUTE)
            END-EXEC.

            IF WS-TXN-COUNT-RECENT > 5
                EXEC SQL
                    UPDATE accounts SET status = 'FROZEN' 
                    WHERE user_id = :WS-USER-ID-INTERNAL
                END-EXEC.

                MOVE "ACCOUNT_FROZEN" TO WS-AUDIT-ACTION.
                STRING "Rapid-fire transfers detected for User ID: " WS-USER-ID-INTERNAL
                       DELIMITED BY SIZE INTO WS-AUDIT-DETAILS.
                MOVE "CRITICAL" TO WS-AUDIT-SEVERITY.
                PERFORM LOG-AUDIT-EVENT.

                MOVE 5 TO WS-EXIT-CODE
                DISPLAY "ERROR|FRAUD_DETECTED|Rapid-fire transfers detected. Account FROZEN"
                EXIT PROGRAM.
            END-IF.

            MOVE 0 TO WS-EXIT-CODE
            DISPLAY "SUCCESS|NO_FRAUD|No suspicious patterns detected"

        PROCESS-CALCULATE-TIER.
            IF CMD-PARAM1 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email is required"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT a.balance INTO :WS-BALANCE
                FROM accounts a
                JOIN users u ON a.user_id = u.id
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|ACCOUNT_NOT_FOUND|No account found"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT annual_rate INTO :WS-ANNUAL-RATE
                FROM interest_rates
                WHERE :WS-BALANCE >= min_balance 
                AND (:WS-BALANCE <= max_balance OR max_balance IS NULL)
                AND is_active = TRUE
                LIMIT 1
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR
                EXIT PROGRAM.
            END-IF.

            COMPUTE WS-INTEREST-AMOUNT = (WS-BALANCE * WS-ANNUAL-RATE) / 12.

            STRING "SUCCESS|INTEREST_TIER|Balance: " WS-BALANCE 
                   " | Rate: " WS-ANNUAL-RATE 
                   " | Monthly: " WS-INTEREST-AMOUNT
                   DELIMITED BY SIZE INTO WS-OUTPUT-MSG.
            DISPLAY WS-OUTPUT-MSG.
            MOVE 0 TO WS-EXIT-CODE.

        PROCESS-ACCRUE-INTEREST.
            IF CMD-PARAM1 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email is required"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT a.balance INTO :WS-BALANCE
                FROM accounts a
                JOIN users u ON a.user_id = u.id
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|ACCOUNT_NOT_FOUND|No account found"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                SELECT annual_rate INTO :WS-ANNUAL-RATE
                FROM interest_rates
                WHERE :WS-BALANCE >= min_balance 
                AND (:WS-BALANCE <= max_balance OR max_balance IS NULL)
                AND is_active = TRUE
                LIMIT 1
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR
                EXIT PROGRAM.
            END-IF.

            * Daily Interest = (Balance * Annual Rate) / 365
            COMPUTE WS-DAILY-INTEREST = (WS-BALANCE * WS-ANNUAL-RATE) / 365.

            STRING "SUCCESS|INTEREST_ACCRUED|Daily accrual for " CMD-PARAM1 
                   " is: " WS-DAILY-INTEREST
                   DELIMITED BY SIZE INTO WS-OUTPUT-MSG.
            DISPLAY WS-OUTPUT-MSG.
            MOVE 0 TO WS-EXIT-CODE.

        PROCESS-INTEREST-PAYOUT.
            IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email and Amount are required"
                EXIT PROGRAM.
            END-IF.

            MOVE CMD-PARAM2 TO WS-INTEREST-AMOUNT.

            EXEC SQL SET AUTOCOMMIT = 0 END-EXEC.

            EXEC SQL
                SELECT a.account_id INTO :WS-ACCOUNT-ID
                FROM accounts a
                JOIN users u ON a.user_id = u.id
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE NOT = 0
                EXEC SQL ROLLBACK END-EXEC.
                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|ACCOUNT_NOT_FOUND|Account not found"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                UPDATE accounts a
                SET a.balance = a.balance + :WS-INTEREST-AMOUNT
                WHERE a.account_id = :WS-ACCOUNT-ID
            END-EXEC.

            IF SQLCODE NOT = 0
                EXEC SQL ROLLBACK END-EXEC.
                EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description)
                VALUES ('INT-PAY', :WS-ACCOUNT-ID, :WS-INTEREST-AMOUNT, 'CREDIT', 1, 'Monthly Interest Payout')
            END-EXEC.

            IF SQLCODE = 0
                EXEC SQL COMMIT END-EXEC.
                MOVE 0 TO WS-EXIT-CODE
                STRING "SUCCESS|INTEREST_PAID|Amount " WS-INTEREST-AMOUNT 
                       " credited to " CMD-PARAM1
                       DELIMITED BY SIZE INTO WS-OUTPUT-MSG.
                DISPLAY WS-OUTPUT-MSG.
            ELSE
                EXEC SQL ROLLBACK END-EXEC.
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR.
            END-IF.

            EXEC SQL SET AUTOCOMMIT = 1 END-EXEC.

        PROCESS-ADD-REWARDS.
            IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
                MOVE 4 TO WS-EXIT-CODE
                DISPLAY "ERROR|MISSING_PARAM|Email and Transaction Amount are required"
                EXIT PROGRAM.
            END-IF.

            MOVE CMD-PARAM2 TO WS-TXN-AMOUNT.

            EXEC SQL
                SELECT u.id INTO :WS-USER-ID-INTERNAL
                FROM users u
                WHERE u.email = :CMD-PARAM1
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 1 TO WS-EXIT-CODE
                DISPLAY "ERROR|USER_NOT_FOUND|User not found"
                EXIT PROGRAM.
            END-IF.

            * Reward Logic: 1 point for every $100 transferred
            COMPUTE WS-POINTS-EARNED = WS-TXN-AMOUNT / 100.

            IF WS-POINTS-EARNED = 0
                MOVE 0 TO WS-EXIT-CODE
                DISPLAY "SUCCESS|NO_REWARDS|Transaction amount too low for rewards"
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                INSERT INTO user_rewards (user_id, points_balance)
                VALUES (:WS-USER-ID-INTERNAL, :WS-POINTS-EARNED)
                ON DUPLICATE KEY UPDATE points_balance = points_balance + :WS-POINTS-EARNED
            END-EXEC.

            IF SQLCODE NOT = 0
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR
                EXIT PROGRAM.
            END-IF.

            EXEC SQL
                INSERT INTO reward_history (user_id, points_change, reason)
                VALUES (:WS-USER-ID-INTERNAL, :WS-POINTS-EARNED, 'Transfer Reward')
            END-EXEC.

            IF SQLCODE = 0
                MOVE 0 TO WS-EXIT-CODE
                STRING "SUCCESS|REWARDS_ADDED|Points earned: " WS-POINTS-EARNED
                       DELIMITED BY SIZE INTO WS-OUTPUT-MSG.
                DISPLAY WS-OUTPUT-MSG.
            ELSE
                MOVE 2 TO WS-EXIT-CODE
                PERFORM CAPTURE-SQL-ERROR.
            END-IF.



