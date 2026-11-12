        IDENTIFICATION DIVISION.
        PROGRAM-ID. wallet_dispute_core.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.

       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01  WS-EXIT-CODE            PIC 9(2) VALUE 0.
        01  WS-QUERY                PIC X(512) VALUE SPACES.
        01  WS-RESULT               PIC X(16384) VALUE SPACES.
        01  WS-PARAM1-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM2-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM3-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM4-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM5-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-PARAM6-TRIMMED       PIC X(100) VALUE SPACES.
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-P5-LEN               PIC 9(3) VALUE 1.
        01  WS-P6-LEN               PIC 9(3) VALUE 1.
        01  WS-I                   PIC 9(3).
        01  WS-J                    PIC 9(5) VALUE 0.
        01  WS-TRIM-IDX             PIC 9     VALUE 0.
        01  WS-TRIM-SRC             PIC X(100) VALUE SPACES.
        01  WS-TRIM-CNT             PIC 9(3)  VALUE 0.
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-AMT-DOTS            PIC 9(2) VALUE 0.
        01  WS-AMT-DIGITS          PIC 9(2) VALUE 0.
        01  WS-AMT-FRAC            PIC 9(2) VALUE 0.
        01  WS-AMT-SEEN-DOT        PIC X(1) VALUE "0".
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
        01  WS-DENIED-TARGET        PIC X(100) VALUE SPACES.
        01  WS-PERM-REQ             PIC X(30) VALUE SPACES.
        01  WS-PERM-ACTOR           PIC X(100) VALUE SPACES.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
        01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
        01  WS-BIND-1               PIC X(256) VALUE SPACES.
        01  WS-BIND-2               PIC X(256) VALUE SPACES.
        01  WS-BIND-3               PIC X(256) VALUE SPACES.
        01  WS-BIND-4               PIC X(256) VALUE SPACES.
        01  WS-BIND-5               PIC X(256) VALUE SPACES.
        01  WS-BIND-6               PIC X(256) VALUE SPACES.
        01  WS-BIND-7               PIC X(256) VALUE SPACES.
        01  F-QUOTE                 PIC X VALUE "'".
        01  F-DQUOTE                PIC X VALUE '"'.
        01  F-BSLASH                PIC X VALUE "\".
        01  F-SEMI                  PIC X VALUE ";".
        01  F-TICK                  PIC X VALUE "`".
        01  WS-TRANSFER-STATE      PIC X(5) VALUE 'OK  '.
            88  WS-TRANSFER-OK       VALUE 'OK'.
            88  WS-TRANSFER-FAIL-SENDER VALUE 'SNDR'.
            88  WS-TRANSFER-FAIL-TARGET VALUE 'TGRT'.
            88  WS-TRANSFER-FAIL-INSUF VALUE 'INSUF'.
            88  WS-TRANSFER-FAIL-IDEMP VALUE 'IDEM'.
            88  WS-TRANSFER-FAIL-CONFLICT VALUE 'CNFL'.
            88  WS-TRANSFER-FAIL-AMOUNT VALUE 'AMNT'.
            88  WS-TRANSFER-FAIL-CURR VALUE 'CURR'.
            88  WS-TRANSFER-FAIL-DB VALUE 'DBER'.
            88  WS-TRANSFER-FAIL-FROZEN VALUE 'FRZN'.
            88  WS-TRANSFER-FAIL-CLOSED VALUE 'CLSD'.
            88  WS-TRANSFER-FAIL-CURINACT VALUE 'CINA'.
            88  WS-TRANSFER-FAIL-LIMIT VALUE 'LIMT'.
            88  WS-TRANSFER-FAIL-DAILY VALUE 'DLIM'.
            88  WS-TRANSFER-FAIL-STALE VALUE 'STAL'.
        01  WS-BALANCE-NUM         PIC S9(16)V9999 COMP-3.
        01  WS-AMOUNT-NUM          PIC S9(16)V9999 COMP-3.
        01  WS-NOW                 PIC X(21) VALUE SPACES.
        01  WS-TXN-REF             PIC X(50) VALUE SPACES.
        01  WS-RAND                PIC X(7)  VALUE SPACES.
        01  WS-MAX-TXN-STR         PIC X(20) VALUE SPACES.
        01  WS-DAILY-LIMIT-STR     PIC X(20) VALUE SPACES.
        01  WS-PRIOR-TOTAL-STR     PIC X(30) VALUE SPACES.
        01  WS-MAX-TXN-NUM         PIC S9(16)V9999 COMP-3.
        01  WS-DAILY-LIMIT-NUM     PIC S9(16)V9999 COMP-3.
        01  WS-PRIOR-TOTAL-NUM     PIC S9(16)V9999 COMP-3.
        01  WS-PARSE-SRC           PIC X(100) VALUE SPACES.
        01  WS-PARSE-BUF           PIC X(100) VALUE SPACES.
        01  WS-PARSE-NUM           PIC S9(16)V9999 COMP-3.
        01  WS-CAP-SRC             PIC X(20) VALUE SPACES.
        01  WS-CAP-OK              PIC X(1) VALUE "Y".
        01  WS-CAP-LEN             PIC 9(3) VALUE 0.
        01  WS-PREC-NUM            PIC S9(4) VALUE 0.
        01  WS-JV-PREC             PIC X(2)  VALUE SPACES.
        01  WS-FEE-NUM             PIC S9(16)V9999 COMP-3.
        01  WS-FEE-STR             PIC X(30) VALUE SPACES.
        01  WS-FEE-EXACT           PIC X(1)  VALUE SPACES.
        01  WS-INCOME-ACC          PIC X(20) VALUE SPACES.
        01  WS-RUN-ID              PIC X(20) VALUE SPACES.
        01  WS-RUN-TRIGGER         PIC X(10) VALUE SPACES.
        01  WS-RUN-COUNT           PIC X(10) VALUE SPACES.
        01  WS-RLIMIT              PIC X(10) VALUE "50".
        01  WS-ROFFSET             PIC X(10) VALUE "0".
        01  WS-ST-ACC               PIC X(20) VALUE SPACES.
        01  WS-ST-PREC              PIC X(5)  VALUE SPACES.
        01  WS-ST-ISO               PIC X(10) VALUE SPACES.
        01  WS-ST-FROM              PIC X(10) VALUE SPACES.
        01  WS-ST-TO                PIC X(10) VALUE SPACES.
        01  WS-ST-QFROM             PIC X(10) VALUE SPACES.
        01  WS-ST-OPEN              PIC X(30) VALUE SPACES.
        01  WS-ST-CLOSE             PIC X(30) VALUE SPACES.
        01  WS-DATE-SRC             PIC X(10) VALUE SPACES.
        01  WS-DATE-BAD             PIC 9     VALUE 0.
        01  WS-DSP-CASE             PIC X(20) VALUE SPACES.
        01  WS-DSP-STATE            PIC X(14) VALUE SPACES.
        01  WS-DSP-OWNER            PIC X(100) VALUE SPACES.
        01  WS-DSP-DUE              PIC X(500) VALUE SPACES.
        01  WS-DSP-DUELEN           PIC 9(5)  VALUE 0.
        01  WS-RTOTAL              PIC X(20) VALUE SPACES.
        01  WS-RLEN                PIC 9(5)  VALUE 0.
        01  WS-HOLD-ID             PIC X(20) VALUE SPACES.
        01  WS-HOLD-FRAC           PIC 9(2) VALUE 0.
        01  WS-HOLD-AMOUNT-NUM     PIC S9(16)V9999 COMP-3.
        01  WS-HOLD-BAL-NUM        PIC S9(16)V9999 COMP-3.
        01  WS-HELD-NUM            PIC S9(16)V9999 COMP-3.
        01  WS-HELD-STR            PIC X(30) VALUE SPACES.
        01  WS-HOLD-ACC            PIC X(20) VALUE SPACES.
        01  WS-HOLD-DAYS           PIC X(20) VALUE SPACES.
        01  WS-REV-AMT             PIC X(30) VALUE SPACES.
        01  WS-REV-CAMT            PIC X(30) VALUE SPACES.
        01  WS-REV-FROM            PIC X(100) VALUE SPACES.
        01  WS-REV-CNT             PIC X(10) VALUE SPACES.
        01  WS-REV-MINFROM         PIC X(100) VALUE SPACES.
        01  WS-REV-AMT-NUM         PIC S9(16)V9999 COMP-3.
        01  WS-REV-CAMT-NUM        PIC S9(16)V9999 COMP-3.
        01  WS-REV-REASON          PIC X(100) VALUE SPACES.
        01  WS-REV-REFUND          PIC X(1)  VALUE "0".
        01  WS-REV-FEE-ACC         PIC X(20) VALUE SPACES.
        01  WS-REV-FEE-AMT         PIC X(30) VALUE SPACES.
        01  WS-REV-FEE-CUR         PIC X(20) VALUE SPACES.
        01  WS-REV-FEE-ISO         PIC X(3)  VALUE SPACES.
        01  WS-REV-FEE-PREC        PIC X(2)  VALUE SPACES.
        01  WS-REV-FEE-NUM         PIC S9(16)V9999 COMP-3.
        01  WS-REV-FX-ACC          PIC X(20) VALUE SPACES.
        01  WS-REV-FX-AMT          PIC X(30) VALUE SPACES.
        01  WS-REV-FX-DESC         PIC X(16) VALUE SPACES.
        01  WS-REV-FX-NUM          PIC S9(16)V9999 COMP-3.
        01  WS-SQL-PTR             PIC 9(5)  VALUE 0.
        01  WS-TX-FROM             PIC X(100) VALUE SPACES.
        01  WS-TX-TO               PIC X(100) VALUE SPACES.
        01  WS-TX-AMT              PIC X(30) VALUE SPACES.
        01  WS-TX-STATUS           PIC X(10) VALUE SPACES.
        01  WS-BUSY                PIC X(1) VALUE "0".
        01  WS-RET-STR             PIC X(20) VALUE SPACES.
        01  WS-DETAIL              PIC X(255) VALUE SPACES.
        01  WS-REVERSED            PIC X(1) VALUE "0".
        01  WS-REF                 PIC X(50) VALUE SPACES.
        01  WS-REFLEN              PIC 9(3) VALUE 1.
        01  WS-INTENT-FROM         PIC X(100) VALUE SPACES.
        01  WS-INTENT-TO           PIC X(100) VALUE SPACES.
        01  WS-INTENT-AMT          PIC X(30) VALUE SPACES.
        01  WS-INTENT-STATUS       PIC X(10) VALUE SPACES.
        01  WS-INTENT-AMOUNT-NUM   PIC S9(16)V9999 COMP-3.
        01  WS-SENDER-ACC          PIC X(20) VALUE SPACES.
        01  WS-SENDER-USER         PIC X(20) VALUE SPACES.
        01  WS-SENDER-BAL          PIC X(30) VALUE SPACES.
        01  WS-SENDER-CUR          PIC X(20) VALUE SPACES.
        01  WS-TARGET-ACC          PIC X(20) VALUE SPACES.
        01  WS-TARGET-CUR          PIC X(20) VALUE SPACES.
        01  WS-SENDER-STATUS       PIC X(10) VALUE SPACES.
        01  WS-SENDER-CURACTIVE    PIC X(1)  VALUE SPACES.
        01  WS-TARGET-STATUS       PIC X(10) VALUE SPACES.
        01  WS-TARGET-CURACTIVE    PIC X(1)  VALUE SPACES.
        01  WS-SENDER-PREC         PIC X(2)  VALUE SPACES.
        01  WS-SENDER-ISO          PIC X(3)  VALUE SPACES.
        01  WS-PAY-ACTION          PIC X(30) VALUE SPACES.
        01  WS-PAY-ACTOR           PIC X(100) VALUE SPACES.
        01  WS-PAY-OUT             PIC X(16384) VALUE SPACES.
        01  WS-TARGET-PREC         PIC X(2)  VALUE SPACES.
        01  WS-RATE-STR            PIC X(40) VALUE SPACES.
        01  WS-RATE-UPDATED        PIC X(30) VALUE SPACES.
        01  WS-RATE-AGE-STR        PIC X(20) VALUE SPACES.
        01  WS-RATE-CUTOFF         PIC X(30) VALUE SPACES.
        01  WS-FX-CRED             PIC X(30) VALUE SPACES.
        01  WS-FX-RES              PIC X(30) VALUE SPACES.
        01  WS-FX-ABS              PIC X(30) VALUE SPACES.
        01  WS-FX-ACC              PIC X(20) VALUE SPACES.
        01  WS-FX-ISO              PIC X(3)  VALUE SPACES.
        01  WS-FX-HAS              PIC X(1)  VALUE "0".

        LINKAGE SECTION.
       01  LS-CMD-ACTION          PIC X(30).
       01  LS-PARAM1              PIC X(100).
       01  LS-PARAM2              PIC X(100).
       01  LS-PARAM3              PIC X(100).
       01  LS-PARAM4              PIC X(100).
       01  LS-PARAM5              PIC X(100).
       01  LS-PARAM6              PIC X(100).
       01  LS-OUTPUT-BUFFER      PIC X(16384).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.
        
        COPY "common_sql.cpy".

        MAIN-LOGIC.
            *> Initialize critical WORKING-STORAGE (for --serve mode):
            MOVE "OK  " TO WS-TRANSFER-STATE
            SET WS-TRANSFER-OK TO TRUE
            MOVE "Y" TO WS-CAP-OK
            MOVE "0" TO WS-BUSY
            MOVE 0 TO WS-PREC-NUM
            MOVE 0 TO WS-ALLOWED
            MOVE "1" TO WS-STEP
            SET STEP-OK TO TRUE
            MOVE "0" TO WS-FX-HAS
            MOVE 0 TO WS-BAD
            MOVE 0 TO WS-P1-LEN
            MOVE 0 TO WS-P2-LEN
            MOVE 0 TO WS-P3-LEN
            MOVE 0 TO WS-P4-LEN
            MOVE 0 TO WS-P5-LEN
            MOVE 0 TO WS-P6-LEN
            MOVE 0 TO WS-CAP-LEN
            MOVE 0 TO WS-AMT-DOTS
            MOVE 0 TO WS-AMT-DIGITS
            MOVE 0 TO WS-AMT-FRAC
            MOVE "0" TO WS-AMT-SEEN-DOT
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            PERFORM TRIM-ALL
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:12) = "OPEN_DISPUTE"
                    PERFORM OPEN-DISPUTE-LOGIC
                WHEN LS-CMD-ACTION(1:16) = "ADD_DISPUTE_NOTE"
                    PERFORM ADD-DISPUTE-NOTE-LOGIC
                WHEN LS-CMD-ACTION(1:11) = "ACK_DISPUTE"
                    PERFORM ACK-DISPUTE-LOGIC
                WHEN LS-CMD-ACTION(1:15) = "RESOLVE_DISPUTE"
                    PERFORM RESOLVE-DISPUTE-LOGIC
                WHEN LS-CMD-ACTION(1:14) = "REJECT_DISPUTE"
                    PERFORM REJECT-DISPUTE-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "LIST_DISPUTES"
                    PERFORM LIST-DISPUTES-LOGIC
                WHEN LS-CMD-ACTION(1:11) = "GET_DISPUTE"
                    PERFORM GET-DISPUTE-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        VALIDATE-ALL.
            *> No SQL metacharacters may reach a query string.
            MOVE 0 TO WS-BAD
            MOVE LS-PARAM1 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM2 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM3 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM4 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM5 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            IF WS-BAD > 0
                EXIT PARAGRAPH
            END-IF.
            MOVE LS-PARAM6 TO WS-CHECK
            PERFORM VALIDATE-INPUT.
            EXIT PARAGRAPH.

        VALIDATE-INPUT.
            INSPECT WS-CHECK TALLYING WS-BAD
                FOR ALL F-QUOTE
                WS-BAD FOR ALL F-DQUOTE
                WS-BAD FOR ALL F-BSLASH
                WS-BAD FOR ALL F-SEMI
                WS-BAD FOR ALL F-TICK.
            EXIT PARAGRAPH.

        TRIM-ALL.
            PERFORM TRIM-ONE VARYING WS-TRIM-IDX FROM 1 BY 1
                    UNTIL WS-TRIM-IDX > 6.

        TRIM-ONE.
            EVALUATE WS-TRIM-IDX
                WHEN 1 MOVE LS-PARAM1 TO WS-TRIM-SRC
                WHEN 2 MOVE LS-PARAM2 TO WS-TRIM-SRC
                WHEN 3 MOVE LS-PARAM3 TO WS-TRIM-SRC
                WHEN 4 MOVE LS-PARAM4 TO WS-TRIM-SRC
                WHEN 5 MOVE LS-PARAM5 TO WS-TRIM-SRC
                WHEN 6 MOVE LS-PARAM6 TO WS-TRIM-SRC
            END-EVALUATE
            MOVE 0 TO WS-TRIM-CNT
            PERFORM VARYING WS-I FROM 100 BY -1
                    UNTIL WS-I < 1 OR WS-TRIM-CNT > 0
                IF WS-TRIM-SRC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-TRIM-CNT
                END-IF
            END-PERFORM
            EVALUATE WS-TRIM-IDX
                WHEN 1 MOVE WS-TRIM-SRC TO WS-PARAM1-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P1-LEN
                WHEN 2 MOVE WS-TRIM-SRC TO WS-PARAM2-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P2-LEN
                WHEN 3 MOVE WS-TRIM-SRC TO WS-PARAM3-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P3-LEN
                WHEN 4 MOVE WS-TRIM-SRC TO WS-PARAM4-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P4-LEN
                WHEN 5 MOVE WS-TRIM-SRC TO WS-PARAM5-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P5-LEN
                WHEN 6 MOVE WS-TRIM-SRC TO WS-PARAM6-TRIMMED
                       MOVE WS-TRIM-CNT TO WS-P6-LEN
            END-EVALUATE.

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
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'USER', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
            EXIT PARAGRAPH.

        CHECK-ST-DATE.
            *> WS-DATE-SRC holds "" or YYYY-MM-DD; sets WS-DATE-BAD = 1
            *> when the shape is wrong (the gateway also enforces DATE).
            MOVE 0 TO WS-DATE-BAD
            IF WS-DATE-SRC = SPACES
                EXIT PARAGRAPH
            END-IF.
            IF WS-DATE-SRC(5:1) NOT = "-" OR WS-DATE-SRC(8:1) NOT = "-"
                MOVE 1 TO WS-DATE-BAD
                EXIT PARAGRAPH
            END-IF.
            PERFORM VARYING WS-J FROM 1 BY 1 UNTIL WS-J > 10
                IF WS-J NOT = 5 AND WS-J NOT = 8
                    IF WS-DATE-SRC(WS-J:1) < "0" OR WS-DATE-SRC(WS-J:1) > "9"
                        MOVE 1 TO WS-DATE-BAD
                    END-IF
                END-IF
            END-PERFORM.
            EXIT PARAGRAPH.

        OPEN-DISPUTE-LOGIC.
            *> p1 = owner email, p2 = actor (must be the owner: a case is
            *> opened by the customer it belongs to), p3 = subject,
            *> p4 = detail, p5 = txn_ref (optional; must be the owner's
            *> own transaction when given).
            IF WS-PARAM1-TRIMMED NOT = WS-PARAM2-TRIMMED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-LEN = 0 OR WS-P4-LEN = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT 1 FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P5-LEN > 0
                MOVE "SELECT 1 FROM pending_transactions WHERE txn_ref = ? AND (from_email = ? OR to_email = ?) LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM5-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT = "ERROR|NO_DATA"
                    MOVE "SELECT 1 FROM ledger l JOIN accounts a ON a.account_id = l.account_id JOIN users u ON u.id = a.user_id WHERE l.txn_ref = ? AND u.email = ? LIMIT 1" TO WS-PREP-SQL
                    MOVE WS-PARAM5-TRIMMED TO WS-BIND-1
                    MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                    IF WS-RESULT = "ERROR|NO_DATA"
                        MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                        EXIT PARAGRAPH
                    END-IF
                    IF WS-RESULT(1:5) = "ERROR"
                        MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                        EXIT PARAGRAPH
                    END-IF
                ELSE
                    IF WS-RESULT(1:5) = "ERROR"
                        MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                        EXIT PARAGRAPH
                    END-IF
                END-IF
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO dispute_cases (user_id, txn_ref, subject, detail) SELECT id, ?, ?, ? FROM users WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM5-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM4-TRIMMED TO WS-BIND-3
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                MOVE WS-RESULT(1:20) TO WS-DSP-CASE
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT u.id, a.id, 'DISPUTE_OPENED', 'DISPUTE', ?, 'SUCCESS' FROM users u, users a WHERE u.email = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-DSP-CASE TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|DISPUTE_OPENED|" DELIMITED BY SIZE
                       WS-DSP-CASE DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        LOAD-DISPUTE-CASE.
            *> Loads WS-DSP-OWNER (owner email) and WS-DSP-STATE for the case
            *> named by p1. Emits UNKNOWN_TRANSACTION / INVALID_INPUT / DB_ERROR.
            MOVE WS-PARAM1-TRIMMED(1:20) TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT u.email, d.state FROM dispute_cases d JOIN users u ON u.id = d.user_id WHERE d.case_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-DSP-OWNER WS-DSP-STATE
            END-UNSTRING
            EXIT PARAGRAPH.

        CHECK-DISPUTE-VISIBILITY.
            *> WS-DSP-OWNER / WS-DSP-STATE are loaded. The actor (p2) may
            *> proceed when they own the case or are a SUPER_ADMIN.
            IF WS-PARAM2-TRIMMED = WS-DSP-OWNER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            EXIT PARAGRAPH.

        ADD-DISPUTE-NOTE-LOGIC.
            *> p1 = case_id, p2 = actor (owner or SUPER_ADMIN), p3 = note.
            *> Notes append to the immutable case history; terminal cases
            *> refuse new notes.
            IF WS-P3-LEN = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-DISPUTE-CASE
            IF LS-OUTPUT-BUFFER(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF.
            PERFORM CHECK-DISPUTE-VISIBILITY
            IF LS-OUTPUT-BUFFER(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF.
            IF WS-DSP-STATE NOT = "OPEN" AND WS-DSP-STATE NOT = "ACKNOWLEDGED"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO dispute_messages (case_id, author_id, body) VALUES (?, (SELECT id FROM users WHERE email = ?), ?)" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE "SUCCESS|DISPUTE_NOTED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        ACK-DISPUTE-LOGIC.
            *> p1 = case_id, p2 = actor (SUPER_ADMIN), p3 = due date
            *> (optional). Claims ownership: only OPEN cases can be
            *> acknowledged, and the acking admin becomes the assignee.
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM3-TRIMMED(1:10) TO WS-DATE-SRC
            PERFORM CHECK-ST-DATE
            IF WS-DATE-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-DISPUTE-CASE
            IF LS-OUTPUT-BUFFER(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF.
            IF WS-DSP-STATE NOT = "OPEN"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE dispute_cases SET state = 'ACKNOWLEDGED', assigned_to = (SELECT id FROM users WHERE email = ?), due_date = NULLIF(?, ''), decided_at = NULL WHERE case_id = ? AND state = 'OPEN'" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT d.user_id, a.id, 'DISPUTE_ACK', 'DISPUTE', ?, 'SUCCESS' FROM dispute_cases d, users a WHERE d.case_id = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|DISPUTE_ACKNOWLEDGED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-RESULT = "SUCCESS|AFFECTED_0"
                    MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        RESOLVE-DISPUTE-LOGIC.
            *> p1 = case_id, p2 = actor (SUPER_ADMIN), p3 = resolution.
            *> Only an acknowledged case can be resolved.
            IF WS-P3-LEN = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-DISPUTE-CASE
            IF LS-OUTPUT-BUFFER(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF.
            IF WS-DSP-STATE NOT = "ACKNOWLEDGED"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE dispute_cases SET state = 'RESOLVED', resolution = ?, decided_at = NOW() WHERE case_id = ? AND state = 'ACKNOWLEDGED'" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT d.user_id, a.id, 'DISPUTE_RESOLVED', 'DISPUTE', ?, 'SUCCESS' FROM dispute_cases d, users a WHERE d.case_id = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|DISPUTE_RESOLVED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-RESULT = "SUCCESS|AFFECTED_0"
                    MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        REJECT-DISPUTE-LOGIC.
            *> p1 = case_id, p2 = actor (SUPER_ADMIN), p3 = reason. An
            *> OPEN or ACKNOWLEDGED case can be refused with a reason.
            IF WS-P3-LEN = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM LOAD-DISPUTE-CASE
            IF LS-OUTPUT-BUFFER(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF.
            IF WS-DSP-STATE NOT = "OPEN" AND WS-DSP-STATE NOT = "ACKNOWLEDGED"
                MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE dispute_cases SET state = 'REJECTED', resolution = ?, decided_at = NOW() WHERE case_id = ? AND state IN ('OPEN', 'ACKNOWLEDGED')" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT d.user_id, a.id, 'DISPUTE_REJECTED', 'DISPUTE', ?, 'SUCCESS' FROM dispute_cases d, users a WHERE d.case_id = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|DISPUTE_REJECTED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-RESULT = "SUCCESS|AFFECTED_0"
                    MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        LIST-DISPUTES-LOGIC.
            *> p1 = actor, p2 = email filter (admin only; anyone else is
            *> pinned to their own cases), p3 = status filter, p4 = limit,
            *> p5 = offset. Read-only queue with an overdue flag computed
            *> from the admin-set due date (no automatic escalation).
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            MOVE WS-RESULT(1:14) TO WS-DSP-STATE
            IF WS-DSP-STATE NOT = "SUPER_ADMIN"
                MOVE WS-PARAM1-TRIMMED TO WS-PARAM2-TRIMMED
                MOVE WS-P1-LEN TO WS-P2-LEN
            END-IF.
            IF WS-PARAM3-TRIMMED NOT = SPACES AND WS-PARAM3-TRIMMED NOT = "OPEN" AND WS-PARAM3-TRIMMED NOT = "ACKNOWLEDGED" AND WS-PARAM3-TRIMMED NOT = "RESOLVED" AND WS-PARAM3-TRIMMED NOT = "REJECTED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "50" TO WS-RLIMIT
            MOVE "0" TO WS-ROFFSET
            IF WS-P4-LEN > 0
                MOVE WS-PARAM4-TRIMMED(1:10) TO WS-RLIMIT
            END-IF.
            IF WS-P5-LEN > 0
                MOVE WS-PARAM5-TRIMMED(1:10) TO WS-ROFFSET
            END-IF.
            MOVE WS-RLIMIT TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-ROFFSET TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM dispute_cases d JOIN users u ON u.id = d.user_id WHERE u.email = COALESCE(NULLIF(?, ''), u.email) AND d.state = COALESCE(NULLIF(?, ''), d.state)" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-RTOTAL
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CONCAT(d.case_id, ':', u.email, ':', d.subject, ':', d.state, ':', " DELIMITED BY SIZE
                   "COALESCE(d.due_date, ''), ':', CASE WHEN d.due_date IS NOT NULL AND " DELIMITED BY SIZE
                   "d.due_date < CURDATE() AND d.state IN ('OPEN', 'ACKNOWLEDGED') THEN '1' " DELIMITED BY SIZE
                   "ELSE '0' END, ':', DATE(d.created_at)) FROM dispute_cases d JOIN users u " DELIMITED BY SIZE
                   "ON u.id = d.user_id WHERE u.email = COALESCE(NULLIF(?, ''), u.email) AND " DELIMITED BY SIZE
                   "d.state = COALESCE(NULLIF(?, ''), d.state) ORDER BY d.case_id DESC " DELIMITED BY SIZE
                   "LIMIT ? OFFSET ?" DELIMITED BY SIZE
               INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-RLIMIT TO WS-BIND-3
            MOVE WS-ROFFSET TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                IF WS-RESULT NOT = "ERROR|NO_DATA"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|DISPUTES|" DELIMITED BY SIZE
                       WS-RTOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RUN-RESULT-LEN
                STRING "SUCCESS|DISPUTES|" DELIMITED BY SIZE
                       WS-RTOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        GET-DISPUTE-LOGIC.
            *> p1 = case_id, p2 = actor (owner or SUPER_ADMIN). Returns the
            *> case plus its append-only message history, oldest first.
            PERFORM LOAD-DISPUTE-CASE
            IF LS-OUTPUT-BUFFER(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF.
            PERFORM CHECK-DISPUTE-VISIBILITY
            IF LS-OUTPUT-BUFFER(1:5) = "ERROR"
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(d.case_id, ':', u.email, ':', COALESCE(d.txn_ref, ''), ':', d.subject, ':', d.detail, ':', d.state, ':', COALESCE((SELECT email FROM users WHERE id = d.assigned_to), ''), ':', COALESCE(d.due_date, ''), ':', CASE WHEN d.due_date IS NOT NULL AND d.due_date < CURDATE() AND d.state IN ('OPEN', 'ACKNOWLEDGED') THEN '1' ELSE '0' END, ':', DATE(d.created_at), ':', COALESCE(d.resolution, '')) FROM dispute_cases d JOIN users u ON u.id = d.user_id WHERE d.case_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RUN-RESULT-LEN
            MOVE WS-RESULT(1:WS-RLEN) TO WS-DSP-DUE
            MOVE WS-RLEN TO WS-DSP-DUELEN
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM dispute_messages WHERE case_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-RTOTAL
            MOVE "SELECT CONCAT(m.msg_id, ':', COALESCE((SELECT email FROM users WHERE id = m.author_id), ''), ':', m.body, ':', DATE(m.created_at)) FROM dispute_messages m WHERE m.case_id = ? ORDER BY m.msg_id LIMIT 100" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                IF WS-RESULT NOT = "ERROR|NO_DATA"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|DISPUTE|" DELIMITED BY SIZE
                       WS-DSP-DUE(1:WS-DSP-DUELEN) DELIMITED BY SIZE "|" DELIMITED BY SIZE
                       WS-RTOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RUN-RESULT-LEN
                STRING "SUCCESS|DISPUTE|" DELIMITED BY SIZE
                       WS-DSP-DUE(1:WS-DSP-DUELEN) DELIMITED BY SIZE "|" DELIMITED BY SIZE
                       WS-RTOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        CHECK-CAP-DIGITS.
            *> Caps are whole major units, digits only: env_or_raw keeps the raw
            *> text so a dotted or malformed setting fails closed below
            *> instead of silently becoming a different number.
            MOVE "Y" TO WS-CAP-OK
            MOVE 0 TO WS-CAP-LEN
            PERFORM VARYING WS-I FROM 20 BY -1 UNTIL WS-I < 1 OR WS-CAP-LEN > 0
                IF WS-CAP-SRC(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-CAP-LEN
                END-IF
            END-PERFORM.
            IF WS-CAP-LEN = 0
                MOVE "N" TO WS-CAP-OK
            END-IF.
            IF WS-CAP-LEN > 0
                PERFORM CHECK-CAP-CHARS
            END-IF.
            EXIT PARAGRAPH.

        CHECK-CAP-CHARS.
            *> Character scan kept in its own paragraph so the loop above
            *> stays a single sentence per the inline-scope rule.
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-CAP-LEN
                IF WS-CAP-SRC(WS-I:1) < "0" OR WS-CAP-SRC(WS-I:1) > "9"
                    MOVE "N" TO WS-CAP-OK
                END-IF
            END-PERFORM.
            EXIT PARAGRAPH.

        TRIM-RUN-RESULT-LEN.
            *> Compute WS-RLEN = length of WS-RESULT without trailing spaces.
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-J FROM 16383 BY -1 UNTIL WS-J < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-J:1) NOT = SPACE
                    MOVE WS-J TO WS-RLEN
                END-IF
            END-PERFORM
            IF WS-RLEN = 0
                MOVE 1 TO WS-RLEN
            END-IF.
            EXIT PARAGRAPH.
