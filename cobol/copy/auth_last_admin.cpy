      *> Last-admin guard (maint-15C): extracted verbatim from auth_core.cob
      *> and auth_recovery_core.cob, where the paragraph had drifted into two
      *> byte-identical copies. Both hosts declare the same interface
      *> (WS-ALLOWED, WS-PARAM1/2-TRIMMED, WS-P2-LEN, LOOKUP-USER-ROLE,
      *> WS-PREP-SQL, WS-BIND-1, WS-RESULT) and PERFORM it from their own
      *> role-change actions.

        GUARD-LAST-ADMIN-ROLE.
            *> p1 = target email, p2 = new role. Sets WS-ALLOWED = 1 when the
            *> change still leaves an active (VERIFIED) SUPER_ADMIN, so the last
            *> administrator can never be demoted away.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM2-TRIMMED(1:WS-P2-LEN) = "SUPER_ADMIN"
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM users WHERE role = 'SUPER_ADMIN' AND status = 'VERIFIED' AND email <> ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "0" AND WS-RESULT(1:5) NOT = "ERROR"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            EXIT PARAGRAPH.
