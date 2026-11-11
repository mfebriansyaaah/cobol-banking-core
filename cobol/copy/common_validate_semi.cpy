      *> Shared 6-param validation pair with semicolons (maint-03b):
      *> byte-identical to the WS-TRIM-IN inline copies that also reject
      *> F-SEMI. Requires WS-TRIM-IN, WS-BAD, F-QUOTE, F-DQUOTE, F-BSLASH,
      *> F-SEMI and F-TICK. Separate file from common_validate.cpy and
      *> common_validate_all.cpy: cobc validates every paragraph of an
      *> included copybook against the host's declarations, so hosts COPY
      *> exactly one of the three files.
      *>
      *> The entry name stays VALIDATE-ALL (not VALIDATE-ALL-SEMI): SEMI
      *> hosts PERFORM the plain names, and each host sees exactly one
      *> definition. Only VALIDATE-INPUT-SEMI carries a distinct name.
       VALIDATE-ALL.
           MOVE 0 TO WS-BAD
           MOVE LS-PARAM1 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT-SEMI
           MOVE LS-PARAM2 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT-SEMI
           MOVE LS-PARAM3 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT-SEMI
           MOVE LS-PARAM4 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT-SEMI
           MOVE LS-PARAM5 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT-SEMI
           MOVE LS-PARAM6 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT-SEMI.
           EXIT PARAGRAPH.

       VALIDATE-INPUT-SEMI.
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-QUOTE
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-DQUOTE
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-BSLASH
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-SEMI
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-TICK.
           EXIT PARAGRAPH.
