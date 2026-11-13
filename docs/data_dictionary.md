# Data Dictionary — cobol_db

Generated from `database/schema.sql` (baseline). 478 tables.


## Domain group: `access_*`


### `access_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| event_type | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| subject_email | VARCHAR(100) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `access_audit_entry`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| audit_id | BIGINT NOT |
| event | VARCHAR(40) NOT |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `access_review_items`

| Column | Type |
|---|---|
| item_id | BIGINT AUTO_INCREMENT |
| review_id | BIGINT NOT |
| email | VARCHAR(100) NOT |
| role | VARCHAR(12) NOT |
| account_status | VARCHAR(20) NOT |
| mfa_enabled | BOOLEAN NOT |
| last_login_at | TIMESTAMP NULL |
| decision | ENUM('PENDING','ATTESTED','REVOKED') NOT |
| reviewer_email | VARCHAR(100) NULL |
| note | VARCHAR(255) NULL |
| decided_at | TIMESTAMP NULL |
| REFERENCES | access_reviews(review_id) ON |

### `access_reviews`

| Column | Type |
|---|---|
| review_id | BIGINT AUTO_INCREMENT |
| period_start | DATE NOT |
| period_end | DATE NOT |
| state | ENUM('OPEN','CLOSED') NOT |
| opened_by | VARCHAR(100) NOT |
| closed_by | VARCHAR(100) NULL |
| created_at | TIMESTAMP DEFAULT |
| closed_at | TIMESTAMP NULL |

## Domain group: `account_*`


### `account_holds`

| Column | Type |
|---|---|
| hold_id | BIGINT AUTO_INCREMENT |
| account_id | INT NOT |
| amount | DECIMAL(18, 4) |
| state | ENUM('PLACED','RELEASED','EXPIRED') NOT |
| reason | VARCHAR(100) NULL |
| actor_email | VARCHAR(100) NOT |
| expires_at | TIMESTAMP NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | accounts(account_id) ON |

## Domain group: `accounts_*`


### `accounts`

