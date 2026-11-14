      *> Shared wallet cap validators (DRY-02): byte-identical to the
      *> inline paragraphs they replace in the five cap-enforcing wallet
      *> modules. Requires WS-CAP-OK, WS-CAP-LEN, WS-CAP-SRC and WS-I.
      *> Hosts COPY this in PROCEDURE DIVISION.
        CHECK-CAP-DIGITS.
            *> Caps are whole major units, digits only: env_or_raw keeps the raw
            *> text so a dotted or malformed setting fails closed below
            *> instead of silently becoming a different number.
            MOVE "Y" TO WS-CAP-OK
            MOVE 0 TO WS-CAP-LEN
            PERFORM VARYING WS-I FROM 20 BY -1 UNTIL WS-I < 1 OR WS-CAP-LEN > 0
                IF WS-CAP-SRC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-CAP-LEN
                END-IF
            END-PERFORM.
            IF WS-CAP-LEN = 0
                MOVE "N" TO WS-CAP-OK
            END-IF.
            IF WS-CAP-LEN > 0
                PERFORM CHECK-CAP-CHARS
            END-IF.
            EXIT PARAGRAPH.
        CHECK-CAP-CHARS.
            *> Character scan kept in its own paragraph so the loop above
            *> stays a single sentence per the inline-scope rule.
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-CAP-LEN
                IF WS-CAP-SRC(WS-I:1) < "0" OR WS-CAP-SRC(WS-I:1) > "9"
                    MOVE "N" TO WS-CAP-OK
                END-IF
            END-PERFORM.
            EXIT PARAGRAPH.
