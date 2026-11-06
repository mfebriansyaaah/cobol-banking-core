// Identity provider (PR-080): mock | local.
// - mock: approves everything (tests, development without fixtures).
// - local: structural NIK validation (length/digits/province-day sanity),
//   no network, no personal data leaves the process. Full KYC workflow
//   arrives in PR-085; the interface is frozen now.
import { mockCalls, safeHealth } from './provider.js';
import { parseNik } from './identity/local_nik.js';

export function validateNikStructure(nik) {
  const r = parseNik(nik);
  return r.valid ? { ok: true, reason: null } : { ok: false, reason: r.reason };
}

export function createIdentityProvider(kind, { logger = null } = {}) {
  if (kind === 'local') {
    return {
      kind,
      async validateNik({ nik }) {
        const r = validateNikStructure(nik);
        if (logger) logger({ event: 'nik_validation', ok: r.ok });
        return r;
      },
      async health() {
        return { ok: true, provider: 'local', detail: null };
      },
    };
  }
  const mock = mockCalls();
  return {
    kind: 'mock',
    calls: mock.calls,
    async validateNik() {
      const event = { event: 'nik_validation', nik: 'redacted', approved: true };
      if (logger) logger(event);
      mock.record(event);
      return { ok: true, reason: null };
    },
    async health() {
      return safeHealth(async () => null, 'mock');
    },
  };
}
