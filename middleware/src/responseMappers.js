// Response mappers: transform a successful COBOL result line into the
// HTTP response body. Pure presentation only: no direct COBOL invoke, no
// token signing, no SQL. Session/token side effects live in authService.js;
// the two session mappers below delegate to it so all orchestration stays
// in one gateway service module.
import { completeLogin, completeStepUp, listPermissions } from './authService.js';
import { completeIssue } from '../adapters/otp.js';

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
  LIST_USERS: async (body) => {
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
  },
  GET_USER: async (body) => {
    // data: ['USER', id, email, name, status, role, createdAt]
    const [id, email, name, status, role, createdAt] = body.data.slice(1);
    return { data: ['USER'], user: { id, email, name, status, role, createdAt } };
  },
  CHECK_BALANCE: async (body) => {
    // Every account, parsed from "iso:balance:available:status" rows.
    const balances = String(body.data[1] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [currency, balance, available, status] = row.split(':');
        return { currency, balance, available, status };
      });
    return { data: ['BALANCES'], balances };
  },
  STATEMENT: async (body) => {
    // One row per posting: id, posting/value dates, ref, source, side,
    // amount, balance after the row, reversal flag, description.
    const rows = String(body.data[5] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [id, postedAt, valueDate, ref, source, side, amount, balanceAfter, reversed, ...desc] = row.split(':');
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
  LIST_DISPUTES: async (body) => {
    // One row per case: id, owner, subject, state, due date, overdue flag, opened date.
    const cases = String(body.data[2] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [caseId, email, subject, state, due, overdue, created] = row.split(':');
        return { caseId, email, subject, state, due, overdue: overdue === '1', created };
      });
    return { data: ['DISPUTES'], total: body.data[1], cases };
  },
  GET_DISPUTE: async (body) => {
    const [caseId, email, ref, subject, detail, state, assignee, due, overdue, created, resolution] = String(
      body.data[1] || '',
    ).split(':');
    const messages = String(body.data[3] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [msgId, author, msgBody, sentAt] = row.split(':');
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
      ? accounts.split(';').map((row) => {
          const [currency, balance, available, status] = row.split(':');
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
  LIST_ACCESS_REVIEWS: async (body) => {
    const total = Number(body.data[1]);
    const reviews = String(body.data[2] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [id, periodStart, periodEnd, state, openedBy, itemCount, closedBy, closedAt] = row.split(':');
        return { id, periodStart, periodEnd, state, openedBy, itemCount: Number(itemCount), closedBy, closedAt };
      });
    return { data: ['REVIEWS'], total, reviews };
  },
  GET_ACCESS_REVIEW: async (body) => {
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
  },
  DECIDE_ACCESS_ITEM: async (body) => {
    return { data: ['ITEM_DECIDED'], itemId: body.data[1], decision: body.data[2] };
  },
  CLOSE_ACCESS_REVIEW: async (body) => {
    return { data: ['REVIEW_CLOSED'], reviewId: body.data[1] };
  },
};
