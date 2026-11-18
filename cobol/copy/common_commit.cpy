      *> Shared commit check (P0-02): drop-in replacement for a bare
      *> CALL "SQL_COMMIT". Checks the commit result and fails closed with
      *> ERROR|DB_ERROR. Requires WS-RESULT and LS-OUTPUT-BUFFER (both
      *> universal). GOBACKs on failure so the caller never moves a false
      *> SUCCESS. Hosts COPY this in PROCEDURE DIVISION.
       COMMIT-CHECKED.
           CALL "SQL_COMMIT" END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT NOT = "SUCCESS|COMMIT"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
               GOBACK
           END-IF.
           EXIT PARAGRAPH.
