       IDENTIFICATION DIVISION.
       PROGRAM-ID. main_logic.

        ENVIRONMENT DIVISION.
        INPUT-OUTPUT SECTION.
        FILE-CONTROL.
            SELECT OUTPUT-FILE ASSIGN TO "output.txt"
                ORGANIZATION IS LINE SEQUENTIAL.

        CONFIGURATION SECTION.
        SPECIAL-NAMES.
            DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        FILE SECTION.
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
        
        PROCEDURE DIVISION.
        
        MAIN-LOGIC.
            OPEN OUTPUT OUTPUT-FILE.
            ACCEPT INPUT-BUFFER.
            
            UNSTRING INPUT-BUFFER DELIMITED BY "|" 
                INTO CMD-ACTION, CMD-PARAM1, CMD-PARAM2, CMD-PARAM3, CMD-PARAM4
            END-UNSTRING.
            
            IF CMD-ACTION = SPACES
                MOVE "ERROR|MISSING_ACTION" TO OUTPUT-RECORD
                WRITE OUTPUT-RECORD
                STOP RUN
            END-IF.
            
            EVALUATE TRUE
                WHEN CMD-ACTION(1:11) = "GET_BALANCE"
                    CALL "wallet_core" USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 WS-OUTPUT-MSG
                    MOVE WS-OUTPUT-MSG TO OUTPUT-RECORD
                    WRITE OUTPUT-RECORD
                
                WHEN CMD-ACTION(1:8) = "TRANSFER"
                    CALL "wallet_core" USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 WS-OUTPUT-MSG
                    MOVE WS-OUTPUT-MSG TO OUTPUT-RECORD
                    WRITE OUTPUT-RECORD
                
                WHEN CMD-ACTION(1:8) = "GET_USER"
                    CALL "USER-CORE" USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 WS-OUTPUT-MSG
                    MOVE WS-OUTPUT-MSG TO OUTPUT-RECORD
                    WRITE OUTPUT-RECORD
                
                WHEN CMD-ACTION(1:10) = "LIST_USERS"
                    CALL "USER-CORE" USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 WS-OUTPUT-MSG
                    MOVE WS-OUTPUT-MSG TO OUTPUT-RECORD
                    WRITE OUTPUT-RECORD
                
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO OUTPUT-RECORD
                    WRITE OUTPUT-RECORD
            END-EVALUATE.
            
            CLOSE OUTPUT-FILE.
            STOP RUN.
