       IDENTIFICATION DIVISION.
       PROGRAM-ID. wallet_transfer_core.
      *> Wallet transfer engine (maint-07, ADR-0010): TRANSFER-LOGIC plus
      *> its 18 helpers, relocated from wallet_core. The owner keeps MAIN-
      *> LOGIC, the entry guards, the read actions, and the single
      *> transaction per transfer; this module joins that transaction
      *> (zero SQL_BEGIN/COMMIT/ROLLBACK of its own, exactly like the
      *> wallet -> fee/payment precedent) and never CALLs back into
      *> wallet_core. Entry validation/trim is shared via wallet_entry.cpy.
      *> Compiled with DECIMAL-POINT IS COMMA like the owner: PARSE-MAJOR
      *> and all NUMVAL/COMPUTE amount logic depend on it.
      *>
      *> Contract (internal CALL, pre-trimmed inputs like every module seam):
      *>   LS-PARAM1..6 = sender, recipient, amount, idempotency key,
      *>     sender-currency pin, recipient-currency pin.
      *>   The callee writes the final outcome (SUCCESS|TRANSFER_OK or the
      *>   exact ERROR mapping, decision table included) to LS-OUTPUT-BUFFER.
      *>   The caller commits on SUCCESS, rolls back on ERROR, and moves the
      *>   buffer verbatim. A caller-side commit failure maps to
      *>   ERROR|DB_ERROR (the transient re-check cannot run after return).

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
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
        01  WS-BUSY                PIC X(1) VALUE "0".
        01  WS-DETAIL              PIC X(255) VALUE SPACES.
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
       01  LS-CMD-ACTION           PIC X(30).
       01  LS-PARAM1               PIC X(100).
       01  LS-PARAM2               PIC X(100).
       01  LS-PARAM3               PIC X(100).
       01  LS-PARAM4               PIC X(100).
       01  LS-PARAM5               PIC X(100).
       01  LS-PARAM6               PIC X(100).
       01  LS-OUTPUT-BUFFER        PIC X(16384).

       PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2
           LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

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
               WHEN LS-CMD-ACTION(1:16) = "WALLET_TRANSFER"
                   PERFORM TRANSFER-LOGIC
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "wallet_entry.cpy".
        COPY "wallet_caps.cpy".

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
                    ADD 1 TO WS-AMT-DOTS END-ADD
                    MOVE "1" TO WS-AMT-SEEN-DOT
                ELSE
                    IF WS-PARAM3-TRIMMED(WS-I:1) >= "0"
                       AND WS-PARAM3-TRIMMED(WS-I:1) <= "9"
                        ADD 1 TO WS-AMT-DIGITS END-ADD
                        IF WS-AMT-SEEN-DOT = "1"
                            ADD 1 TO WS-AMT-FRAC END-ADD
                        END-IF
                    ELSE
                        SET WS-TRANSFER-FAIL-AMOUNT TO TRUE
                    END-IF
                END-IF
            END-PERFORM
            IF WS-AMT-DOTS > 1 OR WS-AMT-FRAC > 4 OR WS-AMT-DIGITS < 1
                OR WS-AMT-DIGITS > 18
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
            COMPUTE WS-PARSE-NUM = FUNCTION NUMVAL(WS-PARSE-BUF) END-COMPUTE
            EXIT PARAGRAPH.

        CHECK-RATE-STALE.
            *> Rate validity window D3, default 24h, fail closed.
            *> WS-RATE-UPDATED holds YYYY-MM-DD HH:MM:SS, compared
            *> as text against the cutoff timestamp.
            MOVE SPACES TO WS-RATE-AGE-STR
            CALL "env_or_raw" USING BY REFERENCE "RATE_MAX_AGE_SECONDS"
                BY REFERENCE "86400" BY REFERENCE WS-RATE-AGE-STR
            END-CALL
            MOVE WS-RATE-AGE-STR TO WS-CAP-SRC
            PERFORM CHECK-CAP-DIGITS
            IF WS-CAP-OK = "N"
                SET WS-TRANSFER-FAIL-DB TO TRUE
                EXIT PARAGRAPH
            END-IF
            MOVE SPACES TO WS-PREP-SQL
            STRING "SELECT CAST(DATE_SUB(NOW(), INTERVAL "
                DELIMITED BY SIZE WS-RATE-AGE-STR DELIMITED BY SPACE
                " SECOND) AS CHAR)" DELIMITED BY SIZE
                INTO WS-PREP-SQL
            END-STRING
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL
                BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-RATE-CUTOFF
            END-UNSTRING
            IF WS-RATE-UPDATED < WS-RATE-CUTOFF
                SET WS-TRANSFER-FAIL-STALE TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        COMPUTE-FX-RESIDUAL.
            *> D1: value residual of a cross-currency posting at 4dp ledger
            *> scale. E4 is the converted value at 4dp; the posted credit
            *> rounds it to the target precision. A nonzero difference books
            *> to the target currency's FX_PNL account; an exact posting
            *> skips silently, needing no FX account.
            MOVE "0" TO WS-FX-HAS
            IF WS-SENDER-CUR = WS-TARGET-CUR
                EXIT PARAGRAPH
            END-IF
            MOVE "SELECT CAST(ROUND(? * ?, ?) AS CHAR)" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-RATE-STR TO WS-BIND-2
            MOVE WS-TARGET-PREC TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-FX-CRED
            END-UNSTRING
            MOVE "SELECT CAST(ROUND(? * ?, 4) - ? AS CHAR)" TO WS-PREP-SQL
            MOVE WS-PARAM3-TRIMMED TO WS-BIND-1
            MOVE WS-RATE-STR TO WS-BIND-2
            MOVE WS-FX-CRED TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-FX-RES
            END-UNSTRING
            PERFORM CHECK-FX-ZERO
            IF WS-FX-HAS = "0"
                EXIT PARAGRAPH
            END-IF
            IF WS-FX-RES(1:1) = "-"
                MOVE WS-FX-RES(2:29) TO WS-FX-ABS
            ELSE
                MOVE WS-FX-RES TO WS-FX-ABS
            END-IF
            MOVE "SELECT CAST(a.account_id AS CHAR), c.iso_code FROM accounts a JOIN currencies c ON c.currency_id = a.currency_id WHERE a.currency_id = ? AND a.account_type = 'FX_PNL' AND a.status = 'ACTIVE' LIMIT 1" TO WS-PREP-SQL
            MOVE WS-TARGET-CUR TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                SET WS-TRANSFER-FAIL-DB TO TRUE
                EXIT PARAGRAPH
            END-IF
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
                EXIT PARAGRAPH
            END-IF
            UNSTRING WS-RESULT DELIMITED BY "|"
                INTO WS-FX-ACC WS-FX-ISO
            END-UNSTRING.
            EXIT PARAGRAPH.

        CHECK-FX-ZERO.
            *> Residual present unless every significant character is zero.
            MOVE "0" TO WS-FX-HAS
            PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 30
                IF WS-FX-RES(WS-I:1) NOT = SPACE
                    IF WS-FX-RES(WS-I:1) NOT = "0"
                        IF WS-FX-RES(WS-I:1) NOT = "."
                            IF WS-FX-RES(WS-I:1) NOT = "-"
                                MOVE "1" TO WS-FX-HAS
                            END-IF
                        END-IF
                    END-IF
                END-IF
            END-PERFORM.
            EXIT PARAGRAPH.

        CHECK-PAYMENT-POLICY.
            *> Owner-configured policy is enforced after the environment
            *> caps. No policy row means no additional restriction. The
            *> unified verdict also covers per-user overrides and velocity:
            *> a VELOCITY block maps to the daily failure like the other
            *> window limits (the precise reason stays in PAY_CHECK output).
            MOVE "PAY_ENFORCE" TO WS-PAY-ACTION
            MOVE WS-PARAM1-TRIMMED TO WS-PAY-ACTOR
            MOVE SPACES TO WS-PAY-OUT
            CALL "payment_core" USING WS-PAY-ACTION WS-PARAM1-TRIMMED
                WS-SENDER-ISO WS-PARAM3-TRIMMED WS-PARAM4-TRIMMED
                WS-PARAM5-TRIMMED WS-PAY-ACTOR WS-PAY-OUT
            END-CALL
            IF WS-PAY-OUT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            ELSE
                IF WS-PAY-OUT(1:27) = "SUCCESS|PAY_ENFORCE|BLOCKED"
                    IF WS-PAY-OUT(28:10) = "|PER_TXN"
                        SET WS-TRANSFER-FAIL-LIMIT TO TRUE
                    ELSE
                        SET WS-TRANSFER-FAIL-DAILY TO TRUE
                    END-IF
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        RECORD-VELOCITY-USAGE.
            *> Every transfer that passes the limit checks advances the
            *> sender's velocity counters for the sender currency. The
            *> recorder joins this transaction (no BEGIN/COMMIT of its
            *> own), so a record failure rolls the money back with it
            *> instead of leaving counters behind the ledger.
            MOVE "VEL_RECORD_ALL_TXN" TO WS-VEL-ACTION
            MOVE WS-PARAM1-TRIMMED TO WS-VEL-P1
            MOVE WS-SENDER-ISO TO WS-VEL-P2
            MOVE WS-PARAM3-TRIMMED TO WS-VEL-P3
            MOVE SPACES TO WS-VEL-P4 WS-VEL-P5 WS-VEL-P6 WS-VEL-OUT
            CALL "fee_core" USING WS-VEL-ACTION WS-VEL-P1 WS-VEL-P2
                WS-VEL-P3 WS-VEL-P4 WS-VEL-P5 WS-VEL-P6 WS-VEL-OUT
            END-CALL
            IF WS-VEL-OUT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        CHECK-DAILY-TOTAL.
            *> Rolling 24h debit total, read at full stored precision and
            *> compared in major units — no fixed scaling.
            MOVE "SELECT CAST(COALESCE(SUM(l.amount),0) AS CHAR) FROM ledger l WHERE l.account_id = ? AND l.type = 'DEBIT' AND l.created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)" TO WS-PREP-SQL
            MOVE WS-SENDER-ACC TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            ELSE
                PERFORM RECORD-DAILY-TOTAL
            END-IF.
            EXIT PARAGRAPH.

        RECORD-DAILY-TOTAL.
            *> Comparison kept in its own paragraph so each branch above is
            *> one sentence per the inline-scope rule.
            MOVE WS-RESULT(1:30) TO WS-PRIOR-TOTAL-STR
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
            MOVE WS-RESULT(1:20) TO WS-INCOME-ACC
            MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'FEE', ?)" TO WS-PREP-SQL
            MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
            MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-FAIL-DB
                EXIT PARAGRAPH
            END-IF.
            MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
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
            MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ?" TO WS-PREP-SQL
            MOVE WS-FEE-STR TO WS-BIND-1
            MOVE WS-SENDER-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        POST-FX-RESIDUAL.
            *> D1: value residual of a cross-currency posting. A gain
            *> (credit rounded down) credits the target currency's FX_PNL
            *> account; a loss (rounded up) debits it. The CHECK constraint
            *> on balances fails a loss the account cannot cover, closed.
            IF WS-FX-RES(1:1) = "-"
                MOVE "UPDATE accounts SET balance = balance - ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-FX-ABS TO WS-BIND-1
                MOVE WS-FX-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                    BY REFERENCE WS-BIND-5
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                    EXIT PARAGRAPH
                END-IF
                MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'DEBIT', ?, 'FX loss', 1, @jid, ?)" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-FX-ACC TO WS-BIND-2
                MOVE WS-FX-ABS TO WS-BIND-3
                MOVE WS-TARGET-CUR TO WS-BIND-4
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-5
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                    EXIT PARAGRAPH
                END-IF
            ELSE
                MOVE "UPDATE accounts SET balance = balance + ? WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-FX-ABS TO WS-BIND-1
                MOVE WS-FX-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                    BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                    BY REFERENCE WS-BIND-5
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:18) NOT = "SUCCESS|AFFECTED_1"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                    EXIT PARAGRAPH
                END-IF
                MOVE "INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, exchange_rate, journal_id, from_email) VALUES (?, ?, ?, 'CREDIT', ?, 'FX gain', 1, @jid, ?)" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-FX-ACC TO WS-BIND-2
                MOVE WS-FX-ABS TO WS-BIND-3
                MOVE WS-TARGET-CUR TO WS-BIND-4
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-5
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5
                END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                    EXIT PARAGRAPH
                END-IF
            END-IF
            MOVE SPACES TO WS-DETAIL
            STRING WS-FX-ABS DELIMITED BY SPACE ":" DELIMITED BY SIZE
                   WS-FX-ISO DELIMITED BY SPACE
                   INTO WS-DETAIL
            END-STRING
            MOVE "INSERT INTO audit_trail (user_id, action, entity_type, entity_id, status, detail, journal_id) VALUES (?, 'FX', 'ACCOUNT', ?, 'SUCCESS', ?, @jid)" TO WS-PREP-SQL
            MOVE WS-SENDER-USER TO WS-BIND-1
            MOVE WS-FX-ACC TO WS-BIND-2
            MOVE WS-DETAIL TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        VERIFY-JOURNAL-FX-BALANCED.
            *> D1: three-leg principal journal with a residual. The sender
            *> debit converted at the snapshotted rate equals the
            *> target-side net (credit plus signed residual) at 4dp
            *> ledger scale, exactly: E4 = ROUND(D x R, 4) = C + S.
            MOVE "SELECT IF(COUNT(*)=3 AND SUM(type='DEBIT')>=1 AND SUM(type='CREDIT')>=1 AND ROUND(MAX(CASE WHEN description = 'Transfer out' THEN amount END) * MAX(CASE WHEN description = 'Transfer in' THEN exchange_rate END), 4) = SUM(CASE WHEN currency_id = ? THEN CASE WHEN type = 'CREDIT' THEN amount ELSE 0 - amount END END), 'BALANCED','UNBALANCED') FROM ledger WHERE journal_id = @jid" TO WS-PREP-SQL
            MOVE WS-TARGET-CUR TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2
                BY REFERENCE WS-BIND-3 BY REFERENCE WS-BIND-4
                BY REFERENCE WS-BIND-5
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT NOT = "BALANCED"
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

        LOCK-ACCOUNTS.
            *> Lock both account rows in ascending id order in a single read.
            *> Uses the no-fetch prepared variant: the rows are not read (which
            *> would raise MariaDB ER_CHECKREAD under contention).
            MOVE "SELECT account_id FROM accounts WHERE account_id IN (?, ?) ORDER BY account_id FOR UPDATE" TO WS-PREP-SQL
            MOVE WS-SENDER-ACC TO WS-BIND-1
            MOVE WS-TARGET-ACC TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_LOCK" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) NOT = "ERROR"
                    IF WS-RESULT NOT = "0" AND WS-RESULT NOT = "1"
                        MOVE "ERROR|AMBIGUOUS_ACCOUNT" TO LS-OUTPUT-BUFFER
                        EXIT PARAGRAPH
                    END-IF
                END-IF
            END-IF
            *> Retention of pending_transactions is an out-of-band EOD job
            *> (EODJOB_PENDING_PURGE). It must never run inside a money
            *> transaction: it locks idempotency rows and bloats the undo log.
            SET WS-TRANSFER-OK TO TRUE
            MOVE "0" TO WS-FX-HAS
            MOVE SPACES TO WS-FX-CRED
            MOVE SPACES TO WS-FX-RES
            MOVE SPACES TO WS-FX-ABS
            MOVE SPACES TO WS-FX-ACC
            MOVE SPACES TO WS-FX-ISO
            PERFORM VALIDATE-AMOUNT
            IF WS-TRANSFER-FAIL-AMOUNT
                MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF
            *> Risk-based KYC step-up (PR-089): transfers above 1,000,000 need
            *> an APPROVED sender; smaller verified transfers stay frictionless.
            *> Amounts parse via PARSE-MAJOR (this program compiles with
            *> DECIMAL-POINT IS COMMA, so a raw NUMVAL would read the dot as
            *> a thousands separator). Fail closed on lookup errors (money
            *> must not move on doubt).
            MOVE WS-PARAM3-TRIMMED TO WS-PARSE-SRC
            PERFORM PARSE-MAJOR
            IF WS-PARSE-NUM > 1000000
                MOVE "SELECT kyc_status FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                IF WS-RESULT NOT = "APPROVED"
                    MOVE "ERROR|KYC_REQUIRED" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
            END-IF
            *> The idempotency key (param 4) doubles as the transaction
            *> reference. Without one, mint a collision-resistant reference
            *> (date+time to hundredths, plus a secure random suffix).
            IF LS-PARAM4 NOT = SPACES
                IF WS-P4-LEN > 50
                    MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF
                MOVE WS-PARAM4-TRIMMED(1:WS-P4-LEN) TO WS-REF
                MOVE WS-P4-LEN TO WS-REFLEN
            ELSE
                MOVE FUNCTION CURRENT-DATE TO WS-NOW
                MOVE SPACES TO WS-TXN-REF
                CALL "generate_random_code" USING BY REFERENCE WS-RAND END-CALL
                STRING "TXN" WS-NOW(1:16) WS-RAND(1:6) DELIMITED BY SIZE INTO WS-TXN-REF
                END-STRING
                MOVE WS-TXN-REF TO WS-REF
                MOVE 25 TO WS-REFLEN
            END-IF
            
            *> (Transaction opened by the caller: ADR-0010 JOIN.)
            *> Replay: a persisted reference for THIS sender, recipient and
            *> amount means the transfer already committed. A reference that
            *> exists with different details (or belongs to someone else) is a
            *> conflict, not a silent success.
            IF LS-PARAM4 NOT = SPACES
                MOVE "SELECT from_email, to_email, CONCAT(amount), status FROM pending_transactions WHERE txn_ref = ? AND from_email = ? LIMIT 1" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                                *> Replay hit: the caller commits the (empty)
                                *> transaction and returns this outcome.
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
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            ELSE
                MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.user_id AS CHAR), CAST(a.currency_id AS CHAR), a.status, CAST(c.is_active AS CHAR), CAST(c.prec_val AS CHAR), c.iso_code FROM accounts a JOIN users u ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ?" TO WS-PREP-SQL
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
            END-IF
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            
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
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                ELSE
                    MOVE "SELECT CAST(a.account_id AS CHAR), CAST(a.currency_id AS CHAR), a.status, CAST(c.is_active AS CHAR), CAST(c.prec_val AS CHAR), c.iso_code FROM accounts a JOIN users u ON a.user_id = u.id JOIN currencies c ON c.currency_id = a.currency_id WHERE u.email = ?" TO WS-PREP-SQL
                    MOVE WS-PARAM2-TRIMMED TO WS-BIND-1
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                END-IF
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                
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
                COMPUTE WS-PREC-NUM = FUNCTION NUMVAL(WS-SENDER-PREC) END-COMPUTE
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
                COMPUTE WS-PREC-NUM = FUNCTION NUMVAL(WS-TARGET-PREC) END-COMPUTE
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
            *> Note: post-lock plain re-reads are not used here. Under READ
            *> COMMITTED (set in sql_bridge.c) the locked rows are read with
            *> SELECT ... FOR UPDATE if needed; the invariants below are also
            *> enforced by the guarded UPDATE in the posting step.
            
            *> Expire stale holds, then read the spendable (available) balance:
            *> ledger balance minus live PLACED holds, at full precision.
            IF WS-TRANSFER-OK
                MOVE "UPDATE account_holds SET state = 'EXPIRED' WHERE account_id = ? AND state = 'PLACED' AND expires_at IS NOT NULL AND expires_at <= NOW()" TO WS-PREP-SQL
                MOVE WS-SENDER-ACC TO WS-BIND-1
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            END-IF.
            IF WS-TRANSFER-OK AND WS-RESULT(1:5) = "ERROR"
                SET WS-TRANSFER-FAIL-DB TO TRUE
            END-IF.
            IF WS-TRANSFER-OK
                MOVE "SELECT CONCAT(balance - COALESCE((SELECT SUM(amount) FROM account_holds WHERE account_id = ? AND state = 'PLACED' AND (expires_at IS NULL OR expires_at > NOW())),0)) FROM accounts WHERE account_id = ?" TO WS-PREP-SQL
                MOVE WS-SENDER-ACC TO WS-BIND-1
                MOVE WS-SENDER-ACC TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT = "ERROR|NO_DATA"
                    SET WS-TRANSFER-FAIL-SENDER TO TRUE
                ELSE
                    IF WS-RESULT(1:5) = "ERROR"
                        SET WS-TRANSFER-FAIL-DB TO TRUE
                    ELSE
                        MOVE WS-RESULT(1:30) TO WS-SENDER-BAL
                    END-IF
                END-IF
            END-IF
            
            *> Cross-currency: look up the rate (base = sender, target = target).
            *> Same currency uses a rate of 1. If only the inverse pair exists,
            *> use its reciprocal.
            IF WS-TRANSFER-OK
                MOVE "1" TO WS-RATE-STR
                IF WS-SENDER-CUR NOT = WS-TARGET-CUR
                    MOVE "SELECT CAST(exchange_rate AS CHAR), CAST(updated_at AS CHAR) FROM exchange_rates WHERE base_currency_id = ? AND target_currency_id = ? LIMIT 1" TO WS-PREP-SQL
                    MOVE WS-SENDER-CUR TO WS-BIND-1
                    MOVE WS-TARGET-CUR TO WS-BIND-2
                    CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                        BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                        BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                    IF WS-RESULT = "ERROR|NO_DATA"
                        *> Fall back to the inverse pair, if any. The reciprocal
                        *> must carry enough precision that the credited amount
                        *> is exact at the target currency's precision even at
                        *> scale, so it is scaled explicitly (a plain ROUND to 6
                        *> decimals over-credits by ~0.5%).
                        MOVE "SELECT CAST(CAST(1 AS DECIMAL(30,20)) / exchange_rate AS DECIMAL(30,18)), CAST(updated_at AS CHAR) FROM exchange_rates WHERE base_currency_id = ? AND target_currency_id = ? LIMIT 1" TO WS-PREP-SQL
                        MOVE WS-TARGET-CUR TO WS-BIND-1
                        MOVE WS-SENDER-CUR TO WS-BIND-2
                        CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                            BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                            BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                        CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                        IF WS-RESULT = "ERROR|NO_DATA"
                            SET WS-TRANSFER-FAIL-CURR TO TRUE
                        ELSE
                            IF WS-RESULT(1:5) = "ERROR"
                                SET WS-TRANSFER-FAIL-DB TO TRUE
                            ELSE
                                UNSTRING WS-RESULT DELIMITED BY "|"
                                    INTO WS-RATE-STR WS-RATE-UPDATED
                                END-UNSTRING
                                PERFORM CHECK-RATE-STALE
                            END-IF
                        END-IF
                    ELSE
                        IF WS-RESULT(1:5) = "ERROR"
                            SET WS-TRANSFER-FAIL-DB TO TRUE
                        ELSE
                            UNSTRING WS-RESULT DELIMITED BY "|"
                                INTO WS-RATE-STR WS-RATE-UPDATED
                            END-UNSTRING
                            PERFORM CHECK-RATE-STALE
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
                CALL "env_or_raw" USING BY REFERENCE "TRANSFER_MAX_PER_TXN" BY REFERENCE "0" BY REFERENCE WS-MAX-TXN-STR END-CALL
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
                CALL "env_or_raw" USING BY REFERENCE "TRANSFER_DAILY_LIMIT" BY REFERENCE "0" BY REFERENCE WS-DAILY-LIMIT-STR END-CALL
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
            *> Check daily limit & payment policy inside locked transaction scope:
            IF WS-TRANSFER-OK AND WS-DAILY-LIMIT-NUM > 0
                PERFORM CHECK-DAILY-TOTAL
            END-IF.
            
            IF WS-TRANSFER-OK
                PERFORM CHECK-PAYMENT-POLICY
            END-IF.
            
            IF WS-TRANSFER-OK
                PERFORM RECORD-VELOCITY-USAGE
            END-IF.
            
            IF WS-TRANSFER-OK
                MOVE WS-SENDER-BAL TO WS-PARSE-SRC
                PERFORM PARSE-MAJOR
                MOVE WS-PARSE-NUM TO WS-BALANCE-NUM
                IF WS-BALANCE-NUM < WS-AMOUNT-NUM + WS-FEE-NUM
                    SET WS-TRANSFER-FAIL-INSUF TO TRUE
                END-IF
            END-IF

            *> D1: value residual of a cross-currency posting. Computed only
            *> once every other check passed; a nonzero residual books to
            *> the target currency's FX_PNL account inside the same journal.
            IF WS-TRANSFER-OK
                PERFORM COMPUTE-FX-RESIDUAL
            END-IF
            
            *> Open the journal header for this posting: one row per transfer
            *> with source, reference, and initiator. Legs and audit rows
            *> below point at it through the connection-scoped @jid.
            IF WS-TRANSFER-OK
                MOVE "INSERT INTO journal_entries (txn_ref, source, actor_email) VALUES (?, 'TRANSFER', ?)" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF.
            IF WS-TRANSFER-OK
                MOVE "SET @jid = LAST_INSERT_ID()" TO WS-PREP-SQL
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
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
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                
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
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                
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
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                
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
                    BY REFERENCE WS-BIND-7 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF

            *> D1: book a nonzero rounding residual to the target
            *> currency's FX_PNL account, inside the same journal.
            IF WS-TRANSFER-OK AND WS-FX-HAS = "1"
                PERFORM POST-FX-RESIDUAL
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
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                
                IF WS-RESULT(1:5) = "ERROR"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Mark the intent committed (the reference only persists on success).
            *> Scoped by the full idempotency key (txn_ref, from_email): the
            *> unscoped form full-scans the table and its gap locks collide
            *> with concurrent transfers. Exactly one row must flip; anything
            *> else means the receipt did not land, so fail closed instead of
            *> reporting a false SUCCESS (a retry after a false success would
            *> double-spend, as the replay check would find no row).
            IF WS-TRANSFER-OK AND LS-PARAM4 NOT = SPACES
                MOVE "UPDATE pending_transactions SET status = 'COMMITTED' WHERE txn_ref = ? AND from_email = ?" TO WS-PREP-SQL
                MOVE WS-REF(1:WS-REFLEN) TO WS-BIND-1
                MOVE WS-PARAM1-TRIMMED TO WS-BIND-2
                CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                    BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                    BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 END-CALL
                CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                IF WS-RESULT NOT = "SUCCESS|AFFECTED_1"
                    SET WS-TRANSFER-FAIL-DB TO TRUE
                END-IF
            END-IF
            
            *> Every leg is written against the open journal; verify the
            *> journal balances before anything becomes durable. A posted
            *> D1 residual makes three legs, verified at 4dp ledger scale.
            IF WS-TRANSFER-OK AND WS-FX-HAS = "1"
                PERFORM VERIFY-JOURNAL-FX-BALANCED
            END-IF.
            IF WS-TRANSFER-OK AND WS-FX-HAS = "0"
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
                *> (Transaction committed by the caller, which
                *> maps a commit failure to ERROR|DB_ERROR.)
                MOVE "SUCCESS|TRANSFER_OK" TO LS-OUTPUT-BUFFER
            ELSE
                IF WS-TRANSFER-FAIL-DB
                    PERFORM CHECK-TRANSIENT
                END-IF
            *> (Transaction rolled back by the caller.)
                *> Decision table: flags are mutually exclusive by construction;
                *> the first match wins. Order reflects business priority.
                EVALUATE TRUE
                    WHEN WS-TRANSFER-FAIL-DB AND WS-BUSY = "1"
                        MOVE "ERROR|DB_BUSY" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-DB
                        MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-CONFLICT
                        MOVE "ERROR|IDEMPOTENCY_CONFLICT" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-IDEMP
                        MOVE "ERROR|TRANSFER_IN_PROGRESS" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-AMOUNT
                        MOVE "ERROR|INVALID_AMOUNT" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-STALE
                        MOVE "ERROR|RATE_STALE" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-CURR
                        MOVE "ERROR|RATE_NOT_FOUND" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-SENDER
                        MOVE "ERROR|ACCOUNT_NOT_FOUND" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-TARGET
                        MOVE "ERROR|TARGET_NOT_FOUND" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-FROZEN
                        MOVE "ERROR|ACCOUNT_FROZEN" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-CLOSED
                        MOVE "ERROR|ACCOUNT_CLOSED" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-CURINACT
                        MOVE "ERROR|CURRENCY_INACTIVE" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-LIMIT
                        MOVE "ERROR|LIMIT_EXCEEDED" TO LS-OUTPUT-BUFFER
                    WHEN WS-TRANSFER-FAIL-DAILY
                        MOVE "ERROR|DAILY_LIMIT_EXCEEDED" TO LS-OUTPUT-BUFFER
                    WHEN OTHER
                        MOVE "ERROR|INSUFFICIENT_FUNDS" TO LS-OUTPUT-BUFFER
                END-EVALUATE
            END-IF.
            EXIT PARAGRAPH.
