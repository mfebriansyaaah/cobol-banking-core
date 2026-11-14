      *> Shared authorization paragraph (maint-00c pilot): byte-identical to
      *> the inline copies it replaces, except the denied-audit target.
      *> The caller sets WS-DENIED-TARGET before PERFORMing (e.g. MOVE
      *> "CARD_CORE" TO WS-DENIED-TARGET). Requires WS-ALLOWED, WS-PREP-SQL,
      *> WS-BIND-1..6, WS-RESULT, WS-P6-TRIMMED, WS-DENIED-ACTOR,
      *> WS-DENIED-TARGET, and the host module's own AUDIT-DENIED paragraph.
       ALLOW-ADMIN.
           MOVE 0 TO WS-ALLOWED
           MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P6-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
               MOVE 1 TO WS-ALLOWED
           END-IF
           IF WS-ALLOWED NOT = 1
               MOVE WS-P6-TRIMMED TO WS-DENIED-ACTOR
               PERFORM AUDIT-DENIED
           END-IF.
           EXIT PARAGRAPH.

       ADMIN-GUARD.
           *> Shared 6-line admin prologue in one PERFORM (DRY-06B): runs
           *> the shared ALLOW-ADMIN, and on refusal writes the single
           *> ERROR|FORBIDDEN output. No new working storage: WS-ALLOWED
           *> already carries the verdict (a 01 here would not compile —
           *> this copybook is included in PROCEDURE DIVISION). The caller
           *> sets WS-DENIED-TARGET first, then exits unless WS-ALLOWED.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ADMIN-GUARD-RESULT.
           *> Same guard for actions that report through WS-RESULT instead
           *> of LS-OUTPUT-BUFFER (loan_schedule family: their epilogue
           *> moves WS-RESULT to the output buffer). Byte-identical to the
           *> inline variant it replaces.
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.
