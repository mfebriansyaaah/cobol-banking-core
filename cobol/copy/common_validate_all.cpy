      *> Shared 6-param validation pair (maint-03b): byte-identical to the
      *> WS-TRIM-IN inline copies (QUOTE/DQUOTE/BSLASH/TICK). Requires
      *> WS-TRIM-IN, WS-BAD, F-QUOTE, F-DQUOTE, F-BSLASH and F-TICK.
      *> Separate file (not in common_validate.cpy): cobc validates every
      *> paragraph of an included copybook against the host's declarations,
      *> so the SEMI pair (F-SEMI) and COUNT-FIELD pair (WS-COUNT-IN/LEN)
      *> live in their own files. Hosts COPY exactly one of the three.
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
