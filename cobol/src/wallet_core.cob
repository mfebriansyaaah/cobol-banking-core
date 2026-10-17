        IDENTIFICATION DIVISION.
        PROGRAM-ID. wallet_core.

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
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-AMT-DOTS            PIC 9(2) VALUE 0.
        01  WS-AMT-DIGITS          PIC 9(2) VALUE 0.
        01  WS-AMT-FRAC            PIC 9(2) VALUE 0.
        01  WS-AMT-SEEN-DOT        PIC X(1) VALUE "0".
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
        01  WS-DENIED-TARGET        PIC X(100) VALUE SPACES.
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
        01  WS-TARGET-PREC         PIC X(2)  VALUE SPACES.
        01  WS-RATE-STR            PIC X(40) VALUE SPACES.

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
        
        MAIN-LOGIC.
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:13) = "CHECK_BALANCE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM GET-BALANCE-LOGIC
                WHEN LS-CMD-ACTION(1:16) = "REVERSE_TRANSFER"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM REVERSE-TRANSFER-LOGIC
                WHEN LS-CMD-ACTION(1:9) = "TX_STATUS"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRANSFER-STATUS-LOGIC
                WHEN LS-CMD-ACTION(1:8) = "TRANSFER"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM TRIM-PARAM5
                    PERFORM TRIM-PARAM6
                    PERFORM TRANSFER-LOGIC
                WHEN LS-CMD-ACTION(1:9) = "RECONCILE"
                    PERFORM TRIM-PARAM1
                    PERFORM RECONCILE-LOGIC
                WHEN LS-CMD-ACTION(1:18) = "RUN_RECONCILIATION"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM RUN-RECONCILIATION-LOGIC
                WHEN LS-CMD-ACTION(1:20) = "LIST_RECONCILIATIONS"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM LIST-RECONCILIATIONS-LOGIC
                WHEN LS-CMD-ACTION(1:15) = "LIST_EXCEPTIONS"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM LIST-EXCEPTIONS-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "ACK_EXCEPTION"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM ACK-EXCEPTION-LOGIC
                WHEN LS-CMD-ACTION(1:17) = "RESOLVE_EXCEPTION"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM RESOLVE-EXCEPTION-LOGIC
                WHEN LS-CMD-ACTION(1:10) = "PLACE_HOLD"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM TRIM-PARAM5
                    PERFORM TRIM-PARAM6
                    PERFORM PLACE-HOLD-LOGIC
                WHEN LS-CMD-ACTION(1:12) = "RELEASE_HOLD"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM RELEASE-HOLD-LOGIC
                WHEN LS-CMD-ACTION(1:12) = "OPEN_DISPUTE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM TRIM-PARAM5
                    PERFORM OPEN-DISPUTE-LOGIC
                WHEN LS-CMD-ACTION(1:16) = "ADD_DISPUTE_NOTE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM ADD-DISPUTE-NOTE-LOGIC
                WHEN LS-CMD-ACTION(1:11) = "ACK_DISPUTE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM ACK-DISPUTE-LOGIC
                WHEN LS-CMD-ACTION(1:15) = "RESOLVE_DISPUTE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM RESOLVE-DISPUTE-LOGIC
                WHEN LS-CMD-ACTION(1:14) = "REJECT_DISPUTE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM REJECT-DISPUTE-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "LIST_DISPUTES"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM TRIM-PARAM5
                    PERFORM LIST-DISPUTES-LOGIC
                WHEN LS-CMD-ACTION(1:11) = "GET_DISPUTE"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM GET-DISPUTE-LOGIC
                WHEN LS-CMD-ACTION(1:9) = "STATEMENT"
                    PERFORM TRIM-PARAM1
                    PERFORM TRIM-PARAM2
                    PERFORM TRIM-PARAM3
                    PERFORM TRIM-PARAM4
                    PERFORM TRIM-PARAM5
                    PERFORM TRIM-PARAM6
                    PERFORM STATEMENT-LOGIC
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
            MOVE LS-PARAM2 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM3 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM4 TO WS-CHECK
            PERFORM VALIDATE-INPUT.
            EXIT PARAGRAPH.

        VALIDATE-INPUT.
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-QUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-DQUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-BSLASH
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-SEMI
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-TICK.
            EXIT PARAGRAPH.

        TRIM-PARAM1.
            MOVE LS-PARAM1 TO WS-PARAM1-TRIMMED.
            MOVE 0 TO WS-P1-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P1-LEN > 0
                IF WS-PARAM1-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P1-LEN
                END-IF
            END-PERFORM.

        TRIM-PARAM2.
            MOVE LS-PARAM2 TO WS-PARAM2-TRIMMED.
            MOVE 0 TO WS-P2-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P2-LEN > 0
                IF WS-PARAM2-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P2-LEN
                END-IF
            END-PERFORM.

        TRIM-PARAM3.
            MOVE LS-PARAM3 TO WS-PARAM3-TRIMMED.
            MOVE 0 TO WS-P3-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P3-LEN > 0
                IF WS-PARAM3-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P3-LEN
                END-IF
            END-PERFORM.

        TRIM-PARAM4.
            MOVE LS-PARAM4 TO WS-PARAM4-TRIMMED.
            MOVE 0 TO WS-P4-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P4-LEN > 0
                IF WS-PARAM4-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P4-LEN
                END-IF
            END-PERFORM.

        TRIM-PARAM5.
            MOVE LS-PARAM5 TO WS-PARAM5-TRIMMED.
            MOVE 0 TO WS-P5-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P5-LEN > 0
                IF WS-PARAM5-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P5-LEN
                END-IF
            END-PERFORM.

        TRIM-PARAM6.
            MOVE LS-PARAM6 TO WS-PARAM6-TRIMMED.
            MOVE 0 TO WS-P6-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P6-LEN > 0
                IF WS-PARAM6-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P6-LEN
                END-IF
            END-PERFORM.

        ALLOW-READ.
            *> Sets WS-ALLOWED when the actor (p2) owns the target (p1) or is an admin.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF
            IF WS-ALLOWED NOT = 1
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            *> Records a refused authorization attempt for WS-DENIED-ACTOR;
            *> unknown actors produce no row. Best-effort.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'USER', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT.
            EXIT PARAGRAPH.

        GET-BALANCE-LOGIC.
            PERFORM ALLOW-READ
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            *> Every account the user holds, as iso:balance:available:status rows.
            MOVE "SELECT CONCAT(c.iso_code, ':', REPLACE(FORMAT(a.balance,c.prec_val), ',', ''), ':', REPLACE(FORMAT(a.balance - COALESCE((SELECT SUM(h.amount) FROM account_holds h WHERE h.account_id = a.account_id AND h.state = 'PLACED' AND (h.expires_at IS NULL OR h.expires_at > NOW())),0),c.prec_val), ',', ''), ':', a.status) FROM accounts a JOIN users u ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ? ORDER BY c.iso_code" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|BALANCES|" DELIMITED BY SIZE
                       WS-RESULT DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        REVERSE-TRANSFER-LOGIC.
            *> p1 = original txn_ref, p2 = actor (SUPER_ADMIN). Compensating,
            *> one-time reversal: credit the original sender, debit the target.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Resolve the transfer's sender. txn_ref is unique per sender, so a
            *> shared reference is refused unless the sender is given (p3).
            MOVE SPACES TO WS-REV-FROM
            IF WS-P3-LEN > 0
                MOVE WS-PARAM3-TRIMMED(1:WS-P3-LEN) TO WS-REV-FROM
            END-IF
            IF WS-REV-FROM = SPACES
                MOVE "SELECT CAST(COUNT(DISTINCT from_email) AS CHAR), MIN(from_email) FROM ledger WHERE txn_ref = ? AND type = 'DEBIT' AND from_email IS NOT NULL" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT = "ERROR|NO_DATA"
                    MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                UNSTRING WS-RESULT DELIMITED BY "|"
                    INTO WS-REV-CNT WS-REV-MINFROM
                END-UNSTRING
                IF WS-REV-CNT(1:1) = "0"
                    MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                IF WS-REV-CNT NOT = "1"
                    MOVE "ERROR|AMBIGUOUS_TRANSACTION" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE WS-REV-MINFROM TO WS-REV-FROM
            END-IF
            *> Already reversed? One reversal per (ref, sender).
            MOVE "SELECT 1 FROM transfer_reversals WHERE orig_ref = ? AND from_email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "ERROR|ALREADY_REVERSED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> The original debit (sender side) and credit (target side), scoped
            *> to the sender so a shared reference cannot pick the wrong rows.
            MOVE "SELECT CAST(account_id AS CHAR), CAST(amount AS CHAR), CAST(currency_id AS CHAR) FROM ledger WHERE txn_ref = ? AND type = 'DEBIT' AND from_email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-SENDER-ACC WS-REV-AMT WS-SENDER-CUR
            END-UNSTRING
            MOVE "SELECT CAST(account_id AS CHAR), CAST(amount AS CHAR), CAST(l.currency_id AS CHAR), CAST(exchange_rate AS CHAR), CAST(c.prec_val AS CHAR) FROM ledger l JOIN currencies c ON c.currency_id = l.currency_id WHERE txn_ref = ? AND type = 'CREDIT' AND from_email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-TARGET-ACC WS-REV-CAMT WS-TARGET-CUR WS-RATE-STR
                     WS-TARGET-PREC
            END-UNSTRING
            SET WS-TRANSFER-OK TO TRUE
            CALL "SQL_BEGIN"
            *> Lock both original accounts (ordered) before touching balances.
            PERFORM LOCK-ACCOUNTS
            IF WS-TRANSFER-FAIL-DB
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> The target must still hold the credited amount to claw it back.
            MOVE "SELECT CONCAT(balance) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
            MOVE WS-TARGET-ACC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-SENDER-BAL
            MOVE WS-SENDER-BAL TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-BALANCE-NUM
            MOVE WS-REV-CAMT TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-REV-CAMT-NUM
            IF WS-BALANCE-NUM < WS-REV-CAMT-NUM
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            SET STEP-OK TO TRUE
            *> Open the journal header for this reversal; legs and the audit
            *> row below point at it through the connection-scoped @jid.
            IF STEP-OK
                MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'REVERSAL', ?)" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            *> One-time marker (PK on orig_ref): a duplicate means already reversed.
            MOVE "INSERT INTO transfer_reversals (orig_ref, from_email, actor_id) SELECT ?, ?, id FROM users WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-REV-FROM TO WS-BIND-2
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF
            IF STEP-OK
                MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-REV-AMT TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-REV-CAMT TO WS-BIND-1
                MOVE WS-TARGET-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, 'Reversal in', ?, @jid, ?)" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                MOVE WS-REV-AMT TO WS-BIND-3
                MOVE WS-SENDER-CUR TO WS-BIND-4
                MOVE WS-RATE-STR TO WS-BIND-5
                MOVE WS-REV-FROM TO WS-BIND-6
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, 'Reversal out', 1, @jid, ?)" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-TARGET-ACC TO WS-BIND-2
                MOVE WS-REV-CAMT TO WS-BIND-3
                MOVE WS-TARGET-CUR TO WS-BIND-4
                MOVE WS-REV-FROM TO WS-BIND-5
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            IF STEP-OK
                MOVE "SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE WS-RESULT TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                MOVE WS-REV-FROM TO WS-BIND-3
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, detail, status, journal_id) VALUES (?, 'REVERSE_TRANSFER', 'LEDGER', ?, ?, 'SUCCESS', @jid)" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF
            *> Every leg is written against the open journal; verify the
            *> journal balances before anything becomes durable. The guard
            *> flag is shared with TRANSFER-LOGIC, so reset it first: in
            *> serve mode Working-Storage survives across requests.
            SET WS-TRANSFER-OK TO TRUE
            IF STEP-OK
                MOVE WS-TARGET-PREC TO WS-JV-PREC
                PERFORM VERIFY-JOURNAL-BALANCED
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|TRANSFER_REVERSED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|REVERSAL_FAILED" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        TRANSFER-STATUS-LOGIC.
            *> p1 = ref, p2 = actor. Owner or admin only.
            MOVE 0 TO WS-ALLOWED
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF
            *> Optional sender filter (p3) lets an admin target one sender; a
            *> non-admin's query is always pinned to their own email. The
            *> amount is formatted at the sender currency's own precision: the
            *> ledger DEBIT leg names the posted currency, and a still-pending
            *> intent falls back to the sender's account currency when it is
            *> unambiguous (a single currency), else 2 decimals. FORMAT (not
            *> ROUND) is used because ROUND keeps its input scale when the
            *> precision is a subquery, which MySQL cannot fold at prepare time.
            MOVE SPACES TO WS-PREP-SQL
            MOVE 1 TO WS-SQL-PTR
            STRING "SELECT p.from_email, p.to_email, REPLACE(FORMAT(p.amount, COALESCE(" DELIMITED BY SIZE
                   "(SELECT c.prec_val FROM ledger l JOIN currencies c ON c.currency_id = l.currency_id " DELIMITED BY SIZE
                   "WHERE l.txn_ref = p.txn_ref AND l.from_email = p.from_email AND l.type = 'DEBIT' LIMIT 1), " DELIMITED BY SIZE
                   "(SELECT MIN(c.prec_val) FROM accounts a JOIN users u ON u.id = a.user_id " DELIMITED BY SIZE
                   "JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = p.from_email " DELIMITED BY SIZE
                   "GROUP BY u.email HAVING COUNT(DISTINCT a.currency_id) = 1), 2)), ',', ''), p.status " DELIMITED BY SIZE
                   "FROM pending_transactions p WHERE p.txn_ref = ?" DELIMITED BY SIZE
                INTO WS-PREP-SQL WITH POINTER WS-SQL-PTR
            END-STRING
            IF WS-P3-LEN > 0
                STRING " AND p.from_email = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL WITH POINTER WS-SQL-PTR
                END-STRING
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            ELSE
                IF WS-ALLOWED = 1
                    STRING " ORDER BY p.id DESC LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL WITH POINTER WS-SQL-PTR
                    END-STRING
                    MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                ELSE
                    STRING " AND p.from_email = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL WITH POINTER WS-SQL-PTR
                    END-STRING
                    MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                    MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                        BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                END-IF
            END-IF
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-TX-FROM WS-TX-TO WS-TX-AMT WS-TX-STATUS
            END-UNSTRING
            *> A non-admin may only see their own.
            IF WS-ALLOWED = 0
                IF WS-TX-FROM(1:WS-P2-LEN) NOT = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                    MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF
            MOVE "0" TO WS-REVERSED
            MOVE "SELECT 1 FROM transfer_reversals WHERE orig_ref = ? AND from_email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-TX-FROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "ERROR|NO_DATA"
                MOVE "1" TO WS-REVERSED
            END-IF
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-REVERSED = "1"
                STRING "SUCCESS|TRANSFER|REVERSED|" DELIMITED BY SIZE
                       WS-TX-FROM DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-TX-TO DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-TX-AMT DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                STRING "SUCCESS|TRANSFER|" DELIMITED BY SIZE
                       WS-TX-STATUS DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-TX-FROM DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-TX-TO DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-TX-AMT DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        STATEMENT-LOGIC.
            *> p1 = owner email, p2 = actor (owner or admin via
            *> ALLOW-READ), p3 = currency ISO (pins the account),
            *> p4 = "from,to" ISO posting dates (each side optional),
            *> p5 = limit, p6 = offset. Read-only account statement:
            *> opening and closing balances plus one row per posting in
            *> range, oldest first, each with posting/value dates,
            *> reference, source, side, amount, balance after the row,
            *> a reversal flag, and the ledger description. Balances and
            *> lines are projected from the immutable ledger, so every
            *> statement is reproducible from source records.
            PERFORM ALLOW-READ
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-LEN = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-ST-FROM WS-ST-TO
            UNSTRING WS-PARAM4-TRIMMED DELIMITED BY ","
                INTO WS-ST-FROM WS-ST-TO
            END-UNSTRING
            MOVE WS-ST-FROM TO WS-DATE-SRC
            PERFORM CHECK-ST-DATE
            IF WS-DATE-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-ST-TO TO WS-DATE-SRC
            PERFORM CHECK-ST-DATE
            IF WS-DATE-BAD NOT = 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-ST-FROM NOT = SPACES
                IF WS-ST-TO NOT = SPACES
                    IF WS-ST-FROM > WS-ST-TO
                        MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                        EXIT PARAGRAPH
                    END-IF
                END-IF
            END-IF.
            MOVE "50" TO WS-RLIMIT
            MOVE "0" TO WS-ROFFSET
            IF WS-P5-LEN > 0
                MOVE WS-PARAM5-TRIMMED TO WS-RLIMIT
            END-IF.
            IF WS-P6-LEN > 0
                MOVE WS-PARAM6-TRIMMED TO WS-ROFFSET
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
            MOVE "SELECT CAST(a.account_id AS CHAR), CAST(c.prec_val AS CHAR), c.iso_code FROM accounts a JOIN users u ON u.id = a.user_id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ? AND c.iso_code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-ST-ACC WS-ST-PREC WS-ST-ISO
            END-UNSTRING
            IF WS-ST-FROM = SPACES
                MOVE "1000-01-01" TO WS-ST-QFROM
            ELSE
                MOVE WS-ST-FROM TO WS-ST-QFROM
            END-IF.
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT REPLACE(FORMAT(COALESCE(SUM(CASE WHEN type = 'CREDIT' THEN amount ELSE 0 - amount END), 0), " WS-ST-PREC(1:1) "), ',', '') FROM ledger WHERE account_id = ? AND DATE(created_at) < ?" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-ST-ACC TO WS-BIND-1
            MOVE WS-ST-QFROM TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-ST-OPEN
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ledger WHERE account_id = ? AND DATE(created_at) >= COALESCE(NULLIF(?, ''), DATE(created_at)) AND DATE(created_at) <= COALESCE(NULLIF(?, ''), DATE(created_at))" TO WS-PREP-SQL
            MOVE WS-ST-ACC TO WS-BIND-1
            MOVE WS-ST-FROM TO WS-BIND-2
            MOVE WS-ST-TO TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-RTOTAL
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT REPLACE(FORMAT((? + COALESCE(SUM(CASE WHEN type = 'CREDIT' THEN amount ELSE 0 - amount END), 0)), " WS-ST-PREC(1:1) "), ',', '') FROM ledger WHERE account_id = ? AND DATE(created_at) >= COALESCE(NULLIF(?, ''), DATE(created_at)) AND DATE(created_at) <= COALESCE(NULLIF(?, ''), DATE(created_at))" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-ST-OPEN TO WS-BIND-1
            MOVE WS-ST-ACC TO WS-BIND-2
            MOVE WS-ST-FROM TO WS-BIND-3
            MOVE WS-ST-TO TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-ST-CLOSE
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CONCAT(l.ledger_id, ':', DATE(l.created_at), ':', " DELIMITED BY SIZE
                   "COALESCE(j.value_date, DATE(l.created_at)), ':', l.txn_ref, ':', " DELIMITED BY SIZE
                   "COALESCE(j.source, 'TRANSFER'), ':', l.type, ':', " DELIMITED BY SIZE
                   "REPLACE(FORMAT(l.amount, " DELIMITED BY SIZE
                   WS-ST-PREC DELIMITED BY SPACE
                   "), ',', ''), ':', REPLACE(FORMAT((? + SUM(CASE WHEN l.type = 'CREDIT' " DELIMITED BY SIZE
                   "THEN l.amount ELSE 0 - l.amount END) OVER (ORDER BY l.ledger_id)), " DELIMITED BY SIZE
                   WS-ST-PREC DELIMITED BY SPACE
                   "), ',', ''), ':', EXISTS(SELECT 1 FROM ledger x JOIN journal_entries y " DELIMITED BY SIZE
                   "ON y.journal_id = x.journal_id WHERE x.txn_ref = l.txn_ref AND " DELIMITED BY SIZE
                   "x.from_email <=> l.from_email AND y.source = 'REVERSAL'), ':', " DELIMITED BY SIZE
                   "l.description) FROM ledger l LEFT JOIN journal_entries j ON j.journal_id = " DELIMITED BY SIZE
                   "l.journal_id WHERE l.account_id = ? AND DATE(l.created_at) >= " DELIMITED BY SIZE
                   "COALESCE(NULLIF(?, ''), DATE(l.created_at)) AND DATE(l.created_at) <= " DELIMITED BY SIZE
                   "COALESCE(NULLIF(?, ''), DATE(l.created_at)) ORDER BY l.ledger_id " DELIMITED BY SIZE
                   "LIMIT ? OFFSET ?" DELIMITED BY SIZE
               INTO WS-PREP-SQL
            END-STRING
            MOVE WS-ST-OPEN TO WS-BIND-1
            MOVE WS-ST-ACC TO WS-BIND-2
            MOVE WS-ST-FROM TO WS-BIND-3
            MOVE WS-ST-TO TO WS-BIND-4
            MOVE WS-RLIMIT TO WS-BIND-5
            MOVE WS-ROFFSET TO WS-BIND-6
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                IF WS-RESULT NOT = "ERROR|NO_DATA"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|STATEMENT|" DELIMITED BY SIZE
                       WS-ST-OPEN DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-ST-CLOSE DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-ST-ISO DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RTOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RUN-RESULT-LEN
                STRING "SUCCESS|STATEMENT|" DELIMITED BY SIZE
                       WS-ST-OPEN DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-ST-CLOSE DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-ST-ISO DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RTOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT = "ERROR|NO_DATA"
                    MOVE "SELECT 1 FROM ledger l JOIN accounts a ON a.account_id = l.account_id JOIN users u ON u.id = a.user_id WHERE l.txn_ref = ? AND u.email = ? LIMIT 1" TO WS-PREP-SQL
                    MOVE WS-PARAM5-TRIMMED TO WS-BIND-1
                    MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                        BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            CALL "SQL_BEGIN"
            MOVE "INSERT INTO dispute_cases (user_id, txn_ref, subject, detail) SELECT id, ?, ?, ? FROM users WHERE email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM5-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM4-TRIMMED TO WS-BIND-3
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                MOVE WS-RESULT TO WS-DSP-CASE
                MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT u.id, a.id, 'DISPUTE_OPENED', 'DISPUTE', ?, 'SUCCESS' FROM users u, users a WHERE u.email = ? AND a.email = ?" TO WS-PREP-SQL
                MOVE WS-DSP-CASE TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|DISPUTE_OPENED|" DELIMITED BY SIZE
                       WS-DSP-CASE DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
            END-IF.
            EXIT PARAGRAPH.

        LOAD-DISPUTE-CASE.
            *> Loads WS-DSP-OWNER (owner email) and WS-DSP-STATE for the case
            *> named by p1. Emits UNKNOWN_TRANSACTION / INVALID_INPUT / DB_ERROR.
            MOVE WS-PARAM1-TRIMMED TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT u.email, d.state FROM dispute_cases d JOIN users u ON u.id = d.user_id WHERE d.case_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM3-TRIMMED TO WS-DATE-SRC
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
            CALL "SQL_BEGIN"
            MOVE "UPDATE dispute_cases SET state = 'ACKNOWLEDGED', assigned_to = (SELECT id FROM users WHERE email = ?), due_date = NULLIF(?, ''), decided_at = NULL WHERE case_id = ? AND state = 'OPEN'" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|DISPUTE_ACKNOWLEDGED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
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
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            CALL "SQL_BEGIN"
            MOVE "UPDATE dispute_cases SET state = 'RESOLVED', resolution = ?, decided_at = NOW() WHERE case_id = ? AND state = 'ACKNOWLEDGED'" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|DISPUTE_RESOLVED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
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
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            CALL "SQL_BEGIN"
            MOVE "UPDATE dispute_cases SET state = 'REJECTED', resolution = ?, decided_at = NOW() WHERE case_id = ? AND state IN ('OPEN', 'ACKNOWLEDGED')" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET STEP-FAIL TO TRUE
                END-IF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|DISPUTE_REJECTED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
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
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-DSP-STATE
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
                MOVE WS-PARAM4-TRIMMED TO WS-RLIMIT
            END-IF.
            IF WS-P5-LEN > 0
                MOVE WS-PARAM5-TRIMMED TO WS-ROFFSET
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-RTOTAL
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
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-RTOTAL
            MOVE "SELECT CONCAT(m.msg_id, ':', COALESCE((SELECT email FROM users WHERE id = m.author_id), ''), ':', m.body, ':', DATE(m.created_at)) FROM dispute_messages m WHERE m.case_id = ? ORDER BY m.msg_id LIMIT 100" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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

        PLACE-HOLD-LOGIC.
            *> p1 = owner email, p2 = amount, p3 = actor (SUPER_ADMIN),
            *> p4 = expiry in days (empty/0 = none), p5 = currency pin
            *> (required when the owner holds several accounts), p6 = reason.
            *> Locks part of an account's balance: PLACED holds reduce the
            *> spendable balance until released or expired.
            SET WS-TRANSFER-OK TO TRUE.
            IF WS-TRANSFER-OK
                MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            END-IF.
            IF WS-TRANSFER-OK AND WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-TRANSFER-OK
                MOVE WS-PARAM1-TRIMMED TO WS-CAP-SRC
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
                    ADD 1 TO WS-AMT-DOTS
                    MOVE "1" TO WS-AMT-SEEN-DOT
                ELSE
                    IF WS-PARAM2-TRIMMED(WS-I:1) >= "0"
                       AND WS-PARAM2-TRIMMED(WS-I:1) <= "9"
                        ADD 1 TO WS-AMT-DIGITS
                        IF WS-AMT-SEEN-DOT = "1"
                            ADD 1 TO WS-HOLD-FRAC
                        END-IF
                    ELSE
                        SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                    END-IF
                END-IF
            END-PERFORM.
            IF WS-AMT-DOTS > 1 OR WS-HOLD-FRAC > 4 OR WS-AMT-DIGITS < 1
                SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
            END-IF.
            IF WS-AMT-DIGITS > 15
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            ELSE
                MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            END-IF.
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
            COMPUTE WS-PREC-NUM = FUNCTION NUMVAL(WS-SENDER-PREC)
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
                MOVE WS-PARAM4-TRIMMED TO WS-CAP-SRC
                PERFORM CHECK-CAP-DIGITS
                IF WS-CAP-OK = "Y"
                    MOVE WS-PARAM4-TRIMMED TO WS-HOLD-DAYS
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
            CALL "SQL_BEGIN"
            MOVE "SELECT account_id FROM accounts WHERE account_id = ? FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-HOLD-ACC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(balance, '|', COALESCE((SELECT SUM(amount) FROM account_holds WHERE account_id = a.account_id AND state = 'PLACED' AND (expires_at IS NULL OR expires_at > NOW())),0)) FROM accounts a WHERE a.account_id = ?" TO WS-PREP-SQL
            MOVE WS-HOLD-ACC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
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
                CALL "SQL_ROLLBACK"
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
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-HOLD-ID
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT u.id, a.id, 'PLACE_HOLD', 'ACCOUNT', ?, ?, 'SUCCESS' FROM users u, users a WHERE u.email = ? AND a.email = ?" TO WS-PREP-SQL
            MOVE WS-HOLD-ACC TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-3
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT"
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
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            ELSE
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
            END-IF.
            EXIT PARAGRAPH.

        APPLY-HOLD-RELEASE.
            *> Lock the hold row; only a PLACED hold can be released.
            CALL "SQL_BEGIN"
            MOVE "SELECT hold_id FROM account_holds WHERE hold_id = ? FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT state FROM account_holds WHERE hold_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "PLACED"
                CALL "SQL_ROLLBACK"
                SET WS-TRANSFER-FAIL-CONFLICT TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-CONFLICT
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE account_holds SET state = 'RELEASED' WHERE hold_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT u.id, a.id, 'RELEASE_HOLD', 'ACCOUNT', ?, 'SUCCESS' FROM account_holds h JOIN accounts ac ON ac.account_id = h.account_id JOIN users u ON u.id = ac.user_id, users a WHERE h.hold_id = ? AND a.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT"
            EXIT PARAGRAPH.

        VALIDATE-AMOUNT.
            *> Defense-in-depth: the core checks the amount is a plain positive
            *> decimal and counts its fraction digits, so the per-currency
            *> precision check (after the sender account is resolved) can
            *> enforce them against that currency's prec_val. At most four
            *> fraction digits: the DECIMAL(18,4) schema cannot store more.
            MOVE 0 TO WS-AMT-DOTS
            MOVE 0 TO WS-AMT-DIGITS
            MOVE 0 TO WS-AMT-FRAC
            MOVE "0" TO WS-AMT-SEEN-DOT
            IF WS-P3-LEN < 1
                SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                EXIT PARAGRAPH
            END-IF
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-P3-LEN
                IF WS-PARAM3-TRIMMED(WS-I:1) = "."
                    ADD 1 TO WS-AMT-DOTS
                    MOVE "1" TO WS-AMT-SEEN-DOT
                ELSE
                    IF WS-PARAM3-TRIMMED(WS-I:1) >= "0"
                       AND WS-PARAM3-TRIMMED(WS-I:1) <= "9"
                        ADD 1 TO WS-AMT-DIGITS
                        IF WS-AMT-SEEN-DOT = "1"
                            ADD 1 TO WS-AMT-FRAC
                        END-IF
                    ELSE
                        SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                    END-IF
                END-IF
            END-PERFORM
            IF WS-AMT-DOTS > 1 OR WS-AMT-FRAC > 4 OR WS-AMT-DIGITS < 1
                OR WS-AMT-DIGITS > 15
                SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
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
            COMPUTE WS-PARSE-NUM = FUNCTION NUMVAL(WS-PARSE-BUF)
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

        CHECK-DAILY-TOTAL.
            *> Rolling 24h debit total, read at full stored precision and
            *> compared in major units — no fixed scaling.
            MOVE "SELECT CAST(COALESCE(SUM(l.amount),0) AS CHAR) FROM ledger l WHERE l.account_id = ? AND l.type = 'DEBIT' AND l.created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)" TO WS-PREP-SQL
            MOVE WS-SENDER-ACC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            ELSE
                PERFORM RECORD-DAILY-TOTAL
            END-IF.
            EXIT PARAGRAPH.

        RECORD-DAILY-TOTAL.
            *> Comparison kept in its own paragraph so each branch above is
            *> one sentence per the inline-scope rule.
            MOVE WS-RESULT TO WS-PRIOR-TOTAL-STR
            MOVE WS-PRIOR-TOTAL-STR TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-PRIOR-TOTAL-NUM
            IF WS-PRIOR-TOTAL-NUM + WS-AMOUNT-NUM > WS-DAILY-LIMIT-NUM
                SET WS-TRANSFER-FAIL-DAILY TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        VERIFY-JOURNAL-BALANCED.
            *> Pre-commit guard: the journal must hold exactly one DEBIT leg
            *> and one CREDIT leg whose amounts agree through the snapshotted
            *> rate — in either direction, so one paragraph serves transfers
            *> (credit = debit x rate) and reversals (debit = credit x rate).
            *> A violation rolls the whole posting back.
            MOVE "SELECT IF(COUNT(*)=2 AND SUM(type='DEBIT')=1 AND (MAX(CASE WHEN type='CREDIT' THEN amount END) = ROUND(MAX(CASE WHEN type='DEBIT' THEN amount END) * MAX(CASE WHEN type='CREDIT' THEN exchange_rate END), ?) OR MAX(CASE WHEN type='DEBIT' THEN amount END) = ROUND(MAX(CASE WHEN type='CREDIT' THEN amount END) * MAX(CASE WHEN type='CREDIT' THEN exchange_rate END), ?)),'BALANCED','UNBALANCED') FROM ledger WHERE journal_id = @jid" TO WS-PREP-SQL
            MOVE WS-JV-PREC TO WS-BIND-1
            MOVE WS-JV-PREC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "BALANCED"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        LOOKUP-TRANSFER-FEE.
            *> Bank-owned per-currency flat fee in major units. No schedule
            *> row means no fee; a fee the currency cannot represent exactly
            *> fails closed instead of rounding silently.
            MOVE "SELECT CAST(fee_amount AS CHAR), fee_amount = ROUND(fee_amount, ?) FROM fee_schedule WHERE currency_id = ?" TO WS-PREP-SQL
            MOVE WS-SENDER-PREC TO WS-BIND-1
            MOVE WS-SENDER-CUR TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE 0 TO WS-FEE-NUM
            END-IF.
            IF WS-RESULT = "ERROR|NO_DATA"
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-FEE-STR WS-FEE-EXACT
            END-UNSTRING
            IF WS-FEE-EXACT NOT = "1"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-FEE-STR TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            MOVE WS-PARSE-NUM TO WS-FEE-NUM
            EXIT PARAGRAPH.

        POST-FEE-JOURNAL.
            *> The fee is its own posting: DEBIT the sender, CREDIT the
            *> currency's fee-income account, verified like any journal.
            MOVE "SELECT CAST(account_id AS CHAR) FROM accounts WHERE currency_id = ? AND account_type = 'FEE_INCOME' AND status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-SENDER-CUR TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT = "ERROR|NO_DATA"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-INCOME-ACC
            MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'FEE', ?)" TO WS-PREP-SQL
            MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ?" TO WS-PREP-SQL
            MOVE WS-FEE-STR TO WS-BIND-1
            MOVE WS-SENDER-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
            MOVE WS-FEE-STR TO WS-BIND-1
            MOVE WS-INCOME-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, 'Fee out', 1, @jid, ?)" TO WS-PREP-SQL
            MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
            MOVE WS-SENDER-ACC TO WS-BIND-2
            MOVE WS-FEE-STR TO WS-BIND-3
            MOVE WS-SENDER-CUR TO WS-BIND-4
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, 'Fee in', 1, @jid, ?)" TO WS-PREP-SQL
            MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
            MOVE WS-INCOME-ACC TO WS-BIND-2
            MOVE WS-FEE-STR TO WS-BIND-3
            MOVE WS-SENDER-CUR TO WS-BIND-4
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-5
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-SENDER-PREC TO WS-JV-PREC
            PERFORM VERIFY-JOURNAL-BALANCED
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE SPACES TO WS-DETAIL
            STRING WS-FEE-STR DELIMITED BY SPACE ":" DELIMITED BY SIZE
                   WS-SENDER-ISO DELIMITED BY SPACE
                   INTO WS-DETAIL
            END-STRING
            MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status, detail, journal_id) VALUES (?, 'FEE', 'ACCOUNT', ?, 'SUCCESS', ?, @jid)" TO WS-PREP-SQL
            MOVE WS-SENDER-USER TO WS-BIND-1
            MOVE WS-SENDER-ACC TO WS-BIND-2
            MOVE WS-DETAIL TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        CHECK-TRANSIENT.
            *> WS-RESULT holds "ERROR|<kind>|<errno>" from the bridge. Flag a
            *> retriable condition (lock wait, deadlock, lost connection).
            MOVE "0" TO WS-BUSY
            MOVE 0 TO WS-BAD
            INSPECT WS-RESULT TALLYING WS-BAD FOR ALL "1205"
            INSPECT WS-RESULT TALLYING WS-BAD FOR ALL "1213"
            INSPECT WS-RESULT TALLYING WS-BAD FOR ALL "2006"
            INSPECT WS-RESULT TALLYING WS-BAD FOR ALL "2013"
            IF WS-BAD > 0
                MOVE "1" TO WS-BUSY
            END-IF.
            EXIT PARAGRAPH.

        RECONCILE-LOGIC.
            *> Only a SUPER_ADMIN (the actor, p1) may run the diagnostic.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT

            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-ACTOR
                MOVE SPACES TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF

            *> Any account whose stored balance differs from its ledger sum.
            *> Display rounds to each currency's own precision.
            MOVE "SELECT CAST(a.account_id AS CHAR), CONCAT(REPLACE(FORMAT(a.balance,c.prec_val), ',', '')), CONCAT(REPLACE(FORMAT(COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0),c.prec_val), ',', '')) FROM accounts a LEFT JOIN ledger l ON l.account_id = a.account_id JOIN currencies c ON c.currency_id = a.currency_id GROUP BY a.account_id, a.balance, c.prec_val HAVING a.balance <> COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0)" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "SUCCESS|RECONCILED" TO LS-OUTPUT-BUFFER
            ELSE
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "ERROR|MISMATCH|" WS-RESULT DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        RUN-RECONCILIATION-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = trigger (MANUAL/SCHEDULED).
            *> Computes the balance-vs-ledger outcome first, then inserts one
            *> immutable run row plus one OPEN finding per mismatch. A crash
            *> before COMMIT leaves no partial run behind.
            MOVE "MANUAL" TO WS-RUN-TRIGGER
            IF WS-P2-LEN > 0
                MOVE WS-PARAM2-TRIMMED TO WS-RUN-TRIGGER
            END-IF.
            IF WS-RUN-TRIGGER NOT = "MANUAL" AND WS-RUN-TRIGGER NOT = "SCHEDULED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-ACTOR
                MOVE SPACES TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN"
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM (SELECT a.account_id FROM accounts a LEFT JOIN ledger l ON l.account_id = a.account_id GROUP BY a.account_id, a.balance HAVING a.balance <> COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0)) t" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-RUN-COUNT
            IF WS-RUN-COUNT = "0"
                MOVE "INSERT INTO reconciliation_runs (trigger_src, actor_email, status, mismatch_count) VALUES (?, ?, 'CLEAN', 0)" TO WS-PREP-SQL
            ELSE
                MOVE "INSERT INTO reconciliation_runs (trigger_src, actor_email, status, mismatch_count) VALUES (?, ?, 'MISMATCH', ?)" TO WS-PREP-SQL
            END-IF.
            MOVE WS-RUN-TRIGGER TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            MOVE WS-RUN-COUNT TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT TO WS-RUN-ID
            IF WS-RUN-COUNT NOT = "0"
                MOVE "INSERT INTO reconciliation_findings (run_id, account_id, balance, ledger_sum) SELECT ?, a.account_id, a.balance, COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0) FROM accounts a LEFT JOIN ledger l ON l.account_id = a.account_id GROUP BY a.account_id, a.balance HAVING a.balance <> COALESCE(SUM(CASE WHEN l.type = 'CREDIT' THEN l.amount ELSE -l.amount END),0)" TO WS-PREP-SQL
                MOVE WS-RUN-ID TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    CALL "SQL_ROLLBACK"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF.
            CALL "SQL_COMMIT"
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|RUN_RECORDED|" WS-RUN-ID DELIMITED BY SPACE
                   "|" DELIMITED BY SIZE WS-RUN-COUNT DELIMITED BY SPACE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
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

        LIST-RECONCILIATIONS-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = limit, p3 = offset. Read-only
            *> view of recorded runs, newest first.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "50" TO WS-RLIMIT
            MOVE "0" TO WS-ROFFSET
            IF WS-P2-LEN > 0
                MOVE WS-PARAM2-TRIMMED TO WS-RLIMIT
            END-IF.
            IF WS-P3-LEN > 0
                MOVE WS-PARAM3-TRIMMED TO WS-ROFFSET
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
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM reconciliation_runs" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-RTOTAL
            MOVE "SELECT CONCAT(run_id, ':', trigger_src, ':', actor_email, ':', status, ':', mismatch_count, ':', DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s')) FROM reconciliation_runs ORDER BY run_id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-RLIMIT TO WS-BIND-1
            MOVE WS-ROFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|RUNS|" WS-RTOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RUN-RESULT-LEN
                STRING "SUCCESS|RUNS|" WS-RTOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        LIST-EXCEPTIONS-LOGIC.
            *> p1 = actor (SUPER_ADMIN), p2 = status filter, p3 = limit,
            *> p4 = offset. Read-only view of exception findings.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P2-LEN > 0 AND WS-PARAM2-TRIMMED NOT = "OPEN" AND WS-PARAM2-TRIMMED NOT = "ACKNOWLEDGED" AND WS-PARAM2-TRIMMED NOT = "RESOLVED"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "50" TO WS-RLIMIT
            MOVE "0" TO WS-ROFFSET
            IF WS-P3-LEN > 0
                MOVE WS-PARAM3-TRIMMED TO WS-RLIMIT
            END-IF.
            IF WS-P4-LEN > 0
                MOVE WS-PARAM4-TRIMMED TO WS-ROFFSET
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
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM reconciliation_findings WHERE status = COALESCE(NULLIF(?, ''), status)" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE WS-RESULT TO WS-RTOTAL
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CONCAT(finding_id, ':', run_id, ':', account_id, ':', balance, ':', ledger_sum, ':', status, ':', COALESCE(owner_email, ''), ':', REPLACE(REPLACE(COALESCE(resolution_note, ''), '|', '/'), ';', ','), ':', DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s')) FROM reconciliation_findings WHERE status = COALESCE(NULLIF(?, ''), status) ORDER BY finding_id DESC LIMIT ? OFFSET ?"
                   DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-RLIMIT TO WS-BIND-2
            MOVE WS-ROFFSET TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            MOVE SPACES TO LS-OUTPUT-BUFFER
            IF WS-RESULT = "ERROR|NO_DATA"
                STRING "SUCCESS|EXCEPTIONS|" WS-RTOTAL DELIMITED BY SPACE INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RUN-RESULT-LEN
                STRING "SUCCESS|EXCEPTIONS|" WS-RTOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACK-EXCEPTION-LOGIC.
            *> p1 = finding_id, p2 = actor (SUPER_ADMIN). Claims ownership:
            *> OPEN becomes ACKNOWLEDGED with the actor as owner.
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM1-TRIMMED TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN"
            MOVE "SELECT finding_id FROM reconciliation_findings WHERE finding_id = ? FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM reconciliation_findings WHERE finding_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "OPEN"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "UPDATE reconciliation_findings SET status = 'ACKNOWLEDGED', owner_email = ? WHERE finding_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) SELECT a.id, a.id, 'RECONCILE_ACK', 'ACCOUNT', ?, 'SUCCESS' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT"
            MOVE "SUCCESS|EXCEPTION_ACKNOWLEDGED" TO LS-OUTPUT-BUFFER
            EXIT PARAGRAPH.

        RESOLVE-EXCEPTION-LOGIC.
            *> p1 = finding_id, p2 = actor (SUPER_ADMIN), p3 = note (opt).
            *> Closes an ACKNOWLEDGED finding; the run link is kept.
            SET WS-TRANSFER-OK TO TRUE
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "SUPER_ADMIN"
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM1-TRIMMED TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-LEN > 0
                PERFORM VALIDATE-RESOLVE-NOTE
            END-IF.
            IF WS-TRANSFER-FAIL-AMOUNT
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_BEGIN"
            MOVE "SELECT finding_id FROM reconciliation_findings WHERE finding_id = ? FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT status FROM reconciliation_findings WHERE finding_id = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT NOT = "ACKNOWLEDGED"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|UNKNOWN_TRANSACTION" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P3-LEN = 0
                MOVE "UPDATE reconciliation_findings SET status = 'RESOLVED', resolution_note = NULL, resolved_at = NOW() WHERE finding_id = ?" TO WS-PREP-SQL
            ELSE
                MOVE "UPDATE reconciliation_findings SET status = 'RESOLVED', resolution_note = ?, resolved_at = NOW() WHERE finding_id = ?" TO WS-PREP-SQL
            END-IF.
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            IF WS-P3-LEN = 0
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            ELSE
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            END-IF.
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'RECONCILE_RESOLVE', 'ACCOUNT', ?, ?, 'SUCCESS' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-2
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            CALL "SQL_COMMIT"
            MOVE "SUCCESS|EXCEPTION_RESOLVED" TO LS-OUTPUT-BUFFER
            EXIT PARAGRAPH.

        VALIDATE-RESOLVE-NOTE.
            *> Notes use the safe alphabet (letters, digits, space, -/_/.).
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-P3-LEN
                EVALUATE TRUE
                    WHEN WS-PARAM3-TRIMMED(WS-I:1) >= "a" AND WS-PARAM3-TRIMMED(WS-I:1) <= "z"
                        CONTINUE
                    WHEN WS-PARAM3-TRIMMED(WS-I:1) >= "A" AND WS-PARAM3-TRIMMED(WS-I:1) <= "Z"
                        CONTINUE
                    WHEN WS-PARAM3-TRIMMED(WS-I:1) >= "0" AND WS-PARAM3-TRIMMED(WS-I:1) <= "9"
                        CONTINUE
                    WHEN WS-PARAM3-TRIMMED(WS-I:1) = " " OR WS-PARAM3-TRIMMED(WS-I:1) = "-" OR WS-PARAM3-TRIMMED(WS-I:1) = "_" OR WS-PARAM3-TRIMMED(WS-I:1) = "."
                        CONTINUE
                    WHEN OTHER
                        SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                END-EVALUATE
            END-PERFORM.
            EXIT PARAGRAPH.

        LOCK-ACCOUNTS.
            *> Lock both account rows in ascending id order in a single read.
            *> Uses the no-fetch prepared variant: the rows are not read (which
            *> would raise MariaDB ER_CHECKREAD under contention).
            MOVE "SELECT account_id FROM accounts WHERE account_id IN (?, ?) ORDER BY account_id FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-SENDER-ACC TO WS-BIND-1
            MOVE WS-TARGET-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT hold_id FROM account_holds WHERE account_id IN (?, ?) AND state = 'PLACED' FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-SENDER-ACC TO WS-BIND-1
            MOVE WS-TARGET-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        TRANSFER-LOGIC.
            *> A transfer to the same account is meaningless.
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE "ERROR|SELF_TRANSFER" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> A user with several accounts (one per currency) must pin the
            *> currency; without a pin the account choice is ambiguous.
            IF WS-P5-LEN = 0
                MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) NOT = "ERROR"
                    IF WS-RESULT NOT = "0" AND WS-RESULT NOT = "1"
                        MOVE "ERROR|AMBIGUOUS_ACCOUNT" TO LS-OUTPUT-BUFFER
                        EXIT PARAGRAPH
                    END-IF
                END-IF
            END-IF
            IF WS-P6-LEN = 0
                MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM accounts a JOIN users u ON a.user_id = u.id WHERE u.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) NOT = "ERROR"
                    IF WS-RESULT NOT = "0" AND WS-RESULT NOT = "1"
                        MOVE "ERROR|AMBIGUOUS_ACCOUNT" TO LS-OUTPUT-BUFFER
                        EXIT PARAGRAPH
                    END-IF
                END-IF
            END-IF
            *> Housekeeping: bound the idempotency table. Intents older than the
            *> retention window (default 30 days, 0 disables) are moved to the
            *> archive, so the replay guarantee is a bounded window but history
            *> is preserved.
            MOVE SPACES TO WS-RET-STR
            CALL "env_or" USING BY REFERENCE "PENDING_RETENTION_DAYS" BY REFERENCE "30" BY REFERENCE WS-RET-STR
            IF WS-RET-STR(1:1) >= "1" AND WS-RET-STR(1:1) <= "9"
                MOVE SPACES TO WS-PREP-SQL
                STRING "INSERT IGNORE INTO pending_transactions_archive (id, txn_ref, from_email, to_email, amount, status, created_at, updated_at) SELECT id, txn_ref, from_email, to_email, amount, status, created_at, updated_at FROM pending_transactions WHERE created_at < DATE_SUB(NOW(), INTERVAL " WS-RET-STR " DAY)" DELIMITED BY SIZE INTO WS-PREP-SQL
                END-STRING
                CALL "SET_QUERY" USING BY REFERENCE WS-PREP-SQL
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                MOVE SPACES TO WS-PREP-SQL
                STRING "DELETE FROM pending_transactions WHERE created_at < DATE_SUB(NOW(), INTERVAL " WS-RET-STR " DAY)" DELIMITED BY SIZE INTO WS-PREP-SQL
                END-STRING
                CALL "SET_QUERY" USING BY REFERENCE WS-PREP-SQL
                CALL "SQL_EXECUTE"
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            END-IF
            SET WS-TRANSFER-OK TO TRUE
            PERFORM VALIDATE-AMOUNT
            IF WS-TRANSFER-FAIL-AMOUNT
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> The idempotency key (param 4) doubles as the transaction
            *> reference. Without one, mint a collision-resistant reference
            *> (date+time to hundredths, plus a secure random suffix).
            IF LS-PARAM4 NOT = SPACES
                MOVE WS-PARAM4-TRIMMED(1:WS-P4-LEN) TO WS-REF
                MOVE WS-P4-LEN TO WS-REFLEN
            ELSE
                MOVE FUNCTION CURRENT-DATE TO WS-NOW
                MOVE SPACES TO WS-TXN-REF
                CALL "generate_random_code" USING BY REFERENCE WS-RAND
                STRING "TXN" WS-NOW(1:16) WS-RAND(1:6) DELIMITED BY SIZE INTO WS-TXN-REF
                END-STRING
                MOVE WS-TXN-REF TO WS-REF
                MOVE 25 TO WS-REFLEN
            END-IF
            
            CALL "SQL_BEGIN"
            
            *> Replay: a persisted reference for THIS sender, recipient and
            *> amount means the transfer already committed. A reference that
            *> exists with different details (or belongs to someone else) is a
            *> conflict, not a silent success.
            IF LS-PARAM4 NOT = SPACES
                MOVE "SELECT from_email, to_email, CONCAT(amount), status FROM pending_transactions WHERE txn_ref = ? AND from_email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT NOT = "ERROR|NO_DATA"
                    IF WS-RESULT(1:5) = "ERROR"
                        SET WS-TRANSFER-FAIL-DB TO TRUE
                    ELSE
                        UNSTRING WS-RESULT DELIMITED BY "|"
                            INTO WS-INTENT-FROM WS-INTENT-TO WS-INTENT-AMT WS-INTENT-STATUS
                        END-UNSTRING
                        MOVE WS-INTENT-AMT TO WS-PARSE-SRC
                        PERFORM PARSE-MAJOR
                        MOVE WS-PARSE-NUM TO WS-INTENT-AMOUNT-NUM
                        MOVE WS-PARAM3-TRIMMED TO WS-PARSE-SRC
                        PERFORM PARSE-MAJOR
                        MOVE WS-PARSE-NUM TO WS-AMOUNT-NUM
                        IF WS-INTENT-FROM(1:WS-P1-LEN) = WS-PARAM1-TRIMMED(1:WS-P1-LEN)
                           AND WS-INTENT-TO(1:WS-P2-LEN) = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                           AND WS-INTENT-AMOUNT-NUM = WS-AMOUNT-NUM
                            IF WS-INTENT-STATUS(1:9) = "COMMITTED"
                                CALL "SQL_COMMIT"
                                MOVE "SUCCESS|TRANSFER_OK" TO LS-OUTPUT-BUFFER
                                EXIT PARAGRAPH
                            ELSE
                                SET WS-TRANSFER-FAIL-IDEMP TO TRUE
                            END-IF
                        ELSE
                            SET WS-TRANSFER-FAIL-CONFLICT TO TRUE
                        END-IF
                    END-IF
                END-IF

                *> Record the intent; a duplicate key means another attempt is running.
                IF WS-TRANSFER-OK
                    MOVE "INSERT INTO pending_transactions (txn_ref, from_email, to_email, amount, status) VALUES (?, ?, ?, ?, 'PENDING')" TO WS-PREP-SQL
                    MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                    MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                    MOVE WS-PARAM2-TRIMMED TO WS-BIND-3
                    MOVE WS-PARAM3-TRIMMED TO WS-BIND-4
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-4
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                    IF WS-RESULT(1:5) = "ERROR"
                        SET WS-TRANSFER-FAIL-IDEMP TO TRUE
                    END-IF
                END-IF
            END-IF

            *> Resolve the sender account (no lock yet). p5 optionally pins the
            *> sender's currency when the user holds several accounts.
            IF WS-P5-LEN > 0
                MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.user_id AS CHAR), CAST(a.currency_id AS CHAR), a.status, CAST(c.is_active AS CHAR), CAST(c.prec_val AS CHAR), c.iso_code FROM accounts a JOIN users u ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ? AND c.iso_code = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                MOVE WS-PARAM5-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
            ELSE
                MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.user_id AS CHAR), CAST(a.currency_id AS CHAR), a.status, CAST(c.is_active AS CHAR), CAST(c.prec_val AS CHAR), c.iso_code FROM accounts a JOIN users u ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
            END-IF
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            
            IF WS-RESULT = "ERROR|NO_DATA"
                SET WS-TRANSFER-FAIL-SENDER TO TRUE
            ELSE
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                ELSE
                    UNSTRING WS-RESULT DELIMITED BY "|"
                        INTO WS-SENDER-ACC WS-SENDER-USER WS-SENDER-CUR
                             WS-SENDER-STATUS WS-SENDER-CURACTIVE WS-SENDER-PREC
                             WS-SENDER-ISO
                    END-UNSTRING
                END-IF
            END-IF
            
            *> The sender's account must be ACTIVE and its currency enabled.
            IF WS-TRANSFER-OK
                IF WS-SENDER-STATUS NOT = "ACTIVE"
                    IF WS-SENDER-STATUS(1:6) = "FROZEN"
                        SET WS-TRANSFER-FAIL-FROZEN TO TRUE
                    ELSE
                        SET WS-TRANSFER-FAIL-CLOSED TO TRUE
                    END-IF
                END-IF
            END-IF
            
            IF WS-TRANSFER-OK
                IF WS-SENDER-CURACTIVE NOT = "1"
                    SET WS-TRANSFER-FAIL-CURINACT TO TRUE
                END-IF
            END-IF
            
            *> Resolve the target account (no lock yet). p6 optionally pins the
            *> target's currency when the recipient holds several accounts.
            IF WS-TRANSFER-OK
                IF WS-P6-LEN > 0
                    MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.currency_id AS CHAR), a.status, CAST(c.is_active AS CHAR), CAST(c.prec_val AS CHAR), c.iso_code FROM accounts a JOIN users u ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ? AND c.iso_code = ? LIMIT 1" TO WS-PREP-SQL
                    MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                    MOVE WS-PARAM6-TRIMMED TO WS-BIND-2
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                        BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                ELSE
                    MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.currency_id AS CHAR), a.status, CAST(c.is_active AS CHAR), CAST(c.prec_val AS CHAR), c.iso_code FROM accounts a JOIN users u ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ?" TO WS-PREP-SQL
                    MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                END-IF
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT = "ERROR|NO_DATA"
                    SET WS-TRANSFER-FAIL-TARGET TO TRUE
                ELSE
                    IF WS-RESULT(1:5) = "ERROR"
                        SET WS-TRANSFER-FAIL-DB TO TRUE
                    ELSE
                        UNSTRING WS-RESULT DELIMITED BY "|"
                            INTO WS-TARGET-ACC WS-TARGET-CUR
                                 WS-TARGET-STATUS WS-TARGET-CURACTIVE WS-TARGET-PREC
                        END-UNSTRING
                    END-IF
                END-IF
            END-IF
            
            *> The target's account must be ACTIVE and its currency enabled.
            IF WS-TRANSFER-OK
                IF WS-TARGET-STATUS NOT = "ACTIVE"
                    IF WS-TARGET-STATUS(1:6) = "FROZEN"
                        SET WS-TRANSFER-FAIL-FROZEN TO TRUE
                    ELSE
                        SET WS-TRANSFER-FAIL-CLOSED TO TRUE
                    END-IF
                END-IF
            END-IF
            
            IF WS-TRANSFER-OK
                IF WS-TARGET-CURACTIVE NOT = "1"
                    SET WS-TRANSFER-FAIL-CURINACT TO TRUE
                END-IF
            END-IF

            *> Precision gate: the amount must fit the sender currency, and
            *> both precisions must be storable. prec_val beyond 4 has no
            *> exact DECIMAL(18,4) representation, so transfers refuse
            *> fail-closed instead of rounding silently.
            IF WS-TRANSFER-OK
                COMPUTE WS-PREC-NUM = FUNCTION NUMVAL(WS-SENDER-PREC)
            END-IF.
            IF WS-TRANSFER-OK AND WS-PREC-NUM < 0
                SET WS-TRANSFER-FAIL-CURINACT TO TRUE
            END-IF.
            IF WS-TRANSFER-OK AND WS-PREC-NUM > 4
                SET WS-TRANSFER-FAIL-CURINACT TO TRUE
            END-IF.
            IF WS-TRANSFER-OK AND WS-AMT-FRAC > WS-PREC-NUM
                SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
            END-IF.
            IF WS-TRANSFER-OK
                COMPUTE WS-PREC-NUM = FUNCTION NUMVAL(WS-TARGET-PREC)
            END-IF.
            IF WS-TRANSFER-OK AND WS-PREC-NUM < 0
                SET WS-TRANSFER-FAIL-CURINACT TO TRUE
            END-IF.
            IF WS-TRANSFER-OK AND WS-PREC-NUM > 4
                SET WS-TRANSFER-FAIL-CURINACT TO TRUE
            END-IF.
            IF WS-TRANSFER-OK
                PERFORM LOOKUP-TRANSFER-FEE
            END-IF.

            *> Lock both account rows in one statement, ordered by id, so two
            *> opposing transfers cannot deadlock (and MariaDB does not hit the
            *> two-statement ER_CHECKREAD).
            IF WS-TRANSFER-OK
                PERFORM LOCK-ACCOUNTS
            END-IF
            
            *> Expire stale holds, then read the spendable (available) balance:
            *> ledger balance minus live PLACED holds, at full precision.
            IF WS-TRANSFER-OK
                MOVE "UPDATE account_holds SET state = 'EXPIRED' WHERE account_id = ? AND state = 'PLACED' AND expires_at IS NOT NULL AND expires_at <= NOW()" TO WS-PREP-SQL
                MOVE WS-SENDER-ACC TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
            END-IF.
            IF WS-TRANSFER-OK AND WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-OK
                MOVE "SELECT CONCAT(balance - COALESCE((SELECT SUM(amount) FROM account_holds WHERE account_id = ? AND state = 'PLACED' AND (expires_at IS NULL OR expires_at > NOW())),0)) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-SENDER-ACC TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT = "ERROR|NO_DATA"
                    SET WS-TRANSFER-FAIL-SENDER TO TRUE
                ELSE
                    IF WS-RESULT(1:5) = "ERROR"
                        SET WS-TRANSFER-FAIL-DB TO TRUE
                    ELSE
                        MOVE WS-RESULT TO WS-SENDER-BAL
                    END-IF
                END-IF
            END-IF
            
            *> Cross-currency: look up the rate (base = sender, target = target).
            *> Same currency uses a rate of 1. If only the inverse pair exists,
            *> use its reciprocal.
            IF WS-TRANSFER-OK
                MOVE "1" TO WS-RATE-STR
                IF WS-SENDER-CUR NOT = WS-TARGET-CUR
                    MOVE "SELECT CAST(exchange_rate AS CHAR) FROM exchange_rates WHERE base_currency_id = ? AND target_currency_id = ? LIMIT 1" TO WS-PREP-SQL
                    MOVE WS-SENDER-CUR TO WS-BIND-1
                    MOVE WS-TARGET-CUR TO WS-BIND-2
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                        BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                    IF WS-RESULT = "ERROR|NO_DATA"
                        *> Fall back to the inverse pair, if any. The reciprocal
                        *> must carry enough precision that the credited amount
                        *> is exact at the target currency's precision even at
                        *> scale, so it is scaled explicitly (a plain ROUND to 6
                        *> decimals over-credits by ~0.5%).
                        MOVE "SELECT CAST(CAST(1 AS DECIMAL(30,20)) / exchange_rate AS DECIMAL(30,18)) FROM exchange_rates WHERE base_currency_id = ? AND target_currency_id = ? LIMIT 1" TO WS-PREP-SQL
                        MOVE WS-TARGET-CUR TO WS-BIND-1
                        MOVE WS-SENDER-CUR TO WS-BIND-2
                        CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                            BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                            BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                        CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                        IF WS-RESULT = "ERROR|NO_DATA"
                            SET WS-TRANSFER-FAIL-CURR TO TRUE
                        ELSE
                            IF WS-RESULT(1:5) = "ERROR"
                                SET WS-TRANSFER-FAIL-DB TO TRUE
                            ELSE
                                MOVE WS-RESULT TO WS-RATE-STR
                            END-IF
                        END-IF
                    ELSE
                        IF WS-RESULT(1:5) = "ERROR"
                            SET WS-TRANSFER-FAIL-DB TO TRUE
                        ELSE
                            MOVE WS-RESULT TO WS-RATE-STR
                        END-IF
                    END-IF
                END-IF
            END-IF
            
            *> Amount must be positive, and the sender must be able to cover it.
            IF WS-TRANSFER-OK
                MOVE WS-PARAM3-TRIMMED TO WS-PARSE-SRC
                PERFORM PARSE-MAJOR
                MOVE WS-PARSE-NUM TO WS-AMOUNT-NUM
                IF WS-AMOUNT-NUM <= 0
                    SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                END-IF
            END-IF
            
            *> Optional per-transaction limit, in whole units of the sender
            *> currency; 0 disables it. A non-numeric setting fails closed.
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-MAX-TXN-STR
                CALL "env_or_raw" USING BY REFERENCE "TRANSFER_MAX_PER_TXN" BY REFERENCE "0" BY REFERENCE WS-MAX-TXN-STR
                MOVE WS-MAX-TXN-STR TO WS-CAP-SRC
                PERFORM CHECK-CAP-DIGITS
            END-IF.
            IF WS-TRANSFER-OK AND WS-CAP-OK = "N"
                SET WS-TRANSFER-FAIL-LIMIT TO TRUE
            END-IF.
            IF WS-TRANSFER-OK AND WS-CAP-OK = "Y"
                MOVE WS-MAX-TXN-STR TO WS-PARSE-SRC
                PERFORM PARSE-MAJOR
                MOVE WS-PARSE-NUM TO WS-MAX-TXN-NUM
            END-IF.
            IF WS-TRANSFER-OK AND WS-MAX-TXN-NUM > 0 AND WS-AMOUNT-NUM > WS-MAX-TXN-NUM
                SET WS-TRANSFER-FAIL-LIMIT TO TRUE
            END-IF.
            
            *> Optional rolling 24h debit limit per account, in whole units of
            *> the sender currency; 0 disables it.
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-DAILY-LIMIT-STR
                CALL "env_or_raw" USING BY REFERENCE "TRANSFER_DAILY_LIMIT" BY REFERENCE "0" BY REFERENCE WS-DAILY-LIMIT-STR
                MOVE WS-DAILY-LIMIT-STR TO WS-CAP-SRC
                PERFORM CHECK-CAP-DIGITS
            END-IF.
            IF WS-TRANSFER-OK AND WS-CAP-OK = "N"
                SET WS-TRANSFER-FAIL-DAILY TO TRUE
            END-IF.
            IF WS-TRANSFER-OK AND WS-CAP-OK = "Y"
                MOVE WS-DAILY-LIMIT-STR TO WS-PARSE-SRC
                PERFORM PARSE-MAJOR
                MOVE WS-PARSE-NUM TO WS-DAILY-LIMIT-NUM
            END-IF.
            IF WS-TRANSFER-OK AND WS-DAILY-LIMIT-NUM > 0
                PERFORM CHECK-DAILY-TOTAL
            END-IF.
            
            IF WS-TRANSFER-OK
                MOVE WS-SENDER-BAL TO WS-PARSE-SRC
                PERFORM PARSE-MAJOR
                MOVE WS-PARSE-NUM TO WS-BALANCE-NUM
                IF WS-BALANCE-NUM < WS-AMOUNT-NUM + WS-FEE-NUM
                    SET WS-TRANSFER-FAIL-INSUF TO TRUE
                END-IF
            END-IF
            
            *> Open the journal header for this posting: one row per transfer
            *> with source, reference, and initiator. Legs and audit rows
            *> below point at it through the connection-scoped @jid.
            IF WS-TRANSFER-OK
                MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'TRANSFER', ?)" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF.
            IF WS-TRANSFER-OK
                MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF.
            *> Debit sender, rounded to its currency precision.
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-PREP-SQL
                STRING "UPDATE accounts SET balance = balance - ROUND(?, " WS-SENDER-PREC(1:1) ") WHERE account_id = ?" DELIMITED BY SIZE INTO WS-PREP-SQL
                END-STRING
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-2
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Credit target (converted to its currency, at its precision).
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-PREP-SQL
                STRING "UPDATE accounts SET balance = balance + ROUND(? * ?, " WS-TARGET-PREC(1:1) ") WHERE account_id = ?" DELIMITED BY SIZE INTO WS-PREP-SQL
                END-STRING
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
                MOVE WS-RATE-STR TO WS-BIND-2
                MOVE WS-TARGET-ACC TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Immutable ledger entries: one DEBIT, one CREDIT, same txn_ref.
            *> The CREDIT row snapshots the applied rate.
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-PREP-SQL
                STRING "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ROUND(?, " WS-SENDER-PREC(1:1) "), 'DEBIT', ?, 'Transfer out', 1, @jid, ?)" DELIMITED BY SIZE INTO WS-PREP-SQL
                END-STRING
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-3
                MOVE WS-SENDER-CUR TO WS-BIND-4
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-5
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-PREP-SQL
                STRING "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ROUND(? * ?, " WS-TARGET-PREC(1:1) "), 'CREDIT', ?, 'Transfer in', ?, @jid, ?)" DELIMITED BY SIZE INTO WS-PREP-SQL
                END-STRING
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-TARGET-ACC TO WS-BIND-2
                MOVE WS-PARAM3-TRIMMED TO WS-BIND-3
                MOVE WS-RATE-STR TO WS-BIND-4
                MOVE WS-TARGET-CUR TO WS-BIND-5
                MOVE WS-RATE-STR TO WS-BIND-6
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-7
                CALL "SQL_PREPARE_EXEC7" USING BY REFERENCE WS-PREP-SQL BY VALUE 7
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                    BY REFERENCE WS-BIND-7
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Audit the movement inside the same transaction, with context.
            IF WS-TRANSFER-OK
                MOVE SPACES TO WS-DETAIL
                STRING WS-PARAM2-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE
                       WS-PARAM3-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE
                       WS-SENDER-ISO DELIMITED BY SPACE
                       INTO WS-DETAIL
                END-STRING
                MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status, detail, journal_id) VALUES (?, 'TRANSFER', 'ACCOUNT', ?, 'SUCCESS', ?, @jid)" TO WS-PREP-SQL
                MOVE WS-SENDER-USER TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                MOVE WS-DETAIL TO WS-BIND-3
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-3
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Mark the intent committed (the reference only persists on success).
            IF WS-TRANSFER-OK AND LS-PARAM4 NOT = SPACES
                MOVE "UPDATE pending_transactions SET status = 'COMMITTED' WHERE txn_ref = ?" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-1
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Every leg is written against the open journal; verify the
            *> journal balances before anything becomes durable.
            IF WS-TRANSFER-OK
                MOVE WS-TARGET-PREC TO WS-JV-PREC
                PERFORM VERIFY-JOURNAL-BALANCED
            END-IF.
            *> A configured fee posts as its own journal after the principal
            *> legs have balanced; the fee journal is verified the same way.
            IF WS-TRANSFER-OK AND WS-FEE-NUM > 0
                PERFORM POST-FEE-JOURNAL
            END-IF.
            *> Commit or roll back the whole movement.
            IF WS-TRANSFER-OK
                CALL "SQL_COMMIT"
                MOVE "SUCCESS|TRANSFER_OK" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK"
                IF WS-TRANSFER-FAIL-DB
                    PERFORM CHECK-TRANSIENT
                    IF WS-BUSY = "1"
                        MOVE "ERROR|DB_BUSY" TO LS-OUTPUT-BUFFER
                    ELSE
                        MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    END-IF
                ELSE
                    IF WS-TRANSFER-FAIL-CONFLICT
                        MOVE "ERROR|IDEMPOTENCY_CONFLICT" TO LS-OUTPUT-BUFFER
                    ELSE
                        IF WS-TRANSFER-FAIL-IDEMP
                            MOVE "ERROR|TRANSFER_IN_PROGRESS" TO LS-OUTPUT-BUFFER
                        ELSE
                            IF WS-TRANSFER-FAIL-AMOUNT
                                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                            ELSE
                                IF WS-TRANSFER-FAIL-CURR
                                    MOVE "ERROR|RATE_NOT_FOUND" TO LS-OUTPUT-BUFFER
                                ELSE
                                    IF WS-TRANSFER-FAIL-SENDER
                                        MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                                    ELSE
                                        IF WS-TRANSFER-FAIL-TARGET
                                            MOVE "ERROR|TARGET_NOT_FOUND" TO LS-OUTPUT-BUFFER
                                        ELSE
                                            IF WS-TRANSFER-FAIL-FROZEN
                                                MOVE "ERROR|ACCOUNT_FROZEN" TO LS-OUTPUT-BUFFER
                                            ELSE
                                                IF WS-TRANSFER-FAIL-CLOSED
                                                    MOVE "ERROR|ACCOUNT_CLOSED" TO LS-OUTPUT-BUFFER
                                                ELSE
                                                    IF WS-TRANSFER-FAIL-CURINACT
                                                        MOVE "ERROR|CURRENCY_INACTIVE" TO LS-OUTPUT-BUFFER
                                                    ELSE
                                                        IF WS-TRANSFER-FAIL-LIMIT
                                                            MOVE "ERROR|LIMIT_EXCEEDED" TO LS-OUTPUT-BUFFER
                                                        ELSE
                                                            IF WS-TRANSFER-FAIL-DAILY
                                                                MOVE "ERROR|DAILY_LIMIT_EXCEEDED" TO LS-OUTPUT-BUFFER
                                                            ELSE
                                                                MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                                                            END-IF
                                                        END-IF
                                                    END-IF
                                                END-IF
                                            END-IF
                                        END-IF
                                    END-IF
                                END-IF
                            END-IF
                        END-IF
                    END-IF
                END-IF
            END-IF.
            EXIT PARAGRAPH.
