        IDENTIFICATION DIVISION.
        PROGRAM-ID. ref_core.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           DECIMAL-POINT IS COMMA.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01  WS-RESULT               PIC X(16384) VALUE SPACES.
        01  WS-PREP-SQL             PIC X(1024) VALUE SPACES.
        01  WS-BIND-1               PIC X(256) VALUE SPACES.
        01  WS-BIND-2               PIC X(256) VALUE SPACES.
        01  WS-BIND-3               PIC X(256) VALUE SPACES.
        01  WS-BIND-4               PIC X(256) VALUE SPACES.
        01  WS-BIND-5               PIC X(256) VALUE SPACES.
        01  WS-BIND-6               PIC X(256) VALUE SPACES.
        01  WS-P1-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P2-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P3-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P4-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P5-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P6-TRIMMED           PIC X(100) VALUE SPACES.
        01  WS-P1-LEN               PIC 9(3) VALUE 1.
        01  WS-P2-LEN               PIC 9(3) VALUE 1.
        01  WS-P3-LEN               PIC 9(3) VALUE 1.
        01  WS-P4-LEN               PIC 9(3) VALUE 1.
        01  WS-P5-LEN               PIC 9(3) VALUE 1.
        01  WS-P6-LEN               PIC 9(3) VALUE 1.
        01  WS-RLEN                 PIC 9(5) VALUE 1.
        01  WS-I                    PIC 9(3) VALUE 1.
        01  WS-BAD                  PIC 9(3) VALUE 0.
        01  WS-ALLOWED              PIC 9 VALUE 0.
        01  WS-CHECK                PIC X(100) VALUE SPACES.
        01  WS-ERR                  PIC X(40) VALUE SPACES.
        01  WS-TOTAL                PIC X(20) VALUE SPACES.
        01  WS-LIMIT                PIC X(10) VALUE SPACES.
        01  WS-OFFSET               PIC X(10) VALUE SPACES.
        01  WS-DENIED-ACTOR         PIC X(100) VALUE SPACES.
        01  WS-DENIED-TARGET        PIC X(100) VALUE SPACES.
        01  WS-AUDIT-ENTITY         PIC X(64) VALUE SPACES.
        01  WS-AUDIT-KEY            PIC X(100) VALUE SPACES.
        01  WS-AUDIT-ACTION         PIC X(20) VALUE SPACES.
        01  WS-STEP                 PIC X VALUE 'Y'.
            88  STEP-OK             VALUE 'Y'.
            88  STEP-FAIL           VALUE 'N'.
        01  F-QUOTE                 PIC X VALUE "'".
        01  F-DQUOTE                PIC X VALUE '"'.
        01  F-BSLASH                PIC X VALUE "\".
        01  F-SEMI                  PIC X VALUE ";".
        01  F-TICK                  PIC X VALUE "`".

        LINKAGE SECTION.
        01  LS-CMD-ACTION           PIC X(30).
        01  LS-PARAM1               PIC X(100).
        01  LS-PARAM2               PIC X(100).
        01  LS-PARAM3               PIC X(100).
        01  LS-PARAM4               PIC X(100).
        01  LS-PARAM5               PIC X(100).
        01  LS-PARAM6               PIC X(100).
        01  LS-OUTPUT-BUFFER        PIC X(16384).

        PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-OUTPUT-BUFFER.

        MAIN-LOGIC.
            PERFORM VALIDATE-ALL
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                GOBACK
            END-IF
            EVALUATE TRUE
                WHEN LS-CMD-ACTION(1:12) = "REF_CUR_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CUR_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CUR_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CUR_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CUR_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CUR-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CTR_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CTR_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CTR_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CTR_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CTR_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CTR-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_HOL_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_HOL_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_HOL_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_HOL_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_HOL_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HOL-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CHN_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CHN_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CHN_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CHN_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CHN_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHN-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_BRN_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_BRN_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_BRN_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_BRN_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_BRN_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-BRN-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CCT_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CCT_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CCT_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CCT_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CCT_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CCT-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_DTP_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_DTP_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_DTP_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_DTP_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_DTP_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTP-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_NTP_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_NTP_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_NTP_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_NTP_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_NTP_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NTP-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_STS_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_STS_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_STS_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_STS_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_STS_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STS-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_RTS_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_RTS_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_RTS_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_RTS_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_RTS_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RTS-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_PRD_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_PRD_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_PRD_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_PRD_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_PRD_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRD-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_ACT_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACT-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_ACT_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACT-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_ACT_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACT-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_ACT_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACT-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_ACT_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACT-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_TXN_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TXN-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_TXN_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TXN-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_TXN_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TXN-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_TXN_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TXN-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_TXN_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TXN-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_FEE_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-FEE-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_FEE_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-FEE-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_FEE_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-FEE-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_FEE_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-FEE-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_FEE_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-FEE-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CHG_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHG-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CHG_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHG-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CHG_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHG-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CHG_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHG-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CHG_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CHG-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_LMT_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMT-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_LMT_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMT-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_LMT_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMT-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_LMT_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMT-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_LMT_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMT-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_LMP_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMP-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_LMP_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMP-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_LMP_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMP-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_LMP_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMP-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_LMP_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LMP-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_STL_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STL-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_STL_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STL-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_STL_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STL-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_STL_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STL-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_STL_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-STL-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CLR_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLR-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CLR_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLR-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CLR_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLR-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CLR_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLR-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CLR_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CLR-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_SUS_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUS-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_SUS_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUS-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_SUS_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUS-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_SUS_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUS-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_SUS_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SUS-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_RND_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RND-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_RND_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RND-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_RND_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RND-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_RND_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RND-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_RND_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RND-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_PRC_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRC-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_PRC_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRC-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_PRC_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRC-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_PRC_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRC-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_PRC_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PRC-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_TAX_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TAX-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_TAX_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TAX-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_TAX_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TAX-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_TAX_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TAX-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_TAX_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TAX-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_LNG_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LNG-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_LNG_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LNG-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_LNG_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LNG-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_LNG_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LNG-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_LNG_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-LNG-DEACT
                WHEN LS-CMD-ACTION(1:11) = "REF_TZ_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TZ-LIST
                WHEN LS-CMD-ACTION(1:10) = "REF_TZ_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TZ-GET
                WHEN LS-CMD-ACTION(1:13) = "REF_TZ_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TZ-CREATE
                WHEN LS-CMD-ACTION(1:13) = "REF_TZ_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TZ-UPDATE
                WHEN LS-CMD-ACTION(1:12) = "REF_TZ_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-TZ-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_RGN_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RGN-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_RGN_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RGN-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_RGN_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RGN-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_RGN_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RGN-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_RGN_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RGN-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CPR_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CPR-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CPR_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CPR-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CPR_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CPR-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CPR_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CPR-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CPR_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CPR-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_HCD_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HCD-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_HCD_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HCD-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_HCD_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HCD-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_HCD_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HCD-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_HCD_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-HCD-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_DTM_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTM-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_DTM_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTM-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_DTM_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTM-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_DTM_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTM-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_DTM_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-DTM-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_NCH_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NCH-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_NCH_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NCH-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_NCH_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NCH-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_NCH_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NCH-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_NCH_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-NCH-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_AET_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AET-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_AET_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AET-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_AET_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AET-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_AET_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AET-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_AET_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-AET-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_SRN_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SRN-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_SRN_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SRN-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_SRN_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SRN-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_SRN_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SRN-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_SRN_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-SRN-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_ACS_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACS-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_ACS_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACS-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_ACS_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACS-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_ACS_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACS-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_ACS_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ACS-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_PMT_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PMT-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_PMT_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PMT-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_PMT_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PMT-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_PMT_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PMT-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_PMT_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PMT-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_CRD_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CRD-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_CRD_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CRD-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_CRD_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CRD-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_CRD_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CRD-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_CRD_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-CRD-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_ADR_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ADR-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_ADR_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ADR-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_ADR_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ADR-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_ADR_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ADR-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_ADR_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-ADR-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_PHN_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PHN-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_PHN_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PHN-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_PHN_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PHN-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_PHN_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PHN-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_PHN_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-PHN-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_EMT_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-EMT-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_EMT_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-EMT-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_EMT_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-EMT-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_EMT_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-EMT-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_EMT_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-EMT-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_RVS_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RVS-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_RVS_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RVS-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_RVS_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RVS-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_RVS_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RVS-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_RVS_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RVS-DEACT
                WHEN LS-CMD-ACTION(1:12) = "REF_RPG_LIST"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RPG-LIST
                WHEN LS-CMD-ACTION(1:11) = "REF_RPG_GET"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RPG-GET
                WHEN LS-CMD-ACTION(1:14) = "REF_RPG_CREATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RPG-CREATE
                WHEN LS-CMD-ACTION(1:14) = "REF_RPG_UPDATE"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RPG-UPDATE
                WHEN LS-CMD-ACTION(1:13) = "REF_RPG_DEACT"
                    PERFORM TRIM-ALL
                    PERFORM ACTION-RPG-DEACT
                WHEN OTHER
                    MOVE "ERROR|INVALID_ACTION" TO LS-OUTPUT-BUFFER
            END-EVALUATE.
            GOBACK.

        VALIDATE-ALL.
            MOVE 0 TO WS-BAD
            MOVE LS-PARAM1 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM2 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM3 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM4 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM5 TO WS-CHECK
            PERFORM VALIDATE-INPUT
            MOVE LS-PARAM6 TO WS-CHECK
            PERFORM VALIDATE-INPUT.
            EXIT PARAGRAPH.

        VALIDATE-INPUT.
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-QUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-DQUOTE
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-BSLASH
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-SEMI
            INSPECT WS-CHECK TALLYING WS-BAD FOR ALL F-TICK.
            EXIT PARAGRAPH.

        TRIM-ALL.
            PERFORM TRIM-P1
            PERFORM TRIM-P2
            PERFORM TRIM-P3
            PERFORM TRIM-P4
            PERFORM TRIM-P5
            PERFORM TRIM-P6.
            EXIT PARAGRAPH.

        TRIM-P1.
            MOVE LS-PARAM1 TO WS-P1-TRIMMED
            MOVE 0 TO WS-P1-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P1-LEN > 0
                IF WS-P1-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P1-LEN
                END-IF
            END-PERFORM
            IF WS-P1-LEN = 0
                MOVE 1 TO WS-P1-LEN
            END-IF.

        TRIM-P2.
            MOVE LS-PARAM2 TO WS-P2-TRIMMED
            MOVE 0 TO WS-P2-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P2-LEN > 0
                IF WS-P2-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P2-LEN
                END-IF
            END-PERFORM
            IF WS-P2-LEN = 0
                MOVE 1 TO WS-P2-LEN
            END-IF.

        TRIM-P3.
            MOVE LS-PARAM3 TO WS-P3-TRIMMED
            MOVE 0 TO WS-P3-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P3-LEN > 0
                IF WS-P3-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P3-LEN
                END-IF
            END-PERFORM
            IF WS-P3-LEN = 0
                MOVE 1 TO WS-P3-LEN
            END-IF.

        TRIM-P4.
            MOVE LS-PARAM4 TO WS-P4-TRIMMED
            MOVE 0 TO WS-P4-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P4-LEN > 0
                IF WS-P4-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P4-LEN
                END-IF
            END-PERFORM
            IF WS-P4-LEN = 0
                MOVE 1 TO WS-P4-LEN
            END-IF.

        TRIM-P5.
            MOVE LS-PARAM5 TO WS-P5-TRIMMED
            MOVE 0 TO WS-P5-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P5-LEN > 0
                IF WS-P5-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P5-LEN
                END-IF
            END-PERFORM
            IF WS-P5-LEN = 0
                MOVE 1 TO WS-P5-LEN
            END-IF.

        TRIM-P6.
            MOVE LS-PARAM6 TO WS-P6-TRIMMED
            MOVE 0 TO WS-P6-LEN
            PERFORM VARYING WS-I FROM 100 BY -1 UNTIL WS-I < 1 OR WS-P6-LEN > 0
                IF WS-P6-TRIMMED(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-P6-LEN
                END-IF
            END-PERFORM
            IF WS-P6-LEN = 0
                MOVE 1 TO WS-P6-LEN
            END-IF.

        ALLOW-ADMIN.
            MOVE 0 TO WS-ALLOWED
            MOVE "SELECT role FROM users WHERE email = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P6-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUPER_ADMIN" OR WS-RESULT = "MANAGER"
                MOVE 1 TO WS-ALLOWED
            END-IF.
            IF WS-ALLOWED NOT = 1
                MOVE WS-P6-TRIMMED TO WS-DENIED-ACTOR
                MOVE "REFERENCE" TO WS-DENIED-TARGET
                PERFORM AUDIT-DENIED
            END-IF.
            EXIT PARAGRAPH.

        AUDIT-DENIED.
            MOVE "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, detail, status) SELECT a.id, a.id, 'AUTHZ_DENIED', 'REFERENCE', ?, ?, 'FAILED' FROM users a WHERE a.email = ?" TO WS-PREP-SQL
            MOVE LS-CMD-ACTION TO WS-BIND-1
            MOVE WS-DENIED-TARGET TO WS-BIND-2
            MOVE WS-DENIED-ACTOR TO WS-BIND-3
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 3
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL.
            EXIT PARAGRAPH.

        AUDIT-REF.
            MOVE "INSERT INTO reference_audit (entity, entity_key, action, actor_email) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-AUDIT-ENTITY TO WS-BIND-1
            MOVE WS-AUDIT-KEY TO WS-BIND-2
            MOVE WS-AUDIT-ACTION TO WS-BIND-3
            MOVE WS-P6-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                SET STEP-FAIL TO TRUE
            END-IF.
            EXIT PARAGRAPH.

        TRIM-RESULT-LEN.
            MOVE 0 TO WS-RLEN
            PERFORM VARYING WS-I FROM 16384 BY -1 UNTIL WS-I < 1 OR WS-RLEN > 0
                IF WS-RESULT(WS-I:1) NOT = SPACE
                    MOVE WS-I TO WS-RLEN
                END-IF
            END-PERFORM
            IF WS-RLEN = 0
                MOVE 1 TO WS-RLEN
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CUR-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 3
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 5
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CUR-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM currencies" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(iso_code, ':', symbol, ':', prec_val, ':', is_active) FROM currencies ORDER BY iso_code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CUR-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 3
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(iso_code, ':', symbol, ':', prec_val, ':', is_active) FROM currencies WHERE iso_code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CUR-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CUR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO currencies (iso_code, symbol, prec_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "currencies" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CUR-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CUR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE currencies SET symbol = ?, prec_val = ?, is_active = ? WHERE iso_code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "currencies" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CUR-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 3
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE currencies SET is_active = FALSE WHERE iso_code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "currencies" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CTR-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 2
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CTR-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_country" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_country ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CTR-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 2
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_country WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CTR-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CTR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_country (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_country" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CTR-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CTR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_country SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_country" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CTR-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 2
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_country SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_country" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-HOL-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 10
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HOL-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_holiday" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_holiday ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HOL-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 10
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_holiday WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-HOL-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-HOL-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_holiday (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_holiday" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HOL-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-HOL-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_holiday SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_holiday" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HOL-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 10
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_holiday SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_holiday" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CHN-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 4
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHN-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_channel" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_channel ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHN-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_channel WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CHN-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CHN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_channel (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_channel" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHN-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CHN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_channel SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_channel" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHN-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_channel SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_channel" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-BRN-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-BRN-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_branch" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_branch ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-BRN-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_branch WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-BRN-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-BRN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_branch (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_branch" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-BRN-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-BRN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_branch SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_branch" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-BRN-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_branch SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_branch" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CCT-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CCT-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_cost_center" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_cost_center ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CCT-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_cost_center WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CCT-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CCT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_cost_center (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_cost_center" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CCT-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CCT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_cost_center SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_cost_center" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CCT-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_cost_center SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_cost_center" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-DTP-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTP-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_document_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_document_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTP-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_document_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-DTP-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-DTP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_document_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_document_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTP-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-DTP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_document_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_document_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTP-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_document_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_document_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-NTP-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NTP-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_notification_template" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_notification_template ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NTP-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_notification_template WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-NTP-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-NTP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_notification_template (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_notification_template" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NTP-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-NTP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_notification_template SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_notification_template" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NTP-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_notification_template SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_notification_template" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-STS-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 4
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STS-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_status_code" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_status_code ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STS-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_status_code WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-STS-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-STS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_status_code (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_status_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STS-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-STS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_status_code SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_status_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STS-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_status_code SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_status_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-RTS-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RTS-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_rate_source" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_rate_source ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RTS-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_rate_source WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-RTS-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RTS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_rate_source (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_rate_source" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RTS-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RTS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_rate_source SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_rate_source" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RTS-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_rate_source SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_rate_source" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-PRD-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRD-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_product_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_product_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRD-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_product_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-PRD-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PRD-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_product_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_product_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRD-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PRD-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_product_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_product_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRD-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_product_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_product_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-ACT-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 4
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACT-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_account_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_account_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACT-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_account_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-ACT-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-ACT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_account_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_account_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACT-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-ACT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_account_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_account_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACT-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_account_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_account_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-TXN-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TXN-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_transaction_code" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_transaction_code ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TXN-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_transaction_code WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-TXN-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-TXN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_transaction_code (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_transaction_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TXN-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-TXN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_transaction_code SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_transaction_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TXN-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_transaction_code SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_transaction_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-FEE-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-FEE-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_fee_code" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_fee_code ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-FEE-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_fee_code WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-FEE-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-FEE-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_fee_code (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_fee_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-FEE-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-FEE-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_fee_code SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_fee_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-FEE-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_fee_code SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_fee_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CHG-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHG-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_charge_code" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_charge_code ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHG-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_charge_code WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CHG-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CHG-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_charge_code (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_charge_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHG-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CHG-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_charge_code SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_charge_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CHG-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_charge_code SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_charge_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-LMT-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LMT-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_limit_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_limit_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LMT-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_limit_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-LMT-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-LMT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_limit_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_limit_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LMT-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-LMT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_limit_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_limit_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LMT-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_limit_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_limit_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-LMP-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LMP-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_limit_profile" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_limit_profile ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LMP-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_limit_profile WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-LMP-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-LMP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_limit_profile (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_limit_profile" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LMP-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-LMP-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_limit_profile SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_limit_profile" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LMP-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_limit_profile SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_limit_profile" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-STL-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STL-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_settlement_account" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_settlement_account ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STL-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_settlement_account WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-STL-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-STL-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_settlement_account (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_settlement_account" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STL-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-STL-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_settlement_account SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_settlement_account" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-STL-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_settlement_account SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_settlement_account" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CLR-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CLR-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_clearing_account" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_clearing_account ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CLR-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_clearing_account WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CLR-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CLR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_clearing_account (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_clearing_account" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CLR-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CLR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_clearing_account SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_clearing_account" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CLR-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_clearing_account SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_clearing_account" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-SUS-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SUS-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_suspense_account" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_suspense_account ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SUS-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_suspense_account WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-SUS-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-SUS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_suspense_account (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_suspense_account" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SUS-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-SUS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_suspense_account SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_suspense_account" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SUS-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_suspense_account SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_suspense_account" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-RND-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RND-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_rounding_rule" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_rounding_rule ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RND-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_rounding_rule WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-RND-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RND-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_rounding_rule (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_rounding_rule" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RND-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RND-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_rounding_rule SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_rounding_rule" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RND-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_rounding_rule SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_rounding_rule" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-PRC-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRC-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_precision_rule" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_precision_rule ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRC-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_precision_rule WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-PRC-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PRC-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_precision_rule (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_precision_rule" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRC-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PRC-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_precision_rule SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_precision_rule" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PRC-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_precision_rule SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_precision_rule" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-TAX-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TAX-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_tax_code" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_tax_code ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TAX-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_tax_code WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-TAX-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-TAX-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_tax_code (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_tax_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TAX-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-TAX-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_tax_code SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_tax_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TAX-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_tax_code SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_tax_code" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-LNG-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 3
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LNG-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_language" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_language ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LNG-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 3
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_language WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-LNG-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-LNG-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_language (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_language" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LNG-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-LNG-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_language SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_language" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-LNG-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 3
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_language SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_language" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-TZ-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 5
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TZ-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_timezone" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_timezone ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TZ-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 5
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_timezone WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-TZ-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-TZ-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_timezone (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_timezone" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TZ-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-TZ-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_timezone SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_timezone" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-TZ-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 5
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_timezone SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_timezone" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-RGN-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 4
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RGN-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_country_region" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_country_region ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RGN-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_country_region WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-RGN-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RGN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_country_region (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_country_region" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RGN-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RGN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_country_region SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_country_region" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RGN-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_country_region SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_country_region" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CPR-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 7
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CPR-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_currency_pair" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_currency_pair ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CPR-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 7
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_currency_pair WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CPR-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CPR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_currency_pair (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_currency_pair" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CPR-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CPR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_currency_pair SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_currency_pair" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CPR-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 7
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_currency_pair SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_currency_pair" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-HCD-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HCD-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_holiday_calendar" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_holiday_calendar ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HCD-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_holiday_calendar WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-HCD-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-HCD-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_holiday_calendar (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_holiday_calendar" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HCD-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-HCD-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_holiday_calendar SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_holiday_calendar" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-HCD-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_holiday_calendar SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_holiday_calendar" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-DTM-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTM-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_document_template" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_document_template ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTM-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_document_template WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-DTM-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-DTM-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_document_template (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_document_template" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTM-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-DTM-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_document_template SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_document_template" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-DTM-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_document_template SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_document_template" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-NCH-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NCH-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_notification_channel" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_notification_channel ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NCH-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_notification_channel WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-NCH-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-NCH-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_notification_channel (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_notification_channel" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NCH-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-NCH-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_notification_channel SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_notification_channel" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-NCH-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_notification_channel SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_notification_channel" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-AET-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 8
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-AET-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_audit_event_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_audit_event_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-AET-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_audit_event_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-AET-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-AET-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_audit_event_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_audit_event_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-AET-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-AET-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_audit_event_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_audit_event_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-AET-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 8
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_audit_event_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_audit_event_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-SRN-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SRN-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_status_reason" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_status_reason ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SRN-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_status_reason WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-SRN-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-SRN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_status_reason (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_status_reason" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SRN-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-SRN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_status_reason SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_status_reason" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-SRN-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_status_reason SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_status_reason" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-ACS-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 4
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACS-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_account_status" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_account_status ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACS-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_account_status WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-ACS-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-ACS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_account_status (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_account_status" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACS-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-ACS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_account_status SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_account_status" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ACS-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_account_status SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_account_status" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-PMT-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PMT-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_payment_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_payment_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PMT-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_payment_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-PMT-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PMT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_payment_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_payment_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PMT-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PMT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_payment_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_payment_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PMT-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_payment_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_payment_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-CRD-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CRD-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_card_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_card_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CRD-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_card_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-CRD-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CRD-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_card_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_card_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CRD-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-CRD-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_card_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_card_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-CRD-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_card_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_card_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-ADR-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ADR-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_address_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_address_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ADR-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_address_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-ADR-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-ADR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_address_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_address_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ADR-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-ADR-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_address_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_address_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-ADR-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_address_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_address_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-PHN-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PHN-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_phone_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_phone_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PHN-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_phone_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-PHN-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PHN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_phone_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_phone_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PHN-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-PHN-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_phone_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_phone_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-PHN-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_phone_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_phone_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-EMT-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-EMT-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_email_type" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_email_type ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-EMT-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_email_type WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-EMT-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-EMT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_email_type (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_email_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-EMT-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-EMT-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_email_type SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_email_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-EMT-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_email_type SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_email_type" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-RVS-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 4
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RVS-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_review_state" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_review_state ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RVS-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_review_state WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-RVS-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RVS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_review_state (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_review_state" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RVS-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RVS-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_review_state SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_review_state" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RVS-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 4
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_review_state SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_review_state" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        VALIDATE-RPG-INPUT.
            MOVE 0 TO WS-BAD
            IF WS-P1-LEN NOT = 6
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P2-LEN < 1 OR WS-P2-LEN > 64
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P3-LEN NOT = 1 OR WS-P3-TRIMMED(1:1) IS NOT NUMERIC
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-LEN NOT = 1
                MOVE 1 TO WS-BAD
            END-IF.
            IF WS-P4-TRIMMED(1:1) NOT = "0" AND WS-P4-TRIMMED(1:1) NOT = "1"
                MOVE 1 TO WS-BAD
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RPG-LIST.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "20" TO WS-LIMIT
            MOVE "0" TO WS-OFFSET
            IF LS-PARAM1 NOT = SPACES
                MOVE WS-P1-TRIMMED(1:WS-P1-LEN) TO WS-LIMIT
            END-IF.
            IF LS-PARAM2 NOT = SPACES
                MOVE WS-P2-TRIMMED(1:WS-P2-LEN) TO WS-OFFSET
            END-IF.
            MOVE "SELECT CAST(COUNT(*) AS CHAR) FROM ref_report_group" TO WS-PREP-SQL
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 0
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            MOVE WS-RESULT(1:20) TO WS-TOTAL
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_report_group ORDER BY code LIMIT ? OFFSET ?" TO WS-PREP-SQL
            MOVE WS-LIMIT TO WS-BIND-1
            MOVE WS-OFFSET TO WS-BIND-2
            CALL "SQL_PREPARE_EXEC_ROWS" USING BY REFERENCE WS-PREP-SQL BY VALUE 2
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            ELSE
                PERFORM TRIM-RESULT-LEN
                MOVE SPACES TO LS-OUTPUT-BUFFER
                STRING "SUCCESS|REF_LIST|" DELIMITED BY SIZE
                       WS-TOTAL DELIMITED BY SPACE "|" DELIMITED BY SIZE
                       WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                       INTO LS-OUTPUT-BUFFER
                END-STRING
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RPG-GET.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            MOVE "SELECT CONCAT(code, ':', label, ':', num_val, ':', is_active) FROM ref_report_group WHERE code = ? LIMIT 1" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "ERROR|NO_DATA"
                MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM TRIM-RESULT-LEN
            MOVE SPACES TO LS-OUTPUT-BUFFER
            STRING "SUCCESS|REF_GET|" DELIMITED BY SIZE
                   WS-RESULT(1:WS-RLEN) DELIMITED BY SIZE
                   INTO LS-OUTPUT-BUFFER
            END-STRING.
            EXIT PARAGRAPH.

        ACTION-RPG-CREATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RPG-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "INSERT INTO ref_report_group (code, label, num_val, is_active) VALUES (?, ?, ?, ?)" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            MOVE WS-P2-TRIMMED TO WS-BIND-2
            MOVE WS-P3-TRIMMED TO WS-BIND-3
            MOVE WS-P4-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_report_group" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "CREATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_CREATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|PREPARE_FAILED|1062" OR WS-ERR = "ERROR|EXEC_FAILED|1062"
                    MOVE "ERROR|DUPLICATE" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RPG-UPDATE.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            PERFORM VALIDATE-RPG-INPUT
            IF WS-BAD > 0
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_report_group SET label = ?, num_val = ?, is_active = ? WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P2-TRIMMED TO WS-BIND-1
            MOVE WS-P3-TRIMMED TO WS-BIND-2
            MOVE WS-P4-TRIMMED TO WS-BIND-3
            MOVE WS-P1-TRIMMED TO WS-BIND-4
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 4
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_report_group" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "UPDATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_UPDATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.

        ACTION-RPG-DEACT.
            PERFORM ALLOW-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF WS-P1-LEN NOT = 6
                MOVE "ERROR|INVALID_INPUT" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            SET STEP-OK TO TRUE
            MOVE SPACES TO WS-ERR
            CALL "SQL_BEGIN" END-CALL
            MOVE "UPDATE ref_report_group SET is_active = FALSE WHERE code = ?" TO WS-PREP-SQL
            MOVE WS-P1-TRIMMED TO WS-BIND-1
            CALL "SQL_PREPARE_EXEC" USING BY REFERENCE WS-PREP-SQL BY VALUE 1
                BY REFERENCE WS-BIND-1 BY REFERENCE WS-BIND-2 BY REFERENCE WS-BIND-3
                BY REFERENCE WS-BIND-4 BY REFERENCE WS-BIND-5 BY REFERENCE WS-BIND-6
            END-CALL
            CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
            IF WS-RESULT = "SUCCESS|AFFECTED_0"
                MOVE "ERROR|NOT_FOUND" TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF WS-RESULT(1:5) = "ERROR"
                MOVE WS-RESULT(1:40) TO WS-ERR
                SET STEP-FAIL TO TRUE
            END-IF.
            IF STEP-OK
                MOVE "ref_report_group" TO WS-AUDIT-ENTITY
                MOVE WS-P1-TRIMMED TO WS-AUDIT-KEY
                MOVE "DEACTIVATE" TO WS-AUDIT-ACTION
                PERFORM AUDIT-REF
            END-IF.
            IF STEP-OK
                CALL "SQL_COMMIT" END-CALL
                MOVE "SUCCESS|REF_DEACTIVATED" TO LS-OUTPUT-BUFFER
            ELSE
                CALL "SQL_ROLLBACK" END-CALL
                IF WS-ERR = "ERROR|NOT_FOUND"
                    MOVE "ERROR|NOT_FOUND" TO LS-OUTPUT-BUFFER
                ELSE
                    MOVE "ERROR|DB_ERROR" TO LS-OUTPUT-BUFFER
                END-IF
            END-IF.
            EXIT PARAGRAPH.
