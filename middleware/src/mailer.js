// Support-only: deliver verification codes out of band. The gateway never
// returns the code in an HTTP response; how it reaches the user (SMTP here, or
// a stub in development) is a transport concern. Delivery is best-effort: a
// failing or missing SMTP never fails the request, and failures are counted.
import { incCounter } from './observability.js';

// Sender address, optionally with a display name ("Name <addr>").
export function mailerFrom() {
  const addr = process.env.MAIL_FROM || 'no-reply@cobol-banking.local';
  const name = process.env.MAIL_FROM_NAME;
  return name ? `${name} <${addr}>` : addr;
}

// Subject per verification purpose (else a generic verification subject).
export function verificationSubject(purpose) {
  switch (purpose) {
    case 'EMAIL_CHANGE':
      return 'Confirm your new email address';
    case 'PASSWORD_RESET':
      return 'Reset your password';
    default:
      return 'Verify your account';
  }
}

export function createMailer({ logger = null } = {}) {
  let transport;
  const timeoutMs = Number(process.env.SMTP_TIMEOUT_MS || 10000);

  async function getTransport() {
    if (!process.env.SMTP_HOST) return null;
    if (!transport) {
      const { default: nodemailer } = await import('nodemailer');
      transport = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT || 587),
        secure: process.env.SMTP_SECURE === 'true',
        auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
        connectionTimeout: timeoutMs,
        greetingTimeout: timeoutMs,
        socketTimeout: timeoutMs,
      });
    }
    return transport;
  }

  // Best-effort delivery: returns true on success, false when there is no SMTP
  // or the send failed. Never throws, so the request path is unaffected.
  async function deliver(message) {
    const t = await getTransport();
    if (!t) return false;
    try {
      await t.sendMail(message);
      incCounter('gateway_mailer_sent_total');
      return true;
    } catch (err) {
      incCounter('gateway_mailer_failed_total');
      if (logger) {
        logger({
          ts: new Date().toISOString(),
          level: 'warn',
          event: 'mail_failed',
          to: message.to,
          subject: message.subject,
          message: err && err.message,
        });
      }
      return false;
    }
  }

  return {
    async sendVerification({ to, purpose, code }) {
      const sent = await deliver({
        from: mailerFrom(),
        to,
        subject: verificationSubject(purpose),
        text: `Your verification code is ${code}`,
      });
      if (sent) return;
      // No SMTP (or the send failed). Log the event (without the code) so it
      // does not leak; in non-production, MAIL_DEBUG=1 also shows the code.
      if (logger) {
        const line = { ts: new Date().toISOString(), level: 'info', event: 'verification_code', to, purpose };
        if (process.env.MAIL_DEBUG === '1' && process.env.NODE_ENV !== 'production') line.code = code;
        logger(line);
      }
    },

    async sendNotice({ to, subject, text }) {
      const sent = await deliver({
        from: mailerFrom(),
        to,
        subject,
        text,
      });
      if (sent) return;
      if (logger) {
        logger({ ts: new Date().toISOString(), level: 'info', event: 'notice', to, subject });
      }
    },
  };
}
