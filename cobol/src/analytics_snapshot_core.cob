       IDENTIFICATION DIVISION.
       PROGRAM-ID. analytics_snapshot_core.
      *> Skeleton module for analytics_snapshot domain.

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
               WHEN LS-CMD-ACTION(1:10) = "ASP_CREATE"
                   PERFORM ACTION-ASP_CREATE
               WHEN LS-CMD-ACTION(1:8) = "ASP_LIST"
                   PERFORM ACTION-ASP_LIST
               WHEN LS-CMD-ACTION(1:7) = "ASP_GET"
                   PERFORM ACTION-ASP_GET
               WHEN LS-CMD-ACTION(1:8) = "ASP_CALC"
                   PERFORM ACTION-ASP_CALC
               WHEN LS-CMD-ACTION(1:12) = "ASP_VALIDATE"
                   PERFORM ACTION-ASP_VALIDATE
               WHEN LS-CMD-ACTION(1:10) = "ASP_EXPORT"
                   PERFORM ACTION-ASP_EXPORT
               WHEN LS-CMD-ACTION(1:9) = "ASP_AUDIT"
                   PERFORM ACTION-ASP_AUDIT
               WHEN LS-CMD-ACTION(1:10) = "ASP_STATUS"
                   PERFORM ACTION-ASP_STATUS
               WHEN LS-CMD-ACTION(1:9) = "ASP_CLOSE"
                   PERFORM ACTION-ASP_CLOSE
               WHEN LS-CMD-ACTION(1:10) = "ASP_REPORT"
                   PERFORM ACTION-ASP_REPORT
               WHEN LS-CMD-ACTION(1:10) = "ASP_VERIFY"
                   PERFORM ACTION-ASP_VERIFY
               WHEN LS-CMD-ACTION(1:8) = "ASP_SYNC"
                   PERFORM ACTION-ASP_SYNC
               WHEN OTHER
                   MOVE "ERROR|INVALID_ACTION" TO WS-RESULT
           END-EVALUATE
           MOVE WS-RESULT TO LS-OUTPUT-BUFFER
           GOBACK.

       ACTION-ASP_CREATE.
           MOVE "ASP_CREATE_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_CREATE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_LIST.
           MOVE "ASP_LIST_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_LIST" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_GET.
           MOVE "ASP_GET_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_GET" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_CALC.
           MOVE "ASP_CALC_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_CALC" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_VALIDATE.
           MOVE "ASP_VALIDATE_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_VALIDATE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_EXPORT.
           MOVE "ASP_EXPORT_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_EXPORT" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_AUDIT.
           MOVE "ASP_AUDIT_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_AUDIT" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_STATUS.
           MOVE "ASP_STATUS_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_STATUS" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_CLOSE.
           MOVE "ASP_CLOSE_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_CLOSE" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_REPORT.
           MOVE "ASP_REPORT_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_REPORT" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_VERIFY.
           MOVE "ASP_VERIFY_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_VERIFY" TO WS-RESULT
           MOVE WS-VAR-01 TO WS-VAR-02
           MOVE WS-VAR-02 TO WS-VAR-03
           MOVE WS-VAR-03 TO WS-VAR-04
           MOVE WS-VAR-04 TO WS-VAR-05
           MOVE WS-VAR-05 TO WS-VAR-06
           EXIT PARAGRAPH.

       ACTION-ASP_SYNC.
           MOVE "ASP_SYNC_OK" TO WS-CODE
           MOVE "SUCCESS|ASP_SYNC" TO WS-RESULT
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

