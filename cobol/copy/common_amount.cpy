      *> Canonical amount parsing (numeric hardening, DOT convention).
      *> System-wide decimal separator is the dot: the gateway validates
      *> dot-only amounts (middleware/contract/validation.js), MySQL
      *> DECIMAL and JSON both use '.'. Every COBOL module compiles
      *> WITHOUT "DECIMAL-POINT IS COMMA", so FUNCTION NUMVAL and
      *> DISPLAY both mean dot. This copybook is the single place that
      *> turns external amount text into a storable number.
      *>
      *> Host contract: COPY this file in PROCEDURE DIVISION and declare
      *> in WORKING-STORAGE (names are part of the contract):
      *>   01 AMT-SRC PIC X(100) VALUE SPACES.  (input: caller moves
      *>                                        trimmed text here)
      *>   01 AMT-BUF PIC X(100) VALUE SPACES.  (scratch)
      *>   01 AMT-NUM PIC S9(16)V9(4) VALUE 0.  (output, major units)
      *>   01 AMT-BAD PIC 9 VALUE 0.            (output flag)
      *>       88 AMT-OK VALUE 0.
      *>       88 AMT-BAD-FLAG VALUE 1.
      *> Coverage: PARSE-AMOUNT is exercised by tests/cobol/
      *> amount_matrix.sh plus the wallet TRANSFER DB suite (HOLD and
      *> REVERSE share the paragraph through identical call sites).
       PARSE-AMOUNT.
           *> Lenient separator, strict shape: a dot decimal is canonical;
           *> a comma decimal is tolerated (normalized to a dot) because
           *> direct COBOL callers bypass the gateway. Mixed forms
           *> ("1,000.00"), thousands separators, signs beyond a single
           *> leading +/- and anything TEST-NUMVAL rejects fail closed
           *> (AMT-BAD-FLAG + zero), as does a value wider than
           *> S9(16)V9(4) (ON SIZE ERROR). Callers range-check the sign
           *> themselves (amounts are expected >= 0).
           *> Reset first: PARSE-AMOUNT runs repeatedly in one process
           *> (--serve mode, several parses per request), so a stale
           *> AMT-BAD/AMT-NUM from the previous call must never leak.
           MOVE 0 TO AMT-BAD
           MOVE 0 TO AMT-NUM
           MOVE AMT-SRC TO AMT-BUF
           INSPECT AMT-BUF REPLACING ALL "," BY "."
           IF FUNCTION TEST-NUMVAL(AMT-BUF) NOT = 0
               MOVE 1 TO AMT-BAD
               MOVE 0 TO AMT-NUM
           ELSE
               COMPUTE AMT-NUM = FUNCTION NUMVAL(AMT-BUF)
                   ON SIZE ERROR MOVE 1 TO AMT-BAD MOVE 0 TO AMT-NUM END-COMPUTE
           END-IF.
           EXIT PARAGRAPH.
