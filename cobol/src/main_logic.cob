       IDENTIFICATION DIVISION.
       PROGRAM-ID. main_logic.

        ENVIRONMENT DIVISION.
        CONFIGURATION SECTION.
        SPECIAL-NAMES.
            DECIMAL-POINT IS COMMA.

        INPUT-OUTPUT SECTION.
        FILE-CONTROL.
            SELECT INPUT-FILE ASSIGN TO "input.txt"
                ORGANIZATION IS LINE SEQUENTIAL.
            SELECT OUTPUT-FILE ASSIGN TO "output.txt"
                ORGANIZATION IS LINE SEQUENTIAL.

        DATA DIVISION.
        FILE SECTION.
        FD  INPUT-FILE.
        01  INPUT-RECORD     PIC X(500).
        FD  OUTPUT-FILE.
        01  OUTPUT-RECORD     PIC X(500).

        WORKING-STORAGE SECTION.
        01  INPUT-BUFFER       PIC X(500) VALUE SPACES.
        01  CMD-ACTION        PIC X(20) VALUE SPACES.
        01  CMD-PARAM1        PIC X(100) VALUE SPACES.
        01  CMD-PARAM2        PIC X(100) VALUE SPACES.
        01  CMD-PARAM3        PIC X(100) VALUE SPACES.
        01  CMD-PARAM4        PIC X(100) VALUE SPACES.
        01  CMD-PARAM5        PIC X(100) VALUE SPACES.
        01  CMD-PARAM6        PIC X(100) VALUE SPACES.
        01  WS-OUTPUT-MSG     PIC X(16384) VALUE SPACES.
        01  WS-OUT-LEN        PIC 9(5) VALUE 0.
        01  WS-OUT-POS        PIC 9(5) VALUE 1.
        01  WS-OUT-I          PIC 9(5) VALUE 0.
        01  WS-ARGS           PIC X(200) VALUE SPACES.
        01  WS-SERVE-DONE     PIC X VALUE 'N'.
        01  WS-EOF            PIC X VALUE 'N'.
        01  DISPATCH-COUNT    PIC 9(3) VALUE 0.
        01  DISPATCH-IDX      PIC 9(3) VALUE 1.
        01  DISPATCH-FOUND    PIC X VALUE 'N'.
        01  DISPATCH-TABLE.
            05  DISPATCH-ENTRY OCCURS 1000 TIMES.
                10  D-PREFIX     PIC X(20) VALUE SPACES.
                10  D-PREFIX-LEN PIC 9(2) VALUE 0.
                10  D-PROGRAM   PIC X(32) VALUE SPACES.

        
        PROCEDURE DIVISION.
        
        MAIN-LOGIC.
            PERFORM INIT-DISPATCH-TABLE
            ACCEPT WS-ARGS FROM COMMAND-LINE END-ACCEPT
            IF WS-ARGS(1:7) = "--serve"
                PERFORM SERVE-MODE
            ELSE
                PERFORM FILE-MODE
            END-IF.
            MOVE 0 TO RETURN-CODE.
            STOP RUN.

        FILE-MODE.
            *> Default: read one request line from input.txt, write output.txt.
            OPEN INPUT INPUT-FILE
            OPEN OUTPUT OUTPUT-FILE
            MOVE 'N' TO WS-EOF
            MOVE SPACES TO INPUT-BUFFER
            READ INPUT-FILE INTO INPUT-BUFFER
                AT END MOVE 'Y' TO WS-EOF
            END-READ
            IF WS-EOF NOT = 'Y'
                PERFORM PARSE-INPUT
                PERFORM DISPATCH-ACTION
                PERFORM WRITE-OUTPUT
            END-IF.
            CLOSE INPUT-FILE
            CLOSE OUTPUT-FILE.
            EXIT PARAGRAPH.

        SERVE-MODE.
            *> Long-running mode: one request line per stdin, one result line
            *> per stdout, until QUIT or EOF (used by the worker pool).
            PERFORM UNTIL WS-SERVE-DONE = 'Y'
                MOVE SPACES TO INPUT-BUFFER
                ACCEPT INPUT-BUFFER END-ACCEPT
                IF INPUT-BUFFER = SPACES
                    MOVE 'Y' TO WS-SERVE-DONE
                ELSE
                    IF INPUT-BUFFER(1:4) = "QUIT"
                        MOVE 'Y' TO WS-SERVE-DONE
                    ELSE
                        PERFORM PARSE-INPUT
                        PERFORM DISPATCH-ACTION
                        IF WS-OUTPUT-MSG = SPACES
                            MOVE "ERROR|EMPTY_RESPONSE" TO WS-OUTPUT-MSG
                        END-IF
                        DISPLAY FUNCTION TRIM(WS-OUTPUT-MSG) END-DISPLAY
                    END-IF
                END-IF
            END-PERFORM.
            EXIT PARAGRAPH.

        PARSE-INPUT.
            MOVE SPACES TO CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 CMD-PARAM5 CMD-PARAM6
            UNSTRING INPUT-BUFFER DELIMITED BY "|" 
                INTO CMD-ACTION, CMD-PARAM1, CMD-PARAM2, CMD-PARAM3, CMD-PARAM4, CMD-PARAM5, CMD-PARAM6
            END-UNSTRING.
            EXIT PARAGRAPH.

        INIT-DISPATCH-TABLE.
            COPY "dispatch_table.cpy".
            EXIT PARAGRAPH.

        DISPATCH-ACTION.
            *> Table-driven dispatch: longest prefix first.
            MOVE 'N' TO DISPATCH-FOUND
            MOVE 1 TO DISPATCH-IDX
            PERFORM UNTIL DISPATCH-IDX > DISPATCH-COUNT OR DISPATCH-FOUND = 'Y'
                IF D-PREFIX-LEN(DISPATCH-IDX) > 0
                    IF CMD-ACTION(1:D-PREFIX-LEN(DISPATCH-IDX)) = D-PREFIX(DISPATCH-IDX)(1:D-PREFIX-LEN(DISPATCH-IDX))
                        MOVE 'Y' TO DISPATCH-FOUND
                        IF D-PROGRAM(DISPATCH-IDX) = "user_core"
                            CALL D-PROGRAM(DISPATCH-IDX) USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 WS-OUTPUT-MSG
                                END-CALL
                        ELSE
                            CALL D-PROGRAM(DISPATCH-IDX) USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 CMD-PARAM5 CMD-PARAM6 WS-OUTPUT-MSG
                                END-CALL
                        END-IF
                    END-IF
                END-IF
                ADD 1 TO DISPATCH-IDX
                END-ADD
            END-PERFORM
            IF DISPATCH-FOUND = 'N'
                IF CMD-ACTION = SPACES
                    MOVE "ERROR|MISSING_ACTION" TO WS-OUTPUT-MSG
                ELSE
                    MOVE "ERROR|INVALID_ACTION" TO WS-OUTPUT-MSG
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        WRITE-OUTPUT.
            *> Emit WS-OUTPUT-MSG as one or more 500-char records. The gateway
            *> joins the lines back; trailing spaces in each line are padding.
            MOVE 0 TO WS-OUT-LEN
            PERFORM VARYING WS-OUT-I FROM 16384 BY -1 UNTIL WS-OUT-I < 1 OR WS-OUT-LEN > 0
                IF WS-OUTPUT-MSG(WS-OUT-I:1) NOT = SPACE
                    MOVE WS-OUT-I TO WS-OUT-LEN
                END-IF
            END-PERFORM
            IF WS-OUT-LEN = 0
                MOVE SPACES TO OUTPUT-RECORD
                WRITE OUTPUT-RECORD END-WRITE
                EXIT PARAGRAPH
            END-IF
            PERFORM VARYING WS-OUT-POS FROM 1 BY 500 UNTIL WS-OUT-POS > WS-OUT-LEN
                MOVE WS-OUTPUT-MSG(WS-OUT-POS:500) TO OUTPUT-RECORD
                WRITE OUTPUT-RECORD END-WRITE
            END-PERFORM.
            EXIT PARAGRAPH.
