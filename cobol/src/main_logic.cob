       IDENTIFICATION DIVISION.
       PROGRAM-ID. main_logic.

        ENVIRONMENT DIVISION.
        CONFIGURATION SECTION.
        SPECIAL-NAMES.
            DECIMAL-POINT IS COMMA.

        INPUT-OUTPUT SECTION.
        FILE-CONTROL.
            SELECT INPUT-FILE ASSIGN TO "input.txt"
                ORGANIZATION IS LINE SEQUENTIAL.
            SELECT OUTPUT-FILE ASSIGN TO "output.txt"
                ORGANIZATION IS LINE SEQUENTIAL.

        DATA DIVISION.
        FILE SECTION.
        FD  INPUT-FILE.
        01  INPUT-RECORD     PIC X(500).
        FD  OUTPUT-FILE.
        01  OUTPUT-RECORD     PIC X(500).

        WORKING-STORAGE SECTION.
        01  INPUT-BUFFER       PIC X(500) VALUE SPACES.
        01  CMD-ACTION        PIC X(20) VALUE SPACES.
        01  CMD-PARAM1        PIC X(100) VALUE SPACES.
        01  CMD-PARAM2        PIC X(100) VALUE SPACES.
        01  CMD-PARAM3        PIC X(100) VALUE SPACES.
        01  CMD-PARAM4        PIC X(100) VALUE SPACES.
        01  CMD-PARAM5        PIC X(100) VALUE SPACES.
        01  CMD-PARAM6        PIC X(100) VALUE SPACES.
        01  WS-OUTPUT-MSG     PIC X(16384) VALUE SPACES.
        01  WS-OUT-LEN        PIC 9(5) VALUE 0.
        01  WS-OUT-POS        PIC 9(5) VALUE 1.
        01  WS-OUT-I          PIC 9(5) VALUE 0.
        01  WS-ARGS           PIC X(200) VALUE SPACES.
        01  WS-SERVE-DONE     PIC X VALUE 'N'.
        01  WS-EOF            PIC X VALUE 'N'.
        01  DISPATCH-COUNT    PIC 9(3) VALUE 0.
        01  DISPATCH-IDX      PIC 9(3) VALUE 1.
        01  DISPATCH-FOUND    PIC X VALUE 'N'.
        01  DISPATCH-TABLE.
            05  DISPATCH-ENTRY OCCURS 1000 TIMES.
                10  D-PREFIX     PIC X(20) VALUE SPACES.
                10  D-PREFIX-LEN PIC 9(2) VALUE 0.
                10  D-PROGRAM   PIC X(32) VALUE SPACES.

        
        PROCEDURE DIVISION.
        
        MAIN-LOGIC.
            PERFORM INIT-DISPATCH-TABLE
            ACCEPT WS-ARGS FROM COMMAND-LINE END-ACCEPT
            IF WS-ARGS(1:7) = "--serve"
                PERFORM SERVE-MODE
            ELSE
                PERFORM FILE-MODE
            END-IF.
            MOVE 0 TO RETURN-CODE.
            STOP RUN.

        FILE-MODE.
            *> Default: read one request line from input.txt, write output.txt.
            OPEN INPUT INPUT-FILE
            OPEN OUTPUT OUTPUT-FILE
            MOVE 'N' TO WS-EOF
            MOVE SPACES TO INPUT-BUFFER
            READ INPUT-FILE INTO INPUT-BUFFER
                AT END MOVE 'Y' TO WS-EOF
            END-READ
            IF WS-EOF NOT = 'Y'
                PERFORM PARSE-INPUT
                PERFORM DISPATCH-ACTION
                PERFORM WRITE-OUTPUT
            END-IF.
            CLOSE INPUT-FILE
            CLOSE OUTPUT-FILE.
            EXIT PARAGRAPH.

        SERVE-MODE.
            *> Long-running mode: one request line per stdin, one result line
            *> per stdout, until QUIT or EOF (used by the worker pool).
            PERFORM UNTIL WS-SERVE-DONE = 'Y'
                MOVE SPACES TO INPUT-BUFFER
                ACCEPT INPUT-BUFFER END-ACCEPT
                IF INPUT-BUFFER = SPACES
                    MOVE 'Y' TO WS-SERVE-DONE
                ELSE
                    IF INPUT-BUFFER(1:4) = "QUIT"
                        MOVE 'Y' TO WS-SERVE-DONE
                    ELSE
                        PERFORM PARSE-INPUT
                        PERFORM DISPATCH-ACTION
                        IF WS-OUTPUT-MSG = SPACES
                            MOVE "ERROR|EMPTY_RESPONSE" TO WS-OUTPUT-MSG
                        END-IF
                        DISPLAY FUNCTION TRIM(WS-OUTPUT-MSG) END-DISPLAY
                    END-IF
                END-IF
            END-PERFORM.
            EXIT PARAGRAPH.

        PARSE-INPUT.
            MOVE SPACES TO CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 CMD-PARAM5 CMD-PARAM6
            UNSTRING INPUT-BUFFER DELIMITED BY "|" 
                INTO CMD-ACTION, CMD-PARAM1, CMD-PARAM2, CMD-PARAM3, CMD-PARAM4, CMD-PARAM5, CMD-PARAM6
            END-UNSTRING.
            EXIT PARAGRAPH.

        INIT-DISPATCH-TABLE.
            MOVE 126 TO DISPATCH-COUNT.
            MOVE "REQUEST_MFA_RECOVERY" TO D-PREFIX(1).
            MOVE 20 TO D-PREFIX-LEN(1).
            MOVE "auth_core" TO D-PROGRAM(1).
            MOVE "REVOKE_OTHER_DEVICES" TO D-PREFIX(2).
            MOVE 20 TO D-PREFIX-LEN(2).
            MOVE "auth_core" TO D-PROGRAM(2).
            MOVE "LIST_RECONCILIATIONS" TO D-PREFIX(3).
            MOVE 20 TO D-PREFIX-LEN(3).
            MOVE "wallet_core" TO D-PROGRAM(3).
            MOVE "APPROVE_MFA_RECOVERY" TO D-PREFIX(4).
            MOVE 20 TO D-PREFIX-LEN(4).
            MOVE "auth_core" TO D-PROGRAM(4).
            MOVE "CONFIRM_EMAIL_CHANGE" TO D-PREFIX(5).
            MOVE 20 TO D-PREFIX-LEN(5).
            MOVE "user_core" TO D-PROGRAM(5).
            MOVE "REVOKE_ALL_SESSIONS" TO D-PREFIX(6).
            MOVE 20 TO D-PREFIX-LEN(6).
            MOVE "auth_core" TO D-PROGRAM(6).
            MOVE "VERIFY_MFA_RECOVERY" TO D-PREFIX(7).
            MOVE 19 TO D-PREFIX-LEN(7).
            MOVE "auth_core" TO D-PROGRAM(7).
            MOVE "RESEND_VERIFICATION" TO D-PREFIX(8).
            MOVE 19 TO D-PREFIX-LEN(8).
            MOVE "auth_core" TO D-PROGRAM(8).
            MOVE "MFA_ENROLL_REQUIRED" TO D-PREFIX(9).
            MOVE 19 TO D-PREFIX-LEN(9).
            MOVE "auth_core" TO D-PROGRAM(9).
            MOVE "CLOSE_ACCESS_REVIEW" TO D-PREFIX(10).
            MOVE 19 TO D-PREFIX-LEN(10).
            MOVE "auth_core" TO D-PROGRAM(10).
            MOVE "LIST_ACCESS_REVIEWS" TO D-PREFIX(11).
            MOVE 19 TO D-PREFIX-LEN(11).
            MOVE "auth_core" TO D-PROGRAM(11).
            MOVE "REVOKE_USER_SESSION" TO D-PREFIX(12).
            MOVE 19 TO D-PREFIX-LEN(12).
            MOVE "auth_core" TO D-PROGRAM(12).
            MOVE "REJECT_MFA_RECOVERY" TO D-PREFIX(13).
            MOVE 19 TO D-PREFIX-LEN(13).
            MOVE "auth_core" TO D-PROGRAM(13).
            MOVE "REVOKE_ACCESS_TOKEN" TO D-PREFIX(14).
            MOVE 19 TO D-PREFIX-LEN(14).
            MOVE "auth_core" TO D-PROGRAM(14).
            MOVE "RUN_RECONCILIATION" TO D-PREFIX(15).
            MOVE 18 TO D-PREFIX-LEN(15).
            MOVE "wallet_core" TO D-PROGRAM(15).
            MOVE "REACTIVATE_DORMANT" TO D-PREFIX(16).
            MOVE 18 TO D-PREFIX-LEN(16).
            MOVE "user_core" TO D-PROGRAM(16).
            MOVE "DECIDE_ACCESS_ITEM" TO D-PREFIX(17).
            MOVE 18 TO D-PREFIX-LEN(17).
            MOVE "auth_core" TO D-PROGRAM(17).
            MOVE "MFA_ENROLL_CONFIRM" TO D-PREFIX(18).
            MOVE 18 TO D-PREFIX-LEN(18).
            MOVE "auth_core" TO D-PROGRAM(18).
            MOVE "OPEN_ACCESS_REVIEW" TO D-PREFIX(19).
            MOVE 18 TO D-PREFIX-LEN(19).
            MOVE "auth_core" TO D-PROGRAM(19).
            MOVE "DEACTIVATE_ACCOUNT" TO D-PREFIX(20).
            MOVE 18 TO D-PREFIX-LEN(20).
            MOVE "user_core" TO D-PROGRAM(20).
            MOVE "REQUEST_OPERATION" TO D-PREFIX(21).
            MOVE 17 TO D-PREFIX-LEN(21).
            MOVE "auth_core" TO D-PROGRAM(21).
            MOVE "LIST_MFA_RECOVERY" TO D-PREFIX(22).
            MOVE 17 TO D-PREFIX-LEN(22).
            MOVE "auth_core" TO D-PROGRAM(22).
            MOVE "RESOLVE_EXCEPTION" TO D-PREFIX(23).
            MOVE 17 TO D-PREFIX-LEN(23).
            MOVE "wallet_core" TO D-PROGRAM(23).
            MOVE "GET_TOKEN_VERSION" TO D-PREFIX(24).
            MOVE 17 TO D-PREFIX-LEN(24).
            MOVE "auth_core" TO D-PROGRAM(24).
            MOVE "GET_ACCESS_REVIEW" TO D-PREFIX(25).
            MOVE 17 TO D-PREFIX-LEN(25).
            MOVE "auth_core" TO D-PROGRAM(25).
            MOVE "APPROVE_REQUEST" TO D-PREFIX(26).
            MOVE 16 TO D-PREFIX-LEN(26).
            MOVE "auth_core" TO D-PROGRAM(26).
            MOVE "LIST_PERMISSIONS" TO D-PREFIX(27).
            MOVE 16 TO D-PREFIX-LEN(27).
            MOVE "auth_core" TO D-PROGRAM(27).
            MOVE "CHECK_PERMISSION" TO D-PREFIX(28).
            MOVE 16 TO D-PREFIX-LEN(28).
            MOVE "auth_core" TO D-PROGRAM(28).
            MOVE "MFA_BACKUP_CODES" TO D-PREFIX(29).
            MOVE 16 TO D-PREFIX-LEN(29).
            MOVE "auth_core" TO D-PROGRAM(29).
            MOVE "REVERSE_TRANSFER" TO D-PREFIX(30).
            MOVE 16 TO D-PREFIX-LEN(30).
            MOVE "wallet_core" TO D-PROGRAM(30).
            MOVE "MFA_ENROLL_BEGIN" TO D-PREFIX(31).
            MOVE 16 TO D-PREFIX-LEN(31).
            MOVE "auth_core" TO D-PROGRAM(31).
            MOVE "STEP_UP_REQUIRED" TO D-PREFIX(32).
            MOVE 16 TO D-PREFIX-LEN(32).
            MOVE "auth_core" TO D-PROGRAM(32).
            MOVE "REQ_EMAIL_CHANGE" TO D-PREFIX(33).
            MOVE 16 TO D-PREFIX-LEN(33).
            MOVE "user_core" TO D-PROGRAM(33).
            MOVE "ADD_DISPUTE_NOTE" TO D-PREFIX(34).
            MOVE 16 TO D-PREFIX-LEN(34).
            MOVE "wallet_core" TO D-PROGRAM(34).
            MOVE "SUSPEND_DORMANT" TO D-PREFIX(35).
            MOVE 15 TO D-PREFIX-LEN(35).
            MOVE "user_core" TO D-PROGRAM(35).
            MOVE "RESOLVE_DISPUTE" TO D-PREFIX(36).
            MOVE 15 TO D-PREFIX-LEN(36).
            MOVE "wallet_core" TO D-PROGRAM(36).
            MOVE "CONSUME_SESSION" TO D-PREFIX(37).
            MOVE 15 TO D-PREFIX-LEN(37).
            MOVE "auth_core" TO D-PROGRAM(37).
            MOVE "LIST_EXCEPTIONS" TO D-PREFIX(38).
            MOVE 15 TO D-PREFIX-LEN(38).
            MOVE "wallet_core" TO D-PROGRAM(38).
            MOVE "ADMIN_RESET_MFA" TO D-PREFIX(39).
            MOVE 15 TO D-PREFIX-LEN(39).
            MOVE "user_core" TO D-PROGRAM(39).
            MOVE "SET_USER_STATUS" TO D-PREFIX(40).
            MOVE 15 TO D-PREFIX-LEN(40).
            MOVE "user_core" TO D-PROGRAM(40).
            MOVE "FORGOT_PASSWORD" TO D-PREFIX(41).
            MOVE 15 TO D-PREFIX-LEN(41).
            MOVE "auth_password_core" TO D-PROGRAM(41).
            MOVE "CHANGE_PASSWORD" TO D-PREFIX(42).
            MOVE 15 TO D-PREFIX-LEN(42).
            MOVE "auth_password_core" TO D-PROGRAM(42).
            MOVE "REJECT_REQUEST" TO D-PREFIX(43).
            MOVE 14 TO D-PREFIX-LEN(43).
            MOVE "auth_core" TO D-PROGRAM(43).
            MOVE "LIST_REQUESTS" TO D-PREFIX(44).
            MOVE 14 TO D-PREFIX-LEN(44).
            MOVE "auth_core" TO D-PROGRAM(44).
            MOVE "REJECT_DISPUTE" TO D-PREFIX(45).
            MOVE 14 TO D-PREFIX-LEN(45).
            MOVE "wallet_core" TO D-PROGRAM(45).
            MOVE "REQUEST_SIGNUP" TO D-PREFIX(46).
            MOVE 14 TO D-PREFIX-LEN(46).
            MOVE "auth_core" TO D-PROGRAM(46).
            MOVE "RESET_PASSWORD" TO D-PREFIX(47).
            MOVE 14 TO D-PREFIX-LEN(47).
            MOVE "auth_password_core" TO D-PROGRAM(47).
            MOVE "UPDATE_PROFILE" TO D-PREFIX(48).
            MOVE 14 TO D-PREFIX-LEN(48).
            MOVE "user_core" TO D-PROGRAM(48).
            MOVE "REVOKE_SESSION" TO D-PREFIX(49).
            MOVE 14 TO D-PREFIX-LEN(49).
            MOVE "auth_core" TO D-PROGRAM(49).
            MOVE "GET_DASHBOARD" TO D-PREFIX(50).
            MOVE 13 TO D-PREFIX-LEN(50).
            MOVE "user_core" TO D-PROGRAM(50).
            MOVE "LIST_SESSIONS" TO D-PREFIX(51).
            MOVE 13 TO D-PREFIX-LEN(51).
            MOVE "auth_core" TO D-PROGRAM(51).
            MOVE "STORE_SESSION" TO D-PREFIX(52).
            MOVE 13 TO D-PREFIX-LEN(52).
            MOVE "auth_core" TO D-PROGRAM(52).
            MOVE "CHECK_BALANCE" TO D-PREFIX(53).
            MOVE 13 TO D-PREFIX-LEN(53).
            MOVE "wallet_core" TO D-PROGRAM(53).
            MOVE "VERIFY_REAUTH" TO D-PREFIX(54).
            MOVE 13 TO D-PREFIX-LEN(54).
            MOVE "auth_core" TO D-PROGRAM(54).
            MOVE "LIST_DISPUTES" TO D-PREFIX(55).
            MOVE 13 TO D-PREFIX-LEN(55).
            MOVE "wallet_core" TO D-PROGRAM(55).
            MOVE "ACK_EXCEPTION" TO D-PREFIX(56).
            MOVE 13 TO D-PREFIX-LEN(56).
            MOVE "wallet_core" TO D-PROGRAM(56).
            MOVE "ARCHIVE_AUDIT" TO D-PREFIX(57).
            MOVE 13 TO D-PREFIX-LEN(57).
            MOVE "auth_core" TO D-PROGRAM(57).
            MOVE "LOGIN_NOTICE" TO D-PREFIX(58).
            MOVE 12 TO D-PREFIX-LEN(58).
            MOVE "auth_core" TO D-PROGRAM(58).
            MOVE "OUTBOX_CLAIM" TO D-PREFIX(59).
            MOVE 12 TO D-PREFIX-LEN(59).
            MOVE "auth_core" TO D-PROGRAM(59).
            MOVE "MARK_DORMANT" TO D-PREFIX(60).
            MOVE 12 TO D-PREFIX-LEN(60).
            MOVE "user_core" TO D-PROGRAM(60).
            MOVE "OPEN_DISPUTE" TO D-PREFIX(61).
            MOVE 12 TO D-PREFIX-LEN(61).
            MOVE "wallet_core" TO D-PROGRAM(61).
            MOVE "LIST_OUTBOX" TO D-PREFIX(62).
            MOVE 12 TO D-PREFIX-LEN(62).
            MOVE "auth_core" TO D-PROGRAM(62).
            MOVE "RELEASE_HOLD" TO D-PREFIX(63).
            MOVE 12 TO D-PREFIX-LEN(63).
            MOVE "wallet_core" TO D-PROGRAM(63).
            MOVE "VERIFY_EMAIL" TO D-PREFIX(64).
            MOVE 12 TO D-PREFIX-LEN(64).
            MOVE "auth_core" TO D-PROGRAM(64).
            MOVE "MFA_DISABLE" TO D-PREFIX(65).
            MOVE 11 TO D-PREFIX-LEN(65).
            MOVE "auth_core" TO D-PROGRAM(65).
            MOVE "CHECK_TOKEN" TO D-PREFIX(66).
            MOVE 11 TO D-PREFIX-LEN(66).
            MOVE "auth_core" TO D-PROGRAM(66).
            MOVE "ACK_DISPUTE" TO D-PREFIX(67).
            MOVE 11 TO D-PREFIX-LEN(67).
            MOVE "wallet_core" TO D-PROGRAM(67).
            MOVE "CHANGE_ROLE" TO D-PREFIX(68).
            MOVE 11 TO D-PREFIX-LEN(68).
            MOVE "auth_core" TO D-PROGRAM(68).
            MOVE "UNLOCK_USER" TO D-PREFIX(69).
            MOVE 11 TO D-PREFIX-LEN(69).
            MOVE "user_core" TO D-PROGRAM(69).
            MOVE "GET_DISPUTE" TO D-PREFIX(70).
            MOVE 11 TO D-PREFIX-LEN(70).
            MOVE "wallet_core" TO D-PROGRAM(70).
            MOVE "OUTBOX_MARK" TO D-PREFIX(71).
            MOVE 11 TO D-PREFIX-LEN(71).
            MOVE "auth_core" TO D-PROGRAM(71).
            MOVE "LIST_USERS" TO D-PREFIX(72).
            MOVE 10 TO D-PREFIX-LEN(72).
            MOVE "user_core" TO D-PROGRAM(72).
            MOVE "PLACE_HOLD" TO D-PREFIX(73).
            MOVE 10 TO D-PREFIX-LEN(73).
            MOVE "wallet_core" TO D-PROGRAM(73).
            MOVE "CHECK_ROLE" TO D-PREFIX(74).
            MOVE 10 TO D-PREFIX-LEN(74).
            MOVE "auth_core" TO D-PROGRAM(74).
            MOVE "AUTH_LOGIN" TO D-PREFIX(75).
            MOVE 10 TO D-PREFIX-LEN(75).
            MOVE "auth_core" TO D-PROGRAM(75).
            MOVE "LIST_AUDIT" TO D-PREFIX(76).
            MOVE 10 TO D-PREFIX-LEN(76).
            MOVE "auth_core" TO D-PROGRAM(76).
            MOVE "TX_STATUS" TO D-PREFIX(77).
            MOVE 9 TO D-PREFIX-LEN(77).
            MOVE "wallet_core" TO D-PROGRAM(77).
            MOVE "RECONCILE" TO D-PREFIX(78).
            MOVE 9 TO D-PREFIX-LEN(78).
            MOVE "wallet_core" TO D-PROGRAM(78).
            MOVE "STATEMENT" TO D-PREFIX(79).
            MOVE 9 TO D-PREFIX-LEN(79).
            MOVE "wallet_core" TO D-PROGRAM(79).
            MOVE "GET_USER" TO D-PREFIX(80).
            MOVE 8 TO D-PREFIX-LEN(80).
            MOVE "user_core" TO D-PROGRAM(80).
            MOVE "TRANSFER" TO D-PREFIX(81).
            MOVE 8 TO D-PREFIX-LEN(81).
            MOVE "wallet_core" TO D-PROGRAM(81).
            MOVE "EODJOB_" TO D-PREFIX(82).
            MOVE 7 TO D-PREFIX-LEN(82).
            MOVE "eod_jobs_core" TO D-PROGRAM(82).
            MOVE "LOAN_" TO D-PREFIX(83).
            MOVE 5 TO D-PREFIX-LEN(83).
            MOVE "loan_core" TO D-PROGRAM(83).
            MOVE "STMT_" TO D-PREFIX(84).
            MOVE 5 TO D-PREFIX-LEN(84).
            MOVE "statement_core" TO D-PROGRAM(84).
            MOVE "CARD_" TO D-PREFIX(85).
            MOVE 5 TO D-PREFIX-LEN(85).
            MOVE "card_core" TO D-PROGRAM(85).
            MOVE "IMPP_" TO D-PREFIX(86).
            MOVE 5 TO D-PREFIX-LEN(86).
            MOVE "import_post_core" TO D-PROGRAM(86).
            MOVE "TRL_" TO D-PREFIX(87).
            MOVE 4 TO D-PREFIX-LEN(87).
            MOVE "treasury_liquidity_core" TO D-PROGRAM(87).
            MOVE "SRC_" TO D-PREFIX(88).
            MOVE 4 TO D-PREFIX-LEN(88).
            MOVE "statement_recon_core" TO D-PROGRAM(88).
            MOVE "RPB_" TO D-PREFIX(89).
            MOVE 4 TO D-PREFIX-LEN(89).
            MOVE "report_builder_core" TO D-PROGRAM(89).
            MOVE "BDR_" TO D-PREFIX(90).
            MOVE 4 TO D-PREFIX-LEN(90).
            MOVE "backup_drill_core" TO D-PROGRAM(90).
            MOVE "PMC_" TO D-PREFIX(91).
            MOVE 4 TO D-PREFIX-LEN(91).
            MOVE "payment_clearing_core" TO D-PROGRAM(91).
            MOVE "LSC_" TO D-PREFIX(92).
            MOVE 4 TO D-PREFIX-LEN(92).
            MOVE "loan_schedule_core" TO D-PROGRAM(92).
            MOVE "FEE_" TO D-PREFIX(93).
            MOVE 4 TO D-PREFIX-LEN(93).
            MOVE "fee_core" TO D-PROGRAM(93).
            MOVE "RPT_" TO D-PREFIX(94).
            MOVE 4 TO D-PREFIX-LEN(94).
            MOVE "report_core" TO D-PROGRAM(94).
            MOVE "PAY_" TO D-PREFIX(95).
            MOVE 4 TO D-PREFIX-LEN(95).
            MOVE "payment_core" TO D-PROGRAM(95).
            MOVE "EOD_" TO D-PREFIX(96).
            MOVE 4 TO D-PREFIX-LEN(96).
            MOVE "eod_core" TO D-PROGRAM(96).
            MOVE "PIC_" TO D-PREFIX(97).
            MOVE 4 TO D-PREFIX-LEN(97).
            MOVE "payment_instruction_core" TO D-PROGRAM(97).
            MOVE "PING" TO D-PREFIX(98).
            MOVE 4 TO D-PREFIX-LEN(98).
            MOVE "auth_core" TO D-PROGRAM(98).
            MOVE "DSH_" TO D-PREFIX(99).
            MOVE 4 TO D-PREFIX-LEN(99).
            MOVE "dashboard_core" TO D-PROGRAM(99).
            MOVE "IMP_" TO D-PREFIX(100).
            MOVE 4 TO D-PREFIX-LEN(100).
            MOVE "import_core" TO D-PROGRAM(100).
            MOVE "FAS_" TO D-PREFIX(101).
            MOVE 4 TO D-PREFIX-LEN(101).
            MOVE "fixed_asset_core" TO D-PROGRAM(101).
            MOVE "CSC_" TO D-PREFIX(102).
            MOVE 4 TO D-PREFIX-LEN(102).
            MOVE "cost_center_core" TO D-PROGRAM(102).
            MOVE "IRC_" TO D-PREFIX(103).
            MOVE 4 TO D-PREFIX-LEN(103).
            MOVE "import_recon_core" TO D-PROGRAM(103).
            MOVE "ACC_" TO D-PREFIX(104).
            MOVE 4 TO D-PREFIX-LEN(104).
            MOVE "account_core" TO D-PROGRAM(104).
            MOVE "VEL_" TO D-PREFIX(105).
            MOVE 4 TO D-PREFIX-LEN(105).
            MOVE "fee_core" TO D-PROGRAM(105).
            MOVE "GLA_" TO D-PREFIX(106).
            MOVE 4 TO D-PREFIX-LEN(106).
            MOVE "gl_allocation_core" TO D-PROGRAM(106).
            MOVE "DEP_" TO D-PREFIX(107).
            MOVE 4 TO D-PREFIX-LEN(107).
            MOVE "deposit_core" TO D-PROGRAM(107).
            MOVE "COL_" TO D-PREFIX(108).
            MOVE 4 TO D-PREFIX-LEN(108).
            MOVE "collection_core" TO D-PROGRAM(108).
            MOVE "RFE_" TO D-PREFIX(109).
            MOVE 4 TO D-PREFIX-LEN(109).
            MOVE "ref_engine" TO D-PROGRAM(109).
            MOVE "PHL_" TO D-PREFIX(110).
            MOVE 4 TO D-PREFIX-LEN(110).
            MOVE "payment_hold_core" TO D-PROGRAM(110).
            MOVE "CLT_" TO D-PREFIX(111).
            MOVE 4 TO D-PREFIX-LEN(111).
            MOVE "collateral_core" TO D-PROGRAM(111).
            MOVE "RX_" TO D-PREFIX(112).
            MOVE 3 TO D-PREFIX-LEN(112).
            MOVE "ref_ext_core" TO D-PROGRAM(112).
            MOVE "GL_" TO D-PREFIX(113).
            MOVE 3 TO D-PREFIX-LEN(113).
            MOVE "gl_core" TO D-PROGRAM(113).
            MOVE "MRT_" TO D-PREFIX(114).
            MOVE 4 TO D-PREFIX-LEN(114).
            MOVE "merchant_core" TO D-PROGRAM(114).
            MOVE "NTP_" TO D-PREFIX(115).
            MOVE 4 TO D-PREFIX-LEN(115).
            MOVE "notification_template_core" TO D-PROGRAM(115).
            MOVE "RPS_" TO D-PREFIX(116).
            MOVE 4 TO D-PREFIX-LEN(116).
            MOVE "report_schedule_core" TO D-PROGRAM(116).
            MOVE "SLT_" TO D-PREFIX(117).
            MOVE 4 TO D-PREFIX-LEN(117).
            MOVE "sla_tracker_core" TO D-PROGRAM(117).
            MOVE "CCL_" TO D-PREFIX(118).
            MOVE 4 TO D-PREFIX-LEN(118).
            MOVE "compliance_calendar_core" TO D-PROGRAM(118).
            MOVE "LOC_" TO D-PREFIX(119).
            MOVE 4 TO D-PREFIX-LEN(119).
            MOVE "letter_of_credit_core" TO D-PROGRAM(119).
            MOVE "BKG_" TO D-PREFIX(120).
            MOVE 4 TO D-PREFIX-LEN(120).
            MOVE "bank_guarantee_core" TO D-PROGRAM(120).
            MOVE "PRL_" TO D-PREFIX(121).
            MOVE 4 TO D-PREFIX-LEN(121).
            MOVE "payroll_processing_core" TO D-PROGRAM(121).
            MOVE "MCS_" TO D-PREFIX(122).
            MOVE 4 TO D-PREFIX-LEN(122).
            MOVE "merchant_settlement_core" TO D-PROGRAM(122).
            MOVE "TXM_" TO D-PREFIX(123).
            MOVE 4 TO D-PREFIX-LEN(123).
            MOVE "tax_management_core" TO D-PROGRAM(123).
            MOVE "CHB_" TO D-PREFIX(124).
            MOVE 4 TO D-PREFIX-LEN(124).
            MOVE "chargeback_core" TO D-PROGRAM(124).
            MOVE "LOY_" TO D-PREFIX(125).
            MOVE 4 TO D-PREFIX-LEN(125).
            MOVE "loyalty_core" TO D-PROGRAM(125).
            MOVE "OTP_" TO D-PREFIX(126).
            MOVE 4 TO D-PREFIX-LEN(126).
            MOVE "phone_otp_core" TO D-PROGRAM(126).
            EXIT PARAGRAPH.

        DISPATCH-ACTION.
            *> Table-driven dispatch: longest prefix first.
            MOVE 'N' TO DISPATCH-FOUND
            MOVE 1 TO DISPATCH-IDX
            PERFORM UNTIL DISPATCH-IDX > DISPATCH-COUNT OR DISPATCH-FOUND = 'Y'
                IF D-PREFIX-LEN(DISPATCH-IDX) > 0
                    IF CMD-ACTION(1:D-PREFIX-LEN(DISPATCH-IDX)) = D-PREFIX(DISPATCH-IDX)(1:D-PREFIX-LEN(DISPATCH-IDX))
                        MOVE 'Y' TO DISPATCH-FOUND
                        IF D-PROGRAM(DISPATCH-IDX) = "user_core"
                            CALL D-PROGRAM(DISPATCH-IDX) USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 WS-OUTPUT-MSG
                                END-CALL
                        ELSE
                            CALL D-PROGRAM(DISPATCH-IDX) USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 CMD-PARAM5 CMD-PARAM6 WS-OUTPUT-MSG
                                END-CALL
                        END-IF
                    END-IF
                END-IF
                ADD 1 TO DISPATCH-IDX
                END-ADD
            END-PERFORM
            IF DISPATCH-FOUND = 'N'
                IF CMD-ACTION = SPACES
                    MOVE "ERROR|MISSING_ACTION" TO WS-OUTPUT-MSG
                ELSE
                    MOVE "ERROR|INVALID_ACTION" TO WS-OUTPUT-MSG
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        WRITE-OUTPUT.
            *> Emit WS-OUTPUT-MSG as one or more 500-char records. The gateway
            *> joins the lines back; trailing spaces in each line are padding.
            MOVE 0 TO WS-OUT-LEN
            PERFORM VARYING WS-OUT-I FROM 16384 BY -1 UNTIL WS-OUT-I < 1 OR WS-OUT-LEN > 0
                IF WS-OUTPUT-MSG(WS-OUT-I:1) NOT = SPACE
                    MOVE WS-OUT-I TO WS-OUT-LEN
                END-IF
            END-PERFORM
            IF WS-OUT-LEN = 0
                MOVE SPACES TO OUTPUT-RECORD
                WRITE OUTPUT-RECORD END-WRITE
                EXIT PARAGRAPH
            END-IF
            PERFORM VARYING WS-OUT-POS FROM 1 BY 500 UNTIL WS-OUT-POS > WS-OUT-LEN
                MOVE WS-OUTPUT-MSG(WS-OUT-POS:500) TO OUTPUT-RECORD
                WRITE OUTPUT-RECORD END-WRITE
            END-PERFORM.
            EXIT PARAGRAPH.
