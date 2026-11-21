// Response mappers: transform a successful COBOL result line into the
// HTTP response body. Pure presentation only: no direct COBOL invoke, no
// token signing, no SQL. Session/token side effects live in authService.js;
// the two session mappers below delegate to it so all orchestration stays
// in one gateway service module.
import { completeLogin, completeStepUp, listPermissions } from './authService.js';
import { completeIssue } from '../adapters/otp.js';
import { isV1 } from './envelope.js';

/**
 * Page metadata for v1 list responses (arch9 WP-14). `total` is the COBOL
 * COUNT(*) when the output carries one, else null (never the page size:
 * COBOL honors LIMIT/OFFSET, so rows.length would lie). limit/offset echo
 * the request with the COBOL-conventional defaults (20/0).
 */
export function pageMeta(input, total) {
  const n = total === null || total === undefined || total === '' ? NaN : Number(total);
  const limit = Number(input && input.limit);
  const offset = Number(input && input.offset);
  return {
    total: Number.isFinite(n) ? n : null,
    limit: Number.isFinite(limit) && limit > 0 ? limit : 20,
    offset: Number.isFinite(offset) && offset >= 0 ? offset : 0,
  };
}

/**
 * Rows-or-"0" COBOL list payloads (ACC/LOAN/DEP/CARD lists answer
 * `SUCCESS|TAG|<rows>` or `SUCCESS|TAG|0` with no total). Shared so every
 * domain list treats the empty page identically.
 */
function listRows(body, index, shape, context) {
  const raw = body && body.data && body.data[index];
  if (!raw || String(raw).trim() === '' || String(raw).trim() === '0') return [];
  return splitRows(raw, { min: shape, context });
}

/**
 * Split a multi-row COBOL field into rows of fields. COBOL packs rows with
 * ';' inside one pipe field and fields with ':'; a short row means the
 * output was truncated or reshaped upstream, so throw instead of returning
 * a misaligned object (the error middleware turns it into a 500).
 */
export function splitRows(value, { rowSep = ';', fieldSep = ':', min = 1, context = 'row' } = {}) {
  return String(value || '')
    .split(rowSep)
    .filter(Boolean)
    .map((row) => {
      const fields = row.split(fieldSep);
      if (fields.length < min) {
        throw new Error(`invalid ${context}: expected at least ${min} fields, got ${fields.length}`);
      }
      return fields;
    });
}

/**
 * Assert an exact field count for fixed-shape rows (every field is
 * allowlisted without ':' at the source: emails, ISO codes, enums, amounts).
 * Free-text rows (statement descriptions) use splitRows min + rest-join.
 */
export function assertFieldCount(fields, count, context) {
  if (fields.length !== count) {
    throw new Error(`invalid ${context}: expected ${count} fields, got ${fields.length}`);
  }
  return fields;
}

