        IDENTIFICATION DIVISION.
        PROGRAM-ID. auth_password_core.

        ENVIRONMENT DIVISION.
        CONFIGURATION SECTION.
        SPECIAL-NAMES.
            DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        COPY "auth_password_ws.cpy".

        LINKAGE SECTION.
        01  LS-CMD-ACTION        PIC X(30).
        01  LS-PARAM1            PIC X(100).
        01  LS-PARAM2            PIC X(100).
        01  LS-PARAM3            PIC X(100).
        01  LS-PARAM4            PIC X(100).
        01  LS-PARAM5            PIC X(100).
        01  LS-PARAM6            PIC X(100).
        01  LS-OUTPUT-BUFFER     PIC X(16384).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

        MAIN-LOGIC.
            *> Phase A1 (ADR 0083): shared working-storage now lives in the
            *> copybook; this sub-program still delegates to auth_core. Subsequent
            *> slices (A2-A6) will move the paragraphs here.

            CALL "auth_core" USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER END-CALL
            GOBACK.
