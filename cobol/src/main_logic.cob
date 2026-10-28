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
            05  DISPATCH-ENTRY OCCURS 500 TIMES.
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
            MOVE 270 TO DISPATCH-COUNT.
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
            MOVE "BATCH_" TO D-PREFIX(83).
            MOVE 6 TO D-PREFIX-LEN(83).
            MOVE "batch_core" TO D-PROGRAM(83).
            MOVE "RECON_" TO D-PREFIX(84).
            MOVE 6 TO D-PREFIX-LEN(84).
            MOVE "recon_core" TO D-PROGRAM(84).
            MOVE "LOAN_" TO D-PREFIX(85).
            MOVE 5 TO D-PREFIX-LEN(85).
            MOVE "loan_core" TO D-PROGRAM(85).
            MOVE "STMT_" TO D-PREFIX(86).
            MOVE 5 TO D-PREFIX-LEN(86).
            MOVE "statement_core" TO D-PROGRAM(86).
            MOVE "CARD_" TO D-PREFIX(87).
            MOVE 5 TO D-PREFIX-LEN(87).
            MOVE "card_core" TO D-PROGRAM(87).
            MOVE "IMPP_" TO D-PREFIX(88).
            MOVE 5 TO D-PREFIX-LEN(88).
            MOVE "import_post_core" TO D-PROGRAM(88).
            MOVE "ALE_" TO D-PREFIX(89).
            MOVE 4 TO D-PREFIX-LEN(89).
            MOVE "alert_escalation_core" TO D-PROGRAM(89).
            MOVE "TRL_" TO D-PREFIX(90).
            MOVE 4 TO D-PREFIX-LEN(90).
            MOVE "treasury_liquidity_core" TO D-PROGRAM(90).
            MOVE "SRC_" TO D-PREFIX(91).
            MOVE 4 TO D-PREFIX-LEN(91).
            MOVE "statement_recon_core" TO D-PROGRAM(91).
            MOVE "REG_" TO D-PREFIX(92).
            MOVE 4 TO D-PREFIX-LEN(92).
            MOVE "regulatory_report_core" TO D-PROGRAM(92).
            MOVE "DOC_" TO D-PREFIX(93).
            MOVE 4 TO D-PREFIX-LEN(93).
            MOVE "document_core" TO D-PROGRAM(93).
            MOVE "FRC_" TO D-PREFIX(94).
            MOVE 4 TO D-PREFIX-LEN(94).
            MOVE "fraud_case_core" TO D-PROGRAM(94).
            MOVE "IRT_" TO D-PREFIX(95).
            MOVE 4 TO D-PREFIX-LEN(95).
            MOVE "interest_rate_core" TO D-PROGRAM(95).
            MOVE "IPM_" TO D-PREFIX(96).
            MOVE 4 TO D-PREFIX-LEN(96).
            MOVE "incident_postmortem_core" TO D-PROGRAM(96).
            MOVE "RPB_" TO D-PREFIX(97).
            MOVE 4 TO D-PREFIX-LEN(97).
            MOVE "report_builder_core" TO D-PROGRAM(97).
            MOVE "PRD_" TO D-PREFIX(98).
            MOVE 4 TO D-PREFIX-LEN(98).
            MOVE "product_catalog_core" TO D-PROGRAM(98).
            MOVE "BDR_" TO D-PREFIX(99).
            MOVE 4 TO D-PREFIX-LEN(99).
            MOVE "backup_drill_core" TO D-PROGRAM(99).
            MOVE "PMC_" TO D-PREFIX(100).
            MOVE 4 TO D-PREFIX-LEN(100).
            MOVE "payment_clearing_core" TO D-PROGRAM(100).
            MOVE "PAT_" TO D-PREFIX(101).
            MOVE 4 TO D-PREFIX-LEN(101).
            MOVE "policy_attestation_core" TO D-PROGRAM(101).
            MOVE "ALT_" TO D-PREFIX(102).
            MOVE 4 TO D-PREFIX-LEN(102).
            MOVE "alert_core" TO D-PROGRAM(102).
            MOVE "LSC_" TO D-PREFIX(103).
            MOVE 4 TO D-PREFIX-LEN(103).
            MOVE "loan_schedule_core" TO D-PROGRAM(103).
            MOVE "EXP_" TO D-PREFIX(104).
            MOVE 4 TO D-PREFIX-LEN(104).
            MOVE "export_archive_core" TO D-PROGRAM(104).
            MOVE "SCL_" TO D-PREFIX(105).
            MOVE 4 TO D-PREFIX-LEN(105).
            MOVE "sanctions_list_core" TO D-PROGRAM(105).
            MOVE "LBP_" TO D-PREFIX(106).
            MOVE 4 TO D-PREFIX-LEN(106).
            MOVE "lbpue_core" TO D-PROGRAM(106).
            MOVE "AAU_" TO D-PREFIX(107).
            MOVE 4 TO D-PREFIX-LEN(107).
            MOVE "access_audit_core" TO D-PROGRAM(107).
            MOVE "FEE_" TO D-PREFIX(108).
            MOVE 4 TO D-PREFIX-LEN(108).
            MOVE "fee_core" TO D-PROGRAM(108).
            MOVE "DLN_" TO D-PREFIX(109).
            MOVE 4 TO D-PREFIX-LEN(109).
            MOVE "data_lineage_core" TO D-PROGRAM(109).
            MOVE "DSN_" TO D-PREFIX(110).
            MOVE 4 TO D-PREFIX-LEN(110).
            MOVE "dispute_notify_core" TO D-PROGRAM(110).
            MOVE "RSC_" TO D-PREFIX(111).
            MOVE 4 TO D-PREFIX-LEN(111).
            MOVE "report_scheduler_core" TO D-PROGRAM(111).
            MOVE "RAU_" TO D-PREFIX(112).
            MOVE 4 TO D-PREFIX-LEN(112).
            MOVE "report_audit_core" TO D-PROGRAM(112).
            MOVE "KCP_" TO D-PREFIX(113).
            MOVE 4 TO D-PREFIX-LEN(113).
            MOVE "kyc_periodic_core" TO D-PROGRAM(113).
            MOVE "RSK_" TO D-PREFIX(114).
            MOVE 4 TO D-PREFIX-LEN(114).
            MOVE "risk_screening_core" TO D-PROGRAM(114).
            MOVE "STL_" TO D-PREFIX(115).
            MOVE 4 TO D-PREFIX-LEN(115).
            MOVE "statement_delivery_core" TO D-PROGRAM(115).
            MOVE "BKP_" TO D-PREFIX(116).
            MOVE 4 TO D-PREFIX-LEN(116).
            MOVE "backup_restore_core" TO D-PROGRAM(116).
            MOVE "GRL_" TO D-PREFIX(117).
            MOVE 4 TO D-PREFIX-LEN(117).
            MOVE "gl_reval_core" TO D-PROGRAM(117).
            MOVE "RPT_" TO D-PREFIX(118).
            MOVE 4 TO D-PREFIX-LEN(118).
            MOVE "report_core" TO D-PROGRAM(118).
            MOVE "PAY_" TO D-PREFIX(119).
            MOVE 4 TO D-PREFIX-LEN(119).
            MOVE "payment_core" TO D-PROGRAM(119).
            MOVE "DSP_" TO D-PREFIX(120).
            MOVE 4 TO D-PREFIX-LEN(120).
            MOVE "dispute_ops_core" TO D-PROGRAM(120).
            MOVE "EOD_" TO D-PREFIX(121).
            MOVE 4 TO D-PREFIX-LEN(121).
            MOVE "eod_core" TO D-PROGRAM(121).
            MOVE "KYC_" TO D-PREFIX(122).
            MOVE 4 TO D-PREFIX-LEN(122).
            MOVE "kyc_review_core" TO D-PROGRAM(122).
            MOVE "AMT_" TO D-PREFIX(123).
            MOVE 4 TO D-PREFIX-LEN(123).
            MOVE "asset_maintenance_core" TO D-PROGRAM(123).
            MOVE "SLO_" TO D-PREFIX(124).
            MOVE 4 TO D-PREFIX-LEN(124).
            MOVE "slo_report_core" TO D-PROGRAM(124).
            MOVE "TAX_" TO D-PREFIX(125).
            MOVE 4 TO D-PREFIX-LEN(125).
            MOVE "tax_report_core" TO D-PROGRAM(125).
            MOVE "FXH_" TO D-PREFIX(126).
            MOVE 4 TO D-PREFIX-LEN(126).
            MOVE "fx_hedging_core" TO D-PROGRAM(126).
            MOVE "ONC_" TO D-PREFIX(127).
            MOVE 4 TO D-PREFIX-LEN(127).
            MOVE "oncall_core" TO D-PROGRAM(127).
            MOVE "ARE_" TO D-PREFIX(128).
            MOVE 4 TO D-PREFIX-LEN(128).
            MOVE "audit_retention_core" TO D-PROGRAM(128).
            MOVE "NTF_" TO D-PREFIX(129).
            MOVE 4 TO D-PREFIX-LEN(129).
            MOVE "notification_core" TO D-PROGRAM(129).
            MOVE "PIC_" TO D-PREFIX(130).
            MOVE 4 TO D-PREFIX-LEN(130).
            MOVE "payment_instruction_core" TO D-PROGRAM(130).
            MOVE "PAL_" TO D-PREFIX(131).
            MOVE 4 TO D-PREFIX-LEN(131).
            MOVE "pipeline_alert_core" TO D-PROGRAM(131).
            MOVE "FWV_" TO D-PREFIX(132).
            MOVE 4 TO D-PREFIX-LEN(132).
            MOVE "fee_waiver_core" TO D-PROGRAM(132).
            MOVE "SCR_" TO D-PREFIX(133).
            MOVE 4 TO D-PREFIX-LEN(133).
            MOVE "secret_rotation_core" TO D-PROGRAM(133).
            MOVE "PING" TO D-PREFIX(134).
            MOVE 4 TO D-PREFIX-LEN(134).
            MOVE "auth_core" TO D-PROGRAM(134).
            MOVE "DSH_" TO D-PREFIX(135).
            MOVE 4 TO D-PREFIX-LEN(135).
            MOVE "dashboard_core" TO D-PROGRAM(135).
            MOVE "CHA_" TO D-PREFIX(136).
            MOVE 4 TO D-PREFIX-LEN(136).
            MOVE "change_approval_core" TO D-PROGRAM(136).
            MOVE "IMP_" TO D-PREFIX(137).
            MOVE 4 TO D-PREFIX-LEN(137).
            MOVE "import_core" TO D-PROGRAM(137).
            MOVE "WFA_" TO D-PREFIX(138).
            MOVE 4 TO D-PREFIX-LEN(138).
            MOVE "workflow_approval_core" TO D-PROGRAM(138).
            MOVE "FOP_" TO D-PREFIX(139).
            MOVE 4 TO D-PREFIX-LEN(139).
            MOVE "fraud_ops_core" TO D-PROGRAM(139).
            MOVE "TRP_" TO D-PREFIX(140).
            MOVE 4 TO D-PREFIX-LEN(140).
            MOVE "treasury_position_core" TO D-PROGRAM(140).
            MOVE "GPC_" TO D-PREFIX(141).
            MOVE 4 TO D-PREFIX-LEN(141).
            MOVE "gl_period_close_core" TO D-PROGRAM(141).
            MOVE "SLA_" TO D-PREFIX(142).
            MOVE 4 TO D-PREFIX-LEN(142).
            MOVE "sla_tracking_core" TO D-PROGRAM(142).
            MOVE "INC_" TO D-PREFIX(143).
            MOVE 4 TO D-PREFIX-LEN(143).
            MOVE "incident_core" TO D-PROGRAM(143).
            MOVE "DRT_" TO D-PREFIX(144).
            MOVE 4 TO D-PREFIX-LEN(144).
            MOVE "data_retention_core" TO D-PROGRAM(144).
            MOVE "XST_" TO D-PREFIX(145).
            MOVE 4 TO D-PREFIX-LEN(145).
            MOVE "export_stream_core" TO D-PROGRAM(145).
            MOVE "DSR_" TO D-PREFIX(146).
            MOVE 4 TO D-PREFIX-LEN(146).
            MOVE "dsar_core" TO D-PROGRAM(146).
            MOVE "VCC_" TO D-PREFIX(147).
            MOVE 4 TO D-PREFIX-LEN(147).
            MOVE "vendor_compliance_core" TO D-PROGRAM(147).
            MOVE "CNS_" TO D-PREFIX(148).
            MOVE 4 TO D-PREFIX-LEN(148).
            MOVE "consolidation_core" TO D-PROGRAM(148).
            MOVE "CFC_" TO D-PREFIX(149).
            MOVE 4 TO D-PREFIX-LEN(149).
            MOVE "capacity_forecast_core" TO D-PROGRAM(149).
            MOVE "FAS_" TO D-PREFIX(150).
            MOVE 4 TO D-PREFIX-LEN(150).
            MOVE "fixed_asset_core" TO D-PROGRAM(150).
            MOVE "LHO_" TO D-PREFIX(151).
            MOVE 4 TO D-PREFIX-LEN(151).
            MOVE "legal_hold_core" TO D-PROGRAM(151).
            MOVE "BLP_" TO D-PREFIX(152).
            MOVE 4 TO D-PREFIX-LEN(152).
            MOVE "billpay_core" TO D-PROGRAM(152).
            MOVE "CST_" TO D-PREFIX(153).
            MOVE 4 TO D-PREFIX-LEN(153).
            MOVE "customer_core" TO D-PROGRAM(153).
            MOVE "CSC_" TO D-PREFIX(154).
            MOVE 4 TO D-PREFIX-LEN(154).
            MOVE "cost_center_core" TO D-PROGRAM(154).
            MOVE "BUD_" TO D-PREFIX(155).
            MOVE 4 TO D-PREFIX-LEN(155).
            MOVE "budget_core" TO D-PROGRAM(155).
            MOVE "ADR_" TO D-PREFIX(156).
            MOVE 4 TO D-PREFIX-LEN(156).
            MOVE "audit_drilldown_core" TO D-PROGRAM(156).
            MOVE "IRC_" TO D-PREFIX(157).
            MOVE 4 TO D-PREFIX-LEN(157).
            MOVE "import_recon_core" TO D-PROGRAM(157).
            MOVE "ACC_" TO D-PREFIX(158).
            MOVE 4 TO D-PREFIX-LEN(158).
            MOVE "account_core" TO D-PROGRAM(158).
            MOVE "SHL_" TO D-PREFIX(159).
            MOVE 4 TO D-PREFIX-LEN(159).
            MOVE "sanctions_hold_core" TO D-PROGRAM(159).
            MOVE "NAU_" TO D-PREFIX(160).
            MOVE 4 TO D-PREFIX-LEN(160).
            MOVE "notification_audit_core" TO D-PROGRAM(160).
            MOVE "KRO_" TO D-PREFIX(161).
            MOVE 4 TO D-PREFIX-LEN(161).
            MOVE "key_rotation_core" TO D-PROGRAM(161).
            MOVE "STO_" TO D-PREFIX(162).
            MOVE 4 TO D-PREFIX-LEN(162).
            MOVE "standing_order_core" TO D-PROGRAM(162).
            MOVE "AST_" TO D-PREFIX(163).
            MOVE 4 TO D-PREFIX-LEN(163).
            MOVE "asset_core" TO D-PROGRAM(163).
            MOVE "ODL_" TO D-PREFIX(164).
            MOVE 4 TO D-PREFIX-LEN(164).
            MOVE "oncall_delivery_core" TO D-PROGRAM(164).
            MOVE "REX_" TO D-PREFIX(165).
            MOVE 4 TO D-PREFIX-LEN(165).
            MOVE "recon_exception_core" TO D-PROGRAM(165).
            MOVE "VEL_" TO D-PREFIX(166).
            MOVE 4 TO D-PREFIX-LEN(166).
            MOVE "fee_core" TO D-PROGRAM(166).
            MOVE "DRC_" TO D-PREFIX(167).
            MOVE 4 TO D-PREFIX-LEN(167).
            MOVE "disaster_recovery_core" TO D-PROGRAM(167).
            MOVE "RPA_" TO D-PREFIX(168).
            MOVE 4 TO D-PREFIX-LEN(168).
            MOVE "report_archive_core" TO D-PROGRAM(168).
            MOVE "CEX_" TO D-PREFIX(169).
            MOVE 4 TO D-PREFIX-LEN(169).
            MOVE "compliance_export_core" TO D-PROGRAM(169).
            MOVE "VRK_" TO D-PREFIX(170).
            MOVE 4 TO D-PREFIX-LEN(170).
            MOVE "vendor_risk_core" TO D-PROGRAM(170).
            MOVE "RMT_" TO D-PREFIX(171).
            MOVE 4 TO D-PREFIX-LEN(171).
            MOVE "remittance_core" TO D-PROGRAM(171).
            MOVE "GLA_" TO D-PREFIX(172).
            MOVE 4 TO D-PREFIX-LEN(172).
            MOVE "gl_allocation_core" TO D-PROGRAM(172).
            MOVE "STR_" TO D-PREFIX(173).
            MOVE 4 TO D-PREFIX-LEN(173).
            MOVE "settlement_recon_core" TO D-PROGRAM(173).
            MOVE "FXD_" TO D-PREFIX(174).
            MOVE 4 TO D-PREFIX-LEN(174).
            MOVE "fx_deal_core" TO D-PROGRAM(174).
            MOVE "VND_" TO D-PREFIX(175).
            MOVE 4 TO D-PREFIX-LEN(175).
            MOVE "vendor_core" TO D-PROGRAM(175).
            MOVE "RCP_" TO D-PREFIX(176).
            MOVE 4 TO D-PREFIX-LEN(176).
            MOVE "recon_ops_core" TO D-PROGRAM(176).
            MOVE "DEP_" TO D-PREFIX(177).
            MOVE 4 TO D-PREFIX-LEN(177).
            MOVE "deposit_core" TO D-PROGRAM(177).
            MOVE "PRC_" TO D-PREFIX(178).
            MOVE 4 TO D-PREFIX-LEN(178).
            MOVE "procurement_core" TO D-PROGRAM(178).
            MOVE "BKV_" TO D-PREFIX(179).
            MOVE 4 TO D-PREFIX-LEN(179).
            MOVE "backup_verification_core" TO D-PROGRAM(179).
            MOVE "ASN_" TO D-PREFIX(180).
            MOVE 4 TO D-PREFIX-LEN(180).
            MOVE "audit_snapshot_core" TO D-PROGRAM(180).
            MOVE "COL_" TO D-PREFIX(181).
            MOVE 4 TO D-PREFIX-LEN(181).
            MOVE "collection_core" TO D-PROGRAM(181).
            MOVE "MDF_" TO D-PREFIX(182).
            MOVE 4 TO D-PREFIX-LEN(182).
            MOVE "metric_definition_core" TO D-PROGRAM(182).
            MOVE "RTJ_" TO D-PREFIX(183).
            MOVE 4 TO D-PREFIX-LEN(183).
            MOVE "retention_job_core" TO D-PROGRAM(183).
            MOVE "DQC_" TO D-PREFIX(184).
            MOVE 4 TO D-PREFIX-LEN(184).
            MOVE "data_quality_core" TO D-PROGRAM(184).
            MOVE "AML_" TO D-PREFIX(185).
            MOVE 4 TO D-PREFIX-LEN(185).
            MOVE "aml_screening_core" TO D-PROGRAM(185).
            MOVE "CAP_" TO D-PREFIX(186).
            MOVE 4 TO D-PREFIX-LEN(186).
            MOVE "capacity_plan_core" TO D-PROGRAM(186).
            MOVE "RDL_" TO D-PREFIX(187).
            MOVE 4 TO D-PREFIX-LEN(187).
            MOVE "report_delivery_core" TO D-PROGRAM(187).
            MOVE "CSM_" TO D-PREFIX(188).
            MOVE 4 TO D-PREFIX-LEN(188).
            MOVE "case_management_core" TO D-PROGRAM(188).
            MOVE "RFE_" TO D-PREFIX(189).
            MOVE 4 TO D-PREFIX-LEN(189).
            MOVE "ref_engine" TO D-PROGRAM(189).
            MOVE "CRT_" TO D-PREFIX(190).
            MOVE 4 TO D-PREFIX-LEN(190).
            MOVE "compliance_retention_core" TO D-PROGRAM(190).
            MOVE "AAN_" TO D-PREFIX(191).
            MOVE 4 TO D-PREFIX-LEN(191).
            MOVE "audit_analytics_core" TO D-PROGRAM(191).
            MOVE "PHL_" TO D-PREFIX(192).
            MOVE 4 TO D-PREFIX-LEN(192).
            MOVE "payment_hold_core" TO D-PROGRAM(192).
            MOVE "CLT_" TO D-PREFIX(193).
            MOVE 4 TO D-PREFIX-LEN(193).
            MOVE "collateral_core" TO D-PROGRAM(193).
            MOVE "ASP_" TO D-PREFIX(194).
            MOVE 4 TO D-PREFIX-LEN(194).
            MOVE "analytics_snapshot_core" TO D-PROGRAM(194).
            MOVE "LPR_" TO D-PREFIX(195).
            MOVE 4 TO D-PREFIX-LEN(195).
            MOVE "limit_profile_core" TO D-PROGRAM(195).
            MOVE "CHG_" TO D-PREFIX(196).
            MOVE 4 TO D-PREFIX-LEN(196).
            MOVE "change_control_core" TO D-PROGRAM(196).
            MOVE "RCL_" TO D-PREFIX(197).
            MOVE 4 TO D-PREFIX-LEN(197).
            MOVE "regulatory_calendar_core" TO D-PROGRAM(197).
            MOVE "RX_" TO D-PREFIX(198).
            MOVE 3 TO D-PREFIX-LEN(198).
            MOVE "ref_ext_core" TO D-PROGRAM(198).
            MOVE "CA_" TO D-PREFIX(199).
            MOVE 3 TO D-PREFIX-LEN(199).
            MOVE "compliance_audit_core" TO D-PROGRAM(199).
            MOVE "GL_" TO D-PREFIX(200).
            MOVE 3 TO D-PREFIX-LEN(200).
            MOVE "gl_core" TO D-PROGRAM(200).
            MOVE "MRT_" TO D-PREFIX(201).
            MOVE 4 TO D-PREFIX-LEN(201).
            MOVE "merchant_core" TO D-PROGRAM(201).
            MOVE "TRF_" TO D-PREFIX(202).
            MOVE 4 TO D-PREFIX-LEN(202).
            MOVE "trade_finance_core" TO D-PROGRAM(202).
            MOVE "TSD_" TO D-PREFIX(203).
            MOVE 4 TO D-PREFIX-LEN(203).
            MOVE "treasury_deal_core" TO D-PROGRAM(203).
            MOVE "CLM_" TO D-PREFIX(204).
            MOVE 4 TO D-PREFIX-LEN(204).
            MOVE "collateral_mgmt_core" TO D-PROGRAM(204).
            MOVE "SIN_" TO D-PREFIX(205).
            MOVE 4 TO D-PREFIX-LEN(205).
            MOVE "standing_instruction_core" TO D-PROGRAM(205).
            MOVE "DDB_" TO D-PREFIX(206).
            MOVE 4 TO D-PREFIX-LEN(206).
            MOVE "direct_debit_core" TO D-PROGRAM(206).
            MOVE "NTP_" TO D-PREFIX(207).
            MOVE 4 TO D-PREFIX-LEN(207).
            MOVE "notification_template_core" TO D-PROGRAM(207).
            MOVE "RPS_" TO D-PREFIX(208).
            MOVE 4 TO D-PREFIX-LEN(208).
            MOVE "report_schedule_core" TO D-PROGRAM(208).
            MOVE "SLT_" TO D-PREFIX(209).
            MOVE 4 TO D-PREFIX-LEN(209).
            MOVE "sla_tracker_core" TO D-PROGRAM(209).
            MOVE "CCL_" TO D-PREFIX(210).
            MOVE 4 TO D-PREFIX-LEN(210).
            MOVE "compliance_calendar_core" TO D-PROGRAM(210).
            MOVE "ASM_" TO D-PREFIX(211).
            MOVE 4 TO D-PREFIX-LEN(211).
            MOVE "asset_management_core" TO D-PROGRAM(211).
            MOVE "POM_" TO D-PREFIX(212).
            MOVE 4 TO D-PREFIX-LEN(212).
            MOVE "portfolio_management_core" TO D-PROGRAM(212).
            MOVE "BND_" TO D-PREFIX(213).
            MOVE 4 TO D-PREFIX-LEN(213).
            MOVE "bond_trading_core" TO D-PROGRAM(213).
            MOVE "LOC_" TO D-PREFIX(214).
            MOVE 4 TO D-PREFIX-LEN(214).
            MOVE "letter_of_credit_core" TO D-PROGRAM(214).
            MOVE "BKG_" TO D-PREFIX(215).
            MOVE 4 TO D-PREFIX-LEN(215).
            MOVE "bank_guarantee_core" TO D-PROGRAM(215).
            MOVE "IVC_" TO D-PREFIX(216).
            MOVE 4 TO D-PREFIX-LEN(216).
            MOVE "invoice_financing_core" TO D-PROGRAM(216).
            MOVE "SCF_" TO D-PREFIX(217).
            MOVE 4 TO D-PREFIX-LEN(217).
            MOVE "supply_chain_finance_core" TO D-PROGRAM(217).
            MOVE "PRL_" TO D-PREFIX(218).
            MOVE 4 TO D-PREFIX-LEN(218).
            MOVE "payroll_processing_core" TO D-PROGRAM(218).
            MOVE "WLM_" TO D-PREFIX(219).
            MOVE 4 TO D-PREFIX-LEN(219).
            MOVE "wealth_management_core" TO D-PROGRAM(219).
            MOVE "ESC_" TO D-PREFIX(220).
            MOVE 4 TO D-PREFIX-LEN(220).
            MOVE "escrow_account_core" TO D-PROGRAM(220).
            MOVE "CRC_" TO D-PREFIX(221).
            MOVE 4 TO D-PREFIX-LEN(221).
            MOVE "credit_card_core" TO D-PROGRAM(221).
            MOVE "DBC_" TO D-PREFIX(222).
            MOVE 4 TO D-PREFIX-LEN(222).
            MOVE "debit_card_core" TO D-PROGRAM(222).
            MOVE "MCS_" TO D-PREFIX(223).
            MOVE 4 TO D-PREFIX-LEN(223).
            MOVE "merchant_settlement_core" TO D-PROGRAM(223).
            MOVE "PWG_" TO D-PREFIX(224).
            MOVE 4 TO D-PREFIX-LEN(224).
            MOVE "payment_gateway_core" TO D-PROGRAM(224).
            MOVE "MBW_" TO D-PREFIX(225).
            MOVE 4 TO D-PREFIX-LEN(225).
            MOVE "mobile_wallet_core" TO D-PROGRAM(225).
            MOVE "DGB_" TO D-PREFIX(226).
            MOVE 4 TO D-PREFIX-LEN(226).
            MOVE "digital_banking_core" TO D-PROGRAM(226).
            MOVE "INB_" TO D-PREFIX(227).
            MOVE 4 TO D-PREFIX-LEN(227).
            MOVE "internet_banking_core" TO D-PROGRAM(227).
            MOVE "APM_" TO D-PREFIX(228).
            MOVE 4 TO D-PREFIX-LEN(228).
            MOVE "api_management_core" TO D-PROGRAM(228).
            MOVE "RTM_" TO D-PREFIX(229).
            MOVE 4 TO D-PREFIX-LEN(229).
            MOVE "rate_management_core" TO D-PROGRAM(229).
            MOVE "FMM_" TO D-PREFIX(230).
            MOVE 4 TO D-PREFIX-LEN(230).
            MOVE "fee_management_core" TO D-PROGRAM(230).
            MOVE "TXM_" TO D-PREFIX(231).
            MOVE 4 TO D-PREFIX-LEN(231).
            MOVE "tax_management_core" TO D-PROGRAM(231).
            MOVE "ADT_" TO D-PREFIX(232).
            MOVE 4 TO D-PREFIX-LEN(232).
            MOVE "audit_trail_core" TO D-PROGRAM(232).
            MOVE "DTA_" TO D-PREFIX(233).
            MOVE 4 TO D-PREFIX-LEN(233).
            MOVE "data_archive_core" TO D-PROGRAM(233).
            MOVE "BUM_" TO D-PREFIX(234).
            MOVE 4 TO D-PREFIX-LEN(234).
            MOVE "backup_management_core" TO D-PROGRAM(234).
            MOVE "SGC_" TO D-PREFIX(235).
            MOVE 4 TO D-PREFIX-LEN(235).
            MOVE "system_config_core" TO D-PROGRAM(235).
            MOVE "UAC_" TO D-PREFIX(236).
            MOVE 4 TO D-PREFIX-LEN(236).
            MOVE "user_activity_core" TO D-PROGRAM(236).
            MOVE "AXC_" TO D-PREFIX(237).
            MOVE 4 TO D-PREFIX-LEN(237).
            MOVE "access_control_core" TO D-PROGRAM(237).
            MOVE "RLM_" TO D-PREFIX(238).
            MOVE 4 TO D-PREFIX-LEN(238).
            MOVE "role_management_core" TO D-PROGRAM(238).
            MOVE "PMS_" TO D-PREFIX(239).
            MOVE 4 TO D-PREFIX-LEN(239).
            MOVE "permission_set_core" TO D-PROGRAM(239).
            MOVE "ORG_" TO D-PREFIX(240).
            MOVE 4 TO D-PREFIX-LEN(240).
            MOVE "organization_unit_core" TO D-PROGRAM(240).
            MOVE "CRW_" TO D-PREFIX(241).
            MOVE 4 TO D-PREFIX-LEN(241).
            MOVE "crypto_wallet_core" TO D-PROGRAM(241).
            MOVE "CRX_" TO D-PREFIX(242).
            MOVE 4 TO D-PREFIX-LEN(242).
            MOVE "crypto_exchange_core" TO D-PROGRAM(242).
            MOVE "BCT_" TO D-PREFIX(243).
            MOVE 4 TO D-PREFIX-LEN(243).
            MOVE "blockchain_tracker_core" TO D-PROGRAM(243).
            MOVE "DAS_" TO D-PREFIX(244).
            MOVE 4 TO D-PREFIX-LEN(244).
            MOVE "digital_asset_core" TO D-PROGRAM(244).
            MOVE "TKN_" TO D-PREFIX(245).
            MOVE 4 TO D-PREFIX-LEN(245).
            MOVE "tokenization_core" TO D-PROGRAM(245).
            MOVE "SMC_" TO D-PREFIX(246).
            MOVE 4 TO D-PREFIX-LEN(246).
            MOVE "smart_contract_core" TO D-PROGRAM(246).
            MOVE "NFT_" TO D-PREFIX(247).
            MOVE 4 TO D-PREFIX-LEN(247).
            MOVE "nft_management_core" TO D-PROGRAM(247).
            MOVE "OPN_" TO D-PREFIX(248).
            MOVE 4 TO D-PREFIX-LEN(248).
            MOVE "open_banking_core" TO D-PROGRAM(248).
            MOVE "PIS_" TO D-PREFIX(249).
            MOVE 4 TO D-PREFIX-LEN(249).
            MOVE "pisp_management_core" TO D-PROGRAM(249).
            MOVE "CSN_" TO D-PREFIX(250).
            MOVE 4 TO D-PREFIX-LEN(250).
            MOVE "consent_management_core" TO D-PROGRAM(250).
            MOVE "CSP_" TO D-PREFIX(251).
            MOVE 4 TO D-PREFIX-LEN(251).
            MOVE "customer_support_core" TO D-PROGRAM(251).
            MOVE "CPM_" TO D-PREFIX(252).
            MOVE 4 TO D-PREFIX-LEN(252).
            MOVE "complaint_management_core" TO D-PROGRAM(252).
            MOVE "DSM_" TO D-PREFIX(253).
            MOVE 4 TO D-PREFIX-LEN(253).
            MOVE "dispute_management_core" TO D-PROGRAM(253).
            MOVE "CHB_" TO D-PREFIX(254).
            MOVE 4 TO D-PREFIX-LEN(254).
            MOVE "chargeback_core" TO D-PROGRAM(254).
            MOVE "RFP_" TO D-PREFIX(255).
            MOVE 4 TO D-PREFIX-LEN(255).
            MOVE "refund_processing_core" TO D-PROGRAM(255).
            MOVE "CAH_" TO D-PREFIX(256).
            MOVE 4 TO D-PREFIX-LEN(256).
            MOVE "cash_management_core" TO D-PROGRAM(256).
            MOVE "VLT_" TO D-PREFIX(257).
            MOVE 4 TO D-PREFIX-LEN(257).
            MOVE "vault_management_core" TO D-PROGRAM(257).
            MOVE "ATM_" TO D-PREFIX(258).
            MOVE 4 TO D-PREFIX-LEN(258).
            MOVE "atm_management_core" TO D-PROGRAM(258).
            MOVE "BRN_" TO D-PREFIX(259).
            MOVE 4 TO D-PREFIX-LEN(259).
            MOVE "branch_management_core" TO D-PROGRAM(259).
            MOVE "TLR_" TO D-PREFIX(260).
            MOVE 4 TO D-PREFIX-LEN(260).
            MOVE "teller_management_core" TO D-PROGRAM(260).
            MOVE "CUX_" TO D-PREFIX(261).
            MOVE 4 TO D-PREFIX-LEN(261).
            MOVE "currency_exchange_core" TO D-PROGRAM(261).
            MOVE "SWP_" TO D-PREFIX(262).
            MOVE 4 TO D-PREFIX-LEN(262).
            MOVE "swap_contract_core" TO D-PROGRAM(262).
            MOVE "FTC_" TO D-PREFIX(263).
            MOVE 4 TO D-PREFIX-LEN(263).
            MOVE "future_contract_core" TO D-PROGRAM(263).
            MOVE "OPT_" TO D-PREFIX(264).
            MOVE 4 TO D-PREFIX-LEN(264).
            MOVE "option_trading_core" TO D-PROGRAM(264).
            MOVE "CMD_" TO D-PREFIX(265).
            MOVE 4 TO D-PREFIX-LEN(265).
            MOVE "commodity_trading_core" TO D-PROGRAM(265).
            MOVE "RPO_" TO D-PREFIX(266).
            MOVE 4 TO D-PREFIX-LEN(266).
            MOVE "repo_agreement_core" TO D-PROGRAM(266).
            MOVE "SEL_" TO D-PREFIX(267).
            MOVE 4 TO D-PREFIX-LEN(267).
            MOVE "securities_lending_core" TO D-PROGRAM(267).
            MOVE "MGT_" TO D-PREFIX(268).
            MOVE 4 TO D-PREFIX-LEN(268).
            MOVE "margin_trading_core" TO D-PROGRAM(268).
            MOVE "STP_" TO D-PREFIX(269).
            MOVE 4 TO D-PREFIX-LEN(269).
            MOVE "structured_product_core" TO D-PROGRAM(269).
            MOVE "SYL_" TO D-PREFIX(270).
            MOVE 4 TO D-PREFIX-LEN(270).
            MOVE "syndicated_loan_core" TO D-PROGRAM(270).
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
                        ELSE
                            CALL D-PROGRAM(DISPATCH-IDX) USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 CMD-PARAM5 CMD-PARAM6 WS-OUTPUT-MSG
                        END-IF
                    END-IF
                END-IF
                ADD 1 TO DISPATCH-IDX
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
