        IDENTIFICATION DIVISION.
        PROGRAM-ID. hashlen_core.

        *> Binary-level split proof (ADR 0083): compute the length of a
        *> NUL-terminated hash buffer. Previously a paragraph in auth_core;
        *> now a standalone program invoked via CALL.

        DATA DIVISION.
        LINKAGE SECTION.
        01  LS-HASH               PIC X(256).
        01  LS-HLEN               PIC 9(3).

        PROCEDURE DIVISION USING LS-HASH LS-HLEN.
        MAIN-LOGIC.
            MOVE 1 TO LS-HLEN
            PERFORM VARYING LS-HLEN FROM 1 BY 1 UNTIL LS-HLEN > 256
                IF LS-HASH(LS-HLEN:1) = LOW-VALUE
                    COMPUTE LS-HLEN = LS-HLEN - 1 END-COMPUTE
                    EXIT PERFORM
                END-IF
            END-PERFORM
            IF LS-HLEN < 1
                MOVE 1 TO LS-HLEN
            END-IF
            GOBACK.
