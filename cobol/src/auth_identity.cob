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

       01  WS-OUTPUT-MSG     PIC X(500) VALUE SPACES.
       01  WS-SQL-STATE      PIC X(5) VALUE SPACES.
       01  WS-USER-ROLE      PIC X(20) VALUE SPACES.
       
       * ---------------------------------------------------------
       * Hashing & Random Variables
       * ---------------------------------------------------------
       01  WS-RAW-PASSWORD   PIC X(100) VALUE SPACES.
       01  WS-HASHED-PASS    PIC X(100) VALUE SPACES.
       01  WS-RANDOM-CODE    PIC X(6) VALUE SPACES.

       LINKAGE SECTION.
       01  LS-ARG-COUNT      PIC 9(4) COMP-5.
       01  LS-ARG-VALUE     PIC X(100) OCCURS 10 TIMES.

       PROCEDURE DIVISION USING LS-ARG-COUNT LS-ARG-VALUE.
       MAIN-LOGIC.
           PERFORM INITIALIZE-PROGRAM.
           PERFORM PARSE-ARGUMENTS.
           
           * Tugas #3: Implement Basic DB Connectivity
           IF CMD-ACTION = "TEST_CONN"
               PERFORM CONNECT-DATABASE
               IF EXIT-SUCCESS
                   DISPLAY "SUCCESS|DB_CONNECTED|Connection established successfully"
               ELSE
                   PERFORM CAPTURE-SQL-ERROR
               END-IF
               STOP RUN WS-EXIT-CODE
           END-IF.

           * Tugas #4: Hashing Test (Temporary for verification)
           IF CMD-ACTION = "TEST_HASH"
               MOVE CMD-PARAM1 TO WS-RAW-PASSWORD
               CALL "hash_password" USING BY REFERENCE WS-RAW-PASSWORD 
                                          BY REFERENCE WS-HASHED-PASS
               DISPLAY "SUCCESS|HASHED|" WS-HASHED-PASS
               STOP RUN WS-EXIT-CODE
           END-IF.

           * Tugas #5: Implement REQUEST_SIGNUP
           IF CMD-ACTION = "REQUEST_SIGNUP"
               PERFORM CONNECT-DATABASE
               IF EXIT-SUCCESS
                   PERFORM PROCESS-SIGNUP
               ELSE
                   PERFORM CAPTURE-SQL-ERROR
               END-IF
               STOP RUN WS-EXIT-CODE
           END-IF.

           * Tugas #7: Implement VERIFY_EMAIL
           IF CMD-ACTION = "VERIFY_EMAIL"
               PERFORM CONNECT-DATABASE
               IF EXIT-SUCCESS
                   PERFORM PROCESS-VERIFICATION
               ELSE
                   PERFORM CAPTURE-SQL-ERROR
               END-IF
               STOP RUN WS-EXIT-CODE
           END-IF.

           * Tugas #8: Implement RBAC (Role Based Access Control)
           IF CMD-ACTION = "CHECK_ROLE"
               PERFORM CONNECT-DATABASE
               IF EXIT-SUCCESS
                   PERFORM PROCESS-CHECK-ROLE
               ELSE
                   PERFORM CAPTURE-SQL-ERROR
               END-IF
               STOP RUN WS-EXIT-CODE
           END-IF.

           * Routing Logic (To be implemented in subsequent tasks)
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
           * Menangkap pesan error dari SQLCA jika tersedia
           IF SQLCODE NOT = 0
               STRING "SQLSTATE: " WS-SQL-STATE " | SQLCODE: " SQLCODE
                      " | MSG: " SQLERRMC
                      DELIMITED BY SIZE INTO WS-OUTPUT-MSG
           ELSE
               MOVE "No SQL Error detected" TO WS-OUTPUT-MSG.
           
           DISPLAY "ERROR|DB_ERROR|" WS-OUTPUT-MSG.

       PROCESS-SIGNUP.
           * Parameter: CMD-PARAM1=email, CMD-PARAM2=pass, CMD-PARAM3=name, CMD-PARAM4=dob
           IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|MISSING_PARAM|Email and Password are required"
               EXIT PROGRAM.

           * 1. Cek apakah email sudah ada
           EXEC SQL
               SELECT id FROM users WHERE email = :CMD-PARAM1
           END-EXEC.
           
           IF SQLCODE = 0
               MOVE 1 TO WS-EXIT-CODE
               DISPLAY "ERROR|USER_EXISTS|Email already registered"
               EXIT PROGRAM.

           * 2. Hash Password menggunakan Library C
           MOVE CMD-PARAM2 TO WS-RAW-PASSWORD
           CALL "hash_password" USING BY REFERENCE WS-RAW-PASSWORD 
                                      BY REFERENCE WS-HASHED-PASS.

           * 3. Generate Kode Verifikasi 6 Angka menggunakan Library C
           CALL "generate_random_code" USING BY REFERENCE WS-RANDOM-CODE.

           * 4. Insert User ke Database
           EXEC SQL
               INSERT INTO users (email, password_hash, full_name, dob, status, verification_code)
               VALUES (:CMD-PARAM1, :WS-HASHED-PASS, :CMD-PARAM3, :CMD-PARAM4, 'UNVERIFIED', :WS-RANDOM-CODE)
           END-EXEC.

           IF SQLCODE = 0
               MOVE 0 TO WS-EXIT-CODE
               STRING "SUCCESS|USER_CREATED|Code: " WS-RANDOM-CODE
                   DELIMITED BY SIZE INTO WS-OUTPUT-MSG
               DISPLAY WS-OUTPUT-MSG
           ELSE
               MOVE 2 TO WS-EXIT-CODE
               PERFORM CAPTURE-SQL-ERROR.

       PROCESS-VERIFICATION.
           * Parameter: CMD-PARAM1=email, CMD-PARAM2=code
           IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|MISSING_PARAM|Email and Code are required"
               EXIT PROGRAM.

           * 1. Validasi kode verifikasi
           EXEC SQL
               SELECT id FROM users 
               WHERE email = :CMD-PARAM1 AND verification_code = :CMD-PARAM2
           END-EXEC.

           IF SQLCODE = 0
               * 2. Update status menjadi VERIFIED
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
           * Parameter: CMD-PARAM1=email, CMD-PARAM2=required_role
           IF CMD-PARAM1 = SPACES OR CMD-PARAM2 = SPACES
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|MISSING_PARAM|Email and Required Role are required"
               EXIT PROGRAM
           END-IF.

           IF FUNCTION TRIM(CMD-PARAM2) NOT = "USER" AND
              FUNCTION TRIM(CMD-PARAM2) NOT = "MANAGER" AND
              FUNCTION TRIM(CMD-PARAM2) NOT = "SUPER_ADMIN"
               MOVE 4 TO WS-EXIT-CODE
               DISPLAY "ERROR|INVALID_ROLE|Role must be USER, MANAGER, or SUPER_ADMIN"
               EXIT PROGRAM
           END-IF.

           EXEC SQL
               SELECT role INTO :WS-USER-ROLE
                FROM users WHERE email = :CMD-PARAM1
           END-EXEC.

            EVALUATE SQLCODE
                WHEN 0
                    IF FUNCTION TRIM(WS-USER-ROLE) = FUNCTION TRIM(CMD-PARAM2)
                        MOVE 0 TO WS-EXIT-CODE
                        MOVE SPACES TO WS-OUTPUT-MSG
                        STRING "SUCCESS|ROLE_VERIFIED|User has the required role: " 
                               FUNCTION TRIM(WS-USER-ROLE)
                            DELIMITED BY SIZE INTO WS-OUTPUT-MSG
                        DISPLAY FUNCTION TRIM(WS-OUTPUT-MSG)
                    ELSE
                        MOVE 5 TO WS-EXIT-CODE
                        MOVE SPACES TO WS-OUTPUT-MSG
                        STRING "ERROR|UNAUTHORIZED|Required " FUNCTION TRIM(CMD-PARAM2) 
                               ", but got " FUNCTION TRIM(WS-USER-ROLE)
                            DELIMITED BY SIZE INTO WS-OUTPUT-MSG
                        DISPLAY FUNCTION TRIM(WS-OUTPUT-MSG)
                    END-IF
                WHEN 100
                    MOVE 1 TO WS-EXIT-CODE
                    DISPLAY "ERROR|USER_NOT_FOUND|Email not registered in the system"
                WHEN OTHER
                    MOVE 2 TO WS-EXIT-CODE
                    PERFORM CAPTURE-SQL-ERROR
            END-EVALUATE.
