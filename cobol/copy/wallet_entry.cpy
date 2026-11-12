      *> Shared wallet entry validation + trim (maint-07): byte-identical
      *> to the inline paragraphs they replace in wallet_core; shared with
      *> wallet_transfer_core so both entries validate and trim the same way.
      *> Requires WS-CHECK, WS-BAD, F-QUOTE/F-DQUOTE/F-BSLASH/F-SEMI/F-TICK,
      *> WS-TRIM-IDX/WS-TRIM-SRC/WS-TRIM-CNT, WS-I, LS-PARAM1..6 and
      *> WS-PARAM1..6-TRIMMED/LEN. Hosts COPY this in PROCEDURE DIVISION.
        VALIDATE-ALL.
            *> No SQL metacharacters may reach a query string.
            MOVE 0 TO WS-BAD
            MOVE LS-PARAM1 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM2 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM3 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM4 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM5 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM6 TO WS-CHECK
            PERFORM VALIDATE-INPUT.
            EXIT PARAGRAPH.

        VALIDATE-INPUT.
            INSPECT WS-CHECK TALLYING WS-BAD
                FOR ALL F-QUOTE
                WS-BAD FOR ALL F-DQUOTE
                WS-BAD FOR ALL F-BSLASH
                WS-BAD FOR ALL F-SEMI
                WS-BAD FOR ALL F-TICK.
            EXIT PARAGRAPH.

        TRIM-ALL.
            PERFORM TRIM-ONE VARYING WS-TRIM-IDX FROM 1 BY 1
                    UNTIL WS-TRIM-IDX > 6.

        TRIM-ONE.
            EVALUATE WS-TRIM-IDX
                WHEN 1 MOVE LS-PARAM1 TO WS-TRIM-SRC
                WHEN 2 MOVE LS-PARAM2 TO WS-TRIM-SRC
                WHEN 3 MOVE LS-PARAM3 TO WS-TRIM-SRC
                WHEN 4 MOVE LS-PARAM4 TO WS-TRIM-SRC
                WHEN 5 MOVE LS-PARAM5 TO WS-TRIM-SRC
                WHEN 6 MOVE LS-PARAM6 TO WS-TRIM-SRC
            END-EVALUATE
            MOVE 0 TO WS-TRIM-CNT
            PERFORM VARYING WS-I FROM 100 BY -1
                    UNTIL WS-I < 1 OR WS-TRIM-CNT > 0
                IF WS-TRIM-SRC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-TRIM-CNT
                END-IF
            END-PERFORM
            EVALUATE WS-TRIM-IDX
                WHEN 1 MOVE WS-TRIM-SRC TO WS-PARAM1-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P1-LEN
                WHEN 2 MOVE WS-TRIM-SRC TO WS-PARAM2-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P2-LEN
                WHEN 3 MOVE WS-TRIM-SRC TO WS-PARAM3-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P3-LEN
                WHEN 4 MOVE WS-TRIM-SRC TO WS-PARAM4-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P4-LEN
                WHEN 5 MOVE WS-TRIM-SRC TO WS-PARAM5-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P5-LEN
                WHEN 6 MOVE WS-TRIM-SRC TO WS-PARAM6-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P6-LEN
            END-EVALUATE.
