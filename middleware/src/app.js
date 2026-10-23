import express from 'express';
import helmet from 'helmet';
import { randomUUID } from 'node:crypto';
import { invoke, InvocationTimeout, InvocationError, PoolSaturated } from './invoker.js';
import { toHttp } from './result.js';
import { buildParams, ValidationError, PATTERNS, assertLineLength } from './validation.js';
import { requireAuth, signToken, signRefresh, verifyRefresh, verifyAccess, signStepUp, verifyStepUp, REFRESH_TTL_DAYS, ACCESS_TTL_SECONDS } from './auth.js';
import { rateLimiter, apiRateLimiter } from './rateLimit.js';
import { createRequestObserver, metricsText, recordError, recordAuthFailure } from './observability.js';
import { getPool } from './pool.js';
import { createMailer } from './mailer.js';
import { createTokenStore } from './tokenStore.js';
import { REF_ENGINE_ROUTES } from './routes/ref_engine.js';
import { GL_ROUTES } from './routes/gl.js';
import { BATCH_ROUTES } from './routes/batch.js';
import { REPORT_ROUTES } from './routes/report.js';
import { IMPORT_ROUTES } from './routes/import.js';
import { FEE_ROUTES } from './routes/fee.js';
import { EOD_ROUTES } from './routes/eod.js';
import { STATEMENT_ROUTES } from './routes/statement.js';
import { EOD_JOB_ROUTES } from './routes/eod_jobs.js';
import { REF_EXT_ROUTES } from './routes/ref_ext.js';
import { NOTIFICATION_ROUTES } from './routes/notification.js';
import { PAYMENT_ROUTES } from './routes/payment.js';
import { RECON_ROUTES } from './routes/recon.js';
import { REPORT_DELIVERY_ROUTES } from './routes/report_delivery.js';
import { DISPUTE_OPS_ROUTES } from './routes/dispute_ops.js';
import { EXPORT_ARCHIVE_ROUTES } from './routes/export_archive.js';
import { RECON_OPS_ROUTES } from './routes/recon_ops.js';
import { ALERT_ROUTES } from './routes/alerts.js';
import { DASHBOARD_ROUTES } from './routes/dashboard.js';
import { AUDIT_ANALYTICS_ROUTES } from './routes/audit_analytics.js';
import { IMPORT_RECON_ROUTES } from './routes/import_recon.js';
import { RECON_EXCEPTION_ROUTES } from './routes/recon_exception.js';
import { DISPUTE_NOTIFY_ROUTES } from './routes/dispute_notify.js';
import { EXPORT_STREAM_ROUTES } from './routes/export_stream.js';
import { ALERT_ESCALATION_ROUTES } from './routes/alert_escalation.js';
import { AUDIT_DRILLDOWN_ROUTES } from './routes/audit_drilldown.js';
import { COMPLIANCE_EXPORT_ROUTES } from './routes/compliance_export.js';
import { PAYMENT_HOLD_ROUTES } from './routes/payment_hold.js';
import { ONCALL_DELIVERY_ROUTES } from './routes/oncall_delivery.js';
import { COMPLIANCE_RETENTION_ROUTES } from './routes/compliance_retention.js';
import { LEGAL_HOLD_ROUTES } from './routes/legal_hold.js';
import { KEY_ROTATION_ROUTES } from './routes/key_rotation.js';
import { DSAR_ROUTES } from './routes/dsar.js';
import { RETENTION_JOB_ROUTES } from './routes/retention_job.js';
import { REPORT_SCHEDULER_ROUTES } from './routes/report_scheduler.js';
import { AUDIT_SNAPSHOT_ROUTES } from './routes/audit_snapshot.js';
import { REPORT_ARCHIVE_ROUTES } from './routes/report_archive.js';
import { FRAUD_OPS_ROUTES } from './routes/fraud_ops.js';
import { LBPUE_ROUTES } from './routes/lbpue.js';
import { KYC_REVIEW_ROUTES } from './routes/kyc_review.js';
import { REGULATORY_REPORT_ROUTES } from './routes/regulatory_report.js';
import { LOAN_ROUTES } from './routes/loan.js';
import { DEPOSIT_ROUTES } from './routes/deposit.js';
import { CARD_ROUTES } from './routes/card.js';
import { TAX_REPORT_ROUTES } from './routes/tax_report.js';
import { FEE_WAIVER_ROUTES } from './routes/fee_waiver.js';
import { LIMIT_PROFILE_ROUTES } from './routes/limit_profile.js';
import { GL_REVAL_ROUTES } from './routes/gl_reval.js';
import { GL_PERIOD_CLOSE_ROUTES } from './routes/gl_period_close.js';
import { SANCTIONS_HOLD_ROUTES } from './routes/sanctions_hold.js';
import { KYC_ROUTES } from './routes/kyc.js';
import { RISK_SCREENING_ROUTES } from './routes/risk_screening.js';
import { POLICY_ATTESTATION_ROUTES } from './routes/policy_attestation.js';
import { REGULATORY_CALENDAR_ROUTES } from './routes/regulatory_calendar.js';
import { VENDOR_ROUTES } from './routes/vendor.js';
import { ASSET_ROUTES } from './routes/asset.js';
import { VENDOR_RISK_ROUTES } from './routes/vendor_risk.js';
import { ASSET_MAINTENANCE_ROUTES } from './routes/asset_maintenance.js';
import { BUDGET_ROUTES } from './routes/budget.js';
import { PROCUREMENT_ROUTES } from './routes/procurement.js';
import { FX_DEAL_ROUTES } from './routes/fx_deal.js';
import { TREASURY_POSITION_ROUTES } from './routes/treasury_position.js';
import { SETTLEMENT_RECON_ROUTES } from './routes/settlement_recon.js';
import { STATEMENT_DELIVERY_ROUTES } from './routes/statement_delivery.js';
import { STATEMENT_RECON_ROUTES } from './routes/statement_recon.js';
import { PAYMENT_INSTRUCTION_ROUTES } from './routes/payment_instructions.js';
import { ONCALL_ROUTES } from './routes/oncall.js';
import { SLO_REPORT_ROUTES } from './routes/slo_report.js';
import { PIPELINE_ALERT_ROUTES } from './routes/pipeline_alert.js';
import { INCIDENT_ROUTES } from './routes/incident.js';
import { CHANGE_CONTROL_ROUTES } from './routes/change_control.js';
import { BACKUP_RESTORE_ROUTES } from './routes/backup_restore.js';
import { SECRET_ROTATION_ROUTES } from './routes/secret_rotation.js';
import { DISASTER_RECOVERY_ROUTES } from './routes/disaster_recovery.js';
import { CAPACITY_PLAN_ROUTES } from './routes/capacity_plan.js';
import { AUDIT_RETENTION_ROUTES } from './routes/audit_retention.js';

