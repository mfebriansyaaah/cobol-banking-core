       IDENTIFICATION DIVISION.
       PROGRAM-ID. import_core.
      *> Import/export foundation (Phase 1, Sprint 1 slice 3).
      *> Batch staging, row validation, correction, posting, and export.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RESULT               PIC X(16384) VALUE SPACES.
       01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
       01  WS-BIND-1               PIC X(256) VALUE SPACES.
       01  WS-BIND-2               PIC X(256) VALUE SPACES.
       01  WS-BIND-3               PIC X(256) VALUE SPACES.
       01  WS-BIND-4               PIC X(256) VALUE SPACES.
       01  WS-BIND-5               PIC X(256) VALUE SPACES.
       01  WS-BIND-6               PIC X(256) VALUE SPACES.
       01  WS-P1-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P2-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P3-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P4-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P5-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P6-TRIMMED           PIC X(100) VALUE SPACES.
       01  WS-P1-LEN               PIC 9(3) VALUE 1.
       01  WS-P2-LEN               PIC 9(3) VALUE 1.
       01  WS-P3-LEN               PIC 9(3) VALUE 1.
       01  WS-P4-LEN               PIC 9(3) VALUE 1.
       01  WS-P5-LEN               PIC 9(3) VALUE 1.
       01  WS-P6-LEN               PIC 9(3) VALUE 1.
       01  WS-TRIM-IN              PIC X(100) VALUE SPACES.
       01  WS-TRIM-OUT             PIC X(100) VALUE SPACES.
       01  WS-TRIM-LEN             PIC 9(3) VALUE 1.
       01  WS-I                    PIC 9(3) VALUE 1.
       01  WS-J                    PIC 9(5) VALUE 1.
       01  WS-RLEN                 PIC 9(5) VALUE 1.
       01  WS-BAD                  PIC 9(3) VALUE 0.
       01  WS-ALLOWED              PIC 9 VALUE 0.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-TOTAL                PIC X(100) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-LOOKUP-BAD           PIC 9 VALUE 0.
       01  WS-BATCH-ID             PIC X(20) VALUE SPACES.
       01  WS-BATCH-TYPE           PIC X(20) VALUE SPACES.
       01  WS-BATCH-STATUS         PIC X(20) VALUE SPACES.
       01  WS-BATCH-TOTAL          PIC X(20) VALUE SPACES.
       01  WS-BATCH-VALID          PIC X(20) VALUE SPACES.
       01  WS-BATCH-INVALID        PIC X(20) VALUE SPACES.
       01  WS-BATCH-POSTED         PIC X(20) VALUE SPACES.
       01  WS-BATCH-SOURCE         PIC X(100) VALUE SPACES.
       01  WS-ROW-ID               PIC X(20) VALUE SPACES.
       01  WS-ROW-STATUS           PIC X(20) VALUE SPACES.
       01  WS-ROW-ERR              PIC X(40) VALUE SPACES.
       01  WS-ROW-DETAIL           PIC X(255) VALUE SPACES.
       01  WS-RAW                  PIC X(100) VALUE SPACES.
       01  WS-F1                   PIC X(100) VALUE SPACES.
       01  WS-F2                   PIC X(100) VALUE SPACES.
       01  WS-F3                   PIC X(100) VALUE SPACES.
       01  WS-ACC                  PIC X(20) VALUE SPACES.
       01  WS-DR                   PIC X(30) VALUE SPACES.
       01  WS-CR                   PIC X(30) VALUE SPACES.
       01  WS-AT-COUNT             PIC 9(3) VALUE 0.
       01  WS-DR-ZERO              PIC 9 VALUE 1.
       01  WS-CR-ZERO              PIC 9 VALUE 1.
       01  WS-VALID-COUNT          PIC 9(9) VALUE 0.
       01  WS-INVALID-COUNT        PIC 9(9) VALUE 0.
       01  WS-CODE-IN              PIC X(100) VALUE SPACES.
       01  WS-CODE-LEN             PIC 9(3) VALUE 0.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-DEC-IN               PIC X(30) VALUE SPACES.
       01  WS-DEC-LEN              PIC 9(3) VALUE 0.
       01  WS-DOT-COUNT            PIC 9(3) VALUE 0.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-BATCH          PIC X(40) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-PART                 PIC X(16384) VALUE SPACES.
       01  WS-PART-LEN             PIC 9(5) VALUE 0.
       01  WS-OUT-POS              PIC 9(5) VALUE 1.
       01  WS-K                    PIC 9(3) VALUE 1.
       01  WS-ROW-INDEX            PIC 9(9) VALUE 0.
       01  WS-ROW-INDEX-ED         PIC Z(8)9 VALUE 0.
       01  WS-VALID-COUNT-ED       PIC Z(8)9 VALUE 0.
       01  WS-INVALID-COUNT-ED     PIC Z(8)9 VALUE 0.
       01  F-QUOTE                 PIC X VALUE "'".
       01  F-DQUOTE                PIC X VALUE '"'.
       01  F-BSLASH                PIC X VALUE "\".
       01  F-SEMI                  PIC X VALUE ";".
       01  F-TICK                  PIC X VALUE "`".

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
           PERFORM VALIDATE-ALL
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               GOBACK
           END-IF
           EVALUATE TRUE
               WHEN LS-CMD-ACTION(1:16) = "IMP_BATCH_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-CREATE
               WHEN LS-CMD-ACTION(1:14) = "IMP_BATCH_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-LIST
               WHEN LS-CMD-ACTION(1:13) = "IMP_BATCH_GET"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-GET
               WHEN LS-CMD-ACTION(1:18) = "IMP_BATCH_VALIDATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-VALIDATE
               WHEN LS-CMD-ACTION(1:14) = "IMP_BATCH_POST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-POST
               WHEN LS-CMD-ACTION(1:14) = "IMP_BATCH_FAIL"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-FAIL
               WHEN LS-CMD-ACTION(1:16) = "IMP_BATCH_EXPORT"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-EXPORT
               WHEN LS-CMD-ACTION(1:15) = "IMP_BATCH_CLONE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-CLONE
               WHEN LS-CMD-ACTION(1:16) = "IMP_BATCH_DELETE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-DELETE
               WHEN LS-CMD-ACTION(1:15) = "IMP_BATCH_RETRY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-RETRY
               WHEN LS-CMD-ACTION(1:17) = "IMP_BATCH_SUMMARY"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-BATCH-SUMMARY
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_trim.cpy".
        COPY "common_sql.cpy".
        COPY "common_validate.cpy".
        COPY "common_result.cpy".

       VALIDATE-ALL.
           MOVE 0 TO WS-BAD
           MOVE LS-PARAM1 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT
           MOVE LS-PARAM2 TO WS-TRIM-IN
           IF LS-CMD-ACTION(1:20) = "IMP_BATCH_STAGE_BULK"
               PERFORM VALIDATE-LINES
           ELSE
               PERFORM VALIDATE-INPUT
           END-IF
           MOVE LS-PARAM3 TO WS-TRIM-IN
           IF LS-CMD-ACTION(1:20) = "IMP_BATCH_STAGE_BULK"
               PERFORM VALIDATE-LINES
           ELSE
               PERFORM VALIDATE-INPUT
           END-IF
           MOVE LS-PARAM4 TO WS-TRIM-IN
           IF LS-CMD-ACTION(1:20) = "IMP_BATCH_STAGE_BULK"
               PERFORM VALIDATE-LINES
           ELSE
               PERFORM VALIDATE-INPUT
           END-IF
           MOVE LS-PARAM5 TO WS-TRIM-IN
           IF LS-CMD-ACTION(1:20) = "IMP_BATCH_STAGE_BULK"
               PERFORM VALIDATE-LINES
           ELSE
               PERFORM VALIDATE-INPUT
           END-IF
           MOVE LS-PARAM6 TO WS-TRIM-IN
           PERFORM VALIDATE-INPUT.
           EXIT PARAGRAPH.

       VALIDATE-INPUT.
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-QUOTE
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-DQUOTE
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-BSLASH
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-SEMI
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-TICK.
           EXIT PARAGRAPH.

       VALIDATE-LINES.
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-QUOTE
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-DQUOTE
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-BSLASH
           INSPECT WS-TRIM-IN TALLYING WS-BAD FOR ALL F-TICK.
           EXIT PARAGRAPH.

       VALIDATE-CODE-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-CODE-LEN
           PERFORM VARYING WS-I FROM 100 BY -1
               UNTIL WS-I < 1 OR WS-CODE-LEN > 0
               IF WS-CODE-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-CODE-LEN
               END-IF
           END-PERFORM
           IF WS-CODE-LEN < 1 OR WS-CODE-LEN > 40
               MOVE 1 TO WS-BAD
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-CODE-LEN
               IF WS-CODE-IN(WS-I:1) IS NOT ALPHABETIC
                  AND WS-CODE-IN(WS-I:1) IS NOT NUMERIC
                  AND WS-CODE-IN(WS-I:1) NOT = "_"
                  AND WS-CODE-IN(WS-I:1) NOT = "-"
                   MOVE 1 TO WS-BAD
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.

       VALIDATE-DECIMAL-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-DOT-COUNT
           MOVE 0 TO WS-DEC-LEN
           PERFORM VARYING WS-I FROM 30 BY -1
               UNTIL WS-I < 1 OR WS-DEC-LEN > 0
               IF WS-DEC-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-DEC-LEN
               END-IF
           END-PERFORM
           IF WS-DEC-LEN < 1 OR WS-DEC-LEN > 20
               MOVE 1 TO WS-BAD
           END-IF.
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-DEC-LEN
               IF WS-DEC-IN(WS-I:1) = "."
                   ADD 1 TO WS-DOT-COUNT END-ADD
               ELSE
                   IF WS-DEC-IN(WS-I:1) IS NOT NUMERIC
                       MOVE 1 TO WS-BAD
                   END-IF
               END-IF
           END-PERFORM.
           IF WS-DOT-COUNT > 1
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

        COPY "common_auth.cpy".

       AUDIT-IMPORT.
           MOVE "INSERT INTO import_audit (action, actor_email, batch_code, detail) VALUES (?, ?, NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-BATCH TO WS-BIND-3
           MOVE WS-AUDIT-DETAIL TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               SET STEP-FAIL TO TRUE
           END-IF.
           EXIT PARAGRAPH.

       AUDIT-DENIED.
           MOVE "AUTHZ_DENIED" TO WS-AUDIT-ACTION
           MOVE SPACES TO WS-AUDIT-BATCH
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT-IMPORT.
           EXIT PARAGRAPH.

       CHECK-BATCH.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-BATCH-ID WS-BATCH-TYPE WS-BATCH-STATUS
               WS-BATCH-TOTAL WS-BATCH-VALID WS-BATCH-INVALID
               WS-BATCH-POSTED WS-BATCH-SOURCE
           MOVE "SELECT CONCAT(id, '|', import_type, '|', status, '|', total_rows, '|', valid_rows, '|', invalid_rows, '|', posted_rows, '|', source_name) FROM import_batch WHERE batch_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE 1 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE 2 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           UNSTRING WS-RESULT DELIMITED BY "|" INTO
               WS-BATCH-ID WS-BATCH-TYPE WS-BATCH-STATUS
               WS-BATCH-TOTAL WS-BATCH-VALID WS-BATCH-INVALID
               WS-BATCH-POSTED WS-BATCH-SOURCE
           END-UNSTRING.
           EXIT PARAGRAPH.

       CHECK-ROW.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-ROW-ID WS-RAW
           MOVE "SELECT CONCAT(id, '|', raw_data) FROM import_row WHERE batch_id = ? AND row_no = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-BATCH-ID TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE 1 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE 2 TO WS-LOOKUP-BAD
               EXIT PARAGRAPH
           END-IF.
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-ROW-ID WS-RAW
           END-UNSTRING.
           EXIT PARAGRAPH.

       TRIM-PART.
           MOVE 0 TO WS-PART-LEN
           PERFORM VARYING WS-J FROM 16384 BY -1
               UNTIL WS-J < 1 OR WS-PART-LEN > 0
               IF WS-PART(WS-J:1) NOT = SPACE
                   MOVE WS-J TO WS-PART-LEN
               END-IF
           END-PERFORM.
           EXIT PARAGRAPH.

       VALIDATE-IMPORT-ROW.
           MOVE SPACES TO WS-ROW-STATUS WS-ROW-ERR WS-ROW-DETAIL
           IF WS-RAW = SPACES
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "EMPTY_ROW" TO WS-ROW-ERR
               MOVE "raw row is empty" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           EVALUATE WS-BATCH-TYPE
               WHEN "LEDGER"
                   PERFORM VALIDATE-LEDGER-ROW
               WHEN "ACCOUNTS"
                   PERFORM VALIDATE-ACCOUNTS-ROW
               WHEN "REFERENCE"
                   PERFORM VALIDATE-REFERENCE-ROW
               WHEN "PAYMENTS"
                   PERFORM VALIDATE-PAYMENTS-ROW
               WHEN OTHER
                   MOVE "INVALID" TO WS-ROW-STATUS
                   MOVE "UNKNOWN_TYPE" TO WS-ROW-ERR
                   MOVE "batch type is not supported" TO WS-ROW-DETAIL
           END-EVALUATE.
           EXIT PARAGRAPH.

       VALIDATE-LEDGER-ROW.
           MOVE SPACES TO WS-ACC WS-DR WS-CR
           UNSTRING WS-RAW DELIMITED BY ":" INTO WS-ACC WS-DR WS-CR
           END-UNSTRING
           IF WS-ACC = SPACES OR WS-DR = SPACES OR WS-CR = SPACES
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_FORMAT" TO WS-ROW-ERR
               MOVE "expected account:debit:credit" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-DR TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_AMOUNT" TO WS-ROW-ERR
               MOVE "debit is not decimal" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-CR TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_AMOUNT" TO WS-ROW-ERR
               MOVE "credit is not decimal" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE 1 TO WS-DR-ZERO WS-CR-ZERO
           PERFORM VARYING WS-K FROM 1 BY 1 UNTIL WS-K > 30
               IF WS-DR(WS-K:1) IS NUMERIC AND WS-DR(WS-K:1) NOT = "0"
                   MOVE 0 TO WS-DR-ZERO
               END-IF
               IF WS-CR(WS-K:1) IS NUMERIC AND WS-CR(WS-K:1) NOT = "0"
                   MOVE 0 TO WS-CR-ZERO
               END-IF
           END-PERFORM
           IF WS-DR-ZERO = WS-CR-ZERO
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_AMOUNT" TO WS-ROW-ERR
               MOVE "exactly one side must be non-zero" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-ACC TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_ACCOUNT" TO WS-ROW-ERR
               MOVE "account code is malformed" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT 1 FROM gl_account WHERE account_code = ? AND is_active = TRUE LIMIT 1" TO WS-PREP-SQL
           MOVE WS-ACC TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "ACCOUNT_NOT_FOUND" TO WS-ROW-ERR
               MOVE "GL account does not exist" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "DB_ERROR" TO WS-ROW-ERR
               MOVE "account lookup failed" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE "VALID" TO WS-ROW-STATUS.
           EXIT PARAGRAPH.

       VALIDATE-ACCOUNTS-ROW.
           MOVE SPACES TO WS-F1 WS-F2
           UNSTRING WS-RAW DELIMITED BY "," INTO WS-F1 WS-F2
           END-UNSTRING
           IF WS-F1 = SPACES OR WS-F2 = SPACES
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_FORMAT" TO WS-ROW-ERR
               MOVE "expected email,currency" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE 0 TO WS-AT-COUNT
           INSPECT WS-F1 TALLYING WS-AT-COUNT FOR ALL "@"
           IF WS-AT-COUNT NOT = 1
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_EMAIL" TO WS-ROW-ERR
               MOVE "email must contain exactly one @" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           IF WS-F2(1:3) IS NOT ALPHABETIC OR WS-F2(4:1) NOT = SPACE
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_CURRENCY" TO WS-ROW-ERR
               MOVE "currency must be three letters" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE "VALID" TO WS-ROW-STATUS.
           EXIT PARAGRAPH.

       VALIDATE-REFERENCE-ROW.
           MOVE SPACES TO WS-F1 WS-F2 WS-F3
           UNSTRING WS-RAW DELIMITED BY ":" INTO WS-F1 WS-F2 WS-F3
           END-UNSTRING
           IF WS-F1 = SPACES OR WS-F2 = SPACES OR WS-F3 = SPACES
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_FORMAT" TO WS-ROW-ERR
               MOVE "expected type:code:label" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE "VALID" TO WS-ROW-STATUS.
           EXIT PARAGRAPH.

       VALIDATE-PAYMENTS-ROW.
           MOVE SPACES TO WS-F1 WS-F2 WS-F3
           UNSTRING WS-RAW DELIMITED BY "," INTO WS-F1 WS-F2 WS-F3
           END-UNSTRING
           IF WS-F1 = SPACES OR WS-F2 = SPACES OR WS-F3 = SPACES
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_FORMAT" TO WS-ROW-ERR
               MOVE "expected from,to,amount" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE 0 TO WS-AT-COUNT
           INSPECT WS-F1 TALLYING WS-AT-COUNT FOR ALL "@"
           IF WS-AT-COUNT NOT = 1
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_EMAIL" TO WS-ROW-ERR
               MOVE "sender must contain exactly one @" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE 0 TO WS-AT-COUNT
           INSPECT WS-F2 TALLYING WS-AT-COUNT FOR ALL "@"
           IF WS-AT-COUNT NOT = 1
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_EMAIL" TO WS-ROW-ERR
               MOVE "target must contain exactly one @" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-F3(1:30) TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "INVALID" TO WS-ROW-STATUS
               MOVE "INVALID_AMOUNT" TO WS-ROW-ERR
               MOVE "amount is not decimal" TO WS-ROW-DETAIL
               EXIT PARAGRAPH
           END-IF.
           MOVE "VALID" TO WS-ROW-STATUS.
           EXIT PARAGRAPH.

       ACTION-BATCH-CREATE.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED NOT = "LEDGER"
              AND WS-P3-TRIMMED NOT = "ACCOUNTS"
              AND WS-P3-TRIMMED NOT = "REFERENCE"
              AND WS-P3-TRIMMED NOT = "PAYMENTS"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT 1 FROM import_batch WHERE batch_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "1"
               MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO import_batch (batch_code, source_name, import_type, status, created_by) VALUES (?, ?, ?, 'STAGED', ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P6-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-BATCH-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "BATCH_CREATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-BATCH
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-IMPORT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|IMP_BATCH_CREATED|" DELIMITED BY SIZE
                      WS-BATCH-ID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BATCH-LIST.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM1 NOT = SPACES
               MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               IF WS-P3-TRIMMED NOT = "STAGED" AND WS-P3-TRIMMED NOT = "VALIDATING"
                  AND WS-P3-TRIMMED NOT = "VALIDATED" AND WS-P3-TRIMMED NOT = "COMPLETED"
                  AND WS-P3-TRIMMED NOT = "FAILED"
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           IF LS-PARAM4 NOT = SPACES
               IF WS-P4-TRIMMED NOT = "LEDGER" AND WS-P4-TRIMMED NOT = "ACCOUNTS"
                  AND WS-P4-TRIMMED NOT = "REFERENCE" AND WS-P4-TRIMMED NOT = "PAYMENTS"
                   MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM import_batch WHERE status = COALESCE(NULLIF(?, ''), status) AND import_type = COALESCE(NULLIF(?, ''), import_type)" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P4-TRIMMED TO WS-BIND-2
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(id, ':', batch_code, ':', source_name, ':', import_type, ':', status, ':', total_rows, ':', valid_rows, ':', invalid_rows, ':', posted_rows) FROM import_batch WHERE status = COALESCE(NULLIF(?, ''), status) AND import_type = COALESCE(NULLIF(?, ''), import_type) ORDER BY id DESC LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P4-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           MOVE WS-OFFSET TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|IMP_BATCHES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|IMP_BATCHES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BATCH-GET.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM2 = SPACES
               MOVE "0" TO WS-P2-TRIMMED
           END-IF.
           IF WS-P2-TRIMMED NOT = "0" AND WS-P2-TRIMMED NOT = "1"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BATCH
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           MOVE 1 TO WS-OUT-POS
           STRING "SUCCESS|IMP_BATCH|" DELIMITED BY SIZE
                  WS-BATCH-ID DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-P1-TRIMMED DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-BATCH-SOURCE DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-BATCH-TYPE DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-BATCH-STATUS DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-BATCH-TOTAL DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-BATCH-VALID DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-BATCH-INVALID DELIMITED BY SPACE ":" DELIMITED BY SIZE
                  WS-BATCH-POSTED DELIMITED BY SPACE
                  INTO LS-OUTPUT-BUFFER WITH POINTER WS-OUT-POS
           END-STRING
           IF WS-P2-TRIMMED = "1"
               MOVE "SELECT CONCAT(row_no, ':', status, ':', COALESCE(error_code, ''), ':', COALESCE(error_detail, ''), ':', raw_data) FROM import_row WHERE batch_id = ? ORDER BY row_no" TO WS-PREP-SQL
               MOVE WS-BATCH-ID TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               MOVE SPACES TO WS-PART
               MOVE 0 TO WS-PART-LEN
               IF WS-RESULT NOT = "ERROR|NO_DATA"
                   MOVE WS-RESULT TO WS-PART
                   PERFORM TRIM-PART
               END-IF
               STRING "|" DELIMITED BY SIZE
                      WS-PART(1:WS-PART-LEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER WITH POINTER WS-OUT-POS
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BATCH-VALIDATE.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BATCH
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-BATCH-STATUS NOT = "STAGED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF FUNCTION NUMVAL(WS-BATCH-TOTAL) = 0
               MOVE "ERROR|NO_ROWS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           MOVE 0 TO WS-VALID-COUNT WS-INVALID-COUNT
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE import_batch SET status = 'VALIDATING', version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-BATCH-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           MOVE 1 TO WS-ROW-INDEX
           PERFORM UNTIL STEP-FAIL
               OR WS-ROW-INDEX > FUNCTION NUMVAL(WS-BATCH-TOTAL)
               MOVE WS-ROW-INDEX TO WS-ROW-INDEX-ED
               MOVE WS-ROW-INDEX-ED TO WS-P2-TRIMMED
               PERFORM CHECK-ROW
               IF WS-LOOKUP-BAD = 1
                   MOVE "ERROR|DB_ERROR" TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   IF WS-LOOKUP-BAD = 2
                       MOVE "ERROR|DB_ERROR" TO WS-ERR
                       SET STEP-FAIL TO TRUE
                   ELSE
                       PERFORM VALIDATE-IMPORT-ROW
                       MOVE "UPDATE import_row SET status = ?, error_code = NULLIF(?, ''), error_detail = NULLIF(?, '') WHERE id = ?" TO WS-PREP-SQL
                       MOVE WS-ROW-STATUS TO WS-BIND-1
                       MOVE WS-ROW-ERR TO WS-BIND-2
                       MOVE WS-ROW-DETAIL TO WS-BIND-3
                       MOVE WS-ROW-ID TO WS-BIND-4
                       CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                           BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                           BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                       END-CALL
                       CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                       IF WS-RESULT(1:5) = "ERROR"
                           MOVE WS-RESULT(1:40) TO WS-ERR
                           SET STEP-FAIL TO TRUE
                       ELSE
                           IF WS-ROW-STATUS = "VALID" AND WS-BATCH-TYPE = "LEDGER"
                               MOVE "UPDATE import_row SET parsed_account = ?, debit_amount = ?, credit_amount = ? WHERE id = ?" TO WS-PREP-SQL
                               MOVE WS-ACC TO WS-BIND-1
                               MOVE WS-DR TO WS-BIND-2
                               MOVE WS-CR TO WS-BIND-3
                               MOVE WS-ROW-ID TO WS-BIND-4
                               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
                               END-CALL
                               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                               IF WS-RESULT(1:5) = "ERROR"
                                   MOVE WS-RESULT(1:40) TO WS-ERR
                                   SET STEP-FAIL TO TRUE
                               END-IF
                           END-IF
                           IF STEP-OK
                               IF WS-ROW-STATUS = "VALID"
                                   ADD 1 TO WS-VALID-COUNT END-ADD
                               ELSE
                                   ADD 1 TO WS-INVALID-COUNT END-ADD
                               END-IF
                           END-IF
                       END-IF
                   END-IF
               END-IF
               ADD 1 TO WS-ROW-INDEX END-ADD
           END-PERFORM.
           IF STEP-OK
               MOVE "UPDATE import_batch SET status = 'VALIDATED', valid_rows = ?, invalid_rows = ?, version = version + 1 WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-VALID-COUNT TO WS-BIND-1
               MOVE WS-INVALID-COUNT TO WS-BIND-2
               MOVE WS-BATCH-ID TO WS-BIND-3
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "BATCH_VALIDATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-BATCH
               MOVE "validated" TO WS-AUDIT-DETAIL
               PERFORM AUDIT-IMPORT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               MOVE WS-VALID-COUNT TO WS-VALID-COUNT-ED
               MOVE WS-INVALID-COUNT TO WS-INVALID-COUNT-ED
               STRING "SUCCESS|IMP_VALIDATED|" DELIMITED BY SIZE
                      FUNCTION TRIM(WS-VALID-COUNT-ED) DELIMITED BY SIZE
                      "|" DELIMITED BY SIZE
                      FUNCTION TRIM(WS-INVALID-COUNT-ED) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BATCH-POST.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BATCH
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-BATCH-STATUS NOT = "VALIDATED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF FUNCTION NUMVAL(WS-BATCH-INVALID) > 0
               MOVE "ERROR|INVALID_ROWS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE import_row SET status = 'POSTED' WHERE batch_id = ? AND status = 'VALID'" TO WS-PREP-SQL
           MOVE WS-BATCH-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE import_batch SET status = 'COMPLETED', posted_rows = valid_rows, version = version + 1 WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-BATCH-ID TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "BATCH_POST" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-BATCH
               MOVE WS-BATCH-VALID TO WS-AUDIT-DETAIL
               PERFORM AUDIT-IMPORT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|IMP_POSTED|" DELIMITED BY SIZE
                      WS-BATCH-VALID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BATCH-FAIL.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BATCH
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-BATCH-STATUS = "COMPLETED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE import_batch SET status = 'FAILED', error_code = ?, error_detail = ?, version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-BATCH-ID TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "BATCH_FAIL" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-BATCH
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-IMPORT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|IMP_FAILED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BATCH-EXPORT.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-TRIMMED NOT = "CSV" AND WS-P2-TRIMMED NOT = "FIXED"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BATCH
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT GROUP_CONCAT(CONCAT(row_no, ':', status, ':', raw_data) ORDER BY row_no SEPARATOR ';') FROM import_row WHERE batch_id = ?" TO WS-PREP-SQL
           MOVE WS-BATCH-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-PART
           MOVE 0 TO WS-PART-LEN
           IF WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE WS-RESULT TO WS-PART
               PERFORM TRIM-PART
           END-IF
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|IMP_EXPORT|" DELIMITED BY SIZE
                  WS-P2-TRIMMED DELIMITED BY SPACE "|" DELIMITED BY SIZE
                  WS-BATCH-STATUS DELIMITED BY SPACE "|" DELIMITED BY SIZE
                  WS-PART(1:WS-PART-LEN) DELIMITED BY SIZE
                  INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.

       ACTION-BATCH-CLONE.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BATCH
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT 1 FROM import_batch WHERE batch_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "1"
               MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR" AND WS-RESULT NOT = "ERROR|NO_DATA"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO import_batch (batch_code, source_name, import_type, status, created_by) VALUES (?, ?, ?, 'STAGED', ?)" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-BATCH-TYPE TO WS-BIND-3
           MOVE WS-P6-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               PERFORM LAST-INSERT-ID
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-BATCH-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "INSERT INTO import_row (batch_id, row_no, raw_data, status) SELECT ?, row_no, raw_data, 'STAGED' FROM import_row WHERE batch_id = ?" TO WS-PREP-SQL
               MOVE WS-BATCH-ID TO WS-BIND-1
               MOVE WS-BATCH-ID TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE import_batch SET total_rows = (SELECT COUNT(*) FROM import_row WHERE batch_id = ?), version = version + 1 WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-BATCH-ID TO WS-BIND-1
               MOVE WS-BATCH-ID TO WS-BIND-2
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "BATCH_CLONE" TO WS-AUDIT-ACTION
               MOVE WS-P2-TRIMMED(1:40) TO WS-AUDIT-BATCH
               MOVE WS-P1-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-IMPORT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|IMP_BATCH_CLONED|" DELIMITED BY SIZE
                      WS-BATCH-ID DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BATCH-DELETE.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BATCH
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-BATCH-STATUS NOT = "STAGED" AND WS-BATCH-STATUS NOT = "FAILED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "DELETE FROM import_batch WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-BATCH-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "BATCH_DELETE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-BATCH
               MOVE "deleted" TO WS-AUDIT-DETAIL
               PERFORM AUDIT-IMPORT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|IMP_BATCH_DELETED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BATCH-RETRY.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BATCH
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-BATCH-STATUS NOT = "FAILED"
               MOVE "ERROR|INVALID_STATUS" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE import_batch SET status = 'STAGED', valid_rows = 0, invalid_rows = 0, posted_rows = 0, error_code = NULL, error_detail = NULL, version = version + 1 WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-BATCH-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "UPDATE import_row SET status = 'STAGED', error_code = NULL, error_detail = NULL WHERE batch_id = ?" TO WS-PREP-SQL
               MOVE WS-BATCH-ID TO WS-BIND-1
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "BATCH_RETRY" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-BATCH
               MOVE "retry" TO WS-AUDIT-DETAIL
               PERFORM AUDIT-IMPORT
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|IMP_BATCH_RETRIED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-BATCH-SUMMARY.
           MOVE "IMPORT_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           PERFORM CHECK-BATCH
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(SUM(status = 'VALID'), ':', SUM(status = 'INVALID'), ':', SUM(status = 'POSTED'), ':', SUM(status = 'SKIPPED'), ':', SUM(status = 'STAGED')) FROM import_row WHERE batch_id = ?" TO WS-PREP-SQL
           MOVE WS-BATCH-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|IMP_SUMMARY|" DELIMITED BY SIZE
                  WS-BATCH-STATUS DELIMITED BY SPACE "|" DELIMITED BY SIZE
                  WS-BATCH-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                  WS-BATCH-VALID DELIMITED BY SPACE "|" DELIMITED BY SIZE
                  WS-BATCH-INVALID DELIMITED BY SPACE "|" DELIMITED BY SIZE
                  WS-BATCH-POSTED DELIMITED BY SPACE "|" DELIMITED BY SIZE
                  WS-RESULT(1:50) DELIMITED BY SIZE
                  INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.
