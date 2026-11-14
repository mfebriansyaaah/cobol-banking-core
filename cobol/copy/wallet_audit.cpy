      *> Shared wallet authorization-denied audit (DRY-02): byte-identical
      *> to the inline paragraphs it replaces in the six wallet modules.
      *> Requires WS-PREP-SQL, WS-BIND-1..5, WS-RESULT, LS-CMD-ACTION,
      *> WS-DENIED-ACTOR, WS-DENIED-TARGET, and common_sql.cpy
      *> (RECORD-AUTHZ-DENIED). Hosts COPY this in PROCEDURE DIVISION.
        AUDIT-DENIED.
            *> Records a refused authorization attempt reliably, even for unknown actors.
            *> Uses audit_authz_denied (no FK to users) for guaranteed logging,
            *> plus audit_trail (existing) for compatibility if the actor exists.
            *> K13 fix: audit denied best-effort → reliable.
            MOVE "INSERT INTO audit_authz_denied (action, actor_email, target_email, target_entity_type, target_entity_id, detail, source) VALUES (?, ?, ?, 'USER', ?, ?, 'WALLET')" TO WS-PREP-SQL
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-ACTOR TO WS-BIND-2
            MOVE WS-DENIED-TARGET TO WS-BIND-3
            MOVE WS-DENIED-TARGET TO WS-BIND-4
            MOVE LS-CMD-ACTION TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            *> Compatibility: also log to existing audit_trail if actor exists (best effort):
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            PERFORM RECORD-AUTHZ-DENIED
            EXIT PARAGRAPH.
