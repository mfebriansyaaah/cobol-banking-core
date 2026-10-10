       IDENTIFICATION DIVISION.
       PROGRAM-ID. MAIN_LOGIC.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  DB-CONFIG.
           05  DSN-NAME      PIC X(30) VALUE "COBOL_MYSQL".
           05  DB-USER       PIC X(30) VALUE "root".
           05  DB-PASS       PIC X(30) VALUE " ".

       01  CMD-ACTION        PIC X(20) VALUE SPACES.
       01  CMD-PARAM1        PIC X(100) VALUE SPACES.
       01  CMD-PARAM2        PIC X(100) VALUE SPACES.
       01  CMD-PARAM3        PIC X(100) VALUE SPACES.
       01  CMD-PARAM4        PIC X(100) VALUE SPACES.

       01  WS-EXIT-CODE      PIC 9(2) VALUE 0.
       01  WS-OUTPUT-MSG     PIC X(500) VALUE SPACES.

       PROCEDURE DIVISION.
       
       MAIN-LOGIC.
           MOVE 0 TO WS-EXIT-CODE.
           MOVE SPACES TO CMD-ACTION, CMD-PARAM1, CMD-PARAM2, CMD-PARAM3, CMD-PARAM4.

           ACCEPT CMD-ACTION END-ACCEPT.
           ACCEPT CMD-PARAM1 END-ACCEPT.
           ACCEPT CMD-PARAM2 END-ACCEPT.
           ACCEPT CMD-PARAM3 END-ACCEPT.
           ACCEPT CMD-PARAM4 END-ACCEPT.

           IF CMD-ACTION = SPACES
               DISPLAY "ERROR|MISSING_ACTION" END-DISPLAY
               STOP RUN WS-EXIT-CODE
           END-IF.

           EVALUATE TRUE
               WHEN CMD-ACTION = "CHECK_BALANCE"
                   CALL "WALLET-CORE" USING BY REFERENCE CMD-ACTION 
                                             BY REFERENCE CMD-PARAM1 
                                             BY REFERENCE CMD-PARAM2 
                                             BY REFERENCE CMD-PARAM3
                                             BY REFERENCE WS-OUTPUT-MSG
                   END-CALL
                   DISPLAY WS-OUTPUT-MSG END-DISPLAY
               
               WHEN CMD-ACTION = "TRANSFER"
                   CALL "WALLET-CORE" USING BY REFERENCE CMD-ACTION 
                                             BY REFERENCE CMD-PARAM1 
                                             BY REFERENCE CMD-PARAM2 
                                             BY REFERENCE CMD-PARAM3
                                             BY REFERENCE WS-OUTPUT-MSG
                   END-CALL
                   DISPLAY WS-OUTPUT-MSG END-DISPLAY
               
               WHEN CMD-ACTION = "GET_USER"
                   CALL "USER-CORE" USING BY REFERENCE CMD-ACTION 
                                           BY REFERENCE CMD-PARAM1 
                                           BY REFERENCE CMD-PARAM2 
                                           BY REFERENCE CMD-PARAM3 
                                           BY REFERENCE CMD-PARAM4
                                           BY REFERENCE WS-OUTPUT-MSG
                   END-CALL
                   DISPLAY WS-OUTPUT-MSG END-DISPLAY
               
               WHEN CMD-ACTION = "LIST_USERS"
                   CALL "USER-CORE" USING BY REFERENCE CMD-ACTION 
                                           BY REFERENCE CMD-PARAM1 
                                           BY REFERENCE CMD-PARAM2 
                                           BY REFERENCE CMD-PARAM3 
                                           BY REFERENCE CMD-PARAM4
                                           BY REFERENCE WS-OUTPUT-MSG
                   END-CALL
                   DISPLAY WS-OUTPUT-MSG END-DISPLAY
               
               WHEN OTHER
                   MOVE 3 TO WS-EXIT-CODE
                   DISPLAY "ERROR|INVALID_ACTION" END-DISPLAY
           END-EVALUATE.
           
           STOP RUN WS-EXIT-CODE.
