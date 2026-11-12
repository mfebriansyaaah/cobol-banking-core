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
      *> Shared user-id lookup (maint-04b): caller stages the email in
      *> WS-BIND-1; the id lands in WS-RESULT. Same footprint as
      *> LOOKUP-USER-ROLE (WS-PREP-SQL, WS-BIND-1..5, WS-RESULT).
       LOOKUP-USER-ID.
           MOVE "SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
           EXIT PARAGRAPH.

      *> Shared last-insert-id lookup (maint-04b): no bind to stage, the id
      *> lands in WS-RESULT. Requires WS-PREP-SQL and WS-RESULT only (no
      *> WS-BIND references at all, so every host qualifies).
       LAST-INSERT-ID.
           MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
           EXIT PARAGRAPH.

      *> Shared currency lookup (maint-04b): caller stages the ISO code in
      *> WS-BIND-1; the currency id lands in WS-RESULT. Same footprint as
      *> LOOKUP-USER-ROLE.
       LOOKUP-CURRENCY.
           MOVE "SELECT currency_id FROM currencies WHERE iso_code = ? LIMIT 1" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
           EXIT PARAGRAPH.

      *> Shared AUTHZ_DENIED audit insert (maint-04b): caller stages
      *> entity id, detail, actor email in WS-BIND-1..3; the row lands in
      *> audit_trail. Same footprint (WS-PREP-SQL, WS-BIND-1..5, WS-RESULT).
       RECORD-AUTHZ-DENIED.
           MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'USER', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
           EXIT PARAGRAPH.
