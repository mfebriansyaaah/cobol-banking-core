// Canonical mailer access for transport (ADR-0006).
// Owner: middleware/adapters. Re-exports the service factory so
// middleware/src imports adapters, never services directly.
export { createMailer, mailerFrom, verificationSubject } from '../services/mailer.js';
