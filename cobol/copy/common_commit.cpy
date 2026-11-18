      *> Shared commit check (P0-02): drop-in replacement for a bare
      *> CALL "SQL_COMMIT". Checks the commit result and fails closed with
      *> ERROR|DB_ERROR. Uses LS-OUTPUT-BUFFER for the commit handshake so
      *> the caller's WS-RESULT (e.g. OUTBOX_CLAIM's claimed rows) survives
      *> a successful COMMIT. Requires WS-RESULT and LS-OUTPUT-BUFFER (both
      *> universal). GOBACKs on failure so the caller never moves a false
      *> SUCCESS. Hosts COPY this in PROCEDURE DIVISION.
       COMMIT-CHECKED.
           CALL "SQL_COMMIT" END-CALL
           CALL "GET_RESULT" USING BY REFERENCE LS-OUTPUT-BUFFER END-CALL
           IF LS-OUTPUT-BUFFER NOT = "SUCCESS|COMMIT"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
               GOBACK
           END-IF
           MOVE SPACES TO LS-OUTPUT-BUFFER.
           EXIT PARAGRAPH.
