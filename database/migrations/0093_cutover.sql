-- Gradual cutover batch: LMP, STL, CLR, SUS, RND, PRC, TAX, LNG, TZ, RGN, CPR, HCD, DTM, NCH, AET, SRN, ACS, PMT, CRD, ADR, PHN, EMT, RVS, RPG, CTY, PRV, DST, PST, REG, DEP, TEM, JOB, EGR, PCT, LNT, DPT, CDP, FTP, CHT, RTT, TER, DVT, ERR, RSN, DCS, TPT, QUE, PRI, SLA, CAL, BDY, COT, STP, PCH, CNW, MCC, ACL, BLT, ETY, JSR, PSR, GLC, STF, RPT, AGP, AST, BCL, LCL, JTY, PFR, ACB, DCB, INB, CPM, RIX, RBK, SPT, FEB, FFQ, CHB, TXB, TXJ, DCT, DFM, NPR, DCH, MSG, TSC, RFQ, RCG, EXT, FFM, BGR, BST, JPR, SCH, CLT, TZR, CGP, RGP, BGP, CHC, USG, CSG, APR, AOW, ARS, AFT, PFT, PGR, PFM, PDS, PTR, PGP, FWV, FCP, FRD, CGR, TGR, TRT, LMB, LFQ, LSC, TCL, TXG, TSR, TCH, PSM, PRL, SCY, CCY, COG, VDR, PWN, RVR, AJR, DSR, CMC, SVL, ESL, CSP, CST, WFA, WFR, CUT, CUG, CUS, CUC, CUI, CUO, CUQ, CUV, IDT, IDS, AFM, ADS, CNT, CNS, CSN, CSS, DSS, DSO, DOW, VFT, VFS, RVT, RVO, APT, APO, RQT, RQS, TKS, TKP, QUS, QUT, NFT, NFR, MSS, MSC, EVT, EVS, AUR, AUS, AUV, RLY, RCL, RFL, RPM, RSD, RDV, ESD, EDV, FSR, FST, FDR.
-- Migrates legacy generated reference rows into the generic ref_engine.
-- Legacy tables remain as a read-only safety copy.

