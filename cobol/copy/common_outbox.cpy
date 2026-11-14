      *> Shared transactional outbox enqueue (DRY-03): byte-identical to
      *> the inline paragraphs it replaces in auth_core, auth_recovery_core
      *> and user_core. Requires WS-NOTIF-TO/PURPOSE/CODE/DETAIL/FAIL,
      *> WS-PREP-SQL, WS-BIND-1..5 and WS-RESULT. Hosts COPY this in
      *> PROCEDURE DIVISION.
        ENQUEUE-NOTIFICATION.
            *> Transactional outbox: the intent commits or rolls back with
            *> the business action that created it. Sets WS-NOTIF-FAIL on
            *> DB error; the caller maps it to its own failure output.
            MOVE 0 TO WS-NOTIF-FAIL
            MOVE "INSERT INTO notification_outbox (recipient, purpose, code, detail) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-NOTIF-TO TO WS-BIND-1
            MOVE WS-NOTIF-PURPOSE TO WS-BIND-2
            MOVE WS-NOTIF-CODE TO WS-BIND-3
            MOVE WS-NOTIF-DETAIL TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE 1 TO WS-NOTIF-FAIL
            END-IF.
            EXIT PARAGRAPH.