const { EMAIL, PASSWORD, NAME, DATE, CODE, ROLE, AMOUNT, INT, LIMIT, KEY, CURRENCY, REASON, TRIGGER_SRC, RECON_STATUS, REQUEST_STATUS, OUTBOX_STATUS, OPERATION, DATERANGE, DISPUTE_STATUS, MFA_CODE, RECOVERY_STATUS, USER_STATUS, AUDIT_ACTION, REVIEW_STATE, REVIEW_DECISION } = PATTERNS;

// Reasons counted in gateway_auth_failures_total. Telemetry only: the code
// still decides, this list only decides which failures are worth counting as
// authentication events.
const AUTH_FAILURE_CODES = new Set([
  'INVALID_CREDENTIALS', 'INVALID_MFA', 'MFA_REQUIRED', 'MFA_SETUP_REQUIRED',
  'ACCOUNT_LOCKED', 'USER_SUSPENDED', 'USER_CLOSED', 'UNVERIFIED',
  'SESSION_NOT_FOUND', 'SESSION_EXPIRED', 'SESSION_FAMILY_EXPIRED', 'SESSION_REUSED',
  'TOKEN_REVOKED', 'PERMISSION_DENIED', 'FORBIDDEN', 'ROLE_DENIED',
]);

// Each route maps an HTTP endpoint to a COBOL action. `fields` lists the
// parameters in the exact order the COBOL module expects them. `tokenIdentity`
// names the field filled from the verified token, never from the request body.
export const ROUTES = [
  ...REF_ENGINE_ROUTES,
  ...GL_ROUTES,
  ...BATCH_ROUTES,
  ...REPORT_ROUTES,
  ...IMPORT_ROUTES,
  ...FEE_ROUTES,
  ...EOD_ROUTES,
  ...STATEMENT_ROUTES,
  ...EOD_JOB_ROUTES,
  ...REF_EXT_ROUTES,
  ...NOTIFICATION_ROUTES,
  ...PAYMENT_ROUTES,
  ...RECON_ROUTES,
  ...REPORT_DELIVERY_ROUTES,
  ...DISPUTE_OPS_ROUTES,
  ...EXPORT_ARCHIVE_ROUTES,
  ...RECON_OPS_ROUTES,
  ...ALERT_ROUTES,
  ...DASHBOARD_ROUTES,
  ...AUDIT_ANALYTICS_ROUTES,
  ...IMPORT_RECON_ROUTES,
  ...RECON_EXCEPTION_ROUTES,
  ...DISPUTE_NOTIFY_ROUTES,
  ...EXPORT_STREAM_ROUTES,
  ...ALERT_ESCALATION_ROUTES,
  ...AUDIT_DRILLDOWN_ROUTES,
  ...COMPLIANCE_EXPORT_ROUTES,
  ...PAYMENT_HOLD_ROUTES,
  ...ONCALL_DELIVERY_ROUTES,
  ...COMPLIANCE_RETENTION_ROUTES,
  ...LEGAL_HOLD_ROUTES,
  ...KEY_ROTATION_ROUTES,
  ...DSAR_ROUTES,
  ...RETENTION_JOB_ROUTES,
  ...REPORT_SCHEDULER_ROUTES,
  ...AUDIT_SNAPSHOT_ROUTES,
  ...REPORT_ARCHIVE_ROUTES,
  ...FRAUD_OPS_ROUTES,
  ...LBPUE_ROUTES,
  ...KYC_REVIEW_ROUTES,
  ...REGULATORY_REPORT_ROUTES,
  ...LOAN_ROUTES,
  ...DEPOSIT_ROUTES,
  ...CARD_ROUTES,
  ...TAX_REPORT_ROUTES,
  ...FEE_WAIVER_ROUTES,
  ...LIMIT_PROFILE_ROUTES,
  ...GL_REVAL_ROUTES,
  ...GL_PERIOD_CLOSE_ROUTES,
  ...SANCTIONS_HOLD_ROUTES,
  ...KYC_ROUTES,
  ...RISK_SCREENING_ROUTES,
  ...POLICY_ATTESTATION_ROUTES,
  ...REGULATORY_CALENDAR_ROUTES,
  ...VENDOR_ROUTES,
  ...ASSET_ROUTES,
  ...VENDOR_RISK_ROUTES,
  ...ASSET_MAINTENANCE_ROUTES,
  ...BUDGET_ROUTES,
  ...PROCUREMENT_ROUTES,
  ...FX_DEAL_ROUTES,
  ...TREASURY_POSITION_ROUTES,
  ...SETTLEMENT_RECON_ROUTES,
  ...STATEMENT_DELIVERY_ROUTES,
  ...STATEMENT_RECON_ROUTES,
  ...PAYMENT_INSTRUCTION_ROUTES,
  ...ONCALL_ROUTES,
  ...SLO_REPORT_ROUTES,
  ...PIPELINE_ALERT_ROUTES,
  ...INCIDENT_ROUTES,
  ...CHANGE_CONTROL_ROUTES,
  ...BACKUP_RESTORE_ROUTES,
  ...SECRET_ROTATION_ROUTES,
  ...DISASTER_RECOVERY_ROUTES,
  ...CAPACITY_PLAN_ROUTES,
  ...AUDIT_RETENTION_ROUTES,
  { method: 'post', path: '/auth/signup', action: 'REQUEST_SIGNUP', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
    { name: 'name', pattern: NAME, required: true },
    { name: 'dob', pattern: DATE, required: true },
  ], onSuccess: async () => {
    // Delivery is owned by the outbox worker (transactional enqueue in
    // COBOL); the code is never returned to the client. A neutral response
    // (no code) is sent when the email is already registered.
    return { data: ['USER_CREATED'] };
  } },
  { method: 'post', path: '/auth/verify', action: 'VERIFY_EMAIL', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
  ] },
  { method: 'post', path: '/auth/forgot', action: 'FORGOT_PASSWORD', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
  ], onSuccess: async () => {
    // Neutral: a code is queued only when the account exists.
    return { data: ['CODE_SENT'] };
  } },
  { method: 'post', path: '/auth/reset-password', action: 'RESET_PASSWORD', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
  ] },
  { method: 'post', path: '/auth/resend', action: 'RESEND_VERIFICATION', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
  ], onSuccess: async () => {
    // Neutral: a new code is queued only when an UNVERIFIED account exists.
    return { data: ['CODE_SENT'] };
  } },
  { method: 'post', path: '/auth/login', action: 'AUTH_LOGIN', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
    { name: 'mfaCode', pattern: MFA_CODE, required: false },
  ], onSuccess: async (body, input, { req }) => {
    const ver = await tokenVersion(input.email);
    const issued = signRefresh({ email: input.email });
    const ua = sanitizeMeta(req && req.headers && req.headers['user-agent'], 120);
    const ip = sanitizeMeta(req && req.ip, 45);
    await invoke('STORE_SESSION', [issued.jti, input.email, String(REFRESH_TTL_DAYS), issued.jti, ua, ip]);
    // Announce a first sign-in from this fingerprint. Best effort: the login
    // must not fail because the notice could not be queued.
    try { await invoke('LOGIN_NOTICE', [input.email, ua, ip]); } catch { /* best effort */ }
    // Whether an admin without MFA must enrol next is decided by COBOL; the
    // gateway forwards the flag without reimplementing the admin-role rule.
    const enroll = (await invoke('MFA_ENROLL_REQUIRED', [input.email])) === 'SUCCESS|1';
    return {
      ...body,
      token: signToken({ email: input.email, ver, jti: randomUUID(), sid: issued.jti }),
      refreshToken: issued.token,
      mfaEnrollmentRequired: enroll,
      permissions: await listPermissions(input.email),
    };
  } },

  // Step-up: re-verify the caller's own credentials and mint a short-lived
  // proof required by privileged admin actions. Bearer-authenticated.
  { method: 'post', path: '/auth/step-up', action: 'VERIFY_REAUTH', tokenIdentity: 'email', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
    { name: 'mfaCode', pattern: MFA_CODE, required: false },
  ], onSuccess: async (body, input) => {
    const ver = await tokenVersion(input.email);
    return { data: ['STEP_UP_OK'], stepUpToken: signStepUp({ email: input.email, ver }) };
  } },

  { method: 'get', path: '/users', action: 'LIST_USERS', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: false },
  ], onSuccess: async (body) => {
    // data: ['LIST_DONE', total, 'id:email:name:role:status;...']
    const total = Number(body.data[1]);
    const users = String(body.data[2] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [id, email, name, role, status] = row.split(':');
        return { id, email, name, role, status };
      });
    return { data: ['USERS'], total, users };
  } },
  { method: 'get', path: '/users/:email', action: 'GET_USER', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body) => {
    // data: ['USER', id, email, name, status, role, createdAt]
    const [id, email, name, status, role, createdAt] = body.data.slice(1);
    return { data: ['USER'], user: { id, email, name, status, role, createdAt } };
  } },
  { method: 'get', path: '/wallet/balance', action: 'CHECK_BALANCE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body) => {
    // Every account, parsed from "iso:balance:available:status" rows.
    const balances = String(body.data[1] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [currency, balance, available, status] = row.split(':');
        return { currency, balance, available, status };
      });
    return { data: ['BALANCES'], balances };
  } },
  { method: 'get', path: '/statements', action: 'STATEMENT', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'currency', pattern: CURRENCY, required: true },
    { name: 'range', pattern: DATERANGE, required: false },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ], onSuccess: async (body) => {
    // One row per posting: id, posting/value dates, ref, source, side,
    // amount, balance after the row, reversal flag, description.
    const rows = String(body.data[5] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [id, postedAt, valueDate, ref, source, side, amount, balanceAfter, reversed, ...desc] = row.split(':');
        return { id, postedAt, valueDate, ref, source, side, amount, balanceAfter, reversed: reversed === '1', description: desc.join(':') };
      });
    return { data: ['STATEMENT'], opening: body.data[1], closing: body.data[2], currency: body.data[3], total: body.data[4], lines: rows };
  } },
  { method: 'post', path: '/disputes', action: 'OPEN_DISPUTE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'subject', pattern: REASON, required: true },
    { name: 'detail', pattern: REASON, required: true },
    { name: 'ref', pattern: KEY, required: false },
  ], onSuccess: async (body) => {
    return { data: ['DISPUTE_OPENED'], caseId: body.data[1] };
  } },
  { method: 'post', path: '/disputes/:id/notes', action: 'ADD_DISPUTE_NOTE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'body', pattern: REASON, required: true },
  ] },
  { method: 'post', path: '/disputes/:id/acknowledge', action: 'ACK_DISPUTE', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'id', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'due', pattern: DATE, required: false },
  ] },
  { method: 'post', path: '/disputes/:id/resolve', action: 'RESOLVE_DISPUTE', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'id', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'resolution', pattern: REASON, required: true },
  ] },
  { method: 'post', path: '/disputes/:id/reject', action: 'REJECT_DISPUTE', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'id', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'reason', pattern: REASON, required: true },
  ] },
  { method: 'get', path: '/disputes', action: 'LIST_DISPUTES', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'email', pattern: EMAIL, required: false },
    { name: 'status', pattern: DISPUTE_STATUS, required: false },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ], onSuccess: async (body) => {
    // One row per case: id, owner, subject, state, due date, overdue flag, opened date.
    const cases = String(body.data[2] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [caseId, email, subject, state, due, overdue, created] = row.split(':');
        return { caseId, email, subject, state, due, overdue: overdue === '1', created };
      });
    return { data: ['DISPUTES'], total: body.data[1], cases };
  } },
  { method: 'get', path: '/disputes/:id', action: 'GET_DISPUTE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body) => {
    const [caseId, email, ref, subject, detail, state, assignee, due, overdue, created, resolution] = String(body.data[1] || '').split(':');
    const messages = String(body.data[3] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [msgId, author, msgBody, sentAt] = row.split(':');
        return { msgId, author, body: msgBody, sentAt };
      });
    return { data: ['DISPUTE'], case: { caseId, email, ref, subject, detail, state, assignee, due, overdue: overdue === '1', created, resolution }, total: body.data[2], messages };
  } },
  { method: 'post', path: '/wallet/transfer', action: 'TRANSFER', tokenIdentity: 'from', stepUpPolicy: 'TRANSFER', fields: [
    { name: 'from', pattern: EMAIL, required: true },
    { name: 'to', pattern: EMAIL, required: true },
    { name: 'amount', pattern: AMOUNT, required: true },
    { name: 'idempotencyKey', pattern: KEY, required: true },
    { name: 'fromCurrency', pattern: CURRENCY, required: false },
    { name: 'toCurrency', pattern: CURRENCY, required: false },
  ] },
  { method: 'get', path: '/transactions/:ref', action: 'TX_STATUS', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: KEY, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'sender', pattern: EMAIL, required: false },
  ] },
  { method: 'post', path: '/transactions/:ref/reverse', action: 'REVERSE_TRANSFER', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'ref', pattern: KEY, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'sender', pattern: EMAIL, required: false },
    { name: 'reason', pattern: REASON, required: true },
  ] },

  { method: 'get', path: '/profile', action: 'GET_DASHBOARD', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body) => {
    // data: ['DASHBOARD', email, name, status, role, dob, createdAt, accounts]
    const [email, name, status, role, dob, createdAt, accounts = ''] = body.data.slice(1);
    const balances = accounts
      ? accounts.split(';').map((row) => {
          const [currency, balance, available, status] = row.split(':');
          return { currency, balance, available, status };
        })
      : [];
    return { data: ['PROFILE'], profile: { email, name, status, role, dob, createdAt }, accounts: balances, permissions: await listPermissions(email) };
  } },
  { method: 'patch', path: '/profile', action: 'UPDATE_PROFILE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'name', pattern: NAME, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'dob', pattern: DATE, required: false },
  ] },
  { method: 'post', path: '/profile/deactivate', action: 'DEACTIVATE_ACCOUNT', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  // Dormant account lifecycle (ADR 0080): flag, suspend after the grace
  // window, and reactivate. SUPER_ADMIN only; the core reads the policy.
  { method: 'post', path: '/admin/dormancy/mark', action: 'MARK_DORMANT', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/dormancy/suspend', action: 'SUSPEND_DORMANT', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/dormancy/reactivate', action: 'REACTIVATE_DORMANT', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/user-status', action: 'SET_USER_STATUS', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'status', pattern: USER_STATUS, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/unlock', action: 'UNLOCK_USER', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/mfa-reset', action: 'ADMIN_RESET_MFA', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/holds', action: 'PLACE_HOLD', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'amount', pattern: AMOUNT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'days', pattern: INT, required: false },
    { name: 'currency', pattern: CURRENCY, required: false },
    { name: 'reason', pattern: REASON, required: false },
  ] },
  { method: 'post', path: '/admin/holds/release', action: 'RELEASE_HOLD', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'holdId', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/profile/email/request', action: 'REQ_EMAIL_CHANGE', tokenIdentity: 'actor', stepUpPolicy: 'REQ_EMAIL_CHANGE', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'newEmail', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
  ], onSuccess: async () => {
    // Neutral: a code is queued only when the new address is free.
    return { data: ['CODE_SENT'] };
  } },
  { method: 'post', path: '/profile/email/confirm', action: 'CONFIRM_EMAIL_CHANGE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'newEmail', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async () => {
    // The abandoned address is notified through the outbox.
    return { data: ['EMAIL_CHANGED'] };
  } },
  { method: 'post', path: '/profile/password', action: 'CHANGE_PASSWORD', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'currentPassword', pattern: PASSWORD, required: true },
    { name: 'newPassword', pattern: PASSWORD, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/mfa/backup-codes', action: 'MFA_BACKUP_CODES', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body) => {
    return { data: ['BACKUP_CODES'], codes: String(body.data[1] || '').split(',').filter(Boolean) };
  } },
  { method: 'post', path: '/mfa/recover', action: 'REQUEST_MFA_RECOVERY', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
  ] },
  { method: 'post', path: '/mfa/recover/confirm', action: 'VERIFY_MFA_RECOVERY', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
  ] },
  { method: 'post', path: '/admin/mfa-recovery/approve', action: 'APPROVE_MFA_RECOVERY', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'requestId', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/mfa-recovery/reject', action: 'REJECT_MFA_RECOVERY', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'requestId', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'get', path: '/admin/mfa-recovery', action: 'LIST_MFA_RECOVERY', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'status', pattern: RECOVERY_STATUS, required: false },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ] },
  { method: 'post', path: '/mfa/enroll', action: 'MFA_ENROLL_BEGIN', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body, input) => {
    // The secret is shown once so the user can add it to their authenticator.
    const secret = body.data[1];
    const issuer = process.env.MFA_ISSUER || 'CobolBank';
    const label = encodeURIComponent(`${issuer}:${input.email}`);
    const otpauth = `otpauth://totp/${label}?secret=${secret}&issuer=${encodeURIComponent(issuer)}&algorithm=SHA1&digits=6&period=30`;
    return { data: ['MFA_SECRET'], secret, otpauth };
  } },
  { method: 'post', path: '/mfa/confirm', action: 'MFA_ENROLL_CONFIRM', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/mfa/disable', action: 'MFA_DISABLE', tokenIdentity: 'actor', stepUpPolicy: 'MFA_DISABLE', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'get', path: '/sessions', action: 'LIST_SESSIONS', tokenIdentity: 'actor', tokenSid: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'sid', pattern: KEY, required: false },
  ] },
  { method: 'post', path: '/sessions/revoke', action: 'REVOKE_USER_SESSION', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'sessionId', pattern: KEY, required: true },
  ] },
  { method: 'post', path: '/sessions/revoke-all', action: 'REVOKE_ALL_SESSIONS', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  // Sign out every other device, keeping the caller's own session family.
  { method: 'post', path: '/sessions/revoke-others', action: 'REVOKE_OTHER_DEVICES', tokenIdentity: 'actor', tokenSid: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'sid', pattern: KEY, required: true },
  ] },
  { method: 'get', path: '/admin/role', action: 'CHECK_ROLE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  // Read-only consistency check: every account balance against its ledger sum.
  // Requires a SUPER_ADMIN actor, taken from the verified token (not the body).
  { method: 'get', path: '/admin/reconcile', action: 'RECONCILE', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  // Recorded reconciliation: same check, but the run and its findings are
  // stored immutably for ownership, resolution, and export.
  { method: 'post', path: '/admin/reconcile/run', action: 'RUN_RECONCILIATION', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'trigger', pattern: TRIGGER_SRC, required: false },
  ] },
  { method: 'get', path: '/admin/reconcile/runs', action: 'LIST_RECONCILIATIONS', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ] },
  { method: 'get', path: '/admin/reconcile/exceptions', action: 'LIST_EXCEPTIONS', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'status', pattern: RECON_STATUS, required: false },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ] },
  { method: 'post', path: '/admin/reconcile/acknowledge', action: 'ACK_EXCEPTION', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'findingId', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'get', path: '/admin/outbox', action: 'LIST_OUTBOX', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'status', pattern: OUTBOX_STATUS, required: false },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ] },
  { method: 'post', path: '/admin/reconcile/resolve', action: 'RESOLVE_EXCEPTION', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'findingId', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'note', pattern: REASON, required: false },
  ] },
  { method: 'post', path: '/admin/requests', action: 'REQUEST_OPERATION', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'operation', pattern: OPERATION, required: true },
    { name: 'target', pattern: EMAIL, required: true },
    { name: 'detail', pattern: KEY, required: false },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/requests/approve', action: 'APPROVE_REQUEST', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'requestId', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/requests/reject', action: 'REJECT_REQUEST', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'requestId', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'get', path: '/admin/requests', action: 'LIST_REQUESTS', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'status', pattern: REQUEST_STATUS, required: false },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ] },
  { method: 'post', path: '/admin/role', action: 'CHANGE_ROLE', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/audit/archive', action: 'ARCHIVE_AUDIT', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'days', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  // Read-only audit trail (SUPER_ADMIN): optional action/email filters + paging.
  // Access review (ADR 0073): a SUPER_ADMIN opens a review, records a
  // decision per privileged account, and closes it once every item is
  // decided and every revoked access is actually gone.
  { method: 'post', path: '/admin/access-reviews', action: 'OPEN_ACCESS_REVIEW', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'periodStart', pattern: DATE, required: true },
    { name: 'periodEnd', pattern: DATE, required: true },
  ], onSuccess: async (body) => {
    return { data: ['REVIEW_OPENED'], reviewId: body.data[1], itemCount: Number(body.data[2]) };
  } },
  { method: 'get', path: '/admin/access-reviews', action: 'LIST_ACCESS_REVIEWS', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'state', pattern: REVIEW_STATE, required: false },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ], onSuccess: async (body) => {
    const total = Number(body.data[1]);
    const reviews = String(body.data[2] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [id, periodStart, periodEnd, state, openedBy, itemCount, closedBy, closedAt] = row.split(':');
        return { id, periodStart, periodEnd, state, openedBy, itemCount: Number(itemCount), closedBy, closedAt };
      });
    return { data: ['REVIEWS'], total, reviews };
  } },
  { method: 'get', path: '/admin/access-reviews/:id', action: 'GET_ACCESS_REVIEW', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'id', pattern: INT, required: true },
  ], onSuccess: async (body) => {
    const [id, periodStart, periodEnd, state, openedBy, closedBy, closedAt, itemRows] = body.data.slice(1);
    const items = String(itemRows || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [itemId, email, role, status, mfaEnabled, decision, reviewer, lastLoginAt, note] = row.split(':');
        return {
          itemId,
          email,
          role,
          status,
          mfaEnabled: mfaEnabled === '1',
          decision,
          reviewer,
          lastLoginAt,
          note,
        };
      });
    return {
      data: ['REVIEW'],
      review: { id, periodStart, periodEnd, state, openedBy, closedBy, closedAt },
      items,
    };
  } },
  { method: 'post', path: '/admin/access-review-items/:itemId/decide', action: 'DECIDE_ACCESS_ITEM', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'itemId', pattern: INT, required: true },
    { name: 'decision', pattern: REVIEW_DECISION, required: true },
    { name: 'note', pattern: REASON, required: false },
  ], onSuccess: async (body) => {
    return { data: ['ITEM_DECIDED'], itemId: body.data[1], decision: body.data[2] };
  } },
  { method: 'post', path: '/admin/access-reviews/:id/close', action: 'CLOSE_ACCESS_REVIEW', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'id', pattern: INT, required: true },
  ], onSuccess: async (body) => {
    return { data: ['REVIEW_CLOSED'], reviewId: body.data[1] };
  } },
  { method: 'get', path: '/admin/audit', action: 'LIST_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'action', pattern: AUDIT_ACTION, required: false },
    { name: 'email', pattern: EMAIL, required: false },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ] },
];

