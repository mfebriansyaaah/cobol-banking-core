      *> Shared transaction finish (DRY-06C): byte-identical to the
      *> inline epilogues it replaces. The caller stages the success
      *> message in WS-SUCCESS-MSG (MOVE literal or STRING block), then
      *> PERFORMs TXN-FINISH (LS-OUTPUT-BUFFER reporters) or
      *> TXN-FINISH-RESULT (WS-RESULT reporters, e.g. loan_schedule whose
      *> epilogue moves WS-RESULT onward). No new shared working storage:
      *> WS-SUCCESS-MSG is declared by each host (a 01 here would not
      *> compile — this copybook is included in PROCEDURE DIVISION).
      *> Requires WS-SUCCESS-MSG, WS-RESULT, LS-OUTPUT-BUFFER, STEP-OK/
      *> STEP-FAIL and WS-STEP. Hosts COPY this in PROCEDURE DIVISION.
       TXN-FINISH.
           *> A commit failure is fail-closed: set DB_ERROR and return.
           *> Never move the staged success message after a failed COMMIT.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT NOT = "SUCCESS|COMMIT"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   MOVE "ERROR|DB_ERROR" TO WS-RESULT
                   GOBACK
               END-IF
               MOVE WS-SUCCESS-MSG TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       TXN-FINISH-RESULT.
           *> Same fail-closed rule for WS-RESULT reporters. Set both
           *> output shapes before GOBACK so no caller sees a stale success.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT NOT = "SUCCESS|COMMIT"
                   MOVE "ERROR|DB_ERROR" TO WS-RESULT
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   GOBACK
               END-IF
               MOVE WS-SUCCESS-MSG TO WS-RESULT
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO WS-RESULT
           END-IF.
           EXIT PARAGRAPH.