| Column | Type |
|---|---|
| account_id | INT AUTO_INCREMENT |
| user_id | INT NOT |
| currency_id | INT NOT |
| account_type | ENUM('SAVINGS' |
| balance | DECIMAL(18, 4) |
| status | ENUM('ACTIVE' |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |
| control_slot | VARCHAR(32) GENERATED |
| (CASE | WHEN status |
| THEN | CONCAT(currency_id |

## Domain group: `alert_*`


### `alert_escalation_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `alert_escalation_policy`

| Column | Type |
|---|---|
| policy_code | VARCHAR(40) PRIMARY |
| alert_type | VARCHAR(32) NOT |
| severity_min | ENUM('INFO','WARNING','CRITICAL') NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `alert_escalation_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| alert_id | BIGINT NOT |
| policy_code | VARCHAR(40) NOT |
| step_no | INT NOT |
| target_email | VARCHAR(100) NOT |
| status | ENUM('PENDING','PAGED','ACKED','RESOLVED','FAILED') NOT |
| detail | VARCHAR(255) NULL |
| paged_at | TIMESTAMP DEFAULT |
| acked_at | DATETIME NULL |
| resolved_at | DATETIME NULL |
| created_by | VARCHAR(100) NOT |

### `alert_escalation_step`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| policy_code | VARCHAR(40) NOT |
| step_no | INT NOT |
| delay_minutes | INT NOT |
| target_email | VARCHAR(100) NOT |
| channel | ENUM('EMAIL','PAGE') NOT |
| enabled | BOOLEAN NOT |
| REFERENCES | alert_escalation_policy(policy_code) ON |

## Domain group: `asset_*`


### `asset_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| asset_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `asset_maintenance`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| asset_code | VARCHAR(40) NOT |
| maintenance_type | VARCHAR(40) NOT |
| cost | DECIMAL(18,4) NOT |
| performed_by | VARCHAR(100) NOT |
| performed_at | TIMESTAMP DEFAULT |

### `asset_maintenance_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| asset_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `asset_register`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| asset_code | VARCHAR(40) NOT |
| name | VARCHAR(120) NOT |
| status | ENUM('ACTIVE','RETIRED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `audit_*`


### `audit_analytics_snapshot`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| snapshot_date | DATE NOT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| event_count | BIGINT NOT |
| failure_count | BIGINT NOT |
| created_at | TIMESTAMP DEFAULT |

### `audit_drilldown_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| query_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `audit_drilldown_query`

| Column | Type |
|---|---|
| query_code | VARCHAR(40) PRIMARY |
| name | VARCHAR(120) NOT |
| filter_spec | VARCHAR(255) NOT |
| saved_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `audit_drilldown_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| query_code | VARCHAR(40) NOT |
| row_count | BIGINT NOT |
| digest | CHAR(64) NULL |
| executed_by | VARCHAR(100) NOT |
| executed_at | TIMESTAMP DEFAULT |

### `audit_retention_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `audit_retention_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `audit_retention_policy`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| policy_name | VARCHAR(64) NOT |
| retention_days | INT NOT |
| status | ENUM('ACTIVE','RETIRED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `audit_retention_policy`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| policy_name | VARCHAR(64) NOT |
| retention_days | INT NOT |
| status | ENUM('ACTIVE','RETIRED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `audit_retention_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| policy_id | BIGINT NOT |
| archived_count | BIGINT NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| run_by | VARCHAR(100) NOT |
| run_at | TIMESTAMP DEFAULT |

### `audit_retention_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| policy_id | BIGINT NOT |
| archived_count | BIGINT NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| run_by | VARCHAR(100) NOT |
| run_at | TIMESTAMP DEFAULT |

### `audit_snapshot`

| Column | Type |
|---|---|
| snapshot_code | VARCHAR(40) PRIMARY |
| period_start | DATE NOT |
| period_end | DATE NOT |
| total_events | BIGINT NOT |
| success_count | BIGINT NOT |
| failed_count | BIGINT NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `audit_snapshot_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| snapshot_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `audit_trail`

| Column | Type |
|---|---|
| audit_id | BIGINT AUTO_INCREMENT |
| user_id | INT NOT |
| actor_id | INT |
| action | VARCHAR(100) NOT |
| entity_type | VARCHAR(50), -- |
| entity_id | VARCHAR(50), -- |
| detail | VARCHAR(255), -- |
| journal_id | BIGINT |
| status | ENUM('SUCCESS', 'FAILED') |
| created_at | TIMESTAMP DEFAULT |

### `audit_trail_archive`

| Column | Type |
|---|---|
| audit_id | BIGINT PRIMARY |
| user_id | INT NOT |
| actor_id | INT NULL |
| action | VARCHAR(100) NOT |
| entity_type | VARCHAR(50) |
| entity_id | VARCHAR(50) |
| detail | VARCHAR(255) |
| status | ENUM('SUCCESS', 'FAILED') |
| journal_id | BIGINT NULL |
| created_at | TIMESTAMP |
| archived_at | TIMESTAMP DEFAULT |

## Domain group: `backup_*`


### `backup_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| backup_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `backup_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| backup_type | VARCHAR(40) NOT |
| target | VARCHAR(100) NOT |
| status | ENUM('RUNNING','VERIFIED','RESTORED','FAILED') NOT |
| started_by | VARCHAR(100) NOT |
| started_at | TIMESTAMP DEFAULT |
| verified_by | VARCHAR(100) NULL |
| verified_at | DATETIME NULL |
| restored_by | VARCHAR(100) NULL |
| restored_at | DATETIME NULL |

### `backup_verification`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| backup_id | BIGINT NOT |
| status | ENUM('PENDING','VERIFIED','FAILED') NOT |
| verified_by | VARCHAR(100) NOT |
| verified_at | TIMESTAMP DEFAULT |

### `backup_verification_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `batch_*`


### `batch_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | INT NULL |
| job_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `batch_control_total`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| run_id | INT NOT |
| total_code | VARCHAR(40) NOT |
| expected_amount | DECIMAL(30,10) NOT |
| actual_amount | DECIMAL(30,10) NOT |
| variance | DECIMAL(30,10) NOT |
| status | ENUM('MATCH','VARIANCE') NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |
| REFERENCES | batch_run(id) ON |

### `batch_job`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| job_code | VARCHAR(40) NOT |
| name | VARCHAR(100) NOT |
| job_type | ENUM('EOD','INTRADAY','REPORT','CLEANUP') NOT |
| frequency | ENUM('MANUAL','DAILY','WEEKLY','MONTHLY') NOT |
| schedule_time | TIME NULL |
| enabled | BOOLEAN NOT |
| max_retries | INT NOT |
| timeout_seconds | INT NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `batch_job_step`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| job_id | INT NOT |
| step_no | INT NOT |
| step_code | VARCHAR(40) NOT |
| step_name | VARCHAR(100) NOT |
| max_retries | INT NOT |
| is_required | BOOLEAN NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | batch_job(id) ON |

### `batch_run`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| job_id | INT NOT |
| business_date | DATE NOT |
| status | ENUM('RUNNING','PAUSED','COMPLETED','FAILED','CANCELLED') NOT |
| attempt | INT NOT |
| processed_count | BIGINT NOT |
| success_count | BIGINT NOT |
| failed_count | BIGINT NOT |
| control_debit | DECIMAL(30,10) NOT |
| control_credit | DECIMAL(30,10) NOT |
| locked_by | VARCHAR(100) NOT |
| started_at | DATETIME NOT |
| finished_at | DATETIME NULL |
| error_code | VARCHAR(40) NULL |
| error_detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |
| version | INT NOT |
| REFERENCES | batch_job(id) |

### `batch_run_step`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| run_id | INT NOT |
| step_no | INT NOT |
| step_code | VARCHAR(40) NOT |
| status | ENUM('PENDING','RUNNING','COMPLETED','FAILED','SKIPPED') NOT |
| attempt | INT NOT |
| processed_count | BIGINT NOT |
| success_count | BIGINT NOT |
| failed_count | BIGINT NOT |
| control_debit | DECIMAL(30,10) NOT |
| control_credit | DECIMAL(30,10) NOT |
| started_at | DATETIME NULL |
| finished_at | DATETIME NULL |
| error_code | VARCHAR(40) NULL |
| error_detail | VARCHAR(255) NULL |
| updated_at | TIMESTAMP DEFAULT |
| REFERENCES | batch_run(id) ON |

## Domain group: `budget_*`


### `budget_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| budget_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `budget_line`

| Column | Type |
|---|---|
| budget_code | VARCHAR(40) PRIMARY |
| cost_center | VARCHAR(40) NOT |
| amount | DECIMAL(18,4) NOT |
| spent | DECIMAL(18,4) NOT |
| period | VARCHAR(20) NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `capacity_*`


### `capacity_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| plan_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `capacity_breach`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| plan_id | BIGINT NOT |
| observed | VARCHAR(40) NOT |
| breached_at | DATETIME NOT |
| recorded_by | VARCHAR(100) NOT |

### `capacity_plan`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| plan_name | VARCHAR(100) NOT |
| threshold | VARCHAR(40) NOT |
| unit | VARCHAR(20) NOT |
| status | ENUM('ACTIVE','RETIRED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `card_*`


### `card_account`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| card_ref | VARCHAR(64) NOT |
| customer_email | VARCHAR(100) NOT |
| card_type | ENUM('DEBIT','CREDIT','PREPAID') NOT |
| status | ENUM('ACTIVE','BLOCKED','CLOSED') NOT |
| limit_amount | DECIMAL(18,4) NOT |
| currency | CHAR(3) NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `card_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| card_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `change_*`


### `change_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| change_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `change_request`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| title | VARCHAR(100) NOT |
| change_type | VARCHAR(40) NOT |
| risk | ENUM('LOW','MEDIUM','HIGH') NOT |
| status | ENUM('REQUESTED','APPROVED','REJECTED','DEPLOYED','ROLLEDBACK') NOT |
| requested_by | VARCHAR(100) NOT |
| approved_by | VARCHAR(100) NULL |
| rejected_by | VARCHAR(100) NULL |
| deployed_at | DATETIME NULL |
| rolled_back_at | DATETIME NULL |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `compliance_*`


### `compliance_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| finding_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `compliance_export_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| package_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `compliance_export_item`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| package_code | VARCHAR(40) NOT |
| item_type | ENUM('AUDIT_QUERY','EXPORT_ARCHIVE','REPORT_RUN') NOT |
| ref_id | VARCHAR(64) NOT |
| included | BOOLEAN NOT |
| detail | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | compliance_export_package(package_code) ON |

### `compliance_export_package`

| Column | Type |
|---|---|
| package_code | VARCHAR(40) PRIMARY |
| framework | ENUM('SOX','GDPR','PCI','AML') NOT |
| title | VARCHAR(120) NOT |
| period_start | DATE NOT |
| period_end | DATE NOT |
| status | ENUM('DRAFT','SEALED','ATTESTED','REVOKED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| sealed_at | DATETIME NULL |
| attested_by | VARCHAR(100) NULL |
| attested_at | DATETIME NULL |
| revoke_reason | VARCHAR(255) NULL |

### `compliance_finding`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| title | VARCHAR(100) NOT |
| severity | ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT |
| status | ENUM('OPEN','CLOSED') NOT |
| raised_by | VARCHAR(100) NOT |
| raised_at | TIMESTAMP DEFAULT |
| closed_at | DATETIME NULL |

### `compliance_retention_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| policy_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `compliance_retention_policy`

| Column | Type |
|---|---|
| policy_code | VARCHAR(40) PRIMARY |
| entity_type | VARCHAR(50) NOT |
| retention_days | INT NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `compliance_retention_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| policy_code | VARCHAR(40) NOT |
| archived_count | BIGINT NOT |
| purged_count | BIGINT NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| executed_by | VARCHAR(100) NOT |
| executed_at | TIMESTAMP DEFAULT |
| REFERENCES | compliance_retention_policy(policy_code) ON |

## Domain group: `currencies_*`


### `currencies`

| Column | Type |
|---|---|
| currency_id | INT AUTO_INCREMENT |
| iso_code | CHAR(3) NOT |
| symbol | VARCHAR(5) NOT |
| prec_val | INT DEFAULT |
| is_active | BOOLEAN DEFAULT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `data_*`


### `data_quality_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| rule_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `data_quality_rule`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| rule_name | VARCHAR(64) NOT |
| severity | ENUM('LOW','MEDIUM','HIGH') NOT |
| status | ENUM('ACTIVE','RETIRED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `data_quality_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| rule_id | BIGINT NOT |
| findings | BIGINT NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| run_by | VARCHAR(100) NOT |
| run_at | TIMESTAMP DEFAULT |

### `data_retention_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| policy_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `data_retention_policy`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| policy_name | VARCHAR(64) NOT |
| retention_days | INT NOT |
| status | ENUM('ACTIVE','RETIRED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `data_retention_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| policy_id | BIGINT NOT |
| purged_count | BIGINT NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| run_by | VARCHAR(100) NOT |
| run_at | TIMESTAMP DEFAULT |

## Domain group: `deposit_*`


### `deposit_account`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| principal | DECIMAL(18,4) NOT |
| currency | CHAR(3) NOT |
| term_months | INT NOT |
| interest_rate | DECIMAL(9,4) NOT |
| status | ENUM('PENDING','ACTIVE','MATURED','CLOSED') NOT |
| maturity_date | DATE NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `deposit_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| deposit_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `dispute_*`


### `dispute_assignment`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| case_id | BIGINT NOT |
| from_user_id | INT NULL |
| to_user_id | INT NULL |
| assigned_by | VARCHAR(100) NOT |
| note | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | dispute_cases(case_id) ON |
| REFERENCES | users(id) ON |
| REFERENCES | users(id) ON |

### `dispute_cases`

| Column | Type |
|---|---|
| case_id | BIGINT AUTO_INCREMENT |
| user_id | INT NOT |
| txn_ref | VARCHAR(50) NULL |
| subject | VARCHAR(100) NOT |
| detail | VARCHAR(100) NOT |
| state | ENUM('OPEN','ACKNOWLEDGED','RESOLVED','REJECTED') NOT |
| assigned_to | INT NULL |
| due_date | DATE NULL |
| resolution | VARCHAR(100) NULL |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |
| decided_at | TIMESTAMP NULL |
| REFERENCES | users(id) ON |
| REFERENCES | users(id) ON |

### `dispute_messages`

| Column | Type |
|---|---|
| msg_id | BIGINT AUTO_INCREMENT |
| case_id | BIGINT NOT |
| author_id | INT NOT |
| body | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | dispute_cases(case_id) ON |
| REFERENCES | users(id) ON |

### `dispute_notification`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| case_id | BIGINT NOT |
| recipient | VARCHAR(100) NOT |
| purpose | VARCHAR(32) NOT |
| template_code | VARCHAR(40) NULL |
| channel | ENUM('EMAIL','INAPP') NOT |
| state | ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT |
| attempts | INT NOT |
| last_error | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| sent_at | DATETIME NULL |
| REFERENCES | dispute_cases(case_id) ON |
| REFERENCES | dispute_notification_template(template_code) ON |

### `dispute_notification_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| case_id | BIGINT NULL |
| notification_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `dispute_notification_template`

| Column | Type |
|---|---|
| template_code | VARCHAR(40) PRIMARY |
| purpose | VARCHAR(32) NOT |
| channel | ENUM('EMAIL','INAPP') NOT |
| subject | VARCHAR(160) NOT |
| body | VARCHAR(1000) NOT |
| enabled | BOOLEAN NOT |
| updated_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `dispute_ops_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| case_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `dispute_sla_policy`

| Column | Type |
|---|---|
| priority | ENUM('LOW','NORMAL','HIGH','URGENT') PRIMARY |
| response_hours | INT NOT |
| resolution_hours | INT NOT |
| enabled | BOOLEAN NOT |
| updated_by | VARCHAR(100) NOT |
| updated_at | TIMESTAMP DEFAULT |

## Domain group: `dr_*`


### `dr_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| plan_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `dr_plan`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| plan_name | VARCHAR(100) NOT |
| rto_minutes | INT NOT |
| rpo_minutes | INT NOT |
| status | ENUM('ACTIVE','VERIFIED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| verified_at | DATETIME NULL |

### `dr_test`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| plan_id | BIGINT NOT |
| outcome | VARCHAR(40) NOT |
| tested_by | VARCHAR(100) NOT |
| tested_at | DATETIME NOT |

## Domain group: `dsar_*`


### `dsar_request`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| subject_email | VARCHAR(100) NOT |
| request_type | ENUM('EXPORT','ERASE') NOT |
| status | ENUM('RECEIVED','IN_PROGRESS','FULFILLED','REJECTED') NOT |
| scope | VARCHAR(64) NOT |
| detail | VARCHAR(255) NULL |
| received_by | VARCHAR(100) NOT |
| received_at | TIMESTAMP DEFAULT |
| decided_by | VARCHAR(100) NULL |
| decided_at | DATETIME NULL |

### `dsar_request_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| request_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `dual_*`


### `dual_control_operations`

| Column | Type |
|---|---|
| operation | VARCHAR(50) PRIMARY |

## Domain group: `eod_*`


### `eod_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| business_date | DATE NULL |
| run_id | INT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `eod_calendar`

| Column | Type |
|---|---|
| business_date | DATE PRIMARY |
| status | ENUM('OPEN','CLOSED') NOT |
| cutoff_time | TIME NOT |
| opened_by | VARCHAR(100) NOT |
| opened_at | TIMESTAMP DEFAULT |
| closed_by | VARCHAR(100) NULL |
| closed_at | DATETIME NULL |
| version | INT NOT |

### `eod_job_run`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| business_date | DATE NOT |
| job_code | ENUM('HOLD_EXPIRY','DORMANT_MARK','DORMANT_SUSPEND','RECON','STATEMENT','PENDING_PURGE') NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| processed_count | BIGINT NOT |
| detail | VARCHAR(255) NULL |
| error_code | VARCHAR(40) NULL |
| actor_email | VARCHAR(100) NOT |
| started_at | DATETIME NOT |
| finished_at | DATETIME NULL |

### `eod_phase`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| run_id | INT NOT |
| phase_no | INT NOT |
| phase_code | ENUM('FEE','HOLD','DORMANT','STATEMENT','RECON') NOT |
| status | ENUM('PENDING','RUNNING','COMPLETED','FAILED','SKIPPED') NOT |
| processed_count | BIGINT NOT |
| control_debit | DECIMAL(30,10) NOT |
| control_credit | DECIMAL(30,10) NOT |
| error_code | VARCHAR(40) NULL |
| error_detail | VARCHAR(255) NULL |
| started_at | DATETIME NULL |
| finished_at | DATETIME NULL |
| updated_at | TIMESTAMP DEFAULT |
| REFERENCES | eod_run(id) ON |

### `eod_run`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| business_date | DATE NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| phase_count | INT NOT |
| completed_phases | INT NOT |
| control_debit | DECIMAL(30,10) NOT |
| control_credit | DECIMAL(30,10) NOT |
| error_code | VARCHAR(40) NULL |
| error_detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| started_at | DATETIME NOT |
| finished_at | DATETIME NULL |
| version | INT NOT |

## Domain group: `escalation_*`


### `escalation_policy`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| policy_code | VARCHAR(40) NOT |
| alert_type | VARCHAR(32) NOT |
| severity_min | ENUM('INFO','WARNING','CRITICAL') NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `escalation_step`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| policy_id | INT NOT |
| step_no | INT NOT |
| delay_minutes | INT NOT |
| target_email | VARCHAR(100) NOT |
| channel | ENUM('EMAIL','PAGE') NOT |
| enabled | BOOLEAN NOT |
| REFERENCES | escalation_policy(id) ON |

## Domain group: `exchange_*`


### `exchange_rates`

| Column | Type |
|---|---|
| rate_id | INT AUTO_INCREMENT |
| base_currency_id | INT NOT |
| target_currency_id | INT NOT |
| exchange_rate | DECIMAL(18, 6) |
| updated_at | TIMESTAMP DEFAULT |

## Domain group: `export_*`


### `export_archive`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| export_type | ENUM('REPORT','IMPORT') NOT |
| source_code | VARCHAR(64) NOT |
| format | ENUM('CSV','JSON','FIXED') NOT |
| content | LONGTEXT NOT |
| row_count | BIGINT NOT |
| byte_count | BIGINT NOT |
| retention_days | INT NOT |
| expires_at | DATE NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `export_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| archive_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `export_download_token`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| token | VARCHAR(64) NOT |
| archive_id | BIGINT NOT |
| expires_at | DATETIME NOT |
| download_count | BIGINT NOT |
| max_downloads | BIGINT NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | export_archive(id) ON |

## Domain group: `fee_*`


### `fee_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| rule_code | VARCHAR(40) NULL |
| account_email | VARCHAR(100) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `fee_rule`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| rule_code | VARCHAR(40) NOT |
| name | VARCHAR(100) NOT |
| fee_type | ENUM('FLAT','PERCENT','TIERED') NOT |
| currency_code | CHAR(3) NOT |
| flat_amount | DECIMAL(30,10) NOT |
| percent_rate | DECIMAL(9,6) NOT |
| min_amount | DECIMAL(30,10) NOT |
| max_amount | DECIMAL(30,10) NOT |
| priority | INT NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `fee_schedule`

| Column | Type |
|---|---|
| currency_id | INT PRIMARY |
| fee_amount | DECIMAL(18, 4) |
| updated_at | TIMESTAMP DEFAULT |
| REFERENCES | currencies(currency_id) |

### `fee_tier`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| rule_id | INT NOT |
| tier_no | INT NOT |
| from_amount | DECIMAL(30,10) NOT |
| to_amount | DECIMAL(30,10) NOT |
| fixed_fee | DECIMAL(30,10) NOT |
| rate | DECIMAL(9,6) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | fee_rule(id) ON |

### `fee_waiver`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| rule_id | INT NOT |
| account_email | VARCHAR(100) NOT |
| reason | VARCHAR(100) NOT |
| valid_from | DATE NOT |
| valid_to | DATE NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | fee_rule(id) ON |

### `fee_waiver_request`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| fee_type | VARCHAR(40) NOT |
| amount | DECIMAL(18,4) NOT |
| status | ENUM('PENDING','APPROVED','REJECTED') NOT |
| reason | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| decided_by | VARCHAR(100) NULL |
| decided_at | DATETIME NULL |

### `fee_waiver_request_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| waiver_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `fraud_*`


### `fraud_review`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| case_ref | VARCHAR(64) NOT |
| customer_email | VARCHAR(100) NOT |
| status | ENUM('OPEN','REVIEWING','CLEARED','BLOCKED') NOT |
| risk_score | INT NOT |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| decided_by | VARCHAR(100) NULL |
| decided_at | DATETIME NULL |

### `fraud_review_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| review_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `fx_*`


### `fx_deal`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| deal_ref | VARCHAR(64) NOT |
| currency_pair | VARCHAR(20) NOT |
| side | ENUM('BUY','SELL') NOT |
| amount | DECIMAL(18,4) NOT |
| rate | DECIMAL(18,8) NOT |
| value_date | DATE NULL |
| status | ENUM('PENDING','CONFIRMED','SETTLED','CANCELLED') NOT |
| counterparty | VARCHAR(100) NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `fx_deal_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| deal_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `gl_*`


### `gl_account`

| Column | Type |
|---|---|
| account_code | VARCHAR(20) PRIMARY |
| name | VARCHAR(100) NOT |
| account_type | ENUM('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE') NOT |
| normal_side | ENUM('DEBIT','CREDIT') NOT |
| parent_code | VARCHAR(20) NULL |
| is_active | BOOLEAN NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | gl_account(account_code) ON |

### `gl_audit`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| action | VARCHAR(32) NOT |
| journal_id | INT NULL |
| account_code | VARCHAR(20) NULL |
| actor_email | VARCHAR(100) |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `gl_journal`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| posting_date | DATE NOT |
| description | VARCHAR(255) NOT |
| currency_code | CHAR(3) NOT |
| status | ENUM('POSTED','REVERSED') NOT |
| source | VARCHAR(20) NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `gl_journal_line`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| journal_id | INT NOT |
| gl_account_code | VARCHAR(20) NOT |
| debit_amount | DECIMAL(30,10) NOT |
| credit_amount | DECIMAL(30,10) NOT |
| memo | VARCHAR(255) |
| REFERENCES | gl_journal(id) ON |
| REFERENCES | gl_account(account_code) ON |

### `gl_period`

| Column | Type |
|---|---|
| period_code | CHAR(7) PRIMARY |
| status | ENUM('OPEN','CLOSED') NOT |
| opened_at | TIMESTAMP DEFAULT |
| closed_at | DATETIME NULL |
| closed_by | VARCHAR(100) |

### `gl_period_lock`

| Column | Type |
|---|---|
| period | VARCHAR(20) PRIMARY |
| status | ENUM('OPEN','LOCKED','CLOSED') NOT |
| locked_by | VARCHAR(100) NULL |
| locked_at | DATETIME NULL |
| closed_at | DATETIME NULL |

### `gl_period_lock_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| period | VARCHAR(20) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `gl_revaluation_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `gl_revaluation_line`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| run_id | BIGINT NOT |
| account_code | VARCHAR(20) NOT |
| original_balance | DECIMAL(18,4) NOT |
| revalued_balance | DECIMAL(18,4) NOT |
| diff | DECIMAL(18,4) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | gl_revaluation_run(id) ON |

### `gl_revaluation_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| period | VARCHAR(20) NOT |
| currency | CHAR(3) NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| matched_count | BIGINT NOT |
| diff_amount | DECIMAL(18,4) NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| completed_at | DATETIME NULL |

## Domain group: `import_*`


### `import_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| batch_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `import_batch`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| batch_code | VARCHAR(40) NOT |
| source_name | VARCHAR(100) NOT |
| import_type | ENUM('LEDGER','ACCOUNTS','REFERENCE','PAYMENTS') NOT |
| status | ENUM('STAGED','VALIDATING','VALIDATED','COMPLETED','FAILED') NOT |
| total_rows | BIGINT NOT |
| valid_rows | BIGINT NOT |
| invalid_rows | BIGINT NOT |
| posted_rows | BIGINT NOT |
| error_code | VARCHAR(40) NULL |
| error_detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| version | INT NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `import_posting`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| batch_id | INT NOT |
| journal_id | INT NOT |
| posted_rows | BIGINT NOT |
| total_debit | DECIMAL(30,10) NOT |
| total_credit | DECIMAL(30,10) NOT |
| status | ENUM('POSTED','REVERSED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | import_batch(id) ON |
| REFERENCES | gl_journal(id) |

### `import_recon_item`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| run_id | INT NOT |
| import_row_id | INT NOT |
| account_code | VARCHAR(20) NOT |
| debit_amount | DECIMAL(30,10) NOT |
| credit_amount | DECIMAL(30,10) NOT |
| matched_journal_id | INT NULL |
| match_status | ENUM('MATCHED','UNMATCHED','MISMATCH') NOT |
| detail | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | import_recon_run(id) ON |
| REFERENCES | import_row(id) ON |
| REFERENCES | gl_journal(id) ON |

### `import_recon_run`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| batch_id | INT NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| row_count | BIGINT NOT |
| matched_count | BIGINT NOT |
| unmatched_count | BIGINT NOT |
| mismatch_count | BIGINT NOT |
| error_detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| started_at | DATETIME NOT |
| finished_at | DATETIME NULL |
| REFERENCES | import_batch(id) ON |

### `import_row`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| batch_id | INT NOT |
| row_no | INT NOT |
| raw_data | VARCHAR(500) NOT |
| status | ENUM('STAGED','VALID','INVALID','POSTED','SKIPPED') NOT |
| error_code | VARCHAR(40) NULL |
| error_detail | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |
| REFERENCES | import_batch(id) ON |

## Domain group: `incident_*`


### `incident`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| title | VARCHAR(100) NOT |
| severity | ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT |
| source | VARCHAR(100) NOT |
| status | ENUM('OPEN','ACKNOWLEDGED','RESOLVED','CLOSED') NOT |
| assignee | VARCHAR(100) NULL |
| resolution | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| resolved_at | DATETIME NULL |
| closed_at | DATETIME NULL |

### `incident_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| incident_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `journal_*`


### `journal_entries`

| Column | Type |
|---|---|
| journal_id | BIGINT AUTO_INCREMENT |
| txn_ref | VARCHAR(50) NOT |
| source | ENUM('TRANSFER','REVERSAL','FEE') NOT |
| actor_email | VARCHAR(100) NOT |
| value_date | DATE NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `key_*`


### `key_rotation_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| plan_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `key_rotation_plan`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| current_version | INT NOT |
| status | ENUM('SCHEDULED','ACTIVE','COMPLETED','CANCELLED') NOT |
| overlap_seconds | INT NOT |
| next_rotation_at | DATETIME NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| completed_at | DATETIME NULL |

## Domain group: `known_*`


### `known_devices`

| Column | Type |
|---|---|
| email | VARCHAR(100) NOT |
| user_agent | VARCHAR(255) NOT |
| ip | VARCHAR(45) NOT |
| first_seen_at | TIMESTAMP DEFAULT |
| last_seen_at | TIMESTAMP DEFAULT |

## Domain group: `kyc_*`


### `kyc_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| case_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `kyc_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| case_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `kyc_case`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| review_type | ENUM('ONBOARDING','PERIODIC','ENHANCED') NOT |
| status | ENUM('PENDING','APPROVED','REJECTED','ESCALATED') NOT |
| risk_level | ENUM('LOW','MEDIUM','HIGH') NOT |
| due_date | DATE NULL |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| decided_by | VARCHAR(100) NULL |
| decided_at | DATETIME NULL |

### `kyc_case`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| review_type | ENUM('ONBOARDING','PERIODIC','ENHANCED') NOT |
| status | ENUM('PENDING','APPROVED','REJECTED','ESCALATED') NOT |
| risk_level | ENUM('LOW','MEDIUM','HIGH') NOT |
| due_date | DATE NULL |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| decided_by | VARCHAR(100) NULL |
| decided_at | DATETIME NULL |

### `kyc_evidence`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| case_id | BIGINT NOT |
| evidence_type | VARCHAR(40) NOT |
| ref | VARCHAR(128) NOT |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | kyc_case(id) ON |

### `kyc_evidence`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| case_id | BIGINT NOT |
| evidence_type | VARCHAR(40) NOT |
| ref | VARCHAR(128) NOT |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | kyc_case(id) ON |

### `kyc_review`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| review_type | ENUM('ONBOARDING','PERIODIC','ENHANCED') NOT |
| status | ENUM('PENDING','APPROVED','REJECTED','ESCALATED') NOT |
| risk_level | ENUM('LOW','MEDIUM','HIGH') NOT |
| due_date | DATE NULL |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| decided_by | VARCHAR(100) NULL |
| decided_at | DATETIME NULL |

### `kyc_review_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| review_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `lbpue_*`


### `lbpue_report`

| Column | Type |
|---|---|
| report_code | VARCHAR(40) PRIMARY |
| period | VARCHAR(20) NOT |
| status | ENUM('DRAFT','GENERATED','SUBMITTED') NOT |
| row_count | BIGINT NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| submitted_at | DATETIME NULL |

### `lbpue_report_execution_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| report_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `ledger_*`


### `ledger`

| Column | Type |
|---|---|
| ledger_id | BIGINT AUTO_INCREMENT |
| txn_ref | VARCHAR(50) NOT |
| account_id | INT NOT |
| amount | DECIMAL(18, 4) |
| type | ENUM('CREDIT', 'DEBIT') |
| currency_id | INT NOT |
| from_email | VARCHAR(100) |
| description | VARCHAR(255) |
| exchange_rate | DECIMAL(30, 18) |
| journal_id | BIGINT NULL |
| created_at | TIMESTAMP DEFAULT |

### `ledger_archive`

| Column | Type |
|---|---|
| ledger_id | BIGINT PRIMARY |
| txn_ref | VARCHAR(50) NOT |
| account_id | INT NOT |
| amount | DECIMAL(18, 4) |
| type | ENUM('CREDIT', 'DEBIT') |
| currency_id | INT NOT |
| from_email | VARCHAR(100) NULL |
| description | VARCHAR(255) |
| exchange_rate | DECIMAL(30, 18) |
| journal_id | BIGINT NULL |
| created_at | TIMESTAMP NULL |
| archived_at | TIMESTAMP DEFAULT |

## Domain group: `legal_*`


### `legal_hold`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| subject_email | VARCHAR(100) NOT |
| case_ref | VARCHAR(64) NOT |
| scope | ENUM('USER','ACCOUNT','AUDIT','LEDGER','GENERAL') NOT |
| status | ENUM('ACTIVE','RELEASED') NOT |
| reason | VARCHAR(255) NULL |
| placed_by | VARCHAR(100) NOT |
| placed_at | TIMESTAMP DEFAULT |
| released_by | VARCHAR(100) NULL |
| released_at | DATETIME NULL |

### `legal_hold_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| hold_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `limit_*`


### `limit_profile`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| daily_limit | DECIMAL(18,4) NOT |
| monthly_limit | DECIMAL(18,4) NOT |
| velocity_tier | VARCHAR(20) NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `limit_profile_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| profile_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `loan_*`


### `loan_application`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| principal | DECIMAL(18,4) NOT |
| currency | CHAR(3) NOT |
| term_months | INT NOT |
| interest_rate | DECIMAL(9,4) NOT |
| status | ENUM('PENDING','APPROVED','REJECTED','DISBURSED','CLOSED') NOT |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| decided_by | VARCHAR(100) NULL |
| decided_at | DATETIME NULL |
| disbursed_at | DATETIME NULL |

### `loan_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| loan_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `loan_repayment`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| loan_id | BIGINT NOT |
| amount | DECIMAL(18,4) NOT |
| status | ENUM('PENDING','PAID') NOT |
| due_date | DATE NULL |
| paid_at | DATETIME NULL |
| REFERENCES | loan_application(id) ON |

## Domain group: `maker_*`


### `maker_requests`

| Column | Type |
|---|---|
| request_id | BIGINT AUTO_INCREMENT |
| operation | VARCHAR(50) NOT |
| target_email | VARCHAR(100) NOT |
| detail | VARCHAR(255) NULL |
| maker_email | VARCHAR(100) NOT |
| state | ENUM('PENDING','APPROVED','REJECTED') NOT |
| created_at | TIMESTAMP DEFAULT |
| decided_at | TIMESTAMP NULL |
| REFERENCES | dual_control_operations(operation) |

## Domain group: `mfa_*`


### `mfa_backup_codes`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| user_id | INT NOT |
| code_hash | VARCHAR(255) NOT |
| used | BOOLEAN NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | users(id) ON |

### `mfa_recovery_requests`

| Column | Type |
|---|---|
| request_id | BIGINT AUTO_INCREMENT |
| user_id | INT NOT |
| state | ENUM('PENDING','VERIFIED','APPROVED','REJECTED') NOT |
| created_at | TIMESTAMP DEFAULT |
| decided_at | TIMESTAMP NULL |
| decided_by | INT NULL |
| REFERENCES | users(id) ON |

## Domain group: `notification_*`


### `notification_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| template_code | VARCHAR(40) NULL |
| user_email | VARCHAR(100) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `notification_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| channel | VARCHAR(20) NOT |
| recipient | VARCHAR(100) NOT |
| status | ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT |
| retry_count | INT NOT |
| enqueued_by | VARCHAR(100) NOT |
| enqueued_at | TIMESTAMP DEFAULT |

### `notification_audit_entry`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| audit_id | BIGINT NOT |
| event | VARCHAR(40) NOT |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `notification_delivery`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| channel | VARCHAR(20) NOT |
| recipient | VARCHAR(100) NOT |
| status | ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT |
| retry_count | INT NOT |
| enqueued_by | VARCHAR(100) NOT |
| enqueued_at | TIMESTAMP DEFAULT |

### `notification_delivery_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| entry_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `notification_outbox`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| recipient | VARCHAR(100) NOT |
| purpose | VARCHAR(32) NOT |
| code | VARCHAR(20) NOT |
| detail | VARCHAR(255) NOT |
| state | ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT |
| attempts | INT NOT |
| next_attempt_at | TIMESTAMP NULL |
| last_error | VARCHAR(255) NULL |
| claimed_by | VARCHAR(100) NULL |
| claimed_at | TIMESTAMP NULL |
| created_at | TIMESTAMP DEFAULT |
| sent_at | TIMESTAMP NULL |

### `notification_preference`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| user_email | VARCHAR(100) NOT |
| purpose | VARCHAR(32) NOT |
| channel | ENUM('EMAIL','INAPP') NOT |
| enabled | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `notification_template`

| Column | Type |
|---|---|
| template_code | VARCHAR(40) PRIMARY |
| purpose | VARCHAR(32) NOT |
| channel | ENUM('EMAIL','INAPP') NOT |
| subject | VARCHAR(160) NOT |
| body | VARCHAR(1000) NOT |
| enabled | BOOLEAN NOT |
| updated_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

## Domain group: `oncall_*`


### `oncall_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| page_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `oncall_delivery`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| page_id | BIGINT NOT |
| channel | ENUM('EMAIL','PAGE') NOT |
| target_email | VARCHAR(100) NOT |
| status | ENUM('QUEUED','SENT','DELIVERED','FAILED','CONFIRMED') NOT |
| retry_count | INT NOT |
| max_retries | INT NOT |
| sent_at | DATETIME NULL |
| delivered_at | DATETIME NULL |
| confirmed_at | DATETIME NULL |
| detail | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | oncall_page(id) ON |

### `oncall_delivery_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| delivery_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `oncall_page`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| alert_id | BIGINT NOT |
| policy_id | INT NULL |
| step_no | INT NOT |
| target_email | VARCHAR(100) NOT |
| status | ENUM('PAGED','ACKED','RESOLVED','FAILED') NOT |
| detail | VARCHAR(255) NULL |
| paged_at | TIMESTAMP DEFAULT |
| acked_at | DATETIME NULL |
| resolved_at | DATETIME NULL |
| created_by | VARCHAR(100) NOT |
| REFERENCES | escalation_policy(id) ON |

### `oncall_rotation`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| rotation_code | VARCHAR(40) NOT |
| name | VARCHAR(100) NOT |
| timezone | VARCHAR(64) NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `oncall_shift`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| rotation_id | INT NOT |
| user_email | VARCHAR(100) NOT |
| starts_at | DATETIME NOT |
| ends_at | DATETIME NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | oncall_rotation(id) ON |

## Domain group: `ops_*`


### `ops_alert`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| alert_type | VARCHAR(32) NOT |
| severity | ENUM('INFO','WARNING','CRITICAL') NOT |
| source_key | VARCHAR(120) NOT |
| title | VARCHAR(160) NOT |
| detail | VARCHAR(255) NOT |
| state | ENUM('OPEN','ACKNOWLEDGED','RESOLVED') NOT |
| owner_email | VARCHAR(100) NULL |
| acknowledged_at | DATETIME NULL |
| resolved_at | DATETIME NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `ops_alert_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| alert_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `ops_alert_event`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| alert_id | BIGINT NOT |
| event | ENUM('RAISED','ACKNOWLEDGED','RESOLVED','NOTE','REOPENED') NOT |
| actor_email | VARCHAR(100) NOT |
| note | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | ops_alert(id) ON |

## Domain group: `password_*`


### `password_blocklist`

| Column | Type |
|---|---|
| hash | CHAR(64) NOT |
| note | VARCHAR(100) NOT |

### `password_history`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| user_id | INT NOT |
| password_hash | VARCHAR(255) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | users(id) ON |

## Domain group: `payment_*`


### `payment_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| user_email | VARCHAR(100) NULL |
| currency_code | CHAR(3) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `payment_hold`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| account_id | INT NOT |
| amount | DECIMAL(18,4) NOT |
| currency | CHAR(3) NOT |
| status | ENUM('ACTIVE','CAPTURED','RELEASED','EXPIRED','FAILED') NOT |
| expires_at | DATETIME NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| captured_at | DATETIME NULL |
| released_at | DATETIME NULL |
| REFERENCES | accounts(account_id) ON |

### `payment_hold_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| hold_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `payment_instruction`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| instruction_code | VARCHAR(40) NOT |
| from_email | VARCHAR(100) NOT |
| to_email | VARCHAR(100) NOT |
| amount | DECIMAL(30,10) NOT |
| currency_code | CHAR(3) NOT |
| frequency | ENUM('ONCE','DAILY','WEEKLY','MONTHLY') NOT |
| next_run_date | DATE NOT |
| end_date | DATE NULL |
| status | ENUM('ACTIVE','PAUSED','CANCELLED','COMPLETED') NOT |
| last_run_at | DATETIME NULL |
| last_txn_ref | VARCHAR(50) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `payment_instruction_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| instruction_id | BIGINT NOT |
| status | ENUM('COMPLETED','FAILED') NOT |
| txn_ref | VARCHAR(50) NULL |
| error_detail | VARCHAR(255) NULL |
| run_at | TIMESTAMP DEFAULT |
| created_by | VARCHAR(100) NOT |
| REFERENCES | payment_instruction(id) ON |

### `payment_policy`

| Column | Type |
|---|---|
| currency_code | CHAR(3) PRIMARY |
| max_per_txn | DECIMAL(30,10) NOT |
| daily_limit | DECIMAL(30,10) NOT |
| daily_count | INT NOT |
| hold_threshold | DECIMAL(30,10) NOT |
| hold_percent | DECIMAL(5,2) NOT |
| enabled | BOOLEAN NOT |
| updated_by | VARCHAR(100) NOT |
| updated_at | TIMESTAMP DEFAULT |

### `payment_profile`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| user_email | VARCHAR(100) NOT |
| currency_code | CHAR(3) NOT |
| daily_limit | DECIMAL(30,10) NOT |
| daily_count | INT NOT |
| enabled | BOOLEAN NOT |
| updated_by | VARCHAR(100) NOT |
| updated_at | TIMESTAMP DEFAULT |

## Domain group: `pending_*`


### `pending_transactions`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| txn_ref | VARCHAR(50) NOT |
| from_email | VARCHAR(100) NOT |
| to_email | VARCHAR(100) NOT |
| amount | DECIMAL(18,4) NOT |
| status | ENUM('PENDING' |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `pending_transactions_archive`

| Column | Type |
|---|---|
| id | BIGINT PRIMARY |
| txn_ref | VARCHAR(50) NOT |
| from_email | VARCHAR(100) NOT |
| to_email | VARCHAR(100) NOT |
| amount | DECIMAL(18,4) NOT |
| status | ENUM('PENDING' |
| created_at | TIMESTAMP |
| updated_at | TIMESTAMP |
| archived_at | TIMESTAMP DEFAULT |

## Domain group: `permissions_*`


### `permissions`

| Column | Type |
|---|---|
| name | VARCHAR(30) NOT |
| description | VARCHAR(255) NOT |

## Domain group: `pipeline_*`


### `pipeline_alert`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| pipeline_name | VARCHAR(100) NOT |
| severity | ENUM('INFO','WARNING','CRITICAL') NOT |
| status | ENUM('OPEN','ACKNOWLEDGED','RESOLVED') NOT |
| message | VARCHAR(255) NOT |
| source_key | VARCHAR(100) NOT |
| occurrence_count | BIGINT NOT |
| first_seen_at | TIMESTAMP DEFAULT |
| last_seen_at | TIMESTAMP DEFAULT |
| acknowledged_by | VARCHAR(100) NULL |
| resolved_by | VARCHAR(100) NULL |
| resolved_at | DATETIME NULL |
| detail | VARCHAR(255) NULL |

### `pipeline_alert_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| alert_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `policy_*`


### `policy_attestation`

| Column | Type |
|---|---|
| attestation_code | VARCHAR(40) PRIMARY |
| policy_name | VARCHAR(120) NOT |
| owner_email | VARCHAR(100) NOT |
| status | ENUM('PENDING','ATTESTED','EXPIRED') NOT |
| due_date | DATE NULL |
| attested_at | DATETIME NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `policy_attestation_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| attestation_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `procurement_*`


### `procurement_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| request_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `procurement_request`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| request_code | VARCHAR(40) NOT |
| item | VARCHAR(120) NOT |
| amount | DECIMAL(18,4) NOT |
| status | ENUM('DRAFT','SUBMITTED','APPROVED','REJECTED','ORDERED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `recon_*`


### `recon_assignment`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| finding_id | BIGINT NOT |
| from_owner | VARCHAR(100) NULL |
| to_owner | VARCHAR(100) NOT |
| rule_code | VARCHAR(40) NULL |
| assigned_by | VARCHAR(100) NOT |
| note | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | reconciliation_findings(finding_id) ON |

### `recon_assignment_rule`

| Column | Type |
|---|---|
| rule_code | VARCHAR(40) PRIMARY |
| owner_email | VARCHAR(100) NOT |
| status_filter | ENUM('ANY','OPEN','ACKNOWLEDGED') NOT |
| min_age_hours | INT NOT |
| priority | INT NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| updated_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `recon_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| finding_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `recon_exception`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| finding_id | BIGINT NULL |
| exception_code | VARCHAR(40) NOT |
| priority | ENUM('LOW','NORMAL','HIGH','URGENT') NOT |
| owner_email | VARCHAR(100) NULL |
| state | ENUM('OPEN','ACKNOWLEDGED','IN_PROGRESS','RESOLVED','REJECTED','CLOSED') NOT |
| due_date | DATE NULL |
| resolution | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |
| resolved_at | DATETIME NULL |
| REFERENCES | reconciliation_findings(finding_id) ON |

### `recon_exception_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| exception_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `recon_exception_note`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| exception_id | BIGINT NOT |
| author_email | VARCHAR(100) NOT |
| body | VARCHAR(255) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | recon_exception(id) ON |

### `recon_note`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| finding_id | BIGINT NOT |
| actor_email | VARCHAR(100) NOT |
| note | VARCHAR(255) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | reconciliation_findings(finding_id) ON |

### `recon_sla_policy`

| Column | Type |
|---|---|
| policy_code | VARCHAR(32) PRIMARY |
| age_hours | INT NOT |
| enabled | BOOLEAN NOT |
| updated_by | VARCHAR(100) NOT |
| updated_at | TIMESTAMP DEFAULT |

## Domain group: `reconciliation_*`


### `reconciliation_findings`

| Column | Type |
|---|---|
| finding_id | BIGINT AUTO_INCREMENT |
| run_id | BIGINT NOT |
| account_id | INT NOT |
| balance | DECIMAL(18, 4) |
| ledger_sum | DECIMAL(18, 4) |
| status | ENUM('OPEN','ACKNOWLEDGED','RESOLVED') NOT |
| owner_email | VARCHAR(100) NULL |
| resolution_note | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| resolved_at | TIMESTAMP NULL |
| REFERENCES | reconciliation_runs(run_id) |
| REFERENCES | accounts(account_id) ON |

### `reconciliation_runs`

| Column | Type |
|---|---|
| run_id | BIGINT AUTO_INCREMENT |
| trigger_src | ENUM('MANUAL','SCHEDULED') NOT |
| actor_email | VARCHAR(100) NOT |
| status | ENUM('CLEAN','MISMATCH') NOT |
| mismatch_count | INT NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `ref_*`


### `ref_account_class`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_account_feature`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_account_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_account_ownership`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_account_purpose`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_account_restriction`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_account_status`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_account_subtype`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_account_type`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_accrual_basis`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_address_format`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_address_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_address_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_adjustment_reason`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_approval_outcome`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_approval_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_audit_event_type`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_audit_result`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_audit_severity`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_audit_source`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_balance_class`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_balance_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_batch_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_batch_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_branch`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_branch_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_business_day`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_calendar`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_calendar_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_card_network`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_card_product`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_card_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_case_priority`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_case_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_channel`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_channel_class`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_charge_basis`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_charge_code`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_charge_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_charge_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_city`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_clearing_account`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_clearing_cycle`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_complaint_category`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_compounding_method`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_consent_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_consent_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_contact_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_contact_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_cost_center`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_country`

| Column | Type |
|---|---|
| code | VARCHAR(2) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_country_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_country_region`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_currency_pair`

| Column | Type |
|---|---|
| code | VARCHAR(7) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_customer_category`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_customer_channel`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_customer_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_customer_industry`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_customer_occupation`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_customer_segment`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_customer_source`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_customer_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_customer_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_cut_off_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_cut_off_time`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_day_count_basis`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_delivery_channel`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_department`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_deposit_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_device_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_dispute_reason`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_district`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_document_category`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_document_format`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_document_owner`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_document_source`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_document_state`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_document_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_document_template`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_document_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_email_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_employee_grade`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_engine_audit`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| type_code | VARCHAR(32) NOT |
| value_code | VARCHAR(64) NOT |
| action | VARCHAR(32) NOT |
| actor_email | VARCHAR(100) |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `ref_entry_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_error_code`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_escalation_level`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_event_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_event_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_export_delivery`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_export_schedule`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_export_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_fee_basis`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_fee_cap`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_fee_code`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_fee_frequency`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_fee_rounding`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_fee_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_fee_waiver`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_file_direction`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_file_format`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_file_source`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_file_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_gl_category`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_hierarchy`

| Column | Type |
|---|---|
| parent_value_id | INT NOT |
| child_value_id | INT NOT |
| REFERENCES | ref_value(id) ON |
| REFERENCES | ref_value(id) ON |

### `ref_holiday`

| Column | Type |
|---|---|
| code | VARCHAR(10) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_holiday_calendar`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_identity_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_identity_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_interest_basis`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_job_priority`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_job_title`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_journal_source`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_journal_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_language`

| Column | Type |
|---|---|
| code | VARCHAR(3) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_ledger_class`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_limit_basis`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_limit_frequency`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_limit_profile`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_limit_scope`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_limit_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_loan_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_merchant_category`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_message_channel`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_message_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_message_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_notification_channel`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_notification_priority`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_notification_result`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_notification_template`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_notification_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_payment_channel`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_payment_rail`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_payment_scheme`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_payment_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_phone_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_postal_code`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_posting_frequency`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_posting_rule`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_posting_window`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_precision_rule`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_pricing_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_pricing_tier`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_priority`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_product_family`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_product_feature`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_product_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_product_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_product_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_profit_center`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_province`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_queue`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_queue_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_queue_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_rate_benchmark`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_rate_index`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_rate_source`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_rate_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_reason_code`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_region`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_region_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_category`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_column`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_delivery`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_filter`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_frequency`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_layout`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_parameter`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_schedule`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_scheduler`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_report_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_request_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_request_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_reversal_reason`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_review_outcome`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_review_state`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_review_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_rounding_rule`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_schedule_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_service_level`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_settlement_account`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_settlement_cycle`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_settlement_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_sla_profile`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_spread_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_statement_format`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_status_code`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_status_reason`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_suspense_account`

| Column | Type |
|---|---|
| code | VARCHAR(8) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_task_priority`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_task_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_tax_basis`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_tax_code`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_tax_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_tax_jurisdiction`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_tax_rate_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_team`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_template_scope`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_template_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_tier`

| Column | Type |
|---|---|
| code | VARCHAR(4) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_timezone`

| Column | Type |
|---|---|
| code | VARCHAR(5) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_timezone_region`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_transaction_channel`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_transaction_class`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_transaction_code`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_transaction_group`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_transaction_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_translation`

| Column | Type |
|---|---|
| ref_value_id | INT NOT |
| locale | VARCHAR(10) NOT |
| label | VARCHAR(128) NOT |
| REFERENCES | ref_value(id) ON |

### `ref_type`

| Column | Type |
|---|---|
| type_code | VARCHAR(32) PRIMARY |
| label | VARCHAR(64) NOT |
| description | VARCHAR(255) |
| is_active | BOOLEAN NOT |
| created_at | TIMESTAMP DEFAULT |

### `ref_user_segment`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_value`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| type_code | VARCHAR(32) NOT |
| code | VARCHAR(64) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | ref_type(type_code) ON |

### `ref_value_date_rule`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_value_version`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| ref_value_id | INT NOT |
| version_no | INT NOT |
| label | VARCHAR(128) NOT |
| attributes | TEXT |
| status | ENUM('DRAFT','ACTIVE','RETIRED') NOT |
| effective_from | DATE NOT |
| effective_to | DATE NULL |
| approved_by | VARCHAR(100) |
| approved_at | DATETIME |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | ref_value(id) ON |

### `ref_verification_status`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_verification_type`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_workflow_action`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

### `ref_workflow_role`

| Column | Type |
|---|---|
| code | VARCHAR(6) PRIMARY |
| label | VARCHAR(64) NOT |
| num_val | INT NOT |
| is_active | BOOLEAN NOT |
| updated_at | TIMESTAMP DEFAULT |

## Domain group: `reference_*`


### `reference_audit`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| entity | VARCHAR(64) NOT |
| entity_key | VARCHAR(128) NOT |
| action | VARCHAR(32) NOT |
| actor_email | VARCHAR(100) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `refresh_*`


### `refresh_families`

| Column | Type |
|---|---|
| family | VARCHAR(50) PRIMARY |
| email | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| rotations | INT NOT |

### `refresh_sessions`

| Column | Type |
|---|---|
| jti | VARCHAR(50) PRIMARY |
| family | VARCHAR(50) NOT |
| email | VARCHAR(100) NOT |
| revoked | BOOLEAN NOT |
| expires_at | TIMESTAMP NOT |
| created_at | TIMESTAMP DEFAULT |
| user_agent | VARCHAR(255) NULL |
| ip | VARCHAR(45) NULL |
| last_seen_at | TIMESTAMP NULL |

## Domain group: `regulatory_*`


### `regulatory_calendar`

| Column | Type |
|---|---|
| event_code | VARCHAR(40) PRIMARY |
| title | VARCHAR(120) NOT |
| regulator | VARCHAR(20) NOT |
| due_date | DATE NOT |
| status | ENUM('OPEN','DONE','CANCELLED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `regulatory_calendar_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| event_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `regulatory_report`

| Column | Type |
|---|---|
| report_code | VARCHAR(40) PRIMARY |
| regulator | ENUM('OJK','BI','PPATK') NOT |
| report_type | VARCHAR(40) NOT |
| period | VARCHAR(40) NOT |
| status | ENUM('DRAFT','SUBMITTED','ACCEPTED','REJECTED') NOT |
| row_count | BIGINT NOT |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| submitted_at | DATETIME NULL |
| decided_at | DATETIME NULL |

### `regulatory_report_execution_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| report_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `report_*`


### `report_archive`

| Column | Type |
|---|---|
| archive_code | VARCHAR(40) PRIMARY |
| report_type | VARCHAR(40) NOT |
| period | VARCHAR(40) NOT |
| row_count | BIGINT NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `report_archive_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| archive_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `report_execution_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| template_code | VARCHAR(40) NULL |
| run_id | INT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `report_execution_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| report_name | VARCHAR(64) NOT |
| duration_ms | INT NOT |
| status | ENUM('OK','FAILED') NOT |
| recorded_by | VARCHAR(100) NOT |
| recorded_at | TIMESTAMP DEFAULT |

### `report_execution_audit_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `report_layout`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| template_id | INT NOT |
| page_width | INT NOT |
| page_length | INT NOT |
| header_text | VARCHAR(100) NOT |
| footer_text | VARCHAR(100) NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |
| REFERENCES | report_template(id) ON |

### `report_run`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| template_id | INT NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| parameters | VARCHAR(255) NOT |
| row_count | BIGINT NOT |
| total_debit | DECIMAL(30,10) NOT |
| total_credit | DECIMAL(30,10) NOT |
| started_at | DATETIME NOT |
| finished_at | DATETIME NULL |
| error_code | VARCHAR(40) NULL |
| error_detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| version | INT NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |
| REFERENCES | report_template(id) |

### `report_run_row`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| run_id | INT NOT |
| ordinal | INT NOT |
| row_data | VARCHAR(500) NOT |
| debit | DECIMAL(30,10) NOT |
| credit | DECIMAL(30,10) NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | report_run(id) ON |

### `report_scheduler`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| template_code | VARCHAR(40) NOT |
| frequency | ENUM('DAILY','WEEKLY','MONTHLY') NOT |
| schedule_time | TIME NOT |
| output_format | ENUM('CSV','FIXED','JSON') NOT |
| currency_code | CHAR(3) NOT |
| recipient | VARCHAR(100) NOT |
| enabled | BOOLEAN NOT |
| last_run_at | DATETIME NULL |
| next_run_date | DATE NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `report_scheduler`

| Column | Type |
|---|---|
| schedule_code | VARCHAR(40) PRIMARY |
| report_type | VARCHAR(40) NOT |
| frequency | ENUM('DAILY','WEEKLY','MONTHLY') NOT |
| next_run_at | DATETIME NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `report_scheduler_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| schedule_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `report_scheduler_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| schedule_code | VARCHAR(40) NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| row_count | BIGINT NOT |
| error_detail | VARCHAR(255) NULL |
| started_at | TIMESTAMP DEFAULT |
| completed_at | DATETIME NULL |
| REFERENCES | report_scheduler(schedule_code) ON |

### `report_scheduler_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| schedule_id | INT NOT |
| report_run_id | INT NULL |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| period_from | DATE NULL |
| period_to | DATE NULL |
| currency_code | CHAR(3) NULL |
| output_format | ENUM('CSV','FIXED','JSON') NULL |
| error_detail | VARCHAR(255) NULL |
| started_at | DATETIME NOT |
| finished_at | DATETIME NULL |
| created_by | VARCHAR(100) NOT |
| REFERENCES | report_scheduler(id) ON |
| REFERENCES | report_run(id) ON |

### `report_template`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| template_code | VARCHAR(40) NOT |
| name | VARCHAR(100) NOT |
| report_type | ENUM('TRIAL_BALANCE','STATEMENT','RECONCILIATION','CUSTOM') NOT |
| output_format | ENUM('CSV','FIXED','JSON') NOT |
| title | VARCHAR(100) NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `report_template_column`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| template_id | INT NOT |
| ordinal | INT NOT |
| header | VARCHAR(100) NOT |
| source_field | VARCHAR(100) NOT |
| width | INT NOT |
| align | ENUM('LEFT','RIGHT','CENTER') NOT |
| column_format | ENUM('TEXT','AMOUNT','DATE','INTEGER') NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | report_template(id) ON |

## Domain group: `retention_*`


### `retention_job_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `retention_job_policy`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| data_class | VARCHAR(40) NOT |
| retention_days | INT NOT |
| enabled | TINYINT NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

### `retention_job_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| data_class | VARCHAR(40) NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| cutoff_at | DATETIME NOT |
| archived_count | BIGINT NOT |
| deleted_count | BIGINT NOT |
| skipped_count | BIGINT NOT |
| detail | VARCHAR(255) NULL |
| executed_by | VARCHAR(100) NOT |
| started_at | TIMESTAMP DEFAULT |
| finished_at | DATETIME NULL |

## Domain group: `reversal_*`


### `reversal_fee_policy`

| Column | Type |
|---|---|
| reason | VARCHAR(100) PRIMARY |
| refund_fee | TINYINT(1) NOT |
| updated_at | TIMESTAMP DEFAULT |

## Domain group: `revoked_*`


### `revoked_access_tokens`

| Column | Type |
|---|---|
| jti | VARCHAR(50) PRIMARY |
| email | VARCHAR(100) NOT |
| expires_at | TIMESTAMP NOT |
| revoked_at | TIMESTAMP DEFAULT |

## Domain group: `risk_*`


### `risk_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| customer_email | VARCHAR(100) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `risk_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| customer_email | VARCHAR(100) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `risk_profile`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| risk_level | ENUM('LOW','MEDIUM','HIGH') NOT |
| score | INT NOT |
| updated_by | VARCHAR(100) NOT |
| updated_at | TIMESTAMP DEFAULT |

### `risk_profile`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| risk_level | ENUM('LOW','MEDIUM','HIGH') NOT |
| score | INT NOT |
| updated_by | VARCHAR(100) NOT |
| updated_at | TIMESTAMP DEFAULT |

## Domain group: `role_*`


### `role_permissions`

| Column | Type |
|---|---|
| role | ENUM('USER','MANAGER','SUPER_ADMIN') NOT |
| permission | VARCHAR(30) NOT |
| REFERENCES | permissions(name) ON |

## Domain group: `sanctions_*`


### `sanctions_hold`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| reason | VARCHAR(120) NOT |
| status | ENUM('ACTIVE','RELEASED') NOT |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |
| released_at | DATETIME NULL |

### `sanctions_hold_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| hold_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `schema_*`


### `schema_migrations`

| Column | Type |
|---|---|
| version | VARCHAR(64) PRIMARY |
| applied_at | TIMESTAMP DEFAULT |
| checksum | VARCHAR(64) NULLABLE — SHA-256 of the applied file (tamper-evident since migration 0666; verified by `migrate.sh --check`) |

One row per applied migration plus, on baselined databases, a
`baseline_v2` marker row whose `checksum` pins `database/schema_v2.sql`
(an edited snapshot fails `--check` as a `baseline_v2` mismatch).
Pre-baseline migrations live in `database/migrations/archive/`; see the
baseline lifecycle in [DATA_MODEL.md](DATA_MODEL.md).

## Domain group: `screening_*`


### `screening_hit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| hit_type | VARCHAR(40) NOT |
| severity | ENUM('LOW','MEDIUM','HIGH') NOT |
| status | ENUM('OPEN','CLEARED','BLOCKED') NOT |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `screening_hit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| customer_email | VARCHAR(100) NOT |
| hit_type | VARCHAR(40) NOT |
| severity | ENUM('LOW','MEDIUM','HIGH') NOT |
| status | ENUM('OPEN','CLEARED','BLOCKED') NOT |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `secret_*`


### `secret_rotation`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| secret_name | VARCHAR(64) NOT |
| next_rotation_at | DATETIME NOT |
| overlap_seconds | INT NOT |
| status | ENUM('SCHEDULED','ROTATED','VERIFIED') NOT |
| scheduled_by | VARCHAR(100) NOT |
| scheduled_at | TIMESTAMP DEFAULT |
| rotated_by | VARCHAR(100) NULL |
| rotated_at | DATETIME NULL |
| verified_by | VARCHAR(100) NULL |
| verified_at | DATETIME NULL |

### `secret_rotation_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| secret_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `settlement_*`


### `settlement_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `settlement_item`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| run_id | BIGINT NOT |
| txn_ref | VARCHAR(64) NOT |
| amount | DECIMAL(18,4) NOT |
| status | ENUM('MATCHED','BREAK','RESOLVED') NOT |
| detail | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | settlement_run(id) ON |

### `settlement_run`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| batch_code | VARCHAR(40) NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| matched_count | BIGINT NOT |
| break_count | BIGINT NOT |
| started_by | VARCHAR(100) NOT |
| started_at | TIMESTAMP DEFAULT |
| completed_at | DATETIME NULL |

## Domain group: `sla_*`


### `sla_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| sla_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `sla_breach`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| sla_id | BIGINT NOT |
| observed | VARCHAR(40) NOT |
| breached_at | DATETIME NOT |
| recorded_by | VARCHAR(100) NOT |

### `sla_definition`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| sla_name | VARCHAR(64) NOT |
| target_pct | DECIMAL(5,2) NOT |
| status | ENUM('ACTIVE','RETIRED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `slo_*`


### `slo_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| slo_name | VARCHAR(64) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `slo_definition`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| slo_name | VARCHAR(64) NOT |
| target_pct | DECIMAL(5,2) NOT |
| window_days | INT NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `slo_measurement`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| slo_name | VARCHAR(64) NOT |
| window_start | DATETIME NULL |
| window_end | DATETIME NULL |
| good_events | BIGINT NOT |
| total_events | BIGINT NOT |
| burn_rate | DECIMAL(8,4) NOT |
| status | ENUM('OK','BREACHED') NOT |
| recorded_at | TIMESTAMP DEFAULT |
| recorded_by | VARCHAR(100) NOT |

## Domain group: `statement_*`


### `statement_archive`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| run_id | INT NOT |
| account_email | VARCHAR(100) NOT |
| currency_code | CHAR(3) NOT |
| opening_balance | DECIMAL(30,10) NOT |
| closing_balance | DECIMAL(30,10) NOT |
| total_debit | DECIMAL(30,10) NOT |
| total_credit | DECIMAL(30,10) NOT |
| row_count | BIGINT NOT |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | statement_run(id) ON |

### `statement_archive_line`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| archive_id | INT NOT |
| line_no | BIGINT NOT |
| posting_date | DATE NOT |
| txn_ref | VARCHAR(50) NOT |
| source | VARCHAR(20) NOT |
| debit_amount | DECIMAL(30,10) NOT |
| credit_amount | DECIMAL(30,10) NOT |
| balance_after | DECIMAL(30,10) NOT |
| description | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | statement_archive(id) ON |

### `statement_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| run_id | INT NULL |
| account_email | VARCHAR(100) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `statement_delivery`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| statement_ref | VARCHAR(64) NOT |
| recipient | VARCHAR(100) NOT |
| channel | ENUM('EMAIL','PORTAL') NOT |
| status | ENUM('QUEUED','SENT','DELIVERED','FAILED') NOT |
| retry_count | INT NOT |
| max_retries | INT NOT |
| sent_at | DATETIME NULL |
| delivered_at | DATETIME NULL |
| detail | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |

### `statement_delivery_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| delivery_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `statement_recon_item`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| run_id | INT NOT |
| statement_line_id | BIGINT NOT |
| account_id | INT NULL |
| txn_ref | VARCHAR(50) NOT |
| posting_date | DATE NOT |
| amount | DECIMAL(30,10) NOT |
| matched_ledger_id | BIGINT NULL |
| match_status | ENUM('MATCHED','UNMATCHED','MISMATCH') NOT |
| detail | VARCHAR(255) NULL |
| created_at | TIMESTAMP DEFAULT |
| REFERENCES | statement_recon_run(id) ON |
| REFERENCES | statement_archive_line(id) ON |
| REFERENCES | accounts(account_id) ON |
| REFERENCES | ledger(ledger_id) ON |

### `statement_recon_run`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| statement_run_id | INT NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| line_count | BIGINT NOT |
| matched_count | BIGINT NOT |
| unmatched_count | BIGINT NOT |
| mismatch_count | BIGINT NOT |
| error_detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| started_at | DATETIME NOT |
| finished_at | DATETIME NULL |
| REFERENCES | statement_run(id) ON |

### `statement_run`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| period_start | DATE NOT |
| period_end | DATE NOT |
| currency_code | CHAR(3) NOT |
| status | ENUM('RUNNING','COMPLETED','FAILED') NOT |
| account_count | BIGINT NOT |
| generated_count | BIGINT NOT |
| failed_count | BIGINT NOT |
| error_code | VARCHAR(40) NULL |
| error_detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| started_at | DATETIME NOT |
| finished_at | DATETIME NULL |
| version | INT NOT |

## Domain group: `step_*`


### `step_up_policy`

| Column | Type |
|---|---|
| action | VARCHAR(30) NOT |
| min_amount | DECIMAL(18,4) NOT |
| enabled | BOOLEAN NOT |

## Domain group: `tax_*`


### `tax_report`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| report_ref | VARCHAR(64) NOT |
| tax_type | ENUM('VAT','INCOME','WITHHOLDING') NOT |
| period | VARCHAR(40) NOT |
| amount | DECIMAL(18,4) NOT |
| currency | CHAR(3) NOT |
| status | ENUM('DRAFT','FILED','PAID','CLOSED') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `tax_report_execution_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| report_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `transfer_*`


### `transfer_reversals`

| Column | Type |
|---|---|
| orig_ref | VARCHAR(50) NOT |
| from_email | VARCHAR(100) NOT |
| actor_id | INT NOT |
| reason | VARCHAR(100) |
| reversed_at | TIMESTAMP DEFAULT |

## Domain group: `treasury_*`


### `treasury_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| position_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `treasury_position`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| currency | CHAR(3) NOT |
| amount | DECIMAL(18,4) NOT |
| as_of_date | DATE NOT |
| status | ENUM('OPEN','CLOSED') NOT |
| detail | VARCHAR(255) NULL |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `users_*`


### `users`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| email | VARCHAR(100) NOT |
| password_hash | VARCHAR(255) NOT |
| full_name | VARCHAR(100) NOT |
| dob | DATE NOT |
| status | ENUM('UNVERIFIED' |
| role | ENUM('USER' |
| token_version | INT NOT |
| failed_logins | INT NOT |
| locked_until | TIMESTAMP NULL |
| last_login_at | TIMESTAMP NULL |
| dormant_notified_at | TIMESTAMP NULL |
| mfa_secret | VARCHAR(64) NULL |
| mfa_enabled | BOOLEAN NOT |
| created_at | TIMESTAMP DEFAULT |
| updated_at | TIMESTAMP DEFAULT |

## Domain group: `velocity_*`


### `velocity_counter`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| account_email | VARCHAR(100) NOT |
| profile_code | VARCHAR(40) NOT |
| window_start | DATETIME NOT |
| used_count | INT NOT |
| used_amount | DECIMAL(30,10) NOT |
| updated_at | TIMESTAMP DEFAULT |

### `velocity_profile`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| profile_code | VARCHAR(40) NOT |
| name | VARCHAR(100) NOT |
| window_seconds | INT NOT |
| max_count | INT NOT |
| max_amount | DECIMAL(30,10) NOT |
| currency_code | CHAR(3) NOT |
| enabled | BOOLEAN NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `vendor_*`


### `vendor`

| Column | Type |
|---|---|
| vendor_code | VARCHAR(40) PRIMARY |
| name | VARCHAR(120) NOT |
| status | ENUM('ACTIVE','INACTIVE') NOT |
| created_by | VARCHAR(100) NOT |
| created_at | TIMESTAMP DEFAULT |

### `vendor_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| vendor_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `vendor_compliance`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| vendor_code | VARCHAR(64) NOT |
| status | ENUM('PENDING','APPROVED') NOT |
| assessed_by | VARCHAR(100) NOT |
| assessed_at | TIMESTAMP DEFAULT |
| approved_by | VARCHAR(100) NULL |
| approved_at | DATETIME NULL |

### `vendor_compliance_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| assessment_id | BIGINT NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

### `vendor_risk`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| vendor_code | VARCHAR(40) NOT |
| risk_level | ENUM('LOW','MEDIUM','HIGH') NOT |
| score | INT NOT |
| assessed_by | VARCHAR(100) NOT |
| assessed_at | TIMESTAMP DEFAULT |

### `vendor_risk_audit`

| Column | Type |
|---|---|
| id | BIGINT AUTO_INCREMENT |
| action | VARCHAR(40) NOT |
| actor_email | VARCHAR(100) NOT |
| vendor_code | VARCHAR(40) NULL |
| detail | VARCHAR(255) |
| created_at | TIMESTAMP DEFAULT |

## Domain group: `verification_*`


### `verification_logs`

| Column | Type |
|---|---|
| id | INT AUTO_INCREMENT |
| email | VARCHAR(100) NOT |
| code | VARCHAR(6) NOT |
| purpose | ENUM('SIGNUP' |
| expires_at | TIMESTAMP NOT |
| is_used | BOOLEAN DEFAULT |
| attempts | INT NOT |
| created_at | TIMESTAMP DEFAULT |
