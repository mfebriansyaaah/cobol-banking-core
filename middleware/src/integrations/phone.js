// Phone OTP provider (PR-080): mock | telegram | free_sms.
// Only mock is implemented; telegram/free_sms resolve through this factory
// with explicit not-configured behavior until PR-082 lands them. The
// interface (sendOtp + health) is frozen now so call sites don't churn.
import { mockCalls, safeHealth } from './provider.js';

export function createPhoneProvider(kind, { logger = null } = {}) {
  if (kind === 'mock') {
    const mock = mockCalls();
    return {
      kind,
      calls: mock.calls,
      async sendOtp({ to, channel = 'sms' }) {
        const event = { event: 'phone_otp', to, channel };
        if (logger) logger(event);
        return mock.record(event);
      },
      async health() {
        return { ok: true, provider: 'mock', detail: null };
      },
    };
  }
  return {
    kind,
    async sendOtp() {
      throw new Error(`phone provider '${kind}' not implemented yet (PR-082)`);
    },
    async health() {
      return safeHealth(async () => {
        throw new Error(`phone provider '${kind}' not implemented yet (PR-082)`);
      }, kind);
    },
  };
}