// Keep client-supplied session metadata to safe, bounded text: strip control
// characters and the input-line/column separators (| and ;) so a user-agent
// cannot corrupt the session-list row format, and cap the length.
function sanitizeMeta(value, max) {
  return String(value || '')
    .replace(/[^\x20-\x7E]/g, '')
    .replace(/[|;]/g, '_')
    .slice(0, max);
}

// The permissions an account holds, for clients to render. Authorization
// itself stays in COBOL; this is a read-only projection, never a decision.
async function listPermissions(email) {
  try {
    const raw = await invoke('LIST_PERMISSIONS', [email]);
    if (!raw.startsWith('SUCCESS|PERMISSIONS')) return [];
    const rows = raw.split('|')[2] || '';
    return rows ? rows.split(';').filter(Boolean) : [];
  } catch {
    return [];
  }
}

async function tokenVersion(email) {
  try {
    const raw = await invoke('GET_TOKEN_VERSION', [email]);
    const v = Number(String(raw).split('|')[1]);
    return Number.isFinite(v) ? v : 1;
  } catch {
    return 1;
  }
}

// The access token carries the user's token version and its own jti; a mismatch
// (or a denylisted jti) means it was revoked since it was issued.
export function buildRouter({ mailer, tokenStore } = {}) {
  const router = express.Router();
  const authLimiter = rateLimiter();
  const apiLimiter = apiRateLimiter();

  const requireActiveToken = async (req, res, next) => {
    try {
      const u = req.user || {};
      const ok = await tokenStore.isActive({ email: u.email || '', ver: u.ver, jti: u.jti });
      if (ok) return next();
      return res.status(401).json({ error: 'TOKEN_REVOKED' });
    } catch (err) {
      return next(err);
    }
  };

  // Permission gate for operator-only endpoints (checked live in COBOL).
  // CHECK_PERMISSION answers whether the actor holds the permission, so a
  // future grant to another role needs no gateway change.
  const requirePermission = (permission) => async (req, res, next) => {
    try {
      const email = (req.user && req.user.email) || '';
      const raw = await invoke('CHECK_PERMISSION', [email, permission]);
      if (raw === 'SUCCESS|PERMISSION_OK') return next();
      if (raw === 'ERROR|ACCOUNT_NOT_FOUND') return res.status(404).json({ error: 'ACCOUNT_NOT_FOUND' });
      recordAuthFailure('PERMISSION_DENIED');
      return res.status(403).json({ error: 'FORBIDDEN' });
    } catch (err) {
      return next(err);
    }
  };

  // Verify a fresh, short-lived step-up proof (from POST /auth/step-up) bound
  // to this caller and its token version. Returns true when it is valid;
  // otherwise it has already written the 401.
  const stepUpProofValid = (req, res) => {
    const token = req.get('x-step-up') || (req.body && req.body.stepUpToken) || '';
    if (!token) {
      recordAuthFailure('STEP_UP_REQUIRED');
      res.status(401).json({ error: 'STEP_UP_REQUIRED' });
      return false;
    }
    let payload;
    try {
      payload = verifyStepUp(token);
    } catch {
      res.status(401).json({ error: 'STEP_UP_REQUIRED' });
      return false;
    }
    const u = req.user || {};
    if (payload.email !== u.email || String(payload.ver) !== String(u.ver)) {
      res.status(401).json({ error: 'STEP_UP_REQUIRED' });
      return false;
    }
    return true;
  };

  // Static gate for privileged admin writes (always required).
  const requireStepUp = (req, res, next) => {
    if (!stepUpProofValid(req, res)) return undefined;
    return next();
  };

  // Risk-based gate for customer actions: COBOL's STEP_UP_REQUIRED reads the
  // owner-controlled policy and decides; the gateway only enforces the answer.
  const requireStepUpPolicy = (action) => async (req, res, next) => {
    try {
      const email = (req.user && req.user.email) || '';
      const amount = (req.body && req.body.amount) ?? (req.query && req.query.amount) ?? '';
      const raw = await invoke('STEP_UP_REQUIRED', [email, action, String(amount)]);
      if (raw === 'SUCCESS|STEP_UP_REQUIRED') {
        if (!stepUpProofValid(req, res)) return undefined;
        return next();
      }
      if (raw.startsWith('ERROR')) {
        recordAuthFailure('STEP_UP_POLICY_FAILED');
        return res.status(500).json({ error: 'STEP_UP_POLICY_FAILED' });
      }
      return next();
    } catch (err) {
      return next(err);
    }
  };

  // Deep health: confirm the COBOL core can reach the database. Rate-limited:
  // it is public and performs a COBOL/DB round-trip, so it must not be an
  // anonymous amplification vector.
  router.get('/health', apiLimiter, async (_req, res) => {
    const t0 = Date.now();
    try {
      const raw = await invoke('PING', []);
      const ms = Date.now() - t0;
      res.set('X-Cobol-Ms', String(ms));
      if (raw === 'SUCCESS|PONG') {
        return res.json({ status: 'ok', db: 'up', data: ['PONG'] });
      }
      return res.status(503).json({ status: 'degraded', db: 'down' });
    } catch {
      res.set('X-Cobol-Ms', String(Date.now() - t0));
      return res.status(503).json({ status: 'degraded', db: 'down' });
    }
  });

  // Liveness: the process is up. No dependencies — never flaps on a DB blip.
  router.get('/live', (_req, res) => res.json({ status: 'alive' }));

  // Readiness: dependencies usable (DB reachable, pool has a worker when
  // pooling is on). Public like a readiness probe must be, so it is
  // rate-limited and its result is cached for a short window (PROBE_CACHE_MS)
  // to bound the DB round-trips an anonymous caller can trigger.
  let readyCache = null; // { at, status, body }
  router.get('/ready', apiLimiter, async (_req, res) => {
    const ttl = Number(process.env.PROBE_CACHE_MS || 1000);
    const now = Date.now();
    if (readyCache && now - readyCache.at < ttl) {
      return res.status(readyCache.status).json(readyCache.body);
    }
    const checks = {};
    try {
      const raw = await invoke('PING', []);
      checks.db = raw === 'SUCCESS|PONG' ? 'up' : 'down';
    } catch {
      checks.db = 'down';
    }
    const pool = getPool();
    checks.pool = pool ? (pool.stats().size > 0 ? 'up' : 'down') : 'off';
    // Informational only: delivery is best-effort, so a missing SMTP does not
    // make the instance unready — but it is surfaced here.
    checks.mailer = process.env.SMTP_HOST ? 'configured' : 'unset';
    const ok = checks.db === 'up' && checks.pool !== 'down';
    const status = ok ? 200 : 503;
    const body = { status: ok ? 'ready' : 'not_ready', checks };
    readyCache = { at: now, status, body };
    return res.status(status).json(body);
  });

  // Prometheus-style counters (support only). Authenticated to keep the
  // surface closed; scrapers send a bearer token.
  router.get('/metrics', apiLimiter, requireAuth, requireActiveToken, requirePermission('AUDIT_READ'), (_req, res) => {
    res.type('text/plain').send(metricsText());
  });

  // Pure transport: exchange a refresh token for a new access token. The old
  // refresh token is consumed atomically; a replay is detected as reuse.
  router.post('/auth/refresh', authLimiter, async (req, res) => {
    try {
      const payload = verifyRefresh((req.body && req.body.refreshToken) || '');
      const consume = await invoke('CONSUME_SESSION', [payload.jti || '']);
      if (consume !== 'SUCCESS|SESSION_CONSUMED') {
        return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
      }
      const family = payload.family || payload.jti;
      const ver = await tokenVersion(payload.email);
      const issued = signRefresh({ email: payload.email, family });
      const ua = sanitizeMeta(req.headers && req.headers['user-agent'], 120);
      const ip = sanitizeMeta(req.ip, 45);
      await invoke('STORE_SESSION', [issued.jti, payload.email, String(REFRESH_TTL_DAYS), family, ua, ip]);
      try { await invoke('LOGIN_NOTICE', [payload.email, ua, ip]); } catch { /* best effort */ }
      const enroll = (await invoke('MFA_ENROLL_REQUIRED', [payload.email])) === 'SUCCESS|1';
      return res.json({
        data: ['REFRESHED'],
        token: signToken({ email: payload.email, ver, jti: randomUUID(), sid: family }),
        refreshToken: issued.token,
        mfaEnrollmentRequired: enroll,
      });
    } catch {
      return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
    }
  });

  // Per-device logout: revoke the presented refresh session and, when the
  // bearer is also presented, deny that access token. Other devices are
  // unaffected — use POST /sessions/revoke-all to log out everywhere.
  router.post('/auth/logout', authLimiter, async (req, res) => {
    try {
      const payload = verifyRefresh((req.body && req.body.refreshToken) || '');
      await invoke('REVOKE_SESSION', [payload.jti || '']);
      const header = req.headers.authorization || '';
      const [scheme, token] = header.split(' ');
      if (scheme === 'Bearer' && token) {
        const u = verifyAccess(token);
        if (u && u.jti) {
          await tokenStore.revoke({ jti: u.jti, email: u.email, ttlSeconds: ACCESS_TTL_SECONDS });
        }
      }
      return res.json({ data: ['LOGGED_OUT'] });
    } catch {
      return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
    }
  });

  // Revoke just the presented access token (per-token denylist), leaving other
  // sessions of the same user valid.
  router.post('/auth/revoke', apiLimiter, requireAuth, requireActiveToken, async (req, res, next) => {
    try {
      await tokenStore.revoke({ jti: req.user.jti, email: req.user.email, ttlSeconds: ACCESS_TTL_SECONDS });
      return res.json({ data: ['TOKEN_REVOKED'] });
    } catch (err) {
      return next(err);
    }
  });

  for (const route of ROUTES) {
    const handler = async (req, res, next) => {
      try {
        const input = { ...req.params, ...req.query, ...req.body };
        if (req.headers['idempotency-key']) {
          input.idempotencyKey = req.headers['idempotency-key'];
        }
        // Identity fields (actor, or the transfer sender) trust the token only.
        if (route.tokenIdentity) {
          input[route.tokenIdentity] = (req.user && req.user.email) || '';
        }
        // Session ids ("sid") are the token's refresh-session family; used to
        // mark the caller's own session in the list.
        if (route.tokenSid) {
          input.sid = (req.user && req.user.sid) || '';
        }
        const params = buildParams(route, input);
        assertLineLength(route.action, params);
        const t0 = Date.now();
        const raw = await invoke(route.action, params);
        res.set('X-Cobol-Ms', String(Date.now() - t0));
        const { status, body } = toHttp(raw);
        if (status !== 200 && body && body.error) {
          res.locals.errorCode = body.error;
          recordError(body.error);
          if (AUTH_FAILURE_CODES.has(body.error)) recordAuthFailure(body.error);
        }
        if (status === 200 && route.onSuccess) {
          return res.status(status).json(await route.onSuccess(body, input, { mailer, req }));
        }
        return res.status(status).json(body);
      } catch (err) {
        return next(err);
      }
    };
    const chain = [];
    if (route.path.startsWith('/auth')) chain.push(authLimiter);
    else chain.push(apiLimiter);
    if (!route.public) chain.push(requireAuth);
    if (!route.public) chain.push(requireActiveToken);
    if (route.stepUp) chain.push(requireStepUp);
    else if (route.stepUpPolicy) chain.push(requireStepUpPolicy(route.stepUpPolicy));
    chain.push(handler);
    router[route.method](route.path, ...chain);
  }

  return router;
}

