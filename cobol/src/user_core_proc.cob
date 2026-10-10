       IDENTIFICATION DIVISION.
       PROGRAM-ID. USER-CORE.
       AUTHOR. KerryHanson1.
       INSTALLATION. ENTERPRISE-BANKING-CORE.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       
       * ---------------------------------------------------------
       * SQLCA - SQL Communication Area
       * ---------------------------------------------------------
       .

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
       * User Data Records
       * ---------------------------------------------------------
       01  WS-USER-RECORD.
           05  WS-USER-ID       PIC 9(10) VALUE ZERO.
           05  WS-USERNAME      PIC X(50) VALUE SPACES.
           05  WS-USER-EMAIL    PIC X(100) VALUE SPACES.
           05  WS-USER-FULLNAME PIC X(100) VALUE SPACES.
           05  WS-USER-STATUS   PIC X(10) VALUE SPACES.

       * ---------------------------------------------------------
       * Exit Codes for Integration
       * ---------------------------------------------------------
       01  WS-EXIT-CODE           PIC 9(2) VALUE 0.
           88  EXIT-SUCCESS        VALUE 0.
           88  EXIT-NOT-FOUND      VALUE 1.
           88  EXIT-DB-ERROR       VALUE 2.
           88  EXIT-INVALID-ARG    VALUE 4.

       * ---------------------------------------------------------
       * Filter Variables
       * ---------------------------------------------------------
       01  WS-STATUS-FILTER    PIC X(10) VALUE 'VERIFIED'.
       01  WS-ROW-COUNT        PIC 9(5) VALUE ZERO.

       LINKAGE SECTION.
       01  LS-CMD-ACTION          PIC X(30).
       01  LS-PARAM1              PIC X(100).
       01  LS-PARAM2              PIC X(100).
       01  LS-PARAM3              PIC X(100).
       01  LS-PARAM4              PIC X(100).
       01  LS-OUTPUT-BUFFER      PIC X(500).

       PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-OUTPUT-BUFFER.
       
       MAIN-LOGIC.
           EVALUATE TRUE
               WHEN LS-CMD-ACTION = "GET_USER"
                   PERFORM ACTION-GET-USER
               WHEN LS-CMD-ACTION = "LIST_USERS"
                   PERFORM ACTION-LIST-USERS
               WHEN OTHER
                   MOVE 4 TO WS-EXIT-CODE
                   MOVE "ERROR|INVALID_ACTION|Action not supported in UserCore" TO LS-OUTPUT-BUFFER
           END-EVALUATE.

           GOBACK.

       ACTION-GET-USER.
           IF LS-PARAM1 = SPACES
               MOVE 4 TO WS-EXIT-CODE
               MOVE "ERROR|MISSING_PARAM|User ID required" TO LS-OUTPUT-BUFFER
               GOBACK.
           END-IF.

           EXEC SQL
               SELECT id, username, email, full_name, status
               INTO :WS-USER-ID, :WS-USERNAME, :WS-USER-EMAIL, :WS-USER-FULLNAME, :WS-USER-STATUS
               FROM users
               WHERE id = :LS-PARAM1
           END-EXEC.

           IF SQLCODE = 0
               MOVE 0 TO WS-EXIT-CODE
               STRING WS-USER-ID "|" WS-USERNAME "|" WS-USER-EMAIL "|"
                      WS-USER-FULLNAME "|" WS-USER-STATUS
                      DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
           ELSE
               MOVE 1 TO WS-EXIT-CODE
               MOVE "ERROR|NOT_FOUND|User not found" TO LS-OUTPUT-BUFFER
           END-IF.

       ACTION-LIST-USERS.
           MOVE ZERO TO WS-ROW-COUNT.
           
           * Set filter if provided in LS-PARAM1
           IF LS-PARAM1 NOT = SPACES
               MOVE LS-PARAM1 TO WS-STATUS-FILTER.
           END-IF.

           EXEC SQL
               DECLARE USER_CURSOR CURSOR FOR
               SELECT id, username, email, full_name, status
               FROM users
               WHERE status = :WS-STATUS-FILTER
           END-EXEC.

           EXEC SQL OPEN USER_CURSOR END-EXEC.
           
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH USER_CURSOR
                   INTO :WS-USER-ID, :WS-USERNAME, :WS-USER-EMAIL, :WS-USER-FULLNAME, :WS-USER-STATUS
               END-EXEC.
               
               IF SQLCODE = 0
                   ADD 1 TO WS-ROW-COUNT
                   STRING WS-USER-ID "|" WS-USERNAME "|" WS-USER-EMAIL "|"
                          WS-USER-FULLNAME "|" WS-USER-STATUS
                          DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                   DISPLAY LS-OUTPUT-BUFFER
               END-IF.
           END-PERFORM.

           EXEC SQL CLOSE USER_CURSOR END-EXEC.
           
           IF WS-ROW-COUNT = 0
               MOVE 1 TO WS-EXIT-CODE
               MOVE "ERROR|NOT_FOUND|No users found" TO LS-OUTPUT-BUFFER
           ELSE
               MOVE 0 TO WS-EXIT-CODE
               MOVE "SUCCESS|LIST_DONE|Fetched " WS-ROW-COUNT " users" TO LS-OUTPUT-BUFFER.
