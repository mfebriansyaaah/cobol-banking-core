       IDENTIFICATION DIVISION.
       PROGRAM-ID. fee_core.
      *> Fee rules, waivers, tiers, and velocity limits (Sprint 1 slice 4).

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
       01  WS-BAD-SAVE             PIC 9 VALUE 0.
       01  WS-EMAIL                PIC X(100) VALUE SPACES.
       01  WS-ALLOWED              PIC 9 VALUE 0.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.
       01  WS-ERR                  PIC X(40) VALUE SPACES.
       01  WS-TOTAL                PIC X(100) VALUE SPACES.
       01  WS-LIMIT                PIC X(10) VALUE SPACES.
       01  WS-OFFSET               PIC X(10) VALUE SPACES.
       01  WS-LOOKUP-BAD           PIC 9 VALUE 0.
       01  WS-RULE-ID              PIC X(20) VALUE SPACES.
       01  WS-RULE-CODE            PIC X(40) VALUE SPACES.
       01  WS-RULE-NAME            PIC X(100) VALUE SPACES.
       01  WS-RULE-TYPE            PIC X(10) VALUE SPACES.
       01  WS-RULE-CURRENCY        PIC X(3) VALUE SPACES.
       01  WS-RULE-ENABLED         PIC X(1) VALUE SPACES.
       01  WS-RULE-FLAT           PIC X(30) VALUE SPACES.
       01  WS-RULE-PERCENT         PIC X(30) VALUE SPACES.
       01  WS-RULE-MIN             PIC X(30) VALUE SPACES.
       01  WS-RULE-MAX             PIC X(30) VALUE SPACES.
       01  WS-TIER-ID              PIC X(20) VALUE SPACES.
       01  WS-TIER-NO              PIC X(10) VALUE SPACES.
       01  WS-TIER-FROM            PIC X(30) VALUE SPACES.
       01  WS-TIER-TO              PIC X(30) VALUE SPACES.
       01  WS-TIER-FIXED           PIC X(30) VALUE SPACES.
       01  WS-TIER-RATE            PIC X(30) VALUE SPACES.
       01  WS-PROFILE-ID           PIC X(20) VALUE SPACES.
       01  WS-PROFILE-CODE         PIC X(40) VALUE SPACES.
       01  WS-PROFILE-NAME         PIC X(100) VALUE SPACES.
       01  WS-PROFILE-WINDOW       PIC X(10) VALUE SPACES.
       01  WS-PROFILE-MAX-COUNT    PIC X(20) VALUE SPACES.
       01  WS-PROFILE-MAX-AMOUNT   PIC X(30) VALUE SPACES.
       01  WS-PROFILE-CURRENCY     PIC X(3) VALUE SPACES.
       01  WS-PROFILE-ENABLED      PIC X(1) VALUE SPACES.
       01  WS-CODE-IN              PIC X(100) VALUE SPACES.
       01  WS-CODE-LEN             PIC 9(3) VALUE 0.
       01  WS-COUNT-IN             PIC X(30) VALUE SPACES.
       01  WS-COUNT-LEN            PIC 9(3) VALUE 0.
       01  WS-DEC-IN               PIC X(30) VALUE SPACES.
       01  WS-DEC-LEN              PIC 9(3) VALUE 0.
       01  WS-DOT-COUNT            PIC 9(3) VALUE 0.
       01  WS-DATE-IN              PIC X(100) VALUE SPACES.
       01  WS-DATE-LEN             PIC 9(3) VALUE 0.
       01  WS-FLAT                 PIC X(30) VALUE SPACES.
       01  WS-PERCENT              PIC X(30) VALUE SPACES.
       01  WS-MIN                  PIC X(30) VALUE SPACES.
       01  WS-MAX                  PIC X(30) VALUE SPACES.
       01  WS-FIXED                PIC X(30) VALUE SPACES.
       01  WS-RATE                 PIC X(30) VALUE SPACES.
       01  WS-WINDOW               PIC X(10) VALUE SPACES.
       01  WS-MAX-COUNT            PIC X(20) VALUE SPACES.
       01  WS-MAX-AMOUNT           PIC X(30) VALUE SPACES.
       01  WS-CURRENCY             PIC X(3) VALUE SPACES.
       01  WS-COUNT1               PIC X(20) VALUE SPACES.
       01  WS-COUNT2               PIC X(30) VALUE SPACES.
       01  WS-NEW-COUNT            PIC 9(18) VALUE 0.
       01  WS-NEW-AMOUNT           PIC 9(20)V9(4) VALUE 0.
       01  WS-VEL-USED-COUNT       PIC X(20) VALUE SPACES.
       01  WS-VEL-USED-AMOUNT      PIC X(30) VALUE SPACES.
       01  WS-VEL-AMOUNT           PIC X(30) VALUE SPACES.
       01  WS-VEL-COUNT-NORM       PIC X(30) VALUE SPACES.
       01  WS-VEL-USED-NORM        PIC X(30) VALUE SPACES.
       01  WS-VEL-AMT-NORM         PIC X(30) VALUE SPACES.
       01  WS-VEL-MAXC-NORM        PIC X(30) VALUE SPACES.
       01  WS-VEL-MAXA-NORM        PIC X(30) VALUE SPACES.
       01  WS-VEL-NEWC-NUM         PIC 9(18) VALUE 0.
       01  WS-VEL-NEWA-NUM         PIC 9(20)V9(4) VALUE 0.
       01  WS-VEL-MAXC-NUM         PIC 9(18) VALUE 0.
       01  WS-VEL-MAXA-NUM         PIC 9(20)V9(4) VALUE 0.
       01  WS-VEL-BLOCKED          PIC X VALUE "0".
       01  WS-VEL-CODES            PIC X(200) VALUE SPACES.
       01  WS-AT-COUNT             PIC 9(3) VALUE 0.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-RULE           PIC X(40) VALUE SPACES.
       01  WS-AUDIT-ACCOUNT        PIC X(100) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
       01  WS-DENIED-TARGET        PIC X(40) VALUE SPACES.
       01  WS-PART                 PIC X(16384) VALUE SPACES.
       01  WS-PART-LEN             PIC 9(5) VALUE 0.
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
               WHEN LS-CMD-ACTION(1:15) = "FEE_RULE_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RULE-CREATE
               WHEN LS-CMD-ACTION(1:13) = "FEE_RULE_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RULE-LIST
               WHEN LS-CMD-ACTION(1:15) = "FEE_RULE_UPDATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-RULE-UPDATE
               WHEN LS-CMD-ACTION(1:15) = "FEE_TIER_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-TIER-CREATE
               WHEN LS-CMD-ACTION(1:13) = "FEE_TIER_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-TIER-LIST
               WHEN LS-CMD-ACTION(1:17) = "FEE_WAIVER_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-WAIVER-CREATE
               WHEN LS-CMD-ACTION(1:15) = "FEE_WAIVER_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-WAIVER-LIST
               WHEN LS-CMD-ACTION(1:13) = "FEE_CALCULATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-FEE-CALCULATE
               WHEN LS-CMD-ACTION(1:18) = "VEL_PROFILE_CREATE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VEL-PROFILE-CREATE
               *> Prefix dispatch: longer names first. "VEL_CHECK" also
               *> matches "VEL_CHECK_ALL_TXN" (and VEL_RECORD likewise),
               *> so the _ALL_TXN clauses must stay above the short ones.
               WHEN LS-CMD-ACTION(1:16) = "VEL_PROFILE_LIST"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VEL-PROFILE-LIST
               WHEN LS-CMD-ACTION(1:17) = "VEL_CHECK_ALL_TXN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VEL-CHECK-ALL-TXN
               WHEN LS-CMD-ACTION(1:9) = "VEL_CHECK"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VEL-CHECK
               WHEN LS-CMD-ACTION(1:18) = "VEL_RECORD_ALL_TXN"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VEL-RECORD-ALL-TXN
               WHEN LS-CMD-ACTION(1:10) = "VEL_RECORD"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VEL-RECORD
               WHEN LS-CMD-ACTION(1:9) = "VEL_USAGE"
                   PERFORM TRIM-ALL
                   PERFORM ACTION-VEL-USAGE
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
           END-EVALUATE.
           GOBACK.

        COPY "common_validate_semi.cpy".
        COPY "common_validate.cpy".



        COPY "common_trim.cpy".

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

       VALIDATE-DATE-FIELD.
           MOVE 0 TO WS-BAD
           MOVE 0 TO WS-DATE-LEN
           PERFORM VARYING WS-I FROM 100 BY -1
               UNTIL WS-I < 1 OR WS-DATE-LEN > 0
               IF WS-DATE-IN(WS-I:1) NOT = SPACE
                   MOVE WS-I TO WS-DATE-LEN
               END-IF
           END-PERFORM
           IF WS-DATE-LEN NOT = 10
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-DATE-IN(5:1) NOT = "-" OR WS-DATE-IN(8:1) NOT = "-"
               MOVE 1 TO WS-BAD
           END-IF.
           IF WS-DATE-IN(1:4) IS NOT NUMERIC
              OR WS-DATE-IN(6:2) IS NOT NUMERIC
              OR WS-DATE-IN(9:2) IS NOT NUMERIC
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-EMAIL-FIELD.
           MOVE 0 TO WS-BAD
           IF WS-EMAIL = SPACES
               MOVE 1 TO WS-BAD
           END-IF.
           MOVE 0 TO WS-AT-COUNT
           INSPECT WS-EMAIL TALLYING WS-AT-COUNT FOR ALL "@"
           IF WS-AT-COUNT NOT = 1
               MOVE 1 TO WS-BAD
           END-IF.
           EXIT PARAGRAPH.

        COPY "common_auth.cpy".

       AUDIT-FEE.
           MOVE "INSERT INTO fee_audit (action, actor_email, rule_code, account_email, detail) VALUES (?, ?, NULLIF(?, ''), NULLIF(?, ''), ?)" TO WS-PREP-SQL
           MOVE WS-AUDIT-ACTION TO WS-BIND-1
           MOVE WS-P6-TRIMMED TO WS-BIND-2
           MOVE WS-AUDIT-RULE TO WS-BIND-3
           MOVE WS-AUDIT-ACCOUNT TO WS-BIND-4
           MOVE WS-AUDIT-DETAIL TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
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
           MOVE SPACES TO WS-AUDIT-RULE WS-AUDIT-ACCOUNT
           MOVE WS-DENIED-TARGET TO WS-AUDIT-DETAIL
           MOVE WS-DENIED-ACTOR TO WS-P6-TRIMMED
           PERFORM AUDIT-FEE.
           EXIT PARAGRAPH.

       CHECK-RULE.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-RULE-ID WS-RULE-TYPE WS-RULE-CURRENCY
               WS-RULE-ENABLED WS-RULE-FLAT WS-RULE-PERCENT
               WS-RULE-MIN WS-RULE-MAX
           MOVE "SELECT CONCAT(id, '|', fee_type, '|', currency_code, '|', IF(enabled, '1', '0'), '|', flat_amount, '|', percent_rate, '|', min_amount, '|', max_amount) FROM fee_rule WHERE rule_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-RULE-CODE TO WS-BIND-1
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
               WS-RULE-ID WS-RULE-TYPE WS-RULE-CURRENCY WS-RULE-ENABLED
               WS-RULE-FLAT WS-RULE-PERCENT WS-RULE-MIN WS-RULE-MAX
           END-UNSTRING.
           EXIT PARAGRAPH.

       CHECK-PROFILE.
           MOVE 0 TO WS-LOOKUP-BAD
           MOVE SPACES TO WS-PROFILE-ID WS-PROFILE-WINDOW
               WS-PROFILE-MAX-COUNT WS-PROFILE-MAX-AMOUNT
               WS-PROFILE-CURRENCY WS-PROFILE-ENABLED
           MOVE "SELECT CONCAT(id, '|', window_seconds, '|', max_count, '|', max_amount, '|', currency_code, '|', IF(enabled, '1', '0')) FROM velocity_profile WHERE profile_code = ? LIMIT 1" TO WS-PREP-SQL
           MOVE WS-PROFILE-CODE TO WS-BIND-1
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
               WS-PROFILE-ID WS-PROFILE-WINDOW WS-PROFILE-MAX-COUNT
               WS-PROFILE-MAX-AMOUNT WS-PROFILE-CURRENCY WS-PROFILE-ENABLED
           END-UNSTRING.
           EXIT PARAGRAPH.

       EVALUATE-VELOCITY.
           *> Single comparison point for velocity, shared by the public
           *> VEL_CHECK and the internal transfer-path check. Inputs:
           *> WS-VEL-USED-COUNT/WS-VEL-USED-AMOUNT (counter state),
           *> WS-VEL-AMOUNT (candidate amount),
           *> WS-PROFILE-MAX-COUNT/WS-PROFILE-MAX-AMOUNT (limits).
           *> Sets WS-VEL-BLOCKED to "1" when the candidate would exceed
           *> either cap. DECIMAL-POINT IS COMMA here, so every decimal
           *> string is normalized (dot to comma) before NUMVAL; a raw
           *> NUMVAL reads "100.00" as 10000 and miscompares by 100x.
           MOVE "0" TO WS-VEL-BLOCKED
           MOVE WS-VEL-USED-COUNT TO WS-VEL-COUNT-NORM
           INSPECT WS-VEL-COUNT-NORM REPLACING ALL "." BY ","
           MOVE WS-VEL-USED-AMOUNT TO WS-VEL-USED-NORM
           INSPECT WS-VEL-USED-NORM REPLACING ALL "." BY ","
           MOVE WS-VEL-AMOUNT TO WS-VEL-AMT-NORM
           INSPECT WS-VEL-AMT-NORM REPLACING ALL "." BY ","
           MOVE WS-PROFILE-MAX-COUNT TO WS-VEL-MAXC-NORM
           INSPECT WS-VEL-MAXC-NORM REPLACING ALL "." BY ","
           MOVE WS-PROFILE-MAX-AMOUNT TO WS-VEL-MAXA-NORM
           INSPECT WS-VEL-MAXA-NORM REPLACING ALL "." BY ","
           COMPUTE WS-VEL-NEWC-NUM = FUNCTION NUMVAL(WS-VEL-COUNT-NORM) + 1 END-COMPUTE
           COMPUTE WS-VEL-NEWA-NUM = FUNCTION NUMVAL(WS-VEL-USED-NORM) + FUNCTION NUMVAL(WS-VEL-AMT-NORM) END-COMPUTE
           COMPUTE WS-VEL-MAXC-NUM = FUNCTION NUMVAL(WS-VEL-MAXC-NORM) END-COMPUTE
           COMPUTE WS-VEL-MAXA-NUM = FUNCTION NUMVAL(WS-VEL-MAXA-NORM) END-COMPUTE
           IF WS-VEL-NEWC-NUM > WS-VEL-MAXC-NUM
              OR WS-VEL-NEWA-NUM > WS-VEL-MAXA-NUM
               MOVE "1" TO WS-VEL-BLOCKED
           END-IF.
           EXIT PARAGRAPH.

        COPY "common_result.cpy".

       ACTION-RULE-CREATE.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM5 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P3-TRIMMED NOT = "FLAT" AND WS-P3-TRIMMED NOT = "PERCENT"
              AND WS-P3-TRIMMED NOT = "TIERED"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P4-LEN NOT = 3 OR WS-P4-TRIMMED(1:3) IS NOT ALPHABETIC
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-FLAT WS-PERCENT WS-MIN WS-MAX
           UNSTRING WS-P5-TRIMMED DELIMITED BY ","
               INTO WS-FLAT WS-PERCENT WS-MIN WS-MAX
           END-UNSTRING
           PERFORM VALIDATE-AMOUNT-SET
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO fee_rule (rule_code, name, fee_type, currency_code, created_by) VALUES (?, ?, ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-P6-TRIMMED TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-RULE-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE fee_rule SET flat_amount = ?, percent_rate = ?, min_amount = ?, max_amount = ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-FLAT TO WS-BIND-1
               MOVE WS-PERCENT TO WS-BIND-2
               MOVE WS-MIN TO WS-BIND-3
               MOVE WS-MAX TO WS-BIND-4
               MOVE WS-RULE-ID TO WS-BIND-5
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
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
               MOVE "RULE_CREATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-RULE
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-FEE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|FEE_RULE_CREATED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       VALIDATE-AMOUNT-SET.
           MOVE 0 TO WS-BAD-SAVE
           MOVE WS-FLAT TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-PERCENT TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-MIN TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-MAX TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-BAD-SAVE TO WS-BAD.
           EXIT PARAGRAPH.

       ACTION-RULE-LIST.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
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
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM fee_rule WHERE (? = '' OR fee_type = ?) AND (? = '' OR currency_code = ?)" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(rule_code, ':', name, ':', fee_type, ':', currency_code, ':', flat_amount, ':', percent_rate, ':', min_amount, ':', max_amount, ':', priority, ':', IF(enabled, '1', '0')) FROM fee_rule WHERE (? = '' OR fee_type = ?) AND (? = '' OR currency_code = ?) ORDER BY rule_code LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P4-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-LIMIT TO WS-BIND-5
           MOVE WS-OFFSET TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|FEE_RULES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|FEE_RULES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-RULE-UPDATE.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM4 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:40) TO WS-RULE-CODE
           PERFORM CHECK-RULE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P2-TRIMMED NOT = "0" AND WS-P2-TRIMMED NOT = "1"
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P3-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-FLAT WS-PERCENT WS-MIN WS-MAX
           UNSTRING WS-P4-TRIMMED DELIMITED BY ","
               INTO WS-FLAT WS-PERCENT WS-MIN WS-MAX
           END-UNSTRING
           PERFORM VALIDATE-AMOUNT-SET
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "UPDATE fee_rule SET enabled = ?, priority = ? WHERE id = ?" TO WS-PREP-SQL
           MOVE WS-P2-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-RULE-ID TO WS-BIND-3
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
               MOVE "UPDATE fee_rule SET flat_amount = ?, percent_rate = ?, min_amount = ?, max_amount = ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-FLAT TO WS-BIND-1
               MOVE WS-PERCENT TO WS-BIND-2
               MOVE WS-MIN TO WS-BIND-3
               MOVE WS-MAX TO WS-BIND-4
               MOVE WS-RULE-ID TO WS-BIND-5
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
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
               MOVE "RULE_UPDATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-RULE
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P4-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-FEE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|FEE_RULE_UPDATED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-TIER-CREATE.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES OR LS-PARAM5 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:40) TO WS-RULE-CODE
           PERFORM CHECK-RULE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED(1:30) TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE 0 TO WS-BAD-SAVE
           MOVE WS-P3-TRIMMED(1:30) TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-P4-TRIMMED(1:30) TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE SPACES TO WS-FIXED WS-RATE
           UNSTRING WS-P5-TRIMMED DELIMITED BY ","
               INTO WS-FIXED WS-RATE
           END-UNSTRING
           MOVE WS-FIXED TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-RATE TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-BAD-SAVE TO WS-BAD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO fee_tier (rule_id, tier_no, from_amount, to_amount, fixed_fee, rate) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-RULE-ID TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-FIXED TO WS-BIND-5
           MOVE WS-RATE TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "TIER_CREATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-RULE
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-FEE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|FEE_TIER_CREATED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-TIER-LIST.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:40) TO WS-RULE-CODE
           PERFORM CHECK-RULE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM fee_tier WHERE rule_id = ?" TO WS-PREP-SQL
           MOVE WS-RULE-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(tier_no, ':', from_amount, ':', to_amount, ':', fixed_fee, ':', rate) FROM fee_tier WHERE rule_id = ? ORDER BY tier_no LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-RULE-ID TO WS-BIND-1
           MOVE WS-LIMIT TO WS-BIND-2
           MOVE WS-OFFSET TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|FEE_TIERS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|FEE_TIERS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-WAIVER-CREATE.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
              OR LS-PARAM3 = SPACES OR LS-PARAM4 = SPACES OR LS-PARAM5 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:40) TO WS-RULE-CODE
           PERFORM CHECK-RULE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED TO WS-EMAIL
           PERFORM VALIDATE-EMAIL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P4-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P5-TRIMMED TO WS-DATE-IN
           PERFORM VALIDATE-DATE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO fee_waiver (rule_id, account_email, reason, valid_from, valid_to, created_by) VALUES (?, ?, ?, ?, ?, ?)" TO WS-PREP-SQL
           MOVE WS-RULE-ID TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           MOVE WS-P5-TRIMMED TO WS-BIND-5
           MOVE WS-P6-TRIMMED TO WS-BIND-6
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 6
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "WAIVER_CREATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-RULE
               MOVE WS-P2-TRIMMED TO WS-AUDIT-ACCOUNT
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-FEE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|FEE_WAIVER_CREATED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-WAIVER-LIST.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED(1:40) TO WS-RULE-CODE
           PERFORM CHECK-RULE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "50" TO WS-LIMIT
           MOVE "0" TO WS-OFFSET
           IF LS-PARAM2 NOT = SPACES
               MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-LIMIT
           END-IF.
           IF LS-PARAM3 NOT = SPACES
               MOVE WS-P3-TRIMMED(1:WS-P3-LEN) TO WS-OFFSET
           END-IF.
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM fee_waiver WHERE rule_id = ?" TO WS-PREP-SQL
           MOVE WS-RULE-ID TO WS-BIND-1
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF
           MOVE WS-RESULT(1:20) TO WS-TOTAL
           MOVE "SELECT CONCAT(account_email, ':', reason, ':', valid_from, ':', valid_to, ':', IF(enabled, '1', '0')) FROM fee_waiver WHERE rule_id = ? ORDER BY id LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-RULE-ID TO WS-BIND-1
           MOVE WS-LIMIT TO WS-BIND-2
           MOVE WS-OFFSET TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|FEE_WAIVERS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|FEE_WAIVERS|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-FEE-CALCULATE.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
              OR LS-PARAM4 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-EMAIL
           PERFORM VALIDATE-EMAIL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED(1:40) TO WS-RULE-CODE
           MOVE WS-P3-TRIMMED(1:30) TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P4-LEN NOT = 3 OR WS-P4-TRIMMED(1:3) IS NOT ALPHABETIC
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-PREP-SQL
           STRING "SELECT CAST(CASE WHEN f.waived = 1 THEN 0 " DELIMITED BY SIZE
                  "WHEN r.min_amount > 0 AND f.base < r.min_amount THEN r.min_amount " DELIMITED BY SIZE
                  "WHEN r.max_amount > 0 AND f.base > r.max_amount THEN r.max_amount " DELIMITED BY SIZE
                  "ELSE f.base END AS DECIMAL(30,10)) FROM (" DELIMITED BY SIZE
                  "SELECT r.id, r.min_amount, r.max_amount, " DELIMITED BY SIZE
                  "IF(EXISTS(SELECT 1 FROM fee_waiver w WHERE w.rule_id = r.id AND w.account_email = ? " DELIMITED BY SIZE
                  "AND w.enabled = TRUE AND CURDATE() BETWEEN w.valid_from AND w.valid_to), 1, 0) waived, " DELIMITED BY SIZE
                  "CASE r.fee_type WHEN 'FLAT' THEN r.flat_amount " DELIMITED BY SIZE
                  "WHEN 'PERCENT' THEN p.amt * r.percent_rate / 100 " DELIMITED BY SIZE
                  "WHEN 'TIERED' THEN COALESCE((SELECT t.fixed_fee + p.amt * t.rate / 100 " DELIMITED BY SIZE
                  "FROM fee_tier t WHERE t.rule_id = r.id AND p.amt >= t.from_amount " DELIMITED BY SIZE
                  "AND (t.to_amount = 0 OR p.amt <= t.to_amount) ORDER BY t.tier_no LIMIT 1), 0) END AS base " DELIMITED BY SIZE
                  "FROM fee_rule r CROSS JOIN (SELECT CAST(? AS DECIMAL(30,10)) amt) p " DELIMITED BY SIZE
                  "WHERE r.rule_code = ? AND r.currency_code = ? AND r.enabled = TRUE) f " DELIMITED BY SIZE
                  "JOIN fee_rule r ON r.id = f.id" DELIMITED BY SIZE
                  INTO WS-PREP-SQL
           END-STRING
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           MOVE WS-P4-TRIMMED TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT = "ERROR|NO_DATA"
               MOVE "ERROR|RULE_NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|FEE_CALC|" DELIMITED BY SIZE
                  WS-RESULT(1:40) DELIMITED BY SIZE
                  INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.

       ACTION-VEL-PROFILE-CREATE.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P1-TRIMMED TO WS-CODE-IN
           PERFORM VALIDATE-CODE-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-WINDOW WS-MAX-COUNT WS-MAX-AMOUNT WS-CURRENCY
           UNSTRING WS-P3-TRIMMED DELIMITED BY ","
               INTO WS-WINDOW WS-MAX-COUNT WS-MAX-AMOUNT WS-CURRENCY
           END-UNSTRING
           MOVE 0 TO WS-BAD-SAVE
           MOVE WS-WINDOW TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-MAX-COUNT TO WS-COUNT-IN
           PERFORM VALIDATE-COUNT-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-MAX-AMOUNT TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0 MOVE 1 TO WS-BAD-SAVE END-IF
           MOVE WS-BAD-SAVE TO WS-BAD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-CURRENCY(1:3) IS NOT ALPHABETIC
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO velocity_profile (profile_code, name, window_seconds, currency_code, created_by, max_count, max_amount) VALUES (?, ?, ?, ?, ?, 0, 0)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-WINDOW TO WS-BIND-3
           MOVE WS-CURRENCY TO WS-BIND-4
           MOVE WS-P6-TRIMMED TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "SELECT LAST_INSERT_ID()" TO WS-PREP-SQL
               CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                   BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                   BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
               END-CALL
               CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE WS-RESULT(1:40) TO WS-ERR
                   SET STEP-FAIL TO TRUE
               ELSE
                   MOVE WS-RESULT(1:20) TO WS-PROFILE-ID
               END-IF
           END-IF.
           IF STEP-OK
               MOVE "UPDATE velocity_profile SET max_count = ?, max_amount = ? WHERE id = ?" TO WS-PREP-SQL
               MOVE WS-MAX-COUNT TO WS-BIND-1
               MOVE WS-MAX-AMOUNT TO WS-BIND-2
               MOVE WS-PROFILE-ID TO WS-BIND-3
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
               MOVE "PROFILE_CREATE" TO WS-AUDIT-ACTION
               MOVE WS-P1-TRIMMED(1:40) TO WS-AUDIT-RULE
               MOVE SPACES TO WS-AUDIT-ACCOUNT
               MOVE WS-P2-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-FEE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|VEL_PROFILE_CREATED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VEL-PROFILE-LIST.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
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
           MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM velocity_profile WHERE (? = '' OR enabled = ?)" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
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
           MOVE "SELECT CONCAT(profile_code, ':', name, ':', window_seconds, ':', max_count, ':', max_amount, ':', currency_code, ':', IF(enabled, '1', '0')) FROM velocity_profile WHERE (? = '' OR enabled = ?) ORDER BY profile_code LIMIT ? OFFSET ?" TO WS-PREP-SQL
           MOVE WS-P3-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-LIMIT TO WS-BIND-3
           MOVE WS-OFFSET TO WS-BIND-4
           CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-RESULT = "ERROR|NO_DATA"
               STRING "SUCCESS|VEL_PROFILES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               IF WS-RESULT(1:5) = "ERROR"
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                   EXIT PARAGRAPH
               END-IF
               PERFORM TRIM-RESULT-LEN
               STRING "SUCCESS|VEL_PROFILES|" DELIMITED BY SIZE
                      WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VEL-CHECK.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED(1:40) TO WS-PROFILE-CODE
           PERFORM CHECK-PROFILE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-PROFILE-ENABLED NOT = "1"
               MOVE "ERROR|PROFILE_DISABLED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COALESCE(SUM(used_count), 0), '|', COALESCE(SUM(used_amount), 0)) FROM velocity_counter WHERE account_email = ? AND profile_code = ? AND window_start = (SELECT FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(NOW()) / window_seconds) * window_seconds) FROM velocity_profile WHERE profile_code = ? LIMIT 1)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P3-TRIMMED(1:30) TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-COUNT1 WS-COUNT2
           END-UNSTRING
           MOVE WS-COUNT1 TO WS-VEL-USED-COUNT
           MOVE WS-COUNT2 TO WS-VEL-USED-AMOUNT
           MOVE WS-P3-TRIMMED(1:30) TO WS-VEL-AMOUNT
           PERFORM EVALUATE-VELOCITY
           MOVE SPACES TO LS-OUTPUT-BUFFER
           IF WS-VEL-BLOCKED = "1"
               STRING "SUCCESS|VELOCITY|BLOCKED|" DELIMITED BY SIZE
                      WS-COUNT1 DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-COUNT2 DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           ELSE
               STRING "SUCCESS|VELOCITY|OK|" DELIMITED BY SIZE
                      WS-COUNT1 DELIMITED BY SPACE "|" DELIMITED BY SIZE
                      WS-COUNT2 DELIMITED BY SPACE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VEL-RECORD.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED(1:40) TO WS-PROFILE-CODE
           PERFORM CHECK-PROFILE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-PROFILE-ENABLED NOT = "1"
               MOVE "ERROR|PROFILE_DISABLED" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-P4-TRIMMED NOT = WS-PROFILE-CURRENCY
               MOVE "ERROR|CURRENCY_MISMATCH" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P3-TRIMMED(1:30) TO WS-DEC-IN
           PERFORM VALIDATE-DECIMAL-FIELD
           IF WS-BAD > 0
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           SET STEP-OK TO TRUE
           MOVE SPACES TO WS-ERR
           CALL "SQL_BEGIN" END-CALL
           MOVE "INSERT INTO velocity_counter (account_email, profile_code, window_start, used_count, used_amount) SELECT ?, ?, FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(NOW()) / window_seconds) * window_seconds), 1, ? FROM velocity_profile WHERE profile_code = ? AND currency_code = ? AND enabled = TRUE ON DUPLICATE KEY UPDATE used_count = used_count + 1, used_amount = used_amount + VALUES(used_amount)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           MOVE WS-P2-TRIMMED TO WS-BIND-4
           MOVE WS-P4-TRIMMED TO WS-BIND-5
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 5
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE WS-RESULT(1:40) TO WS-ERR
               SET STEP-FAIL TO TRUE
           END-IF.
           IF STEP-OK
               MOVE "VELOCITY_RECORD" TO WS-AUDIT-ACTION
               MOVE WS-P2-TRIMMED(1:40) TO WS-AUDIT-RULE
               MOVE WS-P1-TRIMMED TO WS-AUDIT-ACCOUNT
               MOVE WS-P3-TRIMMED TO WS-AUDIT-DETAIL
               PERFORM AUDIT-FEE
           END-IF.
           IF STEP-OK
               CALL "SQL_COMMIT" END-CALL
               MOVE "SUCCESS|VELOCITY_RECORDED" TO LS-OUTPUT-BUFFER
           ELSE
               CALL "SQL_ROLLBACK" END-CALL
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VEL-USAGE.
           MOVE "FEE_CORE" TO WS-DENIED-TARGET
           PERFORM ALLOW-ADMIN
           IF WS-ALLOWED NOT = 1
               MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-P2-TRIMMED(1:40) TO WS-PROFILE-CODE
           PERFORM CHECK-PROFILE
           IF WS-LOOKUP-BAD = 1
               MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           IF WS-LOOKUP-BAD = 2
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE "SELECT CONCAT(COALESCE(SUM(used_count), 0), '|', COALESCE(SUM(used_amount), 0)) FROM velocity_counter WHERE account_email = ? AND profile_code = ? AND window_start = (SELECT FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(NOW()) / window_seconds) * window_seconds) FROM velocity_profile WHERE profile_code = ? LIMIT 1)" TO WS-PREP-SQL
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           UNSTRING WS-RESULT DELIMITED BY "|" INTO WS-COUNT1 WS-COUNT2
           END-UNSTRING
           MOVE SPACES TO LS-OUTPUT-BUFFER
           STRING "SUCCESS|VEL_USAGE|" DELIMITED BY SIZE
                  WS-COUNT1 DELIMITED BY SPACE "|" DELIMITED BY SIZE
                  WS-COUNT2 DELIMITED BY SPACE
                  INTO LS-OUTPUT-BUFFER
           END-STRING.
           EXIT PARAGRAPH.

       ACTION-VEL-CHECK-ALL-TXN.
           *> Internal transfer-path check (called by payment_core): no admin
           *> gate, no audit, no transaction of its own. P1 = sender email,
           *> P2 = currency ISO, P3 = amount. Evaluates every ENABLED
           *> velocity profile of that currency against its current window
           *> and returns the first-match verdict for the unified limit
           *> evaluation. Amount comparison is decimal-exact in SQL, so no
           *> COMMA normalization is needed here.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-PREP-SQL
           STRING "SELECT COALESCE(GROUP_CONCAT(v.code SEPARATOR ','), '') FROM " DELIMITED BY SIZE
                  "(SELECT p.profile_code AS code FROM velocity_profile p " DELIMITED BY SIZE
                  "LEFT JOIN velocity_counter c ON c.profile_code = p.profile_code " DELIMITED BY SIZE
                  "AND c.account_email = ? " DELIMITED BY SIZE
                  "AND c.window_start = FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(NOW()) / p.window_seconds) * p.window_seconds) " DELIMITED BY SIZE
                  "WHERE p.currency_code = ? AND p.enabled = TRUE " DELIMITED BY SIZE
                  "GROUP BY p.profile_code, p.max_count, p.max_amount " DELIMITED BY SIZE
                  "HAVING COALESCE(SUM(c.used_count), 0) + 1 > p.max_count " DELIMITED BY SIZE
                  "OR COALESCE(SUM(c.used_amount), 0) + ? > p.max_amount) v" DELIMITED BY SIZE
                  INTO WS-PREP-SQL END-STRING
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P2-TRIMMED TO WS-BIND-2
           MOVE WS-P3-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               IF WS-RESULT = "ERROR|NO_DATA"
                   MOVE "SUCCESS|VELOCITY_TXN|OK" TO LS-OUTPUT-BUFFER
               ELSE
                   MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
               END-IF
               EXIT PARAGRAPH
           END-IF.
           MOVE WS-RESULT(1:200) TO WS-VEL-CODES
           IF WS-VEL-CODES = SPACES
               MOVE "SUCCESS|VELOCITY_TXN|OK" TO LS-OUTPUT-BUFFER
           ELSE
               MOVE SPACES TO LS-OUTPUT-BUFFER
               STRING "SUCCESS|VELOCITY_TXN|BLOCKED|" DELIMITED BY SIZE
                      FUNCTION TRIM(WS-VEL-CODES) DELIMITED BY SIZE
                      INTO LS-OUTPUT-BUFFER
               END-STRING
           END-IF.
           EXIT PARAGRAPH.

       ACTION-VEL-RECORD-ALL-TXN.
           *> Internal transfer-path recorder (called by wallet_core inside
           *> the transfer transaction): no BEGIN/COMMIT of its own, no
           *> audit. Advances every ENABLED velocity counter of the sender
           *> currency for the current window, atomically with the money
           *> movement. A missing profile set records zero rows and still
           *> succeeds; only a real DB error fails the transfer closed.
           IF LS-PARAM1 = SPACES OR LS-PARAM2 = SPACES OR LS-PARAM3 = SPACES
               MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
               EXIT PARAGRAPH
           END-IF.
           MOVE SPACES TO WS-PREP-SQL
           STRING "INSERT INTO velocity_counter (account_email, profile_code, window_start, used_count, used_amount) " DELIMITED BY SIZE
                  "SELECT ?, p.profile_code, FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(NOW()) / p.window_seconds) * p.window_seconds), 1, ? " DELIMITED BY SIZE
                  "FROM velocity_profile p WHERE p.currency_code = ? AND p.enabled = TRUE " DELIMITED BY SIZE
                  "ON DUPLICATE KEY UPDATE used_count = used_count + 1, used_amount = used_amount + VALUES(used_amount)" DELIMITED BY SIZE
                  INTO WS-PREP-SQL END-STRING
           MOVE WS-P1-TRIMMED TO WS-BIND-1
           MOVE WS-P3-TRIMMED TO WS-BIND-2
           MOVE WS-P2-TRIMMED TO WS-BIND-3
           CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
               BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
               BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
           END-CALL
           CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
           IF WS-RESULT(1:5) = "ERROR"
               MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
           ELSE
               MOVE "SUCCESS|VELOCITY_TXN_RECORDED" TO LS-OUTPUT-BUFFER
           END-IF.
           EXIT PARAGRAPH.
