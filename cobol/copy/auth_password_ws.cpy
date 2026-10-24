      *> Shared working-storage for the password capability (ADR 0083).
      *> Phase A0: infrastructure only; paragraphs still live in auth_core.cob.
      *> Subsequent slices (A1-A6) will move variables and paragraphs here.
      01  WS-AUTH-PASSWORD-SHARED-VERSION PIC X(8) VALUE "A0".
