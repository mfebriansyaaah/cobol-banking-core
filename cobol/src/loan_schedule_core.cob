       IDENTIFICATION DIVISION.
       PROGRAM-ID. loan_schedule_core.
      *> Skeleton module for loan_schedule domain.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-VAR-01           PIC X(100) VALUE SPACES.
       01  WS-VAR-02           PIC X(100) VALUE SPACES.
       01  WS-VAR-03           PIC X(100) VALUE SPACES.
       01  WS-VAR-04           PIC X(100) VALUE SPACES.
       01  WS-VAR-05           PIC X(100) VALUE SPACES.
       01  WS-VAR-06           PIC X(100) VALUE SPACES.
       01  WS-VAR-07           PIC X(100) VALUE SPACES.
       01  WS-VAR-08           PIC X(100) VALUE SPACES.
       01  WS-VAR-09           PIC X(100) VALUE SPACES.
       01  WS-VAR-10           PIC X(100) VALUE SPACES.
       01  WS-VAR-11           PIC X(100) VALUE SPACES.
       01  WS-VAR-12           PIC X(100) VALUE SPACES.
       01  WS-VAR-13           PIC X(100) VALUE SPACES.
       01  WS-VAR-14           PIC X(100) VALUE SPACES.
       01  WS-VAR-15           PIC X(100) VALUE SPACES.
       01  WS-VAR-16           PIC X(100) VALUE SPACES.
       01  WS-VAR-17           PIC X(100) VALUE SPACES.
       01  WS-VAR-18           PIC X(100) VALUE SPACES.
       01  WS-VAR-19           PIC X(100) VALUE SPACES.
       01  WS-VAR-20           PIC X(100) VALUE SPACES.
       01  WS-VAR-21           PIC X(100) VALUE SPACES.
       01  WS-VAR-22           PIC X(100) VALUE SPACES.
       01  WS-VAR-23           PIC X(100) VALUE SPACES.
       01  WS-VAR-24           PIC X(100) VALUE SPACES.
       01  WS-VAR-25           PIC X(100) VALUE SPACES.
       01  WS-VAR-26           PIC X(100) VALUE SPACES.
       01  WS-VAR-27           PIC X(100) VALUE SPACES.
       01  WS-VAR-28           PIC X(100) VALUE SPACES.
       01  WS-VAR-29           PIC X(100) VALUE SPACES.
       01  WS-VAR-30           PIC X(100) VALUE SPACES.
       01  WS-VAR-31           PIC X(100) VALUE SPACES.
       01  WS-VAR-32           PIC X(100) VALUE SPACES.
       01  WS-VAR-33           PIC X(100) VALUE SPACES.
       01  WS-VAR-34           PIC X(100) VALUE SPACES.
       01  WS-VAR-35           PIC X(100) VALUE SPACES.
       01  WS-VAR-36           PIC X(100) VALUE SPACES.
       01  WS-VAR-37           PIC X(100) VALUE SPACES.
       01  WS-VAR-38           PIC X(100) VALUE SPACES.
       01  WS-VAR-39           PIC X(100) VALUE SPACES.
       01  WS-VAR-40           PIC X(100) VALUE SPACES.
       01  WS-PRINCIPAL          PIC 9(12)V99 VALUE 0.
       01  WS-RATE               PIC 9(3)V9(6) VALUE 0.
       01  WS-TERM               PIC 9(4) VALUE 0.
       01  WS-MONTHLY-RATE       PIC 9(3)V9(6) VALUE 0.
       01  WS-PAYMENT            PIC 9(12)V99 VALUE 0.
       01  WS-TOTAL-INTEREST     PIC 9(12)V99 VALUE 0.
       01  WS-PAYMENT-TEXT      PIC Z(10).ZZ VALUE 0.
       01  WS-POWER              PIC 9(5)V9(6) VALUE 0.
       01  WS-AMORT-I            PIC 9(4) VALUE 0.
       01  WS-RESULT               PIC X(16384) VALUE SPACES.
       01  WS-P1                   PIC X(100) VALUE SPACES.
       01  WS-P2                   PIC X(100) VALUE SPACES.
       01  WS-P3                   PIC X(100) VALUE SPACES.
       01  WS-P4                   PIC X(100) VALUE SPACES.
       01  WS-P5                   PIC X(100) VALUE SPACES.
       01  WS-P6                   PIC X(100) VALUE SPACES.
       01  WS-I                    PIC 9(5) VALUE 1.
       01  WS-J                    PIC 9(5) VALUE 1.
       01  WS-K                    PIC 9(5) VALUE 1.
       01  WS-L                    PIC 9(5) VALUE 1.
       01  WS-M                    PIC 9(5) VALUE 1.
       01  WS-N                    PIC 9(5) VALUE 1.
       01  WS-O                    PIC 9(5) VALUE 1.
       01  WS-P                    PIC 9(5) VALUE 1.
       01  WS-Q                    PIC 9(5) VALUE 1.
       01  WS-R                    PIC 9(5) VALUE 1.
       01  WS-S                    PIC 9(5) VALUE 1.
       01  WS-T                    PIC 9(5) VALUE 1.
       01  WS-U                    PIC 9(5) VALUE 1.
       01  WS-V                    PIC 9(5) VALUE 1.
       01  WS-W                    PIC 9(5) VALUE 1.
       01  WS-X                    PIC 9(5) VALUE 1.
       01  WS-Y                    PIC 9(5) VALUE 1.
       01  WS-Z                    PIC 9(5) VALUE 1.
       01  WS-STATUS               PIC X(20) VALUE SPACES.
       01  WS-CODE                 PIC X(20) VALUE SPACES.
       01  WS-MESSAGE              PIC X(100) VALUE SPACES.
       01  WS-AUDIT-ACTION         PIC X(40) VALUE SPACES.
       01  WS-AUDIT-DETAIL         PIC X(255) VALUE SPACES.
       01  WS-ACTOR                PIC X(100) VALUE SPACES.
       01  WS-TARGET               PIC X(100) VALUE SPACES.
       01  WS-AMOUNT               PIC X(20) VALUE SPACES.
       01  WS-CURRENCY             PIC X(3) VALUE SPACES.
       01  WS-DATE-VALUE           PIC X(10) VALUE SPACES.
       01  WS-ID-VALUE             PIC X(20) VALUE SPACES.
       01  WS-LIMIT-VALUE          PIC X(10) VALUE SPACES.
       01  WS-OFFSET-VALUE         PIC X(10) VALUE SPACES.
       01  WS-FLAG                 PIC X VALUE 'N'.
           88  FLAG-YES             VALUE 'Y'.
           88  FLAG-NO              VALUE 'N'.
       01  WS-STEP                 PIC X VALUE 'Y'.
           88  STEP-OK             VALUE 'Y'.
           88  STEP-FAIL           VALUE 'N'.

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
           MOVE SPACES TO WS-RESULT
           MOVE LS-PARAM1 TO WS-P1
           MOVE LS-PARAM2 TO WS-P2
           MOVE LS-PARAM3 TO WS-P3
           MOVE LS-PARAM4 TO WS-P4
           MOVE LS-PARAM5 TO WS-P5
           MOVE LS-PARAM6 TO WS-P6
           PERFORM TRIM-ALL
           EVALUATE TRUE
               WHEN LS-CMD-ACTION(1:10) = "LSC_CREATE"
                   PERFORM ACTION-LSC_CREATE
               WHEN LS-CMD-ACTION(1:7) = "LSC_GET"
                   PERFORM ACTION-LSC_GET
               WHEN LS-CMD-ACTION(1:8) = "LSC_LIST"
                   PERFORM ACTION-LSC_LIST
               WHEN LS-CMD-ACTION(1:10) = "LSC_DETAIL"
                   PERFORM ACTION-LSC_DETAIL
               WHEN LS-CMD-ACTION(1:10) = "LSC_UPDATE"
                   PERFORM ACTION-LSC_UPDATE
               WHEN LS-CMD-ACTION(1:10) = "LSC_DELETE"
                   PERFORM ACTION-LSC_DELETE
               WHEN LS-CMD-ACTION(1:10) = "LSC_SEARCH"
                   PERFORM ACTION-LSC_SEARCH
               WHEN LS-CMD-ACTION(1:11) = "LSC_HISTORY"
                   PERFORM ACTION-LSC_HISTORY
               WHEN LS-CMD-ACTION(1:8) = "LSC_CALC"
                   PERFORM ACTION-LSC_CALC
               WHEN LS-CMD-ACTION(1:13) = "LSC_SCHEDULED"
                   PERFORM ACTION-LSC_SCHEDULED
               WHEN LS-CMD-ACTION(1:12) = "LSC_FORECAST"
                   PERFORM ACTION-LSC_FORECAST
               WHEN LS-CMD-ACTION(1:12) = "LSC_OVERRIDE"
                   PERFORM ACTION-LSC_OVERRIDE
               WHEN LS-CMD-ACTION(1:12) = "LSC_VALIDATE"
                   PERFORM ACTION-LSC_VALIDATE
               WHEN LS-CMD-ACTION(1:10) = "LSC_ADJUST"
                   PERFORM ACTION-LSC_ADJUST
               WHEN LS-CMD-ACTION(1:10) = "LSC_STATUS"
                   PERFORM ACTION-LSC_STATUS
               WHEN LS-CMD-ACTION(1:11) = "LSC_APPROVE"
                   PERFORM ACTION-LSC_APPROVE
               WHEN LS-CMD-ACTION(1:10) = "LSC_REJECT"
                   PERFORM ACTION-LSC_REJECT
               WHEN LS-CMD-ACTION(1:9) = "LSC_CLOSE"
                   PERFORM ACTION-LSC_CLOSE
               WHEN LS-CMD-ACTION(1:10) = "LSC_REOPEN"
                   PERFORM ACTION-LSC_REOPEN
               WHEN LS-CMD-ACTION(1:10) = "LSC_CANCEL"
                   PERFORM ACTION-LSC_CANCEL
               WHEN LS-CMD-ACTION(1:8) = "LSC_HOLD"
                   PERFORM ACTION-LSC_HOLD
               WHEN LS-CMD-ACTION(1:11) = "LSC_RELEASE"
                   PERFORM ACTION-LSC_RELEASE
               WHEN LS-CMD-ACTION(1:8) = "LSC_POST"
                   PERFORM ACTION-LSC_POST
               WHEN LS-CMD-ACTION(1:10) = "LSC_ACCRUE"
                   PERFORM ACTION-LSC_ACCRUE
               WHEN LS-CMD-ACTION(1:10) = "LSC_SETTLE"
                   PERFORM ACTION-LSC_SETTLE
               WHEN LS-CMD-ACTION(1:11) = "LSC_SUMMARY"
                   PERFORM ACTION-LSC_SUMMARY
               WHEN LS-CMD-ACTION(1:10) = "LSC_EXPORT"
                   PERFORM ACTION-LSC_EXPORT
               WHEN LS-CMD-ACTION(1:9) = "LSC_AUDIT"
                   PERFORM ACTION-LSC_AUDIT
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO WS-RESULT
           END-EVALUATE
           MOVE WS-RESULT TO LS-OUTPUT-BUFFER
           GOBACK.

       ACTION-LSC_CREATE.
           MOVE "LSC_CREATE_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_CREATE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_GET.
           MOVE "LSC_GET_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_GET" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_LIST.
           MOVE "LSC_LIST_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_LIST" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_DETAIL.
           MOVE "LSC_DETAIL_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_DETAIL" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_UPDATE.
           MOVE "LSC_UPDATE_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_UPDATE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_DELETE.
           MOVE "LSC_DELETE_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_DELETE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_SEARCH.
           MOVE "LSC_SEARCH_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_SEARCH" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_HISTORY.
           MOVE "LSC_HISTORY_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_HISTORY" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_CALC.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           MOVE FUNCTION NUMVAL(WS-P2) TO WS-RATE
           MOVE FUNCTION NUMVAL(WS-P3) TO WS-TERM
           IF WS-TERM = 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           IF WS-RATE = 0
               COMPUTE WS-PAYMENT = WS-PRINCIPAL / WS-TERM
           ELSE
               COMPUTE WS-MONTHLY-RATE = WS-RATE / 1200
               MOVE 1 TO WS-POWER
               PERFORM VARYING WS-AMORT-I FROM 1 BY 1 UNTIL WS-AMORT-I > WS-TERM
                   COMPUTE WS-POWER = WS-POWER * (1 + WS-MONTHLY-RATE)
               END-PERFORM
               COMPUTE WS-MONTHLY-RATE = WS-RATE / 1200
               MOVE 1 TO WS-POWER
               PERFORM VARYING WS-AMORT-I FROM 1 BY 1 UNTIL WS-AMORT-I > WS-TERM
                   COMPUTE WS-POWER = WS-POWER * (1 + WS-MONTHLY-RATE)
               END-PERFORM
               COMPUTE WS-PAYMENT = WS-PRINCIPAL * WS-MONTHLY-RATE * WS-POWER / (WS-POWER - 1)
           END-IF
           MOVE WS-PAYMENT TO WS-PAYMENT-TEXT
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_CALC|" DELIMITED BY SIZE
                  WS-PAYMENT DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING
           EXIT PARAGRAPH.

       ACTION-LSC_SCHEDULED.
           PERFORM ACTION-LSC_CALC
           IF WS-RESULT(1:5) = "ERROR"
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-TOTAL-INTEREST = WS-PAYMENT * WS-TERM - WS-PRINCIPAL
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_SCHEDULED|" DELIMITED BY SIZE
                  WS-PAYMENT DELIMITED BY SIZE "|" DELIMITED BY SIZE
                  WS-TOTAL-INTEREST DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING
           EXIT PARAGRAPH.

       ACTION-LSC_FORECAST.
           PERFORM ACTION-LSC_CALC
           IF WS-RESULT(1:5) = "ERROR"
               EXIT PARAGRAPH
           END-IF
           COMPUTE WS-TOTAL-INTEREST = WS-PAYMENT * WS-TERM - WS-PRINCIPAL
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_FORECAST|" DELIMITED BY SIZE
                  WS-PAYMENT DELIMITED BY SIZE "|" DELIMITED BY SIZE
                  WS-TOTAL-INTEREST DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING
           EXIT PARAGRAPH.

       ACTION-LSC_OVERRIDE.
           MOVE WS-P4 TO WS-P2
           PERFORM ACTION-LSC_CALC
           IF WS-RESULT(1:5) = "ERROR"
               EXIT PARAGRAPH
           END-IF
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_OVERRIDE|" DELIMITED BY SIZE
                  WS-PAYMENT DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING
           EXIT PARAGRAPH.

       ACTION-LSC_VALIDATE.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           MOVE FUNCTION NUMVAL(WS-P2) TO WS-RATE
           MOVE FUNCTION NUMVAL(WS-P3) TO WS-TERM
           IF WS-PRINCIPAL <= 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           IF WS-TERM = 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           IF WS-RATE < 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE "SUCCESS|LSC_VALIDATE|OK" TO WS-RESULT
           EXIT PARAGRAPH.

       ACTION-LSC_ADJUST.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           MOVE FUNCTION NUMVAL(WS-P2) TO WS-TOTAL-INTEREST
           COMPUTE WS-PRINCIPAL = WS-PRINCIPAL + WS-TOTAL-INTEREST
           MOVE SPACES TO WS-RESULT
           STRING "SUCCESS|LSC_ADJUST|" DELIMITED BY SIZE
                  WS-PRINCIPAL DELIMITED BY SIZE
                  INTO WS-RESULT
           END-STRING
           EXIT PARAGRAPH.

       ACTION-LSC_STATUS.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           MOVE FUNCTION NUMVAL(WS-P3) TO WS-TERM
           IF WS-PRINCIPAL <= 0
               MOVE "SUCCESS|LSC_STATUS|CLOSED" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           IF WS-TERM <= 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE "SUCCESS|LSC_STATUS|ACTIVE" TO WS-RESULT
           EXIT PARAGRAPH.

       ACTION-LSC_APPROVE.
           MOVE "LSC_APPROVE_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_APPROVE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_REJECT.
           MOVE "LSC_REJECT_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_REJECT" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_CLOSE.
           MOVE "LSC_CLOSE_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_CLOSE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_REOPEN.
           MOVE "LSC_REOPEN_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_REOPEN" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_CANCEL.
           MOVE FUNCTION NUMVAL(WS-P1) TO WS-PRINCIPAL
           IF WS-PRINCIPAL <= 0
               MOVE "ERROR|INVALID_INPUT" TO WS-RESULT
               EXIT PARAGRAPH
           END-IF
           MOVE "SUCCESS|LSC_CANCEL|CANCELLED" TO WS-RESULT
           EXIT PARAGRAPH.

       ACTION-LSC_HOLD.
           MOVE "LSC_HOLD_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_HOLD" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_RELEASE.
           MOVE "LSC_RELEASE_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_RELEASE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_POST.
           MOVE "LSC_POST_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_POST" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_ACCRUE.
           MOVE "LSC_ACCRUE_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_ACCRUE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_SETTLE.
           MOVE "LSC_SETTLE_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_SETTLE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_SUMMARY.
           MOVE "LSC_SUMMARY_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_SUMMARY" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_EXPORT.
           MOVE "LSC_EXPORT_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_EXPORT" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-LSC_AUDIT.
           MOVE "LSC_AUDIT_OK" TO WS-CODE
           MOVE "SUCCESS|LSC_AUDIT" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       TRIM-ALL.
           MOVE LS-PARAM1 TO WS-P1
           MOVE LS-PARAM2 TO WS-P2
           MOVE LS-PARAM3 TO WS-P3
           MOVE LS-PARAM4 TO WS-P4
           MOVE LS-PARAM5 TO WS-P5
           MOVE LS-PARAM6 TO WS-P6
           EXIT PARAGRAPH.

       VALIDATE-ALL.
           MOVE 'Y' TO WS-STEP
           EXIT PARAGRAPH.

       AUDIT-ACTION.
           MOVE LS-CMD-ACTION TO WS-AUDIT-ACTION
           EXIT PARAGRAPH.

