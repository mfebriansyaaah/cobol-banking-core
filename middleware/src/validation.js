// Whitelist validation. Every parameter that reaches COBOL must match a strict
// regex with no pipe or newline, so it cannot break out of the input line or
// inject a shell argument.

const EMAIL = /^[A-Za-z0-9._%+-]{1,100}@[A-Za-z0-9.-]{1,100}$/;
// COBOL escapes values before embedding, so quotes/backslash/semicolon are fine;
// only the input-line format characters (pipe, newlines) are forbidden.
const PASSWORD = /^[^|\n\r]{1,100}$/;
const NAME = /^[A-Za-z0-9 .'-]{1,100}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const DATERANGE = /^(\d{4}-\d{2}-\d{2})?,(\d{4}-\d{2}-\d{2})?$/;
const CODE = /^\d{6}$/;
const MFA_CODE = /^(\d{6}|\d{10})$/;
const RECOVERY_STATUS = /^(PENDING|VERIFIED|APPROVED|REJECTED)$/;
const DISPUTE_STATUS = /^(OPEN|ACKNOWLEDGED|RESOLVED|REJECTED)$/;
const ROLE = /^(USER|MANAGER|SUPER_ADMIN)$/;
const AMOUNT = /^\d{1,13}(\.\d{1,4})?$/;
const INT = /^\d{1,6}$/;
// Page size is capped as a boundary/resource guard (1..100); COBOL still
// defaults to 20 when limit is omitted.
const LIMIT = /^(100|[1-9]\d?)$/;
const KEY = /^[A-Za-z0-9._:-]{1,50}$/;
const CURRENCY = /^[A-Z]{3}$/;
const SYMBOL = /^[^|\n\r]{1,5}$/;
const FLAG = /^[01]$/;
const REF_CODE = /^[A-Z0-9_-]{1,20}$/;
const REF_TYPE = /^[a-z][a-z0-9_]{1,31}$/;
const REF_VALUE_CODE = /^[A-Za-z0-9_.:-]{1,64}$/;
const REF_LABEL = /^[^|\n\r]{1,128}$/;
const REF_ATTRIBUTES = /^[^|\n\r]{0,255}$/;
const REF_VERSION = /^\d{1,6}$/;
const GL_ACCOUNT = /^[A-Z0-9]{1,20}$/;
const GL_TYPE = /^(ASSET|LIABILITY|EQUITY|REVENUE|EXPENSE)$/;
const GL_SIDE = /^(DEBIT|CREDIT)$/;
const GL_AMOUNT = /^[A-Z]{3}:\d{1,20}(\.\d{1,4})?$/;
const GL_PERIOD = /^\d{4}-(0[1-9]|1[0-2])$/;
const GL_LINES = /^(?=.{1,100}$)[A-Z0-9]{1,20}:\d{1,20}(\.\d{1,4})?:\d{1,20}(\.\d{1,4})?(;[A-Z0-9]{1,20}:\d{1,20}(\.\d{1,4})?:\d{1,20}(\.\d{1,4})?){1,9}$/;
const BATCH_CODE = /^[A-Z0-9_-]{3,40}$/;
const BATCH_NAME = /^[A-Za-z0-9 ._-]{1,100}$/;
const BATCH_TYPE = /^(EOD|INTRADAY|REPORT|CLEANUP)$/;
const BATCH_FREQ = /^(MANUAL|DAILY|WEEKLY|MONTHLY)$/;
const BATCH_TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const BATCH_SCHEDULE = /^([01]\d|2[0-3]):[0-5]\d,\d{1,2},\d{1,5}$/;
const BATCH_STEP_OPTIONS = /^\d{1,2},[01]$/;
const BATCH_STATUS = /^(RUNNING|PAUSED|COMPLETED|FAILED|CANCELLED)$/;
const BATCH_STEP_STATUS = /^(PENDING|RUNNING|COMPLETED|FAILED|SKIPPED)$/;
const BATCH_COUNT = /^\d{1,18}$/;
const BATCH_COUNTS = /^\d{1,18},\d{1,18},\d{1,18}$/;
const BATCH_TOTALS = /^\d{1,20}(\.\d{1,4})?,\d{1,20}(\.\d{1,4})?$/;
const BATCH_DETAIL = /^[A-Za-z0-9 ._:,-]{0,100}$/;
const BATCH_TOTAL_CODE = /^[A-Z0-9_]{2,40}$/;
const RPT_CODE = /^[A-Z0-9_-]{3,40}$/;
const RPT_NAME = /^[A-Za-z0-9 ._'-]{1,100}$/;
const RPT_TYPE = /^(TRIAL_BALANCE|STATEMENT|RECONCILIATION|CUSTOM)$/;
const RPT_FORMAT = /^(CSV|FIXED|JSON)$/;
const RPT_STATUS = /^(RUNNING|COMPLETED|FAILED)$/;
const RPT_ALIGN = /^(LEFT|RIGHT|CENTER)$/;
const RPT_COL_FORMAT = /^(TEXT|AMOUNT|DATE|INTEGER)$/;
const RPT_COLUMN_OPTIONS = /^\d{1,3},(LEFT|RIGHT|CENTER),(TEXT|AMOUNT|DATE|INTEGER)$/;
const RPT_PARAMS = /^[A-Za-z0-9 .,:_-]{1,100}$/;
const RPT_ROW = /^[A-Za-z0-9 .,:_/@+-]{1,100}$/;
const RPT_COUNTS = /^\d{1,18},\d{1,20}(\.\d{1,4})?,\d{1,20}(\.\d{1,4})?$/;
const RPT_CHECKSUM = /^[A-Za-z0-9_-]{0,64}$/;
const RPT_PAGE_SPEC = /^\d{1,3},\d{1,3}$/;
const SCHEDULE_FREQ = /^(DAILY|WEEKLY|MONTHLY)$/;
const SCHEDULE_TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const SCHEDULE_OUTPUT = /^(CSV|FIXED|JSON),[A-Z]{3}$/;
const DSP_PRIORITY = /^(LOW|NORMAL|HIGH|URGENT)$/;
const DSP_SLA_SPEC = /^\d{1,4},\d{1,4}$/;
const EXP_TYPE = /^(REPORT|IMPORT)$/;
const EXP_FORMAT = /^(CSV|FIXED)$/;
const EXP_DAYS = /^\d{1,4}$/;
const RCP_STATUS_FILTER = /^(ANY|OPEN|ACKNOWLEDGED)$/;
const RCP_RULE_SPEC = /^\d{1,3},[01]$/;
const ALT_TYPE = /^[A-Z][A-Z0-9_]{1,31}$/;
const ALT_SEVERITY = /^(INFO|WARNING|CRITICAL)$/;
const ALT_STATE = /^(OPEN|ACKNOWLEDGED|RESOLVED)$/;
const SRC_STATUS = /^(MATCHED|UNMATCHED|MISMATCH)$/;
const AAN_STATUS = /^(SUCCESS|FAILED)$/;
const IRC_STATUS = /^(MATCHED|UNMATCHED|MISMATCH)$/;
const ADR_FILTER = /^[A-Za-z0-9_,:-]{0,200}$/;
const CEX_FRAMEWORK = /^(SOX|GDPR|PCI|AML)$/;
const CEX_ITEM = /^(AUDIT_QUERY|EXPORT_ARCHIVE|REPORT_RUN)$/;
const CEX_STATUS = /^(DRAFT|SEALED|ATTESTED|REVOKED)$/;
const CRT_ENTITY = /^(USER|ACCOUNT|AUDIT|EXPORT)$/;
const RSC_FREQ = /^(DAILY|WEEKLY|MONTHLY)$/;
const RSC_REPORT = /^[A-Z_]{3,40}$/;
const RSC_STATUS = /^(RUNNING|COMPLETED|FAILED)$/;
const STR_STATUS = /^(MATCHED|BREAK|RESOLVED)$/;
const STL_CHANNEL = /^(EMAIL|PORTAL)$/;
const STL_STATUS = /^(QUEUED|SENT|DELIVERED|FAILED)$/;
const KYC_TYPE = /^(ONBOARDING|PERIODIC|ENHANCED)$/;
const KYC_STATUS = /^(PENDING|APPROVED|REJECTED|ESCALATED)$/;
const KYC_RISK = /^(LOW|MEDIUM|HIGH)$/;
const REG_REGULATOR = /^(OJK|BI|PPATK)$/;
const REG_TYPE = /^[A-Z_]{3,40}$/;
const REG_STATUS = /^(DRAFT|SUBMITTED|ACCEPTED|REJECTED)$/;
const XST_TTL = /^\d{1,5}$/;
const XST_LEN = /^\d{1,3}$/;
const XST_OFFSET = /^\d{1,10}$/;
const ALE_SEVERITY = /^(INFO|WARNING|CRITICAL)$/;
const ALE_STEP = /^\d{1,2},\d{1,4},[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+,(EMAIL|PAGE)$/;
const ALE_RUN_STATUS = /^(PENDING|PAGED|ACKED|RESOLVED|FAILED)$/;
const REX_PRIORITY = /^(LOW|NORMAL|HIGH|URGENT)$/;
const REX_STATE = /^(OPEN|ACKNOWLEDGED|IN_PROGRESS|RESOLVED|REJECTED|CLOSED)$/;
const DSN_PURPOSE = /^[A-Z_]{1,32}$/;
const DSN_CHANNEL = /^(EMAIL|INAPP)$/;
const DSN_STATE = /^(PENDING|SENDING|SENT|FAILED|DEAD)$/;
const PIC_AMOUNT = /^\d{1,20}(\.\d{1,2})?,[A-Z]{3}$/;
const PIC_SCHEDULE = /^(ONCE|DAILY|WEEKLY|MONTHLY),\d{4}-\d{2}-\d{2}(,\d{4}-\d{2}-\d{2})?$/;
const ONC_SHIFT = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2},\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/;
const ONC_DATETIME = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/;
const ONC_STEP = /^\d{1,2},\d{1,4},[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+,(EMAIL|PAGE)$/;
const ONC_PAGE_STATUS = /^(PAGED|ACKED|RESOLVED|FAILED)$/;
const IMP_TYPE = /^(LEDGER|ACCOUNTS|REFERENCE|PAYMENTS)$/;
const IMP_STATUS = /^(STAGED|VALIDATING|VALIDATED|COMPLETED|FAILED)$/;
const IMP_RAW = /^[A-Za-z0-9 .,:@_/+\-]{1,100}$/;
const IMP_CHUNK = /^[A-Za-z0-9 .,:@_/+;\-]{1,100}$/;
const FEE_TYPE = /^(FLAT|PERCENT|TIERED)$/;
const FEE_AMOUNTS = /^\d{1,20}(\.\d{1,4})?,\d{1,9}(\.\d{1,6})?,\d{1,20}(\.\d{1,4})?,\d{1,20}(\.\d{1,4})?$/;
const FEE_TIER_OPTIONS = /^\d{1,20}(\.\d{1,4})?,\d{1,9}(\.\d{1,6})?$/;
const VEL_OPTIONS = /^\d{1,7},\d{1,7},\d{1,20}(\.\d{1,4})?,[A-Z]{3}$/;
const EOD_STATUS = /^(OPEN|CLOSED)$/;
const EOD_RUN_STATUS = /^(RUNNING|COMPLETED|FAILED)$/;
const EOD_PHASE_CODE = /^(FEE|HOLD|DORMANT|STATEMENT|RECON)$/;
const EOD_PHASE_STATUS = /^(PENDING|RUNNING|COMPLETED|FAILED|SKIPPED)$/;
const EOD_COUNTS = /^\d{1,18},\d{1,20}(\.\d{1,4})?,\d{1,20}(\.\d{1,4})?$/;
const EOD_TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const RX_TYPE = /^[a-z][a-z0-9_]{1,31}$/;
const RX_CODE = /^[A-Za-z0-9_.:-]{1,64}$/;
const RX_LOCALE = /^[A-Za-z]{2,5}(-[A-Za-z0-9]{2,8})?$/;
const RX_LABEL = /^[A-Za-z0-9 .,:_@-]{1,100}$/;
const RX_FORMAT = /^(CSV|JSON)$/;
const NTF_CHANNEL = /^(EMAIL|INAPP)$/;
const NTF_PURPOSE = /^[A-Z][A-Z0-9_]{1,31}$/;
const NTF_TEXT = /^[A-Za-z0-9 .,:_-]{1,100}$/;
const PAY_POLICY_SPEC = /^\d{1,20}(\.\d{1,4})?,\d{1,20}(\.\d{1,4})?,\d{1,7},\d{1,20}(\.\d{1,4})?,\d{1,3}(\.\d{1,2})?$/;
const PAY_PROFILE_SPEC = /^\d{1,20}(\.\d{1,4})?,\d{1,7}$/;
const REASON = /^[A-Za-z0-9 ._-]{1,100}$/;
const TRIGGER_SRC = /^(MANUAL|SCHEDULED)$/;
const RECON_STATUS = /^(OPEN|ACKNOWLEDGED|RESOLVED)$/;
const OPERATION = /^[A-Z_]{1,30}$/;
const REQUEST_STATUS = /^(PENDING|APPROVED|REJECTED)$/;
const OUTBOX_STATUS = /^(PENDING|SENDING|SENT|FAILED|DEAD)$/;
const USER_STATUS = /^(UNVERIFIED|VERIFIED|SUSPENDED|CLOSED)$/;
// Audit action filter: an upper-case action token (e.g. SET_USER_STATUS).
const AUDIT_ACTION = /^[A-Z][A-Z_]{0,59}$/;
// Access review (ADR 0073): the review state filter and the per-item
// decision a reviewer may record.
const REVIEW_STATE = /^(OPEN|CLOSED)$/;
const REVIEW_DECISION = /^(ATTESTED|REVOKED)$/;

export const PATTERNS = { EMAIL, PASSWORD, NAME, DATE, CODE, ROLE, AMOUNT, INT, LIMIT, KEY, CURRENCY, SYMBOL, FLAG, REF_CODE, REF_TYPE, REF_VALUE_CODE, REF_LABEL, REF_ATTRIBUTES, REF_VERSION, GL_ACCOUNT, GL_TYPE, GL_SIDE, GL_AMOUNT, GL_PERIOD, GL_LINES, BATCH_CODE, BATCH_NAME, BATCH_TYPE, BATCH_FREQ, BATCH_TIME, BATCH_SCHEDULE, BATCH_STEP_OPTIONS, BATCH_STATUS, BATCH_STEP_STATUS, BATCH_COUNT, BATCH_COUNTS, BATCH_TOTALS, BATCH_DETAIL, BATCH_TOTAL_CODE, RPT_CODE, RPT_NAME, RPT_TYPE, RPT_FORMAT, RPT_STATUS, RPT_ALIGN, RPT_COL_FORMAT, RPT_COLUMN_OPTIONS, RPT_PARAMS, RPT_ROW, RPT_COUNTS, RPT_CHECKSUM, RPT_PAGE_SPEC, SCHEDULE_FREQ, SCHEDULE_TIME, SCHEDULE_OUTPUT, DSP_PRIORITY, DSP_SLA_SPEC, EXP_TYPE, EXP_FORMAT, EXP_DAYS, RCP_STATUS_FILTER, RCP_RULE_SPEC, ALT_TYPE, ALT_SEVERITY, ALT_STATE, SRC_STATUS, PIC_AMOUNT, PIC_SCHEDULE, ONC_SHIFT, ONC_DATETIME, ONC_STEP, ONC_PAGE_STATUS, IMP_TYPE, IMP_STATUS, IMP_RAW, IMP_CHUNK, FEE_TYPE, FEE_AMOUNTS, FEE_TIER_OPTIONS, VEL_OPTIONS, EOD_STATUS, EOD_RUN_STATUS, EOD_PHASE_CODE, EOD_PHASE_STATUS, EOD_COUNTS, EOD_TIME, RX_TYPE, RX_CODE, RX_LOCALE, RX_LABEL, RX_FORMAT, NTF_CHANNEL, NTF_PURPOSE, NTF_TEXT, PAY_POLICY_SPEC, PAY_PROFILE_SPEC, REASON, TRIGGER_SRC, RECON_STATUS, REQUEST_STATUS, OUTBOX_STATUS, OPERATION, DATERANGE, DISPUTE_STATUS, MFA_CODE, RECOVERY_STATUS, USER_STATUS, AUDIT_ACTION, REVIEW_STATE, REVIEW_DECISION };

export class ValidationError extends Error {
  constructor(field) {
    super(`invalid parameter: ${field}`);
    this.field = field;
  }
}

// The COBOL entry reads a single PIC X(500) line. Reject any request whose
// composed `ACTION|p1|p2|p3|p4` line would exceed that record (CODING_STANDARDS 13).
export const MAX_INPUT_LINE = 500;

export function assertLineLength(action, params, max = MAX_INPUT_LINE) {
  const line = [action, ...params].join('|');
  if (line.length > max) {
    const err = new ValidationError('input-line');
    err.reason = 'TOO_LONG';
    throw err;
  }
  return line;
}

/** Validate a value against a named pattern; throw ValidationError on failure. */
export function check(value, pattern, field) {
  const v = value ?? '';
  if (!pattern.test(v)) throw new ValidationError(field);
  return v;
}

/**
 * Build the ordered parameter array for an action, validating each present
 * value. Returns [] (all blanks) for actions with no parameters.
 */
export function buildParams(spec, input) {
  return (spec.fields ?? []).map(({ name, pattern, required }) => {
    const value = input[name];
    if (value === undefined || value === '') {
      if (required) throw new ValidationError(name);
      return '';
    }
    return check(String(value), pattern, name);
  });
}
