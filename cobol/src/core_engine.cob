       IDENTIFICATION DIVISION.
       PROGRAM-ID. core_engine.

        ENVIRONMENT DIVISION.
        INPUT-OUTPUT SECTION.
        FILE-CONTROL.
            SELECT INPUT-FILE ASSIGN TO "input.txt"
                ORGANIZATION IS LINE SEQUENTIAL.
            SELECT OUTPUT-FILE ASSIGN TO "output.txt"
                ORGANIZATION IS LINE SEQUENTIAL.

        DATA DIVISION.
        FILE SECTION.
        FD  INPUT-FILE.
        01  INPUT-RECORD       PIC X(500).
        FD  OUTPUT-FILE.
        01  OUTPUT-RECORD     PIC X(500).

        WORKING-STORAGE SECTION.
        01  INPUT-BUFFER       PIC X(500) VALUE SPACES.
        01  CMD-ACTION        PIC X(20) VALUE SPACES.
        01  CMD-PARAM1        PIC X(100) VALUE SPACES.
        01  CMD-PARAM2        PIC X(100) VALUE SPACES.
        01  CMD-PARAM3        PIC X(100) VALUE SPACES.
        01  CMD-PARAM4        PIC X(100) VALUE SPACES.
        01  WS-OUTPUT-MSG     PIC X(500) VALUE SPACES.
       01  SIM-DB-USERS.
           05  USER-ENTRY OCCURS 100 TIMES.
               10 USER-ID       PIC 9(10).
               10 USER-EMAIL   PIC X(100).
               10 USER-STATUS   PIC X(10).
        01  SIM-DB-ACCOUNTS.
            05  ACC-ENTRY OCCURS 100 TIMES.
                10 ACC-ID        PIC 9(10).
                10 ACC-USER-ID   PIC 9(10).
                10 ACC-BALANCE-RAW PIC 9(15)V99.
                10 ACC-CURRENCY  PIC 9(10).
        01  SIM-DB-COUNTERS.
            05  USER-COUNT      PIC 9(4) VALUE 0.
            05  ACC-COUNT       PIC 9(4) VALUE 0.
        01  WS-IDX              PIC 9(4).
        01  WS-FOUND-IDX        PIC 9(4) VALUE 0.
        01  WS-TEMP-BAL         PIC 9(15)V99.
        01  WS-TEMP-AMT        PIC 9(15)V99.
        01  WS-NUM-CONV         PIC ZZZZZZZZZZZZZZZZZ.99.

        PROCEDURE DIVISION.
        
        MAIN-LOGIC.
            OPEN INPUT INPUT-FILE
            OPEN OUTPUT OUTPUT-FILE
            PERFORM INIT-SIM-DB.
            
            READ INPUT-FILE INTO INPUT-BUFFER
                AT END 
                    CLOSE INPUT-FILE
                    CLOSE OUTPUT-FILE
                    STOP RUN
                END-READ.
            
            UNSTRING INPUT-BUFFER DELIMITED BY "|" 
                INTO CMD-ACTION, CMD-PARAM1, CMD-PARAM2, CMD-PARAM3, CMD-PARAM4
            END-UNSTRING.
            
            IF CMD-ACTION = SPACES
                MOVE "ERROR|MISSING_ACTION" TO OUTPUT-RECORD
                WRITE OUTPUT-RECORD
                STOP RUN
            END-IF.
            
            EVALUATE TRUE
                WHEN CMD-ACTION(1:13) = "CHECK_BALANCE"
                    PERFORM GET-BALANCE-LOGIC
                WHEN CMD-ACTION(1:8) = "TRANSFER"
                    PERFORM TRANSFER-LOGIC
                WHEN CMD-ACTION(1:8) = "GET_USER"
                    PERFORM ACTION-GET-USER
                WHEN CMD-ACTION(1:10) = "LIST_USERS"
                    PERFORM ACTION-LIST-USERS
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO OUTPUT-RECORD
                    WRITE OUTPUT-RECORD
            END-EVALUATE.
            
            CLOSE INPUT-FILE
            CLOSE OUTPUT-FILE
            STOP RUN.

        INIT-SIM-DB.
            MOVE 2 TO USER-COUNT.
            MOVE 1 TO USER-ID(1). 
            MOVE "sender@test.com" TO USER-EMAIL(1). 
            MOVE "VERIFIED" TO USER-STATUS(1).
            MOVE 2 TO USER-ID(2). 
            MOVE "receiver@test.com" TO USER-EMAIL(2). 
            MOVE "VERIFIED" TO USER-STATUS(2).
            
            MOVE 2 TO ACC-COUNT.
            MOVE 1 TO ACC-ID(1). 
            MOVE 1 TO ACC-USER-ID(1). 
            MOVE 1000.00 TO ACC-BALANCE-RAW(1).
            MOVE 2 TO ACC-ID(2). 
            MOVE 2 TO ACC-USER-ID(2). 
            MOVE 0.00 TO ACC-BALANCE-RAW(2).

        GET-BALANCE-LOGIC.
            PERFORM FIND-USER-BY-EMAIL.
            IF WS-FOUND-IDX = 0
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO OUTPUT-RECORD
            ELSE
                MOVE ACC-BALANCE-RAW(WS-FOUND-IDX) TO WS-NUM-CONV
                MOVE WS-NUM-CONV TO OUTPUT-RECORD
            END-IF.
            WRITE OUTPUT-RECORD.
            GOBACK.

        TRANSFER-LOGIC.
            PERFORM FIND-USER-BY-EMAIL.
            IF WS-FOUND-IDX = 0
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO OUTPUT-RECORD
                WRITE OUTPUT-RECORD
                GOBACK
            END-IF.
            
            MOVE ACC-BALANCE-RAW(WS-FOUND-IDX) TO WS-TEMP-BAL.
            COMPUTE WS-TEMP-AMT = FUNCTION NUMVAL(CMD-PARAM3) END-COMPUTE.
            
            IF WS-TEMP-BAL < WS-TEMP-AMT
                MOVE "ERROR|INSUFFICIENT_FUNDS" TO OUTPUT-RECORD
                WRITE OUTPUT-RECORD
                GOBACK
            END-IF.
            
            MOVE CMD-PARAM2 TO CMD-PARAM1.
            PERFORM FIND-USER-BY-EMAIL.
            IF WS-FOUND-IDX = 0
                MOVE "ERROR|TARGET_NOT_FOUND" TO OUTPUT-RECORD
                WRITE OUTPUT-RECORD
                GOBACK
            END-IF.
            
            MOVE WS-FOUND-IDX TO WS-IDX.
            SUBTRACT WS-TEMP-AMT FROM ACC-BALANCE-RAW(WS-FOUND-IDX) END-SUBTRACT.
            ADD WS-TEMP-AMT TO ACC-BALANCE-RAW(WS-IDX) END-ADD.
            
            MOVE "SUCCESS|TRANSFER_OK" TO OUTPUT-RECORD.
            WRITE OUTPUT-RECORD.
            GOBACK.

        ACTION-GET-USER.
            MOVE 0 TO WS-FOUND-IDX.
            PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > USER-COUNT
                IF USER-EMAIL(WS-IDX) = CMD-PARAM1
                    MOVE WS-IDX TO WS-FOUND-IDX
                END-IF
            END-PERFORM.
            
            IF WS-FOUND-IDX = 0
                MOVE "ERROR|NOT_FOUND" TO OUTPUT-RECORD
            ELSE
                STRING USER-ID(WS-FOUND-IDX) "|" USER-EMAIL(WS-FOUND-IDX) 
                       DELIMITED BY SIZE INTO OUTPUT-RECORD END-STRING
            END-IF.
            WRITE OUTPUT-RECORD.
            GOBACK.

        ACTION-LIST-USERS.
            MOVE "SUCCESS|LIST_DONE" TO OUTPUT-RECORD.
            WRITE OUTPUT-RECORD.
            GOBACK.

       FIND-USER-BY-EMAIL.
           MOVE 0 TO WS-FOUND-IDX.
           PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > USER-COUNT
               IF USER-EMAIL(WS-IDX) = CMD-PARAM1
                   MOVE WS-IDX TO WS-FOUND-IDX
               END-IF
           END-PERFORM.
           GOBACK.
