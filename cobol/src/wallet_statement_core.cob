        IDENTIFICATION DIVISION.
        PROGRAM-ID. wallet_statement_core.

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
        COPY "wallet_entry.cpy".
        COPY "wallet_audit.cpy".
        COPY "wallet_caps.cpy".

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
                WHEN LS-CMD-ACTION(1:9) = "STATEMENT"
                    PERFORM STATEMENT-LOGIC
                WHEN OTHER
                    MOVE 4 TO WS-EXIT-CODE
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

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
                MOVE WS-PARAM5-TRIMMED(1:10) TO WS-RLIMIT
            END-IF.
            IF WS-P6-LEN > 0
                MOVE WS-PARAM6-TRIMMED(1:10) TO WS-ROFFSET
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:30) TO WS-ST-OPEN
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ledger WHERE account_id = ? AND DATE(created_at) >= COALESCE(NULLIF(?, ''), DATE(created_at)) AND DATE(created_at) <= COALESCE(NULLIF(?, ''), DATE(created_at))" TO WS-PREP-SQL
            MOVE WS-ST-ACC TO WS-BIND-1
            MOVE WS-ST-FROM TO WS-BIND-2
            MOVE WS-ST-TO TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:20) TO WS-RTOTAL
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT REPLACE(FORMAT((? + COALESCE(SUM(CASE WHEN type = 'CREDIT' THEN amount ELSE 0 - amount END), 0)), " WS-ST-PREC(1:1) "), ',', '') FROM ledger WHERE account_id = ? AND DATE(created_at) >= COALESCE(NULLIF(?, ''), DATE(created_at)) AND DATE(created_at) <= COALESCE(NULLIF(?, ''), DATE(created_at))" DELIMITED BY SIZE INTO WS-PREP-SQL
            END-STRING
            MOVE WS-ST-OPEN TO WS-BIND-1
            MOVE WS-ST-ACC TO WS-BIND-2
            MOVE WS-ST-FROM TO WS-BIND-3
            MOVE WS-ST-TO TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE WS-RESULT(1:30) TO WS-ST-CLOSE
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
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
