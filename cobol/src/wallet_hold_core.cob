        IDENTIFICATION DIVISION.
        PROGRAM-ID. wallet_hold_core.

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
                WHEN LS-CMD-ACTION(1:10) = "PLACE_HOLD"
                    PERFORM PLACE-HOLD-LOGIC
                WHEN LS-CMD-ACTION(1:12) = "RELEASE_HOLD"
                    PERFORM RELEASE-HOLD-LOGIC
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

        PLACE-HOLD-LOGIC.
            *> p1 = owner email, p2 = amount, p3 = actor (SUPER_ADMIN),
            *> p4 = expiry in days (empty/0 = none), p5 = currency pin
            *> (required when the owner holds several accounts), p6 = reason.
            *> Locks part of an account's balance: PLACED holds reduce the
            *> spendable balance until released or expired.
            SET WS-TRANSFER-OK TO TRUE.
            IF WS-TRANSFER-OK
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
                PERFORM LOOKUP-USER-ROLE
            END-IF.
            IF WS-TRANSFER-OK AND WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM3-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-OK
                PERFORM VALIDATE-HOLD-AMOUNT
            END-IF.
            IF WS-TRANSFER-FAIL-AMOUNT
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-OK
                PERFORM RESOLVE-HOLD-ACCOUNT
            END-IF.
            IF WS-TRANSFER-FAIL-SENDER
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-FAIL-CONFLICT
                MOVE "ERROR|AMBIGUOUS_ACCOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-FAIL-CLOSED
                MOVE "ERROR|ACCOUNT_CLOSED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-FAIL-CURINACT
                MOVE "ERROR|CURRENCY_INACTIVE" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-FAIL-AMOUNT
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-OK
                PERFORM VALIDATE-HOLD-DAYS
            END-IF.
            IF WS-TRANSFER-FAIL-AMOUNT
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-OK
                PERFORM INSERT-HOLD-ROW
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-FAIL-INSUF
                MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-OK
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|HOLD_PLACED|" WS-HOLD-ID DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        RELEASE-HOLD-LOGIC.
            *> p1 = hold_id, p2 = actor (SUPER_ADMIN). Releases a PLACED hold;
            *> anything else is reported as unknown.
            SET WS-TRANSFER-OK TO TRUE.
            IF WS-TRANSFER-OK
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                PERFORM LOOKUP-USER-ROLE
            END-IF.
            IF WS-TRANSFER-OK AND WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-OK
                MOVE WS-PARAM1-TRIMMED(1:20) TO WS-CAP-SRC
                PERFORM CHECK-CAP-DIGITS
            END-IF.
            IF WS-TRANSFER-OK AND WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-OK
                PERFORM APPLY-HOLD-RELEASE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-FAIL-CONFLICT
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-OK
                MOVE "SUCCESS|HOLD_RELEASED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-HOLD-AMOUNT.
            *> Amount syntax for holds (p2): plain positive decimal; the
            *> fraction count is checked against the account precision later.
            MOVE 0 TO WS-HOLD-FRAC
            MOVE 0 TO WS-AMT-DOTS
            MOVE 0 TO WS-AMT-DIGITS
            MOVE "0" TO WS-AMT-SEEN-DOT
            IF WS-P2-LEN < 1
                SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-AMOUNT
                EXIT PARAGRAPH
            END-IF.
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-P2-LEN
                IF WS-PARAM2-TRIMMED(WS-I:1) = "."
                    ADD 1 TO WS-AMT-DOTS END-ADD
                    MOVE "1" TO WS-AMT-SEEN-DOT
                ELSE
                    IF WS-PARAM2-TRIMMED(WS-I:1) >= "0"
                       AND WS-PARAM2-TRIMMED(WS-I:1) <= "9"
                        ADD 1 TO WS-AMT-DIGITS END-ADD
                        IF WS-AMT-SEEN-DOT = "1"
                            ADD 1 TO WS-HOLD-FRAC END-ADD
                        END-IF
                    ELSE
                        SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                    END-IF
                END-IF
            END-PERFORM.
            IF WS-AMT-DOTS > 1 OR WS-HOLD-FRAC > 4 OR WS-AMT-DIGITS < 1
                SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
            END-IF.
            IF WS-AMT-DIGITS > 18
                SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-AMOUNT
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM2-TRIMMED TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-HOLD-AMOUNT-NUM
            IF WS-HOLD-AMOUNT-NUM <= 0
                SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        RESOLVE-HOLD-ACCOUNT.
            *> Find the owner's account (pinned by p5 when several exist) and
            *> check the amount fits its precision.
            IF WS-P5-LEN > 0
                MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.user_id AS CHAR), CAST(a.currency_id AS CHAR), a.status, CAST(c.is_active AS CHAR), CAST(c.prec_val AS CHAR), c.iso_code FROM accounts a JOIN users u ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ? AND c.iso_code = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM5-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            ELSE
                MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            END-IF.
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                SET WS-TRANSFER-FAIL-SENDER TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-SENDER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P5-LEN = 0 AND WS-RESULT = "0"
                SET WS-TRANSFER-FAIL-SENDER TO TRUE
            END-IF.
            IF WS-P5-LEN = 0 AND WS-RESULT NOT = "0" AND WS-RESULT NOT = "1"
                SET WS-TRANSFER-FAIL-CONFLICT TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-CONFLICT
                EXIT PARAGRAPH
            END-IF.
            IF WS-P5-LEN = 0
                MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.user_id AS CHAR), CAST(a.currency_id AS CHAR), a.status, CAST(c.is_active AS CHAR), CAST(c.prec_val AS CHAR), c.iso_code FROM accounts a JOIN users u ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT = "ERROR|NO_DATA"
                    SET WS-TRANSFER-FAIL-SENDER TO TRUE
                END-IF
            END-IF.
            IF WS-TRANSFER-FAIL-SENDER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-HOLD-ACC WS-SENDER-USER WS-SENDER-CUR
                     WS-SENDER-STATUS WS-SENDER-CURACTIVE WS-SENDER-PREC
                     WS-SENDER-ISO
            END-UNSTRING
            IF WS-SENDER-STATUS = "FROZEN"
                SET WS-TRANSFER-FAIL-FROZEN TO TRUE
            END-IF.
            IF WS-SENDER-STATUS = "CLOSED"
                SET WS-TRANSFER-FAIL-CLOSED TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-CLOSED
                EXIT PARAGRAPH
            END-IF.
            IF WS-SENDER-CURACTIVE NOT = "1"
                SET WS-TRANSFER-FAIL-CURINACT TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-CURINACT
                EXIT PARAGRAPH
            END-IF.
            COMPUTE WS-PREC-NUM = FUNCTION NUMVAL(WS-SENDER-PREC) END-COMPUTE
            IF WS-PREC-NUM < 0 OR WS-PREC-NUM > 4
                SET WS-TRANSFER-FAIL-CURINACT TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-CURINACT
                EXIT PARAGRAPH
            END-IF.
            IF WS-HOLD-FRAC > WS-PREC-NUM
                SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-HOLD-DAYS.
            *> Expiry in whole days; empty means no expiry. Anything else is
            *> an invalid parameter, not a silent default.
            MOVE SPACES TO WS-HOLD-DAYS
            IF WS-P4-LEN = 0
                MOVE "0" TO WS-HOLD-DAYS
            END-IF.
            IF WS-P4-LEN > 0
                MOVE WS-PARAM4-TRIMMED(1:20) TO WS-CAP-SRC
                PERFORM CHECK-CAP-DIGITS
                IF WS-CAP-OK = "Y"
                    MOVE WS-PARAM4-TRIMMED(1:20) TO WS-HOLD-DAYS
                ELSE
                    SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                END-IF
            END-IF.
            IF WS-TRANSFER-FAIL-AMOUNT
                EXIT PARAGRAPH
            END-IF.
            IF WS-P6-LEN > 0
                PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-P6-LEN
                    EVALUATE TRUE
                        WHEN WS-PARAM6-TRIMMED(WS-I:1) >= "a" AND WS-PARAM6-TRIMMED(WS-I:1) <= "z"
                            CONTINUE
                        WHEN WS-PARAM6-TRIMMED(WS-I:1) >= "A" AND WS-PARAM6-TRIMMED(WS-I:1) <= "Z"
                            CONTINUE
                        WHEN WS-PARAM6-TRIMMED(WS-I:1) >= "0" AND WS-PARAM6-TRIMMED(WS-I:1) <= "9"
                            CONTINUE
                        WHEN WS-PARAM6-TRIMMED(WS-I:1) = " " OR WS-PARAM6-TRIMMED(WS-I:1) = "-" OR WS-PARAM6-TRIMMED(WS-I:1) = "_" OR WS-PARAM6-TRIMMED(WS-I:1) = "."
                            CONTINUE
                        WHEN OTHER
                            SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                    END-EVALUATE
                END-PERFORM
            END-IF.
            EXIT PARAGRAPH.

        INSERT-HOLD-ROW.
            *> Lock the account, re-check under lock, insert the hold, audit.
            CALL "SQL_BEGIN" END-CALL
            MOVE "SELECT account_id FROM accounts WHERE account_id = ? FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-HOLD-ACC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                CALL "SQL_ROLLBACK" END-CALL
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(balance, '|', COALESCE((SELECT SUM(amount) FROM account_holds WHERE account_id = a.account_id AND state = 'PLACED' AND (expires_at IS NULL OR expires_at > NOW())),0)) FROM accounts a WHERE a.account_id = ?" TO WS-PREP-SQL
            MOVE WS-HOLD-ACC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-SENDER-BAL WS-HELD-STR
            END-UNSTRING
            MOVE WS-SENDER-BAL TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-HOLD-BAL-NUM
            MOVE WS-HELD-STR TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-HELD-NUM
            IF WS-HELD-NUM + WS-HOLD-AMOUNT-NUM > WS-HOLD-BAL-NUM
                CALL "SQL_ROLLBACK" END-CALL
                SET WS-TRANSFER-FAIL-INSUF TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-INSUF
                EXIT PARAGRAPH
            END-IF.
            IF WS-HOLD-DAYS = "0"
                MOVE "INSERT INTO account_holds (account_id, amount, state, reason, actor_email, expires_at) VALUES (?, ?, 'PLACED', ?, ?, NULL)" TO WS-PREP-SQL
            ELSE
                MOVE "INSERT INTO account_holds (account_id, amount, state, reason, actor_email, expires_at) VALUES (?, ?, 'PLACED', ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))" TO WS-PREP-SQL
            END-IF.
            MOVE WS-HOLD-ACC TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            PERFORM FILL-HOLD-REMAINING-BINDS
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                CALL "SQL_ROLLBACK" END-CALL
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-HOLD-ID
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT u.id, a.id, 'PLACE_HOLD', 'ACCOUNT', ?, ?, 'SUCCESS' FROM users u, users a WHERE u.email = ? AND a.email = ?" TO WS-PREP-SQL
            MOVE WS-HOLD-ACC TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                CALL "SQL_ROLLBACK" END-CALL
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "SUCCESS|COMMIT"
                SET WS-TRANSFER-FAIL-DB TO TRUE
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        FILL-HOLD-REMAINING-BINDS.
            *> Reason (p6) is optional free text from a safe alphabet; the
            *> bind count differs with the expiry variant.
            IF WS-P6-LEN = 0
                MOVE SPACES TO WS-BIND-3
            ELSE
                MOVE WS-PARAM6-TRIMMED(1:WS-P6-LEN) TO WS-BIND-3
            END-IF
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-4
            IF WS-HOLD-DAYS NOT = "0"
                MOVE WS-HOLD-DAYS TO WS-BIND-5
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            ELSE
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            END-IF.
            EXIT PARAGRAPH.

        APPLY-HOLD-RELEASE.
            *> Lock the hold row; only a PLACED hold can be released.
            CALL "SQL_BEGIN" END-CALL
            MOVE "SELECT hold_id FROM account_holds WHERE hold_id = ? FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                CALL "SQL_ROLLBACK" END-CALL
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT state FROM account_holds WHERE hold_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "PLACED"
                CALL "SQL_ROLLBACK" END-CALL
                SET WS-TRANSFER-FAIL-CONFLICT TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-CONFLICT
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE account_holds SET state = 'RELEASED' WHERE hold_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                CALL "SQL_ROLLBACK" END-CALL
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT u.id, a.id, 'RELEASE_HOLD', 'ACCOUNT', ?, 'SUCCESS' FROM account_holds h JOIN accounts ac ON ac.account_id = h.account_id JOIN users u ON u.id = ac.user_id, users a WHERE h.hold_id = ? AND a.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                CALL "SQL_ROLLBACK" END-CALL
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT" END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "SUCCESS|COMMIT"
                SET WS-TRANSFER-FAIL-DB TO TRUE
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        PARSE-MAJOR.
            *> Canonical money parse into major units. The program compiles
            *> with DECIMAL-POINT IS COMMA, so NUMVAL reads a dot as a
            *> thousands separator ("100.01" would parse as 10001). Normalize
            *> the dot to a comma first; callers pass only validated
            *> digit/dot strings or exact decimals read back from the DB.
            MOVE WS-PARSE-SRC TO WS-PARSE-BUF
            INSPECT WS-PARSE-BUF REPLACING ALL "." BY ","
            COMPUTE WS-PARSE-NUM = FUNCTION NUMVAL(WS-PARSE-BUF) END-COMPUTE
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
