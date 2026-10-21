-- Phase 1 cutover: fee_code, limit_type, and product_type reference domains.
-- The generic engine becomes the read/write source for these domains. The
-- legacy generated tables remain as a read-only safety copy for one release.
-- Idempotent: INSERT IGNORE and NOT EXISTS guards.

INSERT IGNORE INTO ref_fee_code (code, label, num_val, is_active) VALUES
('TRANSF', 'Transfer fee', 2500, TRUE),
('HOLDFE', 'Hold fee', 0, TRUE);

INSERT IGNORE INTO ref_limit_type (code, label, num_val, is_active) VALUES
('DAILYL', 'Daily limit', 0, TRUE),
('TXNLIM', 'Per-transaction limit', 0, TRUE);

INSERT IGNORE INTO ref_product_type (code, label, num_val, is_active) VALUES
('EWALLT', 'E-wallet', 0, TRUE),
('TRFPRD', 'Transfer', 0, TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'fee_code', code FROM ref_fee_code;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, f.label,
       CONCAT('num_val=', f.num_val, ';active=', f.is_active),
       IF(f.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_fee_code f ON f.code = v.code
WHERE v.type_code = 'fee_code'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'limit_type', code FROM ref_limit_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, l.label,
       CONCAT('num_val=', l.num_val, ';active=', l.is_active),
       IF(l.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_limit_type l ON l.code = v.code
WHERE v.type_code = 'limit_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'product_type', code FROM ref_product_type;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, p.label,
       CONCAT('num_val=', p.num_val, ';active=', p.is_active),
       IF(p.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_product_type p ON p.code = v.code
WHERE v.type_code = 'product_type'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'fee_code', f.code, 'CUTOVER', 'migration', 'from ref_fee_code'
FROM ref_fee_code f
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'fee_code' AND a.value_code = f.code AND a.action = 'CUTOVER'
);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'limit_type', l.code, 'CUTOVER', 'migration', 'from ref_limit_type'
FROM ref_limit_type l
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'limit_type' AND a.value_code = l.code AND a.action = 'CUTOVER'
);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'product_type', p.code, 'CUTOVER', 'migration', 'from ref_product_type'
FROM ref_product_type p
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'product_type' AND a.value_code = p.code AND a.action = 'CUTOVER'
);
