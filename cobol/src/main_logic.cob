       IDENTIFICATION DIVISION.
       PROGRAM-ID. main_logic.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  CMD-ACTION        PIC X(20) VALUE SPACES.
       01  CMD-PARAM1        PIC X(100) VALUE SPACES.
       01  CMD-PARAM2        PIC X(100) VALUE SPACES.
       01  CMD-PARAM3        PIC X(100) VALUE SPACES.
       01  CMD-PARAM4        PIC X(100) VALUE SPACES.
       01  WS-OUTPUT-MSG     PIC X(500) VALUE SPACES.

       PROCEDURE DIVISION.
       
       MAIN-LOGIC.
           ACCEPT CMD-ACTION.
           ACCEPT CMD-PARAM1.
           ACCEPT CMD-PARAM2.
           ACCEPT CMD-PARAM3.
           ACCEPT CMD-PARAM4.

           IF CMD-ACTION = SPACES
               DISPLAY "ERROR|MISSING_ACTION"
               STOP RUN
           END-IF.

            EVALUATE TRUE
                WHEN CMD-ACTION(1:11) = "GET_BALANCE"
                    CALL "wallet_core" USING BY REFERENCE CMD-ACTION 
                                              BY REFERENCE CMD-PARAM1 
                                              BY REFERENCE CMD-PARAM2 
                                              BY REFERENCE CMD-PARAM3
                                              BY REFERENCE CMD-PARAM4
                                              BY REFERENCE WS-OUTPUT-MSG
                    DISPLAY WS-OUTPUT-MSG
               
                WHEN CMD-ACTION(1:8) = "TRANSFER"
                    CALL "wallet_core" USING BY REFERENCE CMD-ACTION 
                                              BY REFERENCE CMD_PARAM1 
                                              BY REFERENCE CMD-PARAM2 
                                              BY REFERENCE CMD-PARAM3
                                              BY REFERENCE CMD-PARAM4
                                              BY REFERENCE WS-OUTPUT-MSG
                    DISPLAY WS-OUTPUT-MSG
               
               WHEN CMD-ACTION(1:8) = "GET_USER"
                   CALL "USER-CORE" USING BY REFERENCE CMD-ACTION 
                                           BY REFERENCE CMD-PARAM1 
                                           BY REFERENCE CMD-PARAM2 
                                           BY REFERENCE CMD-PARAM3 
                                           BY REFERENCE CMD-PARAM4
                                           BY REFERENCE WS-OUTPUT-MSG
                   DISPLAY WS-OUTPUT-MSG
               
               WHEN CMD-ACTION(1:10) = "LIST_USERS"
                   CALL "USER-CORE" USING BY REFERENCE CMD-ACTION 
                                           BY REFERENCE CMD-PARAM1 
                                           BY REFERENCE CMD-PARAM2 
                                           BY REFERENCE CMD-PARAM3 
                                           BY REFERENCE CMD-PARAM4
                                           BY REFERENCE WS-OUTPUT-MSG
                   DISPLAY WS-OUTPUT-MSG
               
               WHEN OTHER
                   DISPLAY "ERROR|INVALID_ACTION"
           END-EVALUATE.
           
           STOP RUN.
