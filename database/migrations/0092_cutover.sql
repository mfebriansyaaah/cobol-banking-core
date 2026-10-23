-- Gradual cutover batch: CHN, BRN, CCT, DTP, NTP, STS, RTS, ACT, TXN, CHG.
-- Migrates legacy generated reference rows into the generic ref_engine.
-- Legacy tables remain as a read-only safety copy.

-- channel (CHN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('channel', 'Channel', 'Cut over from ref_channel', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'channel', code FROM ref_channel;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_channel t ON t.code = v.code
WHERE v.type_code = 'channel'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'channel', t.code, 'CUTOVER', 'migration', 'from ref_channel'
FROM ref_channel t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'channel' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- branch (BRN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('branch', 'Branch', 'Cut over from ref_branch', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'branch', code FROM ref_branch;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_branch t ON t.code = v.code
WHERE v.type_code = 'branch'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'branch', t.code, 'CUTOVER', 'migration', 'from ref_branch'
FROM ref_branch t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'branch' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- cost_center (CCT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('cost_center', 'Cost center', 'Cut over from ref_cost_center', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'cost_center', code FROM ref_cost_center;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_cost_center t ON t.code = v.code
WHERE v.type_code = 'cost_center'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'cost_center', t.code, 'CUTOVER', 'migration', 'from ref_cost_center'
FROM ref_cost_center t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'cost_center' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- document_type (DTP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('document_type', 'Document type', 'Cut over from ref_document_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'document_type', code FROM ref_document_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_document_type t ON t.code = v.code
WHERE v.type_code = 'document_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'document_type', t.code, 'CUTOVER', 'migration', 'from ref_document_type'
FROM ref_document_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'document_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- notification_template (NTP)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('notification_template', 'Notification template', 'Cut over from ref_notification_template', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'notification_template', code FROM ref_notification_template;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_notification_template t ON t.code = v.code
WHERE v.type_code = 'notification_template'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'notification_template', t.code, 'CUTOVER', 'migration', 'from ref_notification_template'
FROM ref_notification_template t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'notification_template' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- status_code (STS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('status_code', 'Status code', 'Cut over from ref_status_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'status_code', code FROM ref_status_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_status_code t ON t.code = v.code
WHERE v.type_code = 'status_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'status_code', t.code, 'CUTOVER', 'migration', 'from ref_status_code'
FROM ref_status_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'status_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- rate_source (RTS)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('rate_source', 'Rate source', 'Cut over from ref_rate_source', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'rate_source', code FROM ref_rate_source;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_rate_source t ON t.code = v.code
WHERE v.type_code = 'rate_source'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'rate_source', t.code, 'CUTOVER', 'migration', 'from ref_rate_source'
FROM ref_rate_source t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'rate_source' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- account_type (ACT)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('account_type', 'Account type', 'Cut over from ref_account_type', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'account_type', code FROM ref_account_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_account_type t ON t.code = v.code
WHERE v.type_code = 'account_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'account_type', t.code, 'CUTOVER', 'migration', 'from ref_account_type'
FROM ref_account_type t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'account_type' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- transaction_code (TXN)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('transaction_code', 'Transaction code', 'Cut over from ref_transaction_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'transaction_code', code FROM ref_transaction_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_transaction_code t ON t.code = v.code
WHERE v.type_code = 'transaction_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'transaction_code', t.code, 'CUTOVER', 'migration', 'from ref_transaction_code'
FROM ref_transaction_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'transaction_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

-- charge_code (CHG)
INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES
('charge_code', 'Charge code', 'Cut over from ref_charge_code', TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'charge_code', code FROM ref_charge_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, t.label,
       CONCAT('num_val=', t.num_val, ';active=', t.is_active),
       IF(t.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_charge_code t ON t.code = v.code
WHERE v.type_code = 'charge_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'charge_code', t.code, 'CUTOVER', 'migration', 'from ref_charge_code'
FROM ref_charge_code t
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'charge_code' AND a.value_code = t.code AND a.action = 'CUTOVER'
);

