      *> Shared validation paragraph (PR-022): byte-identical to the
      *> inline copies it replaces. Requires WS-COUNT-IN/LEN,
      *> WS-BAD and WS-I declarations.
       VALIDATE-COUNT-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-COUNT-LEN
           PERFORM VARYING WS-I FROM 30 BY -1
               UNTIL WS-I < 1 OR WS-COUNT-LEN > 0
               IF WS-COUNT-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-COUNT-LEN
               END-IF
           END-PERFORM
           IF WS-COUNT-LEN < 1 OR WS-COUNT-LEN > 18
               MOVE 1 TO WS-BAD
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-COUNT-LEN
               IF WS-COUNT-IN(WS-I:1) IS NOT NUMERIC
                   MOVE 1 TO WS-BAD
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.
