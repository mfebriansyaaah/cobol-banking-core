// Email provider (PR-080): log | mailpit | smtp.
// - log: current development behavior (event logged, code never included,
//   delivery best-effort, never throws). Zero dependencies.
// - mailpit: SMTP to a local Mailpit (MAILPIT_HOST or SMTP_HOST, port 1025).
// - smtp: production SMTP via the existing mailer transport (lazy nodemailer).
import { createMailer } from '../mailer.js';
import { safeHealth } from './provider.js';

export function createEmailProvider(kind, { logger = null } = {}) {
  if (kind === 'smtp' || kind === 'mailpit') {
    const mailer = createMailer({ logger });
    return {
      kind,
      async sendVerification({ to, purpose, code }) {
        return mailer.sendVerification({ to, purpose, code });
      },
      async sendNotice({ to, subject, text }) {
        return mailer.sendNotice({ to, subject, text });
      },
      async health() {
        return safeHealth(async () => {
          if (kind === 'mailpit') {
            return { host: process.env.MAILPIT_HOST || process.env.SMTP_HOST || '127.0.0.1' };
          }
          return { host: process.env.SMTP_HOST || null };
        }, kind);
      },
    };
  }
  // log (default): structured event, no network, no secrets on the wire.
  const mock = [];
  return {
    kind: 'log',
    calls: mock,
    async sendVerification({ to, purpose }) {
      const event = { event: 'email_verification', to, purpose };
      if (logger) logger(event);
      else mock.push(event);
      return true;
    },
    async sendNotice({ to, subject }) {
      const event = { event: 'email_notice', to, subject };
      if (logger) logger(event);
      else mock.push(event);
      return true;
    },
    async health() {
      return { ok: true, provider: 'log', detail: null };
    },
  };
}
