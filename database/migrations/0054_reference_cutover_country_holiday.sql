-- Phase 1 cutover: country and holiday reference domains.
-- The generic reference engine becomes the read/write source for these two
-- domains. The legacy generated tables remain as a read-only safety copy for
-- one release; a later cleanup migration may drop them.
--
-- The migration is idempotent: seeds use INSERT IGNORE, copies use NOT EXISTS,
-- and audit rows use NOT EXISTS.

INSERT IGNORE INTO ref_country (code, label, num_val, is_active) VALUES
('ID', 'Indonesia', 0, TRUE),
('US', 'United States', 0, TRUE);

INSERT IGNORE INTO ref_holiday (code, label, num_val, is_active) VALUES
('NEWYEAR', 'New Year', 0, TRUE);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'country', code FROM ref_country;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, c.label,
       CONCAT('num_val=', c.num_val, ';active=', c.is_active),
       IF(c.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_country c ON c.code = v.code
WHERE v.type_code = 'country'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_value (type_code, code)
SELECT 'holiday', code FROM ref_holiday;

INSERT IGNORE INTO ref_value_version
    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)
SELECT v.id, 1, h.label,
       CONCAT('num_val=', h.num_val, ';active=', h.is_active),
       IF(h.is_active, 'ACTIVE', 'RETIRED'),
       CURDATE(), 'migration', NOW()
FROM ref_value v
JOIN ref_holiday h ON h.code = v.code
WHERE v.type_code = 'holiday'
  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'country', c.code, 'CUTOVER', 'migration', 'from ref_country'
FROM ref_country c
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'country' AND a.value_code = c.code AND a.action = 'CUTOVER'
);

INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)
SELECT 'holiday', h.code, 'CUTOVER', 'migration', 'from ref_holiday'
FROM ref_holiday h
WHERE NOT EXISTS (
    SELECT 1 FROM ref_engine_audit a
    WHERE a.type_code = 'holiday' AND a.value_code = h.code AND a.action = 'CUTOVER'
);
