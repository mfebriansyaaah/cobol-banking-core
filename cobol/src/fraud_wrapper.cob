        IDENTIFICATION DIVISION.
        PROGRAM-ID. FRAUD_WRAPPER.
        AUTHOR. COBOL BACKEND TEAM.
        DATE-WRITTEN. 2026-10-07.

        ENVIRONMENT DIVISION.
        CONFIGURATION SECTION.
        SOURCE-COMPUTER. X86-64.
        OBJECT-COMPUTER. X86-64.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        EXEC SQL INCLUDE SQLCA END-EXEC.

        01  DB-CONFIG.
            05  DSN-NAME      PIC X(30) VALUE "COBOL_MYSQL".
            05  DB-USER       PIC X(30) VALUE "cobol_user".
            05  DB-PASS       PIC X(30) VALUE "cobol_pass".

        01  CMD-INPUT.
            05  CMD-PARAM1    PIC X(100) VALUE SPACES.
            05  CMD-PARAM2    PIC X(100) VALUE SPACES.
            05  CMD-PARAM3    PIC X(100) VALUE SPACES.

        01  WS-EXIT-CODE      PIC 9(2) VALUE 0.
            88  EXIT-SUCCESS         VALUE 0.

        LINKAGE SECTION.
        01  LS-ARG-COUNT      PIC 9(4) COMP-5.
        01  LS-ARG-VALUE     PIC X(100) OCCURS 10 TIMES.

        PROCEDURE DIVISION USING LS-ARG-COUNT LS-ARG-VALUE.
        MAIN-LOGIC.
            IF LS-ARG-COUNT < 5
                DISPLAY "ERROR|MISSING_PARAM|From, To, and Amount required"
                STOP RUN 4
            END-IF.

            MOVE LS-ARG-VALUE(3) TO CMD-PARAM1.
            MOVE LS-ARG-VALUE(4) TO CMD-PARAM2.
            MOVE LS-ARG-VALUE(5) TO CMD-PARAM3.

            * --- STEP 1: EXECUTE LIMIT CHECK VIA AUTH_IDENTITY ---
            CALL "AUTH_IDENTITY" USING LS-ARG-COUNT LS-ARG-VALUE
                WITH CMD-ACTION = "CHECK_LIMITS"
                CMD-PARAM1 = CMD-PARAM1
                CMD-PARAM2 = CMD-PARAM3.
            
            IF WS-EXIT-CODE NOT = 0
                DISPLAY "ERROR|FRAUD_GUARD|Limit Check Failed"
                STOP RUN WS-EXIT-CODE
            END-IF.

            * --- STEP 2: EXECUTE FRAUD DETECTION VIA AUTH_IDENTITY ---
            CALL "AUTH_IDENTITY" USING LS-ARG-COUNT LS-ARG-VALUE
                WITH CMD-ACTION = "DETECT_FRAUD"
                CMD-PARAM1 = CMD-PARAM1.

            IF WS-EXIT-CODE NOT = 0
                DISPLAY "ERROR|FRAUD_GUARD|Fraud Pattern Detected"
                STOP RUN WS-EXIT-CODE
            END-IF.

            * --- STEP 3: EXECUTE ACTUAL TRANSFER ---
            CALL "AUTH_IDENTITY" USING LS-ARG-COUNT LS-ARG-VALUE
                WITH CMD-ACTION = "TRANSFER"
                CMD-PARAM1 = CMD-PARAM1
                CMD-PARAM2 = CMD-PARAM2
                CMD-PARAM3 = CMD-PARAM3.

            STOP RUN WS-EXIT-CODE.
