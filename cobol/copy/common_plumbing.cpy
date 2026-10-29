      *> Common plumbing shared by generated domain modules.
      *> Extracted verbatim from cobol/src/cost_center_core.cob (P1).
      *> Requires the template WORKING-STORAGE names (WS-TRIM-*, WS-P*-TRIMMED,
      *> WS-BAD, WS-RLEN, WS-RESULT, LS-PARAM1..6, F-QUOTE/DQUOTE/BSLASH/TICK).

        VALIDATE-ALL.
            MOVE 0 TO WS-BAD
            MOVE LS-PARAM1 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM2 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM3 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM4 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM5 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM6 TO WS-TRIM-IN
            PERFORM VALIDATE-INPUT.
            EXIT PARAGRAPH.


        VALIDATE-INPUT.
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-QUOTE
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-DQUOTE
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-BSLASH
            INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-TICK.
            EXIT PARAGRAPH.


        TRIM-ALL.
            MOVE LS-PARAM1 TO WS-TRIM-IN
            PERFORM TRIM-VALUE
            MOVE WS-TRIM-OUT TO WS-P1-TRIMMED
            MOVE WS-TRIM-LEN TO WS-P1-LEN
            MOVE LS-PARAM2 TO WS-TRIM-IN
            PERFORM TRIM-VALUE
            MOVE WS-TRIM-OUT TO WS-P2-TRIMMED
            MOVE WS-TRIM-LEN TO WS-P2-LEN
            MOVE LS-PARAM3 TO WS-TRIM-IN
            PERFORM TRIM-VALUE
            MOVE WS-TRIM-OUT TO WS-P3-TRIMMED
            MOVE WS-TRIM-LEN TO WS-P3-LEN
            MOVE LS-PARAM4 TO WS-TRIM-IN
            PERFORM TRIM-VALUE
            MOVE WS-TRIM-OUT TO WS-P4-TRIMMED
            MOVE WS-TRIM-LEN TO WS-P4-LEN
            MOVE LS-PARAM5 TO WS-TRIM-IN
            PERFORM TRIM-VALUE
            MOVE WS-TRIM-OUT TO WS-P5-TRIMMED
            MOVE WS-TRIM-LEN TO WS-P5-LEN
            MOVE LS-PARAM6 TO WS-TRIM-IN
            PERFORM TRIM-VALUE
            MOVE WS-TRIM-OUT TO WS-P6-TRIMMED
            MOVE WS-TRIM-LEN TO WS-P6-LEN.
            EXIT PARAGRAPH.


        TRIM-VALUE.
            MOVE WS-TRIM-IN TO WS-TRIM-OUT
            MOVE 0 TO WS-TRIM-LEN
            PERFORM VARYING WS-I FROM 100 BY -1
                UNTIL WS-I < 1 OR WS-TRIM-LEN > 0
                IF WS-TRIM-OUT(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-TRIM-LEN
                END-IF
            END-PERFORM
            IF WS-TRIM-LEN = 0
                MOVE 1 TO WS-TRIM-LEN
            END-IF.
            EXIT PARAGRAPH.


        TRIM-RESULT-LEN.
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-J FROM 16384 BY -1
                UNTIL WS-J < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-J:1) NOT = SPACE
                    MOVE WS-J TO WS-RLEN
                END-IF
            END-PERFORM
            IF WS-RLEN = 0
                MOVE 1 TO WS-RLEN
            END-IF.
            EXIT PARAGRAPH.

