      *> Card authorize idempotency (arch9 WP-11): extracted verbatim from
      *> card_core.cob. Included by card_core (same compiled module), so the
      *> actions keep their single transaction, working storage, and audit
      *> helpers. Single-consumer copybook like deposit_lifecycle.cpy.
      *>
       CLAIM-AUTHORIZE-REQUEST.
           *> Client-supplied idempotency for authorize (P5) in AMOUNT
           *> mode: the legacy row stays the decision-maker while every
           *> transition is mirrored to idempotency_request. The adopted
           *> auth_ref is written by the action itself (WS-IDEM-LINKVAL is
           *> X(20), too short for a 64-char ref) and read back on DONE
           *> replays.
           PERFORM IDEM-RESET
           MOVE "CARD_AUTHORIZE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED(1:64) TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED(1:64) TO WS-IDEM-KEY
           *> Canonical 4dp form (Z-edit): the stored DECIMAL(18,4) reads
           *> back as "150.0000", so the replay compare must use the same
           *> shape ("150.00" would false-conflict). P2 is already validated
           *> numeric and positive above.
           MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT
           MOVE WS-NUM-AMOUNT TO WS-AMT-EDIT
           MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-IDEM-AMOUNT
           MOVE SPACES TO WS-IDEM-DETAILS
           MOVE "ERROR|AUTHORIZE_IN_PROGRESS" TO WS-IDEM-CODE
           PERFORM IDEM-CLAIM.
           EXIT PARAGRAPH.

       DELETE-AUTHORIZE-REQUEST.
           *> Drops our own PENDING request row on business refusal (status
           *> guard); DONE rows are never touched. The mirror row goes with it.
           PERFORM IDEM-RESET
           MOVE "CARD_AUTHORIZE" TO WS-IDEM-SCOPE
           MOVE WS-P1-TRIMMED(1:64) TO WS-IDEM-ENTITY-VAL
           MOVE WS-P5-TRIMMED(1:64) TO WS-IDEM-KEY
           PERFORM IDEM-DELETE.
           EXIT PARAGRAPH.

       REPLAY-AUTHORIZE-REQUEST.
           *> DONE replay: return the adopted auth_ref stored at completion
           *> time. Runs before the action transaction, read-only.
           *> Self-contained: re-establish the key (P1/P5 are always present).
            PERFORM IDEM-RESET
            MOVE "CARD_AUTHORIZE" TO WS-IDEM-SCOPE
            MOVE WS-P1-TRIMMED(1:64) TO WS-IDEM-ENTITY-VAL
            MOVE WS-P5-TRIMMED(1:64) TO WS-IDEM-KEY
            MOVE "SELECT CONCAT(auth_ref, '|', CAST(amount AS CHAR)) FROM card_authorize_request WHERE card_id = ? AND idempotency_key = ? AND status = 'DONE' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-1
            MOVE WS-IDEM-KEY TO WS-BIND-2
            PERFORM SQL-EXEC-2
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            ELSE
                UNSTRING WS-RESULT DELIMITED BY "|"
                    INTO WS-TMP-STR WS-TMP-AMT
                END-UNSTRING
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|CARD_AUTHORIZE|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-STR) DELIMITED BY SIZE "|" DELIMITED BY SIZE FUNCTION TRIM(WS-TMP-AMT) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER ON OVERFLOW CALL "SQL_ROLLBACK" END-CALL MOVE "ERROR|OUTPUT_TOO_LARGE" TO LS-OUTPUT-BUFFER GOBACK END-STRING
            END-IF
            EXIT PARAGRAPH.

       ADOPT-AUTHORIZE-REQUEST.
           *> Adopt the posted auth_ref into our PENDING request row, then
           *> complete (legacy DONE + mirror DONE). WS-TMP-STR carries the ref.
           *> Self-contained like the CAPTURE/REPAY/REVERSE complete sites:
           *> re-establish the idempotency context instead of inheriting it.
            PERFORM IDEM-RESET
            MOVE "CARD_AUTHORIZE" TO WS-IDEM-SCOPE
            MOVE WS-P1-TRIMMED(1:64) TO WS-IDEM-ENTITY-VAL
            MOVE WS-P5-TRIMMED(1:64) TO WS-IDEM-KEY
            MOVE FUNCTION NUMVAL(WS-P2-TRIMMED) TO WS-NUM-AMOUNT
            MOVE WS-NUM-AMOUNT TO WS-AMT-EDIT
            MOVE FUNCTION TRIM(WS-AMT-EDIT) TO WS-IDEM-AMOUNT
            MOVE SPACES TO WS-IDEM-DETAILS
            MOVE "UPDATE card_authorize_request SET auth_ref = ? WHERE card_id = ? AND idempotency_key = ? AND status = 'PENDING'" TO WS-PREP-SQL
            MOVE WS-TMP-STR TO WS-BIND-1
            MOVE WS-IDEM-ENTITY-VAL TO WS-BIND-2
            MOVE WS-IDEM-KEY TO WS-BIND-3
            PERFORM SQL-EXEC-3
            IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                PERFORM IDEM-COMPLETE
            END-IF.
            EXIT PARAGRAPH.
