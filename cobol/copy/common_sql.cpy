      *> Shared user-role lookup (maint-04a): byte-identical to the inline
      *> copies it replaces. The caller stages the email in WS-BIND-1 first
      *> (e.g. MOVE WS-P6-TRIMMED TO WS-BIND-1); the role lands in WS-RESULT.
      *> Requires WS-PREP-SQL, WS-BIND-1..5 and WS-RESULT. Single bind only:
      *> any multi-bind role query stays inline. Five binds (not six): the
      *> 4-param modules declare no WS-BIND-6, and the count argument is 1,
      *> so extra slots are never read.
       LOOKUP-USER-ROLE.
           MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
           EXIT PARAGRAPH.