export const RESPONSE_MAPPERS = {
  REQUEST_SIGNUP: async () => {
    // Delivery is owned by the outbox worker (transactional enqueue in
    // COBOL); the code is never returned to the client. A neutral response
    // (no code) is sent when the email is already registered.
    return { data: ['USER_CREATED'] };
  },
  FORGOT_PASSWORD: async () => {
    // Neutral: a code is queued only when the account exists.
    return { data: ['CODE_SENT'] };
  },
  RESEND_VERIFICATION: async () => {
    // Neutral: a new code is queued only when an UNVERIFIED account exists.
    return { data: ['CODE_SENT'] };
  },
  AUTH_LOGIN: async (body, input, { req }) => completeLogin(body, input, { req }),
  VERIFY_REAUTH: async (body, input) => completeStepUp(input),
  OTP_ISSUE: async (body, input) => completeIssue(body, input),
  LIST_USERS: async (body, input, { req } = {}) => {
    // data: ['LIST_DONE', total, 'id:email:name:role:status;...']
    const total = Number(body.data[1]);
    const users = splitRows(body.data[2], { min: 5, context: 'LIST_USERS row' }).map((row) => {
      const [id, email, name, role, status] = assertFieldCount(row, 5, 'LIST_USERS row');
      return { id, email, name, role, status };
    });
    if (isV1(req)) return { data: users, meta: pageMeta(input, total) };
    return { data: ['USERS'], total, users };
  },
  GET_USER: async (body) => {
    // data: ['USER', id, email, name, status, role, createdAt]
    const [id, email, name, status, role, createdAt] = body.data.slice(1);
    return { data: ['USER'], user: { id, email, name, status, role, createdAt } };
  },
  CHECK_BALANCE: async (body) => {
    // Every account, parsed from "iso:balance:available:status" rows.
    const balances = splitRows(body.data[1], { min: 4, context: 'CHECK_BALANCE row' }).map((row) => {
      const [currency, balance, available, status] = assertFieldCount(row, 4, 'CHECK_BALANCE row');
      return { currency, balance, available, status };
    });
    return { data: ['BALANCES'], balances };
  },
  STATEMENT: async (body, input, { req } = {}) => {
    // One row per posting: id, posting/value dates, ref, source, side,
    // amount, balance after the row, reversal flag, description. The
    // description is free text and may itself contain ':'; it is the
    // remainder after the 9 fixed fields, never a counted field.
    const rows = splitRows(body.data[5], { min: 9, context: 'STATEMENT row' }).map((row) => {
      const [id, postedAt, valueDate, ref, source, side, amount, balanceAfter, reversed, ...desc] = row;
      return {
        id,
        postedAt,
        valueDate,
        ref,
        source,
        side,
        amount,
        balanceAfter,
        reversed: reversed === '1',
        description: desc.join(':'),
      };
    });
    if (isV1(req)) return { data: rows, meta: pageMeta(input, body.data[4]) };
    return {
      data: ['STATEMENT'],
      opening: body.data[1],
      closing: body.data[2],
      currency: body.data[3],
      total: body.data[4],
      lines: rows,
    };
  },
  OPEN_DISPUTE: async (body) => {
    return { data: ['DISPUTE_OPENED'], caseId: body.data[1] };
  },
  LIST_DISPUTES: async (body, input, { req } = {}) => {
    // One row per case: id, owner, subject, state, due date, overdue flag, opened date.
    const cases = splitRows(body.data[2], { min: 7, context: 'LIST_DISPUTES row' }).map((row) => {
      const [caseId, email, subject, state, due, overdue, created] = assertFieldCount(row, 7, 'LIST_DISPUTES row');
      return { caseId, email, subject, state, due, overdue: overdue === '1', created };
    });
    if (isV1(req)) return { data: cases, meta: pageMeta(input, body.data[1]) };
    return { data: ['DISPUTES'], total: body.data[1], cases };
  },
  GET_DISPUTE: async (body) => {
    const [caseId, email, ref, subject, detail, state, assignee, due, overdue, created, resolution] = assertFieldCount(
      String(body.data[1] || '').split(':'),
      11,
      'GET_DISPUTE case',
    );
    const messages = splitRows(body.data[3], { min: 4, context: 'GET_DISPUTE message' }).map((row) => {
      const [msgId, author, msgBody, sentAt] = assertFieldCount(row, 4, 'GET_DISPUTE message');
      return { msgId, author, body: msgBody, sentAt };
    });
    return {
      data: ['DISPUTE'],
      case: {
        caseId,
        email,
        ref,
        subject,
        detail,
        state,
        assignee,
        due,
        overdue: overdue === '1',
        created,
        resolution,
      },
      total: body.data[2],
      messages,
    };
  },
  GET_DASHBOARD: async (body) => {
    // data: ['DASHBOARD', email, name, status, role, dob, createdAt, accounts]
    const [email, name, status, role, dob, createdAt, accounts = ''] = body.data.slice(1);
    const balances = accounts
      ? splitRows(accounts, { min: 4, context: 'GET_DASHBOARD account' }).map((row) => {
          const [currency, balance, available, status] = assertFieldCount(row, 4, 'GET_DASHBOARD account');
          return { currency, balance, available, status };
        })
      : [];
    return {
      data: ['PROFILE'],
      profile: { email, name, status, role, dob, createdAt },
      accounts: balances,
      permissions: await listPermissions(email),
    };
  },
  REQ_EMAIL_CHANGE: async () => {
    // Neutral: a code is queued only when the new address is free.
    return { data: ['CODE_SENT'] };
  },
  CONFIRM_EMAIL_CHANGE: async () => {
    // The abandoned address is notified through the outbox.
    return { data: ['EMAIL_CHANGED'] };
  },
  MFA_BACKUP_CODES: async (body) => {
    return {
      data: ['BACKUP_CODES'],
      codes: String(body.data[1] || '')
        .split(',')
        .filter(Boolean),
    };
  },
  MFA_ENROLL_BEGIN: async (body, input) => {
    // The secret is shown once so the user can add it to their authenticator.
    const secret = body.data[1];
    const issuer = process.env.MFA_ISSUER || 'CobolBank';
    const label = encodeURIComponent(`${issuer}:${input.email}`);
    const otpauth = `otpauth://totp/${label}?secret=${secret}&issuer=${encodeURIComponent(issuer)}&algorithm=SHA1&digits=6&period=30`;
    return { data: ['MFA_SECRET'], secret, otpauth };
  },
  OPEN_ACCESS_REVIEW: async (body) => {
    return { data: ['REVIEW_OPENED'], reviewId: body.data[1], itemCount: Number(body.data[2]) };
  },
  LIST_ACCESS_REVIEWS: async (body, input, { req } = {}) => {
    const total = Number(body.data[1]);
    const reviews = splitRows(body.data[2], { min: 8, context: 'LIST_ACCESS_REVIEWS row' }).map((row) => {
      const [id, periodStart, periodEnd, state, openedBy, itemCount, closedBy, closedAt] = assertFieldCount(
        row,
        8,
        'LIST_ACCESS_REVIEWS row',
      );
      return { id, periodStart, periodEnd, state, openedBy, itemCount: Number(itemCount), closedBy, closedAt };
    });
    if (isV1(req)) return { data: reviews, meta: pageMeta(input, total) };
    return { data: ['REVIEWS'], total, reviews };
  },
  GET_ACCESS_REVIEW: async (body) => {
    const [id, periodStart, periodEnd, state, openedBy, closedBy, closedAt, itemRows] = body.data.slice(1);
    const items = splitRows(itemRows, { min: 9, context: 'GET_ACCESS_REVIEW item' }).map((row) => {
      const [itemId, email, role, status, mfaEnabled, decision, reviewer, lastLoginAt, note] = assertFieldCount(
        row,
        9,
        'GET_ACCESS_REVIEW item',
      );
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
  },
  DECIDE_ACCESS_ITEM: async (body) => {
    return { data: ['ITEM_DECIDED'], itemId: body.data[1], decision: body.data[2] };
  },
  CLOSE_ACCESS_REVIEW: async (body) => {
    return { data: ['REVIEW_CLOSED'], reviewId: body.data[1] };
  },
  // Domain list mappers for v1 pagination (arch9 WP-14). Legacy paths keep
  // the raw COBOL body untouched (passthrough); only /v1 parses rows and
  // returns {data, meta}. COBOL answers `SUCCESS|TAG|<rows>` or
  // `SUCCESS|TAG|0`; PAY/IMP/RPT lists additionally prefix a COUNT(*) total
  // (`SUCCESS|TAG|<total> |<rows>`).
  ACC_LIST: async (body, input, { req } = {}) => {
    if (!isV1(req)) return body;
    const items = listRows(body, 1, 6, 'ACC_LIST row').map((row) => {
      const [id, accountRef, status, balance, holdAmount, holderName] = assertFieldCount(row, 6, 'ACC_LIST row');
      return { id, accountRef, status, balance, holdAmount, holderName };
    });
    return { data: items, meta: pageMeta(input, null) };
  },
  LOAN_LIST: async (body, input, { req } = {}) => {
    if (!isV1(req)) return body;
    const items = listRows(body, 1, 6, 'LOAN_LIST row').map((row) => {
      const [id, loanRef, status, loanAmount, disbursedAmount, customerName] = assertFieldCount(
        row,
        6,
        'LOAN_LIST row',
      );
      return { id, loanRef, status, loanAmount, disbursedAmount, customerName };
    });
    return { data: items, meta: pageMeta(input, null) };
  },
  DEP_LIST: async (body, input, { req } = {}) => {
    if (!isV1(req)) return body;
    const items = listRows(body, 1, 7, 'DEP_LIST row').map((row) => {
      const [id, email, principal, currency, termMonths, status, accruedInterest] = assertFieldCount(
        row,
        7,
        'DEP_LIST row',
      );
      return { id, email, principal, currency, termMonths, status, accruedInterest };
    });
    return { data: items, meta: pageMeta(input, null) };
  },
  CARD_LIST: async (body, input, { req } = {}) => {
    if (!isV1(req)) return body;
    const items = listRows(body, 1, 9, 'CARD_LIST row').map((row) => {
      const [id, cardRef, email, cardType, status, limitAmount, availableLimit, balance, maskedPan] = assertFieldCount(
        row,
        9,
        'CARD_LIST row',
      );
      return { id, cardRef, email, cardType, status, limitAmount, availableLimit, balance, maskedPan };
    });
    return { data: items, meta: pageMeta(input, null) };
  },
  PAY_POLICY_LIST: async (body, input, { req } = {}) => {
    if (!isV1(req)) return body;
    const items = splitRows(body.data[2], { min: 7, context: 'PAY_POLICY_LIST row' }).map((row) => {
      const [currency, maxPerTxn, dailyLimit, dailyCount, holdThreshold, holdPercent, enabled] = assertFieldCount(
        row,
        7,
        'PAY_POLICY_LIST row',
      );
      return { currency, maxPerTxn, dailyLimit, dailyCount, holdThreshold, holdPercent, enabled: enabled === '1' };
    });
    return { data: items, meta: pageMeta(input, body.data[1]) };
  },
  IMP_BATCH_LIST: async (body, input, { req } = {}) => {
    if (!isV1(req)) return body;
    const items = splitRows(body.data[2], { min: 9, context: 'IMP_BATCH_LIST row' }).map((row) => {
      const [id, code, source, importType, status, totalRows, validRows, invalidRows, postedRows] = assertFieldCount(
        row,
        9,
        'IMP_BATCH_LIST row',
      );
      return { id, code, source, importType, status, totalRows, validRows, invalidRows, postedRows };
    });
    return { data: items, meta: pageMeta(input, body.data[1]) };
  },
  RPT_TEMPLATE_LIST: async (body, input, { req } = {}) => {
    if (!isV1(req)) return body;
    const items = splitRows(body.data[2], { min: 7, context: 'RPT_TEMPLATE_LIST row' }).map((row) => {
      const [id, code, name, reportType, outputFormat, enabled, title] = assertFieldCount(
        row,
        7,
        'RPT_TEMPLATE_LIST row',
      );
      return { id, code, name, reportType, outputFormat, enabled: enabled === '1', title };
    });
    return { data: items, meta: pageMeta(input, body.data[1]) };
  },
};