-- limit_profile (LMP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('limit_profile', 'Limit profile', 'Cut over from ref_limit_profile', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_profile', code FROM ref_limit_profile;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_profile t ON t.code = v.code
WHERE v.type_code = 'limit_profile'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_profile', t.code, 'CUTOVER', 'migration', 'from ref_limit_profile'
FROM ref_limit_profile t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_profile' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- settlement_account (STL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('settlement_account', 'Settlement account', 'Cut over from ref_settlement_account', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'settlement_account', code FROM ref_settlement_account;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_settlement_account t ON t.code = v.code
WHERE v.type_code = 'settlement_account'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'settlement_account', t.code, 'CUTOVER', 'migration', 'from ref_settlement_account'
FROM ref_settlement_account t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'settlement_account' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- clearing_account (CLR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('clearing_account', 'Clearing account', 'Cut over from ref_clearing_account', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'clearing_account', code FROM ref_clearing_account;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_clearing_account t ON t.code = v.code
WHERE v.type_code = 'clearing_account'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'clearing_account', t.code, 'CUTOVER', 'migration', 'from ref_clearing_account'
FROM ref_clearing_account t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'clearing_account' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- suspense_account (SUS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('suspense_account', 'Suspense account', 'Cut over from ref_suspense_account', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'suspense_account', code FROM ref_suspense_account;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_suspense_account t ON t.code = v.code
WHERE v.type_code = 'suspense_account'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'suspense_account', t.code, 'CUTOVER', 'migration', 'from ref_suspense_account'
FROM ref_suspense_account t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'suspense_account' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rounding_rule (RND)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rounding_rule', 'Rounding rule', 'Cut over from ref_rounding_rule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rounding_rule', code FROM ref_rounding_rule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rounding_rule t ON t.code = v.code
WHERE v.type_code = 'rounding_rule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rounding_rule', t.code, 'CUTOVER', 'migration', 'from ref_rounding_rule'
FROM ref_rounding_rule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rounding_rule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- precision_rule (PRC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('precision_rule', 'Precision rule', 'Cut over from ref_precision_rule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'precision_rule', code FROM ref_precision_rule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_precision_rule t ON t.code = v.code
WHERE v.type_code = 'precision_rule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'precision_rule', t.code, 'CUTOVER', 'migration', 'from ref_precision_rule'
FROM ref_precision_rule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'precision_rule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_code (TAX)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_code', 'Tax code', 'Cut over from ref_tax_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_code', code FROM ref_tax_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_code t ON t.code = v.code
WHERE v.type_code = 'tax_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_code', t.code, 'CUTOVER', 'migration', 'from ref_tax_code'
FROM ref_tax_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- language (LNG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('language', 'Language', 'Cut over from ref_language', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'language', code FROM ref_language;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_language t ON t.code = v.code
WHERE v.type_code = 'language'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'language', t.code, 'CUTOVER', 'migration', 'from ref_language'
FROM ref_language t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'language' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- timezone (TZ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('timezone', 'Timezone', 'Cut over from ref_timezone', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'timezone', code FROM ref_timezone;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_timezone t ON t.code = v.code
WHERE v.type_code = 'timezone'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'timezone', t.code, 'CUTOVER', 'migration', 'from ref_timezone'
FROM ref_timezone t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'timezone' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- country_region (RGN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('country_region', 'Country region', 'Cut over from ref_country_region', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'country_region', code FROM ref_country_region;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_country_region t ON t.code = v.code
WHERE v.type_code = 'country_region'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'country_region', t.code, 'CUTOVER', 'migration', 'from ref_country_region'
FROM ref_country_region t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'country_region' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- currency_pair (CPR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('currency_pair', 'Currency pair', 'Cut over from ref_currency_pair', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'currency_pair', code FROM ref_currency_pair;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_currency_pair t ON t.code = v.code
WHERE v.type_code = 'currency_pair'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'currency_pair', t.code, 'CUTOVER', 'migration', 'from ref_currency_pair'
FROM ref_currency_pair t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'currency_pair' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- holiday_calendar (HCD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('holiday_calendar', 'Holiday calendar', 'Cut over from ref_holiday_calendar', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'holiday_calendar', code FROM ref_holiday_calendar;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_holiday_calendar t ON t.code = v.code
WHERE v.type_code = 'holiday_calendar'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'holiday_calendar', t.code, 'CUTOVER', 'migration', 'from ref_holiday_calendar'
FROM ref_holiday_calendar t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'holiday_calendar' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_template (DTM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_template', 'Document template', 'Cut over from ref_document_template', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_template', code FROM ref_document_template;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_template t ON t.code = v.code
WHERE v.type_code = 'document_template'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_template', t.code, 'CUTOVER', 'migration', 'from ref_document_template'
FROM ref_document_template t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_template' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_channel (NCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_channel', 'Notification channel', 'Cut over from ref_notification_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_channel', code FROM ref_notification_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_channel t ON t.code = v.code
WHERE v.type_code = 'notification_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_channel', t.code, 'CUTOVER', 'migration', 'from ref_notification_channel'
FROM ref_notification_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- audit_event_type (AET)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('audit_event_type', 'Audit event type', 'Cut over from ref_audit_event_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'audit_event_type', code FROM ref_audit_event_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_audit_event_type t ON t.code = v.code
WHERE v.type_code = 'audit_event_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'audit_event_type', t.code, 'CUTOVER', 'migration', 'from ref_audit_event_type'
FROM ref_audit_event_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'audit_event_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- status_reason (SRN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('status_reason', 'Status reason', 'Cut over from ref_status_reason', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'status_reason', code FROM ref_status_reason;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_status_reason t ON t.code = v.code
WHERE v.type_code = 'status_reason'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'status_reason', t.code, 'CUTOVER', 'migration', 'from ref_status_reason'
FROM ref_status_reason t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'status_reason' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_status (ACS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_status', 'Account status', 'Cut over from ref_account_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_status', code FROM ref_account_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_status t ON t.code = v.code
WHERE v.type_code = 'account_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_status', t.code, 'CUTOVER', 'migration', 'from ref_account_status'
FROM ref_account_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- payment_type (PMT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('payment_type', 'Payment type', 'Cut over from ref_payment_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'payment_type', code FROM ref_payment_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_payment_type t ON t.code = v.code
WHERE v.type_code = 'payment_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'payment_type', t.code, 'CUTOVER', 'migration', 'from ref_payment_type'
FROM ref_payment_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'payment_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- card_type (CRD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('card_type', 'Card type', 'Cut over from ref_card_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'card_type', code FROM ref_card_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_card_type t ON t.code = v.code
WHERE v.type_code = 'card_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'card_type', t.code, 'CUTOVER', 'migration', 'from ref_card_type'
FROM ref_card_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'card_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- address_type (ADR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('address_type', 'Address type', 'Cut over from ref_address_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'address_type', code FROM ref_address_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_address_type t ON t.code = v.code
WHERE v.type_code = 'address_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'address_type', t.code, 'CUTOVER', 'migration', 'from ref_address_type'
FROM ref_address_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'address_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- phone_type (PHN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('phone_type', 'Phone type', 'Cut over from ref_phone_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'phone_type', code FROM ref_phone_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_phone_type t ON t.code = v.code
WHERE v.type_code = 'phone_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'phone_type', t.code, 'CUTOVER', 'migration', 'from ref_phone_type'
FROM ref_phone_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'phone_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- email_type (EMT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('email_type', 'Email type', 'Cut over from ref_email_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'email_type', code FROM ref_email_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_email_type t ON t.code = v.code
WHERE v.type_code = 'email_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'email_type', t.code, 'CUTOVER', 'migration', 'from ref_email_type'
FROM ref_email_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'email_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- review_state (RVS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('review_state', 'Review state', 'Cut over from ref_review_state', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'review_state', code FROM ref_review_state;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_review_state t ON t.code = v.code
WHERE v.type_code = 'review_state'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'review_state', t.code, 'CUTOVER', 'migration', 'from ref_review_state'
FROM ref_review_state t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'review_state' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_group (RPG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_group', 'Report group', 'Cut over from ref_report_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_group', code FROM ref_report_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_group t ON t.code = v.code
WHERE v.type_code = 'report_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_group', t.code, 'CUTOVER', 'migration', 'from ref_report_group'
FROM ref_report_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- city (CTY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('city', 'City', 'Cut over from ref_city', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'city', code FROM ref_city;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_city t ON t.code = v.code
WHERE v.type_code = 'city'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'city', t.code, 'CUTOVER', 'migration', 'from ref_city'
FROM ref_city t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'city' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- province (PRV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('province', 'Province', 'Cut over from ref_province', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'province', code FROM ref_province;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_province t ON t.code = v.code
WHERE v.type_code = 'province'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'province', t.code, 'CUTOVER', 'migration', 'from ref_province'
FROM ref_province t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'province' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- district (DST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('district', 'District', 'Cut over from ref_district', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'district', code FROM ref_district;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_district t ON t.code = v.code
WHERE v.type_code = 'district'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'district', t.code, 'CUTOVER', 'migration', 'from ref_district'
FROM ref_district t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'district' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- postal_code (PST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('postal_code', 'Postal code', 'Cut over from ref_postal_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'postal_code', code FROM ref_postal_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_postal_code t ON t.code = v.code
WHERE v.type_code = 'postal_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'postal_code', t.code, 'CUTOVER', 'migration', 'from ref_postal_code'
FROM ref_postal_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'postal_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- region (REG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('region', 'Region', 'Cut over from ref_region', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'region', code FROM ref_region;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_region t ON t.code = v.code
WHERE v.type_code = 'region'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'region', t.code, 'CUTOVER', 'migration', 'from ref_region'
FROM ref_region t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'region' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- department (DEP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('department', 'Department', 'Cut over from ref_department', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'department', code FROM ref_department;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_department t ON t.code = v.code
WHERE v.type_code = 'department'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'department', t.code, 'CUTOVER', 'migration', 'from ref_department'
FROM ref_department t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'department' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- team (TEM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('team', 'Team', 'Cut over from ref_team', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'team', code FROM ref_team;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_team t ON t.code = v.code
WHERE v.type_code = 'team'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'team', t.code, 'CUTOVER', 'migration', 'from ref_team'
FROM ref_team t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'team' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- job_title (JOB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('job_title', 'Job title', 'Cut over from ref_job_title', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'job_title', code FROM ref_job_title;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_job_title t ON t.code = v.code
WHERE v.type_code = 'job_title'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'job_title', t.code, 'CUTOVER', 'migration', 'from ref_job_title'
FROM ref_job_title t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'job_title' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- employee_grade (EGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('employee_grade', 'Employee grade', 'Cut over from ref_employee_grade', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'employee_grade', code FROM ref_employee_grade;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_employee_grade t ON t.code = v.code
WHERE v.type_code = 'employee_grade'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'employee_grade', t.code, 'CUTOVER', 'migration', 'from ref_employee_grade'
FROM ref_employee_grade t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'employee_grade' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- profit_center (PCT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('profit_center', 'Profit center', 'Cut over from ref_profit_center', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'profit_center', code FROM ref_profit_center;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_profit_center t ON t.code = v.code
WHERE v.type_code = 'profit_center'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'profit_center', t.code, 'CUTOVER', 'migration', 'from ref_profit_center'
FROM ref_profit_center t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'profit_center' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- loan_type (LNT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('loan_type', 'Loan type', 'Cut over from ref_loan_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'loan_type', code FROM ref_loan_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_loan_type t ON t.code = v.code
WHERE v.type_code = 'loan_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'loan_type', t.code, 'CUTOVER', 'migration', 'from ref_loan_type'
FROM ref_loan_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'loan_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- deposit_type (DPT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('deposit_type', 'Deposit type', 'Cut over from ref_deposit_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'deposit_type', code FROM ref_deposit_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_deposit_type t ON t.code = v.code
WHERE v.type_code = 'deposit_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'deposit_type', t.code, 'CUTOVER', 'migration', 'from ref_deposit_type'
FROM ref_deposit_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'deposit_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- card_product (CDP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('card_product', 'Card product', 'Cut over from ref_card_product', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'card_product', code FROM ref_card_product;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_card_product t ON t.code = v.code
WHERE v.type_code = 'card_product'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'card_product', t.code, 'CUTOVER', 'migration', 'from ref_card_product'
FROM ref_card_product t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'card_product' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_type (FTP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_type', 'Fee type', 'Cut over from ref_fee_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_type', code FROM ref_fee_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_type t ON t.code = v.code
WHERE v.type_code = 'fee_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_type', t.code, 'CUTOVER', 'migration', 'from ref_fee_type'
FROM ref_fee_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- charge_type (CHT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('charge_type', 'Charge type', 'Cut over from ref_charge_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'charge_type', code FROM ref_charge_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_charge_type t ON t.code = v.code
WHERE v.type_code = 'charge_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'charge_type', t.code, 'CUTOVER', 'migration', 'from ref_charge_type'
FROM ref_charge_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'charge_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rate_type (RTT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rate_type', 'Rate type', 'Cut over from ref_rate_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rate_type', code FROM ref_rate_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rate_type t ON t.code = v.code
WHERE v.type_code = 'rate_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rate_type', t.code, 'CUTOVER', 'migration', 'from ref_rate_type'
FROM ref_rate_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rate_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tier (TER)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tier', 'Tier', 'Cut over from ref_tier', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tier', code FROM ref_tier;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tier t ON t.code = v.code
WHERE v.type_code = 'tier'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tier', t.code, 'CUTOVER', 'migration', 'from ref_tier'
FROM ref_tier t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tier' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- device_type (DVT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('device_type', 'Device type', 'Cut over from ref_device_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'device_type', code FROM ref_device_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_device_type t ON t.code = v.code
WHERE v.type_code = 'device_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'device_type', t.code, 'CUTOVER', 'migration', 'from ref_device_type'
FROM ref_device_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'device_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- error_code (ERR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('error_code', 'Error code', 'Cut over from ref_error_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'error_code', code FROM ref_error_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_error_code t ON t.code = v.code
WHERE v.type_code = 'error_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'error_code', t.code, 'CUTOVER', 'migration', 'from ref_error_code'
FROM ref_error_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'error_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- reason_code (RSN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('reason_code', 'Reason code', 'Cut over from ref_reason_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'reason_code', code FROM ref_reason_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_reason_code t ON t.code = v.code
WHERE v.type_code = 'reason_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'reason_code', t.code, 'CUTOVER', 'migration', 'from ref_reason_code'
FROM ref_reason_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'reason_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_status (DCS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_status', 'Document status', 'Cut over from ref_document_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_status', code FROM ref_document_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_status t ON t.code = v.code
WHERE v.type_code = 'document_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_status', t.code, 'CUTOVER', 'migration', 'from ref_document_status'
FROM ref_document_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- template_type (TPT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('template_type', 'Template type', 'Cut over from ref_template_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'template_type', code FROM ref_template_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_template_type t ON t.code = v.code
WHERE v.type_code = 'template_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'template_type', t.code, 'CUTOVER', 'migration', 'from ref_template_type'
FROM ref_template_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'template_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- queue (QUE)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('queue', 'Queue', 'Cut over from ref_queue', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'queue', code FROM ref_queue;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_queue t ON t.code = v.code
WHERE v.type_code = 'queue'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'queue', t.code, 'CUTOVER', 'migration', 'from ref_queue'
FROM ref_queue t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'queue' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- priority (PRI)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('priority', 'Priority', 'Cut over from ref_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'priority', code FROM ref_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_priority t ON t.code = v.code
WHERE v.type_code = 'priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'priority', t.code, 'CUTOVER', 'migration', 'from ref_priority'
FROM ref_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- sla_profile (SLA)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('sla_profile', 'Sla profile', 'Cut over from ref_sla_profile', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'sla_profile', code FROM ref_sla_profile;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_sla_profile t ON t.code = v.code
WHERE v.type_code = 'sla_profile'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'sla_profile', t.code, 'CUTOVER', 'migration', 'from ref_sla_profile'
FROM ref_sla_profile t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'sla_profile' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- calendar (CAL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('calendar', 'Calendar', 'Cut over from ref_calendar', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'calendar', code FROM ref_calendar;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_calendar t ON t.code = v.code
WHERE v.type_code = 'calendar'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'calendar', t.code, 'CUTOVER', 'migration', 'from ref_calendar'
FROM ref_calendar t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'calendar' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- business_day (BDY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('business_day', 'Business day', 'Cut over from ref_business_day', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'business_day', code FROM ref_business_day;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_business_day t ON t.code = v.code
WHERE v.type_code = 'business_day'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'business_day', t.code, 'CUTOVER', 'migration', 'from ref_business_day'
FROM ref_business_day t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'business_day' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- cut_off_time (COT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('cut_off_time', 'Cut off time', 'Cut over from ref_cut_off_time', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'cut_off_time', code FROM ref_cut_off_time;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_cut_off_time t ON t.code = v.code
WHERE v.type_code = 'cut_off_time'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'cut_off_time', t.code, 'CUTOVER', 'migration', 'from ref_cut_off_time'
FROM ref_cut_off_time t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'cut_off_time' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- settlement_type (STP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('settlement_type', 'Settlement type', 'Cut over from ref_settlement_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'settlement_type', code FROM ref_settlement_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_settlement_type t ON t.code = v.code
WHERE v.type_code = 'settlement_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'settlement_type', t.code, 'CUTOVER', 'migration', 'from ref_settlement_type'
FROM ref_settlement_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'settlement_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- payment_channel (PCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('payment_channel', 'Payment channel', 'Cut over from ref_payment_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'payment_channel', code FROM ref_payment_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_payment_channel t ON t.code = v.code
WHERE v.type_code = 'payment_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'payment_channel', t.code, 'CUTOVER', 'migration', 'from ref_payment_channel'
FROM ref_payment_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'payment_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- card_network (CNW)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('card_network', 'Card network', 'Cut over from ref_card_network', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'card_network', code FROM ref_card_network;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_card_network t ON t.code = v.code
WHERE v.type_code = 'card_network'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'card_network', t.code, 'CUTOVER', 'migration', 'from ref_card_network'
FROM ref_card_network t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'card_network' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- merchant_category (MCC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('merchant_category', 'Merchant category', 'Cut over from ref_merchant_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'merchant_category', code FROM ref_merchant_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_merchant_category t ON t.code = v.code
WHERE v.type_code = 'merchant_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'merchant_category', t.code, 'CUTOVER', 'migration', 'from ref_merchant_category'
FROM ref_merchant_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'merchant_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_class (ACL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_class', 'Account class', 'Cut over from ref_account_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_class', code FROM ref_account_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_class t ON t.code = v.code
WHERE v.type_code = 'account_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_class', t.code, 'CUTOVER', 'migration', 'from ref_account_class'
FROM ref_account_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- balance_type (BLT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('balance_type', 'Balance type', 'Cut over from ref_balance_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'balance_type', code FROM ref_balance_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_balance_type t ON t.code = v.code
WHERE v.type_code = 'balance_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'balance_type', t.code, 'CUTOVER', 'migration', 'from ref_balance_type'
FROM ref_balance_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'balance_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- entry_type (ETY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('entry_type', 'Entry type', 'Cut over from ref_entry_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'entry_type', code FROM ref_entry_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_entry_type t ON t.code = v.code
WHERE v.type_code = 'entry_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'entry_type', t.code, 'CUTOVER', 'migration', 'from ref_entry_type'
FROM ref_entry_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'entry_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- journal_source (JSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('journal_source', 'Journal source', 'Cut over from ref_journal_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'journal_source', code FROM ref_journal_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_journal_source t ON t.code = v.code
WHERE v.type_code = 'journal_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'journal_source', t.code, 'CUTOVER', 'migration', 'from ref_journal_source'
FROM ref_journal_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'journal_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- posting_rule (PSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('posting_rule', 'Posting rule', 'Cut over from ref_posting_rule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'posting_rule', code FROM ref_posting_rule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_posting_rule t ON t.code = v.code
WHERE v.type_code = 'posting_rule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'posting_rule', t.code, 'CUTOVER', 'migration', 'from ref_posting_rule'
FROM ref_posting_rule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'posting_rule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- gl_category (GLC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('gl_category', 'Gl category', 'Cut over from ref_gl_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'gl_category', code FROM ref_gl_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_gl_category t ON t.code = v.code
WHERE v.type_code = 'gl_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'gl_category', t.code, 'CUTOVER', 'migration', 'from ref_gl_category'
FROM ref_gl_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'gl_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- statement_format (STF)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('statement_format', 'Statement format', 'Cut over from ref_statement_format', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'statement_format', code FROM ref_statement_format;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_statement_format t ON t.code = v.code
WHERE v.type_code = 'statement_format'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'statement_format', t.code, 'CUTOVER', 'migration', 'from ref_statement_format'
FROM ref_statement_format t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'statement_format' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_type (RPT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_type', 'Report type', 'Cut over from ref_report_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_type', code FROM ref_report_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_type t ON t.code = v.code
WHERE v.type_code = 'report_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_type', t.code, 'CUTOVER', 'migration', 'from ref_report_type'
FROM ref_report_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_group (AGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_group', 'Account group', 'Cut over from ref_account_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_group', code FROM ref_account_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_group t ON t.code = v.code
WHERE v.type_code = 'account_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_group', t.code, 'CUTOVER', 'migration', 'from ref_account_group'
FROM ref_account_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_subtype (AST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_subtype', 'Account subtype', 'Cut over from ref_account_subtype', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_subtype', code FROM ref_account_subtype;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_subtype t ON t.code = v.code
WHERE v.type_code = 'account_subtype'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_subtype', t.code, 'CUTOVER', 'migration', 'from ref_account_subtype'
FROM ref_account_subtype t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_subtype' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- balance_class (BCL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('balance_class', 'Balance class', 'Cut over from ref_balance_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'balance_class', code FROM ref_balance_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_balance_class t ON t.code = v.code
WHERE v.type_code = 'balance_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'balance_class', t.code, 'CUTOVER', 'migration', 'from ref_balance_class'
FROM ref_balance_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'balance_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- ledger_class (LCL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('ledger_class', 'Ledger class', 'Cut over from ref_ledger_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'ledger_class', code FROM ref_ledger_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_ledger_class t ON t.code = v.code
WHERE v.type_code = 'ledger_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'ledger_class', t.code, 'CUTOVER', 'migration', 'from ref_ledger_class'
FROM ref_ledger_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'ledger_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- journal_type (JTY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('journal_type', 'Journal type', 'Cut over from ref_journal_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'journal_type', code FROM ref_journal_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_journal_type t ON t.code = v.code
WHERE v.type_code = 'journal_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'journal_type', t.code, 'CUTOVER', 'migration', 'from ref_journal_type'
FROM ref_journal_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'journal_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- posting_frequency (PFR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('posting_frequency', 'Posting frequency', 'Cut over from ref_posting_frequency', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'posting_frequency', code FROM ref_posting_frequency;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_posting_frequency t ON t.code = v.code
WHERE v.type_code = 'posting_frequency'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'posting_frequency', t.code, 'CUTOVER', 'migration', 'from ref_posting_frequency'
FROM ref_posting_frequency t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'posting_frequency' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- accrual_basis (ACB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('accrual_basis', 'Accrual basis', 'Cut over from ref_accrual_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'accrual_basis', code FROM ref_accrual_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_accrual_basis t ON t.code = v.code
WHERE v.type_code = 'accrual_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'accrual_basis', t.code, 'CUTOVER', 'migration', 'from ref_accrual_basis'
FROM ref_accrual_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'accrual_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- day_count_basis (DCB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('day_count_basis', 'Day count basis', 'Cut over from ref_day_count_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'day_count_basis', code FROM ref_day_count_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_day_count_basis t ON t.code = v.code
WHERE v.type_code = 'day_count_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'day_count_basis', t.code, 'CUTOVER', 'migration', 'from ref_day_count_basis'
FROM ref_day_count_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'day_count_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- interest_basis (INB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('interest_basis', 'Interest basis', 'Cut over from ref_interest_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'interest_basis', code FROM ref_interest_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_interest_basis t ON t.code = v.code
WHERE v.type_code = 'interest_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'interest_basis', t.code, 'CUTOVER', 'migration', 'from ref_interest_basis'
FROM ref_interest_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'interest_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- compounding_method (CPM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('compounding_method', 'Compounding method', 'Cut over from ref_compounding_method', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'compounding_method', code FROM ref_compounding_method;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_compounding_method t ON t.code = v.code
WHERE v.type_code = 'compounding_method'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'compounding_method', t.code, 'CUTOVER', 'migration', 'from ref_compounding_method'
FROM ref_compounding_method t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'compounding_method' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rate_index (RIX)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rate_index', 'Rate index', 'Cut over from ref_rate_index', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rate_index', code FROM ref_rate_index;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rate_index t ON t.code = v.code
WHERE v.type_code = 'rate_index'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rate_index', t.code, 'CUTOVER', 'migration', 'from ref_rate_index'
FROM ref_rate_index t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rate_index' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rate_benchmark (RBK)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rate_benchmark', 'Rate benchmark', 'Cut over from ref_rate_benchmark', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rate_benchmark', code FROM ref_rate_benchmark;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rate_benchmark t ON t.code = v.code
WHERE v.type_code = 'rate_benchmark'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rate_benchmark', t.code, 'CUTOVER', 'migration', 'from ref_rate_benchmark'
FROM ref_rate_benchmark t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rate_benchmark' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- spread_type (SPT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('spread_type', 'Spread type', 'Cut over from ref_spread_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'spread_type', code FROM ref_spread_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_spread_type t ON t.code = v.code
WHERE v.type_code = 'spread_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'spread_type', t.code, 'CUTOVER', 'migration', 'from ref_spread_type'
FROM ref_spread_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'spread_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_basis (FEB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_basis', 'Fee basis', 'Cut over from ref_fee_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_basis', code FROM ref_fee_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_basis t ON t.code = v.code
WHERE v.type_code = 'fee_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_basis', t.code, 'CUTOVER', 'migration', 'from ref_fee_basis'
FROM ref_fee_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_frequency (FFQ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_frequency', 'Fee frequency', 'Cut over from ref_fee_frequency', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_frequency', code FROM ref_fee_frequency;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_frequency t ON t.code = v.code
WHERE v.type_code = 'fee_frequency'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_frequency', t.code, 'CUTOVER', 'migration', 'from ref_fee_frequency'
FROM ref_fee_frequency t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_frequency' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- charge_basis (CHB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('charge_basis', 'Charge basis', 'Cut over from ref_charge_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'charge_basis', code FROM ref_charge_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_charge_basis t ON t.code = v.code
WHERE v.type_code = 'charge_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'charge_basis', t.code, 'CUTOVER', 'migration', 'from ref_charge_basis'
FROM ref_charge_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'charge_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_basis (TXB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_basis', 'Tax basis', 'Cut over from ref_tax_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_basis', code FROM ref_tax_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_basis t ON t.code = v.code
WHERE v.type_code = 'tax_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_basis', t.code, 'CUTOVER', 'migration', 'from ref_tax_basis'
FROM ref_tax_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_jurisdiction (TXJ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_jurisdiction', 'Tax jurisdiction', 'Cut over from ref_tax_jurisdiction', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_jurisdiction', code FROM ref_tax_jurisdiction;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_jurisdiction t ON t.code = v.code
WHERE v.type_code = 'tax_jurisdiction'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_jurisdiction', t.code, 'CUTOVER', 'migration', 'from ref_tax_jurisdiction'
FROM ref_tax_jurisdiction t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_jurisdiction' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_category (DCT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_category', 'Document category', 'Cut over from ref_document_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_category', code FROM ref_document_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_category t ON t.code = v.code
WHERE v.type_code = 'document_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_category', t.code, 'CUTOVER', 'migration', 'from ref_document_category'
FROM ref_document_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_format (DFM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_format', 'Document format', 'Cut over from ref_document_format', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_format', code FROM ref_document_format;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_format t ON t.code = v.code
WHERE v.type_code = 'document_format'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_format', t.code, 'CUTOVER', 'migration', 'from ref_document_format'
FROM ref_document_format t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_format' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_priority (NPR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_priority', 'Notification priority', 'Cut over from ref_notification_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_priority', code FROM ref_notification_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_priority t ON t.code = v.code
WHERE v.type_code = 'notification_priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_priority', t.code, 'CUTOVER', 'migration', 'from ref_notification_priority'
FROM ref_notification_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- delivery_channel (DCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('delivery_channel', 'Delivery channel', 'Cut over from ref_delivery_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'delivery_channel', code FROM ref_delivery_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_delivery_channel t ON t.code = v.code
WHERE v.type_code = 'delivery_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'delivery_channel', t.code, 'CUTOVER', 'migration', 'from ref_delivery_channel'
FROM ref_delivery_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'delivery_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- message_type (MSG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('message_type', 'Message type', 'Cut over from ref_message_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'message_type', code FROM ref_message_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_message_type t ON t.code = v.code
WHERE v.type_code = 'message_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'message_type', t.code, 'CUTOVER', 'migration', 'from ref_message_type'
FROM ref_message_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'message_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- template_scope (TSC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('template_scope', 'Template scope', 'Cut over from ref_template_scope', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'template_scope', code FROM ref_template_scope;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_template_scope t ON t.code = v.code
WHERE v.type_code = 'template_scope'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'template_scope', t.code, 'CUTOVER', 'migration', 'from ref_template_scope'
FROM ref_template_scope t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'template_scope' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_frequency (RFQ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_frequency', 'Report frequency', 'Cut over from ref_report_frequency', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_frequency', code FROM ref_report_frequency;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_frequency t ON t.code = v.code
WHERE v.type_code = 'report_frequency'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_frequency', t.code, 'CUTOVER', 'migration', 'from ref_report_frequency'
FROM ref_report_frequency t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_frequency' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_category (RCG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_category', 'Report category', 'Cut over from ref_report_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_category', code FROM ref_report_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_category t ON t.code = v.code
WHERE v.type_code = 'report_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_category', t.code, 'CUTOVER', 'migration', 'from ref_report_category'
FROM ref_report_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- export_type (EXT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('export_type', 'Export type', 'Cut over from ref_export_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'export_type', code FROM ref_export_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_export_type t ON t.code = v.code
WHERE v.type_code = 'export_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'export_type', t.code, 'CUTOVER', 'migration', 'from ref_export_type'
FROM ref_export_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'export_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- file_format (FFM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('file_format', 'File format', 'Cut over from ref_file_format', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'file_format', code FROM ref_file_format;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_file_format t ON t.code = v.code
WHERE v.type_code = 'file_format'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'file_format', t.code, 'CUTOVER', 'migration', 'from ref_file_format'
FROM ref_file_format t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'file_format' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- batch_group (BGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('batch_group', 'Batch group', 'Cut over from ref_batch_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'batch_group', code FROM ref_batch_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_batch_group t ON t.code = v.code
WHERE v.type_code = 'batch_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'batch_group', t.code, 'CUTOVER', 'migration', 'from ref_batch_group'
FROM ref_batch_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'batch_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- batch_status (BST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('batch_status', 'Batch status', 'Cut over from ref_batch_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'batch_status', code FROM ref_batch_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_batch_status t ON t.code = v.code
WHERE v.type_code = 'batch_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'batch_status', t.code, 'CUTOVER', 'migration', 'from ref_batch_status'
FROM ref_batch_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'batch_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- job_priority (JPR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('job_priority', 'Job priority', 'Cut over from ref_job_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'job_priority', code FROM ref_job_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_job_priority t ON t.code = v.code
WHERE v.type_code = 'job_priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'job_priority', t.code, 'CUTOVER', 'migration', 'from ref_job_priority'
FROM ref_job_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'job_priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- schedule_type (SCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('schedule_type', 'Schedule type', 'Cut over from ref_schedule_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'schedule_type', code FROM ref_schedule_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_schedule_type t ON t.code = v.code
WHERE v.type_code = 'schedule_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'schedule_type', t.code, 'CUTOVER', 'migration', 'from ref_schedule_type'
FROM ref_schedule_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'schedule_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- calendar_type (CLT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('calendar_type', 'Calendar type', 'Cut over from ref_calendar_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'calendar_type', code FROM ref_calendar_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_calendar_type t ON t.code = v.code
WHERE v.type_code = 'calendar_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'calendar_type', t.code, 'CUTOVER', 'migration', 'from ref_calendar_type'
FROM ref_calendar_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'calendar_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- timezone_region (TZR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('timezone_region', 'Timezone region', 'Cut over from ref_timezone_region', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'timezone_region', code FROM ref_timezone_region;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_timezone_region t ON t.code = v.code
WHERE v.type_code = 'timezone_region'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'timezone_region', t.code, 'CUTOVER', 'migration', 'from ref_timezone_region'
FROM ref_timezone_region t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'timezone_region' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- country_group (CGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('country_group', 'Country group', 'Cut over from ref_country_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'country_group', code FROM ref_country_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_country_group t ON t.code = v.code
WHERE v.type_code = 'country_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'country_group', t.code, 'CUTOVER', 'migration', 'from ref_country_group'
FROM ref_country_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'country_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- region_group (RGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('region_group', 'Region group', 'Cut over from ref_region_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'region_group', code FROM ref_region_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_region_group t ON t.code = v.code
WHERE v.type_code = 'region_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'region_group', t.code, 'CUTOVER', 'migration', 'from ref_region_group'
FROM ref_region_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'region_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- branch_group (BGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('branch_group', 'Branch group', 'Cut over from ref_branch_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'branch_group', code FROM ref_branch_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_branch_group t ON t.code = v.code
WHERE v.type_code = 'branch_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'branch_group', t.code, 'CUTOVER', 'migration', 'from ref_branch_group'
FROM ref_branch_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'branch_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- channel_class (CHC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('channel_class', 'Channel class', 'Cut over from ref_channel_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'channel_class', code FROM ref_channel_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_channel_class t ON t.code = v.code
WHERE v.type_code = 'channel_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'channel_class', t.code, 'CUTOVER', 'migration', 'from ref_channel_class'
FROM ref_channel_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'channel_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- user_segment (USG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('user_segment', 'User segment', 'Cut over from ref_user_segment', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'user_segment', code FROM ref_user_segment;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_user_segment t ON t.code = v.code
WHERE v.type_code = 'user_segment'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'user_segment', t.code, 'CUTOVER', 'migration', 'from ref_user_segment'
FROM ref_user_segment t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'user_segment' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_segment (CSG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_segment', 'Customer segment', 'Cut over from ref_customer_segment', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_segment', code FROM ref_customer_segment;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_segment t ON t.code = v.code
WHERE v.type_code = 'customer_segment'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_segment', t.code, 'CUTOVER', 'migration', 'from ref_customer_segment'
FROM ref_customer_segment t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_segment' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_purpose (APR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_purpose', 'Account purpose', 'Cut over from ref_account_purpose', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_purpose', code FROM ref_account_purpose;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_purpose t ON t.code = v.code
WHERE v.type_code = 'account_purpose'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_purpose', t.code, 'CUTOVER', 'migration', 'from ref_account_purpose'
FROM ref_account_purpose t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_purpose' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_ownership (AOW)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_ownership', 'Account ownership', 'Cut over from ref_account_ownership', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_ownership', code FROM ref_account_ownership;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_ownership t ON t.code = v.code
WHERE v.type_code = 'account_ownership'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_ownership', t.code, 'CUTOVER', 'migration', 'from ref_account_ownership'
FROM ref_account_ownership t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_ownership' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_restriction (ARS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_restriction', 'Account restriction', 'Cut over from ref_account_restriction', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_restriction', code FROM ref_account_restriction;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_restriction t ON t.code = v.code
WHERE v.type_code = 'account_restriction'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_restriction', t.code, 'CUTOVER', 'migration', 'from ref_account_restriction'
FROM ref_account_restriction t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_restriction' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_feature (AFT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_feature', 'Account feature', 'Cut over from ref_account_feature', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_feature', code FROM ref_account_feature;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_feature t ON t.code = v.code
WHERE v.type_code = 'account_feature'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_feature', t.code, 'CUTOVER', 'migration', 'from ref_account_feature'
FROM ref_account_feature t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_feature' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- product_feature (PFT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('product_feature', 'Product feature', 'Cut over from ref_product_feature', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_feature', code FROM ref_product_feature;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_feature t ON t.code = v.code
WHERE v.type_code = 'product_feature'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_feature', t.code, 'CUTOVER', 'migration', 'from ref_product_feature'
FROM ref_product_feature t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_feature' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- product_group (PGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('product_group', 'Product group', 'Cut over from ref_product_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_group', code FROM ref_product_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_group t ON t.code = v.code
WHERE v.type_code = 'product_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_group', t.code, 'CUTOVER', 'migration', 'from ref_product_group'
FROM ref_product_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- product_family (PFM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('product_family', 'Product family', 'Cut over from ref_product_family', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_family', code FROM ref_product_family;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_family t ON t.code = v.code
WHERE v.type_code = 'product_family'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_family', t.code, 'CUTOVER', 'migration', 'from ref_product_family'
FROM ref_product_family t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_family' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- product_status (PDS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('product_status', 'Product status', 'Cut over from ref_product_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_status', code FROM ref_product_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_status t ON t.code = v.code
WHERE v.type_code = 'product_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_status', t.code, 'CUTOVER', 'migration', 'from ref_product_status'
FROM ref_product_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- pricing_tier (PTR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('pricing_tier', 'Pricing tier', 'Cut over from ref_pricing_tier', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'pricing_tier', code FROM ref_pricing_tier;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_pricing_tier t ON t.code = v.code
WHERE v.type_code = 'pricing_tier'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'pricing_tier', t.code, 'CUTOVER', 'migration', 'from ref_pricing_tier'
FROM ref_pricing_tier t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'pricing_tier' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- pricing_group (PGP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('pricing_group', 'Pricing group', 'Cut over from ref_pricing_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'pricing_group', code FROM ref_pricing_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_pricing_group t ON t.code = v.code
WHERE v.type_code = 'pricing_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'pricing_group', t.code, 'CUTOVER', 'migration', 'from ref_pricing_group'
FROM ref_pricing_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'pricing_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_waiver (FWV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_waiver', 'Fee waiver', 'Cut over from ref_fee_waiver', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_waiver', code FROM ref_fee_waiver;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_waiver t ON t.code = v.code
WHERE v.type_code = 'fee_waiver'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_waiver', t.code, 'CUTOVER', 'migration', 'from ref_fee_waiver'
FROM ref_fee_waiver t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_waiver' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_cap (FCP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_cap', 'Fee cap', 'Cut over from ref_fee_cap', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_cap', code FROM ref_fee_cap;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_cap t ON t.code = v.code
WHERE v.type_code = 'fee_cap'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_cap', t.code, 'CUTOVER', 'migration', 'from ref_fee_cap'
FROM ref_fee_cap t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_cap' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- fee_rounding (FRD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('fee_rounding', 'Fee rounding', 'Cut over from ref_fee_rounding', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_rounding', code FROM ref_fee_rounding;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_rounding t ON t.code = v.code
WHERE v.type_code = 'fee_rounding'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_rounding', t.code, 'CUTOVER', 'migration', 'from ref_fee_rounding'
FROM ref_fee_rounding t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_rounding' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- charge_group (CGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('charge_group', 'Charge group', 'Cut over from ref_charge_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'charge_group', code FROM ref_charge_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_charge_group t ON t.code = v.code
WHERE v.type_code = 'charge_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'charge_group', t.code, 'CUTOVER', 'migration', 'from ref_charge_group'
FROM ref_charge_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'charge_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_group (TGR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_group', 'Tax group', 'Cut over from ref_tax_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_group', code FROM ref_tax_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_group t ON t.code = v.code
WHERE v.type_code = 'tax_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_group', t.code, 'CUTOVER', 'migration', 'from ref_tax_group'
FROM ref_tax_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- tax_rate_type (TRT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('tax_rate_type', 'Tax rate type', 'Cut over from ref_tax_rate_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'tax_rate_type', code FROM ref_tax_rate_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_tax_rate_type t ON t.code = v.code
WHERE v.type_code = 'tax_rate_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'tax_rate_type', t.code, 'CUTOVER', 'migration', 'from ref_tax_rate_type'
FROM ref_tax_rate_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'tax_rate_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- limit_basis (LMB)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('limit_basis', 'Limit basis', 'Cut over from ref_limit_basis', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_basis', code FROM ref_limit_basis;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_basis t ON t.code = v.code
WHERE v.type_code = 'limit_basis'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_basis', t.code, 'CUTOVER', 'migration', 'from ref_limit_basis'
FROM ref_limit_basis t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_basis' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- limit_frequency (LFQ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('limit_frequency', 'Limit frequency', 'Cut over from ref_limit_frequency', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_frequency', code FROM ref_limit_frequency;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_frequency t ON t.code = v.code
WHERE v.type_code = 'limit_frequency'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_frequency', t.code, 'CUTOVER', 'migration', 'from ref_limit_frequency'
FROM ref_limit_frequency t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_frequency' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- limit_scope (LSC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('limit_scope', 'Limit scope', 'Cut over from ref_limit_scope', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_scope', code FROM ref_limit_scope;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_scope t ON t.code = v.code
WHERE v.type_code = 'limit_scope'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_scope', t.code, 'CUTOVER', 'migration', 'from ref_limit_scope'
FROM ref_limit_scope t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_scope' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_class (TCL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_class', 'Transaction class', 'Cut over from ref_transaction_class', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_class', code FROM ref_transaction_class;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_class t ON t.code = v.code
WHERE v.type_code = 'transaction_class'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_class', t.code, 'CUTOVER', 'migration', 'from ref_transaction_class'
FROM ref_transaction_class t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_class' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_group (TXG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_group', 'Transaction group', 'Cut over from ref_transaction_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_group', code FROM ref_transaction_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_group t ON t.code = v.code
WHERE v.type_code = 'transaction_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_group', t.code, 'CUTOVER', 'migration', 'from ref_transaction_group'
FROM ref_transaction_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_status (TSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_status', 'Transaction status', 'Cut over from ref_transaction_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_status', code FROM ref_transaction_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_status t ON t.code = v.code
WHERE v.type_code = 'transaction_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_status', t.code, 'CUTOVER', 'migration', 'from ref_transaction_status'
FROM ref_transaction_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_channel (TCH)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_channel', 'Transaction channel', 'Cut over from ref_transaction_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_channel', code FROM ref_transaction_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_channel t ON t.code = v.code
WHERE v.type_code = 'transaction_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_channel', t.code, 'CUTOVER', 'migration', 'from ref_transaction_channel'
FROM ref_transaction_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- payment_scheme (PSM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('payment_scheme', 'Payment scheme', 'Cut over from ref_payment_scheme', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'payment_scheme', code FROM ref_payment_scheme;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_payment_scheme t ON t.code = v.code
WHERE v.type_code = 'payment_scheme'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'payment_scheme', t.code, 'CUTOVER', 'migration', 'from ref_payment_scheme'
FROM ref_payment_scheme t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'payment_scheme' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- payment_rail (PRL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('payment_rail', 'Payment rail', 'Cut over from ref_payment_rail', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'payment_rail', code FROM ref_payment_rail;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_payment_rail t ON t.code = v.code
WHERE v.type_code = 'payment_rail'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'payment_rail', t.code, 'CUTOVER', 'migration', 'from ref_payment_rail'
FROM ref_payment_rail t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'payment_rail' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- settlement_cycle (SCY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('settlement_cycle', 'Settlement cycle', 'Cut over from ref_settlement_cycle', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'settlement_cycle', code FROM ref_settlement_cycle;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_settlement_cycle t ON t.code = v.code
WHERE v.type_code = 'settlement_cycle'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'settlement_cycle', t.code, 'CUTOVER', 'migration', 'from ref_settlement_cycle'
FROM ref_settlement_cycle t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'settlement_cycle' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- clearing_cycle (CCY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('clearing_cycle', 'Clearing cycle', 'Cut over from ref_clearing_cycle', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'clearing_cycle', code FROM ref_clearing_cycle;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_clearing_cycle t ON t.code = v.code
WHERE v.type_code = 'clearing_cycle'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'clearing_cycle', t.code, 'CUTOVER', 'migration', 'from ref_clearing_cycle'
FROM ref_clearing_cycle t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'clearing_cycle' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- cut_off_group (COG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('cut_off_group', 'Cut off group', 'Cut over from ref_cut_off_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'cut_off_group', code FROM ref_cut_off_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_cut_off_group t ON t.code = v.code
WHERE v.type_code = 'cut_off_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'cut_off_group', t.code, 'CUTOVER', 'migration', 'from ref_cut_off_group'
FROM ref_cut_off_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'cut_off_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- value_date_rule (VDR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('value_date_rule', 'Value date rule', 'Cut over from ref_value_date_rule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'value_date_rule', code FROM ref_value_date_rule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_value_date_rule t ON t.code = v.code
WHERE v.type_code = 'value_date_rule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'value_date_rule', t.code, 'CUTOVER', 'migration', 'from ref_value_date_rule'
FROM ref_value_date_rule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'value_date_rule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- posting_window (PWN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('posting_window', 'Posting window', 'Cut over from ref_posting_window', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'posting_window', code FROM ref_posting_window;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_posting_window t ON t.code = v.code
WHERE v.type_code = 'posting_window'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'posting_window', t.code, 'CUTOVER', 'migration', 'from ref_posting_window'
FROM ref_posting_window t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'posting_window' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- reversal_reason (RVR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('reversal_reason', 'Reversal reason', 'Cut over from ref_reversal_reason', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'reversal_reason', code FROM ref_reversal_reason;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_reversal_reason t ON t.code = v.code
WHERE v.type_code = 'reversal_reason'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'reversal_reason', t.code, 'CUTOVER', 'migration', 'from ref_reversal_reason'
FROM ref_reversal_reason t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'reversal_reason' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- adjustment_reason (AJR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('adjustment_reason', 'Adjustment reason', 'Cut over from ref_adjustment_reason', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'adjustment_reason', code FROM ref_adjustment_reason;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_adjustment_reason t ON t.code = v.code
WHERE v.type_code = 'adjustment_reason'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'adjustment_reason', t.code, 'CUTOVER', 'migration', 'from ref_adjustment_reason'
FROM ref_adjustment_reason t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'adjustment_reason' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- dispute_reason (DSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('dispute_reason', 'Dispute reason', 'Cut over from ref_dispute_reason', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'dispute_reason', code FROM ref_dispute_reason;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_dispute_reason t ON t.code = v.code
WHERE v.type_code = 'dispute_reason'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'dispute_reason', t.code, 'CUTOVER', 'migration', 'from ref_dispute_reason'
FROM ref_dispute_reason t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'dispute_reason' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- complaint_category (CMC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('complaint_category', 'Complaint category', 'Cut over from ref_complaint_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'complaint_category', code FROM ref_complaint_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_complaint_category t ON t.code = v.code
WHERE v.type_code = 'complaint_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'complaint_category', t.code, 'CUTOVER', 'migration', 'from ref_complaint_category'
FROM ref_complaint_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'complaint_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- service_level (SVL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('service_level', 'Service level', 'Cut over from ref_service_level', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'service_level', code FROM ref_service_level;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_service_level t ON t.code = v.code
WHERE v.type_code = 'service_level'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'service_level', t.code, 'CUTOVER', 'migration', 'from ref_service_level'
FROM ref_service_level t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'service_level' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- escalation_level (ESL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('escalation_level', 'Escalation level', 'Cut over from ref_escalation_level', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'escalation_level', code FROM ref_escalation_level;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_escalation_level t ON t.code = v.code
WHERE v.type_code = 'escalation_level'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'escalation_level', t.code, 'CUTOVER', 'migration', 'from ref_escalation_level'
FROM ref_escalation_level t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'escalation_level' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- case_priority (CSP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('case_priority', 'Case priority', 'Cut over from ref_case_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'case_priority', code FROM ref_case_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_case_priority t ON t.code = v.code
WHERE v.type_code = 'case_priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'case_priority', t.code, 'CUTOVER', 'migration', 'from ref_case_priority'
FROM ref_case_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'case_priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- case_status (CST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('case_status', 'Case status', 'Cut over from ref_case_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'case_status', code FROM ref_case_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_case_status t ON t.code = v.code
WHERE v.type_code = 'case_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'case_status', t.code, 'CUTOVER', 'migration', 'from ref_case_status'
FROM ref_case_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'case_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- workflow_action (WFA)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('workflow_action', 'Workflow action', 'Cut over from ref_workflow_action', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'workflow_action', code FROM ref_workflow_action;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_workflow_action t ON t.code = v.code
WHERE v.type_code = 'workflow_action'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'workflow_action', t.code, 'CUTOVER', 'migration', 'from ref_workflow_action'
FROM ref_workflow_action t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'workflow_action' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- workflow_role (WFR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('workflow_role', 'Workflow role', 'Cut over from ref_workflow_role', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'workflow_role', code FROM ref_workflow_role;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_workflow_role t ON t.code = v.code
WHERE v.type_code = 'workflow_role'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'workflow_role', t.code, 'CUTOVER', 'migration', 'from ref_workflow_role'
FROM ref_workflow_role t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'workflow_role' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_type (CUT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_type', 'Customer type', 'Cut over from ref_customer_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_type', code FROM ref_customer_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_type t ON t.code = v.code
WHERE v.type_code = 'customer_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_type', t.code, 'CUTOVER', 'migration', 'from ref_customer_type'
FROM ref_customer_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_group (CUG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_group', 'Customer group', 'Cut over from ref_customer_group', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_group', code FROM ref_customer_group;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_group t ON t.code = v.code
WHERE v.type_code = 'customer_group'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_group', t.code, 'CUTOVER', 'migration', 'from ref_customer_group'
FROM ref_customer_group t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_group' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_status (CUS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_status', 'Customer status', 'Cut over from ref_customer_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_status', code FROM ref_customer_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_status t ON t.code = v.code
WHERE v.type_code = 'customer_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_status', t.code, 'CUTOVER', 'migration', 'from ref_customer_status'
FROM ref_customer_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_category (CUC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_category', 'Customer category', 'Cut over from ref_customer_category', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_category', code FROM ref_customer_category;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_category t ON t.code = v.code
WHERE v.type_code = 'customer_category'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_category', t.code, 'CUTOVER', 'migration', 'from ref_customer_category'
FROM ref_customer_category t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_category' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_industry (CUI)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_industry', 'Customer industry', 'Cut over from ref_customer_industry', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_industry', code FROM ref_customer_industry;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_industry t ON t.code = v.code
WHERE v.type_code = 'customer_industry'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_industry', t.code, 'CUTOVER', 'migration', 'from ref_customer_industry'
FROM ref_customer_industry t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_industry' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_occupation (CUO)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_occupation', 'Customer occupation', 'Cut over from ref_customer_occupation', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_occupation', code FROM ref_customer_occupation;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_occupation t ON t.code = v.code
WHERE v.type_code = 'customer_occupation'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_occupation', t.code, 'CUTOVER', 'migration', 'from ref_customer_occupation'
FROM ref_customer_occupation t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_occupation' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_source (CUQ)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_source', 'Customer source', 'Cut over from ref_customer_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_source', code FROM ref_customer_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_source t ON t.code = v.code
WHERE v.type_code = 'customer_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_source', t.code, 'CUTOVER', 'migration', 'from ref_customer_source'
FROM ref_customer_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- customer_channel (CUV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('customer_channel', 'Customer channel', 'Cut over from ref_customer_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'customer_channel', code FROM ref_customer_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_customer_channel t ON t.code = v.code
WHERE v.type_code = 'customer_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'customer_channel', t.code, 'CUTOVER', 'migration', 'from ref_customer_channel'
FROM ref_customer_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'customer_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- identity_type (IDT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('identity_type', 'Identity type', 'Cut over from ref_identity_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'identity_type', code FROM ref_identity_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_identity_type t ON t.code = v.code
WHERE v.type_code = 'identity_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'identity_type', t.code, 'CUTOVER', 'migration', 'from ref_identity_type'
FROM ref_identity_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'identity_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- identity_status (IDS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('identity_status', 'Identity status', 'Cut over from ref_identity_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'identity_status', code FROM ref_identity_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_identity_status t ON t.code = v.code
WHERE v.type_code = 'identity_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'identity_status', t.code, 'CUTOVER', 'migration', 'from ref_identity_status'
FROM ref_identity_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'identity_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- address_format (AFM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('address_format', 'Address format', 'Cut over from ref_address_format', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'address_format', code FROM ref_address_format;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_address_format t ON t.code = v.code
WHERE v.type_code = 'address_format'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'address_format', t.code, 'CUTOVER', 'migration', 'from ref_address_format'
FROM ref_address_format t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'address_format' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- address_status (ADS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('address_status', 'Address status', 'Cut over from ref_address_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'address_status', code FROM ref_address_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_address_status t ON t.code = v.code
WHERE v.type_code = 'address_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'address_status', t.code, 'CUTOVER', 'migration', 'from ref_address_status'
FROM ref_address_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'address_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- contact_type (CNT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('contact_type', 'Contact type', 'Cut over from ref_contact_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'contact_type', code FROM ref_contact_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_contact_type t ON t.code = v.code
WHERE v.type_code = 'contact_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'contact_type', t.code, 'CUTOVER', 'migration', 'from ref_contact_type'
FROM ref_contact_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'contact_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- contact_status (CNS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('contact_status', 'Contact status', 'Cut over from ref_contact_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'contact_status', code FROM ref_contact_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_contact_status t ON t.code = v.code
WHERE v.type_code = 'contact_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'contact_status', t.code, 'CUTOVER', 'migration', 'from ref_contact_status'
FROM ref_contact_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'contact_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- consent_type (CSN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('consent_type', 'Consent type', 'Cut over from ref_consent_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'consent_type', code FROM ref_consent_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_consent_type t ON t.code = v.code
WHERE v.type_code = 'consent_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'consent_type', t.code, 'CUTOVER', 'migration', 'from ref_consent_type'
FROM ref_consent_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'consent_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- consent_status (CSS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('consent_status', 'Consent status', 'Cut over from ref_consent_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'consent_status', code FROM ref_consent_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_consent_status t ON t.code = v.code
WHERE v.type_code = 'consent_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'consent_status', t.code, 'CUTOVER', 'migration', 'from ref_consent_status'
FROM ref_consent_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'consent_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_state (DSS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_state', 'Document state', 'Cut over from ref_document_state', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_state', code FROM ref_document_state;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_state t ON t.code = v.code
WHERE v.type_code = 'document_state'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_state', t.code, 'CUTOVER', 'migration', 'from ref_document_state'
FROM ref_document_state t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_state' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_source (DSO)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_source', 'Document source', 'Cut over from ref_document_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_source', code FROM ref_document_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_source t ON t.code = v.code
WHERE v.type_code = 'document_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_source', t.code, 'CUTOVER', 'migration', 'from ref_document_source'
FROM ref_document_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_owner (DOW)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_owner', 'Document owner', 'Cut over from ref_document_owner', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_owner', code FROM ref_document_owner;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_owner t ON t.code = v.code
WHERE v.type_code = 'document_owner'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_owner', t.code, 'CUTOVER', 'migration', 'from ref_document_owner'
FROM ref_document_owner t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_owner' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- verification_type (VFT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('verification_type', 'Verification type', 'Cut over from ref_verification_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'verification_type', code FROM ref_verification_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_verification_type t ON t.code = v.code
WHERE v.type_code = 'verification_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'verification_type', t.code, 'CUTOVER', 'migration', 'from ref_verification_type'
FROM ref_verification_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'verification_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- verification_status (VFS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('verification_status', 'Verification status', 'Cut over from ref_verification_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'verification_status', code FROM ref_verification_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_verification_status t ON t.code = v.code
WHERE v.type_code = 'verification_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'verification_status', t.code, 'CUTOVER', 'migration', 'from ref_verification_status'
FROM ref_verification_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'verification_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- review_type (RVT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('review_type', 'Review type', 'Cut over from ref_review_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'review_type', code FROM ref_review_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_review_type t ON t.code = v.code
WHERE v.type_code = 'review_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'review_type', t.code, 'CUTOVER', 'migration', 'from ref_review_type'
FROM ref_review_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'review_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- review_outcome (RVO)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('review_outcome', 'Review outcome', 'Cut over from ref_review_outcome', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'review_outcome', code FROM ref_review_outcome;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_review_outcome t ON t.code = v.code
WHERE v.type_code = 'review_outcome'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'review_outcome', t.code, 'CUTOVER', 'migration', 'from ref_review_outcome'
FROM ref_review_outcome t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'review_outcome' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- approval_type (APT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('approval_type', 'Approval type', 'Cut over from ref_approval_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'approval_type', code FROM ref_approval_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_approval_type t ON t.code = v.code
WHERE v.type_code = 'approval_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'approval_type', t.code, 'CUTOVER', 'migration', 'from ref_approval_type'
FROM ref_approval_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'approval_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- approval_outcome (APO)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('approval_outcome', 'Approval outcome', 'Cut over from ref_approval_outcome', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'approval_outcome', code FROM ref_approval_outcome;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_approval_outcome t ON t.code = v.code
WHERE v.type_code = 'approval_outcome'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'approval_outcome', t.code, 'CUTOVER', 'migration', 'from ref_approval_outcome'
FROM ref_approval_outcome t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'approval_outcome' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- request_type (RQT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('request_type', 'Request type', 'Cut over from ref_request_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'request_type', code FROM ref_request_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_request_type t ON t.code = v.code
WHERE v.type_code = 'request_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'request_type', t.code, 'CUTOVER', 'migration', 'from ref_request_type'
FROM ref_request_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'request_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- request_status (RQS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('request_status', 'Request status', 'Cut over from ref_request_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'request_status', code FROM ref_request_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_request_status t ON t.code = v.code
WHERE v.type_code = 'request_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'request_status', t.code, 'CUTOVER', 'migration', 'from ref_request_status'
FROM ref_request_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'request_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- task_status (TKS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('task_status', 'Task status', 'Cut over from ref_task_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'task_status', code FROM ref_task_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_task_status t ON t.code = v.code
WHERE v.type_code = 'task_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'task_status', t.code, 'CUTOVER', 'migration', 'from ref_task_status'
FROM ref_task_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'task_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- task_priority (TKP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('task_priority', 'Task priority', 'Cut over from ref_task_priority', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'task_priority', code FROM ref_task_priority;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_task_priority t ON t.code = v.code
WHERE v.type_code = 'task_priority'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'task_priority', t.code, 'CUTOVER', 'migration', 'from ref_task_priority'
FROM ref_task_priority t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'task_priority' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- queue_status (QUS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('queue_status', 'Queue status', 'Cut over from ref_queue_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'queue_status', code FROM ref_queue_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_queue_status t ON t.code = v.code
WHERE v.type_code = 'queue_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'queue_status', t.code, 'CUTOVER', 'migration', 'from ref_queue_status'
FROM ref_queue_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'queue_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- queue_type (QUT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('queue_type', 'Queue type', 'Cut over from ref_queue_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'queue_type', code FROM ref_queue_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_queue_type t ON t.code = v.code
WHERE v.type_code = 'queue_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'queue_type', t.code, 'CUTOVER', 'migration', 'from ref_queue_type'
FROM ref_queue_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'queue_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_type (NFT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_type', 'Notification type', 'Cut over from ref_notification_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_type', code FROM ref_notification_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_type t ON t.code = v.code
WHERE v.type_code = 'notification_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_type', t.code, 'CUTOVER', 'migration', 'from ref_notification_type'
FROM ref_notification_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_result (NFR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_result', 'Notification result', 'Cut over from ref_notification_result', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_result', code FROM ref_notification_result;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_result t ON t.code = v.code
WHERE v.type_code = 'notification_result'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_result', t.code, 'CUTOVER', 'migration', 'from ref_notification_result'
FROM ref_notification_result t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_result' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- message_status (MSS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('message_status', 'Message status', 'Cut over from ref_message_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'message_status', code FROM ref_message_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_message_status t ON t.code = v.code
WHERE v.type_code = 'message_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'message_status', t.code, 'CUTOVER', 'migration', 'from ref_message_status'
FROM ref_message_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'message_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- message_channel (MSC)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('message_channel', 'Message channel', 'Cut over from ref_message_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'message_channel', code FROM ref_message_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_message_channel t ON t.code = v.code
WHERE v.type_code = 'message_channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'message_channel', t.code, 'CUTOVER', 'migration', 'from ref_message_channel'
FROM ref_message_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'message_channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- event_type (EVT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('event_type', 'Event type', 'Cut over from ref_event_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'event_type', code FROM ref_event_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_event_type t ON t.code = v.code
WHERE v.type_code = 'event_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'event_type', t.code, 'CUTOVER', 'migration', 'from ref_event_type'
FROM ref_event_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'event_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- event_status (EVS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('event_status', 'Event status', 'Cut over from ref_event_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'event_status', code FROM ref_event_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_event_status t ON t.code = v.code
WHERE v.type_code = 'event_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'event_status', t.code, 'CUTOVER', 'migration', 'from ref_event_status'
FROM ref_event_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'event_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- audit_result (AUR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('audit_result', 'Audit result', 'Cut over from ref_audit_result', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'audit_result', code FROM ref_audit_result;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_audit_result t ON t.code = v.code
WHERE v.type_code = 'audit_result'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'audit_result', t.code, 'CUTOVER', 'migration', 'from ref_audit_result'
FROM ref_audit_result t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'audit_result' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- audit_source (AUS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('audit_source', 'Audit source', 'Cut over from ref_audit_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'audit_source', code FROM ref_audit_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_audit_source t ON t.code = v.code
WHERE v.type_code = 'audit_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'audit_source', t.code, 'CUTOVER', 'migration', 'from ref_audit_source'
FROM ref_audit_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'audit_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- audit_severity (AUV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('audit_severity', 'Audit severity', 'Cut over from ref_audit_severity', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'audit_severity', code FROM ref_audit_severity;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_audit_severity t ON t.code = v.code
WHERE v.type_code = 'audit_severity'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'audit_severity', t.code, 'CUTOVER', 'migration', 'from ref_audit_severity'
FROM ref_audit_severity t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'audit_severity' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_layout (RLY)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_layout', 'Report layout', 'Cut over from ref_report_layout', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_layout', code FROM ref_report_layout;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_layout t ON t.code = v.code
WHERE v.type_code = 'report_layout'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_layout', t.code, 'CUTOVER', 'migration', 'from ref_report_layout'
FROM ref_report_layout t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_layout' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_column (RCL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_column', 'Report column', 'Cut over from ref_report_column', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_column', code FROM ref_report_column;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_column t ON t.code = v.code
WHERE v.type_code = 'report_column'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_column', t.code, 'CUTOVER', 'migration', 'from ref_report_column'
FROM ref_report_column t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_column' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_filter (RFL)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_filter', 'Report filter', 'Cut over from ref_report_filter', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_filter', code FROM ref_report_filter;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_filter t ON t.code = v.code
WHERE v.type_code = 'report_filter'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_filter', t.code, 'CUTOVER', 'migration', 'from ref_report_filter'
FROM ref_report_filter t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_filter' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_parameter (RPM)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_parameter', 'Report parameter', 'Cut over from ref_report_parameter', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_parameter', code FROM ref_report_parameter;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_parameter t ON t.code = v.code
WHERE v.type_code = 'report_parameter'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_parameter', t.code, 'CUTOVER', 'migration', 'from ref_report_parameter'
FROM ref_report_parameter t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_parameter' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_schedule (RSD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_schedule', 'Report schedule', 'Cut over from ref_report_schedule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_schedule', code FROM ref_report_schedule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_schedule t ON t.code = v.code
WHERE v.type_code = 'report_schedule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_schedule', t.code, 'CUTOVER', 'migration', 'from ref_report_schedule'
FROM ref_report_schedule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_schedule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- report_delivery (RDV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('report_delivery', 'Report delivery', 'Cut over from ref_report_delivery', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'report_delivery', code FROM ref_report_delivery;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_report_delivery t ON t.code = v.code
WHERE v.type_code = 'report_delivery'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'report_delivery', t.code, 'CUTOVER', 'migration', 'from ref_report_delivery'
FROM ref_report_delivery t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'report_delivery' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- export_schedule (ESD)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('export_schedule', 'Export schedule', 'Cut over from ref_export_schedule', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'export_schedule', code FROM ref_export_schedule;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_export_schedule t ON t.code = v.code
WHERE v.type_code = 'export_schedule'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'export_schedule', t.code, 'CUTOVER', 'migration', 'from ref_export_schedule'
FROM ref_export_schedule t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'export_schedule' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- export_delivery (EDV)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('export_delivery', 'Export delivery', 'Cut over from ref_export_delivery', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'export_delivery', code FROM ref_export_delivery;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_export_delivery t ON t.code = v.code
WHERE v.type_code = 'export_delivery'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'export_delivery', t.code, 'CUTOVER', 'migration', 'from ref_export_delivery'
FROM ref_export_delivery t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'export_delivery' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- file_source (FSR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('file_source', 'File source', 'Cut over from ref_file_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'file_source', code FROM ref_file_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_file_source t ON t.code = v.code
WHERE v.type_code = 'file_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'file_source', t.code, 'CUTOVER', 'migration', 'from ref_file_source'
FROM ref_file_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'file_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- file_status (FST)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('file_status', 'File status', 'Cut over from ref_file_status', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'file_status', code FROM ref_file_status;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_file_status t ON t.code = v.code
WHERE v.type_code = 'file_status'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'file_status', t.code, 'CUTOVER', 'migration', 'from ref_file_status'
FROM ref_file_status t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'file_status' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- file_direction (FDR)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('file_direction', 'File direction', 'Cut over from ref_file_direction', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'file_direction', code FROM ref_file_direction;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_file_direction t ON t.code = v.code
WHERE v.type_code = 'file_direction'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'file_direction', t.code, 'CUTOVER', 'migration', 'from ref_file_direction'
FROM ref_file_direction t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'file_direction' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