// Advisory misconfiguration check for the rate-limit key: TRUST_PROXY=true
// trusts any X-Forwarded-For header and lets callers spoof their key (the
// limiter is bypassed). An unset value is sound: loopback-only trust keeps a
// directly exposed socket on its real peer IP. Returns a warning message, or
// null when the setting looks sound.
export function trustProxyWarning() {
  const v = process.env.TRUST_PROXY;
  if (v === 'true') {
    return 'TRUST_PROXY=true trusts any X-Forwarded-For header, letting callers spoof the rate-limit key (use a hop count or subnet instead)';
  }
  return null;
}

export function buildApp({ logger = null, mailer = null, tokenStore = null } = {}) {
  const app = express();
  // Behind a proxy the client IP (and so the rate-limit key) must come from the
  // forwarded headers. Loopback-only unless configured: a same-host proxy is
  // trusted, a remote X-Forwarded-For is not (spoof-proof), and a directly
  // exposed socket keeps its real peer IP. Set TRUST_PROXY to the hop count
  // when the proxy lives on another host.
  app.set('trust proxy', process.env.TRUST_PROXY || 'loopback');
  app.use(helmet());
  app.use(createRequestObserver({ logger }));
  // Legitimate bodies are under a kilobyte (short credential/profile fields);
  // reject anything larger before it costs parsing memory or reaches COBOL.
  app.use(express.json({ limit: process.env.JSON_BODY_LIMIT || '20kb' }));
  app.use(buildRouter({ mailer: mailer || createMailer({ logger }), tokenStore: tokenStore || createTokenStore() }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    let status = 500;
    let code = 'INTERNAL';
    if (err instanceof ValidationError) {
      status = 400;
      code = 'INVALID_PARAMETER';
    } else if (err instanceof InvocationTimeout) {
      status = 504;
      code = 'GATEWAY_TIMEOUT';
    } else if (err instanceof PoolSaturated) {
      status = 503;
      code = 'POOL_SATURATED';
    } else if (err instanceof InvocationError) {
      status = 502;
      code = 'COBOL_UNAVAILABLE';
    } else if (err.status === 413 || err.type === 'entity.too.large') {
      status = 413;
      code = 'BODY_TOO_LARGE';
    }
    res.locals.errorCode = code;
    recordError(code);
    if (logger) {
      logger({
        ts: new Date().toISOString(),
        level: 'error',
        event: 'gateway_error',
        code,
        status,
        message: err && err.message,
        stack: err && err.stack,
      });
    }
    if (err instanceof ValidationError) {
      return res.status(status).json({ error: code, field: err.field });
    }
    return res.status(status).json({ error: code });
  });
  return app;
}
