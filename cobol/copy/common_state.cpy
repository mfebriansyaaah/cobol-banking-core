      *> Standard state-transition result check (arch9 WP-11).
      *> The caller stages a guarded status UPDATE (WHERE id = ? AND
      *> status = '<expected>') and PERFORMs SQL-EXEC-n, then PERFORMs
      *> STATE-EXPECT-ONE. Exactly one row must flip; AFFECTED_0 means the
      *> row is gone or already left the expected state (mapped to
      *> ERROR|INVALID_STATUS, never a silent success); any other error maps
      *> to ERROR|DB_ERROR. Requires WS-STATE-OK, WS-STATE-ERR, WS-RESULT;
      *> hosts declare WS-STATE-OK PIC 9 and WS-STATE-ERR PIC X(40).
      *> Hosts COPY this in PROCEDURE DIVISION.
       STATE-EXPECT-ONE.
           MOVE 1 TO WS-STATE-OK
           MOVE SPACES TO WS-STATE-ERR
           IF WS-RESULT = "SUCCESS|AFFECTED_1"
               EXIT PARAGRAPH
           END-IF
           MOVE 0 TO WS-STATE-OK
           IF WS-RESULT = "SUCCESS|AFFECTED_0"
               MOVE "ERROR|INVALID_STATUS" TO WS-STATE-ERR
           ELSE
               MOVE "ERROR|DB_ERROR" TO WS-STATE-ERR
           END-IF.
           EXIT PARAGRAPH.
