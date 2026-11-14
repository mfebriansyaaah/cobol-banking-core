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
        01  WS-VEL-ACTION          PIC X(30) VALUE SPACES.
        01  WS-VEL-P1              PIC X(100) VALUE SPACES.
        01  WS-VEL-P2              PIC X(100) VALUE SPACES.
        01  WS-VEL-P3              PIC X(100) VALUE SPACES.
        01  WS-VEL-P4              PIC X(100) VALUE SPACES.
        01  WS-VEL-P5              PIC X(100) VALUE SPACES.
        01  WS-VEL-P6              PIC X(100) VALUE SPACES.
        01  WS-VEL-OUT             PIC X(16384) VALUE SPACES.
        01  WS-CALL-ACTION          PIC X(30) VALUE SPACES.
        01  WS-CALL-P1              PIC X(100) VALUE SPACES.
        01  WS-CALL-P2              PIC X(100) VALUE SPACES.
        01  WS-CALL-P3              PIC X(100) VALUE SPACES.
        01  WS-CALL-P4              PIC X(100) VALUE SPACES.
        01  WS-CALL-P5              PIC X(100) VALUE SPACES.
        01  WS-CALL-P6              PIC X(100) VALUE SPACES.
        01  WS-CALL-OUT             PIC X(16384) VALUE SPACES.
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
        COPY "wallet_audit.cpy".

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
                WHEN LS-CMD-ACTION(1:8) = "TRANSFER"
                    PERFORM TRANSFER-LOGIC
                WHEN LS-CMD-ACTION(1:13) = "CHECK_BALANCE"
                    PERFORM GET-BALANCE-LOGIC
                WHEN LS-CMD-ACTION(1:9) = "TX_STATUS"
                    PERFORM TRANSFER-STATUS-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        COPY "wallet_entry.cpy".


        ALLOW-READ.
            *> Sets WS-ALLOWED when the actor (p2) owns the target (p1) or is an admin.
            MOVE 0 TO WS-ALLOWED
            IF WS-PARAM1-TRIMMED(1:WS-P1-LEN) = WS-PARAM2-TRIMMED(1:WS-P2-LEN)
                MOVE 1 TO WS-ALLOWED
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF
            IF WS-ALLOWED NOT = 1
                MOVE WS-PARAM2-TRIMMED TO WS-DENIED-ACTOR
                MOVE WS-PARAM1-TRIMMED TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
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

        TRANSFER-STATUS-LOGIC.
            *> p1 = ref, p2 = actor. Owner or admin only.
            MOVE 0 TO WS-ALLOWED
            MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
            PERFORM LOOKUP-USER-ROLE
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            ELSE
                IF WS-ALLOWED = 1
                    STRING " ORDER BY p.id DESC LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL WITH POINTER WS-SQL-PTR
                    END-STRING
                    MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                ELSE
                    STRING " AND p.from_email = ? LIMIT 1" DELIMITED BY SIZE INTO WS-PREP-SQL WITH POINTER WS-SQL-PTR
                    END-STRING
                    MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                    MOVE WS-PARAM2-TRIMMED TO WS-BIND-2
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                END-IF
            END-IF
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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

        TRANSFER-LOGIC.
            *> JOIN (maint-07, ADR-0010): the body lives in
            *> wallet_transfer_core, which joins this transaction
            *> (zero BEGIN/COMMIT/ROLLBACK of its own). This paragraph
            *> owns the single transaction and finalizes it from the
            *> callee outcome. A caller-side commit failure maps to
            *> ERROR|DB_ERROR (the transient re-check cannot run
            *> after the CALL returns).
            CALL "SQL_BEGIN" END-CALL
            MOVE "WALLET_TRANSFER" TO WS-CALL-ACTION
            MOVE WS-PARAM1-TRIMMED TO WS-CALL-P1
            MOVE WS-PARAM2-TRIMMED TO WS-CALL-P2
            MOVE WS-PARAM3-TRIMMED TO WS-CALL-P3
            MOVE WS-PARAM4-TRIMMED TO WS-CALL-P4
            MOVE WS-PARAM5-TRIMMED TO WS-CALL-P5
            MOVE WS-PARAM6-TRIMMED TO WS-CALL-P6
            MOVE SPACES TO WS-CALL-OUT
            CALL "wallet_transfer_core" USING WS-CALL-ACTION WS-CALL-P1 WS-CALL-P2
                WS-CALL-P3 WS-CALL-P4 WS-CALL-P5 WS-CALL-P6 WS-CALL-OUT
            END-CALL
            IF WS-CALL-OUT(1:5) = "ERROR"
                CALL "SQL_ROLLBACK" END-CALL
            ELSE
                CALL "SQL_COMMIT" END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT NOT = "SUCCESS|COMMIT"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF
            MOVE WS-CALL-OUT TO LS-OUTPUT-BUFFER.
            EXIT PARAGRAPH.
