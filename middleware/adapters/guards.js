// Canonical transport guards (ADR-0006).
// Owner: middleware/adapters. Wraps fail-open security checks so
// middleware/src (transport) never imports services directly:
//   src → adapters → services. COBOL remains the source of truth;
// these guards only shape transport (reject breached passwords, reject bots).
export { assertPasswordAllowed } from '../services/integrations/security/pwned.js';
export { verifyTurnstile, turnstileEnabled } from '../services/integrations/bot/turnstile.js';
