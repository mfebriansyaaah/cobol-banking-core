// Support-only: deliver verification codes out of band. The gateway never
// returns the code in an HTTP response; how it reaches the user (SMTP here, or
// a stub in development) is a transport concern.

export function createMailer({ logger = null } = {}) {
  let transport;

  async function getTransport() {
    if (!process.env.SMTP_HOST) return null;
    if (!transport) {
      const { default: nodemailer } = await import('nodemailer');
      transport = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT || 587),
        secure: process.env.SMTP_SECURE === 'true',
        auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
      });
    }
    return transport;
  }

  return {
    async sendVerification({ to, purpose, code }) {
      const t = await getTransport();
      if (t) {
        await t.sendMail({
          from: process.env.MAIL_FROM || 'no-reply@cobol-banking.local',
          to,
          subject: purpose === 'EMAIL_CHANGE' ? 'Confirm your new email address' : 'Verify your account',
          text: `Your verification code is ${code}`,
        });
        return;
      }
      // No SMTP configured. Log the event (without the code) so it does not
      // leak; in non-production, MAIL_DEBUG=1 also shows the code for local dev.
      if (logger) {
        const line = { ts: new Date().toISOString(), level: 'info', event: 'verification_code', to, purpose };
        if (process.env.MAIL_DEBUG === '1' && process.env.NODE_ENV !== 'production') line.code = code;
        logger(line);
      }
    },
  };
}
