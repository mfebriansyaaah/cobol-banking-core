        IDENTIFICATION DIVISION.
        PROGRAM-ID. auth_password_core.

        ENVIRONMENT DIVISION.
        CONFIGURATION SECTION.
        SPECIAL-NAMES.
            DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01  WS-OUTPUT-MSG        PIC X(16384) VALUE SPACES.

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
            *> Phase 1 (ADR 0083): facade. Password actions are still implemented
            *> in auth_core; this sub-program delegates so the router can target
            *> the capability module. Subsequent slices will move the paragraphs
            *> here and drop them from auth_core.
            CALL "auth_core" USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER
            GOBACK.
